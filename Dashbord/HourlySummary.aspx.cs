using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;

namespace Dashbord
{
    // =====================================================================
    // Hourly Summary by Process — ยอดผลิตรายชั่วโมง (08:00–07:00) แยกตาม Process และรายเครื่อง
    //   GET ?format=json&day=yyyy-MM-dd
    //   ยอด = Shot × Cavity (ชิ้น) · วันนี้ใช้ค่าสดจากเครื่อง (ชุดเดียวกับ MC Monitor) · วันก่อนใช้ mc_hourly
    // =====================================================================
    public partial class HourlySummary : Page
    {
        static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        string _apiOutput;

        protected string ProcessJson { get { return Json.Serialize(AppMenu.Processes); } }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!string.Equals(Request.QueryString["format"], "json", StringComparison.OrdinalIgnoreCase)) return;
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            try
            {
                DateTime now = DateTime.Now, todayStart = CounterStore.ProdDayStart(now), day;
                DateTime dayStart = DateTime.TryParseExact(Request.QueryString["day"] ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out day)
                    ? day.Date.AddHours(CounterStore.DAY_START_HOUR) : todayStart;
                bool today = dayStart == todayStart;

                string err;
                var rows = OeeDb.HourlyAll(dayStart, out err).ToDictionary(x => x.Machine, StringComparer.OrdinalIgnoreCase);

                // ข้อมูลสดจากเครื่อง : Process / Cavity ที่ใช้จริง และ (วันนี้) ยอดรายชั่วโมงล่าสุด
                foreach (object o in CounterStore.Snapshot(null))
                {
                    var v = o as Dictionary<string, object>; if (v == null) continue;
                    string mc = Convert.ToString(v["machine"]);
                    OeeDb.HourMc x;
                    bool inDb = rows.TryGetValue(mc, out x);
                    if (!inDb) { if (!today) continue; x = new OeeDb.HourMc { Machine = mc, Cav = 1 }; rows[mc] = x; }
                    string proc = Convert.ToString(v["process"]);
                    if (!string.IsNullOrEmpty(proc)) x.Process = proc;
                    if (today)
                    {
                        int cav = v["cavities"] == null ? 0 : Convert.ToInt32(v["cavities"]);
                        if (cav > 0) x.Cav = cav;
                        // ชั่วโมงที่ผ่านไปแล้ว (ก่อนชั่วโมงที่แล้ว) ใช้ค่าใน DB เป็นหลัก -> แก้ยอดใน mc_hourly แล้วเห็นผลทันทีโดยไม่ต้องรีสตาร์ทเว็บ
                        //   ชั่วโมงปัจจุบัน / ชั่วโมงที่แล้ว ใช้ค่าสดจากเครื่อง (DB บันทึกตามทุก 1 นาที)
                        int curH = (int)Math.Floor((now - dayStart).TotalHours);
                        var hourly = v["hourly"] as List<object>;
                        if (hourly != null)
                            for (int i = 0; i < 24 && i < hourly.Count; i++)
                            {
                                if (inDb && i < curH - 1) continue;
                                var hd = hourly[i] as Dictionary<string, object>;
                                if (hd != null) x.Shots[i] = Convert.ToInt64(hd["shots"]);
                            }
                    }
                }

                var list = rows.Values.Select(x => new Dictionary<string, object> {
                    { "machine", x.Machine }, { "eqid", ErpQuality.EqidFor(x.Machine) ?? "" }, { "machineNo", x.MachineNo ?? "" },
                    { "process", string.IsNullOrEmpty(x.Process) ? "Other" : x.Process }, { "cav", x.Cav }, { "shots", x.Shots }
                }).ToList();

                Reply(200, new Dictionary<string, object> {
                    { "ok", err == null }, { "error", err }, { "day", dayStart.ToString("yyyy-MM-dd") }, { "today", today },
                    { "dayStart", dayStart.ToString("yyyy-MM-dd HH:mm:ss") }, { "now", now.ToString("yyyy-MM-dd HH:mm:ss") },
                    { "curHour", today ? (int)Math.Floor((now - dayStart).TotalHours) : 24 }, { "machines", list } });
            }
            catch (Exception ex) { Reply(500, new { ok = false, error = ex.Message }); }
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
