using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;

namespace Dashbord
{
    /// <summary>
    /// LeaveRequest.aspx — ใบลา (UBG-FM-HR-09) ออนไลน์ · ต้องล็อกอิน
    ///   เขียนใบลา -> หัวหน้างานเซ็น -> ผู้อนุมัติเซ็น -> ฝ่ายบุคคลเซ็น = อนุมัติ (HR บันทึกใบที่เซ็นบนกระดาษแล้วได้ในครั้งเดียว)
    ///   GET  ?format=init · list&from&to · balance&year · card&code&year
    ///   POST ?format=save {id, emp, type, from, to, portion, hours, reason, substitute, written, medCert, paper, check}
    ///        sign {id, steps[]} · reject {id, note} · cancel {id, note} · quota {emp, year, type, days} · settings {config}
    /// </summary>
    public partial class LeaveRequest : HrPage
    {
        protected string JsVer
        {
            get
            {
                try { return (File.GetLastWriteTimeUtc(Server.MapPath("~/files/LeaveRequest.js")).Ticks / 10000000).ToString(CultureInfo.InvariantCulture); }
                catch { return "1"; }
            }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            string fmt = (Request.QueryString["format"] ?? "").ToLowerInvariant();
            if (fmt == "") return;
            try
            {
                if (Request.HttpMethod == "GET")
                {
                    if (fmt == "init") { InitData(); return; }
                    if (fmt == "list") { Reply(200, new { ok = true, rows = ListRows(Q("from"), Q("to")) }); return; }
                    if (fmt == "balance") { Reply(200, new { ok = true, rows = Balance(Year()) }); return; }
                    if (fmt == "card") { Card(Request.QueryString["code"], Year()); return; }
                    Reply(400, new { ok = false, error = "unknown format" }); return;
                }
                if (Request.HttpMethod != "POST") { Reply(405, new { ok = false, error = "method not allowed" }); return; }
                var d = ReadBody();
                string ip = Request.UserHostAddress;
                long id; long.TryParse(Str(d, "id"), out id);
                if (fmt == "save") { Save(d, id, ip); return; }
                if (fmt == "sign") { Sign(d, id, ip); return; }
                if (fmt == "reject" || fmt == "cancel") { Close(id, fmt == "reject", (Str(d, "note") ?? "").Trim(), ip); return; }
                if (fmt == "quota")
                {
                    if (!HrUser.IsHr) throw new Exception("เฉพาะ HR");
                    double days; int year;
                    int.TryParse(Str(d, "year"), out year);
                    string t = Str(d, "type");
                    if (t != "S" && t != "P" && t != "V") throw new Exception("bad type");
                    string ds = (Str(d, "days") ?? "").Trim();
                    OeeDb.LeaveQuotaSet(Str(d, "emp"), year, t, ds == "" ? (double?)null :
                        double.TryParse(ds, NumberStyles.Float, CultureInfo.InvariantCulture, out days) && days >= 0 && days <= 365 ? days : Bad("จำนวนวันไม่ถูกต้อง"), HrUser.Username, ip);
                    Reply(200, new { ok = true }); return;
                }
                if (fmt == "settings")
                {
                    if (!HrUser.IsHr) throw new Exception("เฉพาะ HR");
                    OeeDb.LeaveConfigSet(Json.ConvertToType<LeaveConfig>(d.ContainsKey("config") ? d["config"] : null), HrUser.Username, ip);
                    Reply(200, new { ok = true, config = OeeDb.LeaveConfigGet() }); return;
                }
                Reply(400, new { ok = false, error = "unknown format" });
            }
            catch (Exception ex) { Reply(500, new { ok = false, error = ex.Message }); }
        }

        static double Bad(string msg) { throw new Exception(msg); }

        DateTime? Q(string k)
        {
            DateTime d;
            return DateTime.TryParseExact(Request.QueryString[k] ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? d : (DateTime?)null;
        }
        int Year() { int y; return int.TryParse(Request.QueryString["year"], out y) && y > 2000 && y < 2200 ? y : DateTime.Today.Year; }
        static DateTime? Dt(object o)
        {
            DateTime d;
            return DateTime.TryParseExact(Convert.ToString(o), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? d : (DateTime?)null;
        }

        // ------------------------------------------------------------ พนักงานที่ดูได้ (supervisor / manager = แผนกที่ดูแล)
        Dictionary<string, Dictionary<string, object>> _emps;
        Dictionary<string, Dictionary<string, object>> AllEmps()
        {
            if (_emps == null)
                _emps = OeeDb.EmpList(false).ToDictionary(r => Convert.ToString(r["emp_code"]), StringComparer.OrdinalIgnoreCase);
            return _emps;
        }
        bool InScope(string emp)
        {
            Dictionary<string, object> r;
            return AllEmps().TryGetValue(emp ?? "", out r) ? HrUser.InScope(Convert.ToString(r["department"])) : HrUser.IsHr;
        }
        string Dept(string emp) { Dictionary<string, object> r; return AllEmps().TryGetValue(emp ?? "", out r) ? Convert.ToString(r["department"]) : ""; }

        void InitData()
        {
            var emps = AllEmps().Values.Where(r => HrUser.InScope(Convert.ToString(r["department"])))
                .Select(r => new {
                    code = r["emp_code"], name = (Convert.ToString(r["prefix"]) + Convert.ToString(r["name_th"])).Trim() == "" ? r["name_en"] : Convert.ToString(r["prefix"]) + Convert.ToString(r["name_th"]),
                    nick = r["nickname"], dept = r["department"], pos = r["position"], start = r["start_date"], group = r["emp_group"], status = r["status"] })
                .OrderBy(x => Convert.ToString(x.code)).ToList();
            Reply(200, new
            {
                ok = true, me = Me(), config = OeeDb.LeaveConfigGet(), types = HrFlow.LEAVE_NAMES, steps = HrFlow.LEAVE_STEPS, stepNames = HrFlow.STEP_NAMES,
                emps = emps, users = OeeDb.HrUserNames(), today = DateTime.Today.ToString("yyyy-MM-dd"), workDays = OeeDb.TaConfigGet().WorkDays,
            });
        }

        // ------------------------------------------------------------ รายการใบลา
        List<Dictionary<string, object>> ListRows(DateTime? from, DateTime? to)
        {
            var rows = OeeDb.LeaveList(from, to, null).Where(r => InScope(Convert.ToString(r["emp_code"]))).ToList();
            foreach (var r in rows) Flags(r);
            return rows;
        }

        /// <summary>สิทธิ์ของผู้ใช้กับใบนี้ : เซ็นช่องไหนได้ / แก้ได้ / ยกเลิกได้</summary>
        void Flags(Dictionary<string, object> r)
        {
            string dept = Dept(Convert.ToString(r["emp_code"]));
            bool pending = Convert.ToString(r["status"]) == "pending";
            bool anySigned = HrFlow.LEAVE_STEPS.Any(s => Convert.ToString(r[s + "_by"]) != "");
            r["canSign"] = pending ? HrFlow.LEAVE_STEPS.Where(s => Convert.ToString(r[s + "_by"]) == "" && HrFlow.CanSign(HrUser, s, dept)).ToList() : new List<string>();
            r["canEdit"] = pending && (HrUser.IsHr || (!anySigned && Convert.ToString(r["created_by"]) == HrUser.Username));
            r["canCancel"] = Convert.ToString(r["status"]) != "cancelled" && Convert.ToString(r["status"]) != "rejected" &&
                             (HrUser.IsHr || (pending && Convert.ToString(r["created_by"]) == HrUser.Username));
            r["dept"] = dept;
        }

        // ------------------------------------------------------------ บันทึก
        void Save(Dictionary<string, object> d, long id, string ip)
        {
            if (!HrUser.CanRequest) throw new Exception("บัญชีนี้ดูได้อย่างเดียว");
            string emp = (Str(d, "emp") ?? "").Trim(), type = (Str(d, "type") ?? "").Trim().ToUpperInvariant(), portion = Str(d, "portion") ?? "full";
            if (!AllEmps().ContainsKey(emp)) throw new Exception("ไม่พบรหัสพนักงาน " + emp);
            if (!InScope(emp)) throw new Exception("พนักงานคนนี้ไม่อยู่ในแผนกที่คุณดูแล");
            if (Array.IndexOf(HrFlow.LEAVE_TYPES, type) < 0) throw new Exception("เลือกประเภทการลา");
            if (HrFlow.HrOnlyType(type) && !HrUser.IsHr) throw new Exception("ขาดงาน / สาย บันทึกได้เฉพาะ HR");
            if (portion != "full" && portion != "am" && portion != "pm" && portion != "hours") portion = "full";
            DateTime? from = Dt(Str(d, "from")), to = Dt(Str(d, "to"));
            if (!from.HasValue) throw new Exception("เลือกวันที่ลา");
            if (!to.HasValue || portion != "full") to = from;
            double hours = 0;
            double.TryParse(Str(d, "hours") ?? "", NumberStyles.Float, CultureInfo.InvariantCulture, out hours);
            TaConfig ta = OeeDb.TaConfigGet(); LeaveConfig lc = OeeDb.LeaveConfigGet();
            double days = HrFlow.LeaveDays(from.Value, to.Value, portion, hours, ta, lc);
            if (days <= 0) throw new Exception("ช่วงที่เลือกไม่มีวันทำงาน (วันหยุด)");
            DateTime written = Dt(Str(d, "written")) ?? DateTime.Today;
            bool medCert = Str(d, "medCert") == "True" || Str(d, "medCert") == "true";
            string substitute = (Str(d, "substitute") ?? "").Trim();

            Dictionary<string, object> old = null;
            if (id > 0)
            {
                old = OeeDb.LeaveGet(id);
                if (old == null) throw new Exception("ไม่พบใบลา");
                Flags(old);
                if (!(bool)old["canEdit"]) throw new Exception("แก้ใบนี้ไม่ได้ (อนุมัติแล้ว / มีคนเซ็นแล้ว)");
            }

            // ---- ตรวจ : ลาซ้อนกัน (บล็อก) · กฎในใบลา + สิทธิ์คงเหลือ (เตือน)
            foreach (var x in OeeDb.LeaveList(from, to, emp))
            {
                if ((long)x["id"] == id) continue;
                string st = Convert.ToString(x["status"]);
                if (st == "rejected" || st == "cancelled") continue;
                bool partial = portion != "full" || Convert.ToString(x["portion"]) != "full";
                bool sameHalf = portion == Convert.ToString(x["portion"]) && (portion == "am" || portion == "pm");
                if (!partial || sameHalf) throw new Exception("ซ้ำกับใบลา " + x["doc_no"] + " (" + x["date_from"] + " - " + x["date_to"] + ")");
            }
            var warn = new List<string>();
            if ((type == "V" || type == "P") && (from.Value - written.Date).TotalDays < lc.AdvanceDays)
                warn.Add((type == "V" ? "ลาพักร้อน" : "ลากิจ") + " ต้องลาล่วงหน้า " + lc.AdvanceDays + " วัน (ใบนี้ล่วงหน้า " + Math.Max(0, (int)(from.Value - written.Date).TotalDays) + " วัน)");
            if (type == "S" && !medCert && days >= lc.SickCertDays)
                warn.Add("ลาป่วย ต้องมีใบรับรองแพทย์ (ยังไม่ได้ติ๊ก)");
            if (type == "S" || type == "P" || type == "V")
            {
                var bal = BalanceOf(emp, from.Value.Year).FirstOrDefault(b => (string)b["type"] == type);
                if (bal != null)
                {
                    double left = (double)bal["quota"] - (double)bal["used"] - (double)bal["pending"] + (old != null && Convert.ToString(old["leave_type"]) == type ? Convert.ToDouble(old["days"]) : 0);
                    if (days > left) warn.Add("สิทธิ์ " + HrFlow.LEAVE_NAMES[type] + " คงเหลือ " + left + " วัน แต่ลา " + days + " วัน");
                }
            }
            if (Str(d, "check") == "True" || Str(d, "check") == "true") { Reply(200, new { ok = true, days = days, warnings = warn }); return; }

            long nid = OeeDb.LeaveSave(id, emp, type, from.Value, to.Value, portion, portion == "hours" ? hours : (double?)null, days,
                                       Str(d, "reason"), substitute, written, medCert, HrUser.Username, ip);
            bool paper = (Str(d, "paper") == "True" || Str(d, "paper") == "true") && HrUser.IsHr;
            if (paper || HrFlow.HrOnlyType(type)) OeeDb.DocSign("hr_leave", nid, HrFlow.LEAVE_STEPS, HrFlow.LEAVE_STEPS, paper, HrUser.Username, ip);
            Reply(200, new { ok = true, id = nid, days = days, warnings = warn });
        }

        void Sign(Dictionary<string, object> d, long id, string ip)
        {
            var row = OeeDb.LeaveGet(id);
            if (row == null) throw new Exception("ไม่พบใบลา");
            Flags(row);
            var can = (List<string>)row["canSign"];
            var want = new List<string>();
            var arr = d.ContainsKey("steps") ? d["steps"] as System.Collections.ArrayList : null;
            if (arr != null) foreach (var x in arr) want.Add(Convert.ToString(x));
            if (want.Count == 0) want = can;
            if (want.Count == 0 || want.Any(s => !can.Contains(s))) throw new Exception("คุณไม่มีสิทธิ์เซ็นช่องนี้");
            if (want.Contains("appr") && can.Contains("sup") && !want.Contains("sup")) want.Insert(0, "sup");   // ผู้อนุมัติเซ็น = เซ็นแทน Leader ที่ยังไม่เซ็นด้วย
            Reply(200, new { ok = true, status = OeeDb.DocSign("hr_leave", id, HrFlow.LEAVE_STEPS, want, false, HrUser.Username, ip) });
        }

        void Close(long id, bool reject, string note, string ip)
        {
            var row = OeeDb.LeaveGet(id);
            if (row == null) throw new Exception("ไม่พบใบลา");
            Flags(row);
            if (reject && ((List<string>)row["canSign"]).Count == 0) throw new Exception("คุณไม่มีสิทธิ์อนุมัติใบนี้");
            if (!reject && !(bool)row["canCancel"]) throw new Exception("ยกเลิกใบนี้ไม่ได้");
            if (reject && note == "") throw new Exception("กรุณาใส่เหตุผลที่ไม่อนุมัติ");
            OeeDb.DocClose("hr_leave", id, reject, note, HrUser.Username, ip);
            Reply(200, new { ok = true });
        }

        // ------------------------------------------------------------ สิทธิ์วันลา (ปี)
        List<Dictionary<string, object>> BalanceOf(string emp, int year)
        {
            Dictionary<string, object> e;
            if (!AllEmps().TryGetValue(emp, out e)) return new List<Dictionary<string, object>>();
            return BalanceRows(new[] { e }, year, OeeDb.LeaveList(new DateTime(year, 1, 1), new DateTime(year, 12, 31), emp), OeeDb.LeaveQuota(year), OeeDb.LeaveConfigGet())
                   .Select(r => (List<Dictionary<string, object>>)r["types"]).First();
        }

        static List<Dictionary<string, object>> BalanceRows(IEnumerable<Dictionary<string, object>> emps, int year, List<Dictionary<string, object>> leaves,
                                                            Dictionary<string, double> quota, LeaveConfig lc)
        {
            var byEmp = leaves.Where(l => Convert.ToString(l["date_from"]).StartsWith(year.ToString(CultureInfo.InvariantCulture)))
                              .GroupBy(l => Convert.ToString(l["emp_code"]), StringComparer.OrdinalIgnoreCase).ToDictionary(g => g.Key, g => g.ToList(), StringComparer.OrdinalIgnoreCase);
            var rows = new List<Dictionary<string, object>>();
            foreach (var e in emps)
            {
                string code = Convert.ToString(e["emp_code"]);
                List<Dictionary<string, object>> mine; byEmp.TryGetValue(code, out mine); mine = mine ?? new List<Dictionary<string, object>>();
                var types = new List<Dictionary<string, object>>();
                foreach (string t in HrFlow.LEAVE_TYPES)
                {
                    double q; bool custom = quota.TryGetValue(code + "|" + t, out q);
                    if (!custom) q = lc.DefaultQuota(t, Dt(e["start_date"]), year);
                    double used = mine.Where(l => Convert.ToString(l["leave_type"]) == t && Convert.ToString(l["status"]) == "approved").Sum(l => Convert.ToDouble(l["days"]));
                    double pend = mine.Where(l => Convert.ToString(l["leave_type"]) == t && Convert.ToString(l["status"]) == "pending").Sum(l => Convert.ToDouble(l["days"]));
                    int times = mine.Count(l => Convert.ToString(l["leave_type"]) == t && Convert.ToString(l["status"]) == "approved");
                    types.Add(new Dictionary<string, object> { { "type", t }, { "quota", (t == "S" || t == "P" || t == "V") ? q : 0.0 }, { "custom", custom },
                                                               { "used", used }, { "pending", pend }, { "times", times } });
                }
                rows.Add(new Dictionary<string, object> { { "code", code }, { "types", types } });
            }
            return rows;
        }

        List<Dictionary<string, object>> Balance(int year)
        {
            var emps = AllEmps().Values.Where(e => HrUser.InScope(Convert.ToString(e["department"])) &&
                                                   (Convert.ToString(e["status"]) != "Resigned" || Convert.ToString(e["resign_date"]).StartsWith(year.ToString(CultureInfo.InvariantCulture)))).ToList();
            return BalanceRows(emps, year, OeeDb.LeaveList(new DateTime(year, 1, 1), new DateTime(year, 12, 31), null), OeeDb.LeaveQuota(year), OeeDb.LeaveConfigGet());
        }

        // ------------------------------------------------------------ บัตรบันทึกการลา (พิมพ์ ตามแบบ UBG-FM-HR-09)
        void Card(string code, int year)
        {
            code = (code ?? "").Trim();
            if (!AllEmps().ContainsKey(code) || !InScope(code)) throw new Exception("ไม่พบพนักงาน");
            var leaves = OeeDb.LeaveList(new DateTime(year, 1, 1), new DateTime(year, 12, 31), code)
                              .Where(l => Convert.ToString(l["status"]) == "approved").OrderBy(l => Convert.ToString(l["date_from"])).ToList();
            Reply(200, new { ok = true, year = year, emp = AllEmps()[code], leaves = leaves, balance = BalanceOf(code, year) });
        }
    }
}
