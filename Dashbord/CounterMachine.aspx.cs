using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;

namespace Dashbord
{
    /// <summary>
    /// CounterMachine.aspx
    ///   POST  (JSON body)                -> รับข้อมูลจาก Node-RED (IoT Box) + คำนวณ Count
    ///   GET   ?format=json               -> JSON ทุกเครื่อง (Machine_Monitor.aspx ดึงไปแสดง)
    ///   GET   ?format=json&machine=MC26  -> JSON เฉพาะเครื่อง
    ///   GET   (ไม่มี format)              -> หน้า Counter Machine
    /// </summary>
    public partial class CounterMachine : Page
    {
        static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
        string _apiOutput;   // != null -> ตอบเป็น API (ไม่วาดหน้า / Master Page)

        protected void Page_Load(object sender, EventArgs e)
        {
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            string method = Request.HttpMethod.ToUpperInvariant();

            if (method == "OPTIONS")
            {
                Response.AppendHeader("Access-Control-Allow-Origin", "*");
                Response.AppendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
                Response.AppendHeader("Access-Control-Allow-Headers", "Content-Type, X-Api-Key");
                Response.StatusCode = 204;
                _apiOutput = "";
                return;
            }

            if (method == "POST")
            {
                HandlePost();
                return;
            }

            // GET ?format=log&machine=MC27[&day=yyyy-MM-dd] -> ประวัติสถานะ / Downtime ของวันผลิต (popup ในการ์ด)
            if (method == "GET" && string.Equals(Request.QueryString["format"], "log", StringComparison.OrdinalIgnoreCase))
            {
                string mc = Request.QueryString["machine"];
                if (string.IsNullOrEmpty(mc)) { Reply(400, new { ok = false, error = "missing 'machine'" }); return; }
                DateTime day;
                DateTime dayStart = DateTime.TryParseExact(Request.QueryString["day"], "yyyy-MM-dd",
                        System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out day)
                    ? day.Date.AddHours(CounterStore.ProdDayStart(DateTime.Now).Hour)
                    : CounterStore.ProdDayStart(DateTime.Now);
                Reply(200, Request.QueryString["kind"] == "ng" ? ErpQuality.NgDetail(mc, dayStart) : OeeDb.StatusLog(mc, dayStart));
                return;
            }

            // GET ?format=oee&from=yyyy-MM-dd&to=yyyy-MM-dd[&proc=Injection][&machine=MC27]
            //   -> OEE ย้อนหลัง สูตรเดียวกับหน้านี้ (A,P จากเครื่อง · Q จาก ERP) สำหรับหน้า OEE Dashboard
            if (method == "GET" && string.Equals(Request.QueryString["format"], "oee", StringComparison.OrdinalIgnoreCase))
            {
                var ci = System.Globalization.CultureInfo.InvariantCulture;
                var ds = System.Globalization.DateTimeStyles.None;
                DateTime today = CounterStore.ProdDayStart(DateTime.Now).Date, f, t;
                if (!DateTime.TryParseExact(Request.QueryString["from"] ?? "", "yyyy-MM-dd", ci, ds, out f)) f = today;
                if (!DateTime.TryParseExact(Request.QueryString["to"] ?? "", "yyyy-MM-dd", ci, ds, out t)) t = f;
                if ((t - f).TotalDays > 92) { Reply(400, new { ok = false, error = "ช่วงวันยาวเกิน 92 วัน" }); return; }
                Reply(200, OeeReport.Build(f, t, Request.QueryString["proc"], Request.QueryString["machine"]));
                return;
            }

            // GET ?format=oeedaily&machine=MC13&from=yyyy-MM-dd&to=yyyy-MM-dd -> OEE รายวันของเครื่องเดียว (แท็บ OEE ใน popup)
            if (method == "GET" && string.Equals(Request.QueryString["format"], "oeedaily", StringComparison.OrdinalIgnoreCase))
            {
                var ci = System.Globalization.CultureInfo.InvariantCulture;
                var ds = System.Globalization.DateTimeStyles.None;
                string mc = Request.QueryString["machine"];
                if (string.IsNullOrEmpty(mc)) { Reply(400, new { ok = false, error = "missing 'machine'" }); return; }
                DateTime today = CounterStore.ProdDayStart(DateTime.Now).Date, f, t;
                if (!DateTime.TryParseExact(Request.QueryString["to"] ?? "", "yyyy-MM-dd", ci, ds, out t)) t = today;
                if (!DateTime.TryParseExact(Request.QueryString["from"] ?? "", "yyyy-MM-dd", ci, ds, out f)) f = t.AddDays(-13);
                if (Math.Abs((t - f).TotalDays) > 92) { Reply(400, new { ok = false, error = "range longer than 92 days" }); return; }
                Reply(200, OeeReport.Daily(mc, f, t));
                return;
            }

            if (method == "GET" && string.Equals(Request.QueryString["format"], "json", StringComparison.OrdinalIgnoreCase))
            {
                DateTime now = DateTime.Now;
                Reply(200, new Dictionary<string, object> {
                    { "serverTime", now.ToString("yyyy-MM-dd HH:mm:ss") },
                    { "dayStart", CounterStore.ProdDayStart(now).ToString("yyyy-MM-dd HH:mm") },
                    { "machines", CounterStore.Snapshot(Request.QueryString["machine"]) },
                    { "db", OeeDb.Info() },
                    { "erp", ErpQuality.Info() } });
                return;
            }

            if (method != "GET")
                Reply(405, new { ok = false, error = "method not allowed" });
            // GET ปกติ -> แสดงหน้า (CounterMachine.aspx)
        }

        void HandlePost()
        {
            if (CounterStore.API_KEY.Length > 0 && Request.Headers["X-Api-Key"] != CounterStore.API_KEY)
            {
                Reply(401, new { ok = false, error = "invalid api key" });
                return;
            }

            string body;
            using (var r = new StreamReader(Request.InputStream, Encoding.UTF8)) body = r.ReadToEnd();

            Dictionary<string, object> d;
            try { d = Json.Deserialize<Dictionary<string, object>>(body); }
            catch (Exception ex) { Reply(400, new { ok = false, error = "bad json: " + ex.Message }); return; }

            string id = CounterStore.GetStr(d, "machine");
            if (string.IsNullOrEmpty(id)) { Reply(400, new { ok = false, error = "missing 'machine'" }); return; }

            Reply(200, new Dictionary<string, object> { { "ok", true }, { "data", CounterStore.Update(d, id) } });
        }

        void Reply(int code, object body)
        {
            Response.StatusCode = code;
            Response.TrySkipIisCustomErrors = true;
            Response.ContentType = "application/json; charset=utf-8";
            Response.AppendHeader("Access-Control-Allow-Origin", "*");
            _apiOutput = Json.Serialize(body);
        }

        protected override void Render(HtmlTextWriter writer)
        {
            if (_apiOutput != null) writer.Write(_apiOutput);   // API: ส่ง JSON อย่างเดียว ไม่มี Master Page
            else base.Render(writer);
        }
    }
}
