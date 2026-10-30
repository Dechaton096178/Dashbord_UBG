using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;

namespace Dashbord
{
    // =========================================================
    // Time Attendance : ค่าตั้ง + โครงสร้างข้อมูล
    // =========================================================
    public class TaShift
    {
        public string Code, Name, Start, End;   // "08:00" / "17:00" · กะดึกจบหลังเที่ยงคืนได้ (20:00 -> 05:00)
        public int BreakMin;                    // พักกี่นาที (หักจากชั่วโมงทำงานปกติ)
        public int? OtBreakMin;                 // พักก่อนเริ่ม OT กี่นาที (เลิก 16:45 พัก 60 → OT เริ่ม 17:45) · null = 60
        [System.Web.Script.Serialization.ScriptIgnore] public int StartMin { get { return TaConfig.Hm(Start); } }
        [System.Web.Script.Serialization.ScriptIgnore] public int EndMin { get { return TaConfig.Hm(End); } }
        /// <summary>กะดึก = เริ่มตั้งแต่บ่ายสอง หรือเลิกหลังเที่ยงคืน</summary>
        [System.Web.Script.Serialization.ScriptIgnore] public bool IsNight { get { return StartMin >= 14 * 60 || EndMin < StartMin; } }
    }

    public class TaConfig
    {
        public List<TaShift> Shifts;
        public int GraceMin = 0;          // สายได้ไม่เกินกี่นาที (0 = เลยเวลาเข้างาน 1 นาทีก็สาย)
        public int OtAfterEndMin = 60;    // (เลิกใช้ · ย้ายไปตั้งรายกะที่ TaShift.OtBreakMin)
        public int OtRoundMin = 30;       // ปัด OT ลงทีละกี่นาที
        public int OtMinMin = 30;         // OT ต่ำกว่านี้ไม่นับ
        public int EarlyOtMin = 120;      // มาก่อนเวลาเข้ากะตั้งแต่กี่นาที ถึงนับเป็น OT ก่อนเข้างาน (0 = ไม่นับ) เช่น เข้า 04:45 กะ 08:00 = OT 3 ชม.
        public int SessionMaxHours = 18;  // สแกนเข้าแล้ว สแกนถัดไปภายในกี่ชั่วโมง = สแกนออกของรอบเดียวกัน
        public int DupMin = 3;            // สแกนซ้ำภายในกี่นาที = นับครั้งเดียว
        public string WorkDays = "1,2,3,4,5,6";   // วันทำงาน 0=อาทิตย์ 1=จันทร์ ... 6=เสาร์ (ไม่มาสแกนในวันทำงาน = ขาด/ไม่มีสแกน)
        public List<string> Holidays;     // วันหยุดบริษัท yyyy-MM-dd

        public static int Hm(string s)
        {
            var m = Regex.Match(s ?? "", @"^(\d{1,2}):(\d{2})$");
            return m.Success ? (int.Parse(m.Groups[1].Value) % 24) * 60 + Math.Min(59, int.Parse(m.Groups[2].Value)) : 0;
        }

        /// <summary>ค่าเริ่มต้น : กะเช้า 08:00-17:00 · กะดึก 20:00-05:00 (พัก 60 นาที)</summary>
        public static TaConfig Fix(TaConfig c)
        {
            c = c ?? new TaConfig();
            if (c.Shifts == null || c.Shifts.Count == 0)
                c.Shifts = new List<TaShift> {
                    new TaShift { Code = "D", Name = "Day", Start = "08:00", End = "17:00", BreakMin = 60 },
                    new TaShift { Code = "N", Name = "Night", Start = "20:00", End = "05:00", BreakMin = 60 } };
            foreach (var s in c.Shifts)
            {
                s.Code = string.IsNullOrWhiteSpace(s.Code) ? "S" : s.Code.Trim();
                s.Name = string.IsNullOrWhiteSpace(s.Name) ? s.Code : s.Name.Trim();
                if (!Regex.IsMatch(s.Start ?? "", @"^\d{1,2}:\d{2}$")) s.Start = "08:00";
                if (!Regex.IsMatch(s.End ?? "", @"^\d{1,2}:\d{2}$")) s.End = "17:00";
                s.BreakMin = Math.Max(0, Math.Min(240, s.BreakMin));
                s.OtBreakMin = Math.Max(0, Math.Min(240, s.OtBreakMin ?? 60));
            }
            c.GraceMin = Math.Max(0, Math.Min(120, c.GraceMin));
            c.OtAfterEndMin = Math.Max(0, Math.Min(240, c.OtAfterEndMin));
            c.OtRoundMin = Math.Max(1, Math.Min(60, c.OtRoundMin));
            c.OtMinMin = Math.Max(0, Math.Min(240, c.OtMinMin));
            c.EarlyOtMin = Math.Max(0, Math.Min(600, c.EarlyOtMin));
            c.SessionMaxHours = Math.Max(8, Math.Min(24, c.SessionMaxHours));
            c.DupMin = Math.Max(0, Math.Min(30, c.DupMin));
            c.WorkDays = string.Join(",", (c.WorkDays ?? "").Split(',').Select(x => x.Trim()).Where(x => Regex.IsMatch(x, "^[0-6]$")).Distinct());
            c.Holidays = (c.Holidays ?? new List<string>()).Select(x => (x ?? "").Trim()).Where(x => Regex.IsMatch(x, @"^\d{4}-\d{2}-\d{2}$")).Distinct().OrderBy(x => x).ToList();
            return c;
        }

        public bool IsWorkDay(DateTime d)
        {
            return (WorkDays ?? "").Split(',').Contains(((int)d.DayOfWeek).ToString(CultureInfo.InvariantCulture))
                   && !(Holidays ?? new List<string>()).Contains(d.ToString("yyyy-MM-dd"));
        }
    }

    public class TaPunch
    {
        public long Id;
        public string ScanId, Source, ScanName, ScanDept, Note, By;
        public DateTime At;
        public bool Void;
        public string Key { get { return ScanId + "|" + At.ToString("yyyy-MM-dd HH:mm:ss"); } }
    }

    /// <summary>1 รอบการทำงาน = สแกนเข้า + สแกนออก (กะดึกข้ามวันได้) · วันทำงาน = วันที่ของเวลาเข้ากะ</summary>
    public class TaSession
    {
        public string ScanId;
        public DateTime WorkDate;
        public TaShift Shift;
        public DateTime ShiftStart, ShiftEnd;
        public DateTime In;
        public DateTime? Out;
        public int Punches;
        public int LateMin, EarlyMin, WorkMin, OtMin;
        public bool Working, MissingOut;
        public bool Planned;      // ใช้กะตามแผน (Shift plan)
        public bool Mismatch;     // มีแผนกะ แต่เวลาเข้าห่างจากกะในแผนเกิน 6 ชม. -> ระบบเดากะเอง (ควรแก้แผน)
        public TaShift PlannedShift;
    }

    /// <summary>แผนกะ : พนักงานคนนี้ทำกะไหน ตั้งแต่วันไหน (ถึงวันไหน · ว่าง = จนกว่าจะเปลี่ยน)</summary>
    public class TaPlan
    {
        public long Id;
        public string EmpCode, Scan, ShiftCode, Note, By;
        public DateTime From;
        public DateTime? To;
        public DateTime CreatedAt;
    }

    /// <summary>หากะของพนักงานในวันหนึ่ง : แผนที่ครอบวันนั้น และเริ่มล่าสุดชนะ (แผนชั่วคราวทับแผนถาวรได้)</summary>
    public class TaPlanBook
    {
        readonly Dictionary<string, List<TaPlan>> _byScan = new Dictionary<string, List<TaPlan>>();
        readonly Dictionary<string, TaShift> _shifts;

        public TaPlanBook(IEnumerable<TaPlan> plans, TaConfig cfg)
        {
            _shifts = cfg.Shifts.GroupBy(x => x.Code, StringComparer.OrdinalIgnoreCase).ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);
            foreach (var p in plans ?? new List<TaPlan>())
            {
                if (p.Scan == null) continue;
                List<TaPlan> l;
                if (!_byScan.TryGetValue(p.Scan, out l)) _byScan[p.Scan] = l = new List<TaPlan>();
                l.Add(p);
            }
            foreach (var l in _byScan.Values) l.Sort((a, b) => a.From != b.From ? b.From.CompareTo(a.From) : b.Id.CompareTo(a.Id));   // ใหม่สุดก่อน
        }

        public TaPlan PlanOn(string scan, DateTime day)
        {
            List<TaPlan> l;
            if (scan == null || !_byScan.TryGetValue(scan, out l)) return null;
            foreach (var p in l)
                if (p.From <= day && (!p.To.HasValue || p.To.Value >= day)) return p;
            return null;
        }

        /// <summary>กะตามแผนของวันนั้น (null = ไม่มีแผน / รหัสกะถูกลบจาก Settings แล้ว)</summary>
        public TaShift ShiftOn(string scan, DateTime day)
        {
            TaPlan p = PlanOn(scan, day); TaShift sh;
            return p != null && _shifts.TryGetValue(p.ShiftCode, out sh) ? sh : null;
        }
    }

    // =========================================================
    // TaCalc : จับคู่ เข้า-ออก · หากะ · คำนวณสาย / ออกก่อน / ชั่วโมงทำงาน / OT
    // =========================================================
    public static class TaCalc
    {
        /// <summary>รหัสเครื่องสแกน -> ตัวเลข (ใช้เทียบกับรหัสพนักงาน U-0104 = 104)</summary>
        public static string ScanKey(string code)
        {
            string digits = new string((code ?? "").Where(char.IsDigit).ToArray()).TrimStart('0');
            return digits.Length == 0 ? null : digits;
        }

        public static List<TaSession> Sessions(IEnumerable<TaPunch> punches, TaConfig cfg, DateTime now)
        {
            return Sessions(punches, cfg, now, null);
        }

        public static List<TaSession> Sessions(IEnumerable<TaPunch> punches, TaConfig cfg, DateTime now, TaPlanBook plan)
        {
            var result = new List<TaSession>();
            foreach (var g in punches.Where(p => !p.Void).GroupBy(p => p.ScanId))
            {
                // ตัดสแกนซ้ำ (กดหลายครั้งติดกัน)
                var list = new List<TaPunch>();
                foreach (var p in g.OrderBy(p => p.At))
                    if (list.Count == 0 || (p.At - list[list.Count - 1].At).TotalMinutes > cfg.DupMin) list.Add(p);

                int i = 0;
                while (i < list.Count)
                {
                    DateTime tin = list[i].At;
                    int j = i + 1, last = -1;
                    while (j < list.Count && (list[j].At - tin).TotalHours <= cfg.SessionMaxHours) { last = j; j++; }
                    var s = new TaSession { ScanId = g.Key, In = tin, Out = last >= 0 ? list[last].At : (DateTime?)null, Punches = j - i };
                    Measure(s, cfg, now, plan);
                    result.Add(s);
                    i = j;
                }
            }
            return result;
        }

        public const int PLAN_MAX_DIFF_MIN = 360;   // เวลาเข้าห่างจากกะในแผนเกินนี้ = ไม่ใช่กะนั้น (เดากะเอง + เตือน)

        /// <summary>เลือกกะ : มีแผนกะ = ใช้กะตามแผน · ไม่มี = กะที่เวลาเข้างานใกล้ที่สุด · แล้วคิดสาย / ออกก่อน / ชั่วโมง / OT</summary>
        static void Measure(TaSession s, TaConfig cfg, DateTime now, TaPlanBook plan)
        {
            double best = double.MaxValue;
            bool anyPlan = false;
            if (plan != null)
                for (int d = -1; d <= 1; d++)
                {
                    DateTime day = s.In.Date.AddDays(d);
                    TaShift sh = plan.ShiftOn(s.ScanId, day);
                    if (sh == null) continue;
                    anyPlan = true;
                    DateTime st = day.AddMinutes(sh.StartMin);
                    double diff = Math.Abs((s.In - st).TotalMinutes);
                    if (diff < best) { best = diff; s.Shift = sh; s.ShiftStart = st; }
                }
            if (anyPlan && best <= PLAN_MAX_DIFF_MIN) s.Planned = true;
            else
            {
                if (anyPlan) { s.Mismatch = true; s.PlannedShift = s.Shift; }
                best = double.MaxValue;
                foreach (var sh in cfg.Shifts)
                    for (int d = -1; d <= 1; d++)
                    {
                        DateTime st = s.In.Date.AddDays(d).AddMinutes(sh.StartMin);
                        double diff = Math.Abs((s.In - st).TotalMinutes);
                        if (diff < best) { best = diff; s.Shift = sh; s.ShiftStart = st; }
                    }
            }
            int len = (s.Shift.EndMin - s.Shift.StartMin + 1440) % 1440;
            if (len == 0) len = 1440;
            s.ShiftEnd = s.ShiftStart.AddMinutes(len);
            s.WorkDate = s.ShiftStart.Date;

            double lateRaw = (s.In - s.ShiftStart).TotalMinutes;
            s.LateMin = lateRaw > cfg.GraceMin ? (int)Math.Ceiling(lateRaw) : 0;

            // OT ก่อนเข้างาน (มาเช้ามากตามที่ตั้งไว้)
            double early = (s.ShiftStart - s.In).TotalMinutes;
            int otBefore = cfg.EarlyOtMin > 0 && early >= cfg.EarlyOtMin ? (int)early / cfg.OtRoundMin * cfg.OtRoundMin : 0;

            if (s.Out == null)
            {
                s.Working = now < s.ShiftEnd.AddHours(4);
                s.MissingOut = !s.Working;
                return;
            }
            DateTime o = s.Out.Value;
            s.EarlyMin = o < s.ShiftEnd ? (int)Math.Ceiling((s.ShiftEnd - o).TotalMinutes) : 0;

            DateTime a = s.In > s.ShiftStart ? s.In : s.ShiftStart, b = o < s.ShiftEnd ? o : s.ShiftEnd;
            int span = b > a ? (int)(b - a).TotalMinutes : 0;
            s.WorkMin = Math.Max(0, span - (span >= 300 ? s.Shift.BreakMin : 0));      // ทำงานเกิน 5 ชม. หักเวลาพัก

            DateTime otStart = s.ShiftEnd.AddMinutes(s.Shift.OtBreakMin ?? 60);   // เลิกกะ + พักก่อน OT
            if (o > otStart)
            {
                int raw = (int)(o - otStart).TotalMinutes;
                int ot = raw / cfg.OtRoundMin * cfg.OtRoundMin;
                s.OtMin = ot >= cfg.OtMinMin ? ot : 0;
            }
            s.OtMin += otBefore;
        }

        // =========================================================
        // อ่านไฟล์รายงานจากเครื่องสแกน (Excel / CSV)
        //   รูปแบบเดิม : ชื่อแผนก · รหัสพนักงาน · ชื่อ · วันที่ "2026-10-27 (อังคาร)" · บันทึกเวลา1..n
        //   แถว ".." = คนเดิม วันถัดไป
        //   หรือแบบง่าย : รหัส · วันเวลา (1 แถว = 1 ครั้ง)
        // =========================================================
        public static List<TaPunch> ParseScannerFile(List<SheetReader.Sheet> sheets, List<string> warnings)
        {
            var result = new List<TaPunch>();
            foreach (var sh in sheets)
            {
                int hr = -1, cId = -1, cName = -1, cDept = -1, cDate = -1;
                var timeCols = new List<int>();
                for (int i = 0; i < sh.Rows.Count && i < 20 && hr < 0; i++)
                {
                    int id = -1, nm = -1, dp = -1, dt = -1; var tc = new List<int>();
                    for (int c = 0; c < sh.Rows[i].Count; c++)
                    {
                        string k = SheetReader.Key(sh.Rows[i][c]);
                        if (k.Length == 0) continue;
                        if (dp < 0 && (k.Contains(SheetReader.Key("แผนก")) || k == "department" || k == "dept")) dp = c;
                        else if (id < 0 && (k.Contains(SheetReader.Key("รหัส")) || k == "id" || k == "acno" || k == "userid" || k == "empid" || k == "employeeid" || k == "no")) id = c;
                        else if (dt < 0 && (k == SheetReader.Key("วันที่") || k == "date" || k == "datetime" || k.Contains("วนทเวลา"))) dt = c;
                        else if (nm < 0 && (k == SheetReader.Key("ชื่อ") || k.StartsWith(SheetReader.Key("ชื่อ")) || k == "name")) nm = c;
                        else if (k.StartsWith(SheetReader.Key("บันทึกเวลา")) || Regex.IsMatch(k, @"^(time|clock|punch)\d*$") || k.StartsWith("checkin") || k.StartsWith("checkout")) tc.Add(c);
                    }
                    if (id >= 0 && dt >= 0) { hr = i; cId = id; cName = nm; cDept = dp; cDate = dt; timeCols = tc; }
                }
                if (hr < 0) { warnings.Add(sh.Name + " : ไม่พบหัวตาราง (ต้องมี รหัสพนักงาน + วันที่) - ข้าม"); continue; }

                // คอลัมน์ว่างต่อจาก "บันทึกเวลา" ก็เป็นเวลาสแกนเพิ่มเติม (เช่น บันทึกเวลา3 แล้วมีอีก 3 ช่องไม่มีหัว)
                if (timeCols.Count > 0)
                {
                    int c = timeCols.Max() + 1;
                    while (c < sh.Rows[hr].Count + 6 && SheetReader.Key(sh.Cell(hr, c)).Length == 0) { timeCols.Add(c); c++; if (c > 60) break; }
                }

                string curId = null, curName = null, curDept = null;
                for (int i = hr + 1; i < sh.Rows.Count; i++)
                {
                    string id = sh.Cell(i, cId).Trim();
                    if (id == ".." || id == "")
                    {
                        if (id == "" && sh.Cell(i, cDate).Trim() == "") continue;
                    }
                    else
                    {
                        curId = id; curName = cName >= 0 ? sh.Cell(i, cName).Trim() : ""; curDept = cDept >= 0 ? sh.Cell(i, cDept).Trim() : "";
                    }
                    if (curId == null) continue;
                    string scan = ScanKey(curId);
                    if (scan == null) continue;

                    string ds = sh.Cell(i, cDate).Trim();
                    DateTime? day = ParseDay(ds);
                    TimeSpan? dtTime = ParseTimeOfDateCell(ds);
                    if (day == null) { if (ds != "") warnings.Add(sh.Name + "!" + (i + 1) + " : อ่านวันที่ไม่ได้ \"" + ds + "\""); continue; }

                    if (timeCols.Count == 0 && dtTime != null)
                        result.Add(new TaPunch { ScanId = scan, At = day.Value + dtTime.Value, ScanName = curName, ScanDept = curDept });
                    foreach (int c in timeCols)
                    {
                        TimeSpan? t = ParseTime(sh.Cell(i, c));
                        if (t != null) result.Add(new TaPunch { ScanId = scan, At = day.Value + t.Value, ScanName = curName, ScanDept = curDept });
                    }
                }
            }
            // ซ้ำในไฟล์ = นับครั้งเดียว
            return result.GroupBy(p => p.Key).Select(g => g.First()).OrderBy(p => p.At).ToList();
        }

        static DateTime? ParseDay(string s)
        {
            if (string.IsNullOrWhiteSpace(s)) return null;
            double oa;
            if (double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out oa) && oa > 20000 && oa < 80000) return DateTime.FromOADate(oa).Date;
            var m = Regex.Match(s, @"(\d{4})[-/](\d{1,2})[-/](\d{1,2})");
            if (m.Success) return Safe(int.Parse(m.Groups[1].Value), int.Parse(m.Groups[2].Value), int.Parse(m.Groups[3].Value));
            m = Regex.Match(s, @"(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})");
            if (m.Success) return Safe(int.Parse(m.Groups[3].Value), int.Parse(m.Groups[2].Value), int.Parse(m.Groups[1].Value));   // d/M/yyyy
            return null;
        }

        static DateTime? Safe(int y, int mo, int d)
        {
            if (y > 2400) y -= 543;
            try { return new DateTime(y, mo, d); } catch { return null; }
        }

        /// <summary>เวลาที่อยู่ในช่องวันที่ (แบบ 1 แถว = 1 ครั้ง : "2026-10-27 07:19" หรือเลข Excel 46322.30)</summary>
        static TimeSpan? ParseTimeOfDateCell(string s)
        {
            double oa;
            if (double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out oa) && oa > 20000 && oa < 80000 && oa != Math.Floor(oa))
                return DateTime.FromOADate(oa).TimeOfDay;
            var m = Regex.Match(s ?? "", @"\s(\d{1,2}):(\d{2})(?::(\d{2}))?");
            return m.Success ? new TimeSpan(int.Parse(m.Groups[1].Value) % 24, int.Parse(m.Groups[2].Value), m.Groups[3].Success ? int.Parse(m.Groups[3].Value) : 0) : (TimeSpan?)null;
        }

        /// <summary>"07:19" / "7:19:05" / เลข Excel 0.7993 (= 19:11)</summary>
        public static TimeSpan? ParseTime(string s)
        {
            s = (s ?? "").Trim();
            if (s.Length == 0) return null;
            var m = Regex.Match(s, @"^(\d{1,2})[:.](\d{2})(?::(\d{2}))?$");
            if (m.Success)
            {
                int h = int.Parse(m.Groups[1].Value), mi = int.Parse(m.Groups[2].Value);
                if (h > 23 || mi > 59) return null;
                return new TimeSpan(h, mi, m.Groups[3].Success ? int.Parse(m.Groups[3].Value) : 0);
            }
            double f;
            if (double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out f) && f >= 0 && f < 1)
            {
                int sec = (int)Math.Round(f * 86400);
                return TimeSpan.FromSeconds(Math.Min(sec, 86399));
            }
            return null;
        }
    }
}
