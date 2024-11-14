# These are the policy rule options that will be applied to all built policies.
$CommonBasePolicyRuleOptions = @(
    'Enabled:Inherit Default Policy',
    'Enabled:Unsigned System Integrity Policy',
    'Enabled:Advanced Boot Options Menu',
    'Enabled:Update Policy No Reboot',
    'Enabled:Allow Supplemental Policies',
    'Disabled:Flight Signing',
    'Required:WHQL',
    'Enabled:Boot Audit On Failure'
)

# The following specified policies are expected to reside in the "BasePolicies" directory.
$BasePolicyConfigurations = @(
    (New-WDACPolicyConfiguration -BasePolicy -FileName 'BaseDriverPolicy.xml' -PolicyName 'BaseDriverRuleset' -PolicyRuleOptions 'Enabled:Audit Mode'),
    (New-WDACPolicyConfiguration -BasePolicy -FileName 'BaseUserPolicy.xml' -PolicyName 'BaseUserModeRuleset' -PolicyRuleOptions 'Disabled:Script Enforcement', 'Enabled:UMCI', 'Enabled:Audit Mode'),
    (New-WDACPolicyConfiguration -BasePolicy -FileName 'MicrosoftRecommendedBlockRules.xml' -PolicyName 'MicrosoftRecommendedBlockRuleset' -PolicyRuleOptions 'Disabled:Script Enforcement', 'Enabled:UMCI', 'Enabled:Audit Mode')
)

# The following specified policies are expected to reside in the "SupplementalPolicies" directory.
$SupplementalPolicyConfigurations = @(
    (New-WDACPolicyConfiguration -SupplementalPolicy -FileName 'MicrosoftSurfaceDriverPolicy.xml' -PolicyName '3rdPartyDriverRuleset' -PolicyRuleOptions 'Enabled:Audit Mode')
)

# The following configuration implies that the "AppSpecificPolicies" directory is populated with policy XML files that are to be merged.
$MergedPolicyConfiguration = New-WDACPolicyConfiguration -MergedPolicy -PolicyName 'Merged3rdPartySoftwareRuleset' -BasePolicyToSupplement 'BaseUserModeRuleset' -PolicyRuleOptions 'Enabled:Audit Mode'

$CodeIntegrityPoliciesArgs = @{
    CommonBasePolicyRuleOptions     = $CommonBasePolicyRuleOptions
    BasePolicyConfiguration         = $BasePolicyConfigurations
    SupplementalPolicyConfiguration = $SupplementalPolicyConfigurations
    MergedPolicyConfiguration       = $MergedPolicyConfiguration
}

# Upon running this, all generated policy XML and binary .cip files will be stored in the "BuildArtifacts" directory.
Invoke-WDACCodeIntegrityPolicyBuild @CodeIntegrityPoliciesArgs
