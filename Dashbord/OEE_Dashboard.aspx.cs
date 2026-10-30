using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;

namespace Dashbord
{
    // =====================================================================
    // OEE Dashboard (แบบ OEE History) — สูตรเดียวกับ MC Monitor
    //   A, P = สถานะ / Shot จากเครื่อง (OEE.mc_daily)   Q = Good / (Good + NG) จาก ERP ตาม EQID
    //   วันผลิต 07:45–07:45 (CounterStore.DAY_START)
    //
    //   GET ?format=hist&from=yyyy-MM-dd&to=yyyy-MM-dd[&proc=Injection][&machine=MC13]
    //     -> daily  : OEE รายวัน (ทุกเครื่องรวมกัน หรือเครื่องเดียว)
    //        summary: ยอดรวมทั้งช่วง + แยกรายเครื่อง
    //   (หน้าเดิมที่คำนวณจาก ERP Check-Out สำรองไว้ที่ Backup\OEE_Dashboard_2026-10-23)
    // =====================================================================
    public partial class OEE_Dashboard : Page
    {
        const int MAX_DAYS = 92;
        const int CACHE_MIN = 10;          // วันที่ผ่านไปแล้ว เก็บผลไว้ 10 นาที (วันนี้คำนวณใหม่ทุกครั้ง)

        static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        static readonly ConcurrentDictionary<string, KeyValuePair<DateTime, Dictionary<string, object>>> _dayCache =
            new ConcurrentDictionary<string, KeyValuePair<DateTime, Dictionary<string, object>>>();
        string _apiOutput;

        /// <summary>รายชื่อ Process สำหรับตัวเลือกบนหน้า (ชุดเดียวกับ MC Monitor)</summary>
        protected string ProcessJson { get { return Json.Serialize(AppMenu.Processes); } }

        protected void Page_Load(object sender, EventArgs e)
        {
            string fmt = (Request.QueryString["format"] ?? "").ToLowerInvariant();
            if (fmt == "") return;
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            try
            {
                if (fmt == "timeline") { Reply(200, Timeline(Request.QueryString["day"], Request.QueryString["machines"])); return; }
                if (fmt != "hist") { Reply(400, new { ok = false, error = "unknown format" }); return; }
                var ci = CultureInfo.InvariantCulture; var ds = DateTimeStyles.None;
                DateTime today = CounterStore.ProdDayStart(DateTime.Now).Date, f, t;
                if (!DateTime.TryParseExact(Request.QueryString["to"] ?? "", "yyyy-MM-dd", ci, ds, out t)) t = today;
                if (!DateTime.TryParseExact(Request.QueryString["from"] ?? "", "yyyy-MM-dd", ci, ds, out f)) f = t.AddDays(-13);
                if (t < f) { var x = f; f = t; t = x; }
                if ((t - f).TotalDays >= MAX_DAYS) f = t.AddDays(-(MAX_DAYS - 1));
                string proc = Request.QueryString["proc"]; if (string.Equals(proc, "All", StringComparison.OrdinalIgnoreCase)) proc = null;
                string mc = Request.QueryString["machine"]; if (string.IsNullOrWhiteSpace(mc) || mc == "All") mc = null;
                Reply(200, Hist(f, t, proc, mc, today));
            }
            catch (Exception ex) { Reply(500, new { ok = false, error = ex.Message }); }
        }

        static Dictionary<string, object> Hist(DateTime f, DateTime t, string proc, string mc, DateTime today)
        {
            var res = new Dictionary<string, object> { { "ok", true }, { "from", f.ToString("yyyy-MM-dd") }, { "to", t.ToString("yyyy-MM-dd") },
                                                       { "process", proc ?? "All" }, { "machine", mc ?? "" } };
            // ยอดรวมทั้งช่วง + แยกรายเครื่อง (เครื่องเดียว = กรองเฉพาะเครื่องนั้น)
            var summary = OeeReport.Build(f, t, mc != null ? null : proc, mc);
            res["summary"] = summary;

            if (mc != null)
            {
                // เครื่องเดียว : ใช้ OEE รายวันแบบเดียวกับแท็บ OEE History ใน popup
                var d = OeeReport.Daily(mc, f, t);
                res["daily"] = d["rows"]; res["total"] = d["total"];
                res["dbError"] = d["dbError"]; res["erpError"] = d["erpError"];
                return res;
            }

            // ทุกเครื่อง (หรือทั้ง Process) : OEE ของแต่ละวัน = รวมทุกเครื่องในวันนั้น
            int n = (int)(t - f).TotalDays + 1;
            var days = new Dictionary<string, object>[n];
            Parallel.For(0, n, new ParallelOptions { MaxDegreeOfParallelism = 4 }, i =>
            {
                DateTime day = f.AddDays(i);
                days[i] = DayTotal(day, proc, day < today);
            });
            res["daily"] = days;
            res["total"] = summary["total"];
            res["dbError"] = summary["dbError"]; res["erpError"] = summary["erpError"];
            return res;
        }

        // GET ?format=timeline&day=yyyy-MM-dd&machines=MC13,MC14 -> สถานะเครื่องทั้งวันผลิต (เดิน / Idle / Breakdown / Offline) สำหรับกราฟ Timeline
        static Dictionary<string, object> Timeline(string dayStr, string machines)
        {
            DateTime day;
            if (!DateTime.TryParseExact(dayStr ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out day))
                day = CounterStore.ProdDayStart(DateTime.Now).Date;
            DateTime dayStart = day.Date + CounterStore.DAY_START;
            var list = (machines ?? "").Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries).Select(x => x.Trim()).Where(x => x.Length > 0).Distinct().Take(200).ToList();
            var items = new ConcurrentDictionary<string, object>();
            Parallel.ForEach(list, new ParallelOptions { MaxDegreeOfParallelism = 6 }, mc =>
            {
                var log = OeeDb.StatusLog(mc, dayStart);
                items[mc] = new Dictionary<string, object> { { "events", log["events"] }, { "error", log.ContainsKey("error") ? log["error"] : null } };
            });
            return new Dictionary<string, object> {
                { "ok", true }, { "day", day.ToString("yyyy-MM-dd") }, { "dayStart", dayStart.ToString("yyyy-MM-dd HH:mm:ss") },
                { "now", DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") }, { "items", items.ToDictionary(k => k.Key, k => k.Value) } };
        }

        static Dictionary<string, object> DayTotal(DateTime day, string proc, bool cacheable)
        {
            string key = day.ToString("yyyy-MM-dd") + "|" + (proc ?? "All");
            KeyValuePair<DateTime, Dictionary<string, object>> hit;
            if (cacheable && _dayCache.TryGetValue(key, out hit) && (DateTime.Now - hit.Key).TotalMinutes < CACHE_MIN) return hit.Value;

            var b = OeeReport.Build(day, day, proc, null);
            var tt = (Dictionary<string, object>)b["total"];
            int machines = Convert.ToInt32(tt["machines"]);
            double erpActual = Convert.ToDouble(tt["erpActual"] ?? 0.0);
            double plan = Convert.ToDouble(tt["plannedHours"] ?? 0.0), run = Convert.ToDouble(tt["runHours"] ?? 0.0);
            object q = tt["quality"];
            var row = new Dictionary<string, object> {
                { "day", day.ToString("yyyy-MM-dd") }, { "noData", machines == 0 && erpActual <= 0 },
                { "machines", machines }, { "plannedHours", plan }, { "runHours", run },
                { "lossHours", Math.Round(Math.Max(0, plan - run), 1) }, { "offlineHours", 0 },
                { "shots", tt["shots"] }, { "pieces", tt["pieces"] }, { "erpGood", tt["erpGood"] }, { "erpNg", tt["erpNg"] },
                { "availability", tt["availability"] }, { "performance", tt["performance"] }, { "quality", q },
                { "qualityAssumed", q == null }, { "oee", tt["oee"] }
            };
            if (cacheable && b["dbError"] == null) _dayCache[key] = new KeyValuePair<DateTime, Dictionary<string, object>>(DateTime.Now, row);
            return row;
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
