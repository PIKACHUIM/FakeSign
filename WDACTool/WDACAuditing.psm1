# File paths are often in the format of device path (e.g. \Device\HarddiskVolumeN\).
# Get-Partition is used to map the volume number to a partition so that file paths can be normalized.
$Script:PartitionMapping = @{}

Get-Partition | Where-Object { $_.DriveLetter } | ForEach-Object { $PartitionMapping[$_.PartitionNumber.ToString()] = $_.DriveLetter }

# Try again. Get-Partition is flakey for some reason but it seems to work if tried a second time.
if ($PartitionMapping.Count -eq 0) {
    Get-Partition | Where-Object { $_.DriveLetter } | ForEach-Object { $PartitionMapping[$_.PartitionNumber.ToString()] = $_.DriveLetter }
}

# Resolve user names from SIDs
$Script:UserMapping = @{}

$Script:Providers = @{
    'Microsoft-Windows-AppLocker'     = (Get-WinEvent -ListProvider Microsoft-Windows-AppLocker)
    'Microsoft-Windows-CodeIntegrity' = (Get-WinEvent -ListProvider Microsoft-Windows-CodeIntegrity)
}

# Hash to cache event templates
$Script:EventTemplates = @{}

# This hashtable is used to resolve RequestedSigningLevel and ValidatedSigningLevel fields into human-readable properties
# For more context around signing levels, Alex Ionescu (@aionescu) has a great resource on them:
# http://www.alex-ionescu.com/?p=146
# They are also officially documented here: https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/event-tag-explanations#validatedsigninglevel
$Script:SigningLevelMapping = @{
    [Byte] 0x0 = 'Not Checked'
    [Byte] 0x1 = 'Unsigned'
    [Byte] 0x2 = 'WDAC Code Integrity Policy'
    [Byte] 0x3 = 'Developer-Signed'
    [Byte] 0x4 = 'Authenticode-Signed'
    [Byte] 0x5 = 'Microsoft Store-Signed PPL'
    [Byte] 0x6 = 'Microsoft Store-Signed'
    [Byte] 0x7 = 'Antimalware PPL'
    [Byte] 0x8 = 'Microsoft-Signed'
    [Byte] 0x9 = 'Custom4'
    [Byte] 0xA = 'Custom5'
    [Byte] 0xB = '.NET NGEN Signer'
    [Byte] 0xC = 'Windows'
    [Byte] 0xD = 'Windows PPL'
    [Byte] 0xE = 'Windows TCB'
    [Byte] 0xF = 'Custom6'
}

# These are documented here: https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/event-tag-explanations#signaturetype
$Script:SignatureTypeMapping = @{
    [Byte] 0 = 'Unsigned'
    [Byte] 1 = 'Embedded Authenticode Signature'
    [Byte] 2 = 'Cached CI Extended Attribute Signature'
    [Byte] 3 = 'Cached Catalog Signature'
    [Byte] 4 = 'Catalog Signature'
    [Byte] 5 = 'Cached CI Extended Attribute Hint'
    [Byte] 6 = 'Appx or MSIX Package Catalog Verified'
    [Byte] 7 = 'File was Verified'
}

# These are documented here: https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/event-tag-explanations#verificationerror
$Script:VerificationErrorMapping = @{
    [Byte] 0 = 'Successfully verified signature'
    [Byte] 1 = 'File has an invalid hash'
    [Byte] 2 = 'File contains shared writable sections'
    [Byte] 3 = 'File is not signed'
    [Byte] 4 = 'Revoked signature'
    [Byte] 5 = 'Expired signature'
    [Byte] 6 = 'File is signed using a weak hashing algorithm which does not meet the minimum policy'
    [Byte] 7 = 'Invalid root certificate'
    [Byte] 8 = 'Signature was unable to be validated; generic error'
    [Byte] 9 = 'Signing time not trusted'
    [Byte] 10 = 'The file must be signed using page hashes for this scenario'
    [Byte] 11 = 'Page hash mismatch'
    [Byte] 12 = 'Not valid for a PPL (Protected Process Light)'
    [Byte] 13 = 'Not valid for a PP (Protected Process)'
    [Byte] 14 = 'The signature is missing the required ARM EKU'
    [Byte] 15 = 'Failed WHQL check'
    [Byte] 16 = 'Default policy signing level not met'
    [Byte] 17 = "Custom policy signing level not met; returned when signature doesn't validate against an SBCP-defined set of certs"
    [Byte] 18 = 'Custom signing level not met; returned if signature fails to match CISigners in UMCI'
    [Byte] 19 = 'Binary is revoked by file hash'
    [Byte] 20 = "SHA1 cert hash's timestamp is missing or after valid cutoff as defined by Weak Crypto Policy"
    [Byte] 21 = 'Failed to pass WDAC policy'
    [Byte] 22 = 'Not IUM (Isolated User Mode) signed; indicates trying to load a non-trustlet binary into a trustlet'
    [Byte] 23 = 'Invalid image hash'
    [Byte] 24 = 'Flight root not allowed; indicates trying to run flight-signed code on production OS'
    [Byte] 25 = 'Anti-cheat policy violation'
    [Byte] 26 = 'Explicitly denied by WDAC policy'
    [Byte] 27 = 'The signing chain appears to be tampered/invalid'
    [Byte] 28 = 'Resource page hash mismatch'
}

function Get-UserMapping {
    [CmdletBinding()]
    param (
        # Security identifier of the account to look up
        [Parameter(Mandatory)]
        [System.Security.Principal.SecurityIdentifier]$SID
    )

    if (-not ($UserMapping[$SID.Value])) {
        $Account = Get-CimInstance Win32_Account -Property SID, Caption -Filter ('SID="{0}"' -f $SID.Value)
        # Revert to the SID if a user name cannot be resolved
        $UserMapping[$SID.Value] = if ($Account.Caption) {$Account.Caption} else {$SID.Value}
    }
    $UserMapping[$SID.Value]
}

function Get-WDACPolicyRefreshEventFilter {
    <#
    .SYNOPSIS
    Returns a filter to use to get only events that occured since last policy refresh

    .DESCRIPTION
    Get-WDACPolicyRefreshEventFilter retrieves the latestMicrosoft-Windows-CodeIntegrity/Operational policy refresh event (id 3099) and generates a string to insert in "FilterXPath" filters to only search for events generated after the latest policy refresh

    .EXAMPLE
    Get-WDACPolicyRefreshEventFilter

    Looks for the latest policy refresh event and returns a filter string such as " and TimeCreated[@SystemTime >= '2020-10-05T08:11:22.7969367+02:00']"
    #>

    [CmdletBinding()]
    param()

    # Only consider failed audit events that occured after the last CI policy update (event ID 3099)
    $LastPolicyUpdateEvent = Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-CodeIntegrity/Operational'; Id = 3099 } -MaxEvents 1 -ErrorAction Ignore

    # Sometimes this event will not be present - e.g. if the log rolled since the last update.
    if ($LastPolicyUpdateEvent) {
        $DateTimeAfter = [Xml.XmlConvert]::ToString($LastPolicyUpdateEvent.TimeCreated.ToUniversalTime(), 'O')

        " and TimeCreated[@SystemTime >= '$DateTimeAfter']"
    } else {
        Write-Verbose "No policy update event was present in the event log. Ignoring the -SinceLastPolicyRefresh switch."
        ''
    }
}

function Get-WinEventData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Diagnostics.Eventing.Reader.EventLogRecord] $EventRecord
    )

    process {
        $Provider = $Providers[$EventRecord.ProviderName]

        if ($Provider.Events.Id -contains $EventRecord.Id) {
            $EventTemplateName = $EventRecord.ProviderName, $EventRecord.Id, $EventRecord.Version -join '_'

            if (-not $EventTemplates[$EventTemplateName]) {
                $EventTemplates[$EventTemplateName] = ($Provider.Events | Where-Object { $_.Id -eq $EventRecord.Id -and $_.Version -eq $EventRecord.Version }).Template
            }

            [Xml] $XmlTemplate = $EventTemplates[$EventTemplateName]

            $EventData = @{}

            for ($i = 0; $i -lt $EventRecord.Properties.Count; $i++) {
                $Name = $XmlTemplate.template.data.name[$i] -replace ' ', ''
                $Value = $EventRecord.Properties[$i].Value

                $EventData[$Name] = $Value
            }

            $EventData
        }
        else {
            $EventRecord.Properties.Value
        }
    }
}

function Get-WDACApplockerScriptMsiEvent {
<#
.SYNOPSIS

Returns script/MSI event log audit/enforcement events in a more human-readable fashion.

.DESCRIPTION

Get-WDACApplockerScriptMsiEvent retrieves and parses Microsoft-Windows-AppLocker/MSI and Script audit and enforcement events into a format that is more human-readable. This function is designed to facilitate regular code integrity policy baselining. Non-PE code that is subject to code integrity enforcement is logged to the Microsoft-Windows-AppLocker/MSI and Script log.

Author: Matthew Graeber
License: BSD 3-Clause

.PARAMETER SignerInformation

Specifies that correlated signer information should be collected. Note: When there are many CodeIntegrity events present in the event log, collection of signature events can be time consuming.

.PARAMETER ShowAllowedEvents

Specifies that Get-WDACApplockerScriptMsiEvent should also return scripts that were allowed to execute (via 8037 events)

.PARAMETER SinceLastPolicyRefresh

Specifies that events should only be returned since the last time the code integrity policy was refreshed. This option is useful for baselining purposes.

.PARAMETER MaxEvents

Specifies the maximum number of events that Get-WDACCodeIntegrityEvent returns. The default is to return all the events.

.EXAMPLE

Get-WDACApplockerScriptMsiEvent

Return all user-mode code integrity events (audit/enforcement) since the last code intgrity policy refresh.

.EXAMPLE

Get-WDACApplockerScriptMsiEvent -MaxEvents 5

Return the most recent 5 script/MSI code integrity events.

.EXAMPLE

Get-WDACApplockerScriptMsiEvent -SinceLastPolicyRefresh

Return all script/MSI code integrity events since the last code intgrity policy refresh.

.EXAMPLE

Get-WDACApplockerScriptMsiEvent -SignerInformation
#>

    [CmdletBinding()]
    param (
        [Switch]
        $SignerInformation,

        [Switch]
        $ShowAllowedEvents,

        [Switch]
        $SinceLastPolicyRefresh,

        [Int64]
        $MaxEvents
    )

    $MaxEventArg = @{}

    # Pass -MaxEvents through to Get-WinEvent
    if ($MaxEvents) { $MaxEventArg = @{ MaxEvents = $MaxEvents } }

    $PolicyRefreshFilter = ''

    if ($SinceLastPolicyRefresh) {
        $PolicyRefreshFilter = Get-WDACPolicyRefreshEventFilter -Verbose:$False
    }

    if ($ShowAllowedEvents) {
        $Filter = "*[System[(EventID = 8028 or EventID = 8029 or EventID = 8037)$($PolicyRefreshFilter)]]"
    } else {
        $Filter = "*[System[(EventID = 8028 or EventID = 8029)$($PolicyRefreshFilter)]]"
    }

    Write-Verbose "XPath Filter: $Filter"

    $EventIdMapping = @{
        8028 = 'Audit'
        8029 = 'Enforce'
        8037 = 'Allowed'
    }

    Get-WinEvent -LogName 'Microsoft-Windows-AppLocker/MSI and Script' -FilterXPath $Filter @MaxEventArg -ErrorAction Ignore | ForEach-Object {
        $ResolvedSigners = $null
        $SigningStatus = $null

        # 8037 (Allow) events do not populate signer information so don't attempt to retrieve
        if ($SignerInformation -and ($_.Id -ne 8037)) {
            $SigningStatus = 'Unsigned'

            # Retrieve correlated signer info (event ID 8038)
            # Note: there may be more than one correlated signer event in the case of the file having multiple signers.
            $Signer = Get-WinEvent -LogName 'Microsoft-Windows-AppLocker/MSI and Script' -FilterXPath "*[System[EventID = 8038 and Correlation[@ActivityID = '$($_.ActivityId.Guid)']]]" -MaxEvents 1 -ErrorAction Ignore

            # Unsigned scripts will often generate bogus 8038 events. Don't process them
            if ($Signer.Properties.Count -gt 0) {

                if ($Signer.Properties[0].Value -gt 1) {
                    $Signer = Get-WinEvent -LogName 'Microsoft-Windows-AppLocker/MSI and Script' -FilterXPath "*[System[EventID = 8038 and Correlation[@ActivityID = '$($_.ActivityId.Guid)']]]" -MaxEvents ($Signer.Properties[0].Value) -ErrorAction Ignore
                }

                $ResolvedSigners = $Signer | ForEach-Object {
                    $SignerData = Get-WinEventData -EventRecord $_

                    if (-not (($SignerData.PublisherNameLength -eq 0) -and ($SignerData.IssuerNameLength -eq 0) -and ($SignerData.PublisherTBSHashSize -eq 0) -and ($SignerData.IssuerTBSHashSize -eq 0))) {
                        $SigningStatus = 'Signed'

                        $PublisherTBSHash = $null
                        if ($SignerData.PublisherTBSHash) { $PublisherTBSHash = [BitConverter]::ToString($SignerData.PublisherTBSHash).Replace('-','') }

                        $IssuerTBSHash = $null
                        if ($SignerData.IssuerTBSHash) { $IssuerTBSHash = [BitConverter]::ToString($SignerData.IssuerTBSHash).Replace('-','') }

                        New-Object -TypeName PSObject -Property ([Ordered] @{
                            SignatureIndex = $SignerData.Signature
                            PublisherName = $SignerData.PublisherName
                            IssuerName = $SignerData.IssuerName
                            PublisherTBSHash = $PublisherTBSHash
                            IssuerTBSHash = $IssuerTBSHash
                        })
                    }
                }
            }
        }

        $EventData = Get-WinEventData -EventRecord $_

        $UserName = Get-UserMapping $_.UserId.Value

        $SHA1FileHash = $null
        if ($EventData.Sha1Hash) { $SHA1FileHash = [BitConverter]::ToString($EventData.Sha1Hash).Replace('-','') }

        $SHA256FileHash = $null
        if ($EventData.Sha256CatalogHash) { $SHA256FileHash = [BitConverter]::ToString($EventData.Sha256CatalogHash).Replace('-','') }

        $SHA256AuthenticodeHash = $null
        if ($EventData.Sha256Hash) { $SHA256AuthenticodeHash = [BitConverter]::ToString($EventData.Sha256Hash).Replace('-','') }

        $ObjectArgs = [Ordered] @{
            TimeCreated = $_.TimeCreated
            ProcessID = $_.ProcessId
            User = $UserName
            EventType = $EventIdMapping[$_.Id]
            FilePath = $EventData.FilePath
            SHA1FileHash = $SHA1FileHash
            SHA256FileHash = $SHA256FileHash
            SHA256AuthenticodeHash = $SHA256AuthenticodeHash
            UserWriteable = $EventData.UserWriteable
            Signed = $SigningStatus
            SignerInfo = ($ResolvedSigners | Sort-Object -Property SignatureIndex)
        }

        New-Object -TypeName PSObject -Property $ObjectArgs
    }
}

function Get-WDACCodeIntegrityEvent {
<#
.SYNOPSIS

Returns code integrity event log audit/enforcement events in a more human-readable fashion.

.DESCRIPTION

Get-WDACCodeIntegrityEvent retrieves and parses Microsoft-Windows-CodeIntegrity/Operational PE audit and enforcement events into a format that is more human-readable. This function is designed to facilitate regular code integrity policy baselining.

Author: Matthew Graeber
License: BSD 3-Clause

.PARAMETER User

Specifies that only user-mode events should be returned. If neither -User nor -Kernel is specified, user and kernel events are returned.

.PARAMETER Kernel

Specifies that only kernel-mode events should be returned. If neither -User nor -Kernel is specified, user and kernel events are returned.

.PARAMETER Audit

Specifies that only audit events (event ID 3076) should be returned. If neither -Audit nor -Enforce is specified, audit and enforcement events are returned.

.PARAMETER Enforce

Specifies that only enforcement events (event ID 3077) should be returned. If neither -Audit nor -Enforce is specified, audit and enforcement events are returned.

.PARAMETER SinceLastPolicyRefresh

Specifies that events should only be returned since the last time the code integrity policy was refreshed. This option is useful for baselining purposes.

.PARAMETER SignerInformation

Specifies that correlated signer information should be collected. Note: When there are many CodeIntegrity events present in the event log, collection of signature events can be time consuming.

.PARAMETER CheckWhqlStatus

Specifies that correlated WHQL events should be collected. Supplying this switch will populate the returned FailedWHQL property.

.PARAMETER IgnoreNativeImagesDLLs

Specifies that events where ResolvedFilePath is like "$env:SystemRoot\assembly\NativeImages*.dll" should be skipped. Useful to suppress events caused by auto-generated "NativeImages DLLs"

.PARAMETER IgnoreDenyEvents

Specifies that only events will be returned that are not explicitly blocked by policy. This switch only works when -SignerInformation is also specified. This switch is available to help reduce noise and prevent inadvertantly creating allow rules for explicitly denied executables.

.PARAMETER MaxEvents

Specifies the maximum number of events that Get-WDACCodeIntegrityEvent returns. The default is to return all the events.

.EXAMPLE

Get-WDACCodeIntegrityEvent -SinceLastPolicyRefresh

Return all code integrity events (user/kernel/audit/enforcement) since the last code intgrity policy refresh.

.EXAMPLE

Get-WDACCodeIntegrityEvent -User -SinceLastPolicyRefresh

Return all user-mode code integrity events (audit/enforcement) since the last code intgrity policy refresh.

.EXAMPLE

Get-WDACCodeIntegrityEvent -Kernel -MaxEvents 5

Return the most recent 5 kernel mode code integrity events.

.EXAMPLE

Get-WDACCodeIntegrityEvent -Kernel -Enforce

Return all kernel mode enforcement events.
#>

    [CmdletBinding(DefaultParameterSetName = 'NoSignerCheck')]
    param (
        [Parameter(ParameterSetName = 'NoSignerCheck')]
        [Parameter(ParameterSetName = 'SignerCheck')]
        [Switch]
        $User,

        [Parameter(ParameterSetName = 'NoSignerCheck')]
        [Parameter(ParameterSetName = 'SignerCheck')]
        [Switch]
        $Kernel,

        [Parameter(ParameterSetName = 'NoSignerCheck')]
        [Parameter(ParameterSetName = 'SignerCheck')]
        [Switch]
        $Audit,

        [Parameter(ParameterSetName = 'NoSignerCheck')]
        [Parameter(ParameterSetName = 'SignerCheck')]
        [Switch]
        $Enforce,

        [Parameter(ParameterSetName = 'NoSignerCheck')]
        [Parameter(ParameterSetName = 'SignerCheck')]
        [Switch]
        $SinceLastPolicyRefresh,

        [Parameter(Mandatory, ParameterSetName = 'SignerCheck')]
        [Switch]
        $SignerInformation,

        [Parameter(ParameterSetName = 'NoSignerCheck')]
        [Parameter(ParameterSetName = 'SignerCheck')]
        [Switch]
        $CheckWhqlStatus,

        [Parameter(ParameterSetName = 'NoSignerCheck')]
        [Parameter(ParameterSetName = 'SignerCheck')]
        [Switch]
        $IgnoreNativeImagesDLLs,

        [Parameter(ParameterSetName = 'SignerCheck')]
        [Switch]
        $IgnoreDenyEvents,

        [Parameter(ParameterSetName = 'NoSignerCheck')]
        [Parameter(ParameterSetName = 'SignerCheck')]
        [Int64]
        $MaxEvents
    )

    # If neither -User nor -Kernel are supplied, do not filter based on signing scenario
    # If -User and -Kernel are supplied, do not filter based on signing scenario
    # Only filter in a mutually exclusive scenario.
    $ScenarioFilter = ''

    if ($User -and !$Kernel) {
        # 1 == A user-mode rule triggered
        $ScenarioFilter = " and EventData[Data[@Name='SI Signing Scenario'] = 1]"
    } elseif ($Kernel -and !$User) {
        # 2 == A kernel-mode rule triggered
        $ScenarioFilter = " and EventData[Data[@Name='SI Signing Scenario'] = 0]"
    }

    # If neither -Audit nor -Enforce are supplied, do not filter based on event ID
    # If -Audit and -Enforce are supplied, do not filter based on event ID
    # Only filter in a mutually exclusive scenario.
    $ModeFilter = '(EventID = 3076 or EventID = 3077)'

    if ($Audit -and !$Enforce) {
        # Event ID 3076 == an audit event
        $ModeFilter = "EventID = 3076"
    } elseif ($Enforce -and !$Audit) {
        # Event ID 3077 == an enforcement event
        $ModeFilter = "EventID = 3077"
    }

    $PolicyRefreshFilter = ''

    if ($SinceLastPolicyRefresh) {
        $PolicyRefreshFilter = Get-WDACPolicyRefreshEventFilter -Verbose:$False
    }

    $Filter = "*[System[$($ModeFilter)$($PolicyRefreshFilter)]$ScenarioFilter]"

    Write-Verbose "XPath Filter: $Filter"

    $EventIdMapping = @{
        3076 = 'Audit'
        3077 = 'Enforce'
    }

    $SigningScenarioMapping = @{
        [UInt32] 0 = 'Driver'
        [UInt32] 1 = 'UserMode'
    }

    $MaxEventArg = @{}

    # Pass -MaxEvents through to Get-WinEvent
    if ($MaxEvents) { $MaxEventArg = @{ MaxEvents = $MaxEvents } }

    Get-WinEvent -LogName 'Microsoft-Windows-CodeIntegrity/Operational' -FilterXPath $Filter @MaxEventArg -ErrorAction Ignore | ForEach-Object {
        $EventData = Get-WinEventData -EventRecord $_

        $WHQLFailed = $null

        if ($CheckWhqlStatus) {
            $WHQLFailed = $False

            # A correlated 3082 event indicates that WHQL verification failed
            $WHQLEvent = Get-WinEvent -LogName 'Microsoft-Windows-CodeIntegrity/Operational' -FilterXPath "*[System[EventID = 3082 and Correlation[@ActivityID = '$($_.ActivityId.Guid)']]]" -MaxEvents 1 -ErrorAction Ignore

            if ($WHQLEvent) { $WHQLFailed = $True }
        }

        $ResolvedSigners = $null
        $ExplicitlyDeniedSigner = $False

        if ($SignerInformation) {
            # Retrieve correlated signer info (event ID 3089)
            # Note: there may be more than one correlated signer event in the case of the file having multiple signers.
            $Signer = Get-WinEvent -LogName 'Microsoft-Windows-CodeIntegrity/Operational' -FilterXPath "*[System[EventID = 3089 and Correlation[@ActivityID = '$($_.ActivityId.Guid)']]]" -MaxEvents 1 -ErrorAction Ignore

            if ($Signer -and $Signer.Properties -and ($Signer.Properties[0].Value -gt 1)) {
                $Signer = Get-WinEvent -LogName 'Microsoft-Windows-CodeIntegrity/Operational' -FilterXPath "*[System[EventID = 3089 and Correlation[@ActivityID = '$($_.ActivityId.Guid)']]]" -MaxEvents ($Signer.Properties[0].Value) -ErrorAction Ignore
            }

            $ResolvedSigners = $Signer | ForEach-Object {
                $SignerData = Get-WinEventData -EventRecord $_

                $SignatureType = $SignatureTypeMapping[$SignerData.SignatureType]

                $VerificationError = $VerificationErrorMapping[$SignerData.VerificationError]

                if ($IgnoreDenyEvents -and ($VerificationError -eq 'Explicitly denied by WDAC policy')) { $ExplicitlyDeniedSigner = $True }

                $Hash = $null
                if ($SignerData.Hash) { $Hash = [BitConverter]::ToString($SignerData.Hash).Replace('-','') }

                $PublisherTBSHash = $null
                if ($SignerData.PublisherTBSHash) { $PublisherTBSHash = [BitConverter]::ToString($SignerData.PublisherTBSHash).Replace('-','') }

                $IssuerTBSHash = $null
                if ($SignerData.IssuerTBSHash) { $IssuerTBSHash = [BitConverter]::ToString($SignerData.IssuerTBSHash).Replace('-','') }

                New-Object -TypeName PSObject -Property ([Ordered] @{
                    SignatureIndex = $SignerData.Signature
                    Hash = $Hash
                    PageHash = $SignerData.PageHash
                    SignatureType = $SignatureType
                    ValidatedSigningLevel = $SigningLevelMapping[$SignerData.ValidatedSigningLevel]
                    VerificationError = $VerificationError
                    Flags = $SignerData.Flags
                    PolicyBits = $SignerData.PolicyBits
                    NotValidBefore = $SignerData.NotValidBefore
                    NotValidAfter = $SignerData.NotValidAfter
                    PublisherName = $SignerData.PublisherName
                    IssuerName = $SignerData.IssuerName
                    PublisherTBSHash = $PublisherTBSHash
                    IssuerTBSHash = $IssuerTBSHash
                })
            }
        }

        if (-not $ExplicitlyDeniedSigner) {
            $UnresolvedFilePath = $EventData.FileName

            $ResolvedFilePath = $null
            # Make a best effort to resolve the device path to a normal path.
            if ($UnresolvedFilePath -match '(?<Prefix>^\\Device\\HarddiskVolume(?<VolumeNumber>\d)\\)') {
                $ResolvedFilePath = $UnresolvedFilePath.Replace($Matches['Prefix'], "$($PartitionMapping[$Matches['VolumeNumber']]):\")
            } elseif ($UnresolvedFilePath.ToLower().StartsWith('system32')) {
                $ResolvedFilePath = "$($Env:windir)\System32$($UnresolvedFilePath.Substring(8))"
            }

            # If all else fails regarding path resolution, show a warning.
            if ($ResolvedFilePath -and !(Test-Path -Path $ResolvedFilePath)) {
                Write-Warning "The following file path was either not resolved properly or was not present on disk: $ResolvedFilePath"
            }

            $ResolvedProcessName = $null
            $ProcessName = $EventData.ProcessName
            # Make a best effort to resolve the process path to a normal path.
            if ($ProcessName -match '(?<Prefix>^\\Device\\HarddiskVolume(?<VolumeNumber>\d)\\)') {
                $ResolvedProcessName = $ProcessName.Replace($Matches['Prefix'], "$($PartitionMapping[$Matches['VolumeNumber']]):\")
            } elseif ($ProcessName.ToLower().StartsWith('system32')) {
                $ResolvedProcessName = "$($Env:windir)\System32$($ProcessName.Substring(8))"
            }

            # If all else fails regarding path resolution, show a warning.
            if ($ResolvedProcessName -and !(Test-Path -Path $ResolvedProcessName)) {
                Write-Warning "The following process file path was either not resolved properly or was not present on disk: $ResolvedProcessName"
            }

            $UserName = Get-UserMapping $_.UserId.Value

            $SHA1FileHash = $null
            if ($EventData.SHA1FlatHash) { $SHA1FileHash = [BitConverter]::ToString($EventData.SHA1FlatHash[0..19]).Replace('-','') }

            $SHA1AuthenticodeHash = $null
            if ($EventData.SHA1Hash) { $SHA1AuthenticodeHash = [BitConverter]::ToString($EventData.SHA1Hash).Replace('-','') }
            
            $SHA256FileHash = $null
            if ($EventData.SHA256FlatHash) { $SHA256FileHash = [BitConverter]::ToString($EventData.SHA256FlatHash[0..31]).Replace('-','') }

            $SHA256AuthenticodeHash = $null
            if ($EventData.SHA256Hash) { $SHA256AuthenticodeHash = [BitConverter]::ToString($EventData.SHA256Hash).Replace('-','') }

            $PolicyGuid = $null
            if ($EventData.PolicyGUID) { $PolicyGuid = $EventData.PolicyGUID.Guid.ToUpper() }

            $PolicyHash = $null
            if ($EventData.PolicyHash) { $PolicyHash = [BitConverter]::ToString($EventData.PolicyHash).Replace('-','') }

            $CIEventProperties = [Ordered] @{
                TimeCreated = $_.TimeCreated
                ProcessID = $_.ProcessId
                User = $UserName
                EventType = $EventIdMapping[$_.Id]
                SigningScenario = $SigningScenarioMapping[$EventData.SISigningScenario]
                UnresolvedFilePath = $UnresolvedFilePath
                FilePath = $ResolvedFilePath
                SHA1FileHash = $SHA1FileHash
                SHA1AuthenticodeHash = $SHA1AuthenticodeHash
                SHA256FileHash = $SHA256FileHash
                SHA256AuthenticodeHash = $SHA256AuthenticodeHash
                UnresolvedProcessName = $EventData.ProcessName
                ProcessName = $ResolvedProcessName
                RequestedSigningLevel = $SigningLevelMapping[$EventData.RequestedSigningLevel]
                ValidatedSigningLevel = $SigningLevelMapping[$EventData.ValidatedSigningLevel]
                PolicyName = $EventData.PolicyName
                PolicyID = $EventData.PolicyId
                PolicyGUID = $PolicyGuid
                PolicyHash = $PolicyHash
                OriginalFileName = $EventData.OriginalFileName
                InternalName = $EventData.InternalName
                FileDescription = $EventData.FileDescription
                ProductName = $EventData.ProductName
                FileVersion = $EventData.FileVersion
                PackageFamilyName = $EventData.PackageFamilyName
                UserWriteable = $EventData.UserWriteable
                FailedWHQL = $WHQLFailed
                SignerInfo = ($ResolvedSigners | Sort-Object -Property SignatureIndex)
            }

            if (-not $IgnoreNativeImagesDLLs -or ($IgnoreNativeImagesDLLs -and $CIEventProperties.ResolvedFilePath -notlike "$env:SystemRoot\assembly\NativeImages*.dll")) {
                New-Object -TypeName PSObject -Property $CIEventProperties
            }
        }
    }
}

function Copy-WDACEventFile {
<#
.SYNOPSIS

Copies files returned by the Get-WDACApplockerScriptMsiEvent or Get-WDACCodeIntegrityEvent functions to a destination directory.

.DESCRIPTION

Copy-WDACEventFile copies files returned by the Get-WDACApplockerScriptMsiEvent or Get-WDACCodeIntegrityEvent functions to a destination directory. When developing targeted code integrity policies, it is ideal to consolidate all the relevant files in a dedicated directory that are not intermingled with files not to be added per policy. Copy-WDACEventFile copies files in a targeted fashion such that Get-SystemDriver will scan a specific path containing only the relevant file.

Author: Matthew Graeber
License: BSD 3-Clause

.PARAMETER FilePath

Specifies the filepath of the executable or script to be copied.

.PARAMETER Destination

Specifies the destination directory where all files will be copied.

.EXAMPLE

Get-WDACCodeIntegrityEvent | Copy-WDACEventFile -Destination .\FilesToAllow

.EXAMPLE

Get-WDACApplockerScriptMsiEvent | Copy-WDACEventFile -Destination .\FilesToAllow

.INPUTS

PSObject

Copy-WDACEventFile accepts the output of Get-WDACApplockerScriptMsiEvent and Get-WDACCodeIntegrityEvent.

.OUTPUTS

System.IO.FileInfo

Copy-WDACEventFile outputs a FileInfo object representing the new file that was copied to its destination.
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 1)]
        [String]
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        $Destination,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, Position = 0)]
        [String[]]
        [ValidateNotNullOrEmpty()]
        $FilePath
    )

    BEGIN {
        $ResolvedDestination = Resolve-Path $Destination
    }

    PROCESS {
        foreach ($Path in $FilePath) {
            $FileName = Split-Path -Path $Path -Leaf
            $ChildDestinationDirectory = (Split-Path -Path $Path -Parent).Substring(2)

            $DestinationDirectory = Join-Path -Path $ResolvedDestination -ChildPath $ChildDestinationDirectory
            $DestinationFilePath = Join-Path -Path $DestinationDirectory -ChildPath $FileName

            # If the destination directory doesn't exist, create it
            if (-not (Test-Path -Path $DestinationDirectory -PathType Container)) {
                $null = mkdir -Path $DestinationDirectory -Force
            }

            Copy-Item -Path $Path -Destination $DestinationFilePath -PassThru
        }
    }
}