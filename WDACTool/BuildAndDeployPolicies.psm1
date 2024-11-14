function ConvertTo-WDACPolicyRuleValue {
<#
.SYNOPSIS

A helper function to convert Windows Defender Application Control (WDAC) policy rule options to numeric values which are required for the Set-RuleOption cmdlet.

.DESCRIPTION

ConvertTo-WDACPolicyRuleValue converts human-readable WDAC policy rule options to numeric values for use by the Set-RuleOption cmdlet. Due to the poor design of Set-RuleOption, you cannot supply these string values and must supply integeter values which is not intuitive or user-friendly. This function makes calling Set-RuleOption more intuitive.

This function is not designed to be exposed to users. Functions with parameters that support policy rules options should support tab-completion for the human-readble values.

Author: Matthew Graeber

.PARAMETER PolicyOptionStrings

Specifies an array of human-readble policy rule options that want to be set.

.EXAMPLE

ConvertTo-WDACPolicyRuleValue -PolicyOptionStrings 'Enabled:UMCI', 'Enabled:Boot Menu Protection', 'Enabled:Audit Mode'

Returns an array of integer values representing the requested policy rule options. These values can then be more easily supplied to a subsequent call to Set-RuleOption.
#>

    [OutputType([Int[]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('Enabled:UMCI',
                     'Enabled:Boot Menu Protection',
                     'Required:WHQL',
                     'Enabled:Audit Mode',
                     'Disabled:Flight Signing',
                     'Enabled:Inherit Default Policy',
                     'Enabled:Unsigned System Integrity Policy',
                     'Allowed:Debug Policy Augmented',
                     'Required:EV Signers',
                     'Enabled:Advanced Boot Options Menu',
                     'Enabled:Boot Audit On Failure',
                     'Disabled:Script Enforcement',
                     'Required:Enforce Store Applications',
                     'Enabled:Managed Installer',
                     'Enabled:Intelligent Security Graph Authorization',
                     'Enabled:Invalidate EAs on Reboot',
                     'Enabled:Update Policy No Reboot',
                     'Enabled:Allow Supplemental Policies',
                     'Disabled:Runtime FilePath Rule Protection',
                     'Enabled:Dynamic Code Security',
                     'Enabled:Revoked Expired As Unsigned')]
        [String[]] $PolicyOptionStrings
    )

    $RuleOptionMapping = @{
        'Enabled:UMCI' = 0
        'Enabled:Boot Menu Protection' = 1
        'Required:WHQL' = 2
        'Enabled:Audit Mode' = 3
        'Disabled:Flight Signing' = 4
        'Enabled:Inherit Default Policy' = 5
        'Enabled:Unsigned System Integrity Policy' = 6
        'Allowed:Debug Policy Augmented' = 7
        'Required:EV Signers' = 8
        'Enabled:Advanced Boot Options Menu' = 9
        'Enabled:Boot Audit On Failure' = 10
        'Disabled:Script Enforcement' = 11
        'Required:Enforce Store Applications' = 12
        'Enabled:Managed Installer' = 13
        'Enabled:Intelligent Security Graph Authorization' = 14
        'Enabled:Invalidate EAs on Reboot' = 15
        'Enabled:Update Policy No Reboot' = 16
        'Enabled:Allow Supplemental Policies' = 17
        'Disabled:Runtime FilePath Rule Protection' = 18
        'Enabled:Dynamic Code Security' = 19
        'Enabled:Revoked Expired As Unsigned' = 20
    }

    foreach ($PolicyOptionString in $PolicyOptionStrings) {
        $RuleOptionMapping[$PolicyOptionString]
    }
}

function New-WDACPolicyConfiguration {
<#
.SYNOPSIS

A helper function used to specify a code integrity policy configuration.

.DESCRIPTION

New-WDACPolicyConfiguration is used as a helper function to generate code integrity policy configuration options and to supply them to the Invoke-WDACCodeIntegrityPolicyBuild function.

The objects output by New-WDACPolicyConfiguration are intended to be supplied as arguments to the following parameters in Invoke-WDACCodeIntegrityPolicyBuild: -BasePolicyConfiguration, -SupplementalPolicyConfiguration, -MergedPolicyConfiguration

Author: Matthew Graeber

.PARAMETER BasePolicy

Specifies that a base policy is to be configured and built. Base policies must reside in the "BasePolicies" directory.

When this switch is specified, the object output is supplied to the -BasePolicyConfiguration parameter in Invoke-WDACCodeIntegrityPolicyBuild.

.PARAMETER SupplementalPolicy

Specifies that a supplemental policy is to be configured and built. Supplemental policies must reside in the "SupplementalPolicies" directory.

When this switch is specified, the object output is supplied to the -SupplementalPolicyConfiguration parameter in Invoke-WDACCodeIntegrityPolicyBuild.

.PARAMETER MergedPolicy

Specifies that a supplemental policy is to be configured and built by merging multiple policies together. Supplemental policies designed for merging must reside in the "AppSpecificPolicies" directory.

When this switch is specified, the object output is supplied to the -MergedPolicyConfiguration parameter in Invoke-WDACCodeIntegrityPolicyBuild.

.PARAMETER FileName

Specifies the filename of the XML policy file. This parameter only applies when the -BasePolicy or -SupplementalPolicy switches are supplied.

.PARAMETER PolicyName

Specifies the name of the policy. Upon deployment of your policy, this policy name will be surfaced in the event log.

.PARAMETER PolicyRuleOptions

Specifies the policy rule options that you want to supply to the specified policy. This parameter supports tab-completion.

.PARAMETER BasePolicyToSupplement

Specifies the base policy that the merged, application-specific policy is a supplement to. This parameter is mandatory when -MergedPolicy is specified.

.EXAMPLE

$BaseDriverPolicy = New-WDACPolicyConfiguration -BasePolicy -FileName 'BaseDriverPolicy.xml' -PolicyName 'BaseDriverRuleset' -PolicyRuleOptions 'Enabled:Audit Mode'

Specifies configuration options for a base policy. The object output would then be supplied to the -BasePolicyConfiguration parameter in Invoke-WDACCodeIntegrityPolicyBuild.

.EXAMPLE

$SupplementalSurfacePolicy = New-WDACPolicyConfiguration -SupplementalPolicy -FileName 'MicrosoftSurfaceDriverPolicy.xml' -PolicyName '3rdPartyDriverRuleset' -PolicyRuleOptions 'Enabled:Audit Mode'

Specifies configuration options for a supplemental policy. The object output would then be supplied to the -SupplementalPolicyConfiguration parameter in Invoke-WDACCodeIntegrityPolicyBuild.

.EXAMPLE

$MergedPolicyConfiguration = New-WDACPolicyConfiguration -MergedPolicy -PolicyName 'Merged3rdPartySoftwareRuleset' -BasePolicyToSupplement 'BaseUserModeRuleset' -PolicyRuleOptions 'Enabled:Audit Mode'

Specifies configuration options for a merged supplemental policy (i.e. the policies that reside in the "AppSpecificPolicies" directory). The object output would then be supplied to the -MergedPolicyConfiguration parameter in Invoke-WDACCodeIntegrityPolicyBuild.
#>

    [CmdletBinding(DefaultParameterSetName = 'Base')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Base')]
        [Switch]
        $BasePolicy,

        [Parameter(Mandatory, ParameterSetName = 'Supplemental')]
        [Switch]
        $SupplementalPolicy,

        [Parameter(Mandatory, ParameterSetName = 'Merged')]
        [Switch]
        $MergedPolicy,

        [Parameter(Mandatory, ParameterSetName = 'Merged')]
        [String]
        [ValidateNotNullOrEmpty()]
        $BasePolicyToSupplement,

        [Parameter(Mandatory, ParameterSetName = 'Base')]
        [Parameter(Mandatory, ParameterSetName = 'Supplemental')]
        [String]
        $FileName,

        [Parameter(Mandatory)]
        [String]
        $PolicyName,

        [String[]]
        [ValidateSet('Enabled:UMCI',
                     'Enabled:Boot Menu Protection',
                     'Required:WHQL',
                     'Enabled:Audit Mode',
                     'Disabled:Flight Signing',
                     'Enabled:Inherit Default Policy',
                     'Enabled:Unsigned System Integrity Policy',
                     'Allowed:Debug Policy Augmented',
                     'Required:EV Signers',
                     'Enabled:Advanced Boot Options Menu',
                     'Enabled:Boot Audit On Failure',
                     'Disabled:Script Enforcement',
                     'Required:Enforce Store Applications',
                     'Enabled:Managed Installer',
                     'Enabled:Intelligent Security Graph Authorization',
                     'Enabled:Invalidate EAs on Reboot',
                     'Enabled:Update Policy No Reboot',
                     'Enabled:Allow Supplemental Policies',
                     'Disabled:Runtime FilePath Rule Protection',
                     'Enabled:Dynamic Code Security',
                     'Enabled:Revoked Expired As Unsigned')]
        $PolicyRuleOptions
    )

    if ($BasePolicy) {
        $ConfigurationProperties = [Ordered] @{
            PSTypeName        = 'WDACBasePolicyConfiguration'
            FileName          = $FileName
            PolicyName        = $PolicyName
            PolicyRuleOptions = $PolicyRuleOptions
        }
    }

    if ($SupplementalPolicy) {
        $ConfigurationProperties = [Ordered] @{
            PSTypeName        = 'WDACSupplementalPolicyConfiguration'
            FileName          = $FileName
            PolicyName        = $PolicyName
            PolicyRuleOptions = $PolicyRuleOptions
        }
    }

    if ($MergedPolicy) {
        $ConfigurationProperties = [Ordered] @{
            PSTypeName        = 'WDACMergedPolicyConfiguration'
            PolicyName        = $PolicyName
            PolicyRuleOptions = $PolicyRuleOptions
            BasePolicyToSupplement = $BasePolicyToSupplement
        }
    }

    New-Object -TypeName PSObject -Property $ConfigurationProperties
}

function Invoke-WDACCodeIntegrityPolicyBuild {
<#
.SYNOPSIS

Facilitates building and deploying multiple base and supplemental code integrity policies.

.DESCRIPTION

Invoke-WDACCodeIntegrityPolicyBuild builds and, optionally, deploys and refreshes code integrity policies locally.

Author: Matthew Graeber

.PARAMETER CommonBasePolicyRuleOptions

Specifies a set of policy rule options to apply to all generated policy files. This parameter was designed to facilitate consistency

.PARAMETER BasePolicyConfiguration

Specifies one or more base policy configurations that were generated by New-WDACPolicyConfiguration.

.PARAMETER SupplementalPolicyConfiguration

Specifies one or more supplemental policy configurations that were generated by New-WDACPolicyConfiguration.

.PARAMETER MergedPolicyConfiguration

Specifies a merged supplemental policy configuration that was generated by New-WDACPolicyConfiguration.

.PARAMETER ArtifactPath

By default, generated artifacts (code integrity policy XML and binary code integrity policy .cip files) are written to the "BuildArtifacts" directory. This parameter allows you to specify an alternate build artifact directory. The directory must already exist.

.PARAMETER Deploy

Copies generated binary policy files to %windir%\System32\CodeIntegrity\CiPolicies\Active. If this option is selected, the policy won't be updated until the next reboot.

.PARAMETER DeployAndUpdate

Copies generated binary policy files to %windir%\System32\CodeIntegrity\CiPolicies\Active and refreshes the rules so that policy changes take effect immediately.

.EXAMPLE

$CommonBasePolicyRuleOptions = @(
    'Enabled:Unsigned System Integrity Policy',
    'Enabled:Advanced Boot Options Menu',
    'Enabled:Update Policy No Reboot',
    'Enabled:Allow Supplemental Policies',
    'Disabled:Flight Signing',
    'Required:WHQL',
    'Enabled:Boot Audit On Failure'
)

$BasePolicyConfigurations = @(
    (New-WDACPolicyConfiguration -BasePolicy -FileName 'BaseDriverPolicy.xml' -PolicyName 'BaseDriverRuleset' -PolicyRuleOptions 'Enabled:Audit Mode'),
    (New-WDACPolicyConfiguration -BasePolicy -FileName 'BaseUserPolicy.xml' -PolicyName 'BaseUserModeRuleset' -PolicyRuleOptions 'Disabled:Script Enforcement', 'Enabled:UMCI', 'Enabled:Audit Mode'),
    (New-WDACPolicyConfiguration -BasePolicy -FileName 'MicrosoftRecommendedBlockRules.xml' -PolicyName 'MicrosoftRecommendedBlockRuleset' -PolicyRuleOptions 'Disabled:Script Enforcement', 'Enabled:UMCI', 'Enabled:Audit Mode')
)

$SupplementalPolicyConfigurations = @(
    (New-WDACPolicyConfiguration -SupplementalPolicy -FileName 'MicrosoftSurfaceDriverPolicy.xml' -PolicyName '3rdPartyDriverRuleset' -PolicyRuleOptions 'Enabled:Audit Mode')
)

$MergedPolicyConfiguration = New-WDACPolicyConfiguration -MergedPolicy -PolicyName 'Merged3rdPartySoftwareRuleset' -BasePolicyToSupplement 'BaseUserModeRuleset' -PolicyRuleOptions 'Enabled:Audit Mode'

$CodeIntegrityPoliciesArgs = @{
    CommonBasePolicyRuleOptions     = $CommonBasePolicyRuleOptions
    BasePolicyConfiguration         = $BasePolicyConfigurations
    SupplementalPolicyConfiguration = $SupplementalPolicyConfigurations
    MergedPolicyConfiguration       = $MergedPolicyConfiguration
}

Invoke-WDACCodeIntegrityPolicyBuild @CodeIntegrityPoliciesArgs

This code specifies several policy configurations, converts them to binary form, and saves the resulting binary policy files to the "BuildArtifacts" directory.
#>

    [CmdletBinding(DefaultParameterSetName = 'Deploy')]
    param (
        [Parameter()]
        [ValidateSet('Enabled:UMCI',
                     'Enabled:Boot Menu Protection',
                     'Required:WHQL',
                     'Enabled:Audit Mode',
                     'Disabled:Flight Signing',
                     'Enabled:Inherit Default Policy',
                     'Enabled:Unsigned System Integrity Policy',
                     'Allowed:Debug Policy Augmented',
                     'Required:EV Signers',
                     'Enabled:Advanced Boot Options Menu',
                     'Enabled:Boot Audit On Failure',
                     'Disabled:Script Enforcement',
                     'Required:Enforce Store Applications',
                     'Enabled:Managed Installer',
                     'Enabled:Intelligent Security Graph Authorization',
                     'Enabled:Invalidate EAs on Reboot',
                     'Enabled:Update Policy No Reboot',
                     'Enabled:Allow Supplemental Policies',
                     'Disabled:Runtime FilePath Rule Protection',
                     'Enabled:Dynamic Code Security',
                     'Enabled:Revoked Expired As Unsigned')]
        [String[]]
        $CommonBasePolicyRuleOptions,

        [Parameter(Mandatory)]
        [PSTypeName('WDACBasePolicyConfiguration')]
        [PSObject[]]
        $BasePolicyConfiguration,

        [PSTypeName('WDACSupplementalPolicyConfiguration')]
        [PSObject[]]
        $SupplementalPolicyConfiguration,

        [PSTypeName('WDACMergedPolicyConfiguration')]
        [PSObject]
        $MergedPolicyConfiguration,

        [String]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        $ArtifactPath,

        [Parameter(ParameterSetName = 'Deploy')]
        [Switch]
        $Deploy,

        [Parameter(ParameterSetName = 'DeployAndUpdate')]
        [Switch]
        $DeployAndUpdate
    )

    # Policy ID will be set to the day's date.
    $DateString = (Get-Date).ToString('MM_dd_yyyy')

    $CommonBasePolicyRuleOptionValues = ConvertTo-WDACPolicyRuleValue -PolicyOptionStrings $CommonBasePolicyRuleOptions

    $ArtifactBasePath = "$PSScriptRoot\BuildArtifacts"

    $MergedPolicy = $null

    if ($ArtifactPath) {
        $ArtifactBasePath = $ArtifactPath
    }

    # Configure and build base policies
    $BasePolicies = foreach ($BaseConfig in $BasePolicyConfiguration) {
        $BasePolicyPath = "$PSScriptRoot\BasePolicies\$($BaseConfig.FileName)"

        # Each base template policy will be copied to this location prior to configuration.
        $BasePolicyBuildPath = "$ArtifactBasePath\$($BaseConfig.FileName)"

        [Xml] $PolicyXml = Get-Content -Path $BasePolicyPath -Raw

        $PolicyID = $PolicyXml.SiPolicy.PolicyID
        # $BasePolicyID = $PolicyXml.SiPolicy.BasePolicyID

        Copy-Item -Path $BasePolicyPath -Destination $BasePolicyBuildPath

        if ($CommonBasePolicyRuleOptionValues) {
            foreach ($CommonBaseRuleOptionValue in $CommonBasePolicyRuleOptionValues) {
                Set-RuleOption -FilePath $BasePolicyBuildPath -Option $CommonBaseRuleOptionValue
            }
        }

        $BaseConfigurationPolicyRuleOptionValues = $null

        if ($BaseConfig.PolicyRuleOptions) {
            $BaseConfigurationPolicyRuleOptionValues = ConvertTo-WDACPolicyRuleValue -PolicyOptionStrings $BaseConfig.PolicyRuleOptions
        }

        foreach ($RuleOption in $BaseConfigurationPolicyRuleOptionValues) {
            Set-RuleOption -FilePath $BasePolicyBuildPath -Option $RuleOption
        }

        Set-CIPolicyIdInfo -FilePath $BasePolicyBuildPath -PolicyName $BaseConfig.PolicyName -PolicyId $DateString -WarningAction SilentlyContinue

        [Xml] $BuiltPolicyXml = Get-Content -Path $BasePolicyBuildPath -Raw

        ConvertFrom-CIPolicy -XmlFilePath $BasePolicyBuildPath -BinaryFilePath "$ArtifactBasePath\$PolicyID.cip" | ForEach-Object {
            # ConvertFrom-CIPolicy returns a string consisting of the binary CI policy file. Resolve the path.
            $FileInfo = Get-Item -Path $_
            $XmlFileInfo = Get-Item -Path $BasePolicyBuildPath

            $PolicyProperties = [Ordered] @{
                PolicyType = 'Base'
                XmlFileInfo = $XmlFileInfo
                BinaryFileInfo = $FileInfo
                PolicyID = $BuiltPolicyXml.SiPolicy.PolicyID
                BasePolicyID = $BuiltPolicyXml.SiPolicy.BasePolicyID
                PolicyInfoName = ($BuiltPolicyXml.SiPolicy.Settings.Setting | Where-Object { $_.ValueName -eq 'Name' } | Select-Object -ExpandProperty Value | Select-Object -ExpandProperty String)
                PolicyInfoID = ($BuiltPolicyXml.SiPolicy.Settings.Setting | Where-Object { $_.ValueName -eq 'Id' } | Select-Object -ExpandProperty Value | Select-Object -ExpandProperty String)
            }

            New-Object -TypeName PSObject -Property $PolicyProperties
        }
    }

    # Configure and build supplemental policies
    if ($SupplementalPolicyConfiguration)
    {
        $SupplementalPolicies = foreach ($SupplementalConfig in $SupplementalPolicyConfiguration) {
            $SupplementalPolicyPath = "$PSScriptRoot\SupplementalPolicies\$($SupplementalConfig.FileName)"

            # Each base template policy will be copied to this location prior to configuration.
            $SupplementalPolicyBuildPath = "$ArtifactBasePath\$($SupplementalConfig.FileName)"

            [Xml] $PolicyXml = Get-Content -Path $SupplementalPolicyPath -Raw

            $PolicyID = $PolicyXml.SiPolicy.PolicyID

            Copy-Item -Path $SupplementalPolicyPath -Destination $SupplementalPolicyBuildPath

            if ($CommonBasePolicyRuleOptions) {
                foreach ($CommonBaseRuleOption in $CommonBasePolicyRuleOptionValues) {
                    Set-RuleOption -FilePath $SupplementalPolicyBuildPath -Option $CommonBaseRuleOption
                }
            }

            $SupplementalConfigurationPolicyRuleOptionValues = $null

            if ($SupplementalConfig.PolicyRuleOptions) {
                $SupplementalConfigurationPolicyRuleOptionValues = ConvertTo-WDACPolicyRuleValue -PolicyOptionStrings $SupplementalConfig.PolicyRuleOptions
            }

            foreach ($RuleOption in $SupplementalConfigurationPolicyRuleOptionValues) {
                Set-RuleOption -FilePath $SupplementalPolicyBuildPath -Option $RuleOption
            }

            # Delete the "Enabled:Allow Supplemental Policies" if it was specified in the common policy rule option config.
            Set-RuleOption -FilePath $SupplementalPolicyBuildPath -Option 17 -Delete

            Set-CIPolicyIdInfo -FilePath $SupplementalPolicyBuildPath -PolicyName $SupplementalConfig.PolicyName -PolicyId $DateString -WarningAction SilentlyContinue

            [Xml] $BuiltPolicyXml = Get-Content -Path $SupplementalPolicyBuildPath -Raw

            ConvertFrom-CIPolicy -XmlFilePath $SupplementalPolicyBuildPath -BinaryFilePath "$ArtifactBasePath\$PolicyID.cip" | ForEach-Object {
                # ConvertFrom-CIPolicy returns a string consisting of the binary CI policy file. Resolve the path.
                $FileInfo = Get-Item -Path $_
                $XmlFileInfo = Get-Item -Path $SupplementalPolicyBuildPath

                $PolicyProperties = [Ordered] @{
                    PolicyType = 'Supplemental'
                    XmlFileInfo = $XmlFileInfo
                    BinaryFileInfo = $FileInfo
                    PolicyID = $BuiltPolicyXml.SiPolicy.PolicyID
                    BasePolicyID = $BuiltPolicyXml.SiPolicy.BasePolicyID
                    PolicyInfoName = ($BuiltPolicyXml.SiPolicy.Settings.Setting | Where-Object { $_.ValueName -eq 'Name' } | Select-Object -ExpandProperty Value | Select-Object -ExpandProperty String)
                    PolicyInfoID = ($BuiltPolicyXml.SiPolicy.Settings.Setting | Where-Object { $_.ValueName -eq 'Id' } | Select-Object -ExpandProperty Value | Select-Object -ExpandProperty String)
                }

                New-Object -TypeName PSObject -Property $PolicyProperties
            }
        }
    }

    # Build the app-specific policy
    if ($MergedPolicyConfiguration) {
        if (-not ($BasePolicies | Where-Object { $_.PolicyInfoName -eq $MergedPolicyConfiguration.BasePolicyToSupplement })) {
            Write-Error "The merged, application-specific supplemental policy is expected to supplement the following base policy that was not supplied: $($MergedPolicyConfiguration.BasePolicyToSupplement)"
            return
        }

        $BasePolicyID = $BasePolicies | Where-Object { $_.PolicyInfoName -eq $MergedPolicyConfiguration.BasePolicyToSupplement } | Select-Object -ExpandProperty BasePolicyId

        $CopiedAppTemplateDestination = "$ArtifactBasePath\AppSpecificPolicyTemplate.xml"

        # Copy the application-specific template policy to the artifacts directory.
        # This is done because the BasePolicyID element is going to be updated in the XML.
        # Assign the application-specific supplemental policy base policy ID to the base policy name specified.

        # I'd love to use the supported cmdlet for this but I really don't like that you can't avoid
        # Having the PolicyID reset.
        # Set-CIPolicyIdInfo -FilePath $CopiedAppTemplateDestination -SupplementsBasePolicyID $BasePolicyID

        $XmlString = Get-Content -Path "$PSScriptRoot\AppSpecificPolicies\AppSpecificPolicyTemplate.xml" -Raw

        $BasePolicyIdToReplace = [Xml] $XmlString | Select-Object -ExpandProperty SiPolicy | Select-Object -ExpandProperty BasePolicyId

        $ReplacedXmlString = $XmlString -replace "<BasePolicyID>$BasePolicyIdToReplace</BasePolicyID>", "<BasePolicyID>$BasePolicyID</BasePolicyID>"

        Out-File -FilePath $CopiedAppTemplateDestination -InputObject $ReplacedXmlString -Encoding utf8 -ErrorAction Stop

        # AppSpecificPolicyTemplate.xml is used for maintaining file rule options.
        # Note: AppSpecificPolicyTemplate.xml must be the first policy file specified as this is what Merge-CIPolicy takes policy options from.
        $AppSpecificPolicyFiles = New-Object -TypeName String[](0)

        $AppSpecificPolicyFiles += $CopiedAppTemplateDestination
        Get-ChildItem "$PSScriptRoot\AppSpecificPolicies\*.xml" -Exclude 'AppSpecificPolicyTemplate.xml' |
            Select-Object -ExpandProperty FullName |
            ForEach-Object { $AppSpecificPolicyFiles += $_ }

        $MergedPolicyPath = "$ArtifactBasePath\MergedPolicy.xml"

        $null = Merge-CIPolicy -OutputFilePath $MergedPolicyPath -PolicyPaths ([String[]] $AppSpecificPolicyFiles)

        [Xml] $PolicyXml = Get-Content -Path $MergedPolicyPath -Raw

        $PolicyID = $PolicyXml.SiPolicy.PolicyID

        if ($CommonBasePolicyRuleOptions)
        {
            foreach ($CommonBaseRuleOption in $CommonBasePolicyRuleOptionValues) {
                Set-RuleOption -FilePath $MergedPolicyPath -Option $CommonBaseRuleOption
            }
        }

        $MergedConfigurationPolicyRuleOptionValues = $null

        if ($MergedPolicyConfiguration.PolicyRuleOptions) {
            $MergedConfigurationPolicyRuleOptionValues = ConvertTo-WDACPolicyRuleValue -PolicyOptionStrings $MergedPolicyConfiguration.PolicyRuleOptions
        }

        foreach ($RuleOption in $MergedConfigurationPolicyRuleOptionValues) {
            Set-RuleOption -FilePath $MergedPolicyPath -Option $RuleOption
        }

        # Delete the "Enabled:Allow Supplemental Policies" if it was specified in the common policy rule option config.
        Set-RuleOption -FilePath $MergedPolicyPath -Option 17 -Delete

        Set-CIPolicyIdInfo -FilePath $MergedPolicyPath -PolicyName $MergedPolicyConfiguration.PolicyName -PolicyId $DateString -WarningAction SilentlyContinue

        [Xml] $BuiltPolicyXml = Get-Content -Path $MergedPolicyPath -Raw

        ConvertFrom-CIPolicy -XmlFilePath $MergedPolicyPath -BinaryFilePath "$ArtifactBasePath\$PolicyID.cip" | ForEach-Object {
            # ConvertFrom-CIPolicy returns a string consisting of the binary CI policy file. Resolve the path.
            $FileInfo = Get-Item -Path $_
            $XmlFileInfo = Get-Item -Path $MergedPolicyPath

            $PolicyProperties = [Ordered] @{
                PolicyType = 'MergedSupplemental'
                XmlFileInfo = $XmlFileInfo
                BinaryFileInfo = $FileInfo
                PolicyID = $BuiltPolicyXml.SiPolicy.PolicyID
                BasePolicyID = $BuiltPolicyXml.SiPolicy.BasePolicyID
                PolicyInfoName = ($BuiltPolicyXml.SiPolicy.Settings.Setting | Where-Object { $_.ValueName -eq 'Name' } | Select-Object -ExpandProperty Value | Select-Object -ExpandProperty String)
                PolicyInfoID = ($BuiltPolicyXml.SiPolicy.Settings.Setting | Where-Object { $_.ValueName -eq 'Id' } | Select-Object -ExpandProperty Value | Select-Object -ExpandProperty String)
            }

            $MergedPolicy = New-Object -TypeName PSObject -Property $PolicyProperties
        }
    }

    # Build a list of the generated binary policy files so that only those files are deployed
    # when -Deploy or -DeployAndUpdate are specified.
    $BinaryPolicyFiles = New-Object -TypeName String[](0)

    if ($BasePolicies) {
        $BasePolicies
        $BasePolicies | ForEach-Object { $BinaryPolicyFiles += $_.BinaryFileInfo }
    }

    if ($SupplementalPolicies) {
        $SupplementalPolicies
        $SupplementalPolicies | ForEach-Object { $BinaryPolicyFiles += $_.BinaryFileInfo }
    }

    if ($MergedPolicy) {
        $MergedPolicy
        $BinaryPolicyFiles += $MergedPolicy.BinaryFileInfo
    }

    # Copy all binary policy files to the relevant WDAC CI policy directory.
    if ($Deploy -or $DeployAndUpdate) {
        $BinaryPolicyFiles | Get-ChildItem | ForEach-Object {
            $DestinationDir = "$Env:windir\System32\CodeIntegrity\CiPolicies\Active"

            Write-Verbose "Copying $($_.FullName) to $DestinationDir."
            $_ | Copy-Item -Destination $DestinationDir -PassThru
        }
    }

    # Refresh all active code integrity policies so that the changes can take effect immediately without needing to reboot.
    if ($DeployAndUpdate) {
        Get-ChildItem -Path "$Env:windir\System32\CodeIntegrity\CiPolicies\Active\*.cip" | ForEach-Object {
            Write-Verbose "Applying the following policy: $($_.FullName)"

            $Result = Invoke-CimMethod -Namespace root\Microsoft\Windows\CI -ClassName PS_UpdateAndCompareCIPolicy -MethodName Update -Arguments @{ FilePath = $_.FullName }
            if ($Result.ReturnValue -ne 0) {
                Write-Error "The following policy failed to refresh: $($_.FullName). Return value: $($Result.ReturnValue)"
            }
        }
    }
}

filter Update-WDACBinaryCodeIntegrityPolicy {
<#
.SYNOPSIS

Refreshes a binary code integrity policy without requiring a reboot.

.DESCRIPTION

Update-WDACBinaryCodeIntegrityPolicy is used to explicitly refresh one or more binary code integrity policies without requiring a reboot. In order to support this scenario, your base policy must be configured with the "Enabled:Update Policy No Reboot" option.

Author: Matthew Graeber

.PARAMETER Path

Specifies the path to a binary code integrity file that you would like to explicitly update without rebooting. A binary code integrity policy will have a file extension of .p7b or .cip in a multi-policy scenario.

.EXAMPLE

Update-WDACBinaryPolicy -Path C:\Windows\System32\CodeIntegrity\SIPolicy.p7b

Updating a single policy.

.EXAMPLE

Get-ChildItem -Path "$Env:windir\System32\CodeIntegrity\CiPolicies\Active\*.cip" | Update-WDACBinaryCodeIntegrityPolicy

Updating all policies in a multi-policy scenario.
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]
        [ValidateNotNullOrEmpty()]
        [Alias('FullName')]
        $Path
    )

    $FullPath = Resolve-Path $Path

    $Result = Invoke-CimMethod -Namespace root\Microsoft\Windows\CI -ClassName PS_UpdateAndCompareCIPolicy -MethodName Update -Arguments @{ FilePath = $FullPath.Path }

    if ($Result.ReturnValue -ne 0) {
        Write-Error "The following policy failed to refresh: $($FullPath.Path). Return value: $($Result.ReturnValue)"
    }
}

function Disable-WDACDeployedPolicy {
<#
.SYNOPSIS

Disables the currently deployed code integrity policy. Note: this does not delete deployed policy files in %windir%\System32\CodeIntegrity. Those should be removed manually, if desired.

.EXAMPLE

Disable-WDACDeployedPolicy
#>

    Invoke-CimMethod -Namespace root\Microsoft\Windows\CI -ClassName PS_UpdateAndCompareCIPolicy -MethodName Delete
}