using System;
using System.IO;
using System.Net;
using System.Text;
using System.Configuration;
using System.Web;

namespace Dashbord
{
    // =====================================================================
    // ทดสอบส่งแจ้งเตือน LINE (Messaging API แทน LINE Notify ที่ปิดบริการแล้ว)
    //   Web.config <appSettings> : LineChannelAccessToken = Channel access token (long-lived)
    //   Recipient : User ID (U + 32 ตัว) / Group ID (C...) -> push
    //               พิมพ์ ALL -> broadcast ถึงทุกคนที่แอด OA เป็นเพื่อน (ไม่ต้องรู้ ID)
    //   หมายเหตุ : เดิมใช้ async + GetAwaiter().GetResult() ใน WebForms -> ค้าง (deadlock) ได้ จึงเปลี่ยนเป็นแบบ sync
    // =====================================================================
    public partial class LineAert_Water : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
        }

        protected void btnSend_Click(object sender, EventArgs e)
        {
            try
            {
                string detail;
                bool ok = SendLineMessage(txtRecipient.Text.Trim(), txtMessage.Text.Trim(), out detail);
                lblResult.ForeColor = ok ? System.Drawing.Color.Green : System.Drawing.Color.Red;
                lblResult.Text = HttpUtility.HtmlEncode(detail);
            }
            catch (Exception ex)
            {
                lblResult.ForeColor = System.Drawing.Color.Red;
                lblResult.Text = "Error: " + HttpUtility.HtmlEncode(ex.Message);
            }
        }

        /// <summary>ส่งข้อความ LINE · คืน true เมื่อ LINE ตอบ 200</summary>
        public static bool SendLineMessage(string recipient, string message, out string detail)
        {
            string token = ConfigurationManager.AppSettings["LineChannelAccessToken"];
            if (String.IsNullOrWhiteSpace(token))
                throw new Exception("ไม่พบ LineChannelAccessToken ใน Web.config");
            if (String.IsNullOrEmpty(recipient))
                throw new Exception("กรุณากรอก Recipient ID (หรือพิมพ์ ALL เพื่อส่งถึงทุกคนที่แอดเพื่อน)");
            if (String.IsNullOrEmpty(message))
                throw new Exception("กรุณากรอกข้อความ");

            return SendLineRaw(recipient, "[{\"type\":\"text\",\"text\":" + JsonString(message) + "}]", out detail);
        }

        /// <summary>ส่งข้อความ LINE แบบกำหนดเอง (messagesJson = JSON array ของ message object เช่น text / flex) · คืน true เมื่อ LINE ตอบ 200</summary>
        public static bool SendLineRaw(string recipient, string messagesJson, out string detail)
        {
            string token = ConfigurationManager.AppSettings["LineChannelAccessToken"];
            if (String.IsNullOrWhiteSpace(token))
                throw new Exception("ไม่พบ LineChannelAccessToken ใน Web.config");
            if (String.IsNullOrEmpty(recipient))
                throw new Exception("กรุณากรอก Recipient ID (หรือพิมพ์ ALL เพื่อส่งถึงทุกคนที่แอดเพื่อน)");
            bool broadcast = recipient.Equals("ALL", StringComparison.OrdinalIgnoreCase);
            string msgs = "\"messages\":" + messagesJson;
            string json = broadcast ? "{" + msgs + "}" : "{\"to\":" + JsonString(recipient) + "," + msgs + "}";
            string url = broadcast ? "https://api.line.me/v2/bot/message/broadcast" : "https://api.line.me/v2/bot/message/push";

            ServicePointManager.SecurityProtocol |= (SecurityProtocolType)3072; // TLS 1.2
            byte[] data = Encoding.UTF8.GetBytes(json);
            HttpWebRequest req = (HttpWebRequest)WebRequest.Create(url);
            req.Method = "POST";
            req.ContentType = "application/json; charset=utf-8";
            req.Headers.Add("Authorization", "Bearer " + token.Trim());
            req.Headers.Add("X-Line-Retry-Key", Guid.NewGuid().ToString());   // กันส่งซ้ำถ้า retry
            req.ContentLength = data.Length;
            req.Timeout = 15000;

            try
            {
                using (Stream s = req.GetRequestStream()) s.Write(data, 0, data.Length);
                using (HttpWebResponse res = (HttpWebResponse)req.GetResponse())
                {
                    detail = "ส่งสำเร็จ (" + (broadcast ? "broadcast ทุกคน" : "push") + ") HTTP " + (int)res.StatusCode +
                             " · " + DateTime.Now.ToString("HH:mm:ss");
                    return true;
                }
            }
            catch (WebException ex)
            {
                HttpWebResponse res = ex.Response as HttpWebResponse;
                detail = ex.Message;
                if (res != null)
                    using (StreamReader reader = new StreamReader(res.GetResponseStream()))
                        detail = "HTTP " + (int)res.StatusCode + ": " + reader.ReadToEnd() + Hint((int)res.StatusCode);
                return false;
            }
        }

        static string Hint(int code)
        {
            switch (code)
            {
                case 400: return "  → ตรวจ Recipient ID (User ID ขึ้นต้น U ยาว 33 ตัว) และผู้รับต้องแอด OA เป็นเพื่อนแล้ว";
                case 401: return "  → Token ผิด/หมดอายุ : ออก Channel access token (long-lived) ใหม่ใน LINE Developers";
                case 403: return "  → บัญชีนี้ไม่มีสิทธิ์ใช้ API นี้";
                case 429: return "  → เกินโควตาข้อความของเดือนนี้ หรือส่งถี่เกินไป";
                default: return "";
            }
        }

        private static string JsonString(string value)
        {
            return new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(value);
        }
    }
}
