using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;

namespace Dashbord
{
    // =====================================================================
    // Injection Layout — ผังโรงงานแผนก Injection PVC แสดงสถานะ / OEE สดของแต่ละเครื่อง (สำหรับจอทีวี)
    //   GET ?format=live  -> ข้อมูลสดทุกเครื่อง Process = Injection (ชุดเดียวกับ MC Monitor) + EQID
    //   ตำแหน่งบนผังจับจาก EQID เช่น UB-MC-PV-1-3 = แถว 1 เครื่อง 3 · UB-MC-SF-xxx = โซน Seam buffing
    // =====================================================================
    public partial class InjectionLayout : Page
    {
        const string PROCESS = "Injection";
        static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        string _apiOutput;

        protected void Page_Load(object sender, EventArgs e)
        {
            string fmt = (Request.QueryString["format"] ?? "").ToLowerInvariant();
            if (fmt == "") return;
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            try
            {
                if (fmt != "live") { Reply(400, new { ok = false, error = "unknown format" }); return; }
                var rows = new List<object>();
                foreach (object o in CounterStore.Snapshot(null))
                {
                    var v = o as Dictionary<string, object>;
                    if (v == null) continue;
                    string proc = Convert.ToString(v["process"]);
                    string mc = Convert.ToString(v["machine"]);
                    string eq = ErpQuality.EqidFor(mc) ?? "";
                    // เอาเฉพาะ Injection (ดูจาก Process ที่ Node-RED ส่งมา หรือรหัส EQID แบบ PV)
                    bool inj = string.Equals(proc, PROCESS, StringComparison.OrdinalIgnoreCase) || eq.IndexOf("-PV-", StringComparison.OrdinalIgnoreCase) >= 0;
                    bool seam = proc.IndexOf("Seam", StringComparison.OrdinalIgnoreCase) >= 0 || eq.IndexOf("-SF-", StringComparison.OrdinalIgnoreCase) >= 0;   // Seam buffing อยู่ห้องเดียวกัน
                    if (!inj && !seam) continue;
                    var r = new Dictionary<string, object>(v);
                    r.Remove("hourly");
                    r["eqid"] = eq;
                    r["cat"] = Cat(v);
                    var hourly = v["hourly"] as List<object>;
                    var hs = new List<long>();
                    if (hourly != null) foreach (object h in hourly) { var hd = h as Dictionary<string, object>; hs.Add(hd == null ? 0 : Convert.ToInt64(hd["shots"])); }
                    r["hours"] = hs;
                    rows.Add(r);
                }
                DateTime now = DateTime.Now;
                Reply(200, new Dictionary<string, object> {
                    { "ok", true }, { "now", now.ToString("yyyy-MM-dd HH:mm:ss") },
                    { "dayStart", CounterStore.ProdDayStart(now).ToString("yyyy-MM-dd HH:mm:ss") }, { "machines", rows } });
            }
            catch (Exception ex) { Reply(500, new { ok = false, error = ex.Message }); }
        }

        // สถานะแบบเดียวกับ MC Monitor : off / down / run / idle
        static string Cat(Dictionary<string, object> v)
        {
            if (!(v["online"] is bool) || !(bool)v["online"]) return "off";
            int s = v["status"] == null ? 0 : Convert.ToInt32(v["status"], CultureInfo.InvariantCulture);
            if (s >= 17) return "down";
            if (s == 2 || s == 4) return "run";
            return "idle";
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
