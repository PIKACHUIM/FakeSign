# 自建时间戳服务器实现伪签名驱动证书

# Drivers Signning with Self-Sign Fake Timestamp Servers

![自建时间戳服务器实现伪签名驱动证书](https://github.com/PIKACHUIM/FakeSign/raw/main/Pictures/20241114143520.png)

### 2025/04/01更新：

**接到通知域名提供者通知，由于域名存在滥用情况，注册局已经停止了所有us.kg的解析，请使用下列备用的时间戳地址：**

**We have received notification from the domain provider that due to domain abuse, the registry has stopped all resolution of us.kg. Please use the following alternative timestamp address:**

- http://timers.dns.navy/
- http://timers.524228.xyz/

## 项目介绍 / Introduction

购买一个代码签名证书非常昂贵，而在Windows平台上，驱动签名需要EV代码签名证书才能进行WHQL认证，EV代码签名证书一年就需要几千块。作为个人开发者或者测试驱动需求，购买权威机构的EV代码签名证书是非常不划算的，同时需要公司认证，时间流程都非常麻烦。微软于2019年7月暂停了EV交叉驱动签名证书CA的签发，意味着这之后不能直接使用EV代码签名，需要WHQL认证。但在这之前签发的证书可以直接签署驱动完成认证。网上有一些泄露的EV代码签名证书，可以利用[《自建时间戳服务实现伪签驱动证书》](https://code.52pika.cn/index.php/archives/277/)的时间戳功能完成伪造签名，让签名时间戳在泄露证书有效期内，实现驱动签名和认证。

Purchasing a code signing certificate is very expensive, and on the Windows platform, driver signing requires an EV code signing certificate for WHQL authentication, which costs several thousand yuan per year. As an individual developer or test driver, purchasing an EV code signing certificate from an authoritative organization is very uneconomical, and requires company certification, which is a very complicated time process. Microsoft suspended the issuance of EV cross drive signing certificate CA in July 2019, which means that EV code signing cannot be directly used after that and WHQL authentication is required. But certificates issued before this can be directly signed to complete authentication. There are some leaked EV code signature certificates online, which can be used to [Implement Pseudo Signature Driver Certificates through Self-built Timestamp Services](https://code.52pika.cn/index.php/archives/277/)  The timestamp function completes the forgery of signatures, allowing the signature timestamp to be within the validity period of the leaked certificate, achieving driver signature and authentication.

## 免责声明 / Disclaimers

**本文涉及网络安全实验，阅读本文表示您已经阅读、完全理解并承诺遵守下列条款的全部内容：**

**This article involves network security experiments. Reading this article means that you have read, fully understood, and committed to complying with all the following terms and conditions:**

> <details><summary><strong><red>"Drivers Signning with Self-Sign Fake Timestamp Servers" Disclaimers - English</red></strong></summary><p><strong>Welcome to research and conduct the experiment on &quot;Drivers Signning with Self-Sign Fake Timestamp Servers&quot;</strong></p><p>Before using this experiment,<em><u>Please carefully read and agree to the following disclaimer license terms</u>.</em></p><p><strong>Continuing means that you agree to all the terms</strong>.<em>If you do not agree with any content of this license term,</em></p><p><em><u>Please immediately stop conducting this experiment and delete all content and its derivative data</u>.</em></p><ol start=''><li><h6 id='explanation-of-terms'>Explanation of Terms</h6><ol><li>&quot;Experimental Content&quot;: This includes the technology (including but not limited to code, files, steps) and its derivative content provided by this website experiment.</li><li>&quot;Violation of laws and regulations&quot;: refers to a violation of the relevant laws and regulations mentioned in this agreement and in your country or region, as well as their relevant provisions.</li><li>&quot;Author&quot;: The provider of this experimental technology, including the creator of this document, website provider, and other assistance providers.</li><li>&quot;User&quot;: The subject who uses the technology provided in this experiment (including but not limited to: code, files, steps) and its derivative content.</li></ol></li><li><h6 id='experimental-purpose'>Experimental Purpose</h6><ol><li>This experiment aims to provide practical learning and technical research on network security technology.</li></ol><ol start='2'><li>This experiment is only for individuals or groups to conduct non commercial technological exploration.</li></ol></li></ol><ol start='2'><li><h6 id='usage-restrictions'>Usage Restrictions</h6><ol><li>You promise that the principles of this experiment will only be used for experiments and safety technology testing and technical experiments, and will not be used in confidential or important production environments.</li><li>You are not allowed to use it for any activities that violate laws and regulations, including but not limited to criminal behavior, fraud, damage to computer information systems, etc.</li></ol></li><li><h6 id='legal-compliance'>Legal Compliance</h6><ol><li>You comply with the Cybersecurity Law of the People&#39;s Republic of China and are not allowed to use any technology on this website for illegal or criminal activities.</li><li>You shall comply with Article 286 (1) of the Criminal Law of the People&#39;s Republic of China and shall not use any technology on this website to damage the computer information system.</li><li>You shall comply with Article 32 of the Electronic Signature Law of the People&#39;s Republic of China and shall not use any technology of this website to forge, impersonate, or embezzle the electronic signature of others</li><li>You shall comply with the laws and regulations of China and other countries and regions where you are located, and shall not use any technology on this website to violate laws and regulations, or cause problems or losses to any other individual or group.</li></ol></li><li><h6 id='disclaimer'>Disclaimer</h6><ol><li>This experiment is only for technical and safety technical testing purposes and is not responsible for the user&#39;s behavior</li><li>The principles of this experiment are published on Github and can be freely accessed and used by anyone. The author is not responsible for the user behavior of the experiment.</li><li>The principle of this experiment may have technical, safety, or other issues, and users are required to bear the risk of use and take necessary safety measures to protect their own and others&#39; interests.</li><li>The author shall not be liable for any direct or indirect losses arising from the use of the principles of this experiment, including but not limited to profit losses, data losses, business interruptions, etc.</li><li>This website reserves the right to interrupt or terminate this service at any time without prior notice to users.</li></ol></li><li><h6 id='violations'>Violations</h6><ol>     	<li>If you violate any of the above terms, you will fully and independently bear any legal and other responsibilities and consequences that may arise</li></ol><p>&nbsp;</p><p>Please carefully read and understand the above disclaimer terms before using this service.</p><p>If you agree and accept the above terms, please continue to use this experiment.</p><p>If you have any questions or need further explanation, please contact us.</p></li></ol></details>
>
>
> <details>
> <summary><strong><red>《自建时间戳服务器实现伪签名驱动证书》免责声明 - 简体中文</red></strong></summary>
> <p><span>欢迎您研究并进行《自建时间戳服务器实现伪签名驱动证书》实验（以下简称“本实验”）。</span></p><p><span>在使用本实验前</span><strong><span>请您仔细阅读并同意以下免责许可条款</span></strong><span>，继续则代表您同意条款全部内容。</span></p><p><span>若您不同意本许可条款的任何内容，请立即停止进行本实验，并删除所有内容及其衍数据。</span></p><ol start=""><li><h6 id="术语解释"><span>术语解释</span></h6><ol start=""><li><p><span>“实验内容”：包括本网站实验所提供的技术（包括但不限于代码、文件、步骤）及其衍生内容。</span></p></li><li><p><span>“违反法律法规”：指违反本协议所提及的和您所在国家或地区的相关法律法规，及其相关规定。</span></p></li><li><p><span>“作者”：本实验技术的提供者，包括本文档创建人，网站提供者，以及其他提供帮助的主体等。</span></p></li><li><p><span>“使用者”：使用本实验提供的技术（包括但不限于：代码、文件、步骤）及其衍生内容的主体。</span></p></li></ol><p><strong><span>本文件中的关键词“必须”、“不得”、“要求”、“应”、“不应”、“可”、“不可”、“建议”、“旨在”、“仅（供）”和“可选”</span></strong></p><p><strong><span>应按照RFC2119中的说明进行解释。</span></strong></p></li><li><h6 id="实验目的"><span>实验目的</span></h6><ol start=""><li><p><span>本实验</span><strong><span>旨在</span></strong><span>提供网络安全技术的实践学习和技术研究。</span></p></li><li><p><span>本实验</span><strong><span>仅供</span></strong><span>个人或团体进行非商业性质的技术探索。</span></p></li></ol></li><li><h6 id="使用限制"><span>使用限制</span></h6><ol start=""><li><p><span>您</span><strong><span>必须</span></strong><span>承诺本实验的原理仅用于实验和安全技术测试和技术实验，不用于需保密或者重要生产环境。</span></p></li><li><p><span>您</span><strong><span>不得</span></strong><span>用于任何违反法律法规的活动，包括但不限于犯罪行为、欺诈、破坏计算机信息系统等。</span></p></li></ol></li><li><h6 id="法律合规"><span>法律合规</span></h6><ol start=""><li><p><span>您</span><strong><span>必须</span></strong><span>遵守《中华人民共和国网络安全法》，不得使用本网站任何技术进行违法犯罪活动。</span></p></li><li><p><span>您</span><strong><span>必须</span></strong><span>遵守《中华人民共和国刑法》第286条第1款规定，不得使用本网站的任何技术破坏计算机信息系统。</span></p></li><li><p><span>您</span><strong><span>必须</span></strong><span>遵守《中华人民共和国电子签名法》第32条，不得使用本网站的任何技术伪造、冒用、盗用他人的电子签名</span></p></li><li><p><span>您</span><strong><span>必须</span></strong><span>遵守中国以及其他所在国家和地区的法律法规，不得使用本网站的任何技术违反法律法规，或者给其他任何个人、团体造成问题或者损失。</span></p></li></ol></li><li><h6 id="免责声明"><span>免责声明</span></h6><ol start=""><li><p><span>本实验</span><strong><span>仅</span></strong><span>提供技术实验和安全技术测试之用，不对使用者的行为负责</span></p></li><li><p><span>本实验的原理发布在Github上，任何人均可自由获取和使用，作者不对实验的使用者行为负责。</span></p></li><li><p><span>本实验的原理</span><strong><span>可能</span></strong><span>存在技术问题、安全问题或其他问题，使用者需自行承担使用风险，并采取必要的安全措施保护自身和他人的利益。</span></p></li><li><p><span>作者对于使用本实验的原理所产生的任何直接或间接损失，包括但不限于利润损失、数据损失、业务中断等，不承担责任。</span></p></li><li><p><span>本网站保留在任何时候中断或终止本服务的权利，而无需提前通知使用者。</span></p></li></ol></li><li><h6 id="违规情形"><span>违规情形</span></h6><p><strong><span>您如果违反上述条款的任何内容，您将完全独立承担带来的任何法律以及其他责任和后果。</span></strong></p></li></ol><p><span>请您在使用本服务前认真阅读并理解上述免责许可条款。若您同意并接受上述条款，请继续使用本实验。</span></p><p><span>如有任何疑问或需要进一步解释，请联系我们。</span></p>
> </details>

## 简易使用 / Quick Usage

### 简易使用方法 / Easy Way to Sign Drivers

1. 下载时间证书信任工具：[数字证书安装工具](https://github.com/PIKACHUIM/FakeSign/raw/refs/heads/main/Releases/PikachuTestCert.exe)，双击EXE，根据安装流程信任证书文件

   （Download Time Certificate Trust Tool: [Digital Certificate Installation Tool](https://github.com/PIKACHUIM/FakeSign/raw/refs/heads/main/Releases/PikachuTestCert.exe)）

   如果需要静默安装，则应该运行（If silent installation is required, it should be run）：

   ```cmd
   PikachuTestCert.exe /VERYSILENT # 隐藏任何安装窗口和提示（需要管理员权限）
   PikachuTestCert.exe /SILENT     # 隐藏安装确认但显示进度（需要管理员权限）
   ```

2. 安装泄露驱动签名证书：**我不提供任何证书**，你可以去查找（[FuckCertVerifyTime](https://github.com/wanttobeno/FuckCertVerifyTime/tree/master/代码签名数字证书)）

   （Install leaked driver signature certificate: **I do not provide any certificate **([FuckCertVerifiyTime](https://github.com/wanttobeno/FuckCertVerifyTime/tree/master/)) ）

3. 下载驱动代码签名工具：[亚洲诚信签名工具](https://github.com/PIKACHUIM/FakeSign/raw/refs/heads/main/Releases/TimestampClient.zip)，打开软件选择[**自定义时间戳**]进行签名：

   （Download the driver code signing tool: [Asia Integrity Signature Tool](https://github.com/PIKACHUIM/FakeSign/raw/refs/heads/main/Releases/TimestampClient.zip), and then: ）

   1. 首先需要修改`inf文件`，修改`DriverVer`的日期部分，修改到**签名证书的时间范围**内：

      It is necessary to open the `.inf` files and modify the `DriverVer` to the time range of the signning certificate:

      ```inf
      DriverVer = 01/01/2015,1.0.1.0
      ```

   2. 签名`*.SYS`和其他文件（`.dll`、`.exe`等），**签名的时间需要大于或等于第一步的驱动版本时间**：

      Signature ` *.SYS ` and other files, **sign time needs to be greater than or equal to the DriverVer time **:

      1. 修改`hook.ini`，将`TimeStamp`内的值修改为**不低于上一步时间的值**：

         Modify `hook.ini` to change the value in 'Timestamptamp' to **not lower than the value of the previous step time**:

         ```
         [TimeStamp]
         TimeStamp=2015-01-01T08:00:00
         ServerURL=http://test.timer.us.kg/
         ```

      2. 打开**DSignTool.exe**，点击[**规则管理**]——[**添加**]——勾选[**将时间戳添加到数据中**] ——选中 [定义的时间戳]

         Open **DSignTool.exe***, click [Rule Management] - [Add] - check [Add Timestamp] - select [Defined Timestamp]

      3. 点击[**数字签名**]——拖入待签名的`*.SYS`和其他文件（`.dll`、`.exe`等），点击[数字签名]——选[双签名]或[SHA1]——驱动模式

         Click on [Digital Signature] - drag in the `*.sys` other files to be signed

         Click on [Digital Signature] - select [Double Signature] or [SHA1] - [Drive Mode]

   3. 修改系统时间，**修改的时间需要大于或等于第一步的驱动版本时间**，修改命令如下：

      Modify the system time, **The time needs to be greater than or equal to the driver version time of the first step**. 

      The modification command is as follows:

      ```cmd
      date 2015/01/01 && time 08:00:00
      ```

   4. 使用`infcat`创建CAT目录文件，需要先安装[ Windows 驱动程序工具包 (WDK) ](https://learn.microsoft.com/zh-cn/windows-hardware/drivers/download-the-wdk)

      To create a CAT directory file by `infcat`, you need to first install the [Windows Driver Kit (WDK)](https://learn.microsoft.com/en-us/windows-hardware/drivers/download-the-wdk)

      1. X86和X64驱动签名命令(X86 and X64 signning commands)：

         ```cmd
         inf2cat /v /os:XP_X86,Vista_X86,Vista_X64,7_X86,7_X64,8_X86,8_X64,6_3_X86,6_3_X64,10_X86,10_X64 /driver:.
         ```

      2. X86和X64完整签名命令(X86 and X64 fully signning commands)：

         ```cmd
         inf2cat /v /os:2000,XP_X86,XP_X64,Vista_X86,Vista_X64,7_X86,7_X64,8_X86,8_X64,6_3_X86,6_3_X64,10_X86,10_X64,10_AU_X86,10_AU_X64,10_RS2_X86,10_RS2_X64,10_RS3_X86,10_RS3_X64,10_RS4_X86,10_RS4_X64,10_RS5_X86,10_RS5_X64,10_19H1_X86,10_19H1_X64,10_VB_X86,10_VB_X64,10_CO_X64,10_NI_X64,Server2003_X86,Server2003_X64,Server2008_X86,Server2008_X64,Server2008R2_X64,Server8_X64,Server6_3_X64,Server10_X64,SERVER2016_X64,ServerRS5_X64 /driver:.
         ```
         
      3. A64和I64驱动签名命令(ARM and A64 driver signning commands)：
      
      ```cmd
         inf2cat /os:Server2003_IA64,Server2008_IA64,Server2008R2_IA64,Server10_ARM64,ServerRS5_ARM64,ServerFE_ARM64,10_RS3_ARM64,10_RS4_ARM64,10_RS5_ARM64,10_19H1_ARM64,10_VB_ARM64,10_CO_ARM64,10_NI_ARM64 /v /driver:.
      ```
      
   5. 签名`*.cat`文件，**签名的时间需要大于或等于第三步的CAT时间**：

   Sign the ` *.cat ` file, and the signing time needs to be greater than or equal to the CAT time of the third step

   1. 修改`hook.ini`，将`TimeStamp`内的值修改为**不低于上一步时间的值**

      Modify `hook.ini` to change the value in 'Timestamptamp' to **not lower than the value of the previous step time**:

      ```
         [TimeStamp]
      TimeStamp=2015-01-01T09:00:00
         ServerURL=http://test.timer.us.kg/
      ```

      2. 打开**DSignTool.exe**，点击[**规则管理**]——[**添加**]——勾选[**将时间戳添加到数据中**] ——选中 [定义的时间戳]

      Open **DSignTool.exe***, click [Rule Management] - [Add] - check [Add Timestamp] - select [Defined Timestamp]

   3. 点击[**数字签名**]——拖入待签名的`*.cat`文件，点击[数字签名]——选[双签名]或[SHA1]——[驱动模式]签名即可

      Click on [Digital Signature] - drag in the `*.cat` to be signed

      Click on [Digital Signature] - select [Double Signature] or [SHA1] - [Drive Mode]

4. 备注信息 / Notice：

   1. 上述教程无需自建TSA服务，如有需要自己搭建的，可以直接前往[皮卡丘公共服务测试根证书](https://test.certs.us.kg/)申请您的时间戳证书

   2. 签名时间顺序：驱动版本时间<=sys/dll签名时间<=CAT创建时间<=CAT签名时间

   3. The above tutorial does not require building your own TSA service. 

      If you need to build it yourself, go to [Pikachu Public Test CA](https://test.certs.us.kg/) Apply for your timestamp certificate

   4. Signing time sequence: Driver version time<=sys/dll Signature time<=CAT creation time<=CAT signature time




#### 附录：CAT签名使用的Inf2Cat版本号对照表

| Windows 版本                                             | 版本标识符      |
| :------------------------------------------------------- | :-------------- |
| Windows 11，版本 22H2 x64 Edition                        | 10_NI_X64       |
| Windows 11，版本 22H2 Arm64 版本                         | 10_NI_ARM64     |
| Windows 11，版本 21H2 x64 Edition                        | 10_CO_X64       |
| Windows 11，版本 21H2 Arm64 版本                         | 10_CO_ARM64     |
| Windows Server 2022 x64 版本                             | ServerFE_X64    |
| Windows Server 2022 Arm64 Edition                        | ServerFE_ARM64  |
| Windows 10，版本 22H2、21H2、21H1、20H2、2004 x86 版本   | 10_VB_X86       |
| Windows 10，版本 22H2、21H2、21H1、20H2、2004 x64 版本   | 10_VB_X64       |
| Windows 10，版本 22H2、21H2、21H1、20H2、2004 Arm64 版本 | 10_VB_ARM64     |
| Windows 10，版本 1909、1903 x86 版本                     | 10_19H1_X86     |
| Windows 10，版本 1909、1903 x64 版本                     | 10_19H1_X64     |
| Windows 10，版本 1909、1903 Arm64 Edition                | 10_19H1_ARM64   |
| Windows 10 版本 1809 x86 版本                            | 10_RS5_X86      |
| Windows 10 版本 1809 x64 版本                            | 10_RS5_X64      |
| Windows 10 版本 1809 Arm64 版本                          | 10_RS5_ARM64    |
| Windows Server 2019 x64 Edition                          | ServerRS5_X64   |
| Windows Server 2019 Arm64 Edition                        | ServerRS5_ARM64 |
| Windows 10，版本 1803 x86 Edition                        | 10_RS4_X86      |
| Windows 10，版本 1803 x64 Edition                        | 10_RS4_X64      |
| Windows 10，版本 1803 Arm64 Edition                      | 10_RS4_ARM64    |
| Windows 10，版本 1709 x86 Edition                        | 10_RS3_X86      |
| Windows 10，版本 1709 x64 Edition                        | 10_RS3_X64      |
| Windows 10，版本 1709 Arm64 Edition                      | 10_RS3_ARM64    |
| Windows 10，版本 1703 x86 Edition                        | 10_RS2_X86      |
| Windows 10，版本 1703 x64 Edition                        | 10_RS2_X64      |
| Windows 10版本 1607 x86 Edition                          | 10_AU_X86       |
| Windows 10，版本 1607 x64 Edition                        | 10_AU_X64       |
| Windows Server 2016 x64 版本                             | SERVER2016_X64  |
| Windows 10 x86 版本                                      | 10_X86          |
| Windows 10 x64 版本                                      | 10_X64          |
| Windows Server 2016                                      | Server10_X64    |
| arm 上的Windows Server 2016                              | Server10_ARM64  |






> #### 开安全启动驱动签名步骤
>
> 1、修改inf文件为时间1（在过期证书有效期内，最好是颁发的时候）
>
> 2、亚洲诚信工具签名用过期EV交叉证书签名sys文件（时间1）
>
> 3、修改系统时间为时间2（时间2>=时间1）
>
> 4、inf2cat立即生成cat
>
> 5、亚洲诚信工具签名cat文件（时间3>=时间2）

### 部署时间证书 / Deploy Timestamp Server

（一般情况不需要这个操作，你只需参考前一个“简易使用方法”内的教程即可）

1、生成一张时间戳证书([教程XCA自制CA证书并签发时间戳证书](https://code.52pika.cn/index.php/archives/330/))，或者在这里申请一张：[皮卡丘测试证书在线服务](https://code.52pika.cn/index.php/archives/330/)

2、下载[自信任时间戳工具](https://github.com/PIKACHUIM/FakeSign/raw/refs/heads/main/Releases/TimestampServer.zip)，解压并按照您的情况修改`config.json`，然后以**管理员权限**运行：`TimeStamping.exe`

3、修改`hook.ini`中的`ServerURL`项为你自建的服务器地址，参考“简易使用方法”里面的教程，正常执行签名即可

### 二合一整合包 / TSA Server + Signtool 2in1

（一般情况不需要这个操作，你只需参考前一个“简易使用方法”内的教程即可）

1、生成一张时间戳证书([教程XCA自制CA证书并签发时间戳证书](https://code.52pika.cn/index.php/archives/330/))，或者在这里申请一张：[皮卡丘测试证书在线服务](https://code.52pika.cn/index.php/archives/330/)

2、下载[自信任整合包签名](https://github.com/PIKACHUIM/FakeSign/raw/refs/heads/main/Releases/TimestampAllin1.zip)，解压并按照您的情况修改`config.json`，然后以**管理员权限**运行：`TimeStamping.exe`

3、修改`hook.ini`中的`ServerURL`项为你自建的服务器地址，参考“简易使用方法”里面的教程，正常执行签名即可

### 驱动生成CAT / Driver Cat Create Usage

```shell
inf2cat /v /os:XP_X86,Vista_X86,Vista_X64,7_X86,7_X64,8_X86,8_X64,6_3_X86,6_3_X64,10_X86,10_X64 /driver:.
```

### 添加时间方法 / Time Signature Methods

 ```shell
 signtool timestamp /t "http://<ServerHost:Port>/{SHA1|SHA256}/YYYY-MM-DDTHH:mm:ss" <待签名程序>
 ```

#### 添加时间示例 / Signature Examples

##### 单独添加时间戳（序号=1）

```shell
signtool timestamp /tp 1 /tr "http://test.timer.us.kg/2011-01-01T00:00:00" test.exe
```

##### 代码签名时间戳（SHA160）

```shell
signtool.exe sign /f Cert.pfx /p password /tr "http://test.timer.us.kg/2011-01-01T00:00:00" /as /v test.exe
```

##### 代码签名时间戳（SHA256）

```shell
signtool.exe sign /f Cert.pfx /p password /fd sha256 /tr "http://test.timer.us.kg/2011-01-01T00:00:00" /td sha256 /as /v test.exe
```

## 实现原理 / Principles

- ### 微软内核模式驱动代码签名要求：

  ![20230425155145](https://github.com/PIKACHUIM/FakeSign/raw/main/Pictures/20230425155145.jpg)

  | 适用于：       | Windows Vista、Windows 7;带安全启动的 Windows 8+ | Windows 8、Windows 8.1、Windows 10 版本 1507、1511 以及安全启动 | Windows 10 版本 1607、1703、1709 以及安全启动                | Windows 10 版本 1803 及安全启动                              |
  | :------------- | :----------------------------------------------- | :----------------------------------------------------------- | :----------------------------------------------------------- | :----------------------------------------------------------- |
  | **架构：**     | 仅 64 位，32 位不需要签名                        | 64 位、32 位                                                 | 64 位、32 位                                                 | 64 位、32 位                                                 |
  | **需要签名：** | 嵌入文件或目录文件                               | 嵌入文件或目录文件                                           | 嵌入文件或目录文件                                           | 嵌入文件或目录文件                                           |
  | **签名算法：** | SHA2                                             | SHA2                                                         | SHA2                                                         | SHA2                                                         |
  | **证书：**     | 代码完整性信任的标准根                           | 代码完整性信任的标准根                                       | Microsoft 根证书颁发机构 2010、Microsoft 根证书颁发机构、Microsoft 根证书颁发机构 | Microsoft 根证书颁发机构 2010、Microsoft 根证书颁发机构、Microsoft 根证书颁发机构 |

- ### 微软禁用内核驱动强制签名方法：

  - Windows 10 1607 之后UEFI引导模式，并且开启Secure Boot选项：

    - 无法开启测试模式，*不能通过修改BCD解决*，**可以使用EFIGuard**

    - 每次可以开机进入<u>高级模式</u>-选择<u>禁用内核驱动强制签名</u>启动

  - Windows 10 1607 之前，Win8/8.1/7/Vista，或者关闭Secure Boot：

    - **开启测试模式**： 

      ```shell
      bcdedit /enum all
      bcdedit /set {default} testsigning on
      bcdedit /set nointegritychecks on
      bcdedit /set testsigning on
      bcdedit /debug ON
      bcdedit /bootdebug ON
      ```

    - 也可以每次可以开机进入<u>高级模式</u>-选择<u>禁用内核驱动强制签名</u>启动

- ### 伪造签名原理

  ![伪造签名原理](https://github.com/PIKACHUIM/FakeSign/raw/main/Pictures/20230425160222.jpg)

  - #### 自建伪造时间戳服务器

    **您可以直接前往[皮卡丘公共服务测试根证书](https://test.certs.us.kg/)一键申请您自己的时间戳证书，无需再自建，自建教程：**

    > - 自建CA证书（CA=TRUE，密钥用法=Certificate Signing, Off-line CRL Signing, CRL Signing，增强型密钥用法=2.5.29.32.0）
    >
    > - 自签时间戳签名证书（密钥用途=Digital Signature，增强型密钥用法=时间戳 ，OCSP-URL，CRL-URL）
    >
    > - 设置CRL地址（推荐Nginx，把CRL文件放入对应地址），或者设置OCSP服务器（OpenSSL OCSP）
    >
    > - 搭建并启动时间戳响应服务器（*RFC*3161以及Authenticode格式 ，需要同时支持SHA1+SHA256）
    
    



## 自建时间服务 / TSA Server

上述教程无需自建TSA服务，如有需要自己搭建的，可以直接前往[皮卡丘公共服务测试根证书](https://test.certs.us.kg/)申请您的时间戳证书

The above tutorial does not require building your own TSA service. 

If you need to build it yourself, go to [Pikachu Public Test CA](https://test.certs.us.kg/) Apply for your timestamp certificate

### 直接修改配置文件（推荐）

- #### 打开文件

  ```json
  {
    "listen_path": "/TSA/",
    "listen_addr": "localhost",
    "listen_port": "1003",
    "server_urls": "http://test.timer.us.kg/",
    "server_cert": "TSA.crt",
    "server_keys": "TSA.key",
    "server_fake": "true",
    "windows_url": "",
    "linuxos_url": "",
    "signers_url": "",
    "githubs_url": "https://github.com/PIKACHUIM/FakeSign",
    "article_url": "https://code.52pika.cn/index.php/archives/277/",
    "service_url": "https://test.certs.us.kg/"
  }
  ```

  

### VS编译构建时间戳服务器

- #### 下载项目

  ```shell
  git clone https://github.com/PIKACHUIM/FakeSign.git
  ```

- #### 修改代码

  编辑：`TimeTool/Develop/TimeStamping/Program.cs`

  如果要使用伪造服务器，则此处填写`true`，如果要使用真实时间，应当填写`false`

  ```c#
  static readonly string supportFake = @"true";
  ```

- #### 编译构建

  输出：`TimeTool/Develop/TimeStamping/bin/Debug`

### Windows部署服务（推荐）

1. 创建一个CA和时间戳证书，参考[XCA自制CA证书并签发时间戳证书](https://code.52pika.cn/index.php/archives/330/)
2. 放置证书文件到当前的运行目录内，需要参考下面的文件说明：
   - **TSA.crt 证书Base64编码**
   - **TSA.key 密钥Base64编码**
3. 双击：`TimeStamping.exe`即可运行

### Ubuntu部署服务（不推荐）

#### 安装Wine

```shell
sudo dpkg --add-architecture i386
sudo apt-get install wine mono-complete winetricks wine32 winbind
```

#### 安装.Net

- ##### 自动安装

  ```shell
  sudo winetricks dotnet45
  ```

- #### 手动安装

  1. 下载文件 [wine-mono-7.4.0-x86.msi](Download/wine-mono-7.4.0-x86.msi) 

  2. ```shell
     wine uninstaller
     wine64 uninstaller
     ```

     安装上一步下载的MSI文件(wine-mono-7.4.0-x86.msi)

- #### 运行服务

  创建一个CA和时间戳证书，参考[XCA自制CA证书并签发时间戳证书](https://code.52pika.cn/index.php/archives/330/)
  
  放置证书文件到当前的运行目录内，需要参考下面的文件说明：
  
  - **TSA.crt 证书Base64编码**
  - **TSA.key 密钥Base64编码**
  
  ```shell
  wine TimeStamping.exe
  ```

## 构建签名工具 / Build Sign Tool

正常情况不需要自行搭建服务器，如果有需要使用自己的服务器，请继续阅读

Under normal circumstances, it is not necessary to set up a server on your own. 

If you need to use your own server, please continue reading.

### 直接修改hook.ini文件（推荐）

- #### 修改文件

  ```ini
  [TimeStamp]
  TimeStamp=2015-01-01T00:00:00
  ServerURL=http://localhost:1003/TSA/
  ```

### VS编译HookSigntool

- #### 下载项目

  ```shell
  git clone https://github.com/PIKACHUIM/FakeSign.git
  ```

- #### 修改代码

  编辑：`SignTool/Hooktool/main.cpp`，取消注释下列行：

  将里面的`http://*********/fake/RSA/`修改为`http://你的地址:端口/路径`
  
  ```c++
  wcscat(buf, L"http://*********/fake/RSA/");
  ```

- #### 编译构建

  输出：`SignTool/Hooktool/bin/Debug`
  
  

## 参考资料 / Reference

> [1] 时间戳签名库以及本地Demo服务器，可以倒填时间制造有效签名，JemmyloveJenny，吾爱破解，https://www.52pojie.cn/thread-908684-1-1.html
>
> [2] 亚洲诚信数字签名工具修改版 自定义时间戳 驱动签名，JemmyloveJenny，吾爱破解，https://www.52pojie.cn/thread-1027420-1-1.html
>
> [3] 关于Windows驱动签名认证的大致总结，[ANY_LNK](https://space.bilibili.com/1337311595)，BiliBili，https://www.bilibili.com/read/cv17812616
>
> [4] 数字证书伪造与利用（仅方便用于驱动开发人员的调试，不得非法使用），MIAIONE，BiliBili，https://www.bilibili.com/read/cv9802857/
