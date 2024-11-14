# Pikachu RFC3161 Time Stamping Responder

# 皮卡丘RFC3161时间戳响应服务

## Detail / 服务信息

- ### FakeTime / 伪造时间签名: False / 不可用

## Usage / 使用方法

- ### SignTool

  ```
  signtool.exe sign /v /f "your_cert.pfx" /p "pfx password" /t "http://time.pika.net.cn/RSA/" "unsign file"
  ```

- ### DSignTool

  > - ##### Pikachu Fake CA （推荐）：[亚洲诚信签名工具 / TrustAsia SignTool - PikaFakeTimers](https://github.com/PIKACHUIM/FakeSign/raw/main/SignTool/Released/HookSigntool-PikaFakeTimers.zip)
  >
  > - ##### Pikachu Root CA （备用）：[亚洲诚信签名工具 / TrustAsia SignTool - PikaRealTimers](https://github.com/PIKACHUIM/FakeSign/raw/main/SignTool/Released/HookSigntool-PikaRealTimers.zip)
  >
  > - ##### JemmyLoveJenny（备用）：[亚洲诚信签名工具 / TrustAsia SignTool - JemmyLoveJenny](https://github.com/PIKACHUIM/FakeSign/raw/main/SignTool/Released/HookSigntool-JemmyLoveJenny.zip)