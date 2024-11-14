The `WDACTools` PowerShell module comprises everything that should be needed to build, configure, deploy, and audit [Windows Defender Application Control](https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/windows-defender-application-control) (WDAC) policies.

Despite the relative complexity of this repository, the goal is to minimize policy deployment, maintenance, and auditing overhead. `WDACTools` requires Windows 10 1903+ Enterprise in order to build multiple policies. Once policies are built, Enterprise SKUs of Windows 10 1903+ are not required for deployment as long as the `Enabled:Inherit Default Policy` [policy rule option](https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/select-types-of-rules-to-create) is specified.

# Motivations

The feature of WDAC that motivated me to develop this module was, beginning in Windows 10 1903, the ability to deploy [multiple base and supplemental policies](https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/deploy-multiple-windows-defender-application-control-policies). In particular, this offers the following unique advantages:

1. Mixed-mode policy enforcement: Upon properly tuning a policy, I can place one or more policies into enforcement mode. Then, as new tuning/maintenance requirements arise, I can have one or more policies in audit mode that will permit execution while tuning while keeping well-establised rules in enforcement mode. Additionally, there may be scenarios where it is unrealistic to block execution of certain binaries but you would like to have optics into when they're loaded with an audit mode policy side by side with enforcement policies.
2. Maintaining multiple policies that are scoped to a specific set of software and/or signers is far easier to maintain than a single, massive, difficult to audit policy.
3. When code integrity (CI) events are logged, the corresponding policy that generated the CI event is logged.

# Problems

1. The advantage that having many policies offers also creates its own maintenance headache where maintaining policy rule option consistency across many policies. I have been bitten by accidentally prematurely placing a policy intended for audit mode in enforcement mode, resulting in an unstable OS, a [problem which is painful and challenging to debug](https://posts.specterops.io/adventures-in-extremely-strict-device-guard-policy-configuration-part-1-device-drivers-fd1a281b35a8).
2. As rich as the logging is, it remains difficult to contextualize what all fields mean across many related events.
3. The existing WDAC cmdlets available in the [ConfigCI PowerShell module](https://docs.microsoft.com/en-us/powershell/module/configci/?view=win10-ps) remain difficult to work with and do not output relevant objects that would enable tests to be written. Additionally, there is no cmdlet available to recover an XML policy from a binary .p7b/.cip policy.

This module aims to address all of the above problems. While the auditing functionality of this module facilitates building code integrity policies, this module does not aim to automate application control policy configuration methodology. **Use of this module assumes you are already comfortable building WDAC code integrity policies.**

# Available Module Functions

### Usage

Method 1: Import the module manifest directly

```powershell
Import-Module WDACTools.psd1

# View available exported functions
Get-Command -Module WDACTools
```

Method 2: Place the `WDACTools` directory into a desired module path. Upon doing so, module autoloading will automatically load `WDACTools` when one of its functions is executed. The following command will show the available module paths:

```powershell
$Env:PSModulePath -split ';'
```

## New-WDACPolicyConfiguration

Supports: `Configuration`

`New-WDACPolicyConfiguration` is used as a helper function to generate code integrity policy configuration options and to supply them to the `Invoke-WDACCodeIntegrityPolicyBuild` function.

## Invoke-WDACCodeIntegrityPolicyBuild

Supports: `Build`, `Deployment`

`Invoke-WDACCodeIntegrityPolicyBuild` builds and, optionally, deploys and refreshes code integrity policies locally.

## Get-WDACCodeIntegrityEvent

Supports: `Auditing`

`Get-WDACCodeIntegrityEvent` retrieves and parses `Microsoft-Windows-CodeIntegrity/Operational` PE audit and enforcement events into a format that is more human-readable. This function is designed to facilitate regular code integrity policy baselining.

## Get-WDACApplockerScriptMsiEvent

Supports: `Auditing`

`Get-WDACApplockerScriptMsiEvent` retrieves and parses `Microsoft-Windows-AppLocker/MSI and Script` audit and enforcement events into a format that is more human-readable. This function is designed to facilitate regular code integrity policy baselining. Non-PE code that is subject to code integrity enforcement is logged to the `Microsoft-Windows-AppLocker/MSI and Script` log.

## ConvertTo-WDACCodeIntegrityPolicy

Supports: `Auditing`

`ConvertTo-WDACCodeIntegrityPolicy` converts a binary file that contains a Code Integrity policy into XML format. This function is used to audit deployed Code Integrity policies for which the original XML is not present. It can also be used to compare deployed rules against a reference XML file. This function is [`ConvertFrom-CIPolicy`](https://docs.microsoft.com/en-us/powershell/module/configci/convertfrom-cipolicy?view=win10-ps) in reverse.

## Get-WDACCodeIntegrityBinaryPolicyCertificate

Supports: `Auditing`

`Get-WDACCodeIntegrityBinaryPolicyCertificate` obtains signer information from a signed, binary code integrity policy. This function was developed as the result of Get-AuthenticodeSignature not supporting signed, binary code integrity policies. Signed policies are represented as PKCS#7 ASN.1 SignedData (szOID_RSA_signedData - 1.2.840.113549.1.7.2).

# Expected CI Policy Locations

`Invoke-WDACCodeIntegrityPolicyBuild` expects your policies to reside in specific directories included in this repository.

## `BasePolicies` Directory

These are base policies that should rarely change with the exception of relevant policy rule modification (e.g. switching from audit to enforcement mode) and the occasional updating of deny rules in MicrosoftRecommendedBlockRules.xml. Intuitively, deny rules would live as supplemental rules but [deny rules are not honored in supplemental rules](https://web.archive.org/web/20190904022759/https://www.microsoft.com/security/blog/2019/07/01/delivering-major-enhancements-in-windows-defender-application-control-with-the-windows-10-may-2019-update/).

## `SupplementalPolicies` Directory

This is where optional supplemental policies reside. These policies are intended to be updated more frequently whereas the base policies should rarely change.

## `AppSpecificPolicies` Directory

This is where all optional application/vendor-specific policies should reside. For example, if your goal is to allow Google products to execute, a dedicated Google policy should reside here. Having software/vendor-specific policies in here will drastically alleviate the maintenance burden across a complex software landscape. A question that would be expected to arise is, "why can't I just have a ton of app-specific policies as independent supplemental policies?" That's because [Microsoft only supports 32 active CI policies](https://twitter.com/j3ffr3y1974/status/1189235744008802309).

The policies in this directory will be merged together to form `MergedPolicy.xml` in the `BuildArtifacts` directory.

# Recommended CI Policy Format

As the `WDACTools` module was designed to facilitate consistency across all of your policies, it is recommended that your policies have the following characteristics:

1. Each policy have an empty policy rule option element. This would take on the following form:

```xml
<Rules />
```

`WDACTools` is designed to permit supplying policy rule options via code so that consistency is ensured and so that generated policies can be easily tested against expected policy rule options.

2. Policy settings Name and ID fields should be named `REPLACEME`. Doing so, allows you to specify policy names via code. `Invoke-WDACCodeIntegrityPolicyBuild` populates each policy ID with the build date (format: `MM_DD_YYYY`) as a way to simplify auditing.

```xml
<Settings>
  <Setting Provider="PolicyInfo" Key="Information" ValueName="Name">
    <Value>
      <String>REPLACEME</String>
    </Value>
  </Setting>
  <Setting Provider="PolicyInfo" Key="Information" ValueName="Id">
    <Value>
      <String>REPLACEME</String>
    </Value>
  </Setting>
</Settings>
```

# Generated Build Artifacts

When policies are built with `Invoke-WDACCodeIntegrityPolicyBuild`, all generated XML and binary policies are saved to the `BuildArtifacts` directory. `Invoke-WDACCodeIntegrityPolicyBuild` supports an optional `-ArtifactPath` parameter though that allows you to specify an alternate build artifact path.
