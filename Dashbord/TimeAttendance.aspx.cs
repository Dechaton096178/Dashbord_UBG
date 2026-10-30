using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;

namespace Dashbord
{
    /// <summary>
    /// TimeAttendance.aspx — เวลาเข้า-ออกงาน (แผนก HR) · ต้องล็อกอิน
    ///   ขั้นตอน : HR ดึงไฟล์ Excel จากเครื่องสแกน -> Import ที่หน้านี้ -> ระบบจับคู่ เข้า/ออก + คิด สาย / OT / ไม่มีสแกน
    ///   GET  ?format=init                      ค่าตั้ง + ช่วงวันที่ที่มีข้อมูล
    ///   GET  ?format=day&date=yyyy-MM-dd       รายวัน (ทุกคน)
    ///   GET  ?format=month&from=..&to=..       สรุปรายคน
    ///   GET  ?format=person&scan=104&from=&to= รายละเอียด 1 คน (รอบทำงาน + เวลาสแกนทุกครั้ง)
    ///   GET  ?format=csv&from=..&to=..         ดาวน์โหลดสรุป (CSV) · ?format=csvday&date=.. รายวัน
    ///   POST ?format=import {name, data, commit} · punchadd {scan, at, note} · punchvoid {id, void, note} · settings {config}
    ///   ข้อมูล : hr_punch, hr_setting (HrTaDb.cs) · คำนวณ : TaCalc.cs
    /// </summary>
    public partial class TimeAttendance : HrPage
    {
        protected string JsVer
        {
            get
            {
                try { return (File.GetLastWriteTimeUtc(Server.MapPath("~/files/TimeAttendance.js")).Ticks / 10000000).ToString(CultureInfo.InvariantCulture); }
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
                    if (fmt == "day") { Reply(200, new { ok = true, date = Day("date").ToString("yyyy-MM-dd"), rows = DayRows(Day("date")) }); return; }
                    if (fmt == "month") { DateTime a = Day("from"), b = Day("to"); Reply(200, new { ok = true, rows = MonthRows(a, b) }); return; }
                    if (fmt == "person") { Person(); return; }
                    if (fmt == "csv") { CsvMonth(Day("from"), Day("to")); return; }
                    if (fmt == "csvday") { CsvDay(Day("date")); return; }
                    if (fmt == "plan") { Reply(200, new { ok = true, date = Day("date").ToString("yyyy-MM-dd"), rows = PlanRows(Day("date")) }); return; }
                    if (fmt == "planhist") { PlanHist(Request.QueryString["code"]); return; }
                    Reply(400, new { ok = false, error = "unknown format" }); return;
                }
                if (Request.HttpMethod != "POST") { Reply(405, new { ok = false, error = "method not allowed" }); return; }
                if (!HrUser.CanEdit) { Reply(403, new { ok = false, error = "บัญชีนี้ดูได้อย่างเดียว (viewer)" }); return; }
                var d = ReadBody();
                string ip = Request.UserHostAddress;
                if (fmt == "import")
                {
                    string c = Str(d, "commit");
                    Reply(200, Import(Str(d, "name"), Str(d, "data"), c == "True" || c == "true", ip));
                }
                else if (fmt == "punchadd")
                {
                    DateTime at;
                    if (!DateTime.TryParseExact(Str(d, "at") ?? "", new[] { "yyyy-MM-dd HH:mm", "yyyy-MM-ddTHH:mm" }, CultureInfo.InvariantCulture, DateTimeStyles.None, out at))
                        throw new Exception("วันเวลาไม่ถูกต้อง");
                    OeeDb.TaPunchAddManual(TaCalc.ScanKey(Str(d, "scan")), at, (Str(d, "note") ?? "").Trim(), HrUser.Username, ip);
                    Reply(200, new { ok = true });
                }
                else if (fmt == "punchvoid")
                {
                    long id; long.TryParse(Str(d, "id"), out id);
                    string v = Str(d, "void");
                    OeeDb.TaPunchVoid(id, v == "True" || v == "true", (Str(d, "note") ?? "").Trim(), HrUser.Username, ip);
                    Reply(200, new { ok = true });
                }
                else if (fmt == "planadd")
                {
                    var codes = new List<string>();
                    var arr = d.ContainsKey("codes") ? d["codes"] as System.Collections.ArrayList : null;
                    if (arr != null) foreach (var x in arr) codes.Add(Convert.ToString(x));
                    DateTime from, to; bool hasTo = DateTime.TryParseExact(Str(d, "to") ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out to);
                    if (!DateTime.TryParseExact(Str(d, "from") ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out from)) throw new Exception("กรุณาเลือกวันที่เริ่ม");
                    string shift = Str(d, "shift");
                    if (!OeeDb.TaConfigGet().Shifts.Any(x => string.Equals(x.Code, shift, StringComparison.OrdinalIgnoreCase))) throw new Exception("ไม่พบกะ " + shift);
                    Reply(200, new { ok = true, added = OeeDb.TaPlanAdd(codes, shift, from, hasTo ? to : (DateTime?)null, (Str(d, "note") ?? "").Trim(), HrUser.Username, ip) });
                }
                else if (fmt == "plandelete")
                {
                    long id; long.TryParse(Str(d, "id"), out id);
                    OeeDb.TaPlanDelete(id, HrUser.Username, ip);
                    Reply(200, new { ok = true });
                }
                else if (fmt == "settings")
                {
                    var cfg = Json.ConvertToType<TaConfig>(d.ContainsKey("config") ? d["config"] : null);
                    OeeDb.TaConfigSet(cfg, HrUser.Username, ip);
                    Reply(200, new { ok = true, config = OeeDb.TaConfigGet() });
                }
                else Reply(400, new { ok = false, error = "unknown format" });
            }
            catch (Exception ex) { Reply(500, new { ok = false, error = ex.Message }); }
        }

        DateTime Day(string q)
        {
            DateTime d;
            return DateTime.TryParseExact(Request.QueryString[q] ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? d : DateTime.Today;
        }

        void InitData()
        {
            DateTime?[] r = OeeDb.TaRange();
            Reply(200, new
            {
                ok = true, me = Me(), config = OeeDb.TaConfigGet(),
                first = r[0].HasValue ? r[0].Value.ToString("yyyy-MM-dd") : null,
                last = r[1].HasValue ? r[1].Value.ToString("yyyy-MM-dd") : null,
                today = DateTime.Today.ToString("yyyy-MM-dd"),
            });
        }

        // ------------------------------------------------------------ พนักงาน (จับคู่กับรหัสเครื่องสแกน)
        class Emp
        {
            public string Code, Name, Nick, Dept, Group, Scan;
            public DateTime? Start, Resign;
            public bool Resigned;
            /// <summary>ควรมาสแกน : เคยสแกนในช่วง 30 วัน หรือเป็นพนักงานใหม่ (เริ่มงานไม่เกิน 14 วัน)</summary>
            public bool Expected(Dictionary<string, DateTime> seen, DateTime d)
            {
                return seen.ContainsKey(Scan) || (Start.HasValue && Start.Value.Date >= d.AddDays(-14));
            }
            public bool ActiveOn(DateTime d)
            {
                if (Start.HasValue && Start.Value.Date > d) return false;
                if (Resigned && (!Resign.HasValue || Resign.Value.Date <= d)) return false;
                return true;
            }
        }

        static DateTime? D(object o)
        {
            DateTime d;
            return DateTime.TryParseExact(Convert.ToString(o), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? d : (DateTime?)null;
        }

        static Dictionary<string, Emp> Emps()
        {
            var map = new Dictionary<string, Emp>();
            foreach (var r in OeeDb.EmpList(false))
            {
                string scan = TaCalc.ScanKey(Convert.ToString(r["emp_code"]));
                if (scan == null) continue;
                var e = new Emp
                {
                    Code = Convert.ToString(r["emp_code"]), Scan = scan,
                    Name = (Convert.ToString(r["prefix"]) + Convert.ToString(r["name_th"])).Trim(),
                    Nick = Convert.ToString(r["nickname"]), Dept = Convert.ToString(r["department"]), Group = Convert.ToString(r["emp_group"]),
                    Start = D(r["start_date"]), Resign = D(r["resign_date"]), Resigned = Convert.ToString(r["status"]) == "Resigned",
                };
                if (e.Name.Length == 0) e.Name = Convert.ToString(r["name_en"]);
                Emp old;
                if (!map.TryGetValue(scan, out old) || (old.Resigned && !e.Resigned)) map[scan] = e;   // เลขซ้ำ (U-5004 / S-5004) : เลือกคนที่ยังทำงาน
            }
            return map;
        }

        static List<TaSession> SessionsFor(DateTime from, DateTime to, TaConfig cfg, out List<TaPunch> punches)
        {
            punches = OeeDb.TaPunches(from.AddDays(-1), to.AddDays(2));
            return TaCalc.Sessions(punches, cfg, DataNow(), PlanBook(cfg)).Where(s => s.WorkDate >= from && s.WorkDate <= to).ToList();
        }

        static TaPlanBook PlanBook(TaConfig cfg) { return new TaPlanBook(OeeDb.TaPlans(null), cfg); }

        /// <summary>"ตอนนี้" ของข้อมูล = เวลาสแกนล่าสุดในระบบ (ไฟล์ดึงมาตอนเช้า คนที่ยังไม่สแกนออก = ยังทำงานอยู่ ไม่ใช่ลืมสแกน)</summary>
        static DateTime DataNow()
        {
            DateTime?[] r = OeeDb.TaRange();
            return r[1].HasValue && r[1].Value < DateTime.Now ? r[1].Value : DateTime.Now;
        }

        static string T(DateTime? t, DateTime workDate)
        {
            if (!t.HasValue) return "";
            string s = t.Value.ToString("HH:mm");
            int dd = (t.Value.Date - workDate).Days;
            return dd == 0 ? s : s + (dd > 0 ? " +" + dd : " " + dd);      // ข้ามวัน เช่น "07:30 +1"
        }

        static Dictionary<string, object> SessionRow(TaSession s)
        {
            return new Dictionary<string, object> {
                { "date", s.WorkDate.ToString("yyyy-MM-dd") }, { "shift", s.Shift.Code }, { "shiftName", s.Shift.Name },
                { "shiftTime", s.Shift.Start + "-" + s.Shift.End },
                { "in", T(s.In, s.WorkDate) }, { "out", T(s.Out, s.WorkDate) }, { "punches", s.Punches },
                { "late", s.LateMin }, { "early", s.EarlyMin }, { "work", s.WorkMin }, { "ot", s.OtMin },
                { "status", s.Working ? "working" : s.MissingOut ? "noout" : s.LateMin > 0 ? "late" : s.EarlyMin > 0 ? "early" : "ok" },
                { "planned", s.Planned }, { "mismatch", s.Mismatch }, { "planShift", s.PlannedShift != null ? s.PlannedShift.Name : "" },
            };
        }

        /// <summary>ไม่มีสแกนเลยกี่วัน = ไม่นับเป็น "ไม่มีสแกน" (น่าจะลาออกแล้ว แต่ทะเบียนยังเป็น Active)</summary>
        public const int UNSEEN_DAYS = 30;

        // ------------------------------------------------------------ รายวัน
        List<Dictionary<string, object>> DayRows(DateTime day)
        {
            TaConfig cfg = OeeDb.TaConfigGet();
            List<TaPunch> punches;
            var sessions = SessionsFor(day, day, cfg, out punches);
            var book = PlanBook(cfg);
            var emps = Emps();
            var bySc = sessions.GroupBy(s => s.ScanId).ToDictionary(g => g.Key, g => g.OrderBy(s => s.In).ToList());
            var rows = new List<Dictionary<string, object>>();
            bool workDay = cfg.IsWorkDay(day), future = day > DateTime.Today;
            var seen = OeeDb.TaLastScan(day.AddDays(-UNSEEN_DAYS), day.AddDays(2));
            bool hasData = punches.Any(p => !p.Void && p.At.Date == day);     // วันนี้ยังไม่ได้นำเข้าไฟล์ = ไม่ตัดสินว่าใครขาด
            bool complete = punches.Any(p => !p.Void && p.At.Date > day);    // ไฟล์มีข้อมูลถึงวันถัดไปแล้ว = วันนี้ครบ (ไม่งั้นกะดึกอาจยังไม่มา)

            foreach (var e in emps.Values.OrderBy(x => x.Code))
            {
                List<TaSession> ss;
                bool has = bySc.TryGetValue(e.Scan, out ss);
                if (!has && !e.ActiveOn(day)) continue;
                if (has)
                    foreach (var s in ss) rows.Add(Merge(EmpCols(e), SessionRow(s)));
                else if (!future && hasData)
                {
                    var r = EmpCols(e);
                    r["date"] = day.ToString("yyyy-MM-dd");
                    r["status"] = !workDay ? "off" : !e.Expected(seen, day) ? "unseen" : complete ? "noscan" : "pending";
                    TaShift ps = book.ShiftOn(e.Scan, day);
                    if (ps != null) { r["shift"] = ps.Code; r["shiftName"] = ps.Name; r["shiftTime"] = ps.Start + "-" + ps.End; r["planned"] = true; }   // unseen = ไม่เคยสแกนเลยใน 30 วัน (ลาออกแล้ว?)
                    rows.Add(r);
                }
            }
            // ใบลา + ใบขอ OT ของวันนี้
            var leaves = OtCalc.LeaveDays(day, day, cfg);
            var ot = OtCalc.Lines(day, day, sessions, cfg).GroupBy(l => l.Emp, StringComparer.OrdinalIgnoreCase).ToDictionary(g => g.Key, g => g.ToList(), StringComparer.OrdinalIgnoreCase);
            string dk = day.ToString("yyyy-MM-dd");
            foreach (var r in rows)
            {
                string code = Convert.ToString(r["code"]);
                OtCalc.LeaveDay lv;
                if (leaves.TryGetValue(code + "|" + dk, out lv))
                {
                    r["leave"] = lv.Type; r["leaveSt"] = lv.Status; r["leaveDoc"] = lv.Doc; r["leavePortion"] = lv.Portion;
                    string st = Convert.ToString(r["status"]);
                    if (lv.Type != "L" && (st == "noscan" || st == "pending" || st == "unseen")) r["status"] = "leave";
                }
                List<OtCalc.LineInfo> ol;
                if (ot.TryGetValue(code, out ol))
                {
                    r["otReq"] = string.Join(", ", ol.Select(x => x.From + "-" + x.To));
                    r["otReqSt"] = ol.All(x => x.Status == "approved") ? "approved" : "pending";
                    r["otPay"] = ol.Where(x => x.Status == "approved").Sum(x => x.PayMin);
                    r["otReqMin"] = ol.Sum(x => x.ApprMin);
                }
                else if (r.ContainsKey("ot") && Convert.ToInt32(r["ot"]) > 0) r["otNoReq"] = true;
            }
            // รหัสในเครื่องสแกนที่ไม่มีในทะเบียนพนักงาน
            foreach (var kv in bySc.Where(kv => !emps.ContainsKey(kv.Key)))
            {
                var p = punches.FirstOrDefault(x => x.ScanId == kv.Key && x.ScanName != "");
                foreach (var s in kv.Value)
                    rows.Add(Merge(new Dictionary<string, object> {
                        { "code", "" }, { "scan", kv.Key }, { "name", p != null ? p.ScanName : "" }, { "nick", "" },
                        { "dept", p != null ? p.ScanDept : "" }, { "group", "" }, { "unknown", true } }, SessionRow(s)));
            }
            return rows;
        }

        static Dictionary<string, object> EmpCols(Emp e)
        {
            return new Dictionary<string, object> { { "code", e.Code }, { "scan", e.Scan }, { "name", e.Name }, { "nick", e.Nick }, { "dept", e.Dept }, { "group", e.Group } };
        }

        static Dictionary<string, object> Merge(Dictionary<string, object> a, Dictionary<string, object> b)
        {
            foreach (var kv in b) a[kv.Key] = kv.Value;
            return a;
        }

        // ------------------------------------------------------------ สรุปรายคน (ช่วงวันที่)
        List<Dictionary<string, object>> MonthRows(DateTime from, DateTime to)
        {
            if (to < from) { var x = from; from = to; to = x; }
            if ((to - from).TotalDays > 62) throw new Exception("เลือกช่วงได้ไม่เกิน 62 วัน");
            TaConfig cfg = OeeDb.TaConfigGet();
            List<TaPunch> punches;
            var sessions = SessionsFor(from, to, cfg, out punches);
            var emps = Emps();
            var bySc = sessions.GroupBy(s => s.ScanId).ToDictionary(g => g.Key, g => g.ToList());
            DateTime last = to < DateTime.Today ? to : DateTime.Today;
            var rows = new List<Dictionary<string, object>>();
            var seen = OeeDb.TaLastScan(from.AddDays(-UNSEEN_DAYS), to.AddDays(2));
            var leaves = OtCalc.LeaveDays(from, to, cfg);
            var otByEmp = OtCalc.Lines(from, to, sessions, cfg).GroupBy(l => l.Emp, StringComparer.OrdinalIgnoreCase).ToDictionary(g => g.Key, g => g.ToList(), StringComparer.OrdinalIgnoreCase);
            var dataDays = new HashSet<DateTime>(punches.Where(p => !p.Void).Select(p => p.At.Date));   // นับ "ไม่มีสแกน" เฉพาะวันที่มีไฟล์สแกนแล้ว
            if (dataDays.Count > 0) dataDays.Remove(dataDays.Max());                                     // วันสุดท้ายของไฟล์อาจยังไม่ครบ (กะดึกยังไม่เข้า)

            foreach (var e in emps.Values.OrderBy(x => x.Code))
            {
                List<TaSession> ss;
                if (!bySc.TryGetValue(e.Scan, out ss)) ss = new List<TaSession>();
                bool unseen = ss.Count == 0 && !e.Expected(seen, last);
                int noScan = 0, workDays = 0;
                var lv = new Dictionary<string, double> { { "S", 0 }, { "P", 0 }, { "V", 0 }, { "O", 0 }, { "A", 0 }, { "L", 0 } };
                for (DateTime d = from; d <= to; d = d.AddDays(1))
                {
                    OtCalc.LeaveDay x;
                    if (leaves.TryGetValue(e.Code + "|" + d.ToString("yyyy-MM-dd"), out x) && x.Status == "approved") lv[x.Type] += x.Type == "L" ? 1 : x.Days;
                }
                var dates = new HashSet<DateTime>(ss.Select(s => s.WorkDate));
                for (DateTime d = from; d <= last; d = d.AddDays(1))
                {
                    if (!e.ActiveOn(d) || !cfg.IsWorkDay(d) || !dataDays.Contains(d)) continue;
                    workDays++;
                    OtCalc.LeaveDay x;
                    bool onLeave = leaves.TryGetValue(e.Code + "|" + d.ToString("yyyy-MM-dd"), out x) && x.Type != "L" && x.Portion == "full";
                    if (!dates.Contains(d) && !onLeave) noScan++;
                }
                if (ss.Count == 0 && workDays == 0) continue;
                rows.Add(Merge(EmpCols(e), new Dictionary<string, object> {
                    { "workDays", workDays }, { "days", dates.Count }, { "noScan", unseen ? 0 : noScan }, { "unseen", unseen },
                    { "lvS", lv["S"] }, { "lvP", lv["P"] }, { "lvV", lv["V"] }, { "lvO", lv["O"] }, { "lvA", lv["A"] }, { "lvL", lv["L"] },
                    { "leaveDays", lv["S"] + lv["P"] + lv["V"] + lv["O"] },
                    { "otReq", OtList(otByEmp, e.Code).Where(o => o.Status == "approved").Sum(o => o.ApprMin) },
                    { "otPay", OtList(otByEmp, e.Code).Where(o => o.Status == "approved").Sum(o => o.PayMin) },
                    { "otNoReq", ss.Where(x => x.OtMin > 0 && !OtList(otByEmp, e.Code).Any(o => o.Date == x.WorkDate)).Sum(x => x.OtMin) },
                    { "lateCount", ss.Count(s => s.LateMin > 0) }, { "lateMin", ss.Sum(s => s.LateMin) },
                    { "earlyCount", ss.Count(s => s.EarlyMin > 0) }, { "noOut", ss.Count(s => s.MissingOut) },
                    { "night", ss.Count(s => s.Shift.IsNight) },
                    { "work", ss.Sum(s => s.WorkMin) }, { "ot", ss.Sum(s => s.OtMin) },
                }));
            }
            foreach (var kv in bySc.Where(kv => !emps.ContainsKey(kv.Key)))
            {
                var p = punches.FirstOrDefault(x => x.ScanId == kv.Key && x.ScanName != "");
                rows.Add(new Dictionary<string, object> {
                    { "code", "" }, { "scan", kv.Key }, { "name", p != null ? p.ScanName : "" }, { "nick", "" }, { "dept", p != null ? p.ScanDept : "" }, { "group", "" }, { "unknown", true },
                    { "workDays", 0 }, { "days", kv.Value.Select(s => s.WorkDate).Distinct().Count() }, { "noScan", 0 },
                    { "lateCount", kv.Value.Count(s => s.LateMin > 0) }, { "lateMin", kv.Value.Sum(s => s.LateMin) },
                    { "earlyCount", kv.Value.Count(s => s.EarlyMin > 0) }, { "noOut", kv.Value.Count(s => s.MissingOut) },
                    { "night", kv.Value.Count(s => s.Shift.IsNight) }, { "work", kv.Value.Sum(s => s.WorkMin) }, { "ot", kv.Value.Sum(s => s.OtMin) } });
            }
            return rows;
        }

        // ------------------------------------------------------------ แผนกะ : ทุกคน ณ วันที่เลือก
        List<Dictionary<string, object>> PlanRows(DateTime day)
        {
            TaConfig cfg = OeeDb.TaConfigGet();
            var plans = OeeDb.TaPlans(null);
            var book = new TaPlanBook(plans, cfg);
            var byEmp = plans.GroupBy(p => p.Scan ?? "").ToDictionary(g => g.Key, g => g.ToList());
            var rows = new List<Dictionary<string, object>>();
            foreach (var e in Emps().Values.Where(x => x.ActiveOn(day)).OrderBy(x => x.Code))
            {
                TaPlan cur = book.PlanOn(e.Scan, day);
                TaShift sh = book.ShiftOn(e.Scan, day);
                List<TaPlan> mine; byEmp.TryGetValue(e.Scan, out mine); mine = mine ?? new List<TaPlan>();
                // การเปลี่ยนกะครั้งถัดไป (หลังวันที่เลือก)
                DateTime? next = null; TaShift nextSh = null;
                for (DateTime d = day.AddDays(1); d <= day.AddDays(62); d = d.AddDays(1))
                {
                    TaShift x = book.ShiftOn(e.Scan, d);
                    if ((x == null ? "" : x.Code) != (sh == null ? "" : sh.Code)) { next = d; nextSh = x; break; }
                }
                var r = EmpCols(e);
                r["shift"] = sh != null ? sh.Code : "";
                r["shiftName"] = sh != null ? sh.Name : (cur != null ? cur.ShiftCode + " (deleted)" : "");
                r["shiftTime"] = sh != null ? sh.Start + "-" + sh.End : "";
                r["from"] = cur != null ? cur.From.ToString("yyyy-MM-dd") : "";
                r["to"] = cur != null && cur.To.HasValue ? cur.To.Value.ToString("yyyy-MM-dd") : "";
                r["temp"] = cur != null && cur.To.HasValue;
                r["next"] = next.HasValue ? next.Value.ToString("yyyy-MM-dd") : "";
                r["nextName"] = next.HasValue ? (nextSh != null ? nextSh.Name : "(no plan)") : "";
                r["changes"] = mine.Count;
                rows.Add(r);
            }
            return rows;
        }

        void PlanHist(string code)
        {
            if (string.IsNullOrWhiteSpace(code)) throw new Exception("missing code");
            var names = OeeDb.TaConfigGet().Shifts.ToDictionary(x => x.Code, x => x.Name + " " + x.Start + "-" + x.End, StringComparer.OrdinalIgnoreCase);
            string n;
            Reply(200, new
            {
                ok = true,
                rows = OeeDb.TaPlans(code.Trim()).Select(p => new {
                    id = p.Id, shift = p.ShiftCode, shiftName = names.TryGetValue(p.ShiftCode, out n) ? n : p.ShiftCode + " (deleted)",
                    from = p.From.ToString("yyyy-MM-dd"), to = p.To.HasValue ? p.To.Value.ToString("yyyy-MM-dd") : "", note = p.Note, by = p.By,
                    at = p.CreatedAt == DateTime.MinValue ? "" : p.CreatedAt.ToString("yyyy-MM-dd HH:mm") }).ToList()
            });
        }

        static List<OtCalc.LineInfo> OtList(Dictionary<string, List<OtCalc.LineInfo>> m, string code)
        {
            List<OtCalc.LineInfo> l; return m.TryGetValue(code ?? "", out l) ? l : new List<OtCalc.LineInfo>();
        }

        // ------------------------------------------------------------ รายละเอียด 1 คน
        void Person()
        {
            string scan = TaCalc.ScanKey(Request.QueryString["scan"]);
            DateTime from = Day("from"), to = Day("to");
            if (scan == null) throw new Exception("missing scan");
            TaConfig cfg = OeeDb.TaConfigGet();
            var punches = OeeDb.TaPunches(from.AddDays(-1), to.AddDays(2)).Where(p => p.ScanId == scan).ToList();
            var sessions = TaCalc.Sessions(punches, cfg, DataNow(), PlanBook(cfg)).Where(s => s.WorkDate >= from && s.WorkDate <= to).OrderBy(s => s.In).ToList();
            Emp e; Emps().TryGetValue(scan, out e);
            DateTime last = to < DateTime.Today ? to : DateTime.Today;
            var dates = new HashSet<DateTime>(sessions.Select(s => s.WorkDate));
            var noScan = new List<string>();
            var dataDays = OeeDb.TaDataDays(from, to.AddDays(2));
            if (dataDays.Count > 0) dataDays.Remove(dataDays.Max());
            if (e != null)
                for (DateTime d = from; d <= last; d = d.AddDays(1))
                    if (e.ActiveOn(d) && cfg.IsWorkDay(d) && dataDays.Contains(d) && !dates.Contains(d)) noScan.Add(d.ToString("yyyy-MM-dd"));
            Reply(200, new
            {
                ok = true, scan = scan,
                emp = e == null ? null : (object)EmpCols(e),
                sessions = sessions.Select(SessionRow).ToList(),
                noScan = noScan,
                punches = punches.Where(p => p.At >= from.AddHours(-6) && p.At < to.AddDays(1).AddHours(12)).Select(p => new {
                    id = p.Id, at = p.At.ToString("yyyy-MM-dd HH:mm"), source = p.Source, isVoid = p.Void, note = p.Note, by = p.Source == "manual" ? p.By : "" }).ToList(),
            });
        }

        // ------------------------------------------------------------ CSV
        static string Hm(object min) { int m = Convert.ToInt32(min); return m == 0 ? "" : (m / 60) + ":" + (m % 60).ToString("00"); }

        void CsvMonth(DateTime from, DateTime to)
        {
            var sb = new StringBuilder("Code,Scan ID,Name,Nickname,Department,Group,Work days,Days scanned,No scan,Late (times),Late (min),Early out (times),Missing OUT,Night shifts,Work hours,OT hours (scan),OT requested (approved),OT payable,OT without request,Sick,Personal,Vacation,Other,Absence,Late (times)\r\n");
            foreach (var r in MonthRows(from, to))
                sb.Append(string.Join(",", new[] {
                    Csv((string)r["code"]), Csv((string)r["scan"]), Csv((string)r["name"]), Csv((string)r["nick"]), Csv((string)r["dept"]), Csv((string)r["group"]),
                    r["workDays"].ToString(), r["days"].ToString(), r["noScan"].ToString(), r["lateCount"].ToString(), r["lateMin"].ToString(),
                    r["earlyCount"].ToString(), r["noOut"].ToString(), r["night"].ToString(), Hm(r["work"]), Hm(r["ot"]),
                    Hm(V(r, "otReq")), Hm(V(r, "otPay")), Hm(V(r, "otNoReq")), N(r, "lvS"), N(r, "lvP"), N(r, "lvV"), N(r, "lvO"), N(r, "lvA"), N(r, "lvL") })).Append("\r\n");
            SendCsv("Attendance_" + from.ToString("yyyyMMdd") + "-" + to.ToString("yyyyMMdd") + ".csv", sb);
        }

        static object V(Dictionary<string, object> r, string k) { object v; return r.TryGetValue(k, out v) ? v : 0; }
        static string N(Dictionary<string, object> r, string k) { double d = Convert.ToDouble(V(r, k)); return d == 0 ? "" : d.ToString(CultureInfo.InvariantCulture); }

        void CsvDay(DateTime day)
        {
            var sb = new StringBuilder("Date,Code,Scan ID,Name,Department,Shift,In,Out,Late (min),Early out (min),Work hours,OT hours,Status\r\n");
            foreach (var r in DayRows(day))
            {
                object v;
                Func<string, string> g = k => r.TryGetValue(k, out v) ? Convert.ToString(v, CultureInfo.InvariantCulture) : "";
                sb.Append(string.Join(",", new[] { g("date"), Csv(g("code")), g("scan"), Csv(g("name")), Csv(g("dept")), g("shiftName"), g("in"), g("out"),
                    g("late") == "0" ? "" : g("late"), g("early") == "0" ? "" : g("early"),
                    r.ContainsKey("work") ? Hm(r["work"]) : "", r.ContainsKey("ot") ? Hm(r["ot"]) : "", g("status") })).Append("\r\n");
            }
            SendCsv("Attendance_" + day.ToString("yyyyMMdd") + ".csv", sb);
        }

        // ------------------------------------------------------------ นำเข้าไฟล์จากเครื่องสแกน
        object Import(string fileName, string b64, bool commit, string ip)
        {
            var warnings = new List<string>();
            List<TaPunch> punches = TaCalc.ParseScannerFile(SheetReader.ReadBase64(fileName, b64), warnings);
            if (punches.Count == 0) return new { ok = false, error = "ไม่พบเวลาสแกนในไฟล์" + (warnings.Count > 0 ? " · " + warnings[0] : "") };
            DateTime a = punches.Min(p => p.At).Date, b = punches.Max(p => p.At).Date.AddDays(1);
            HashSet<string> have = OeeDb.TaExistingKeys(a, b);
            var fresh = punches.Where(p => !have.Contains(p.Key)).ToList();
            var emps = Emps();
            var unknown = punches.Where(p => !emps.ContainsKey(p.ScanId)).GroupBy(p => p.ScanId)
                                 .Select(g => new { scan = g.Key, name = g.First().ScanName, dept = g.First().ScanDept, count = g.Count() }).ToList();
            var perDay = punches.GroupBy(p => p.At.Date).OrderBy(g => g.Key)
                                .Select(g => new { date = g.Key.ToString("yyyy-MM-dd"), punches = g.Count(), people = g.Select(p => p.ScanId).Distinct().Count(), fresh = g.Count(p => !have.Contains(p.Key)) }).ToList();
            int added = 0;
            if (commit && fresh.Count > 0) added = OeeDb.TaPunchInsertMany(fresh, HrUser.Username, ip, fileName);
            return new
            {
                ok = true, committed = commit, total = punches.Count, fresh = fresh.Count, existing = punches.Count - fresh.Count, added = added,
                people = punches.Select(p => p.ScanId).Distinct().Count(), from = a.ToString("yyyy-MM-dd"), to = b.AddDays(-1).ToString("yyyy-MM-dd"),
                perDay = perDay, unknown = unknown, warnings = warnings.Take(20).ToList(),
            };
        }
    }
}
