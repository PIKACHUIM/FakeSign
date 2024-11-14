欢迎使用JemmyLoveJenny修改版的数字签名工具！
本工具基于TrustAsia亚洲诚信数字签名工具专业版，版本3.2.0修改
修改版本V2.1

修改版本与原版的区别：
1.在原版中，若想使用已过期的数字证书进行签名，则需要修改整个系统的时间。在修改版本中，无需修改系统时间即可使用过期的证书进行签名。
2.修改了原版时间戳列表，删除TrustAsia时间戳（TrustAsia时间戳与Symantec时间戳是同一个），增加了我自建的时间戳服务器。该自建时间戳
  服务器可以伪造证书有效期内的时间戳签名，使过期证书的签名变为有效。
  若将我的 JemmyLoveJenny EV Root CA 添加进系统根证书信任列表，过期的代码签名证书+此专用时间戳可以直接通过WinXP-Win10所有系统
  的驱动加载签名检查。（证书必须有MicrosoftCodeVerificationRoot的交叉签名，且颁发日期在2015-07-29以前）
  EVRootCA.crt就是我自签名的根证书。为了便于添加信任，我制作了注册表添加方式，运行EVRootCA.reg也可以达到的目的。

修改过程：
1.编译HookSigntool.dll，使用微软Detur库Hook了签名工具的函数 crypt32.dll!CertVerifyTimeValidity ， mssign32!SignerSign ， 
  mssign32!SignerTimeStamp ， mssign32!SignerTimeStampEx2 ， mssign32!SignerTimeStampEx3 ， kernel32.dll!GetLocalTime 这6个函数。
2.修改DSigntool.exe，PE头部导入表添加 HookSigntool.dll!attach 达到Hook函数的目的。
3.修改Dsigntool.exe，将TrustAsia的时间戳地址更换为我自己的专用时间戳。

用法：
1.安装原版签名工具，获取地址为 https://www.trustasia.com/sign-tools
2.下载本修改版工具，替换文件到安装位置。
3.安装时间戳服务器根证书，运行EVRootCA.reg，或者将EVRootCA.crt导入根证书。
4.修改Hook.ini中的Timestamp值，格式为 "yyyy-MM-dd'T'HH:mm:ss" UTC时间
  北京时间是UTC+8，所以时间需要减掉8小时才能变成UTC时间
  举几个例子：
  北京时间 2011-04-01 08:00:00，时间戳设置为 2011-04-01T00:00:00
  北京时间 2019-03-10 10:25:34，时间戳设置为 2019-03-10T02:25:34
  注意！自定义的时间戳日期最好接近证书的颁发时间，因为大部分泄露的证书已经被CA吊销，自定义的时间必须在证书吊销之前才能通过驱动签名验证！
5.可以用config和ts两个参数启动DSigntool.exe。
  "DSigntool.exe -config <iniFile>" 可以指定在其他位置的ini文件
  "DSigntool.exe -ts <Timestamp>" 可以指定伪造时间戳的签名时间，格式同上
  两个参数可以同时使用，ts能够覆盖ini中设置的Timestamp
6.自建时间戳也可以配合signtool使用
  时间戳服务器的地址是 http://tsa.pki.jemmylovejenny.tk/SHA1/ 或 http://tsa.pki.jemmylovejenny.tk/SHA256/
  这两个地址都支持 Authenticode 和 RFC3161 时间戳，也就是说，在微软signtool中使用 /t "<URL>" 或者 /tr "<URL>" 都是可以的，可以根据自己的
  需要打不同协议的时间戳 （Authenticode时间戳兼容性比较好，支持XP）
  两个地址的区别就是，时间戳后签名证书链不同，一个证书链哈希算法是SHA1，另一个是SHA256，其他没有区别。
  第一个时间戳签名用 【signtool timestamp /t "<URL>" <filename>】
  之后多个签名的时间戳用 【signtool timestamp /tp <index> /tr "<URL>" <filename>】
  比如test.exe有两个无时间戳的签名，那么打时间戳的命令为
  【signtool timestamp /t "http://tsa.pki.jemmylovejenny.tk/SHA1/2011-04-01T00:00:00" test.exe】
  【signtool timestamp /tp 1 /tr "http://tsa.pki.jemmylovejenny.tk/SHA256/2011-04-01T00:00:00" test.exe】
  