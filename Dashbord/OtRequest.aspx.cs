using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;

namespace Dashbord
{
    /// <summary>
    /// OtRequest.aspx — ใบขออนุมัติทำงานล่วงเวลา (UBG-FM-HR-07) ออนไลน์ · ต้องล็อกอิน
    ///   ผู้ขอเปิดโอที -> หัวหน้าแผนก -> ฝ่ายบุคคล -> ผู้อนุมัติ = อนุมัติ
    ///   GET  ?format=init · list&from&to · compare&from&to (OT ที่ขอ เทียบ เวลาสแกนจริง)
    ///   POST ?format=save {id, dept, date, note, lines[{emp, from, to, job, remark}], paper} · sign {id, steps[]} · reject · cancel
    /// </summary>
    public partial class OtRequest : HrPage
    {
        protected string JsVer
        {
            get
            {
                try { return (File.GetLastWriteTimeUtc(Server.MapPath("~/files/OtRequest.js")).Ticks / 10000000).ToString(CultureInfo.InvariantCulture); }
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
                    if (fmt == "list") { Reply(200, new { ok = true, rows = ListRows(Q("from") ?? DateTime.Today.AddDays(-31), Q("to") ?? DateTime.Today.AddDays(31)) }); return; }
                    if (fmt == "compare") { Compare(Q("from") ?? DateTime.Today.AddDays(-7), Q("to") ?? DateTime.Today); return; }
                    Reply(400, new { ok = false, error = "unknown format" }); return;
                }
                if (Request.HttpMethod != "POST") { Reply(405, new { ok = false, error = "method not allowed" }); return; }
                var d = ReadBody();
                string ip = Request.UserHostAddress;
                long id; long.TryParse(Str(d, "id"), out id);
                if (fmt == "save") { Save(d, id, ip); return; }
                if (fmt == "sign") { Sign(d, id, ip); return; }
                if (fmt == "reject" || fmt == "cancel") { Close(id, fmt == "reject", (Str(d, "note") ?? "").Trim(), ip); return; }
                Reply(400, new { ok = false, error = "unknown format" });
            }
            catch (Exception ex) { Reply(500, new { ok = false, error = ex.Message }); }
        }

        DateTime? Q(string k)
        {
            DateTime d;
            return DateTime.TryParseExact(Request.QueryString[k] ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? d : (DateTime?)null;
        }

        Dictionary<string, Dictionary<string, object>> _emps;
        Dictionary<string, Dictionary<string, object>> AllEmps()
        {
            if (_emps == null) _emps = OeeDb.EmpList(false).ToDictionary(r => Convert.ToString(r["emp_code"]), StringComparer.OrdinalIgnoreCase);
            return _emps;
        }
        string Dept(string emp) { Dictionary<string, object> r; return AllEmps().TryGetValue(emp ?? "", out r) ? Convert.ToString(r["department"]) : ""; }
        static string Name(Dictionary<string, object> r)
        {
            string n = (Convert.ToString(r["prefix"]) + Convert.ToString(r["name_th"])).Trim();
            return n.Length > 0 ? n : Convert.ToString(r["name_en"]);
        }

        void InitData()
        {
            var ta = OeeDb.TaConfigGet();
            var emps = AllEmps().Values.Where(r => HrUser.InScope(Convert.ToString(r["department"])))
                .Select(r => new { code = r["emp_code"], name = Name(r), nick = r["nickname"], dept = r["department"], status = r["status"] })
                .OrderBy(x => Convert.ToString(x.code)).ToList();
            Reply(200, new
            {
                ok = true, me = Me(), emps = emps, steps = HrFlow.OT_STEPS, stepNames = HrFlow.STEP_NAMES, users = OeeDb.HrUserNames(),
                today = DateTime.Today.ToString("yyyy-MM-dd"), shifts = ta.Shifts.Select(s => new { code = s.Code, name = s.Name, start = s.Start, end = s.End, otBreak = s.OtBreakMin ?? 60 }).ToList(),
            });
        }

        // ------------------------------------------------------------ รายการใบขอ OT
        bool InScope(Dictionary<string, object> doc)
        {
            if (HrUser.InScope(Convert.ToString(doc["department"]))) return true;
            return ((List<Dictionary<string, object>>)doc["lines"]).Any(l => HrUser.InScope(Dept(Convert.ToString(l["emp_code"]))));
        }

        void Flags(Dictionary<string, object> r)
        {
            string dept = Convert.ToString(r["department"]);
            bool pending = Convert.ToString(r["status"]) == "pending";
            bool anySigned = HrFlow.OT_STEPS.Any(s => Convert.ToString(r[s + "_by"]) != "");
            r["canSign"] = pending ? HrFlow.OT_STEPS.Where(s => Convert.ToString(r[s + "_by"]) == "" && HrFlow.CanSign(HrUser, s, dept)).ToList() : new List<string>();
            r["canEdit"] = pending && (HrUser.IsHr || (!anySigned && Convert.ToString(r["created_by"]) == HrUser.Username));
            r["canCancel"] = Convert.ToString(r["status"]) != "cancelled" && Convert.ToString(r["status"]) != "rejected" &&
                             (HrUser.IsHr || (pending && Convert.ToString(r["created_by"]) == HrUser.Username));
            int min = 0;
            DateTime day = DateTime.ParseExact(Convert.ToString(r["ot_date"]), "yyyy-MM-dd", CultureInfo.InvariantCulture);
            foreach (var l in (List<Dictionary<string, object>>)r["lines"])
            {
                DateTime a, b;
                if (HrFlow.OtWindow(day, Convert.ToString(l["time_from"]), Convert.ToString(l["time_to"]), out a, out b)) min += (int)(b - a).TotalMinutes;
            }
            r["minutes"] = min;
        }

        List<Dictionary<string, object>> ListRows(DateTime from, DateTime to)
        {
            var rows = OeeDb.OtList(from, to, null).Where(InScope).ToList();
            foreach (var r in rows) Flags(r);
            return rows;
        }

        Dictionary<string, object> GetDoc(long id)
        {
            var r = OeeDb.OtList(null, null, id).FirstOrDefault();
            if (r == null) throw new Exception("ไม่พบใบขอ OT");
            Flags(r);
            return r;
        }

        // ------------------------------------------------------------ บันทึก
        void Save(Dictionary<string, object> d, long id, string ip)
        {
            if (!HrUser.CanRequest) throw new Exception("บัญชีนี้ดูได้อย่างเดียว");
            DateTime date;
            if (!DateTime.TryParseExact(Str(d, "date") ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out date)) throw new Exception("เลือกวันที่ทำ OT");
            string dept = (Str(d, "dept") ?? "").Trim();
            if (!HrUser.InScope(dept)) throw new Exception("แผนกนี้ไม่อยู่ในความดูแลของคุณ");
            var lines = new List<OeeDb.OtLine>();
            var arr = d.ContainsKey("lines") ? d["lines"] as System.Collections.ArrayList : null;
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if (arr != null)
                foreach (var o in arr)
                {
                    var l = o as Dictionary<string, object>; if (l == null) continue;
                    string emp = (Str(l, "emp") ?? "").Trim();
                    if (emp == "") continue;
                    if (!AllEmps().ContainsKey(emp)) throw new Exception("ไม่พบรหัสพนักงาน " + emp);
                    if (!HrUser.InScope(Dept(emp))) throw new Exception(emp + " ไม่อยู่ในแผนกที่คุณดูแล");
                    if (!seen.Add(emp)) throw new Exception(emp + " ซ้ำในใบเดียวกัน");
                    string f = (Str(l, "from") ?? "").Trim(), t = (Str(l, "to") ?? "").Trim();
                    if (HrFlow.Minutes(f) < 0 || HrFlow.Minutes(t) < 0) throw new Exception(emp + " : เวลาไม่ถูกต้อง (HH:mm)");
                    if (f == t) throw new Exception(emp + " : เวลาเข้า = เวลาเลิก");
                    lines.Add(new OeeDb.OtLine { Emp = emp, From = f, To = t, Job = Str(l, "job"), Remark = Str(l, "remark") });
                }
            if (lines.Count == 0) throw new Exception("ใส่รายชื่อพนักงานอย่างน้อย 1 คน");
            if (id > 0 && !(bool)GetDoc(id)["canEdit"]) throw new Exception("แก้ใบนี้ไม่ได้ (อนุมัติแล้ว / มีคนเซ็นแล้ว)");

            // คนเดียวกัน วันเดียวกัน อยู่ในใบอื่นแล้ว = เตือน (บล็อก)
            foreach (var other in OeeDb.OtList(date, date, null))
            {
                if ((long)other["id"] == id) continue;
                string st = Convert.ToString(other["status"]);
                if (st == "rejected" || st == "cancelled") continue;
                foreach (var l in (List<Dictionary<string, object>>)other["lines"])
                    if (seen.Contains(Convert.ToString(l["emp_code"]))) throw new Exception(l["emp_code"] + " มีในใบขอ OT " + other["doc_no"] + " วันเดียวกันแล้ว");
            }
            long nid = OeeDb.OtSave(id, dept, date, Str(d, "note"), lines, HrUser.Username, ip);
            bool paper = (Str(d, "paper") == "True" || Str(d, "paper") == "true") && HrUser.IsHr;
            if (paper) OeeDb.DocSign("hr_ot", nid, HrFlow.OT_STEPS, HrFlow.OT_STEPS, true, HrUser.Username, ip);
            Reply(200, new { ok = true, id = nid });
        }

        void Sign(Dictionary<string, object> d, long id, string ip)
        {
            var row = GetDoc(id);
            var can = (List<string>)row["canSign"];
            var want = new List<string>();
            var arr = d.ContainsKey("steps") ? d["steps"] as System.Collections.ArrayList : null;
            if (arr != null) foreach (var x in arr) want.Add(Convert.ToString(x));
            if (want.Count == 0) want = can;
            if (want.Count == 0 || want.Any(s => !can.Contains(s))) throw new Exception("คุณไม่มีสิทธิ์เซ็นช่องนี้");
            if (want.Contains("appr") && can.Contains("sup") && !want.Contains("sup")) want.Insert(0, "sup");   // ผู้อนุมัติเซ็น = เซ็นแทน Leader ที่ยังไม่เซ็นด้วย
            Reply(200, new { ok = true, status = OeeDb.DocSign("hr_ot", id, HrFlow.OT_STEPS, want, false, HrUser.Username, ip) });
        }

        void Close(long id, bool reject, string note, string ip)
        {
            var row = GetDoc(id);
            if (reject && ((List<string>)row["canSign"]).Count == 0) throw new Exception("คุณไม่มีสิทธิ์อนุมัติใบนี้");
            if (!reject && !(bool)row["canCancel"]) throw new Exception("ยกเลิกใบนี้ไม่ได้");
            if (reject && note == "") throw new Exception("กรุณาใส่เหตุผลที่ไม่อนุมัติ");
            OeeDb.DocClose("hr_ot", id, reject, note, HrUser.Username, ip);
            Reply(200, new { ok = true });
        }

        // ------------------------------------------------------------ OT ที่ขอ เทียบ เวลาสแกนจริง
        void Compare(DateTime from, DateTime to)
        {
            if (to < from) { var x = from; from = to; to = x; }
            if ((to - from).TotalDays > 62) throw new Exception("เลือกช่วงได้ไม่เกิน 62 วัน");
            TaConfig cfg = OeeDb.TaConfigGet();
            var punches = OeeDb.TaPunches(from.AddDays(-1), to.AddDays(2));
            DateTime?[] rng = OeeDb.TaRange();
            DateTime now = rng[1].HasValue && rng[1].Value < DateTime.Now ? rng[1].Value : DateTime.Now;
            var sessions = TaCalc.Sessions(punches, cfg, now, new TaPlanBook(OeeDb.TaPlans(null), cfg));
            var lines = OtCalc.Lines(from, to, sessions, cfg).Where(l => HrUser.InScope(Dept(l.Emp))).ToList();
            var emps = AllEmps();
            Func<string, string> nm = c => { Dictionary<string, object> r; return emps.TryGetValue(c ?? "", out r) ? Name(r) : ""; };
            var rows = lines.Select(l => new {
                doc = l.Doc, docId = l.DocId, status = l.Status, date = l.Date.ToString("yyyy-MM-dd"), emp = l.Emp, name = nm(l.Emp), dept = Dept(l.Emp),
                from = l.From, to = l.To, appr = l.ApprMin, pay = l.PayMin, flag = l.Flag,
                @in = l.In.HasValue ? l.In.Value.ToString("HH:mm") + ((l.In.Value.Date - l.Date).Days != 0 ? " " + (l.In.Value.Date - l.Date).Days.ToString("+0;-0") : "") : "",
                @out = l.Out.HasValue ? l.Out.Value.ToString("HH:mm") + ((l.Out.Value.Date - l.Date).Days != 0 ? " " + (l.Out.Value.Date - l.Date).Days.ToString("+0;-0") : "") : "",
            }).ToList();
            // ทำ OT ตามเวลาสแกน แต่ไม่มีใบขอ
            var have = new HashSet<string>(lines.Select(l => l.Scan + "|" + l.Date.ToString("yyyy-MM-dd")));
            var byScan = emps.Values.GroupBy(r => TaCalc.ScanKey(Convert.ToString(r["emp_code"])) ?? "").ToDictionary(g => g.Key, g => g.First());
            var noReq = sessions.Where(s => s.WorkDate >= from && s.WorkDate <= to && s.OtMin > 0 && !have.Contains(s.ScanId + "|" + s.WorkDate.ToString("yyyy-MM-dd")))
                .Select(s => { Dictionary<string, object> r; byScan.TryGetValue(s.ScanId, out r); return new { s, r }; })
                .Where(x => x.r != null && HrUser.InScope(Convert.ToString(x.r["department"])))
                .Select(x => new { date = x.s.WorkDate.ToString("yyyy-MM-dd"), emp = Convert.ToString(x.r["emp_code"]), name = Name(x.r), dept = Convert.ToString(x.r["department"]),
                                   shift = x.s.Shift.Name, @in = x.s.In.ToString("yyyy-MM-dd HH:mm"), @out = x.s.Out.HasValue ? x.s.Out.Value.ToString("yyyy-MM-dd HH:mm") : "", ot = x.s.OtMin })   // วันที่ + เวลาสแกนจริง
                .OrderBy(x => x.date).ThenBy(x => x.emp).ToList();
            Reply(200, new { ok = true, rows = rows, noRequest = noReq });
        }
    }
}
