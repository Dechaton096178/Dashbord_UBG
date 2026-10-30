using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;

namespace Dashbord
{
    /// <summary>
    /// WeightLog.aspx  — น้ำหนักจากเครื่องชั่ง
    ///   POST (JSON)  {"machine":"Extruder03","weight":40.12,"unit":"g","stable":true,"model":"Super Range","barcode":"S-Range","min":40,"max":40.3,"result":"OK"}
    ///                -> บันทึกลง MySQL weight_log (รับเฉพาะน้ำหนัก > 1.0 g)
    ///   GET ?format=json&machine=Extruder03&day=yyyy-MM-dd -> รายการชั่งของวันผลิต 07:45-07:45
    ///   POST (JSON)  {"live":true, ...}  -> ค่าสดจากตราชั่ง เก็บในหน่วยความจำอย่างเดียว (ไม่ลง DB)
    ///   GET ?format=live&machine=Extruder03 -> ค่าสดล่าสุด (หน้าเว็บดึงทุก 0.4 วิ ให้ตัวเลขวิ่งตามตราชั่ง)
    ///   GET (ไม่มี format) -> หน้าแสดงผล
    /// </summary>
    public partial class WeightLog : Page
    {
        static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        string _apiOutput;
        public const double MIN_GRAMS = 1.0;   // น้ำหนักต้องมากกว่าค่านี้ (กรัม) ถึงจะบันทึก
        public const int LIVE_STALE_MS = 15000; // ไม่มีค่าสดเกิน 15 วิ = ตราชั่งออฟไลน์

        // ค่าสดล่าสุดของแต่ละเครื่อง (อยู่ในหน่วยความจำ IIS เท่านั้น)
        class LiveVal { public double Weight; public string Unit, Model, Result, Barcode; public bool Stable; public double? Min, Max; public int Code; public DateTime At; }
        static readonly ConcurrentDictionary<string, LiveVal> Live = new ConcurrentDictionary<string, LiveVal>(StringComparer.OrdinalIgnoreCase);

        protected void Page_Load(object sender, EventArgs e)
        {
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            string method = Request.HttpMethod.ToUpperInvariant();
            if (method == "POST") { HandlePost(); return; }
            if (method == "GET" && string.Equals(Request.QueryString["format"], "json", StringComparison.OrdinalIgnoreCase))
            {
                DateTime day;
                DateTime start = DateTime.TryParseExact(Request.QueryString["day"] ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out day)
                    ? day.Date + CounterStore.DAY_START
                    : CounterStore.ProdDayStart(DateTime.Now);
                Reply(200, OeeDb.WeightReport(Clean(Request.QueryString["machine"]), start));
                return;
            }
            if (method == "GET" && string.Equals(Request.QueryString["format"], "live", StringComparison.OrdinalIgnoreCase))
            {
                string mc = Clean(Request.QueryString["machine"]);
                LiveVal v;
                if (string.IsNullOrEmpty(mc) || !Live.TryGetValue(mc, out v)) { Reply(200, new { ok = true, machine = mc, online = false }); return; }
                long age = (long)(DateTime.Now - v.At).TotalMilliseconds;
                Reply(200, new { ok = true, machine = mc, online = age < LIVE_STALE_MS, ageMs = age, weight = v.Weight, unit = v.Unit, stable = v.Stable,
                                 model = v.Model, barcode = v.Barcode, code = v.Code, min = v.Min, max = v.Max, result = v.Result, at = v.At.ToString("yyyy-MM-dd HH:mm:ss") });
                return;
            }
            if (method != "GET") Reply(405, new { ok = false, error = "method not allowed" });
        }

        void HandlePost()
        {
            if (CounterStore.API_KEY.Length > 0 && Request.Headers["X-Api-Key"] != CounterStore.API_KEY)
            { Reply(401, new { ok = false, error = "invalid api key" }); return; }

            string body;
            using (var r = new StreamReader(Request.InputStream, Encoding.UTF8)) body = r.ReadToEnd();
            Dictionary<string, object> d;
            try { d = Json.Deserialize<Dictionary<string, object>>(body); }
            catch (Exception ex) { Reply(400, new { ok = false, error = "bad json: " + ex.Message }); return; }
            if (d == null) { Reply(400, new { ok = false, error = "empty body" }); return; }

            string machine = Clean(Str(d, "machine"));
            if (string.IsNullOrEmpty(machine)) { Reply(400, new { ok = false, error = "missing 'machine'" }); return; }
            double w;
            if (!double.TryParse(Str(d, "weight"), NumberStyles.Float, CultureInfo.InvariantCulture, out w))
            { Reply(400, new { ok = false, error = "missing/invalid 'weight'" }); return; }

            // ค่าสด: เก็บในหน่วยความจำ แล้วตอบทันที (ไม่แตะ DB)
            if (string.Equals(Str(d, "live"), "true", StringComparison.OrdinalIgnoreCase))
            {
                double lmn, lmx; int code;
                var lv = new LiveVal { Weight = w, At = DateTime.Now, Unit = Str(d, "unit"), Model = Str(d, "model"), Result = Str(d, "result"),
                                       Stable = string.Equals(Str(d, "stable"), "true", StringComparison.OrdinalIgnoreCase) };
                if (double.TryParse(Str(d, "min"), NumberStyles.Float, CultureInfo.InvariantCulture, out lmn)) lv.Min = lmn;
                if (double.TryParse(Str(d, "max"), NumberStyles.Float, CultureInfo.InvariantCulture, out lmx)) lv.Max = lmx;
                if (int.TryParse(Str(d, "code"), out code)) lv.Code = code;
                if (lv.Unit != null && lv.Unit.Length > 8) lv.Unit = lv.Unit.Substring(0, 8);
                if (lv.Model != null && lv.Model.Length > 60) lv.Model = lv.Model.Substring(0, 60);
                lv.Barcode = Str(d, "barcode"); if (lv.Barcode != null && lv.Barcode.Length > 20) lv.Barcode = lv.Barcode.Substring(0, 20);
                if (Live.Count < 100 || Live.ContainsKey(machine)) Live[machine] = lv;
                Reply(200, new { ok = true, live = true });
                return;
            }

            bool? stable = null;
            object so; if (d.TryGetValue("stable", out so) && so != null) { bool b; if (bool.TryParse(Convert.ToString(so, CultureInfo.InvariantCulture), out b)) stable = b; }
            string unit = Str(d, "unit"); if (unit != null && unit.Length > 8) unit = unit.Substring(0, 8);
            // ไม่บันทึกน้ำหนักไม่เกิน 1.0 g (ค่าแกว่ง / เครื่องชั่งว่าง) · หน่วย kg แปลงเป็นกรัมก่อนเทียบ
            double grams = string.Equals(unit, "kg", StringComparison.OrdinalIgnoreCase) ? w * 1000 : w;
            if (grams <= MIN_GRAMS) { Reply(200, new { ok = true, skipped = "weight <= " + MIN_GRAMS + " g" }); return; }

            // รุ่น / Spec / ผล (จาก Node-RED)
            string model = Str(d, "model");
            if (string.Equals(model, "Default", StringComparison.OrdinalIgnoreCase)) model = OeeDb.NOT_SCANNED;   // flow Node-RED รุ่นเก่ายังส่ง "Default" มา
            double mn, mx; double? specMin = null, specMax = null;
            if (double.TryParse(Str(d, "min"), NumberStyles.Float, CultureInfo.InvariantCulture, out mn)) specMin = mn;
            if (double.TryParse(Str(d, "max"), NumberStyles.Float, CultureInfo.InvariantCulture, out mx)) specMax = mx;
            string result = (Str(d, "result") ?? "").ToUpperInvariant();
            if (result != "OK" && result != "NG") result = (specMin.HasValue && specMax.HasValue) ? (w >= specMin.Value && w <= specMax.Value ? "OK" : "NG") : null;

            long id;
            string err = OeeDb.InsertWeight(machine, w, unit, stable, FixText(Str(d, "text")), model, Str(d, "barcode"), specMin, specMax, result, out id);
            if (err == "dup") { Reply(200, new { ok = true, skipped = "duplicate" }); return; }
            if (err != null) { Reply(500, new { ok = false, error = err }); return; }
            Reply(200, new { ok = true, id = id });
        }

        static string FixText(string t)   // flow รุ่นเก่า: "Default | ST,+..." -> "Not ScanBarcode | ST,+..."
        {
            return t != null && t.StartsWith("Default |", StringComparison.OrdinalIgnoreCase) ? OeeDb.NOT_SCANNED + t.Substring(7) : t;
        }
        static string Str(Dictionary<string, object> d, string k)
        {
            object o; return d.TryGetValue(k, out o) && o != null ? Convert.ToString(o, CultureInfo.InvariantCulture).Trim() : null;
        }
        static string Clean(string s)
        {
            if (string.IsNullOrEmpty(s)) return s;
            var sb = new StringBuilder();
            foreach (char ch in s) if (char.IsLetterOrDigit(ch) || ch == '-' || ch == '_' || ch == '.') sb.Append(ch);
            return sb.Length > 40 ? sb.ToString(0, 40) : sb.ToString();
        }

        void Reply(int code, object body)
        {
            Response.StatusCode = code;
            Response.TrySkipIisCustomErrors = true;
            Response.ContentType = "application/json; charset=utf-8";
            _apiOutput = Json.Serialize(body);
        }

        protected override void Render(HtmlTextWriter writer)
        {
            if (_apiOutput != null) writer.Write(_apiOutput);
            else base.Render(writer);
        }
    }
}
