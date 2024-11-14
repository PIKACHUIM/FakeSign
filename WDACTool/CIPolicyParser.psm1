function ConvertTo-WDACCodeIntegrityPolicy {
<#
.SYNOPSIS

Converts a binary file that contains a Code Integrity policy into XML format.

Author: Matthew Graeber (@mattifestation)
Contributors: James Forshaw (@tiraniddo) - thanks for the major bug fixes!
License: BSD 3-Clause

Modified to add propert PKCS#7 support and the new DG policy header version.

.DESCRIPTION

ConvertTo-WDACCodeIntegrityPolicy converts a binary file that contains a Code Integrity policy into XML format. This function is used to audit deployed Code Integrity policies for which the original XML is not present. It can also be used to compare deployed rules against a reference XML file.

Note: the process of converting an XML file to a binary policy is lossy. ID, Name, and FriendlyName attributes are all lost in the process. ConvertTo-WDACCodeIntegrityPolicy auto-generates ID and Name properties when necessary.

ConvertTo-WDACCodeIntegrityPolicy supports both signed and unsigned policies.

.PARAMETER BinaryFilePath

Specifies the path of the binary policy file that this cmdlet converts. Deployed binary policy files are located in %SystemRoot%\System32\CodeIntegrity\SIPolicy.p7b.

.PARAMETER XmlFilePath

Specifies the path for the output converted policy XML file.

.EXAMPLE

ConvertTo-WDACCodeIntegrityPolicy -BinaryFilePath C:\Windows\System32\CodeIntegrity\SIPolicy.p7b -XmlFilePath recovered_policy.xml

.OUTPUTS

System.IO.FileInfo

Outputs a recovered Code Integrity policy XML file.
#>

    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter(Position = 0, Mandatory)]
        [String]
        [ValidateScript({ [IO.File]::Exists((Resolve-Path $_).Path) })]
        $BinaryFilePath,

        [Parameter(Position = 1, Mandatory)]
        [String]
        [ValidateNotNullOrEmpty()]
        $XmlFilePath
    )

    Set-StrictMode -Version Latest

    $CorruptPolicyErr = 'The CI policy may be corrupt.'

    $HeaderLengthMax = 0x44
    $GuidLength = 0x10

    # Generated code that enables CI policy XML serialization.
    $TypeDef = @'
    using System.Xml.Serialization;

    namespace CodeIntegrity {
        [System.FlagsAttribute()]
        public enum PolicyRules {
            EnabledUMCI =                                     0x00000004,
            EnabledBootMenuProtection =                       0x00000008,
            EnabledIntelligentSecurityGraphAuthorization =    0x00000010,
            EnabledInvalidateEAsonReboot =                    0x00000020,
            EnabledWindowsLockdownTrialMode =                 0x00000040,
            RequiredWHQL =                                    0x00000080,
            EnabledDeveloperModeDynamicCodeTrust =            0x00000100,
            EnabledAllowSupplementalPolicies =                0x00000400,
            DisabledRuntimeFilePathRuleProtection =           0x00000800,
            EnabledRevokedExpiredAsUnsigned =                 0x00002000,
            EnabledAuditMode =                                0x00010000,
            DisabledFlightSigning =                           0x00020000,
            EnabledInheritDefaultPolicy =                     0x00040000,
            EnabledUnsignedSystemIntegrityPolicy =            0x00080000,
            EnabledDynamicCodeSecurity =                      0x00100000,
            RequiredEVSigners =                               0x00200000,
            EnabledBootAuditOnFailure =                       0x00400000,
            EnabledAdvancedBootOptionsMenu =                  0x00800000,
            DisabledScriptEnforcement =                       0x01000000,
            RequiredEnforceStoreApplications =                0x02000000,
            EnabledSecureSettingPolicy =                      0x04000000,
            EnabledManagedInstaller =                         0x08000000,
            EnabledUpdatePolicyNoReboot =                     0x10000000,
            EnabledConditionalWindowsLockdownPolicy =         0x20000000
        }

        // The following code was generated with: xsd.exe C:\Windows\schemas\CodeIntegrity\cipolicy.xsd /classes /namespace:CodeIntegrity

        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class Macros {

            private MacrosMacro[] macroField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("Macro")]
            public MacrosMacro[] Macro {
                get {
                    return this.macroField;
                }
                set {
                    this.macroField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        public partial class MacrosMacro {

            private string idField;

            private string valueField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string Id {
                get {
                    return this.idField;
                }
                set {
                    this.idField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string Value {
                get {
                    return this.valueField;
                }
                set {
                    this.valueField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(Namespace="urn:schemas-microsoft-com:sipolicy")]
        public partial class RuleType {

            private OptionType itemField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("Option")]
            public OptionType Item {
                get {
                    return this.itemField;
                }
                set {
                    this.itemField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Xml.Serialization.XmlTypeAttribute(Namespace="urn:schemas-microsoft-com:sipolicy")]
        public enum OptionType {

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:UMCI")]
            EnabledUMCI,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Boot Menu Protection")]
            EnabledBootMenuProtection,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Intelligent Security Graph Authorization")]
            EnabledIntelligentSecurityGraphAuthorization,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Invalidate EAs on Reboot")]
            EnabledInvalidateEAsonReboot,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Windows Lockdown Trial Mode")]
            EnabledWindowsLockdownTrialMode,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Required:WHQL")]
            RequiredWHQL,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Developer Mode Dynamic Code Trust")]
            EnabledDeveloperModeDynamicCodeTrust,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Allow Supplemental Policies")]
            EnabledAllowSupplementalPolicies,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Disabled:Runtime FilePath Rule Protection")]
            DisabledRuntimeFilePathRuleProtection,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Revoked Expired As Unsigned")]
            EnabledRevokedExpiredAsUnsigned,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Audit Mode")]
            EnabledAuditMode,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Disabled:Flight Signing")]
            DisabledFlightSigning,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Inherit Default Policy")]
            EnabledInheritDefaultPolicy,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Unsigned System Integrity Policy")]
            EnabledUnsignedSystemIntegrityPolicy,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Dynamic Code Security")]
            EnabledDynamicCodeSecurity,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Required:EV Signers")]
            RequiredEVSigners,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Boot Audit On Failure")]
            EnabledBootAuditOnFailure,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Advanced Boot Options Menu")]
            EnabledAdvancedBootOptionsMenu,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Disabled:Script Enforcement")]
            DisabledScriptEnforcement,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Required:Enforce Store Applications")]
            RequiredEnforceStoreApplications,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Secure Setting Policy")]
            EnabledSecureSettingPolicy,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Managed Installer")]
            EnabledManagedInstaller,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Update Policy No Reboot")]
            EnabledUpdatePolicyNoReboot,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Enabled:Conditional Windows Lockdown Policy")]
            EnabledConditionalWindowsLockdownPolicy,
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(Namespace="urn:schemas-microsoft-com:sipolicy")]
        public partial class SettingValueType {

            private object itemField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("Binary", typeof(byte[]), DataType="hexBinary")]
            [System.Xml.Serialization.XmlElementAttribute("Boolean", typeof(bool))]
            [System.Xml.Serialization.XmlElementAttribute("DWord", typeof(uint))]
            [System.Xml.Serialization.XmlElementAttribute("String", typeof(string))]
            public object Item {
                get {
                    return this.itemField;
                }
                set {
                    this.itemField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class Setting {

            private SettingValueType valueField;

            private string providerField;

            private string keyField;

            private string valueNameField;

            /// <remarks/>
            public SettingValueType Value {
                get {
                    return this.valueField;
                }
                set {
                    this.valueField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string Provider {
                get {
                    return this.providerField;
                }
                set {
                    this.providerField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string Key {
                get {
                    return this.keyField;
                }
                set {
                    this.keyField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string ValueName {
                get {
                    return this.valueNameField;
                }
                set {
                    this.valueNameField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class Settings {

            private Setting[] itemsField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("Setting")]
            public Setting[] Items {
                get {
                    return this.itemsField;
                }
                set {
                    this.itemsField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class CertEKU {

            private string idField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string ID {
                get {
                    return this.idField;
                }
                set {
                    this.idField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class CertOemID {

            private string valueField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string Value {
                get {
                    return this.valueField;
                }
                set {
                    this.valueField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class CertPublisher {

            private string valueField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string Value {
                get {
                    return this.valueField;
                }
                set {
                    this.valueField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class CertIssuer {

            private string valueField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string Value {
                get {
                    return this.valueField;
                }
                set {
                    this.valueField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class CertRoot {

            private CertEnumType typeField;

            private byte[] valueField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public CertEnumType Type {
                get {
                    return this.typeField;
                }
                set {
                    this.typeField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute(DataType="hexBinary")]
            public byte[] Value {
                get {
                    return this.valueField;
                }
                set {
                    this.valueField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Xml.Serialization.XmlTypeAttribute(Namespace="urn:schemas-microsoft-com:sipolicy")]
        public enum CertEnumType {

            /// <remarks/>
            TBS,

            /// <remarks/>
            Wellknown,
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class ProductSigners {

            private AllowedSigners allowedSignersField;

            private DeniedSigners deniedSignersField;

            private FileRulesRef fileRulesRefField;

            /// <remarks/>
            public AllowedSigners AllowedSigners {
                get {
                    return this.allowedSignersField;
                }
                set {
                    this.allowedSignersField = value;
                }
            }

            /// <remarks/>
            public DeniedSigners DeniedSigners {
                get {
                    return this.deniedSignersField;
                }
                set {
                    this.deniedSignersField = value;
                }
            }

            /// <remarks/>
            public FileRulesRef FileRulesRef {
                get {
                    return this.fileRulesRefField;
                }
                set {
                    this.fileRulesRefField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class AllowedSigners {

            private AllowedSigner[] allowedSignerField;

            private string workaroundField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("AllowedSigner")]
            public AllowedSigner[] AllowedSigner {
                get {
                    return this.allowedSignerField;
                }
                set {
                    this.allowedSignerField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string Workaround {
                get {
                    return this.workaroundField;
                }
                set {
                    this.workaroundField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class AllowedSigner {

            private ExceptDenyRule[] exceptDenyRuleField;

            private string signerIdField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("ExceptDenyRule")]
            public ExceptDenyRule[] ExceptDenyRule {
                get {
                    return this.exceptDenyRuleField;
                }
                set {
                    this.exceptDenyRuleField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string SignerId {
                get {
                    return this.signerIdField;
                }
                set {
                    this.signerIdField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class ExceptDenyRule {

            private string denyRuleIDField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string DenyRuleID {
                get {
                    return this.denyRuleIDField;
                }
                set {
                    this.denyRuleIDField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class DeniedSigners {

            private DeniedSigner[] deniedSignerField;

            private string workaroundField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("DeniedSigner")]
            public DeniedSigner[] DeniedSigner {
                get {
                    return this.deniedSignerField;
                }
                set {
                    this.deniedSignerField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string Workaround {
                get {
                    return this.workaroundField;
                }
                set {
                    this.workaroundField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class DeniedSigner {

            private ExceptAllowRule[] exceptAllowRuleField;

            private string signerIdField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("ExceptAllowRule")]
            public ExceptAllowRule[] ExceptAllowRule {
                get {
                    return this.exceptAllowRuleField;
                }
                set {
                    this.exceptAllowRuleField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string SignerId {
                get {
                    return this.signerIdField;
                }
                set {
                    this.signerIdField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class ExceptAllowRule {

            private string allowRuleIDField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string AllowRuleID {
                get {
                    return this.allowRuleIDField;
                }
                set {
                    this.allowRuleIDField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class FileRulesRef {

            private FileRuleRef[] fileRuleRefField;

            private string workaroundField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("FileRuleRef")]
            public FileRuleRef[] FileRuleRef {
                get {
                    return this.fileRuleRefField;
                }
                set {
                    this.fileRuleRefField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string Workaround {
                get {
                    return this.workaroundField;
                }
                set {
                    this.workaroundField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class FileRuleRef {

            private string ruleIDField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string RuleID {
                get {
                    return this.ruleIDField;
                }
                set {
                    this.ruleIDField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class TestSigners {

            private AllowedSigners allowedSignersField;

            private DeniedSigners deniedSignersField;

            private FileRulesRef fileRulesRefField;

            /// <remarks/>
            public AllowedSigners AllowedSigners {
                get {
                    return this.allowedSignersField;
                }
                set {
                    this.allowedSignersField = value;
                }
            }

            /// <remarks/>
            public DeniedSigners DeniedSigners {
                get {
                    return this.deniedSignersField;
                }
                set {
                    this.deniedSignersField = value;
                }
            }

            /// <remarks/>
            public FileRulesRef FileRulesRef {
                get {
                    return this.fileRulesRefField;
                }
                set {
                    this.fileRulesRefField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class TestSigningSigners {

            private AllowedSigners allowedSignersField;

            private DeniedSigners deniedSignersField;

            private FileRulesRef fileRulesRefField;

            /// <remarks/>
            public AllowedSigners AllowedSigners {
                get {
                    return this.allowedSignersField;
                }
                set {
                    this.allowedSignersField = value;
                }
            }

            /// <remarks/>
            public DeniedSigners DeniedSigners {
                get {
                    return this.deniedSignersField;
                }
                set {
                    this.deniedSignersField = value;
                }
            }

            /// <remarks/>
            public FileRulesRef FileRulesRef {
                get {
                    return this.fileRulesRefField;
                }
                set {
                    this.fileRulesRefField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class FileAttribRef {

            private string ruleIDField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string RuleID {
                get {
                    return this.ruleIDField;
                }
                set {
                    this.ruleIDField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class EKUs {

            private EKU[] itemsField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("EKU")]
            public EKU[] Items {
                get {
                    return this.itemsField;
                }
                set {
                    this.itemsField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class EKU {

            private string idField;

            private byte[] valueField;

            private string friendlyNameField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string ID {
                get {
                    return this.idField;
                }
                set {
                    this.idField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute(DataType="hexBinary")]
            public byte[] Value {
                get {
                    return this.valueField;
                }
                set {
                    this.valueField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FriendlyName {
                get {
                    return this.friendlyNameField;
                }
                set {
                    this.friendlyNameField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class FileRules {

            private object[] itemsField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("Allow", typeof(Allow))]
            [System.Xml.Serialization.XmlElementAttribute("Deny", typeof(Deny))]
            [System.Xml.Serialization.XmlElementAttribute("FileAttrib", typeof(FileAttrib))]
            public object[] Items {
                get {
                    return this.itemsField;
                }
                set {
                    this.itemsField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class Allow {

            private string idField;

            private string friendlyNameField;

            private string fileNameField;

            private string internalNameField;

            private string fileDescriptionField;

            private string productNameField;

            private string packageFamilyNameField;

            private string packageVersionField;

            private string minimumFileVersionField;

            private string maximumFileVersionField;

            private byte[] hashField;

            private string appIDsField;

            private string filePathField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string ID {
                get {
                    return this.idField;
                }
                set {
                    this.idField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FriendlyName {
                get {
                    return this.friendlyNameField;
                }
                set {
                    this.friendlyNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FileName {
                get {
                    return this.fileNameField;
                }
                set {
                    this.fileNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string InternalName {
                get {
                    return this.internalNameField;
                }
                set {
                    this.internalNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FileDescription {
                get {
                    return this.fileDescriptionField;
                }
                set {
                    this.fileDescriptionField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string ProductName {
                get {
                    return this.productNameField;
                }
                set {
                    this.productNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string PackageFamilyName {
                get {
                    return this.packageFamilyNameField;
                }
                set {
                    this.packageFamilyNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string PackageVersion {
                get {
                    return this.packageVersionField;
                }
                set {
                    this.packageVersionField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string MinimumFileVersion {
                get {
                    return this.minimumFileVersionField;
                }
                set {
                    this.minimumFileVersionField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string MaximumFileVersion {
                get {
                    return this.maximumFileVersionField;
                }
                set {
                    this.maximumFileVersionField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute(DataType="hexBinary")]
            public byte[] Hash {
                get {
                    return this.hashField;
                }
                set {
                    this.hashField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string AppIDs {
                get {
                    return this.appIDsField;
                }
                set {
                    this.appIDsField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FilePath {
                get {
                    return this.filePathField;
                }
                set {
                    this.filePathField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class Deny {

            private string idField;

            private string friendlyNameField;

            private string fileNameField;

            private string internalNameField;

            private string fileDescriptionField;

            private string productNameField;

            private string packageFamilyNameField;

            private string packageVersionField;

            private string minimumFileVersionField;

            private string maximumFileVersionField;

            private byte[] hashField;

            private string appIDsField;

            private string filePathField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string ID {
                get {
                    return this.idField;
                }
                set {
                    this.idField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FriendlyName {
                get {
                    return this.friendlyNameField;
                }
                set {
                    this.friendlyNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FileName {
                get {
                    return this.fileNameField;
                }
                set {
                    this.fileNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string InternalName {
                get {
                    return this.internalNameField;
                }
                set {
                    this.internalNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FileDescription {
                get {
                    return this.fileDescriptionField;
                }
                set {
                    this.fileDescriptionField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string ProductName {
                get {
                    return this.productNameField;
                }
                set {
                    this.productNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string PackageFamilyName {
                get {
                    return this.packageFamilyNameField;
                }
                set {
                    this.packageFamilyNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string PackageVersion {
                get {
                    return this.packageVersionField;
                }
                set {
                    this.packageVersionField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string MinimumFileVersion {
                get {
                    return this.minimumFileVersionField;
                }
                set {
                    this.minimumFileVersionField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string MaximumFileVersion {
                get {
                    return this.maximumFileVersionField;
                }
                set {
                    this.maximumFileVersionField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute(DataType="hexBinary")]
            public byte[] Hash {
                get {
                    return this.hashField;
                }
                set {
                    this.hashField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string AppIDs {
                get {
                    return this.appIDsField;
                }
                set {
                    this.appIDsField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FilePath {
                get {
                    return this.filePathField;
                }
                set {
                    this.filePathField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class FileAttrib {

            private string idField;

            private string friendlyNameField;

            private string fileNameField;

            private string internalNameField;

            private string fileDescriptionField;

            private string productNameField;

            private string packageFamilyNameField;

            private string packageVersionField;

            private string minimumFileVersionField;

            private string maximumFileVersionField;

            private byte[] hashField;

            private string appIDsField;

            private string filePathField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string ID {
                get {
                    return this.idField;
                }
                set {
                    this.idField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FriendlyName {
                get {
                    return this.friendlyNameField;
                }
                set {
                    this.friendlyNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FileName {
                get {
                    return this.fileNameField;
                }
                set {
                    this.fileNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string InternalName {
                get {
                    return this.internalNameField;
                }
                set {
                    this.internalNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FileDescription {
                get {
                    return this.fileDescriptionField;
                }
                set {
                    this.fileDescriptionField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string ProductName {
                get {
                    return this.productNameField;
                }
                set {
                    this.productNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string PackageFamilyName {
                get {
                    return this.packageFamilyNameField;
                }
                set {
                    this.packageFamilyNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string PackageVersion {
                get {
                    return this.packageVersionField;
                }
                set {
                    this.packageVersionField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string MinimumFileVersion {
                get {
                    return this.minimumFileVersionField;
                }
                set {
                    this.minimumFileVersionField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string MaximumFileVersion {
                get {
                    return this.maximumFileVersionField;
                }
                set {
                    this.maximumFileVersionField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute(DataType="hexBinary")]
            public byte[] Hash {
                get {
                    return this.hashField;
                }
                set {
                    this.hashField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string AppIDs {
                get {
                    return this.appIDsField;
                }
                set {
                    this.appIDsField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FilePath {
                get {
                    return this.filePathField;
                }
                set {
                    this.filePathField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class UpdatePolicySigner {

            private string signerIdField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string SignerId {
                get {
                    return this.signerIdField;
                }
                set {
                    this.signerIdField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class UpdatePolicySigners {

            private UpdatePolicySigner[] itemsField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("UpdatePolicySigner")]
            public UpdatePolicySigner[] Items {
                get {
                    return this.itemsField;
                }
                set {
                    this.itemsField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class SupplementalPolicySigner {

            private string signerIdField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string SignerId {
                get {
                    return this.signerIdField;
                }
                set {
                    this.signerIdField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class SupplementalPolicySigners {

            private SupplementalPolicySigner[] itemsField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("SupplementalPolicySigner")]
            public SupplementalPolicySigner[] Items {
                get {
                    return this.itemsField;
                }
                set {
                    this.itemsField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class CiSigner {

            private string signerIdField;

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string SignerId {
                get {
                    return this.signerIdField;
                }
                set {
                    this.signerIdField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class CiSigners {

            private CiSigner[] itemsField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("CiSigner")]
            public CiSigner[] Items {
                get {
                    return this.itemsField;
                }
                set {
                    this.itemsField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class Signers {

            private Signer[] itemsField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("Signer")]
            public Signer[] Items {
                get {
                    return this.itemsField;
                }
                set {
                    this.itemsField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class Signer {

            private CertRoot certRootField;

            private CertEKU[] certEKUField;

            private CertIssuer certIssuerField;

            private CertPublisher certPublisherField;

            private CertOemID certOemIDField;

            private FileAttribRef[] fileAttribRefField;

            private string nameField;

            private string idField;

            private System.DateTime signTimeAfterField;

            private bool signTimeAfterFieldSpecified;

            /// <remarks/>
            public CertRoot CertRoot {
                get {
                    return this.certRootField;
                }
                set {
                    this.certRootField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("CertEKU")]
            public CertEKU[] CertEKU {
                get {
                    return this.certEKUField;
                }
                set {
                    this.certEKUField = value;
                }
            }

            /// <remarks/>
            public CertIssuer CertIssuer {
                get {
                    return this.certIssuerField;
                }
                set {
                    this.certIssuerField = value;
                }
            }

            /// <remarks/>
            public CertPublisher CertPublisher {
                get {
                    return this.certPublisherField;
                }
                set {
                    this.certPublisherField = value;
                }
            }

            /// <remarks/>
            public CertOemID CertOemID {
                get {
                    return this.certOemIDField;
                }
                set {
                    this.certOemIDField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("FileAttribRef")]
            public FileAttribRef[] FileAttribRef {
                get {
                    return this.fileAttribRefField;
                }
                set {
                    this.fileAttribRefField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string Name {
                get {
                    return this.nameField;
                }
                set {
                    this.nameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string ID {
                get {
                    return this.idField;
                }
                set {
                    this.idField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public System.DateTime SignTimeAfter {
                get {
                    return this.signTimeAfterField;
                }
                set {
                    this.signTimeAfterField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlIgnoreAttribute()]
            public bool SignTimeAfterSpecified {
                get {
                    return this.signTimeAfterFieldSpecified;
                }
                set {
                    this.signTimeAfterFieldSpecified = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class SigningScenarios {

            private SigningScenario[] itemsField;

            /// <remarks/>
            [System.Xml.Serialization.XmlElementAttribute("SigningScenario")]
            public SigningScenario[] Items {
                get {
                    return this.itemsField;
                }
                set {
                    this.itemsField = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class SigningScenario {

            private ProductSigners productSignersField;

            private TestSigners testSignersField;

            private TestSigningSigners testSigningSignersField;

            private string idField;

            private string friendlyNameField;

            private byte valueField;

            private string inheritedScenariosField;

            private ushort minimumHashAlgorithmField;

            private bool minimumHashAlgorithmFieldSpecified;

            /// <remarks/>
            public ProductSigners ProductSigners {
                get {
                    return this.productSignersField;
                }
                set {
                    this.productSignersField = value;
                }
            }

            /// <remarks/>
            public TestSigners TestSigners {
                get {
                    return this.testSignersField;
                }
                set {
                    this.testSignersField = value;
                }
            }

            /// <remarks/>
            public TestSigningSigners TestSigningSigners {
                get {
                    return this.testSigningSignersField;
                }
                set {
                    this.testSigningSignersField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string ID {
                get {
                    return this.idField;
                }
                set {
                    this.idField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FriendlyName {
                get {
                    return this.friendlyNameField;
                }
                set {
                    this.friendlyNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public byte Value {
                get {
                    return this.valueField;
                }
                set {
                    this.valueField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string InheritedScenarios {
                get {
                    return this.inheritedScenariosField;
                }
                set {
                    this.inheritedScenariosField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public ushort MinimumHashAlgorithm {
                get {
                    return this.minimumHashAlgorithmField;
                }
                set {
                    this.minimumHashAlgorithmField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlIgnoreAttribute()]
            public bool MinimumHashAlgorithmSpecified {
                get {
                    return this.minimumHashAlgorithmFieldSpecified;
                }
                set {
                    this.minimumHashAlgorithmFieldSpecified = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Diagnostics.DebuggerStepThroughAttribute()]
        [System.ComponentModel.DesignerCategoryAttribute("code")]
        [System.Xml.Serialization.XmlTypeAttribute(AnonymousType=true, Namespace="urn:schemas-microsoft-com:sipolicy")]
        [System.Xml.Serialization.XmlRootAttribute(Namespace="urn:schemas-microsoft-com:sipolicy", IsNullable=false)]
        public partial class SiPolicy {

            private string versionExField;

            private string policyTypeIDField;

            private string platformIDField;

            private string policyIDField;

            private string basePolicyIDField;

            private RuleType[] rulesField;

            private EKU[] eKUsField;

            private object[] fileRulesField;

            private Signer[] signersField;

            private SigningScenario[] signingScenariosField;

            private UpdatePolicySigner[] updatePolicySignersField;

            private CiSigner[] ciSignersField;

            private uint hvciOptionsField;

            private bool hvciOptionsFieldSpecified;

            private Setting[] settingsField;

            private MacrosMacro[] macrosField;

            private SupplementalPolicySigner[] supplementalPolicySignersField;

            private string friendlyNameField;

            private PolicyType policyTypeField;

            private bool policyTypeFieldSpecified;

            /// <remarks/>
            public string VersionEx {
                get {
                    return this.versionExField;
                }
                set {
                    this.versionExField = value;
                }
            }

            /// <remarks/>
            public string PolicyTypeID {
                get {
                    return this.policyTypeIDField;
                }
                set {
                    this.policyTypeIDField = value;
                }
            }

            /// <remarks/>
            public string PlatformID {
                get {
                    return this.platformIDField;
                }
                set {
                    this.platformIDField = value;
                }
            }

            /// <remarks/>
            public string PolicyID {
                get {
                    return this.policyIDField;
                }
                set {
                    this.policyIDField = value;
                }
            }

            /// <remarks/>
            public string BasePolicyID {
                get {
                    return this.basePolicyIDField;
                }
                set {
                    this.basePolicyIDField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlArrayItemAttribute("Rule", IsNullable=false)]
            public RuleType[] Rules {
                get {
                    return this.rulesField;
                }
                set {
                    this.rulesField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlArrayItemAttribute("EKU", IsNullable=false)]
            public EKU[] EKUs {
                get {
                    return this.eKUsField;
                }
                set {
                    this.eKUsField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlArrayItemAttribute("Allow", typeof(Allow), IsNullable=false)]
            [System.Xml.Serialization.XmlArrayItemAttribute("Deny", typeof(Deny), IsNullable=false)]
            [System.Xml.Serialization.XmlArrayItemAttribute("FileAttrib", typeof(FileAttrib), IsNullable=false)]
            public object[] FileRules {
                get {
                    return this.fileRulesField;
                }
                set {
                    this.fileRulesField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlArrayItemAttribute("Signer", IsNullable=false)]
            public Signer[] Signers {
                get {
                    return this.signersField;
                }
                set {
                    this.signersField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlArrayItemAttribute("SigningScenario", IsNullable=false)]
            public SigningScenario[] SigningScenarios {
                get {
                    return this.signingScenariosField;
                }
                set {
                    this.signingScenariosField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlArrayItemAttribute("UpdatePolicySigner", IsNullable=false)]
            public UpdatePolicySigner[] UpdatePolicySigners {
                get {
                    return this.updatePolicySignersField;
                }
                set {
                    this.updatePolicySignersField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlArrayItemAttribute("CiSigner", IsNullable=false)]
            public CiSigner[] CiSigners {
                get {
                    return this.ciSignersField;
                }
                set {
                    this.ciSignersField = value;
                }
            }

            /// <remarks/>
            public uint HvciOptions {
                get {
                    return this.hvciOptionsField;
                }
                set {
                    this.hvciOptionsField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlIgnoreAttribute()]
            public bool HvciOptionsSpecified {
                get {
                    return this.hvciOptionsFieldSpecified;
                }
                set {
                    this.hvciOptionsFieldSpecified = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlArrayItemAttribute("Setting", IsNullable=false)]
            public Setting[] Settings {
                get {
                    return this.settingsField;
                }
                set {
                    this.settingsField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlArrayItemAttribute("Macro", IsNullable=false)]
            public MacrosMacro[] Macros {
                get {
                    return this.macrosField;
                }
                set {
                    this.macrosField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlArrayItemAttribute("SupplementalPolicySigner", IsNullable=false)]
            public SupplementalPolicySigner[] SupplementalPolicySigners {
                get {
                    return this.supplementalPolicySignersField;
                }
                set {
                    this.supplementalPolicySignersField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public string FriendlyName {
                get {
                    return this.friendlyNameField;
                }
                set {
                    this.friendlyNameField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlAttributeAttribute()]
            public PolicyType PolicyType {
                get {
                    return this.policyTypeField;
                }
                set {
                    this.policyTypeField = value;
                }
            }

            /// <remarks/>
            [System.Xml.Serialization.XmlIgnoreAttribute()]
            public bool PolicyTypeSpecified {
                get {
                    return this.policyTypeFieldSpecified;
                }
                set {
                    this.policyTypeFieldSpecified = value;
                }
            }
        }

        /// <remarks/>
        [System.CodeDom.Compiler.GeneratedCodeAttribute("xsd", "4.8.3698.0")]
        [System.SerializableAttribute()]
        [System.Xml.Serialization.XmlTypeAttribute(Namespace="urn:schemas-microsoft-com:sipolicy")]
        public enum PolicyType {

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Base Policy")]
            BasePolicy,

            /// <remarks/>
            [System.Xml.Serialization.XmlEnumAttribute("Supplemental Policy")]
            SupplementalPolicy,
        }
    }
'@

    if (-not ('CodeIntegrity.SIPolicy' -as [Type])) {
        Add-Type -TypeDefinition $TypeDef -ReferencedAssemblies 'System.Xml'
    }

    function ConvertTo-Oid {
    <#
    .SYNOPSIS

    Decodes a DER encoded ASN.1 object identifier (OID)

    .DESCRIPTION

    ConvertTo-Oid decodes a DER encoded ASN.1 object identifier (OID). This can be used as a helper function for binary certificate parsers.

    .PARAMETER EncodedOIDBytes

    Specifies the bytes of an absolute (starts with 6), encoded OID.

    .EXAMPLE

    ConvertTo-Oid -EncodedOIDBytes @(0x06, 0x0A, 0x2B, 0x06, 0x01, 0x04, 0x01, 0x82, 0x37, 0x0A, 0x03, 0x05)

    .OUTPUTS

    System.Security.Cryptography.Oid

    ConvertTo-Oid outputs an OID object representing the decoded OID.
    #>

        [OutputType([System.Security.Cryptography.Oid])]
        param (
            [Parameter(Mandatory = $True, Position = 0)]
            [Byte[]]
            [ValidateNotNullOrEmpty()]
            $EncodedOIDBytes
        )

        # This only handles absolute encoded OIDs - those that start with 6.
        # [Security.Cryptography.CryptoConfig]::EncodeOID only handles absolute OIDs.

        # This article describes the OID encoding/decoding process:
        # https://msdn.microsoft.com/en-us/library/windows/desktop/bb540809(v=vs.85).aspx

        if (($EncodedOIDBytes.Length -lt 2) -or ($EncodedOIDBytes[1] -ne ($EncodedOIDBytes.Length - 2))) {
            throw 'Invalid encoded EKU OID value.'
        }

        $OIDComponents = New-Object -TypeName 'System.Collections.Generic.List[Int]'

        $SecondComponent = $EncodedOIDBytes[2] % 40
        $FirstComponent = ($EncodedOIDBytes[2] - $SecondComponent) / 40

        $OIDComponents.Add($FirstComponent)
        $OIDComponents.Add($SecondComponent)

        $i = 3

        while ($i -lt $EncodedOIDBytes.Length) {
            if (-not ($EncodedOIDBytes[$i] -band 0x80)) {
                # It is just singlebyte encoded
                $OIDComponents.Add($EncodedOIDBytes[$i])
                $i++
            } else {
                # It is either two or three byte encoded
                $Byte1 = ($EncodedOIDBytes[$i] -shl 1) -shr 1 # Strip the high bit
                $Byte2 = $EncodedOIDBytes[$i+1]

                if ($Byte2 -band 0x80) {
                    # three byte encoded
                    $Byte3 = $EncodedOIDBytes[$i+2]
                    $i += 3

                    $Byte2 = $Byte2 -band 0x7F
                    if ($Byte2 -band 1) { $Byte3 = $Byte3 -bor 0x80 }
                    if ($Byte1 -band 1) { $Byte2 = $Byte2 -bor 0x80 }
                    $Byte2 = $Byte2 -shr 1
                    $Byte1 = $Byte1 -shr 1
                    if ($Byte2 -band 1) { $Byte2 = $Byte2 -bor 0x80 }
                    $Byte1 = $Byte1 -shr 1

                    $OIDComponents.Add([BitConverter]::ToInt32(@($Byte3, $Byte2, $Byte1, 0), 0))
                } else {
                    # two byte encoded
                    $i +=2

                    # "Shift" the low bit from the high byte to the high bit of the low byte
                    if ($Byte1 -band 1) { $Byte2 -bor 0x80 }
                    $Byte1 = $Byte1 -shr 1

                    $OIDComponents.Add([BitConverter]::ToInt16(@($Byte2, $Byte1), 0))
                }
            }
        }

        [Security.Cryptography.Oid] ($OIDComponents -join '.')
    }

    # Helper function to read strings from the binary
    function Get-BinaryString {
        [OutputType('String')]
        param (
            [Parameter(Mandatory)]
            [IO.BinaryReader]
            [ValidateNotNullOrEmpty()]
            $BinaryReader
        )

        $StringLength = $BinaryReader.ReadUInt32()

        if ($StringLength) {
            $PaddingBytes = 4 - $StringLength % 4 -band 3

            $StringBytes = $BinaryReader.ReadBytes($StringLength)
            $null = $BinaryReader.ReadBytes($PaddingBytes)

            [Text.Encoding]::Unicode.GetString($StringBytes)
        }

        $null = $BinaryReader.ReadInt32()
    }

    # Obtain the full path to the policy file if a relative path was provided.
    $BinPath = Resolve-Path $BinaryFilePath

    $XmlPathDir = Split-Path -Path $XmlFilePath -Parent
    $XmlPathFile = Split-Path -Path $XmlFilePath -Leaf

    if (-not $XmlPathDir) {
        $XmlPathDir = $PWD
    }

    $ResolvedDir = Resolve-Path -Path $XmlPathDir

    if (-not [System.IO.Directory]::Exists($ResolvedDir.Path)) {
        throw "Cannot find path '$ResolvedDir' because it does not exist."
        return
    }

    $FullXmlPath = Join-Path -Path $ResolvedDir -ChildPath $XmlPathFile

    try {
        $CIPolicyBytes = [IO.File]::ReadAllBytes($BinPath.Path)

        try {
            try {
                $ContentType = [Security.Cryptography.Pkcs.ContentInfo]::GetContentType($CIPolicyBytes)
            } catch {
                $ContentType = $null
            }

            # Check for PKCS#7 ASN.1 SignedData type
            if ($ContentType -and $ContentType.Value -eq '1.2.840.113549.1.7.2') {
              $Cms = New-Object System.Security.Cryptography.Pkcs.SignedCms
              $Cms.Decode($CIPolicyBytes)
              $CIPolicyBytes = $Cms.ContentInfo.Content
              if ($CIPolicyBytes[0] -eq 4) {
                # Policy is stored as an OCTET STRING
                $PolicySize = $CIPolicyBytes[1]
                $BaseIndex = 2
                if (($PolicySize -band 0x80) -eq 0x80) {
                    $SizeCount = $PolicySize -band 0x7F
                    $BaseIndex += $SizeCount
                    $PolicySize = 0
                    for ($i = 0; $i -lt $SizeCount; $i++) {
                        $PolicySize = $PolicySize -shl 8
                        $PolicySize = $PolicySize -bor $CIPolicyBytes[2 + $i]
                    }
                }

                $CIPolicyBytes = $CIPolicyBytes[$BaseIndex..($BaseIndex + $PolicySize - 1)]
              }
            }
        } catch {
            Write-Output $_
        }

        $MemoryStream = New-Object -TypeName IO.MemoryStream -ArgumentList @(,$CIPolicyBytes)
        $BinaryReader = New-Object -TypeName System.IO.BinaryReader -ArgumentList $MemoryStream, ([Text.Encoding]::Unicode)
    } catch {
        throw $_
        return
    }

    $SIPolicy = New-Object -TypeName CodeIntegrity.SIPolicy

    try {
        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): CI Policy Format Version"

        # Validate binary CI policy header
        # This header value indicates likely indicates the schema version that was used.
        # This script will only support whatever the latest schema version was at the time of last update, in this case, 7.
        $CIPolicyFormatVersion = $BinaryReader.ReadInt32()

        # My inference is that the binary format will terminate with a UInt32 value that is $CIPolicyFormatVersion + 1.
        # For example, if $CIPolicyFormatVersion is 7, the binary policy is expected to be terminated with 0x00000008.
        # This way, should the following warning be presented, should a format version of 8 be introduced, I will know that
        # there will be binary data in need of parsing beyond 0x00000008.

        if ($CIPolicyFormatVersion -gt 7) {
            Write-Warning "$BinPath has an invalid or unsupported binary CI policy format version value: 0x$($CIPolicyFormatVersion.ToString('X8')). If you are sure that you are dealing with a binary code integrity policy, there is a high liklihood that Microsoft updated the binary file for mat to support new schema elements and that this code will likely need to be updated."
        }

        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): PolicyTypeID"

        $PolicyTypeID = [Guid][Byte[]] $BinaryReader.ReadBytes($GuidLength)

        # The policy type ID can be used to determine the intended purpose of the CI policy
        switch ($PolicyTypeID.Guid) {
            'a244370e-44c9-4c06-b551-f6016e563076' { Write-Verbose "PolicyTypeID: {$PolicyTypeID} - Enterprise Code Integrity Policy (SiPolicy.p7b or UpdateSiPolicy.p7b)" }
            '2a5a0136-f09f-498e-99cc-51099011157c' { Write-Verbose "PolicyTypeID: {$PolicyTypeID} - Windows Revoke Code Integrity Policy (RvkSiPolicy.p7b or UpdateRvkSiPolicy.p7b)" }
            '976d12c8-cb9f-4730-be52-54600843238e' { Write-Verbose "PolicyTypeID: {$PolicyTypeID} - SKU Code Integrity Policy (SkuSiPolicy.p7b or UpdateSkuSiPolicy.p7b)" }
            '5951a96a-e0b5-4d3d-8fb8-3e5b61030784' { Write-Verbose "PolicyTypeID: {$PolicyTypeID} - Windows Lockdown (S-Mode) Code Integrity Policy (WinSiPolicy.p7b or UpdateWinSiPolicy.p7b)" }
            '4e61c68c-97f6-430b-9cd7-9b1004706770' { Write-Verbose "PolicyTypeID: {$PolicyTypeID} - Advanced Threat Protection Code Integrity Policy (ATPSiPolicy.p7b or UpdateATPSiPolicy.p7b)" }
            'd2bda982-ccf6-4344-ac5b-0b44427b6816' { Write-Verbose "PolicyTypeID: {$PolicyTypeID} - Driver Code Integrity Policy (DriverSiPolicy.p7b or UpdateDriverSiPolicy.p7b)" }
        }

        $SetPolicyTypeID = $True

        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): PlatformID"

        [Byte[]] $PlatformIDBytes = $BinaryReader.ReadBytes($GuidLength)
        $PlatformID = [Guid] $PlatformIDBytes

        $SIPolicy.PlatformID = "{$($PlatformID.ToString().ToUpper())}"

        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): Option Flags"

        $OptionFlags = $BinaryReader.ReadInt32()

        # Validate that the high bit is set - i.e. mask it off with 0x80000000
        if ($OptionFlags -band ([Int32]::MinValue) -ne [Int32]::MinValue) {
            throw "Invalid policy options flag. $CorruptPolicyErr"
            return
        }

        if (($OptionFlags -band 0x40000000) -eq 0x40000000) {
            Write-Verbose 'Policy option flags indicate that the code integrity policy was built from supplmental policies.'
        }

        # Obtain the policy rules but first remove the upper two high bits -
        # i.e. anding it with 0x3FFFFFFF first
        $PolicyRules = [CodeIntegrity.PolicyRules] ($OptionFlags -band 0x3FFFFFFF)

        $PolicyRulesArray = $PolicyRules -split ', '

        $Rules = New-Object -TypeName CodeIntegrity.RuleType[]($PolicyRulesArray.Length)

        for ($i = 0; $i -lt $Rules.Length; $i++) {
            $RuleType = New-Object -TypeName CodeIntegrity.RuleType -Property @{ Item = $PolicyRulesArray[$i] }
            $Rules[$i] = $RuleType
        }

        $SIPolicy.Rules = $Rules

        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): EKU Rule Count"
        $EKURuleEntryCount = $BinaryReader.ReadInt32()

        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): File Rule Count"
        $FileRuleEntryCount = $BinaryReader.ReadInt32()

        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): Signer Rule Count"
        $SignerRuleEntryCount = $BinaryReader.ReadInt32()

        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): Signer Scenario Rule Count"
        $SignerScenarioEntryCount = $BinaryReader.ReadInt32()

        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): VersionEx"
        $Revis = $BinaryReader.ReadUInt16()
        $Build = $BinaryReader.ReadUInt16()
        $Minor = $BinaryReader.ReadUInt16()
        $Major = $BinaryReader.ReadUInt16()

        $PolicyVersion = New-Object -TypeName Version -ArgumentList $Major, $Minor, $Build, $Revis

        $SIPolicy.VersionEx = $PolicyVersion

        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): Header Length"
        # Validate that the fixed header length was written to the end of the header
        $HeaderLength = $BinaryReader.ReadInt32()

        if ($HeaderLength -ne ($HeaderLengthMax - 4)) {
            Write-Warning "$BinPath has an invalid header footer: 0x$($HeaderLength.ToString('X8')). $CorruptPolicyErr"
        }

        if ($EKURuleEntryCount) {
            $EKUArray = New-Object -TypeName CodeIntegrity.EKU[]($EKURuleEntryCount)

            Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): EKU Rules"

            for ($i = 0; $i -lt $EKURuleEntryCount; $i++) {
                # Length of the encoded EKU OID value
                $EkuValueLen = $BinaryReader.ReadUInt32()

                # Length of the encoded EKU OID value padded out to 4 bytes
                $PaddingBytes = 4 - $EkuValueLen % 4 -band 3

                $EKUValueBytes = $BinaryReader.ReadBytes($EkuValueLen)
                $null = $BinaryReader.ReadBytes($PaddingBytes)

                $EKUValueBytesCopy = $EKUValueBytes
                #$EKUValueBytesCopy[0] = 6

                $OID = ConvertTo-Oid -EncodedOIDBytes $EKUValueBytesCopy

                $Properties = @{
                    Value = $EKUValueBytes
                    ID = "ID_EKU_E_$(($i + 1).ToString('X4'))"
                }

                # Reconstruct the original FriendlyName that would have been lost
                # in the process of converting to binary form.
                if ($OID) {
                    if ($OID.FriendlyName) {
                        $Properties['FriendlyName'] = $OID.FriendlyName
                    } elseif ($OID.Value) {
                        $Properties['FriendlyName'] = $OID.Value
                    }
                }

                $EKUArray[$i] = New-Object -TypeName CodeIntegrity.EKU -Property $Properties
            }

            $SIPolicy.EKUs = $EKUArray
        }

        if ($FileRuleEntryCount) {
            # The XMl serializer won't validate unless
            # I use a generic collection vs. a System.Object[].
            $Script:FileRulesArray = New-Object -TypeName 'System.Collections.Generic.List[Object]'

            Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): File Rules"

            for ($i = 0; $i -lt $FileRuleEntryCount; $i++) {
                $FileRuleTypeValue = $BinaryReader.ReadInt32()

                switch ($FileRuleTypeValue) {
                    0 {
                        $TypeName = 'CodeIntegrity.Deny'
                        $ID = "ID_DENY_D_$(($i + 1).ToString('X4'))"
                    }

                    1 {
                        $TypeName = 'CodeIntegrity.Allow'
                        $ID = "ID_ALLOW_A_$(($i + 1).ToString('X4'))"
                    }

                    2 {
                        $TypeName = 'CodeIntegrity.FileAttrib'
                        $ID = "ID_FILEATTRIB_F_$(($i + 1).ToString('X4'))"
                    }

                    default { throw "Invalid file rule type: 0x$($FileRuleTypeValue.ToString('X8'))" }
                }

                $FileRule = New-Object -TypeName $TypeName -Property @{ ID = $ID }

                $FileName = Get-BinaryString -BinaryReader $BinaryReader

                if ($FileName) {
                    $FileRule.FileName = $FileName
                }

                $Revis = $BinaryReader.ReadUInt16()
                $Build = $BinaryReader.ReadUInt16()
                $Minor = $BinaryReader.ReadUInt16()
                $Major = $BinaryReader.ReadUInt16()

                $MinimumVersion = New-Object -TypeName Version -ArgumentList $Major, $Minor, $Build, $Revis

                # If it's a deny rule and MaximumFileVersion is null, the version will be set to 65535.65535.65535.65535
                # Otherwise, if MinimumFileVersion is non-zero, then a MinimumFileVersion was specified.
                if (!(($FileRuleTypeValue -eq 0) -and ($MinimumVersion -eq '65535.65535.65535.65535')) -and ($MinimumVersion -ne '0.0.0.0')) {
                    $FileRule.MinimumFileVersion = $MinimumVersion
                }

                $HashLen = $BinaryReader.ReadUInt32()

                if ($HashLen) {
                    $PaddingBytes = 4 - $HashLen % 4 -band 3

                    $HashBytes = $BinaryReader.ReadBytes($HashLen)
                    $null = $BinaryReader.ReadBytes($PaddingBytes)

                    $FileRule.Hash = $HashBytes
                }

                $Script:FileRulesArray.Add($FileRule)
            }

            $SIPolicy.FileRules = $Script:FileRulesArray
        }

        if ($SignerRuleEntryCount) {
            $Script:SignersArray = New-Object -TypeName CodeIntegrity.Signer[]($SignerRuleEntryCount)

            Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): Signer Rules"

            for ($i = 0; $i -lt $SignerRuleEntryCount; $i++) {
                $CertRootTypeValue = $BinaryReader.ReadInt32()

                $Signer = New-Object -TypeName CodeIntegrity.Signer -Property @{
                    ID = "ID_SIGNER_S_$(($i + 1).ToString('X4'))"
                    Name = "Signer $($i + 1)"
                }

                switch ($CertRootTypeValue) {
                    0 { $CertRootType = [CodeIntegrity.CertEnumType] 'TBS' } # TBS - To Be Signed
                    1 { $CertRootType = [CodeIntegrity.CertEnumType] 'WellKnown' }
                    default { throw "Invalid certificate root type: 0x$($CertRooTypeValue.ToString('X8'))" }
                }

                if ($CertRootType -eq 'TBS') {
                    $CertRootLength = $BinaryReader.ReadUInt32()

                    if ($CertRootLength) {
                        $PaddingBytes = 4 - $CertRootLength % 4 -band 3

                        # This is a hash of the ToBeSigned data blob.
                        # The hashing algorithm used is dictated by the algorithm specified in the certificate.
                        [Byte[]] $CertRootBytes = $BinaryReader.ReadBytes($CertRootLength)

                        $null = $BinaryReader.ReadBytes($PaddingBytes)
                    }
                } else {
                    # WellKnown type

                    # I'd like to know what these map to. I assume there's a mapped list of common
                    # Microsoft root certificates.
                    # It doesn't appear as though the ConfigCI cmdlets can generate a well known root type.
                    [Byte[]] $CertRootBytes = @(($BinaryReader.ReadUInt32() -band 0xFF))
                }

                $CertRootObject = New-Object -TypeName CodeIntegrity.CertRoot -Property @{ Type = $CertRootType; Value = $CertRootBytes }

                $Signer.CertRoot = $CertRootObject

                $CertEKULength = $BinaryReader.ReadUInt32()

                if ($CertEKULength) {
                    $CertEKUArray = New-Object -TypeName CodeIntegrity.CertEKU[]($CertEKULength)

                    for ($j = 0; $j -lt $CertEKULength; $j++) {
                        $EKUIndex = $BinaryReader.ReadUInt32()
                        $CertEKUArray[$j] = New-Object -TypeName CodeIntegrity.CertEKU -Property @{ ID = $SIPolicy.EKUs[$EKUIndex].ID }
                    }

                    $Signer.CertEKU = $CertEKUArray
                }

                $CertIssuer = Get-BinaryString -BinaryReader $BinaryReader

                if ($CertIssuer) {
                    $Signer.CertIssuer = New-Object -TypeName CodeIntegrity.CertIssuer -Property @{ Value = $CertIssuer }
                }

                $CertPublisher = Get-BinaryString -BinaryReader $BinaryReader

                if ($CertPublisher) {
                    $Signer.CertPublisher = New-Object -TypeName CodeIntegrity.CertPublisher -Property @{ Value = $CertPublisher }
                }

                $CertOemID = Get-BinaryString -BinaryReader $BinaryReader

                if ($CertOemID) {
                    $Signer.CertOemID = New-Object -TypeName CodeIntegrity.CertOemID -Property @{ Value = $CertOemID }
                }

                $FileAttribRefLength = $BinaryReader.ReadUInt32()

                if ($FileAttribRefLength) {
                    $FileAttribRefArray = New-Object -TypeName CodeIntegrity.FileAttribRef[]($FileAttribRefLength)

                    for ($j = 0; $j -lt $FileAttribRefLength; $j++) {
                        $FileAttribRefIndex = $BinaryReader.ReadUInt32()
                        $FileAttribRefArray[$j] = New-Object -TypeName CodeIntegrity.FileAttribRef -Property @{ RuleID = $SIPolicy.FileRules[$FileAttribRefIndex].ID }
                    }

                    $Signer.FileAttribRef = $FileAttribRefArray
                }

                $Script:SignersArray[$i] = $Signer
            }

            $SIPolicy.Signers = $Script:SignersArray
        }

        $UpdatePolicySignersLength = $BinaryReader.ReadUInt32()

        if ($UpdatePolicySignersLength) {
            $UpdatePolicySigners = New-Object -TypeName CodeIntegrity.UpdatePolicySigner[]($UpdatePolicySignersLength)

            Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): Update Policy Signers"

            for ($i = 0; $i -lt $UpdatePolicySignersLength; $i++) {
                $UpdatePolicySignersIndex = $BinaryReader.ReadUInt32()
                $UpdatePolicySigners[$i] = New-Object -TypeName CodeIntegrity.UpdatePolicySigner -Property @{ SignerId = $SIPolicy.Signers[$UpdatePolicySignersIndex].ID }
            }

            $SIPolicy.UpdatePolicySigners = $UpdatePolicySigners
        }

        $CISignersLength = $BinaryReader.ReadUInt32()

        if ($CISignersLength) {
            $CISigners = New-Object -TypeName CodeIntegrity.CiSigner[]($CISignersLength)

            Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): CI Signers"

            for ($i = 0; $i -lt $CISignersLength; $i++) {
                $CISignersIndex = $BinaryReader.ReadUInt32()
                $CISigners[$i] = New-Object -TypeName CodeIntegrity.CiSigner -Property @{ SignerId = $SIPolicy.Signers[$CISignersIndex].ID }
            }

            $SIPolicy.CiSigners = $CISigners
        }

        if ($SignerScenarioEntryCount) {
            $SignerScenarioArray = New-Object -TypeName CodeIntegrity.SigningScenario[]($SignerScenarioEntryCount)

            Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): Signer Scenarios"

            for ($i = 0; $i -lt $SignerScenarioEntryCount; $i++) {
                [Byte] $SigningScenarioValue = $BinaryReader.ReadUInt32() -band 0xFF

                $DriverSigningScenarioCount = 1
                $WindowsSigningScenarioCount = 0

                switch ($SigningScenarioValue) {
                    131 {
                        $ID = "ID_SIGNINGSCENARIO_DRIVERS_$($DriverSigningScenarioCount.ToString('X'))"
                        $DriverSigningScenarioCount++
                    }

                    12 {
                        $ID = 'ID_SIGNINGSCENARIO_WINDOWS'

                        # It is unlikely that there would ever be more than one windows
                        # (i.e. user mode) signing scenario but handle it just in case.
                        if ($WindowsSigningScenarioCount) {
                            $ID += "_$(($WindowsSigningScenarioCount + 1).ToString('X'))"
                        }

                        $WindowsSigningScenarioCount++
                    }

                    default {
                        # It is unlikely that there would ever be a value other than
                        # 131 or 12 but account for it anyway.
                        $ID = "ID_SIGNINGSCENARIO_S_$(($i + 1).ToString('X4'))"
                    }
                }

                $SigningScenario = New-Object -TypeName CodeIntegrity.SigningScenario -Property @{ ID = $ID; Value = $SigningScenarioValue }

                # The ability to inherit from another signing scenario is not formally documented
                # other than in the SIPolicy schema.
                $InheritedScenarios = $null

                $InheritedScenarioLength = $BinaryReader.ReadUInt32()

                if ($InheritedScenarioLength) {
                    $InheritedScenarios = New-Object UInt32[]($InheritedScenarioLength)

                    for ($j = 0; $j -lt $InheritedScenarioLength; $j++) {
                        $InheritedScenarios[$j] = $BinaryReader.ReadUInt32()
                    }

                    # To-do: Make sure I resolve the indices later on!
                    $InheritedScenariosString = $InheritedScenarios -join ','
                    $SigningScenario.InheritedScenarios = $InheritedScenariosString
                }

                [UInt16] $MinimumHashValueValue = $BinaryReader.ReadUInt32() -band [UInt16]::MaxValue

                # 0x800C refers to the absense of a minimum hash algorithm.
                if ($MinimumHashValueValue -ne 0x800C) {
                    $MinimumHashValue = $MinimumHashValueValue

                    $SigningScenario.MinimumHashAlgorithmSpecified = $True
                    $SigningScenario.MinimumHashAlgorithm = $MinimumHashValue
                } else {
                    $SigningScenario.MinimumHashAlgorithmSpecified = $False
                }

                # Loop over product signers, test signers, and test signing signers
                1..3 | ForEach-Object {
                    $AllowedSignersCount = $BinaryReader.ReadUInt32()
                    $AllowSignersObject = $null

                    if ($AllowedSignersCount) {
                        $AllowSignersObject = New-Object -TypeName CodeIntegrity.AllowedSigners
                        $AllowSignerArray = New-Object -TypeName CodeIntegrity.AllowedSigner[]($AllowedSignersCount)

                        for ($j = 0; $j -lt $AllowedSignersCount; $j++) {
                            $AllowedSignerIndex = $BinaryReader.ReadUInt32()

                            $ExceptDenyRuleLength = $BinaryReader.ReadUInt32()

                            $ExceptDenyRulesArray = $null

                            if ($ExceptDenyRuleLength) {
                                $ExceptDenyRulesArray = New-Object -TypeName CodeIntegrity.ExceptDenyRule[]($ExceptDenyRuleLength)

                                for ($k = 0; $k -lt $ExceptDenyRuleLength; $k++) {
                                    $ExceptDenyRuleIndex = $BinaryReader.ReadUInt32()
                                    $ExceptDenyRulesArray[$k] = New-Object -TypeName CodeIntegrity.ExceptDenyRule -Property @{ DenyRuleID = $SIPolicy.FileRules[$ExceptDenyRuleIndex].ID }
                                }
                            }

                            $AllowSignerArray[$j] = New-Object -TypeName CodeIntegrity.AllowedSigner -Property @{ SignerId = $SIPolicy.Signers[$AllowedSignerIndex].ID }
                            $AllowSignerArray[$j].ExceptDenyRule = $ExceptDenyRulesArray
                        }

                        $AllowSignersObject.AllowedSigner = $AllowSignerArray
                    }

                    $DeniedSignersCount = $BinaryReader.ReadUInt32()
                    $DeniedSignersObject = $null

                    if ($DeniedSignersCount) {
                        $DeniedSignersObject = New-Object -TypeName CodeIntegrity.DeniedSigners
                        $DeniedSignerArray = New-Object -TypeName CodeIntegrity.DeniedSigner[]($DeniedSignersCount)

                        for ($j = 0; $j -lt $DeniedSignersCount; $j++) {
                            $DeniedSignerIndex = $BinaryReader.ReadUInt32()

                            $ExceptAllowRuleLength = $BinaryReader.ReadUInt32()

                            $ExceptAllowRulesArray = $null

                            if ($ExceptAllowRuleLength) {
                                $ExceptAllowRulesArray = New-Object -TypeName CodeIntegrity.ExceptAllowRule[]($ExceptAllowRuleLength)

                                for ($k = 0; $k -lt $ExceptAllowRuleLength; $k++) {
                                    $ExceptAllowRuleIndex = $BinaryReader.ReadUInt32()
                                    $ExceptAllowRulesArray[$k] = New-Object -TypeName CodeIntegrity.ExceptAllowRule -Property @{ AllowRuleID = $SIPolicy.FileRules[$ExceptAllowRuleIndex].ID }
                                }
                            }

                            $DeniedSignerArray[$j] = New-Object -TypeName CodeIntegrity.DeniedSigner -Property @{ SignerId = $SIPolicy.Signers[$DeniedSignerIndex].ID }
                            $DeniedSignerArray[$j].ExceptAllowRule = $ExceptAllowRulesArray
                        }

                        $DeniedSignersObject.DeniedSigner = $DeniedSignerArray
                    }

                    $FileRulesRefCount = $BinaryReader.ReadUInt32()
                    $FileRulesRefObject = $null

                    if ($FileRulesRefCount) {
                        $FileRulesRefObject = New-Object -TypeName CodeIntegrity.FileRulesRef
                        $FileRuleRefArray = New-Object -TypeName CodeIntegrity.FileRuleRef[]($FileRulesRefCount)

                        for ($j = 0; $j -lt $FileRulesRefCount; $j++) {
                            $FileRulesRefIndex = $BinaryReader.ReadUInt32()

                            $FileRuleRefArray[$j] = New-Object -TypeName CodeIntegrity.FileRuleRef -Property @{ RuleID = $SIPolicy.FileRules[$FileRulesRefIndex].ID }
                        }

                        $FileRulesRefObject.FileRuleRef = $FileRuleRefArray
                    }

                    $NullSigner = $False

                    # Don't populate the relevant object if it wasn't present in the binary.
                    # Even setting a property to null in an object that can be serialized
                    # with XML can result in the creation of empty XML element/attributes.
                    if (($AllowedSignersCount -eq 0) -and ($DeniedSignersCount -eq 0) -and ($FileRulesRefCount -eq 0)) {
                        $NullSigner = $True
                    }

                    switch ($_) {
                        1 { # Product signers
                            if (-not $NullSigner) {
                                $ProductSigner = New-Object -TypeName CodeIntegrity.ProductSigners

                                if ($AllowSignersObject) { $ProductSigner.AllowedSigners = $AllowSignersObject }
                                if ($DeniedSignersObject) { $ProductSigner.DeniedSigners = $DeniedSignersObject }
                                if ($FileRulesRefObject) { $ProductSigner.FileRulesRef = $FileRulesRefObject }

                                $SigningScenario.ProductSigners = $ProductSigner
                            } else {
                                $SigningScenario.ProductSigners = New-Object -TypeName CodeIntegrity.ProductSigners
                            }
                        }

                        2 { # Test signers
                            if (-not $NullSigner) {
                                $TestSigner = New-Object -TypeName CodeIntegrity.TestSigners

                                if ($AllowSignersObject) { $TestSigner.AllowedSigners = $AllowSignersObject }
                                if ($DeniedSignersObject) { $TestSigner.DeniedSigners = $DeniedSignersObject }
                                if ($FileRulesRefObject) { $TestSigner.FileRulesRef = $FileRulesRefObject }

                                $SigningScenario.TestSigners = $TestSigner
                            } else {
                                $SigningScenario.TestSigners = New-Object -TypeName CodeIntegrity.TestSigners
                            }
                        }

                        3 { # Test signing signers
                            if (-not $NullSigner) {
                                $TestSigningSigner = New-Object -TypeName CodeIntegrity.TestSigningSigners

                                if ($AllowSignersObject) { $TestSigningSigner.AllowedSigners = $AllowSignersObject }
                                if ($DeniedSignersObject) { $TestSigningSigner.DeniedSigners = $DeniedSignersObject }
                                if ($FileRulesRefObject) { $TestSigningSigner.FileRulesRef = $FileRulesRefObject }

                                $SigningScenario.TestSigningSigners = $TestSigningSigner
                            } else {
                                $SigningScenario.TestSigningSigners = New-Object -TypeName CodeIntegrity.TestSigningSigners
                            }
                        }
                    }
                }

                $SignerScenarioArray[$i] = $SigningScenario
            }

            # Resolve inherited scenario IDs now that they've all been parsed.
            for ($i = 0; $i -lt $SignerScenarioEntryCount; $i++) {
                if ($SignerScenarioArray[$i].InheritedScenarios) {
                    [Int[]] $ScenarioIndices = $SignerScenarioArray[$i].InheritedScenarios -split ','

                    $SignerScenarioArray[$i].InheritedScenarios = ($ScenarioIndices | ForEach-Object { $SignerScenarioArray[$_].ID }) -join ','
                }
            }

            $SIPolicy.SigningScenarios = $SignerScenarioArray
        }

        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): HVCI Options"
        # Maybe I could parse this out
        $HVCIOptions = $BinaryReader.ReadUInt32()

        if ($HVCIOptions) {
            $SIPolicy.HvciOptions = $HVCIOptions
            $SIPolicy.HvciOptionsSpecified = $True
        } else {
            $SIPolicy.HvciOptionsSpecified = $False
        }

        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): Secure Settings"
        $SecureSettingsLength = $BinaryReader.ReadUInt32()

        if ($SecureSettingsLength) {

            $SecureSettings = New-Object CodeIntegrity.Setting[]($SecureSettingsLength)

            for ($i = 0; $i -lt $SecureSettingsLength; $i++) {
                Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): Secure Settings [$i]"

                $Provider = Get-BinaryString -BinaryReader $BinaryReader
                $Key = Get-BinaryString -BinaryReader $BinaryReader
                $ValueName = Get-BinaryString -BinaryReader $BinaryReader

                $ValueType = $BinaryReader.ReadUInt32()

                switch ($ValueType) {
                    0 { # Boolean type
                        [Bool] $Value = $BinaryReader.ReadUInt32()
                    }

                    1 { # Unsigned int type
                        [UInt32] $Value = $BinaryReader.ReadUInt32()
                    }

                    2 { # Byte array type
                        # Length of the byte array
                        $ByteArrayLen = $BinaryReader.ReadUInt32()

                        # Length of the byte array padded out to 4 bytes
                        $PaddingBytes = 4 - $ByteArrayLen % 4 -band 3

                        $ValueBytes = $BinaryReader.ReadBytes($ByteArrayLen)
                        $null = $BinaryReader.ReadBytes($PaddingBytes)

                        [Byte[]] $Value = $ValueBytes
                    }

                    3 { # String type
                        [String] $Value = Get-BinaryString -BinaryReader $BinaryReader
                    }
                }

                $SecureSetting = New-Object CodeIntegrity.Setting
                $SettingValueType = New-Object CodeIntegrity.SettingValueType
                $SettingValueType.Item = $Value

                $SecureSetting.Provider = $Provider
                $SecureSetting.Key = $Key
                $SecureSetting.ValueName = $ValueName
                $SecureSetting.Value = $SettingValueType

                $SecureSettings[$i] = $SecureSetting
            }

            $SIPolicy.Settings = $SecureSettings
        }

        $V3RuleSupport = $BinaryReader.ReadUInt32()

        if ($V3RuleSupport -eq 3 -and $CIPolicyFormatVersion -ge 3) {

            Write-Verbose 'Processing binary format v3 rules: file rule maximum versions and macro rules'

            if ($FileRuleEntryCount) {

                Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): File Rules Macros"

                for ($i = 0; $i -lt $FileRuleEntryCount; $i++) {
                    $Revis = $BinaryReader.ReadUInt16()
                    $Build = $BinaryReader.ReadUInt16()
                    $Minor = $BinaryReader.ReadUInt16()
                    $Major = $BinaryReader.ReadUInt16()

                    $MaximumVersion = New-Object -TypeName Version -ArgumentList $Major, $Minor, $Build, $Revis

                    if ($MaximumVersion -ne ([Version] '0.0.0.0')) {
                        $Script:FileRulesArray[$i].MaximumFileVersion = $MaximumVersion
                    }

                    $MacroStringCount = $BinaryReader.ReadUInt32()

                    # Note: macro names are not stored in a binary policy (only values) so no effort will be made to infer macro names.
                    if ($MacroStringCount) {
                        if ($MacroStringCount -eq 1) {
                            $MacroString = Get-BinaryString -BinaryReader $BinaryReader

                            $Script:FileRulesArray[$i].AppIDs = $MacroString
                        } else {
                            $MacroStrings = (1..$MacroStringCount | ForEach-Object { Get-BinaryString -BinaryReader $BinaryReader }) -join ''

                            $Script:FileRulesArray[$i].AppIDs = $MacroStrings
                        }
                    }
                }
            }

            if ($SignerRuleEntryCount) {

                Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): Signer Rules Macro"

                for ($i = 0; $i -lt $SignerRuleEntryCount; $i++) {
                    $SignTimeAfterValue = $BinaryReader.ReadInt64()

                    if ($SignTimeAfterValue -ne 0) {
                        $Script:SignersArray[$i].SignTimeAfter = [DateTime]::FromFileTime($SignTimeAfterValue)
                    }
                }
            }

            $V4RuleSupport = $BinaryReader.ReadUInt32()

            if ($V4RuleSupport -eq 4 -and $CIPolicyFormatVersion -ge 4) {
                Write-Verbose 'Processing binary format v4 rules: file metadata - InternalName, FileDescription, ProductName'

                if ($FileRuleEntryCount) {

                    Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): File Rules File Metadata"

                    for ($i = 0; $i -lt $FileRuleEntryCount; $i++) {
                        $InternalName = Get-BinaryString -BinaryReader $BinaryReader
                        $FileDescription = Get-BinaryString -BinaryReader $BinaryReader
                        $ProductName = Get-BinaryString -BinaryReader $BinaryReader

                        if ($InternalName) { $Script:FileRulesArray[$i].InternalName = $InternalName }
                        if ($FileDescription) { $Script:FileRulesArray[$i].FileDescription = $FileDescription }
                        if ($ProductName) { $Script:FileRulesArray[$i].ProductName = $ProductName }
                    }
                }

                $V5RuleSupport = $BinaryReader.ReadUInt32()

                if ($V5RuleSupport -eq 5 -and $CIPolicyFormatVersion -ge 5) {
                    Write-Verbose 'Processing binary format v5 rules: PackageFamilyName and PackageVersion'

                    if ($FileRuleEntryCount) {

                        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): File Rules Package Metadata"

                        for ($i = 0; $i -lt $FileRuleEntryCount; $i++) {
                            $PackageFamilyName = Get-BinaryString -BinaryReader $BinaryReader

                            $Revis = $BinaryReader.ReadUInt16()
                            $Build = $BinaryReader.ReadUInt16()
                            $Minor = $BinaryReader.ReadUInt16()
                            $Major = $BinaryReader.ReadUInt16()

                            $PackageVersion = New-Object -TypeName Version -ArgumentList $Major, $Minor, $Build, $Revis

                            if ($PackageFamilyName) { $Script:FileRulesArray[$i].PackageFamilyName = $PackageFamilyName }

                            if ($PackageVersion -ne ([Version] '0.0.0.0')) {
                                $Script:FileRulesArray[$i].PackageVersion = $PackageVersion
                            }
                        }
                    }

                    $V6RuleSupport = $BinaryReader.ReadUInt32()

                    if ($V6RuleSupport -eq 6 -and $CIPolicyFormatVersion -ge 6) {

                        Write-Verbose 'Processing binary format v6 rules: Supplemental policy information - BasePolicyID, PolicyID, and supplemental signers'

                        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): BasePolicyID and PolicyID GUID"

                        # The CI policy has the new BasePolicyID and PolicyID elements versus the older PolicyTypeID element.

                        $PolicyID = [Guid][Byte[]] $BinaryReader.ReadBytes($GuidLength)

                        $SIPolicy.PolicyID = "{$($PolicyID.ToString().ToUpper())}"

                        $BasePolicyID = [Guid][Byte[]] $BinaryReader.ReadBytes($GuidLength)

                        $SIPolicy.BasePolicyID = "{$($BasePolicyID.ToString().ToUpper())}"

                        $SIPolicy.PolicyTypeSpecified = $True

                        if ($SIPolicy.PolicyID -eq $SIPolicy.BasePolicyID) {
                            $SIPolicy.PolicyType = 'BasePolicy'
                        } else {
                            $SIPolicy.PolicyType = 'SupplementalPolicy'
                        }

                        $SetPolicyTypeID = $False

                        $SupplementalSignerRuleEntryCount = $BinaryReader.ReadUInt32()

                        if ($SupplementalSignerRuleEntryCount) {
                            $SupplementalSigners = New-Object -TypeName CodeIntegrity.SupplementalPolicySigner[]($SupplementalSignerRuleEntryCount)

                            Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): Supplemental Signers"

                            for ($i = 0; $i -lt $SupplementalSignerRuleEntryCount; $i++) {
                                $SupplemetalSignersIndex = $BinaryReader.ReadUInt32()
                                $SupplementalSigners[$i] = New-Object -TypeName CodeIntegrity.SupplementalPolicySigner -Property @{ SignerId = $SIPolicy.Signers[$SupplemetalSignersIndex].ID }
                            }

                            $SIPolicy.SupplementalPolicySigners = $SupplementalSigners
                        }

                        $V7RuleSupport = $BinaryReader.ReadUInt32()

                        if ($V7RuleSupport -eq 7 -and $CIPolicyFormatVersion -ge 7) {
                            Write-Verbose 'Processing binary format v7 rules: FilePath rules'

                            if ($FileRuleEntryCount) {

                                Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): FilePath Rules"

                                for ($i = 0; $i -lt $FileRuleEntryCount; $i++) {
                                    $FilePath = Get-BinaryString -BinaryReader $BinaryReader

                                    if ($FilePath) { $Script:FileRulesArray[$i].FilePath = $FilePath }
                                }
                            }

                            $V8RuleSupport = $BinaryReader.ReadUInt32()

                            # To-do: What follows will need to be updated when a new CI policy schema is released.
                            if ($V8RuleSupport -ne 8) {
                                Write-Warning 'A parsing error may have occurred. The CI policy should end with 0x00000008.'
                            }
                        }
                    }
                }
            }

            if ($FileRuleEntryCount) { $SIPolicy.FileRules = $Script:FileRulesArray }
            if ($SignerRuleEntryCount) { $SIPolicy.Signers = $Script:SignersArray }
        }

        Write-Verbose "Position 0x$($BinaryReader.BaseStream.Position.ToString('X8')): End of Policy"

    } catch {
        $BinaryReader.Close()
        $MemoryStream.Close()

        throw $_
        return
    }

    if ($SetPolicyTypeID) { $SIPolicy.PolicyTypeID = "{$($PolicyTypeID.ToString().ToUpper())}" }

    $BinaryReader.Close()
    $MemoryStream.Close()

    $XmlOutputSuccess = $False

    try {
        $XmlTextWriter = New-Object -TypeName Xml.XmlTextWriter -ArgumentList $FullXmlPath, $null
        $XmlTextWriter.Formatting = 'Indented'

        $XmlSerializer = New-Object -TypeName Xml.Serialization.XmlSerializer -ArgumentList ([CodeIntegrity.SIPolicy])

        $XmlSerializer.Serialize($XmlTextWriter, $SIPolicy)
        $XmlTextWriter.Close()
        $XmlOutputSuccess = $True
    } catch {
        throw $_
        return
    }

    if ($XmlOutputSuccess) {
        Get-Item -Path $FullXmlPath
    }
}

function Get-WDACCodeIntegrityBinaryPolicyCertificate {
<#
.SYNOPSIS

Extracts the signer information from a signed, binary code integrity policy.

Author: Matthew Graeber (@mattifestation)
Contributors: James Forshaw (@tiraniddo) - thanks for the major bug fixes!
License: BSD 3-Clause

.DESCRIPTION

Get-WDACCodeIntegrityBinaryPolicyCertificate obtains signer information from a signed, binary code integrity policy. This function was developed as the result of Get-AuthenticodeSignature not supporting signed, binary code integrity policies. Signed policies are represented as PKCS#7 ASN.1 SignedData (szOID_RSA_signedData - 1.2.840.113549.1.7.2).

.PARAMETER BinaryFilePath

Specifies the path of a signed, binary code interity policy. Deployed binary policy files are located in %SystemRoot%\System32\CodeIntegrity\SIPolicy.p7b.

.EXAMPLE

Get-WDACCodeIntegrityBinaryPolicyCertificate -BinaryFilePath C:\Windows\System32\CodeIntegrity\SIPolicy.p7b

.OUTPUTS

System.Security.Cryptography.X509Certificates.X509Certificate2

If the binary code integrity is signed, Get-WDACCodeIntegrityBinaryPolicyCertificate will output a list of X509Certificate2 objects.
#>

    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param (
        [Parameter(Position = 0, Mandatory)]
        [String]
        [ValidateScript({ [IO.File]::Exists((Resolve-Path $_).Path) })]
        $BinaryFilePath
    )

    # Obtain the full path to the policy file if a relative path was provided.
    $BinPath = Resolve-Path $BinaryFilePath
    try {
        $Cms = New-Object System.Security.Cryptography.Pkcs.SignedCms
        $Cms.Decode([IO.File]::ReadAllBytes($BinPath))
        $Cms.Certificates
    } catch {
        throw "$BinPath is not a signed binary code integrity policy."
    }
}
