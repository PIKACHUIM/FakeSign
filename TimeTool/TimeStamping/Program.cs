using System;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using System.Threading;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using LibTimeStamp;

namespace FakeStamping
{
    class Program
    {
        static TSResponder tsResponder;
        static string listen_path = @"/TSA/";
        static string listen_addr = @"localhost";
        static string listen_port = @"1003";
        static string server_urls = @"http://time.pika.net.cn/fake/RSA/";
        static string server_cert = @"TSA.crt";
        static string server_keys = @"TSA.key";
        static string server_fake = @"true";
        static string windows_url = @"https://github.com/PIKACHUIM/CA/raw/main/fake/FakeCACert.zip";
        static string linuxos_url = @"https://github.com/PIKACHUIM/CA/raw/main/fake/CA-ALLCERT.zip";
        static string signers_url = @"https://github.com/PIKACHUIM/FakeSign/raw/main/SignTool/Released/HookSigntool-PikaFakeTimers.zip";
        static string githubs_url = @"https://github.com/PIKACHUIM/FakeSign";
        static string article_url = @"https://code.52pika.cn/index.php/archives/277/";
        static string service_url = @"https://cert.pika.net.cn/fake/";

        static string Readjson(string key)
        {
            string jsonfile = "config.json";
            try
            {
                string json_text = File.ReadAllText(jsonfile);
                JObject json_data = JObject.Parse(json_text);
                return json_data[key].ToString();
            }
            catch
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("   [Error!!] Read file or keys failed: " + jsonfile);
                Console.ForegroundColor = ConsoleColor.White;
                return "";
            }
        }

        static void Main(string[] args)
        {
            Program.ReadJson();
            Program.ShowDesc();
            try
            {
                tsResponder = new TSResponder(File.ReadAllBytes((string)server_cert),
                                              File.ReadAllBytes((string)server_keys), "SHA1");
            }
            catch
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("   [Error!!] Can NOT Find TimeStamp Cert File");
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("   [Warning] Please Check Your Cert and Key!");
                Console.ForegroundColor = ConsoleColor.White;
                return;
            }
            HttpListener listener = new HttpListener();
            try
            {
                listener.AuthenticationSchemes = AuthenticationSchemes.Anonymous;
                listener.Prefixes.Add(@"http://" + listen_addr + ":" + listen_port + listen_path);
                listener.Start();
            }
            catch
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("   [Error!!] TimeStamp Responder Can NOT Listen Port: " + listen_port);
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("   [Warning] Please Run as Administrator and Check Port!");
                Console.ForegroundColor = ConsoleColor.White;
                //Console.ReadLine();
                return;
            }
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("   [Success] Your TimeStamp HTTP Server Started Successfully!");
            Console.WriteLine("   [Success] TimeStamp Responder: http://" + listen_addr + ":" + listen_port + listen_path);
            Console.ForegroundColor = ConsoleColor.White;
            Console.WriteLine();
            while (true)
            {
                HttpListenerContext ctx = listener.GetContext();
                ThreadPool.QueueUserWorkItem(new WaitCallback(TaskProc), ctx);
            }
        }

        static void ShowDesc()
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.Title = "Pikachu TimeStamp Responder";
            Console.WriteLine(
                "==============================================================\r\n" +
                "|                                                            |\r\n" +
                "|           Pikachu RFC3161 Time Stamping Responder          |\r\n" +
                "|                 Last Updated: Nov 01 2024                  |\r\n" +
                "|                                                            |\r\n" +
                "|------------------------------------------------------------|\r\n" +
                "|  Notice: This Responder Should Run in Administrator Mode!! |\r\n" +
                "|  Server Accept UTC Time in the Form of yyyy-MM-ddTHH:mm:ss |\r\n" +
                "|  For Example: http://your_ip:port/path/2020-01-01T00:00:00 |\r\n" +
                "==============================================================\r\n"
                );
            Console.ForegroundColor = ConsoleColor.Blue;
            Console.WriteLine("   [Message] TimeStamp Responder: " + @"http://" + listen_addr + ":" + listen_port + listen_path);
            Console.WriteLine("   [Message] TimeStamp Cert File: " + server_cert);
            Console.WriteLine("   [Message] TimeStamp Keys File: " + server_keys);
        }

        static void ReadJson()
        {
            Program.listen_path = Program.Readjson("listen_path");
            Program.listen_addr = Program.Readjson("listen_addr");
            Program.listen_port = Program.Readjson("listen_port");
            Program.server_urls = Program.Readjson("server_urls");
            Program.server_cert = Program.Readjson("server_cert");
            Program.server_keys = Program.Readjson("server_keys");
            Program.server_fake = Program.Readjson("server_fake");
            Program.windows_url = Program.Readjson("windows_url");
            Program.linuxos_url = Program.Readjson("linuxos_url");
            Program.signers_url = Program.Readjson("signers_url");
            Program.githubs_url = Program.Readjson("githubs_url");
            Program.article_url = Program.Readjson("article_url");
            Program.service_url = Program.Readjson("service_url");
        }

        static void TaskProc(object o)
        {
            HttpListenerContext ctx = (HttpListenerContext)o;
            ctx.Response.StatusCode = 200;
            HttpListenerRequest request = ctx.Request;
            HttpListenerResponse response = ctx.Response;
            string usage_time;
            if (server_fake == "true")
                usage_time = "2020-01-01T00:00:00";
            else
                usage_time = "";
            if (ctx.Request.HttpMethod != "POST")
            {
                StreamWriter writer = new StreamWriter(response.OutputStream, Encoding.ASCII);

                writer.WriteLine("<h1>Pikachu RFC3161 Time Stamping Responder</h1>" +

                                 "<h2>Server Detail</h2>" +
                                 "<blockquote><ul>" +
                                 "<li><span>ServerURL: " + server_urls + "</span></li>" +
                                 "<li><span>FakeTimer: " + server_fake + "</span></li>" +
                                 "</ul></blockquote></li></ul>" +

                                 "<h2>Trust CA Cert</h2>" +
                                 "<blockquote><ul>" +
                                 "<li><span>Win32: </span><a href='" + windows_url + "'>" +
                                 "<span>CA_Installer.exe</span></a></li>" +
                                 "<li><span>Other: </span><a href='" + linuxos_url + "'>" +
                                 "<span>CA_Installer.zip</span></a></li>" +
                                 "</ul></blockquote></li></ul>" +

                                 "<h2>Signing Usage</h2>" +
                                     "<blockquote><ul>" +
                                         "<li><h3>Microsoft SignTool</h3>" +
                                             "<blockquote><ul>" +
                                                 "<li>Sign Code: <code>signtool.exe sign /v /f  \"Cert.pfx\" /t " + server_urls + usage_time + " \"UnsignFile.exe\" </code></li>" +
                                                 "<li>New Stamp: <code>signtool.exe signtool timestamp /t &nbsp;&nbsp;&nbsp;" + server_urls + usage_time + " \"UnsignFile.exe\" </code></li>" +
                                                 "<li>Add Stamp: <code>signtool.exe signtool timestamp /tp 1 " + server_urls + usage_time + " \"UnsignFile.exe\" </code></li>" +
                                             "</ul></blockquote>" +
                                         "</li>" +
                                         "<li><h3>TrustAsia SignTool</h3>" +
                                             "<blockquote><ul>" +
                                                 "<li><span>Pikachu Fake CA TS: </span><a href='" + signers_url + "'>" +
                                                    "<span>TrustAsia SignTool - FakeTime</span></a></li>" +
                                             "</ul></blockquote>" +
                                         "</li>" +
                                      "</ul></blockquote>" +
                                 "<h2>Project Pages</h2>" +
                                 "<blockquote><ul>" +
                                 "<li><span>Github: </span><a href='" + githubs_url + "'><span>Fake Signs - PIKACHUIM</span></a></li>" +
                                 "<li><span>Usages: </span><a href='" + article_url + "'><span>Fake Timestamp Servers</span></a></li>" +
                                 "<li><span>CA Web: </span><a href='" + service_url + "'><span>Pikachu Test CA Online</span></a></li>" +
                                 "</ul></blockquote></li></ul>" +
                                 "<style>*{font-family:Consolas}</style>"
                                 );
                writer.Close();
                ctx.Response.Close();
            }
            else
            {
                try
                {
                    string log = "";
                    string date = request.RawUrl.Remove(0, listen_path.Length);
                    DateTime signTime;
                    signTime = DateTime.UtcNow;
                    if (server_fake == "true")
                    {
                        Console.WriteLine("   [Success] Fake Stamp Responder: " + server_fake);
                        if (!DateTime.TryParseExact(date, "yyyy-MM-dd'T'HH:mm:ss",
                                                    CultureInfo.InvariantCulture,
                                                    DateTimeStyles.AdjustToUniversal | DateTimeStyles.AssumeUniversal,
                                                    out signTime))
                        {
                            signTime = DateTime.UtcNow;
                            Console.WriteLine("   [Warning] Can Not Process Time: " + date);
                        }
                        else
                        {
                            Console.WriteLine("   [Success] Fake Stamp Responder: " + date);
                        }
                    }
                    else
                    {
                        Console.WriteLine("   [Success] Real Stamp Responder!");
                    }
                    BinaryReader reader = new BinaryReader(request.InputStream);
                    byte[] bRequest = reader.ReadBytes((int)request.ContentLength64);

                    bool RFC;
                    byte[] bResponse = tsResponder.GenResponse(bRequest, signTime, out RFC);
                    if (RFC)
                    {
                        response.ContentType = "application/timestamp-reply";
                        log += "   [Success] RFC3161 Time Stamping ";
                    }
                    else
                    {
                        response.ContentType = "application/octet-stream";
                        log += "   [Success] Authenticode Stamping ";
                    }
                    log += signTime;
                    BinaryWriter writer = new BinaryWriter(response.OutputStream);
                    writer.Write(bResponse);
                    writer.Close();
                    ctx.Response.Close();
                    Console.WriteLine(log);
                }
                catch (Exception e)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine(DateTime.Now.ToString("yyyy-M-d HH:mm:ss") + " ERROR " + e.Message);
                    Console.ForegroundColor = ConsoleColor.White;
                    ctx.Response.Close();
                }

            }
        }
    }
}
