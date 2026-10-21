using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.Common;
using System.Data.SqlClient;
using System.Globalization;
using System.Reflection;
using System.Threading;

namespace Dashbord
{
    /// <summary>
    /// สถานะล่าสุดของเครื่อง 1 เครื่อง (เก็บในหน่วยความจำ)
    /// </summary>
    public class MachineState
    {
        public string Machine;
        public string Process;         // ส่งมาจาก Node-RED (ถ้ามี) เช่น "Injection", "Mixing"
        public bool Online;
        public int? Status;
        public string StatusText;
        public string Mode;            // operating / loss / offline
        public string Operator;
        public long? ShotCount;
        public double? CycleTime;
        public int? Cavities;
        public long? TargetShots;
        public string JobStart;
        public string JobFinish;
        public long? OkCount, NgCount;   // ชิ้นดี / ชิ้นเสีย (เครื่องที่มีข้อมูล เช่น Seambuffing)
        public double? SpeedPerMin;      // ความเร็ว ชิ้น/นาที
        public double? IdealCt;          // CT มาตรฐานจาก Node-RED (วินาที/ชิ้น)
        public double? IdealCtDb;        // CT มาตรฐานจากตาราง machine.std_cycle_sec (ใช้เมื่อ Node-RED ไม่ส่งมา)
        public double? StdCt { get { return IdealCt ?? IdealCtDb; } }
        public int? CavDb;               // จำนวน Cavity จากตาราง machine.cavities (ใช้เมื่อ HMI ส่ง 1 / ไม่ส่ง)
        public int Cav
        {
            get
            {
                return (Cavities.HasValue && Cavities.Value > 1) ? Cavities.Value
                                      : (CavDb.HasValue && CavDb.Value > 0) ? CavDb.Value
                                      : (Cavities.HasValue && Cavities.Value > 0) ? Cavities.Value : 1;
            }
        }

        public string ProdDay;
        public DateTime CountStart;    // เวลาเริ่มนับยอดของวันนี้ (รับข้อมูลครั้งแรก / ขึ้นวันใหม่ 08:00)
        public long ShotsToday;
        public long[] Hourly = new long[24];
        public double OperatingSec, LossSec, OfflineSec;
        public long? LastShot;
        public long OkToday, NgToday;  // ยอด OK / NG รวมทั้งวัน (นับจากผลต่าง ไม่สนใจหน้างานรีเซ็ต)
        public long? LastOk, LastNg;
        public string LastMode;
        public DateTime LastUpdate;
        public DateTime? LastOnline;   // เวลาล่าสุดที่ได้ข้อมูลจริง (online:true)

        // สำหรับบันทึกลงฐานข้อมูล
        public double[] HourOp = new double[24], HourLoss = new double[24], HourOff = new double[24];
        public string LastCat;         // run / idle / down / off (ใช้บันทึก mc_status_log)
    }

    /// <summary>
    /// ที่เก็บข้อมูลเครื่องจาก Node-RED + คำนวณยอด Count
    /// ค่าหลักอยู่ในหน่วยความจำ (หน้าจอ realtime) และบันทึกลง MySQL (DB: OEE) ทุก 1 นาทีผ่าน OeeDb
    /// เมื่อแอปเริ่มใหม่ จะโหลดยอดของวันนี้กลับจาก DB แล้วนับต่อ
    /// </summary>
    public static class CounterStore
    {
        public const string API_KEY = "";          // ถ้าใส่ค่า ผู้ส่งต้องแนบ header X-Api-Key ให้ตรง
        public const int DAY_START_HOUR = 8;       // วันผลิตเริ่ม 08:00
        public const int MAX_GAP_SEC = 300;        // ช่วงห่างเกิน 5 นาทีไม่นำมาคิดเวลา
        public const int STALE_SEC = 30;           // ไม่มีข้อมูลเกิน 30 วินาที = ขาดการติดต่อ
        public const long MAX_SHOT_DELTA = 1000;   // กันค่ากระโดดผิดปกติต่อ 1 ครั้งที่ส่ง

        static readonly Dictionary<string, MachineState> Machines =
            new Dictionary<string, MachineState>(StringComparer.OrdinalIgnoreCase);
        static readonly object Sync = new object();

        // ------------------------------------------------------------ public API
        public static DateTime ProdDayStart(DateTime t)
        {
            DateTime d = t.Date.AddHours(DAY_START_HOUR);
            return t < d ? d.AddDays(-1) : d;
        }

        /// <summary>รับข้อมูล 1 ครั้งจาก Node-RED แล้วคืนค่าที่คำนวณแล้ว</summary>
        public static Dictionary<string, object> Update(Dictionary<string, object> d, string id)
        {
            lock (Sync)
            {
                EnsureLoaded();
                return ToView(UpdateCore(d, id), DateTime.Now);
            }
        }

        /// <summary>ค่าทุกเครื่อง (หรือเฉพาะเครื่องที่ระบุ) เรียงตามชื่อ</summary>
        public static List<object> Snapshot(string only)
        {
            DateTime now = DateTime.Now;
            var list = new List<object>();
            lock (Sync)
            {
                EnsureLoaded();
                var keys = new List<string>(Machines.Keys);
                keys.Sort(StringComparer.OrdinalIgnoreCase);
                foreach (string k in keys)
                    if (string.IsNullOrEmpty(only) || string.Equals(k, only, StringComparison.OrdinalIgnoreCase))
                        list.Add(ToView(Machines[k], now));
            }
            return list;
        }

        // ------------------------------------------------------------ DB integration
        static bool _loaded;

        /// <summary>ครั้งแรกที่แอปทำงาน: โหลดยอดของวันนี้จาก DB + เริ่มตัวบันทึกทุก 1 นาที</summary>
        static void EnsureLoaded()
        {
            if (_loaded) return;
            _loaded = true;
            OeeDb.LoadToday(Machines, ProdDayStart(DateTime.Now));
            OeeDb.Start();
            ErpQuality.Start();
        }

        public static string CatOf(MachineState m)
        {
            if (!m.Online) return "off";
            if (m.Status >= 17) return "down";
            if (m.Status == 2 || m.Status == 4) return "run";
            return "idle";
        }

        /// <summary>คัดลอกค่าทุกเครื่องสำหรับเขียนลง DB (เรียกจาก OeeDb ทุก 1 นาที)</summary>
        // ---- OEE = A x P x Q (ใช้ทั้งหน้าเว็บและบันทึก DB) ----
        //   A = Operating / (Operating + Loss + Offline)
        //   P = (Shots วันนี้ x Std CT) / Operating          (ต้องมี Std CT)
        //   Q = OK / (OK + NG) ของวันนี้                     (ยังไม่มีข้อมูล NG -> Q = 100%)
        public static void Apq(MachineState m, out double? A, out double? P, out double? Q, out double? O, out bool qAssumed)
        {
            double total = m.OperatingSec + m.LossSec + m.OfflineSec;
            A = total > 0 ? m.OperatingSec * 100.0 / total : (double?)null;
            P = (m.StdCt.HasValue && m.StdCt.Value > 0 && m.OperatingSec > 0)
                ? Math.Min(100.0, m.ShotsToday * m.StdCt.Value * 100.0 / m.OperatingSec) : (double?)null;
            string src;
            Q = QualityOf(m, out src);
            qAssumed = src == "100%";
            O = (A.HasValue && P.HasValue) ? A.Value * P.Value * Q.Value / 10000.0 : (double?)null;
        }

        // Q : 1) OK/NG รายเครื่องจาก PLC  2) NG รายเครื่องจาก ERP (EQID)  3) Q ทั้ง Process จาก ERP  4) ไม่มีข้อมูล -> 100%
        // แผนกที่ให้ NG มาจาก ERP เสมอ (ไม่ใช้ NG จาก PLC) — พนักงานคีย์ NG ใน ERP
        public static readonly HashSet<string> ErpNgProcesses = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "Injection", "Seambuffing" };
        public static bool UsesErpNg(MachineState m)
        {
            return ErpNgProcesses.Contains(string.IsNullOrEmpty(m.Process) ? "Injection" : m.Process.Trim());
        }

        public static double QualityOf(MachineState m, out string source)
        {
            if (UsesErpNg(m))
            {
                double? qe = ErpQuality.ForMachine(m.Machine);                  // NG รายเครื่อง (EQID)
                if (qe.HasValue) { source = "ERP"; return qe.Value; }
                qe = ErpQuality.ForProcess(string.IsNullOrEmpty(m.Process) ? "Injection" : m.Process);
                if (qe.HasValue) { source = "ERP-P"; return qe.Value; }
                source = "100%"; return 100.0;
            }
            long okng = m.OkToday + m.NgToday;
            if (okng > 0) { source = "PLC"; return m.OkToday * 100.0 / okng; }
            if (m.OkCount.HasValue && (m.OkCount.Value + (m.NgCount ?? 0)) > 0)
            { source = "PLC"; return m.OkCount.Value * 100.0 / (m.OkCount.Value + (m.NgCount ?? 0)); }
            double? q = ErpQuality.ForMachine(m.Machine);                       // NG รายเครื่อง (EQID)
            if (q.HasValue) { source = "ERP"; return q.Value; }
            q = ErpQuality.ForProcess(string.IsNullOrEmpty(m.Process) ? "Injection" : m.Process);   // ทั้ง Process
            if (q.HasValue) { source = "ERP-P"; return q.Value; }
            source = "100%"; return 100.0;
        }

        // Std CT จากตาราง machine (OeeDb อ่านมาให้ทุกครั้งที่บันทึก)
        public static void ApplyStdCycle(Dictionary<string, double> std)
        {
            ApplyMachineCfg(std, null);
        }
        public static void ApplyMachineCfg(Dictionary<string, double> std, Dictionary<string, int> cav)
        {
            lock (Sync)
                foreach (MachineState m in Machines.Values)
                {
                    double v; int c;
                    m.IdealCtDb = std.TryGetValue(m.Machine, out v) && v > 0 ? v : (double?)null;
                    if (cav != null) m.CavDb = cav.TryGetValue(m.Machine, out c) && c > 0 ? c : (int?)null;
                }
        }

        public static List<OeeDb.Row> ExportForDb()
        {
            var rows = new List<OeeDb.Row>();
            DateTime now = DateTime.Now;
            DateTime dayStart = ProdDayStart(now);
            int hNow = (int)Math.Floor((now - dayStart).TotalHours);
            lock (Sync)
            {
                foreach (MachineState m in Machines.Values)
                {
                    bool stale = (now - m.LastUpdate).TotalSeconds > STALE_SEC;
                    // กล่อง IoT เงียบไป (ไม่มี POST) -> บันทึกว่า Offline ตั้งแต่ข้อมูลล่าสุด
                    if (stale && m.LastCat != null && m.LastCat != "off")
                    {
                        OeeDb.QueueStatus(m.Machine, m.ProdDay, null, "off", m.LastUpdate, m.ShotCount, m.Operator);
                        m.LastCat = "off";
                    }
                    if (m.ProdDay != dayStart.ToString("yyyy-MM-dd")) continue;   // ยังไม่มีข้อมูลของวันนี้

                    var r = new OeeDb.Row();
                    r.Machine = m.Machine; r.Process = m.Process; r.ProdDay = dayStart; r.CountStart = m.CountStart;
                    r.OperatingSec = m.OperatingSec; r.LossSec = m.LossSec; r.OfflineSec = m.OfflineSec;
                    int cav = m.Cav;
                    r.ShotsToday = m.ShotsToday; r.PiecesToday = m.ShotsToday * cav;
                    r.Counter = m.ShotCount; r.Cycle = m.CycleTime; r.Status = m.Status; r.Operator = m.Operator;
                    r.Online = m.Online && !stale; r.Category = stale ? "off" : CatOf(m);
                    r.TargetShots = m.TargetShots; r.JobStart = m.JobStart; r.JobFinish = m.JobFinish;
                    double total = m.OperatingSec + m.LossSec + m.OfflineSec;
                    double? A, P, Q, O; bool qa;
                    Apq(m, out A, out P, out Q, out O, out qa);
                    r.Availability = A.HasValue ? Math.Round(A.Value, 2) : (double?)null;
                    r.Performance = P.HasValue ? Math.Round(P.Value, 2) : (double?)null;
                    r.Quality = Q.HasValue ? QPctUtil.Down(Q.Value) : (double?)null;
                    r.Oee = O.HasValue ? Math.Round(O.Value, 2) : (double?)null;
                    r.OkToday = m.OkToday; r.NgToday = m.NgToday; r.StdCt = m.StdCt;
                    for (int h = Math.Max(0, hNow - 1); h <= Math.Min(23, hNow); h++)
                        r.Hours.Add(new OeeDb.HourRow
                        {
                            HourStart = dayStart.AddHours(h),
                            Shots = m.Hourly[h],
                            Op = m.HourOp[h],
                            Loss = m.HourLoss[h],
                            Off = m.HourOff[h]
                        });
                    rows.Add(r);
                }
            }
            return rows;
        }

        // ------------------------------------------------------------ helpers
        static object Get(Dictionary<string, object> d, string k)
        {
            object v;
            return (d != null && d.TryGetValue(k, out v)) ? v : null;
        }
        public static string GetStr(Dictionary<string, object> d, string k)
        {
            object v = Get(d, k);
            return v == null ? null : Convert.ToString(v, CultureInfo.InvariantCulture).Trim();
        }
        static long? GetLong(Dictionary<string, object> d, string k)
        {
            object v = Get(d, k);
            if (v == null) return null;
            try { return Convert.ToInt64(v, CultureInfo.InvariantCulture); } catch { return null; }
        }
        static double? GetDouble(Dictionary<string, object> d, string k)
        {
            object v = Get(d, k);
            if (v == null) return null;
            try { return Convert.ToDouble(v, CultureInfo.InvariantCulture); } catch { return null; }
        }
        static bool GetBool(Dictionary<string, object> d, string k, bool def)
        {
            object v = Get(d, k);
            if (v == null) return def;
            if (v is bool) return (bool)v;
            string s = Convert.ToString(v, CultureInfo.InvariantCulture).ToLowerInvariant();
            return s == "true" || s == "1" || s == "on";
        }

        /// <summary>
        /// กันกรณี Node-RED ยังไม่ตั้ง WORD_SWAP = true : ค่า 32-bit สลับ word แล้วได้เลขเป็นทวีคูณของ 65536
        /// เช่น 59 กลายเป็น 3,866,624 (59 x 65536) -> แปลงกลับเป็น 59
        /// </summary>
        static long? FixWordSwap(long? v)
        {
            if (!v.HasValue) return v;
            long x = v.Value;
            if (x > 0xFFFF && x <= 0xFFFFFFFFL && (x & 0xFFFF) == 0) return x >> 16;
            return v;
        }

        static void ResetDay(MachineState m, string dayKey, DateTime now)
        {
            m.ProdDay = dayKey;
            m.CountStart = now;
            m.ShotsToday = 0;
            m.OkToday = m.NgToday = 0;
            m.Hourly = new long[24];
            m.HourOp = new double[24]; m.HourLoss = new double[24]; m.HourOff = new double[24];
            m.OperatingSec = m.LossSec = m.OfflineSec = 0;
        }

        // ------------------------------------------------------------ core
        static MachineState UpdateCore(Dictionary<string, object> d, string id)
        {
            DateTime now = DateTime.Now;
            DateTime dayStart = ProdDayStart(now);
            string dayKey = dayStart.ToString("yyyy-MM-dd");

            MachineState m;
            if (!Machines.TryGetValue(id, out m))
            {
                m = new MachineState();
                m.Machine = id;
                m.ProdDay = dayKey;
                m.CountStart = now;
                m.LastUpdate = now;
                Machines[id] = m;
            }

            // 1) นับเวลาที่ผ่านไปตามสถานะ "ก่อนหน้า"
            if (m.LastMode != null)
            {
                double gap = (now - m.LastUpdate).TotalSeconds;
                if (gap > 0 && gap <= MAX_GAP_SEC)
                {
                    int hg = (int)Math.Floor((now - dayStart).TotalHours);
                    bool sameDay = m.ProdDay == dayKey && hg >= 0 && hg < 24;
                    if (m.LastMode == "operating") { m.OperatingSec += gap; if (sameDay) m.HourOp[hg] += gap; }
                    else if (m.LastMode == "loss") { m.LossSec += gap; if (sameDay) m.HourLoss[hg] += gap; }
                    else { m.OfflineSec += gap; if (sameDay) m.HourOff[hg] += gap; }
                }
            }

            // 2) ขึ้นวันผลิตใหม่ (08:00) -> เริ่มนับใหม่
            if (m.ProdDay != dayKey) ResetDay(m, dayKey, now);

            // 3) ค่าล่าสุด
            m.Online = GetBool(d, "online", true);
            string proc = GetStr(d, "process");
            if (!string.IsNullOrEmpty(proc)) m.Process = proc;
            if (m.Online)
            {
                m.LastOnline = now;
                long? st = GetLong(d, "status");
                m.Status = st.HasValue ? (int?)st.Value : null;
                m.StatusText = GetStr(d, "statusText");
                m.Operator = GetStr(d, "operator");
                m.ShotCount = FixWordSwap(GetLong(d, "shotCount"));
                m.CycleTime = GetDouble(d, "cycleTime");
                long? cav = GetLong(d, "cavities");
                m.Cavities = cav.HasValue ? (int?)cav.Value : null;
                m.TargetShots = GetLong(d, "targetShots");
                m.JobStart = GetStr(d, "jobStart");
                m.JobFinish = GetStr(d, "jobFinish");
                m.OkCount = GetLong(d, "okCount");
                m.NgCount = GetLong(d, "ngCount");
                m.SpeedPerMin = GetDouble(d, "speedPerMin");
                double? ict = GetDouble(d, "idealCycleTime");
                if (ict.HasValue && ict.Value > 0) m.IdealCt = ict;
                m.Mode = (m.Status == 2 || m.Status == 4) ? "operating" : "loss";
            }
            else
            {
                m.StatusText = "Offline";
                m.Mode = "offline";
            }

            // 4) ยอด Shot ของวัน จากผลต่าง Counter
            if (m.Online && m.ShotCount.HasValue)
            {
                if (m.LastShot.HasValue)
                {
                    long delta = m.ShotCount.Value - m.LastShot.Value;
                    if (delta < 0) delta = m.ShotCount.Value;            // Counter ถูกรีเซ็ต / เปลี่ยน Job
                    if (delta < 0 || delta > MAX_SHOT_DELTA) delta = 0;  // ค่าผิดปกติ ไม่นับ
                    if (delta > 0)
                    {
                        m.ShotsToday += delta;
                        int h = (int)Math.Floor((now - dayStart).TotalHours);
                        if (h >= 0 && h < 24) m.Hourly[h] += delta;
                    }
                }
                m.LastShot = m.ShotCount;   // ครั้งแรก = ตั้งฐาน
            }

            // 4.1) ยอด OK / NG ของวัน จากผลต่าง (Counter หน้างานรีเซ็ตกี่ครั้งก็นับต่อ)
            if (m.Online)
            {
                m.OkToday += CountDelta(m.OkCount, ref m.LastOk);
                m.NgToday += CountDelta(m.NgCount, ref m.LastNg);
            }

            // 5) สถานะเปลี่ยน -> บันทึกประวัติ (mc_status_log)
            string cat = CatOf(m);
            if (cat != m.LastCat)
            {
                OeeDb.QueueStatus(m.Machine, dayKey, m.Online ? m.Status : null, cat, now, m.ShotCount, m.Operator);
                m.LastCat = cat;
            }

            m.LastMode = m.Mode;
            m.LastUpdate = now;
            return m;
        }

        // ผลต่างของ Counter: ลดลง = ถูกรีเซ็ต -> นับค่าใหม่ทั้งหมด, ครั้งแรก = ตั้งฐาน
        static long CountDelta(long? cur, ref long? last)
        {
            if (!cur.HasValue) return 0;
            long delta = 0;
            if (last.HasValue)
            {
                delta = cur.Value - last.Value;
                if (delta < 0) delta = cur.Value;
                if (delta < 0 || delta > MAX_SHOT_DELTA) delta = 0;
            }
            last = cur;
            return delta;
        }

        static Dictionary<string, object> ToView(MachineState m, DateTime now)
        {
            bool stale = (now - m.LastUpdate).TotalSeconds > STALE_SEC;
            bool online = m.Online && !stale;
            double total = m.OperatingSec + m.LossSec + m.OfflineSec;
            int cav = m.Cav;

            var hourly = new List<object>();
            DateTime ds = ProdDayStart(now);
            for (int i = 0; i < 24; i++)
                hourly.Add(new Dictionary<string, object> {
                    { "hour", ds.AddHours(i).ToString("HH:00") }, { "shots", m.Hourly[i] } });

            var v = new Dictionary<string, object>();
            v["machine"] = m.Machine;
            v["process"] = m.Process;
            v["online"] = online;
            v["stale"] = stale;
            v["power"] = online ? "ON" : "OFF";
            v["status"] = m.Status;
            v["statusText"] = stale ? "No data" : m.StatusText;
            v["mode"] = stale ? "offline" : m.Mode;
            v["operator"] = m.Operator;
            v["shotCount"] = m.ShotCount;
            v["cycleTime"] = m.CycleTime;
            v["cavities"] = cav;                 // Cavity ที่ใช้คูณจริง (HMI ถ้า > 1 ไม่งั้นจากตาราง machine)
            v["cavitiesHmi"] = m.Cavities;       // ค่าที่ HMI ส่งมา
            v["cavitiesDb"] = m.CavDb;           // ค่าในตาราง machine.cavities
            v["targetShots"] = m.TargetShots;
            v["jobStart"] = m.JobStart;
            v["jobFinish"] = m.JobFinish;
            v["okCount"] = m.OkCount;
            v["ngCount"] = m.NgCount;
            v["speedPerMin"] = m.SpeedPerMin;
            v["okToday"] = m.OkToday;
            v["ngToday"] = m.NgToday;
            long okng = m.OkToday + m.NgToday;                       // Quality ของวัน (จากยอดรวมทั้งวัน)
            if (okng == 0) okng = (m.OkCount ?? 0) + (m.NgCount ?? 0);  // ยังไม่มียอดวันนี้ -> ใช้ค่าปัจจุบัน
            long okv = (m.OkToday + m.NgToday) > 0 ? m.OkToday : (m.OkCount ?? 0);
            v["quality"] = (m.OkCount.HasValue && okng > 0) ? QPctUtil.Down(okv * 100.0 / okng) : (double?)null;
            v["prodDay"] = m.ProdDay;
            v["countStart"] = m.CountStart.ToString("yyyy-MM-dd HH:mm:ss");
            v["shotsToday"] = m.ShotsToday;
            v["piecesToday"] = m.ShotsToday * cav;
            v["piecesCounter"] = m.ShotCount.HasValue ? m.ShotCount.Value * cav : (long?)null;
            v["operatingHours"] = Math.Round(m.OperatingSec / 3600.0, 4);
            v["lossHours"] = Math.Round(m.LossSec / 3600.0, 4);
            v["offlineHours"] = Math.Round(m.OfflineSec / 3600.0, 4);
            v["availability"] = total > 0 ? Math.Round(m.OperatingSec * 100.0 / total, 1) : (double?)null;
            // ---- OEE = A x P x Q ----
            double? A, P, Q, O; bool qAssumed;
            Apq(m, out A, out P, out Q, out O, out qAssumed);
            v["idealCycleTime"] = m.StdCt;
            v["performance"] = P.HasValue ? Math.Round(P.Value, 1) : (double?)null;
            v["quality"] = Q.HasValue ? QPctUtil.Down(Q.Value) : (double?)null;
            string qSrc; QualityOf(m, out qSrc);
            v["qualityAssumed"] = qAssumed;          // true = ยังไม่มีข้อมูล NG (OEE คิด Q = 100%)
            v["qualitySource"] = qSrc;               // PLC | ERP | ERP-P | 100%
            double eOut, eNg;
            if (ErpQuality.CountsForMachine(m.Machine, out eOut, out eNg)) { v["erpOut"] = eOut; v["erpNg"] = eNg; }
            else { v["erpOut"] = null; v["erpNg"] = null; }
            v["oee"] = O.HasValue ? Math.Round(O.Value, 1) : (double?)null;
            v["avgCycleToday"] = m.ShotsToday > 0 ? Math.Round(m.OperatingSec / m.ShotsToday, 1) : (double?)null;
            v["jobProgress"] = (m.TargetShots.HasValue && m.TargetShots.Value > 0 && m.ShotCount.HasValue)
                                  ? Math.Round(m.ShotCount.Value * 100.0 / m.TargetShots.Value, 1) : (double?)null;
            v["hourly"] = hourly;
            v["lastUpdate"] = m.LastUpdate.ToString("yyyy-MM-dd HH:mm:ss");
            v["lastOnline"] = m.LastOnline.HasValue ? m.LastOnline.Value.ToString("yyyy-MM-dd HH:mm:ss") : null;
            return v;
        }
    }

    /// <summary>
    /// บันทึกลง MySQL (DB: OEE) — connection string ชื่อ "OEEConnectionString" ใน Web.config
    /// ใช้ไลบรารี MySqlConnector (NuGet) ถ้ายังไม่ได้ติดตั้ง/ยังไม่ตั้งค่า ระบบหน้าจอยังทำงานปกติ แค่ไม่บันทึก
    /// เขียนทุก 1 นาทีแบบ background ไม่ทำให้หน้าเว็บช้า ถ้า DB ล่มจะลองใหม่รอบถัดไป
    /// </summary>
    public static class OeeDb
    {
        public const string CONN_NAME = "OEEConnectionString";
        public const int FLUSH_SEC = 60;
        const int MAX_PENDING_EVENTS = 5000;

        public class HourRow { public DateTime HourStart; public long Shots; public double Op, Loss, Off; }
        public class Row
        {
            public string Machine, Process, Operator, Category, JobStart, JobFinish;
            public DateTime ProdDay, CountStart;
            public double OperatingSec, LossSec, OfflineSec;
            public long ShotsToday, PiecesToday;
            public long? Counter, TargetShots;
            public double? Cycle, Availability, Performance, Quality, Oee, StdCt;
            public long OkToday, NgToday;
            public int? Status;
            public bool Online;
            public List<HourRow> Hours = new List<HourRow>();
        }
        class StatusEvent
        {
            public string Machine, Category, Operator; public DateTime ProdDay, Time; public int? Status; public long? Counter;
        }

        static readonly object EvSync = new object();
        static List<StatusEvent> _events = new List<StatusEvent>();
        static Timer _timer;
        static int _busy;
        static DbProviderFactory _factory;
        static bool? _hasOeeCols;   // ตาราง mc_daily มีคอลัมน์ OEE แล้วหรือยัง (รัน OEE_add_oee_columns.sql)
        static string _conn;

        public static bool Enabled { get; private set; }
        public static DateTime? LastWrite { get; private set; }
        public static string LastError { get; private set; }

        public static Dictionary<string, object> Info()
        {
            return new Dictionary<string, object> {
                { "enabled", Enabled },
                { "lastWrite", LastWrite.HasValue ? LastWrite.Value.ToString("yyyy-MM-dd HH:mm:ss") : null },
                { "lastError", LastError },
                { "oeeColumns", _hasOeeCols } };
        }

        // ------------------------------------------------------------ setup
        static bool Init()
        {
            if (_factory != null && _conn != null) return true;
            ConnectionStringSettings cs = ConfigurationManager.ConnectionStrings[CONN_NAME];
            if (cs == null || string.IsNullOrWhiteSpace(cs.ConnectionString) || cs.ConnectionString.Contains("ใส่รหัสผ่าน"))
            {
                LastError = "ยังไม่ได้ตั้งค่า " + CONN_NAME + " ใน Web.config";
                return false;
            }
            string[] types = {
                "MySqlConnector.MySqlConnectorFactory, MySqlConnector",      // NuGet: MySqlConnector (แนะนำ)
                "MySql.Data.MySqlClient.MySqlClientFactory, MySql.Data"      // NuGet: MySql.Data (สำรอง)
            };
            foreach (string tn in types)
            {
                try
                {
                    Type t = Type.GetType(tn, false);
                    if (t == null) continue;
                    FieldInfo f = t.GetField("Instance", BindingFlags.Public | BindingFlags.Static);
                    if (f == null) continue;
                    _factory = (DbProviderFactory)f.GetValue(null);
                    break;
                }
                catch { }
            }
            if (_factory == null)
            {
                LastError = "ไม่พบไลบรารี MySqlConnector (ติดตั้งผ่าน NuGet)";
                return false;
            }
            _conn = cs.ConnectionString;
            return true;
        }

        public static void Start()
        {
            Enabled = Init();
            if (!Enabled || _timer != null) return;
            _timer = new Timer(delegate { Flush(); }, null, FLUSH_SEC * 1000, FLUSH_SEC * 1000);
        }

        static DbConnection Open()
        {
            DbConnection c = _factory.CreateConnection();
            c.ConnectionString = _conn;
            c.Open();
            return c;
        }

        static DbCommand Cmd(DbConnection c, DbTransaction tx, string sql, params object[] nameValues)
        {
            DbCommand cmd = c.CreateCommand();
            cmd.Transaction = tx;
            cmd.CommandText = sql;
            cmd.CommandTimeout = 15;
            for (int i = 0; i + 1 < nameValues.Length; i += 2)
            {
                DbParameter p = cmd.CreateParameter();
                p.ParameterName = (string)nameValues[i];
                p.Value = nameValues[i + 1] ?? DBNull.Value;
                cmd.Parameters.Add(p);
            }
            return cmd;
        }

        static object DbTime(string s)
        {
            DateTime t;
            if (!string.IsNullOrEmpty(s) && DateTime.TryParseExact(s, "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out t))
                return t;
            return null;
        }

        // ------------------------------------------------------------ Master Sample (หน้า MasterSample.aspx)
        //   master_sample       : ข้อมูลสินค้าต้นแบบ 1 แถว = 1 สินค้า x 1 Supplier (บาร์โค้ดเดียวกันมีได้หลาย Supplier)
        //   master_sample_photo : รูปแต่ละช่อง (logo1, logo2, side1, ...) เก็บเป็น BLOB ในฐานข้อมูล
        static bool _msTable;
        public static readonly string[] MS_FIELDS = { "product_name", "product_number", "supplier", "barcode", "barcode2", "sqe", "prepared", "supplier_approver", "sample_location", "short_name", "comment" };

        static void EnsureMsTable(DbConnection c)
        {
            if (_msTable) return;
            Cmd(c, null, @"CREATE TABLE IF NOT EXISTS master_sample (
                              id                INT UNSIGNED NOT NULL AUTO_INCREMENT,
                              product_name      VARCHAR(120) NOT NULL,
                              product_number    VARCHAR(40)  NULL,
                              supplier          VARCHAR(40)  NULL,
                              barcode           VARCHAR(40)  NULL COMMENT 'BarCode 1 (Unit / UPC)',
                              barcode2          VARCHAR(40)  NULL COMMENT 'BarCode 2 (Case / GTIN-14)',
                              sqe               VARCHAR(40)  NULL COMMENT 'SQE/SI',
                              prepared          DATE         NULL,
                              supplier_approver VARCHAR(60)  NULL,
                              sample_location   VARCHAR(60)  NULL,
                              short_name        VARCHAR(80)  NULL,
                              comment           VARCHAR(500) NULL,
                              updated_at        DATETIME     NULL,
                              updated_ip        VARCHAR(45)  NULL,
                              PRIMARY KEY (id),
                              KEY ix_barcode (barcode),
                              KEY ix_barcode2 (barcode2),
                              KEY ix_pn (product_number)
                           ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
            // ตารางเดิม (ก่อนมี BarCode 2) -> เพิ่มคอลัมน์
            if (Convert.ToInt32(Cmd(c, null, "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'master_sample' AND COLUMN_NAME = 'barcode2'").ExecuteScalar(), CultureInfo.InvariantCulture) == 0)
            {
                Cmd(c, null, "ALTER TABLE master_sample ADD COLUMN barcode2 VARCHAR(40) NULL COMMENT 'BarCode 2 (Case / GTIN-14)' AFTER barcode").ExecuteNonQuery();
                Cmd(c, null, "ALTER TABLE master_sample ADD KEY ix_barcode2 (barcode2)").ExecuteNonQuery();
            }
            Cmd(c, null, @"CREATE TABLE IF NOT EXISTS master_sample_photo (
                              sample_id    INT UNSIGNED NOT NULL,
                              slot         VARCHAR(20)  NOT NULL,
                              content_type VARCHAR(40)  NOT NULL,
                              data         MEDIUMBLOB   NOT NULL,
                              uploaded_at  DATETIME     NOT NULL,
                              uploaded_ip  VARCHAR(45)  NULL,
                              PRIMARY KEY (sample_id, slot)
                           ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
            // ตารางว่าง -> นำเข้าข้อมูลตั้งต้นจาก DataMasterSheet.xlsx (MasterSampleSeed.cs)
            if (Convert.ToInt32(Cmd(c, null, "SELECT COUNT(*) FROM master_sample").ExecuteScalar(), CultureInfo.InvariantCulture) == 0)
            {
                var js = new System.Web.Script.Serialization.JavaScriptSerializer();
                var rows = js.Deserialize<List<Dictionary<string, string>>>(MasterSampleSeed.Json);
                foreach (var r in rows)
                {
                    DateTime dt; object prep = DateTime.TryParseExact(r["prep"], "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out dt) ? (object)dt : null;
                    Cmd(c, null, @"INSERT INTO master_sample (product_name, product_number, supplier, barcode, sqe, prepared, supplier_approver, sample_location, short_name, updated_at)
                                   VALUES (@a, @b, @c, @d, @e, @f, @g, @h, @i, NOW())",
                        "@a", r["name"], "@b", NullIfEmpty(r["pn"]), "@c", NullIfEmpty(r["sup"]), "@d", NullIfEmpty(r["bc"]), "@e", NullIfEmpty(r["sqe"]),
                        "@f", prep, "@g", NullIfEmpty(r["appr"]), "@h", NullIfEmpty(r["loc"]), "@i", NullIfEmpty(r["sn"])).ExecuteNonQuery();
                }
            }
            _msTable = true;
        }
        static object NullIfEmpty(string s) { return string.IsNullOrWhiteSpace(s) ? null : (object)s.Trim(); }

        static Dictionary<string, object> MsRow(DbDataReader r)
        {
            var d = new Dictionary<string, object>();
            d["id"] = Convert.ToInt32(r["id"], CultureInfo.InvariantCulture);
            foreach (string f in MS_FIELDS)
            {
                object v = r[f];
                d[f] = v == DBNull.Value ? "" : f == "prepared" ? Convert.ToDateTime(v, CultureInfo.InvariantCulture).ToString("yyyy-MM-dd") : Convert.ToString(v, CultureInfo.InvariantCulture);
            }
            d["updated_at"] = r["updated_at"] == DBNull.Value ? "" : Convert.ToDateTime(r["updated_at"], CultureInfo.InvariantCulture).ToString("yyyy-MM-dd HH:mm");
            d["photos"] = r["photos"] == DBNull.Value ? "" : Convert.ToString(r["photos"], CultureInfo.InvariantCulture);   // slot1,slot2,...
            return d;
        }
        const string MS_SELECT = @"SELECT s.*, (SELECT GROUP_CONCAT(p.slot) FROM master_sample_photo p WHERE p.sample_id = s.id) AS photos FROM master_sample s ";

        /// <summary>รายการทั้งหมด (ไม่มีรูป) เรียงตามวันที่จัดทำล่าสุด</summary>
        public static List<Dictionary<string, object>> MsList()
        {
            if (!Init()) throw new Exception(LastError ?? "DB ยังไม่ได้ตั้งค่า");
            var list = new List<Dictionary<string, object>>();
            using (DbConnection c = Open())
            {
                EnsureMsTable(c);
                using (DbDataReader r = Cmd(c, null, MS_SELECT + "ORDER BY s.prepared DESC, s.id DESC").ExecuteReader())
                    while (r.Read()) list.Add(MsRow(r));
            }
            return list;
        }

        public static Dictionary<string, object> MsGet(int id)
        {
            if (!Init()) throw new Exception(LastError ?? "DB ยังไม่ได้ตั้งค่า");
            using (DbConnection c = Open())
            {
                EnsureMsTable(c);
                using (DbDataReader r = Cmd(c, null, MS_SELECT + "WHERE s.id = @id", "@id", id).ExecuteReader())
                    return r.Read() ? MsRow(r) : null;
            }
        }

        /// <summary>บันทึก (id = 0 → เพิ่มใหม่) · คืน id</summary>
        public static int MsSave(int id, Dictionary<string, string> v, string ip)
        {
            if (!Init()) throw new Exception(LastError ?? "DB ยังไม่ได้ตั้งค่า");
            string name; if (!v.TryGetValue("product_name", out name) || string.IsNullOrWhiteSpace(name)) throw new Exception("ต้องใส่ Product Name");
            var args = new List<object>();
            foreach (string f in MS_FIELDS)
            {
                string s; v.TryGetValue(f, out s); s = (s ?? "").Trim();
                object val = s.Length == 0 ? null : (object)s;
                if (f == "prepared" && val != null)
                {
                    DateTime dt;
                    if (!DateTime.TryParseExact(s, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out dt)) throw new Exception("วันที่ Prepared ต้องเป็น yyyy-MM-dd");
                    val = dt;
                }
                int max = f == "comment" ? 500 : f == "product_name" ? 120 : f == "short_name" ? 80 : f == "supplier_approver" || f == "sample_location" ? 60 : 40;
                if (val is string && ((string)val).Length > max) val = ((string)val).Substring(0, max);
                args.Add("@" + f); args.Add(val);
            }
            args.Add("@ip"); args.Add(ip); args.Add("@id"); args.Add(id);
            using (DbConnection c = Open())
            {
                EnsureMsTable(c);
                if (id > 0)
                {
                    var sets = new List<string>(); foreach (string f in MS_FIELDS) sets.Add(f + " = @" + f);
                    if (Cmd(c, null, "UPDATE master_sample SET " + string.Join(", ", sets) + ", updated_at = NOW(), updated_ip = @ip WHERE id = @id", args.ToArray()).ExecuteNonQuery() == 0)
                        throw new Exception("ไม่พบรายการ id " + id);
                    return id;
                }
                var ps = new List<string>(); foreach (string f in MS_FIELDS) ps.Add("@" + f);
                Cmd(c, null, "INSERT INTO master_sample (" + string.Join(", ", MS_FIELDS) + ", updated_at, updated_ip) VALUES (" + string.Join(", ", ps) + ", NOW(), @ip)", args.ToArray()).ExecuteNonQuery();
                return Convert.ToInt32(Cmd(c, null, "SELECT LAST_INSERT_ID()").ExecuteScalar(), CultureInfo.InvariantCulture);
            }
        }

        public static void MsDelete(int id)
        {
            if (!Init()) throw new Exception(LastError ?? "DB ยังไม่ได้ตั้งค่า");
            using (DbConnection c = Open())
            {
                EnsureMsTable(c);
                Cmd(c, null, "DELETE FROM master_sample_photo WHERE sample_id = @id", "@id", id).ExecuteNonQuery();
                Cmd(c, null, "DELETE FROM master_sample WHERE id = @id", "@id", id).ExecuteNonQuery();
            }
        }

        public static void MsPhotoPut(int id, string slot, string contentType, byte[] data, string ip)
        {
            if (!Init()) throw new Exception(LastError ?? "DB ยังไม่ได้ตั้งค่า");
            using (DbConnection c = Open())
            {
                EnsureMsTable(c);
                Cmd(c, null, @"INSERT INTO master_sample_photo (sample_id, slot, content_type, data, uploaded_at, uploaded_ip) VALUES (@id, @s, @ct, @d, NOW(), @ip)
                               ON DUPLICATE KEY UPDATE content_type = @ct, data = @d, uploaded_at = NOW(), uploaded_ip = @ip",
                    "@id", id, "@s", slot, "@ct", contentType, "@d", data, "@ip", ip).ExecuteNonQuery();
                Cmd(c, null, "UPDATE master_sample SET updated_at = NOW(), updated_ip = @ip WHERE id = @id", "@id", id, "@ip", ip).ExecuteNonQuery();
            }
        }

        public static void MsPhotoDelete(int id, string slot)
        {
            if (!Init()) throw new Exception(LastError ?? "DB ยังไม่ได้ตั้งค่า");
            using (DbConnection c = Open())
            {
                EnsureMsTable(c);
                Cmd(c, null, "DELETE FROM master_sample_photo WHERE sample_id = @id AND slot = @s", "@id", id, "@s", slot).ExecuteNonQuery();
            }
        }

        /// <summary>อ่านรูป · คืน null ถ้าไม่มี</summary>
        public static byte[] MsPhotoGet(int id, string slot, out string contentType, out DateTime uploaded)
        {
            contentType = null; uploaded = DateTime.MinValue;
            if (!Init()) throw new Exception(LastError ?? "DB ยังไม่ได้ตั้งค่า");
            using (DbConnection c = Open())
            {
                EnsureMsTable(c);
                using (DbDataReader r = Cmd(c, null, "SELECT content_type, uploaded_at, data FROM master_sample_photo WHERE sample_id = @id AND slot = @s", "@id", id, "@s", slot).ExecuteReader())
                {
                    if (!r.Read()) return null;
                    contentType = r.GetString(0);
                    uploaded = Convert.ToDateTime(r.GetValue(1), CultureInfo.InvariantCulture);
                    return (byte[])r.GetValue(2);
                }
            }
        }

        // ------------------------------------------------------------ ถังน้ำ (หน้า WaterTank.aspx)
        //   water_state : สถานะล่าสุดต่อถัง (ระดับ, ตั้งแต่เมื่อไร, แจ้ง LINE ล่าสุด, ส่งสรุปรายวันวันไหนแล้ว)
        //   water_event : ประวัติ (level = เปลี่ยนระดับ, line = ส่ง LINE)
        static bool _waterTable;

        public class WaterState
        {
            public string Tank, Level, AlertType, DailyDay; public DateTime? Since, LastSeen, AlertAt; public int? Di1, Di2, Di3;
        }

        static void EnsureWaterTable(DbConnection c)
        {
            if (_waterTable) return;
            Cmd(c, null, @"CREATE TABLE IF NOT EXISTS water_state (
                              tank        VARCHAR(40) NOT NULL,
                              level       VARCHAR(10) NULL COMMENT 'full / normal / low / empty / fault',
                              since       DATETIME    NULL,
                              last_seen   DATETIME    NULL,
                              di1         TINYINT     NULL,
                              di2         TINYINT     NULL,
                              di3         TINYINT     NULL,
                              alert_type  VARCHAR(10) NULL COMMENT 'แจ้ง LINE ล่าสุดเรื่องอะไร',
                              alert_at    DATETIME    NULL,
                              daily_day   VARCHAR(10) NULL COMMENT 'วันที่ส่งสรุปรายวันล่าสุด yyyy-MM-dd',
                              PRIMARY KEY (tank)
                           ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
            // ตารางเดิม (ก่อนมี Relay ตัวที่ 3) -> เพิ่มคอลัมน์ di3
            if (Convert.ToInt32(Cmd(c, null, "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'water_state' AND COLUMN_NAME = 'di3'").ExecuteScalar(), CultureInfo.InvariantCulture) == 0)
                Cmd(c, null, "ALTER TABLE water_state ADD COLUMN di3 TINYINT NULL AFTER di2").ExecuteNonQuery();
            Cmd(c, null, @"CREATE TABLE IF NOT EXISTS water_event (
                              id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                              tank    VARCHAR(40)  NOT NULL,
                              at      DATETIME     NOT NULL,
                              kind    VARCHAR(10)  NOT NULL COMMENT 'level / line',
                              level   VARCHAR(10)  NULL,
                              prev    VARCHAR(10)  NULL,
                              ok      TINYINT(1)   NULL,
                              note    VARCHAR(500) NULL,
                              PRIMARY KEY (id),
                              KEY ix_tank_at (tank, at)
                           ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
            _waterTable = true;
        }

        public static WaterState WaterLoad(string tank)
        {
            if (!Init()) throw new Exception(LastError ?? "DB ยังไม่ได้ตั้งค่า");
            using (DbConnection c = Open())
            {
                EnsureWaterTable(c);
                using (DbDataReader r = Cmd(c, null, "SELECT level, since, last_seen, di1, di2, alert_type, alert_at, daily_day, di3 FROM water_state WHERE tank = @t", "@t", tank).ExecuteReader())
                {
                    var st = new WaterState { Tank = tank };
                    if (!r.Read()) return st;
                    st.Level = r.IsDBNull(0) ? null : r.GetString(0);
                    st.Since = r.IsDBNull(1) ? (DateTime?)null : Convert.ToDateTime(r.GetValue(1), CultureInfo.InvariantCulture);
                    st.LastSeen = r.IsDBNull(2) ? (DateTime?)null : Convert.ToDateTime(r.GetValue(2), CultureInfo.InvariantCulture);
                    st.Di1 = r.IsDBNull(3) ? (int?)null : Convert.ToInt32(r.GetValue(3), CultureInfo.InvariantCulture);
                    st.Di2 = r.IsDBNull(4) ? (int?)null : Convert.ToInt32(r.GetValue(4), CultureInfo.InvariantCulture);
                    st.AlertType = r.IsDBNull(5) ? null : r.GetString(5);
                    st.AlertAt = r.IsDBNull(6) ? (DateTime?)null : Convert.ToDateTime(r.GetValue(6), CultureInfo.InvariantCulture);
                    st.DailyDay = r.IsDBNull(7) ? null : r.GetString(7);
                    st.Di3 = r.IsDBNull(8) ? (int?)null : Convert.ToInt32(r.GetValue(8), CultureInfo.InvariantCulture);
                    return st;
                }
            }
        }

        public static void WaterSave(WaterState st)
        {
            if (!Init()) throw new Exception(LastError ?? "DB ยังไม่ได้ตั้งค่า");
            using (DbConnection c = Open())
            {
                EnsureWaterTable(c);
                Cmd(c, null, @"INSERT INTO water_state (tank, level, since, last_seen, di1, di2, di3, alert_type, alert_at, daily_day)
                               VALUES (@t, @l, @s, @ls, @d1, @d2, @d3, @at, @aa, @dd)
                               ON DUPLICATE KEY UPDATE level = @l, since = @s, last_seen = @ls, di1 = @d1, di2 = @d2, di3 = @d3,
                                                       alert_type = @at, alert_at = @aa, daily_day = @dd",
                    "@t", st.Tank, "@l", st.Level, "@s", st.Since, "@ls", st.LastSeen, "@d1", st.Di1, "@d2", st.Di2, "@d3", st.Di3,
                    "@at", st.AlertType, "@aa", st.AlertAt, "@dd", st.DailyDay).ExecuteNonQuery();
            }
        }

        public static void WaterAddEvent(string tank, DateTime at, string kind, string level, string prev, bool? ok, string note)
        {
            if (!Init()) return;
            try
            {
                using (DbConnection c = Open())
                {
                    EnsureWaterTable(c);
                    if (note != null && note.Length > 500) note = note.Substring(0, 500);
                    Cmd(c, null, "INSERT INTO water_event (tank, at, kind, level, prev, ok, note) VALUES (@t, @a, @k, @l, @p, @o, @n)",
                        "@t", tank, "@a", at, "@k", kind, "@l", level, "@p", prev, "@o", ok.HasValue ? (object)(ok.Value ? 1 : 0) : null, "@n", note).ExecuteNonQuery();
                }
            }
            catch (Exception ex) { LastError = "water event: " + ex.Message; }
        }

        /// <summary>ประวัติถังน้ำช่วง [from, to) เรียงเก่า→ใหม่ + ระดับก่อนหน้าช่วง (ไว้วาดแถบเวลา)</summary>
        public static List<Dictionary<string, object>> WaterEvents(string tank, DateTime from, DateTime to, out string levelBefore)
        {
            levelBefore = null;
            var list = new List<Dictionary<string, object>>();
            if (!Init()) throw new Exception(LastError ?? "DB ยังไม่ได้ตั้งค่า");
            using (DbConnection c = Open())
            {
                EnsureWaterTable(c);
                object o = Cmd(c, null, "SELECT level FROM water_event WHERE tank = @t AND kind = 'level' AND at < @f ORDER BY at DESC LIMIT 1", "@t", tank, "@f", from).ExecuteScalar();
                if (o != null && o != DBNull.Value) levelBefore = Convert.ToString(o, CultureInfo.InvariantCulture);
                using (DbDataReader r = Cmd(c, null, @"SELECT at, kind, level, prev, ok, note FROM water_event
                                                        WHERE tank = @t AND at >= @f AND at < @to ORDER BY at, id LIMIT 2000",
                                             "@t", tank, "@f", from, "@to", to).ExecuteReader())
                    while (r.Read())
                        list.Add(new Dictionary<string, object> {
                            { "at", Convert.ToDateTime(r.GetValue(0), CultureInfo.InvariantCulture).ToString("yyyy-MM-dd HH:mm:ss") },
                            { "kind", r.GetString(1) },
                            { "level", r.IsDBNull(2) ? null : r.GetString(2) },
                            { "prev", r.IsDBNull(3) ? null : r.GetString(3) },
                            { "ok", r.IsDBNull(4) ? (bool?)null : Convert.ToInt32(r.GetValue(4), CultureInfo.InvariantCulture) == 1 },
                            { "note", r.IsDBNull(5) ? null : r.GetString(5) } });
            }
            return list;
        }

        /// <summary>จำนวนครั้งที่ส่ง LINE สำเร็จตั้งแต่ต้นเดือน</summary>
        public static int WaterLineCountMonth(string tank)
        {
            if (!Init()) return 0;
            try
            {
                using (DbConnection c = Open())
                {
                    EnsureWaterTable(c);
                    DateTime m = new DateTime(DateTime.Now.Year, DateTime.Now.Month, 1);
                    return Convert.ToInt32(Cmd(c, null, "SELECT COUNT(*) FROM water_event WHERE tank = @t AND kind = 'line' AND ok = 1 AND at >= @m",
                                               "@t", tank, "@m", m).ExecuteScalar(), CultureInfo.InvariantCulture);
                }
            }
            catch { return 0; }
        }

        // ------------------------------------------------------------ ยอดเข้าชมแต่ละหน้า (ป้ายมุมจอใน Site.Master)
        //   page_view_day : 1 แถว = 1 หน้า x 1 วัน (views = ครั้งที่เปิด, visitors = เครื่อง/IP ไม่ซ้ำในวันนั้น)
        //   page_visitor  : IP ที่เคยเปิดหน้านั้นในวันนั้น (ไว้นับ visitors ไม่ซ้ำ)
        //   กันนับซ้ำ : IP เดิม + หน้าเดิม ภายใน VIEW_REPEAT_MIN นาที นับครั้งเดียว (จอ TV ที่รีโหลดเองไม่ทำให้ยอดพอง)
        public const int VIEW_REPEAT_MIN = 10;
        static bool _viewTable;
        static DateTime _viewBackoff = DateTime.MinValue;
        static readonly Dictionary<string, DateTime> _lastView = new Dictionary<string, DateTime>(StringComparer.OrdinalIgnoreCase);

        public class ViewStat { public long Total, Today, TodayVisitors; public DateTime? Since; }

        static void EnsureViewTable(DbConnection c)
        {
            if (_viewTable) return;
            Cmd(c, null, @"CREATE TABLE IF NOT EXISTS page_view_day (
                              page      VARCHAR(80) NOT NULL,
                              view_day  DATE        NOT NULL,
                              views     INT UNSIGNED NOT NULL DEFAULT 0,
                              visitors  INT UNSIGNED NOT NULL DEFAULT 0,
                              PRIMARY KEY (page, view_day)
                           ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
            Cmd(c, null, @"CREATE TABLE IF NOT EXISTS page_visitor (
                              page      VARCHAR(80) NOT NULL,
                              view_day  DATE        NOT NULL,
                              ip        VARCHAR(45) NOT NULL,
                              first_at  DATETIME    NOT NULL,
                              PRIMARY KEY (page, view_day, ip)
                           ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
            _viewTable = true;
        }

        /// <summary>นับการเปิดหน้า 1 ครั้ง แล้วคืนยอดรวม / วันนี้ · DB ล่ม = คืน null (หน้าเว็บยังเปิดได้ปกติ)</summary>
        public static ViewStat TrackView(string page, string ip)
        {
            if (string.IsNullOrEmpty(page)) return null;
            if (page.Length > 80) page = page.Substring(0, 80);
            ip = string.IsNullOrEmpty(ip) ? "?" : (ip.Length > 45 ? ip.Substring(0, 45) : ip);
            DateTime now = DateTime.Now;
            if (now < _viewBackoff || !Init()) return null;

            bool count;
            lock (_lastView)
            {
                string k = page + "|" + ip;
                DateTime last;
                count = !_lastView.TryGetValue(k, out last) || (now - last).TotalMinutes >= VIEW_REPEAT_MIN;
                if (count) _lastView[k] = now;
                if (_lastView.Count > 20000) _lastView.Clear();
            }
            try
            {
                using (DbConnection c = Open())
                {
                    EnsureViewTable(c);
                    DateTime day = now.Date;
                    if (count)
                    {
                        int isNew = Cmd(c, null, "INSERT IGNORE INTO page_visitor (page, view_day, ip, first_at) VALUES (@p, @d, @ip, @t)",
                                        "@p", page, "@d", day, "@ip", ip, "@t", now).ExecuteNonQuery() > 0 ? 1 : 0;
                        Cmd(c, null, @"INSERT INTO page_view_day (page, view_day, views, visitors) VALUES (@p, @d, 1, @n)
                                       ON DUPLICATE KEY UPDATE views = views + 1, visitors = visitors + @n",
                            "@p", page, "@d", day, "@n", isNew).ExecuteNonQuery();
                    }
                    var st = new ViewStat();
                    using (DbDataReader rd = Cmd(c, null, @"SELECT COALESCE(SUM(views), 0), MIN(view_day),
                                                                  COALESCE(SUM(CASE WHEN view_day = @d THEN views END), 0),
                                                                  COALESCE(SUM(CASE WHEN view_day = @d THEN visitors END), 0)
                                                             FROM page_view_day WHERE page = @p", "@p", page, "@d", day).ExecuteReader())
                        if (rd.Read())
                        {
                            st.Total = Convert.ToInt64(rd.GetValue(0), CultureInfo.InvariantCulture);
                            st.Since = rd.IsDBNull(1) ? (DateTime?)null : Convert.ToDateTime(rd.GetValue(1), CultureInfo.InvariantCulture);
                            st.Today = Convert.ToInt64(rd.GetValue(2), CultureInfo.InvariantCulture);
                            st.TodayVisitors = Convert.ToInt64(rd.GetValue(3), CultureInfo.InvariantCulture);
                        }
                    return st;
                }
            }
            catch (Exception ex)
            {
                LastError = "page view: " + ex.Message;
                _viewBackoff = now.AddMinutes(1);      // DB มีปัญหา -> พัก 1 นาที ไม่ให้ทุกหน้าช้า
                return null;
            }
        }

        // ------------------------------------------------------------ queue
        public static void QueueStatus(string machine, string prodDay, int? status, string category, DateTime time, long? counter, string op)
        {
            DateTime pd;
            if (!DateTime.TryParseExact(prodDay, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out pd)) pd = time.Date;
            lock (EvSync)
            {
                if (_events.Count >= MAX_PENDING_EVENTS) _events.RemoveAt(0);
                _events.Add(new StatusEvent { Machine = machine, ProdDay = pd, Status = status, Category = category, Time = time, Counter = counter, Operator = op });
            }
        }

        // ------------------------------------------------------------ write (ทุก 1 นาที)
        public static void Flush()
        {
            if (!Enabled || Interlocked.Exchange(ref _busy, 1) == 1) return;
            List<StatusEvent> events;
            lock (EvSync) { events = _events; _events = new List<StatusEvent>(); }
            try
            {
                List<Row> rows;
                DateTime now = DateTime.Now;
                using (DbConnection c = Open())
                {
                    CheckSchema(c);
                    ReadStdCycle(c);
                }
                rows = CounterStore.ExportForDb();       // export ใหม่หลังได้ Std CT จาก DB
                using (DbConnection c = Open())
                using (DbTransaction tx = c.BeginTransaction())
                {
                    // เครื่องที่ยังไม่มีในตาราง machine -> เพิ่มให้อัตโนมัติ
                    var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                    foreach (Row r in rows) EnsureMachine(c, tx, r.Machine, r.Process, seen);
                    foreach (StatusEvent e in events) EnsureMachine(c, tx, e.Machine, null, seen);

                    // ประวัติสถานะ : ปิดรายการเดิม แล้วเปิดรายการใหม่
                    foreach (StatusEvent e in events)
                    {
                        Cmd(c, tx, @"UPDATE mc_status_log
                                       SET end_time = @t, duration_sec = GREATEST(0, TIMESTAMPDIFF(SECOND, start_time, @t)), counter_end = @cnt
                                     WHERE machine_code = @m AND end_time IS NULL",
                            "@t", e.Time, "@cnt", e.Counter, "@m", e.Machine).ExecuteNonQuery();
                        Cmd(c, tx, @"INSERT INTO mc_status_log (machine_code, prod_day, status_code, category, start_time, counter_start, operator)
                                     VALUES (@m, @pd, @st, @cat, @t, @cnt, @op)",
                            "@m", e.Machine, "@pd", e.ProdDay, "@st", e.Status, "@cat", e.Category, "@t", e.Time,
                            "@cnt", e.Counter, "@op", e.Operator).ExecuteNonQuery();
                    }

                    foreach (Row r in rows)
                    {
                        if (_hasOeeCols == true)
                            Cmd(c, tx, @"INSERT INTO mc_daily (prod_day, machine_code, count_start, operating_sec, loss_sec, offline_sec,
                                         shots_today, pieces_today, last_counter, last_cycle_sec, last_status, last_operator, availability,
                                         performance, quality, oee, ok_today, ng_today, std_cycle_sec)
                                     VALUES (@pd, @m, @cs, @op, @loss, @off, @shots, @pcs, @cnt, @cyc, @st, @opr, @av, @pf, @q, @oee, @ok, @ng, @std)
                                     ON DUPLICATE KEY UPDATE count_start = VALUES(count_start), operating_sec = VALUES(operating_sec),
                                         loss_sec = VALUES(loss_sec), offline_sec = VALUES(offline_sec), shots_today = VALUES(shots_today),
                                         pieces_today = VALUES(pieces_today), last_counter = VALUES(last_counter), last_cycle_sec = VALUES(last_cycle_sec),
                                         last_status = VALUES(last_status), last_operator = VALUES(last_operator), availability = VALUES(availability),
                                         performance = VALUES(performance), quality = VALUES(quality), oee = VALUES(oee),
                                         ok_today = VALUES(ok_today), ng_today = VALUES(ng_today), std_cycle_sec = VALUES(std_cycle_sec)",
                                "@pd", r.ProdDay, "@m", r.Machine, "@cs", r.CountStart, "@op", (long)r.OperatingSec, "@loss", (long)r.LossSec,
                                "@off", (long)r.OfflineSec, "@shots", r.ShotsToday, "@pcs", r.PiecesToday, "@cnt", r.Counter, "@cyc", r.Cycle,
                                "@st", r.Status, "@opr", r.Operator, "@av", r.Availability, "@pf", r.Performance, "@q", r.Quality,
                                "@oee", r.Oee, "@ok", r.OkToday, "@ng", r.NgToday, "@std", r.StdCt).ExecuteNonQuery();
                        else
                            Cmd(c, tx, @"INSERT INTO mc_daily (prod_day, machine_code, count_start, operating_sec, loss_sec, offline_sec,
                                         shots_today, pieces_today, last_counter, last_cycle_sec, last_status, last_operator, availability)
                                     VALUES (@pd, @m, @cs, @op, @loss, @off, @shots, @pcs, @cnt, @cyc, @st, @opr, @av)
                                     ON DUPLICATE KEY UPDATE count_start = VALUES(count_start), operating_sec = VALUES(operating_sec),
                                         loss_sec = VALUES(loss_sec), offline_sec = VALUES(offline_sec), shots_today = VALUES(shots_today),
                                         pieces_today = VALUES(pieces_today), last_counter = VALUES(last_counter), last_cycle_sec = VALUES(last_cycle_sec),
                                         last_status = VALUES(last_status), last_operator = VALUES(last_operator), availability = VALUES(availability)",
                                "@pd", r.ProdDay, "@m", r.Machine, "@cs", r.CountStart, "@op", (long)r.OperatingSec, "@loss", (long)r.LossSec,
                                "@off", (long)r.OfflineSec, "@shots", r.ShotsToday, "@pcs", r.PiecesToday, "@cnt", r.Counter, "@cyc", r.Cycle,
                                "@st", r.Status, "@opr", r.Operator, "@av", r.Availability).ExecuteNonQuery();

                        foreach (HourRow h in r.Hours)
                            Cmd(c, tx, @"INSERT INTO mc_hourly (machine_code, hour_start, prod_day, shots, operating_sec, loss_sec, offline_sec)
                                         VALUES (@m, @hs, @pd, @shots, @op, @loss, @off)
                                         ON DUPLICATE KEY UPDATE shots = VALUES(shots), operating_sec = VALUES(operating_sec),
                                             loss_sec = VALUES(loss_sec), offline_sec = VALUES(offline_sec)",
                                "@m", r.Machine, "@hs", h.HourStart, "@pd", r.ProdDay, "@shots", h.Shots,
                                "@op", (long)h.Op, "@loss", (long)h.Loss, "@off", (long)h.Off).ExecuteNonQuery();

                        Cmd(c, tx, @"INSERT INTO mc_snapshot (ts, machine_code, online, status_code, category, counter, shots_today,
                                         target_shots, cycle_sec, operator, job_start, job_finish)
                                     VALUES (@ts, @m, @on, @st, @cat, @cnt, @shots, @tg, @cyc, @opr, @js, @jf)",
                            "@ts", now, "@m", r.Machine, "@on", r.Online ? 1 : 0, "@st", r.Online ? r.Status : null, "@cat", r.Category,
                            "@cnt", r.Counter, "@shots", r.ShotsToday, "@tg", r.TargetShots, "@cyc", r.Cycle, "@opr", r.Operator,
                            "@js", DbTime(r.JobStart), "@jf", DbTime(r.JobFinish)).ExecuteNonQuery();
                    }
                    tx.Commit();
                }
                LastWrite = DateTime.Now;
                LastError = null;
            }
            catch (Exception ex)
            {
                LastError = DateTime.Now.ToString("HH:mm:ss") + " " + ex.Message;
                lock (EvSync) { events.AddRange(_events); _events = events; }   // เขียนไม่สำเร็จ -> เก็บไว้ส่งรอบหน้า
            }
            finally
            {
                Interlocked.Exchange(ref _busy, 0);
            }
        }

        // ------------------------------------------------------------ ประวัติสถานะ (popup Downtime ของการ์ด)
        //   รายการของวันผลิตนั้นจาก mc_status_log (+ รายการที่ยังไม่ได้บันทึกในรอบ 1 นาทีล่าสุด)
        public static Dictionary<string, object> StatusLog(string machine, DateTime dayStart)
        {
            var res = new Dictionary<string, object>();
            var list = new List<object>();
            res["machine"] = machine;
            res["dayStart"] = dayStart.ToString("yyyy-MM-dd HH:mm:ss");
            res["now"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
            res["events"] = list;
            if (!Init()) { res["error"] = LastError ?? "DB ยังไม่ได้ตั้งค่า"; return res; }
            DateTime now = DateTime.Now, dayEnd = dayStart.AddDays(1);
            try
            {
                using (DbConnection c = Open())
                using (DbDataReader rd = Cmd(c, null, @"SELECT l.category, l.status_code, s.text, l.start_time, l.end_time,
                                                              l.counter_start, l.counter_end, l.operator, l.reason
                                                         FROM mc_status_log l
                                                         LEFT JOIN status_code s ON s.code = l.status_code
                                                        WHERE l.machine_code = @m
                                                          AND l.start_time < @to
                                                          AND (l.end_time IS NULL OR l.end_time > @from)
                                                        ORDER BY l.start_time
                                                        LIMIT 2000",
                                                     "@m", machine, "@from", dayStart, "@to", dayEnd).ExecuteReader())
                {
                    while (rd.Read())
                    {
                        DateTime st = Convert.ToDateTime(rd.GetValue(3));
                        DateTime? en = rd.IsDBNull(4) ? (DateTime?)null : Convert.ToDateTime(rd.GetValue(4));
                        DateTime s0 = st < dayStart ? dayStart : st;                 // ตัดให้อยู่ในวันผลิตนี้
                        DateTime e0 = en ?? (now < dayEnd ? now : dayEnd);
                        if (e0 > dayEnd) e0 = dayEnd;
                        list.Add(new Dictionary<string, object> {
                            { "cat", rd.GetString(0) },
                            { "code", rd.IsDBNull(1) ? (int?)null : Convert.ToInt32(rd.GetValue(1)) },
                            { "text", rd.IsDBNull(2) ? null : rd.GetString(2) },
                            { "start", s0.ToString("yyyy-MM-dd HH:mm:ss") },
                            { "end", en.HasValue ? e0.ToString("yyyy-MM-dd HH:mm:ss") : null },
                            { "sec", Math.Max(0, (long)(e0 - s0).TotalSeconds) },
                            { "cntStart", rd.IsDBNull(5) ? (long?)null : Convert.ToInt64(rd.GetValue(5)) },
                            { "cntEnd", rd.IsDBNull(6) ? (long?)null : Convert.ToInt64(rd.GetValue(6)) },
                            { "operator", rd.IsDBNull(7) ? null : rd.GetString(7) },
                            { "reason", rd.IsDBNull(8) ? null : rd.GetString(8) } });
                    }
                }
                // รายการที่ยังรอบันทึก (ไม่เกิน 1 นาที) -> ต่อท้ายให้เห็นทันที
                lock (EvSync)
                    foreach (StatusEvent e in _events)
                    {
                        if (!string.Equals(e.Machine, machine, StringComparison.OrdinalIgnoreCase) || e.Time < dayStart || e.Time >= dayEnd) continue;
                        if (list.Count > 0)
                        {
                            var last = (Dictionary<string, object>)list[list.Count - 1];
                            if (last["end"] == null)
                            {
                                DateTime ls = DateTime.ParseExact((string)last["start"], "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture);
                                last["end"] = e.Time.ToString("yyyy-MM-dd HH:mm:ss");
                                last["sec"] = Math.Max(0, (long)(e.Time - ls).TotalSeconds);
                                last["cntEnd"] = e.Counter;
                            }
                        }
                        list.Add(new Dictionary<string, object> {
                            { "cat", e.Category }, { "code", e.Status }, { "text", null },
                            { "start", e.Time.ToString("yyyy-MM-dd HH:mm:ss") }, { "end", null },
                            { "sec", Math.Max(0, (long)(now - e.Time).TotalSeconds) },
                            { "cntStart", e.Counter }, { "cntEnd", null }, { "operator", e.Operator }, { "reason", null } });
                    }
            }
            catch (Exception ex)
            {
                res["error"] = ex.Message;
            }
            return res;
        }

        // ตรวจครั้งแรกว่ารัน OEE_add_oee_columns.sql แล้วหรือยัง (ยังไม่รัน -> บันทึกแบบเดิมไปก่อน)
        static void CheckSchema(DbConnection c)
        {
            if (_hasOeeCols == true) return;
            object n = Cmd(c, null, @"SELECT COUNT(*) FROM information_schema.COLUMNS
                                       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'mc_daily' AND COLUMN_NAME = 'oee'").ExecuteScalar();
            _hasOeeCols = Convert.ToInt32(n) > 0;
        }

        // Std CT ของแต่ละเครื่องจากตาราง machine.std_cycle_sec (แก้ใน phpMyAdmin ได้ มีผลภายใน 1 นาที)
        static void ReadStdCycle(DbConnection c)
        {
            var std = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
            var cav = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            using (DbDataReader rd = Cmd(c, null, "SELECT machine_code, std_cycle_sec, cavities FROM machine").ExecuteReader())
                while (rd.Read())
                {
                    if (!rd.IsDBNull(1)) std[rd.GetString(0)] = Convert.ToDouble(rd.GetValue(1));
                    if (!rd.IsDBNull(2)) cav[rd.GetString(0)] = Convert.ToInt32(rd.GetValue(2));
                }
            CounterStore.ApplyMachineCfg(std, cav);
        }

        static void EnsureMachine(DbConnection c, DbTransaction tx, string code, string process, HashSet<string> seen)
        {
            if (string.IsNullOrEmpty(code) || !seen.Add(code)) return;
            Cmd(c, tx, "INSERT IGNORE INTO machine (machine_code, machine_no, process) VALUES (@m, @m, @p)",
                "@m", code, "@p", string.IsNullOrEmpty(process) ? "Injection" : process).ExecuteNonQuery();
        }

        // ------------------------------------------------------------ น้ำหนักจากเครื่องชั่ง (หน้า WeightLog.aspx)
        //   ตาราง weight_log : 1 แถว = ชั่ง 1 ครั้ง (Node-RED ส่งมาเฉพาะตอนน้ำหนัก > 0 และนิ่งแล้ว)
        static bool _weightTable;
        static readonly Dictionary<string, KeyValuePair<DateTime, double>> _lastWeight = new Dictionary<string, KeyValuePair<DateTime, double>>(StringComparer.OrdinalIgnoreCase);

        static void EnsureWeightTable(DbConnection c)
        {
            if (_weightTable) return;
            Cmd(c, null, @"CREATE TABLE IF NOT EXISTS weight_log (
                              id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                              machine_code VARCHAR(40)   NOT NULL,
                              weigh_time   DATETIME      NOT NULL,
                              prod_day     DATE          NOT NULL COMMENT 'วันผลิต 08:00-08:00',
                              weight       DECIMAL(12,4) NOT NULL,
                              unit         VARCHAR(8)    NULL,
                              stable       TINYINT(1)    NULL,
                              raw_text     VARCHAR(80)   NULL,
                              model        VARCHAR(40)   NULL COMMENT 'รุ่น (จาก PRODUCTION NAME)',
                              barcode      VARCHAR(20)   NULL COMMENT 'บาร์โค้ดรุ่นที่ยิง เช่น S-Soft',
                              spec_min     DECIMAL(10,3) NULL,
                              spec_max     DECIMAL(10,3) NULL,
                              result       VARCHAR(4)    NULL COMMENT 'OK / NG',
                              PRIMARY KEY (id),
                              KEY ix_mc_day (machine_code, prod_day),
                              KEY ix_mc_time (machine_code, weigh_time)
                           ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
            // ตารางเดิม (สร้างก่อนมีรุ่น) -> เพิ่มคอลัมน์ที่ยังไม่มี
            var have = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            using (DbDataReader rd = Cmd(c, null, "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'weight_log'").ExecuteReader())
                while (rd.Read()) have.Add(rd.GetString(0));
            string[,] add = { { "model", "VARCHAR(40) NULL" }, { "spec_min", "DECIMAL(10,3) NULL" }, { "spec_max", "DECIMAL(10,3) NULL" }, { "result", "VARCHAR(4) NULL" }, { "barcode", "VARCHAR(20) NULL" } };
            for (int i = 0; i < add.GetLength(0); i++)
                if (!have.Contains(add[i, 0])) Cmd(c, null, "ALTER TABLE weight_log ADD COLUMN " + add[i, 0] + " " + add[i, 1]).ExecuteNonQuery();
            _weightTable = true;
        }

        /// <summary>บันทึกน้ำหนัก 1 ครั้ง · คืน "dup" ถ้าค่าเดิมซ้ำภายใน 3 วินาที (กันส่งซ้ำ)</summary>
        public static string InsertWeight(string machine, double weight, string unit, bool? stable, string raw, out long id)
        {
            return InsertWeight(machine, weight, unit, stable, raw, null, null, null, null, out id);
        }

        public static string InsertWeight(string machine, double weight, string unit, bool? stable, string raw,
                                          string model, double? specMin, double? specMax, string result, out long id)
        {
            return InsertWeight(machine, weight, unit, stable, raw, model, null, specMin, specMax, result, out id);
        }

        public static string InsertWeight(string machine, double weight, string unit, bool? stable, string raw,
                                          string model, string barcode, double? specMin, double? specMax, string result, out long id)
        {
            id = 0;
            if (!Init()) return LastError ?? "DB ยังไม่ได้ตั้งค่า";
            DateTime now = DateTime.Now;
            lock (_lastWeight)
            {
                KeyValuePair<DateTime, double> last;
                if (_lastWeight.TryGetValue(machine, out last) && Math.Abs(last.Value - weight) < 1e-9 && (now - last.Key).TotalSeconds < 3) return "dup";
                _lastWeight[machine] = new KeyValuePair<DateTime, double>(now, weight);
            }
            try
            {
                using (DbConnection c = Open())
                {
                    EnsureWeightTable(c);
                    Cmd(c, null, @"INSERT INTO weight_log (machine_code, weigh_time, prod_day, weight, unit, stable, raw_text, model, barcode, spec_min, spec_max, result)
                                   VALUES (@m, @t, @d, @w, @u, @s, @r, @mo, @bc, @mn, @mx, @rs)",
                        "@m", machine, "@t", now, "@d", CounterStore.ProdDayStart(now).Date, "@w", weight,
                        "@u", unit, "@s", stable.HasValue ? (object)(stable.Value ? 1 : 0) : null,
                        "@r", raw != null && raw.Length > 80 ? raw.Substring(0, 80) : raw,
                        "@mo", string.IsNullOrEmpty(model) ? null : (model.Length > 40 ? model.Substring(0, 40) : model),
                        "@bc", string.IsNullOrEmpty(barcode) ? null : (barcode.Length > 20 ? barcode.Substring(0, 20) : barcode),
                        "@mn", specMin, "@mx", specMax, "@rs", string.IsNullOrEmpty(result) ? null : result).ExecuteNonQuery();
                    object o = Cmd(c, null, "SELECT LAST_INSERT_ID()").ExecuteScalar();
                    id = Convert.ToInt64(o, CultureInfo.InvariantCulture);
                }
                return null;
            }
            catch (Exception ex) { return ex.Message; }
        }

        /// <summary>รายงานน้ำหนักของวันผลิต (08:00 → 08:00) + รายชื่อเครื่องที่เคยส่ง</summary>
        public static Dictionary<string, object> WeightReport(string machine, DateTime dayStart)
        {
            var res = new Dictionary<string, object>();
            var rows = new List<object>();
            var machines = new List<string>();
            res["dayStart"] = dayStart.ToString("yyyy-MM-dd HH:mm");
            res["dayEnd"] = dayStart.AddDays(1).ToString("yyyy-MM-dd HH:mm");
            res["now"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
            res["machines"] = machines;
            res["rows"] = rows;
            if (!Init()) { res["error"] = LastError ?? "DB ยังไม่ได้ตั้งค่า"; return res; }
            try
            {
                using (DbConnection c = Open())
                {
                    EnsureWeightTable(c);
                    using (DbDataReader rd = Cmd(c, null, "SELECT DISTINCT machine_code FROM weight_log WHERE weigh_time >= @f ORDER BY machine_code",
                                                 "@f", DateTime.Now.AddDays(-60)).ExecuteReader())
                        while (rd.Read()) machines.Add(rd.GetString(0));
                    if (string.IsNullOrEmpty(machine) && machines.Count > 0) machine = machines[0];
                    res["machine"] = machine;
                    if (!string.IsNullOrEmpty(machine))
                        using (DbDataReader rd = Cmd(c, null, @"SELECT id, weigh_time, weight, unit, stable, model, spec_min, spec_max, result, barcode FROM weight_log
                                                                WHERE machine_code = @m AND weigh_time >= @f AND weigh_time < @t
                                                                ORDER BY weigh_time LIMIT 20000",
                                                     "@m", machine, "@f", dayStart, "@t", dayStart.AddDays(1)).ExecuteReader())
                            while (rd.Read())
                                rows.Add(new Dictionary<string, object> {
                                    { "id", Convert.ToInt64(rd.GetValue(0), CultureInfo.InvariantCulture) },
                                    { "t", rd.GetDateTime(1).ToString("yyyy-MM-dd HH:mm:ss") },
                                    { "w", Convert.ToDouble(rd.GetValue(2), CultureInfo.InvariantCulture) },
                                    { "u", rd.IsDBNull(3) ? "" : rd.GetString(3) },
                                    { "s", rd.IsDBNull(4) ? (object)null : Convert.ToInt32(rd.GetValue(4), CultureInfo.InvariantCulture) == 1 },
                                    { "m", rd.IsDBNull(5) ? "" : rd.GetString(5) },
                                    { "mn", rd.IsDBNull(6) ? (object)null : Convert.ToDouble(rd.GetValue(6), CultureInfo.InvariantCulture) },
                                    { "mx", rd.IsDBNull(7) ? (object)null : Convert.ToDouble(rd.GetValue(7), CultureInfo.InvariantCulture) },
                                    { "r", rd.IsDBNull(8) ? "" : rd.GetString(8) },
                                    { "b", rd.IsDBNull(9) ? "" : rd.GetString(9) } });
                }
            }
            catch (Exception ex) { res["error"] = ex.Message; }
            return res;
        }

        // ------------------------------------------------------------ ย้อนหลังหลายวัน (หน้า OEE Dashboard)
        //   รวม mc_daily ต่อเครื่อง ช่วงวันผลิต from..to (รวมทั้งสองวัน) -> ใช้ A / P / ยอด Shot ชุดเดียวกับ MC Monitor
        public class DayAgg
        {
            public string Machine, MachineNo, Process;
            public int Days, Cavities;
            public double OperatingSec, LossSec, OfflineSec, StdShotSec;   // StdShotSec = Σ(shots x Std CT)
            public long Shots, Pieces;
            public double? StdCt;
        }
        public static List<DayAgg> DailyRange(DateTime fromDay, DateTime toDay, out string error)
        {
            error = null;
            var list = new List<DayAgg>();
            if (!Init()) { error = LastError ?? "DB not configured"; return list; }
            try
            {
                using (DbConnection c = Open())
                {
                    CheckSchema(c);
                    string stdExpr = _hasOeeCols == true ? "COALESCE(d.std_cycle_sec, m.std_cycle_sec)" : "m.std_cycle_sec";
                    using (DbDataReader rd = Cmd(c, null, @"
                        SELECT d.machine_code, MAX(m.machine_no), MAX(m.process), MAX(m.cavities), COUNT(*),
                               SUM(d.operating_sec), SUM(d.loss_sec), SUM(d.offline_sec),
                               SUM(d.shots_today), SUM(d.pieces_today),
                               SUM(d.shots_today * IFNULL(" + stdExpr + @", 0)),
                               MAX(m.std_cycle_sec)
                          FROM mc_daily d LEFT JOIN machine m ON m.machine_code = d.machine_code
                         WHERE d.prod_day BETWEEN @f AND @t
                         GROUP BY d.machine_code", "@f", fromDay.Date, "@t", toDay.Date).ExecuteReader())
                        while (rd.Read())
                        {
                            var a = new DayAgg();
                            a.Machine = rd.GetString(0);
                            a.MachineNo = rd.IsDBNull(1) ? a.Machine : rd.GetString(1);
                            a.Process = rd.IsDBNull(2) ? "Injection" : rd.GetString(2);
                            a.Cavities = rd.IsDBNull(3) ? 1 : Math.Max(1, Convert.ToInt32(rd.GetValue(3)));
                            a.Days = Convert.ToInt32(rd.GetValue(4));
                            a.OperatingSec = Convert.ToDouble(rd.GetValue(5));
                            a.LossSec = Convert.ToDouble(rd.GetValue(6));
                            a.OfflineSec = Convert.ToDouble(rd.GetValue(7));
                            a.Shots = Convert.ToInt64(rd.GetValue(8));
                            a.Pieces = Convert.ToInt64(rd.GetValue(9));
                            a.StdShotSec = Convert.ToDouble(rd.GetValue(10));
                            a.StdCt = rd.IsDBNull(11) ? (double?)null : Convert.ToDouble(rd.GetValue(11));
                            list.Add(a);
                        }
                }
            }
            catch (Exception ex) { error = ex.Message; }
            return list;
        }

        // ------------------------------------------------------------ รายวัน เครื่องเดียว (แท็บ OEE ใน popup เครื่อง)
        public class MachineDay
        {
            public DateTime Day; public int Cavities;
            public double OperatingSec, LossSec, OfflineSec, StdShotSec; public long Shots, Pieces; public double? StdCt;
            public string MachineNo, Process;
        }
        public static List<MachineDay> MachineDays(string machine, DateTime fromDay, DateTime toDay, out string error)
        {
            error = null;
            var list = new List<MachineDay>();
            if (!Init()) { error = LastError ?? "DB not configured"; return list; }
            try
            {
                using (DbConnection c = Open())
                {
                    CheckSchema(c);
                    string stdExpr = _hasOeeCols == true ? "COALESCE(d.std_cycle_sec, m.std_cycle_sec)" : "m.std_cycle_sec";
                    using (DbDataReader rd = Cmd(c, null, @"
                        SELECT d.prod_day, m.machine_no, m.process, m.cavities,
                               d.operating_sec, d.loss_sec, d.offline_sec, d.shots_today, d.pieces_today,
                               d.shots_today * IFNULL(" + stdExpr + @", 0), " + stdExpr + @"
                          FROM mc_daily d LEFT JOIN machine m ON m.machine_code = d.machine_code
                         WHERE d.machine_code = @m AND d.prod_day BETWEEN @f AND @t
                         ORDER BY d.prod_day", "@m", machine, "@f", fromDay.Date, "@t", toDay.Date).ExecuteReader())
                        while (rd.Read())
                        {
                            var a = new MachineDay();
                            a.Day = Convert.ToDateTime(rd.GetValue(0)).Date;
                            a.MachineNo = rd.IsDBNull(1) ? machine : rd.GetString(1);
                            a.Process = rd.IsDBNull(2) ? "Injection" : rd.GetString(2);
                            a.Cavities = rd.IsDBNull(3) ? 1 : Math.Max(1, Convert.ToInt32(rd.GetValue(3)));
                            a.OperatingSec = rd.IsDBNull(4) ? 0 : Convert.ToDouble(rd.GetValue(4));
                            a.LossSec = rd.IsDBNull(5) ? 0 : Convert.ToDouble(rd.GetValue(5));
                            a.OfflineSec = rd.IsDBNull(6) ? 0 : Convert.ToDouble(rd.GetValue(6));
                            a.Shots = rd.IsDBNull(7) ? 0 : Convert.ToInt64(rd.GetValue(7));
                            a.Pieces = rd.IsDBNull(8) ? 0 : Convert.ToInt64(rd.GetValue(8));
                            a.StdShotSec = rd.IsDBNull(9) ? 0 : Convert.ToDouble(rd.GetValue(9));
                            a.StdCt = rd.IsDBNull(10) ? (double?)null : Convert.ToDouble(rd.GetValue(10));
                            list.Add(a);
                        }
                }
            }
            catch (Exception ex) { error = ex.Message; }
            return list;
        }

        // ------------------------------------------------------------ load (ตอนแอปเริ่ม)
        public static void LoadToday(Dictionary<string, MachineState> machines, DateTime dayStart)
        {
            if (!Init()) return;
            try
            {
                string dayKey = dayStart.ToString("yyyy-MM-dd");
                using (DbConnection c = Open())
                {
                    using (DbDataReader rd = Cmd(c, null, @"SELECT d.machine_code, d.count_start, d.operating_sec, d.loss_sec, d.offline_sec,
                                                                  d.shots_today, d.last_counter, d.updated_at, m.process
                                                             FROM mc_daily d LEFT JOIN machine m ON m.machine_code = d.machine_code
                                                            WHERE d.prod_day = @pd", "@pd", dayStart.Date).ExecuteReader())
                    {
                        while (rd.Read())
                        {
                            var m = new MachineState();
                            m.Machine = rd.GetString(0);
                            m.ProdDay = dayKey;
                            m.CountStart = Convert.ToDateTime(rd.GetValue(1));
                            m.OperatingSec = Convert.ToDouble(rd.GetValue(2));
                            m.LossSec = Convert.ToDouble(rd.GetValue(3));
                            m.OfflineSec = Convert.ToDouble(rd.GetValue(4));
                            m.ShotsToday = Convert.ToInt64(rd.GetValue(5));
                            if (!rd.IsDBNull(6)) m.LastShot = Convert.ToInt64(rd.GetValue(6));   // นับ Shot ต่อจากค่าเดิม
                            m.ShotCount = m.LastShot;
                            m.LastUpdate = Convert.ToDateTime(rd.GetValue(7));
                            if (!rd.IsDBNull(8) && rd.GetString(8) != "Injection") m.Process = rd.GetString(8);
                            m.StatusText = "No data";
                            m.Mode = "offline";
                            machines[m.Machine] = m;
                        }
                    }
                    CheckSchema(c);
                    if (_hasOeeCols == true)
                        using (DbDataReader rd = Cmd(c, null, "SELECT machine_code, ok_today, ng_today FROM mc_daily WHERE prod_day = @pd", "@pd", dayStart.Date).ExecuteReader())
                            while (rd.Read())
                            {
                                MachineState m;
                                if (!machines.TryGetValue(rd.GetString(0), out m)) continue;
                                if (!rd.IsDBNull(1)) m.OkToday = Convert.ToInt64(rd.GetValue(1));
                                if (!rd.IsDBNull(2)) m.NgToday = Convert.ToInt64(rd.GetValue(2));
                            }
                    using (DbDataReader rd = Cmd(c, null, "SELECT machine_code, std_cycle_sec FROM machine WHERE std_cycle_sec IS NOT NULL").ExecuteReader())
                        while (rd.Read())
                        {
                            MachineState m;
                            if (machines.TryGetValue(rd.GetString(0), out m)) m.IdealCtDb = Convert.ToDouble(rd.GetValue(1));
                        }
                    using (DbDataReader rd = Cmd(c, null, @"SELECT machine_code, hour_start, shots, operating_sec, loss_sec, offline_sec
                                                             FROM mc_hourly WHERE prod_day = @pd", "@pd", dayStart.Date).ExecuteReader())
                    {
                        while (rd.Read())
                        {
                            MachineState m;
                            if (!machines.TryGetValue(rd.GetString(0), out m)) continue;
                            int h = (int)Math.Floor((Convert.ToDateTime(rd.GetValue(1)) - dayStart).TotalHours);
                            if (h < 0 || h > 23) continue;
                            m.Hourly[h] = Convert.ToInt64(rd.GetValue(2));
                            m.HourOp[h] = Convert.ToDouble(rd.GetValue(3));
                            m.HourLoss[h] = Convert.ToDouble(rd.GetValue(4));
                            m.HourOff[h] = Convert.ToDouble(rd.GetValue(5));
                        }
                    }
                }
                LastError = null;
            }
            catch (Exception ex)
            {
                LastError = "โหลดข้อมูลเดิมไม่ได้: " + ex.Message;
            }
        }
    }

    // =====================================================================
    // ErpQuality : ดึงยอด OUT / NG ของวันผลิตนี้ (ตั้งแต่ 08:00) แยกตาม Process จาก ERP (EMES_UNIVERSAL)
    //   ตาราง SFT_OP_REALRUN + OPERATION.NAME (Injection, Seambuffing, Coating ...) ทุก 5 นาที
    //   Q = OUTQTY / (OUTQTY + DEFECTQTY)   (ERP ไม่มีรหัสเครื่อง -> ทุกเครื่องใน Process เดียวกันได้ Q เท่ากัน)
    // =====================================================================
    public static class ErpQuality
    {
        public const string CONN_NAME = "EMESConnectionString";
        public const int REFRESH_SEC = 300;

        class Item { public double Out, Ng; }
        static Dictionary<string, Item> _data = new Dictionary<string, Item>(StringComparer.OrdinalIgnoreCase);
        static Dictionary<string, Item> _mc = new Dictionary<string, Item>(StringComparer.OrdinalIgnoreCase);   // key = EQID ตัด "1." ออก เช่น UB-MC-PV-1-1

        // รหัสที่ Node-RED ส่งมา -> รหัสเครื่องใน ERP (EQID ไม่รวมเลขนำหน้า)
        static readonly Dictionary<string, string> EqidOf = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) {
            { "MC27", "UB-MC-PV-1-1" }, { "MC12", "UB-MC-PV-1-2" },
            { "MC13", "UB-MC-PV-1-3" }, { "MC14", "UB-MC-PV-1-4" }, { "MC15", "UB-MC-PV-1-5" },
            { "MC16", "UB-MC-PV-1-6" }, { "MC17", "UB-MC-PV-1-7" }, { "MC18", "UB-MC-PV-1-8" },
            { "MC21", "UB-MC-PV-2-1" }, { "MC22", "UB-MC-PV-2-2" }, { "MC23", "UB-MC-PV-2-3" },
            { "MC24", "UB-MC-PV-2-4" }, { "MC25", "UB-MC-PV-2-5" }, { "MC26", "UB-MC-PV-2-6" },
            { "MC7",  "UB-MC-PV-2-7" }, { "MC28", "UB-MC-PV-2-8" },
            // Seambuffing (ERP: 2.UB-MC-SF-00x) *** ตรวจให้ตรงกับเครื่องจริง ***
            { "SB04", "UB-MC-SF-004" },   // Seambuffing 4 (เดิมใช้รหัส SB01)
            { "SB02", "UB-MC-SF-002" },   // Seambuffing 2
            { "SB03", "UB-MC-SF-003" }    // Seambuffing 3
        };
        static string NormEqid(string e)
        {
            if (string.IsNullOrEmpty(e)) return "";
            e = e.Trim();
            int dot = e.IndexOf('.');
            if (dot > 0 && dot <= 3) e = e.Substring(dot + 1);   // "1.UB-MC-PV-1-1" -> "UB-MC-PV-1-1"
            return e;
        }

        // ---- รายละเอียดงานเสียรายเครื่อง (popup แท็บ NG) : ราย Lot + สาเหตุ ----
        public static Dictionary<string, object> NgDetail(string machine, DateTime dayStart)
        {
            var res = new Dictionary<string, object>();
            string eq;
            if (!EqidOf.TryGetValue(machine ?? "", out eq)) eq = NormEqid(machine);
            res["machine"] = machine; res["eqid"] = eq;
            var lots = new List<object>();
            var reasons = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
            double tOut = 0, tNg = 0;
            try
            {
                ConnectionStringSettings cs = ConfigurationManager.ConnectionStrings[CONN_NAME];
                if (cs == null) throw new Exception("ไม่พบ " + CONN_NAME);
                var map = new Dictionary<string, Dictionary<string, object>>();
                var order = new List<string>();
                using (var c = new SqlConnection(cs.ConnectionString))
                using (var cmd = c.CreateCommand())
                {
                    cmd.CommandTimeout = 30;
                    cmd.CommandText = @"
                        SELECT A.OUTTIME, A.ID, A.ERP_OPID, LTRIM(RTRIM(M.MO022)) AS Ball,
                               ISNULL(A.OUTQTY, 0) AS OutQty,
                               LTRIM(RTRIM(E.EXCEPTREASON)) AS Reason, ISNULL(E.EXCEPTQTY, 0) AS NgQty
                          FROM SFT_OP_REALRUN A
                          LEFT JOIN MODETAIL M ON M.CMOID = A.ID
                          LEFT JOIN SFT_OP_EXCEPT E ON E.ID = A.ID AND E.ERP_OPID = A.ERP_OPID AND E.EXCEPTTYPE = 'defect'
                         WHERE A.OUTTIME >= @From AND A.OUTTIME < @To
                           AND (LTRIM(RTRIM(A.EQID)) = @Eq OR LTRIM(RTRIM(A.EQID)) LIKE '%.' + @Eq)
                         ORDER BY A.OUTTIME DESC";
                    cmd.Parameters.AddWithValue("@From", dayStart);
                    cmd.Parameters.AddWithValue("@To", dayStart.AddDays(1));
                    cmd.Parameters.AddWithValue("@Eq", eq);
                    c.Open();
                    using (var rd = cmd.ExecuteReader())
                        while (rd.Read())
                        {
                            DateTime t = Convert.ToDateTime(rd.GetValue(0));
                            string id = rd.IsDBNull(1) ? "" : rd.GetValue(1).ToString().Trim();
                            string key = id + "|" + t.Ticks;
                            Dictionary<string, object> lot;
                            if (!map.TryGetValue(key, out lot))
                            {
                                double o = Convert.ToDouble(rd.GetValue(4));
                                lot = new Dictionary<string, object> {
                                    { "time", t.ToString("yyyy-MM-dd HH:mm:ss") }, { "lot", id },
                                    { "op", rd.IsDBNull(2) ? null : rd.GetValue(2).ToString() },
                                    { "ball", rd.IsDBNull(3) ? null : rd.GetString(3) },
                                    { "out", o }, { "ng", 0.0 }, { "reasons", new List<object>() } };
                                map[key] = lot; order.Add(key); tOut += o;
                            }
                            if (!rd.IsDBNull(5))
                            {
                                string r = rd.GetString(5); double q = Convert.ToDouble(rd.GetValue(6));
                                if (r.Length == 0 && q == 0) continue;
                                if (r.Length == 0) r = "(no reason)";
                                lot["ng"] = (double)lot["ng"] + q; tNg += q;
                                ((List<object>)lot["reasons"]).Add(new Dictionary<string, object> { { "reason", r }, { "qty", q } });
                                double v; reasons.TryGetValue(r, out v); reasons[r] = v + q;
                            }
                        }
                }
                foreach (string k in order) lots.Add(map[k]);
            }
            catch (Exception ex) { res["error"] = ex.Message; }
            var top = new List<object>();
            var rl = new List<KeyValuePair<string, double>>(reasons);
            rl.Sort((x, y) => y.Value.CompareTo(x.Value));
            foreach (var kv in rl) top.Add(new Dictionary<string, object> { { "reason", kv.Key }, { "qty", kv.Value } });
            res["out"] = tOut; res["ng"] = tNg;
            res["quality"] = (tOut + tNg) > 0 ? QPctUtil.Down(tOut * 100.0 / (tOut + tNg)) : (double?)null;
            res["lots"] = lots; res["reasons"] = top;
            return res;
        }

        // EQID ใน ERP (เช่น 1.UB-MC-PV-1-1) -> รหัสเครื่องที่ Node-RED ใช้ (เช่น MC27) ; ไม่พบ = null
        public static string MachineForEqid(string eqid)
        {
            string k = NormEqid(eqid);
            foreach (var kv in EqidOf)
                if (string.Equals(kv.Value, k, StringComparison.OrdinalIgnoreCase)) return kv.Key;
            return null;
        }

        public static string EqidFor(string machine)
        {
            string eq;
            return EqidOf.TryGetValue(machine ?? "", out eq) ? eq : NormEqid(machine);
        }

        // ยอดจาก ERP ต่อเครื่อง ช่วงเวลา from..to (ใช้หน้า OEE Dashboard) : key = EQID ตัดเลขนำหน้า
        public class ErpAgg { public string Eqid, Process; public double Out, Ng; public int Batches; }
        public static Dictionary<string, ErpAgg> RangeByMachine(DateTime from, DateTime to, out string error)
        {
            error = null;
            var res = new Dictionary<string, ErpAgg>(StringComparer.OrdinalIgnoreCase);
            try
            {
                ConnectionStringSettings cs = ConfigurationManager.ConnectionStrings[CONN_NAME];
                if (cs == null) throw new Exception("ไม่พบ " + CONN_NAME);
                using (var c = new SqlConnection(cs.ConnectionString))
                using (var cmd = c.CreateCommand())
                {
                    cmd.CommandTimeout = 60;
                    cmd.CommandText = @"
                        SELECT LTRIM(RTRIM(A.EQID)) AS EQID, MAX(O.NAME) AS ProcName, COUNT(DISTINCT A.ID) AS Batches,
                               SUM(ISNULL(A.OUTQTY, 0)) AS OutQty,
                               SUM(ISNULL(X.NgQty, 0)) AS NgQty
                          FROM SFT_OP_REALRUN A
                          LEFT JOIN OPERATION O ON O.ERP_OPID = A.ERP_OPID
                         OUTER APPLY (SELECT SUM(E.EXCEPTQTY) AS NgQty FROM SFT_OP_EXCEPT E
                                       WHERE E.ID = A.ID AND E.ERP_OPID = A.ERP_OPID AND E.EXCEPTTYPE = 'defect') X
                         WHERE A.OUTTIME >= @From AND A.OUTTIME < @To
                           AND ISNULL(A.EQID, '') <> ''
                         GROUP BY LTRIM(RTRIM(A.EQID))";
                    cmd.Parameters.AddWithValue("@From", from);
                    cmd.Parameters.AddWithValue("@To", to);
                    c.Open();
                    using (var rd = cmd.ExecuteReader())
                        while (rd.Read())
                        {
                            string raw = rd.GetString(0), key = NormEqid(raw);
                            ErpAgg a;
                            if (!res.TryGetValue(key, out a)) res[key] = a = new ErpAgg { Eqid = raw, Process = rd.IsDBNull(1) ? "" : Convert.ToString(rd.GetValue(1)).Trim() };
                            a.Batches += Convert.ToInt32(rd.GetValue(2));
                            a.Out += Convert.ToDouble(rd.GetValue(3));
                            a.Ng += Convert.ToDouble(rd.GetValue(4));
                        }
                }
            }
            catch (Exception ex) { error = ex.Message; }
            return res;
        }

        // ยอดจาก ERP รายวันผลิต ของเครื่องเดียว (แท็บ OEE ใน popup) : key = วันผลิต (เริ่ม DAY_START_HOUR)
        public static Dictionary<DateTime, ErpAgg> DailyForMachine(string machine, DateTime from, DateTime to, out string error)
        {
            error = null;
            var res = new Dictionary<DateTime, ErpAgg>();
            string eq = EqidFor(machine);
            if (string.IsNullOrEmpty(eq)) return res;
            try
            {
                ConnectionStringSettings cs = ConfigurationManager.ConnectionStrings[CONN_NAME];
                if (cs == null) throw new Exception("ไม่พบ " + CONN_NAME);
                using (var c = new SqlConnection(cs.ConnectionString))
                using (var cmd = c.CreateCommand())
                {
                    cmd.CommandTimeout = 60;
                    cmd.CommandText = @"
                        SELECT CAST(DATEADD(HOUR, -@H, A.OUTTIME) AS DATE) AS PDay, COUNT(DISTINCT A.ID) AS Batches,
                               SUM(ISNULL(A.OUTQTY, 0)) AS OutQty,
                               SUM(ISNULL(X.NgQty, 0)) AS NgQty
                          FROM SFT_OP_REALRUN A
                         OUTER APPLY (SELECT SUM(E.EXCEPTQTY) AS NgQty FROM SFT_OP_EXCEPT E
                                       WHERE E.ID = A.ID AND E.ERP_OPID = A.ERP_OPID AND E.EXCEPTTYPE = 'defect') X
                         WHERE A.OUTTIME >= @From AND A.OUTTIME < @To
                           AND (LTRIM(RTRIM(A.EQID)) = @Eq OR LTRIM(RTRIM(A.EQID)) LIKE '_.' + @Eq OR LTRIM(RTRIM(A.EQID)) LIKE '__.' + @Eq)
                         GROUP BY CAST(DATEADD(HOUR, -@H, A.OUTTIME) AS DATE)";
                    cmd.Parameters.AddWithValue("@From", from);
                    cmd.Parameters.AddWithValue("@To", to);
                    cmd.Parameters.AddWithValue("@Eq", eq);
                    cmd.Parameters.AddWithValue("@H", CounterStore.DAY_START_HOUR);
                    c.Open();
                    using (var rd = cmd.ExecuteReader())
                        while (rd.Read())
                            res[Convert.ToDateTime(rd.GetValue(0)).Date] = new ErpAgg {
                                Eqid = eq, Batches = Convert.ToInt32(rd.GetValue(1)),
                                Out = Convert.ToDouble(rd.GetValue(2)), Ng = Convert.ToDouble(rd.GetValue(3)) };
                }
            }
            catch (Exception ex) { error = ex.Message; }
            return res;
        }

        // ยอด OUT / NG ของวันนี้รายเครื่องจาก ERP (ใช้แสดงในการ์ด)
        public static bool CountsForMachine(string machine, out double outQty, out double ngQty)
        {
            outQty = 0; ngQty = 0;
            if (string.IsNullOrEmpty(machine)) return false;
            string key;
            if (!EqidOf.TryGetValue(machine, out key)) key = NormEqid(machine);
            lock (Sync)
            {
                Item it;
                if (!_mc.TryGetValue(key, out it)) return false;
                outQty = it.Out; ngQty = it.Ng;
                return true;
            }
        }

        public static double? ForMachine(string machine)
        {
            if (string.IsNullOrEmpty(machine)) return null;
            string key;
            if (!EqidOf.TryGetValue(machine, out key)) key = NormEqid(machine);
            lock (Sync)
            {
                Item it;
                if (!_mc.TryGetValue(key, out it)) return null;
                double total = it.Out + it.Ng;
                return total > 0 ? it.Out * 100.0 / total : (double?)null;
            }
        }
        static readonly object Sync = new object();
        static Timer _timer;
        static int _busy;
        public static DateTime? LastRead { get; private set; }
        public static string LastError { get; private set; }

        public static void Start()
        {
            if (_timer != null) return;
            _timer = new Timer(delegate { Refresh(); }, null, 5000, REFRESH_SEC * 1000);
        }

        public static double? ForProcess(string process)
        {
            if (string.IsNullOrEmpty(process)) return null;
            lock (Sync)
            {
                Item it;
                if (!_data.TryGetValue(process.Trim(), out it)) return null;
                double total = it.Out + it.Ng;
                return total > 0 ? it.Out * 100.0 / total : (double?)null;
            }
        }

        public static Dictionary<string, object> Info()
        {
            var procs = new Dictionary<string, object>();
            lock (Sync)
                foreach (var kv in _data)
                {
                    double total = kv.Value.Out + kv.Value.Ng;
                    procs[kv.Key] = new Dictionary<string, object> {
                        { "out", kv.Value.Out }, { "ng", kv.Value.Ng },
                        { "quality", total > 0 ? QPctUtil.Down(kv.Value.Out * 100.0 / total) : (double?)null } };
                }
            var mcs = new Dictionary<string, object>();
            lock (Sync)
                foreach (var kv in _mc)
                {
                    double total = kv.Value.Out + kv.Value.Ng;
                    mcs[kv.Key] = new Dictionary<string, object> {
                        { "out", kv.Value.Out }, { "ng", kv.Value.Ng },
                        { "quality", total > 0 ? QPctUtil.Down(kv.Value.Out * 100.0 / total) : (double?)null } };
                }
            return new Dictionary<string, object> {
                { "lastRead", LastRead.HasValue ? LastRead.Value.ToString("yyyy-MM-dd HH:mm:ss") : null },
                { "lastError", LastError }, { "processes", procs }, { "machines", mcs } };
        }

        public static void Refresh()
        {
            if (Interlocked.Exchange(ref _busy, 1) == 1) return;
            try
            {
                ConnectionStringSettings cs = ConfigurationManager.ConnectionStrings[CONN_NAME];
                if (cs == null || string.IsNullOrWhiteSpace(cs.ConnectionString)) { LastError = "ไม่พบ " + CONN_NAME + " ใน Web.config"; return; }
                DateTime dayStart = CounterStore.ProdDayStart(DateTime.Now);
                var data = new Dictionary<string, Item>(StringComparer.OrdinalIgnoreCase);
                using (var c = new SqlConnection(cs.ConnectionString))
                using (var cmd = c.CreateCommand())
                {
                    cmd.CommandTimeout = 20;
                    cmd.CommandText = @"
                        SELECT LTRIM(RTRIM(O.NAME)) AS ProcName,
                               SUM(ISNULL(SOR.OUTQTY, 0))    AS OutQty,
                               SUM(ISNULL(SOR.DEFECTQTY, 0)) AS NgQty
                          FROM SFT_OP_REALRUN SOR
                          JOIN OPERATION O ON O.ERP_OPID = SOR.ERP_OPID
                         WHERE SOR.OUTTIME >= @From AND SOR.OUTTIME < @To
                           AND SOR.[SEQUENCE] = 0
                         GROUP BY LTRIM(RTRIM(O.NAME))";
                    cmd.Parameters.AddWithValue("@From", dayStart);
                    cmd.Parameters.AddWithValue("@To", dayStart.AddDays(1));
                    c.Open();
                    using (var rd = cmd.ExecuteReader())
                        while (rd.Read())
                        {
                            if (rd.IsDBNull(0)) continue;
                            data[rd.GetString(0)] = new Item
                            {
                                Out = rd.IsDBNull(1) ? 0 : Convert.ToDouble(rd.GetValue(1)),
                                Ng = rd.IsDBNull(2) ? 0 : Convert.ToDouble(rd.GetValue(2))
                            };
                        }
                }
                // ---- รายเครื่อง: แถว Check-Out (EQID ไม่ว่าง) + NG จาก SFT_OP_EXCEPT (เหมือนหน้า IOT_NGDashcord) ----
                var mc = new Dictionary<string, Item>(StringComparer.OrdinalIgnoreCase);
                using (var c = new SqlConnection(cs.ConnectionString))
                using (var cmd = c.CreateCommand())
                {
                    cmd.CommandTimeout = 30;
                    cmd.CommandText = @"
                        SELECT X.EQID, SUM(X.OutQty) AS OutQty, SUM(X.NgQty) AS NgQty
                          FROM (
                                SELECT LTRIM(RTRIM(A.EQID)) AS EQID,
                                       ISNULL(A.OUTQTY, 0) AS OutQty,
                                       ISNULL((SELECT SUM(E.EXCEPTQTY) FROM SFT_OP_EXCEPT E
                                                WHERE E.ID = A.ID AND E.ERP_OPID = A.ERP_OPID
                                                  AND E.EXCEPTTYPE = 'defect'), 0) AS NgQty
                                  FROM SFT_OP_REALRUN A
                                 WHERE A.OUTTIME >= @From AND A.OUTTIME < @To
                                   AND ISNULL(A.EQID, '') <> ''
                               ) X
                         GROUP BY X.EQID";
                    cmd.Parameters.AddWithValue("@From", dayStart);
                    cmd.Parameters.AddWithValue("@To", dayStart.AddDays(1));
                    c.Open();
                    using (var rd = cmd.ExecuteReader())
                        while (rd.Read())
                        {
                            if (rd.IsDBNull(0)) continue;
                            string key = NormEqid(rd.GetString(0));
                            Item it;
                            if (!mc.TryGetValue(key, out it)) mc[key] = it = new Item();
                            it.Out += rd.IsDBNull(1) ? 0 : Convert.ToDouble(rd.GetValue(1));
                            it.Ng += rd.IsDBNull(2) ? 0 : Convert.ToDouble(rd.GetValue(2));
                        }
                }
                lock (Sync) { _data = data; _mc = mc; }
                LastRead = DateTime.Now;
                LastError = null;
            }
            catch (Exception ex)
            {
                LastError = DateTime.Now.ToString("HH:mm:ss") + " " + ex.Message;
            }
            finally
            {
                Interlocked.Exchange(ref _busy, 0);
            }
        }
    }

    // =====================================================================
    // OeeReport : OEE ย้อนหลัง (หน้า OEE Dashboard) ใช้สูตรเดียวกับ MC Monitor
    //   A = Operating / (Operating + Loss + Offline)      <- สถานะจริงจากเครื่อง (mc_daily)
    //   P = Σ(Shot x Std CT) / Operating                  <- Shot จากเครื่อง (mc_daily)
    //   Q = Good / (Good + NG)                            <- ERP รายเครื่อง (EQID) ช่วงเดียวกัน
    //   วันผลิต 08:00 -> 08:00 วันถัดไป
    //   GET CounterMachine.aspx?format=oee&from=yyyy-MM-dd&to=yyyy-MM-dd[&proc=Injection][&machine=MC27]
    // =====================================================================
    // Quality % : ปัดลง 2 ตำแหน่ง -> มี NG แม้ 1 ชิ้นจะไม่แสดง 100% · NG % : ปัดขึ้น -> มี NG จะไม่แสดง 0%
    public static class QPctUtil
    {
        public static double Down(double pct) { return Math.Floor(pct * 100.0 + 1e-7) / 100.0; }
        public static double Up(double pct) { return Math.Ceiling(pct * 100.0 - 1e-7) / 100.0; }
    }

    public static class OeeReport
    {
        static double? Pct(double num, double den) { return den > 0 ? Math.Round(num * 100.0 / den, 1) : (double?)null; }

        public static Dictionary<string, object> Build(DateTime fromDay, DateTime toDay, string process, string machine)
        {
            if (toDay < fromDay) { var t = fromDay; fromDay = toDay; toDay = t; }
            int hh = CounterStore.DAY_START_HOUR;
            DateTime from = fromDay.Date.AddHours(hh), to = toDay.Date.AddDays(1).AddHours(hh);
            string dbErr, erpErr;
            var days = OeeDb.DailyRange(fromDay, toDay, out dbErr);
            var erp = ErpQuality.RangeByMachine(from, to, out erpErr);

            var rows = new List<Dictionary<string, object>>();
            var usedErp = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            double tOp = 0, tPlan = 0, tStd = 0, tGood = 0, tNg = 0, tErpOut = 0; long tShots = 0, tPieces = 0; int tBatches = 0;

            foreach (var d in days)
            {
                if (!string.IsNullOrEmpty(process) && !string.Equals(process, "All", StringComparison.OrdinalIgnoreCase)
                    && !string.Equals(d.Process, process, StringComparison.OrdinalIgnoreCase)) continue;
                if (!string.IsNullOrEmpty(machine) && !string.Equals(machine, d.Machine, StringComparison.OrdinalIgnoreCase)) continue;

                string eq = ErpQuality.EqidFor(d.Machine);
                ErpQuality.ErpAgg e = null;
                if (!string.IsNullOrEmpty(eq) && erp.TryGetValue(eq, out e)) usedErp.Add(eq);

                double plan = d.OperatingSec + d.LossSec + d.OfflineSec;
                double? A = Pct(d.OperatingSec, plan);
                double? P = d.StdShotSec > 0 ? Math.Min(100.0, Math.Round(d.StdShotSec * 100.0 / Math.Max(1, d.OperatingSec), 1)) : (double?)null;
                double? Q = e != null && (e.Out + e.Ng) > 0 ? QPctUtil.Down(e.Out * 100.0 / (e.Out + e.Ng)) : (double?)null;
                double? O = (A.HasValue && P.HasValue) ? Math.Round(A.Value * P.Value * (Q ?? 100.0) / 10000.0, 1) : (double?)null;

                rows.Add(new Dictionary<string, object> {
                    { "machine", d.Machine }, { "eqid", e != null ? e.Eqid : eq }, { "process", d.Process }, { "days", d.Days },
                    { "plannedHours", Math.Round(plan / 3600.0, 2) }, { "runHours", Math.Round(d.OperatingSec / 3600.0, 2) },
                    { "lossHours", Math.Round(d.LossSec / 3600.0, 2) }, { "offlineHours", Math.Round(d.OfflineSec / 3600.0, 2) },
                    { "shots", d.Shots }, { "cavities", d.Cavities }, { "pieces", d.Pieces }, { "stdCt", d.StdCt },
                    { "batches", e != null ? e.Batches : 0 },
                    { "erpGood", e != null ? e.Out : (double?)null }, { "erpNg", e != null ? e.Ng : (double?)null },
                    { "erpActual", e != null ? e.Out + e.Ng : (double?)null },
                    { "diffPcs", e != null ? (double?)(d.Pieces - (e.Out + e.Ng)) : null },   // ยอดเครื่อง - ยอด ERP
                    { "availability", A }, { "performance", P }, { "quality", Q }, { "qualityAssumed", !Q.HasValue }, { "oee", O }
                });
                tOp += d.OperatingSec; tPlan += plan; tStd += d.StdShotSec; tShots += d.Shots; tPieces += d.Pieces;
                if (e != null) { tGood += e.Out; tNg += e.Ng; tErpOut += e.Out + e.Ng; tBatches += e.Batches; }
            }

            // เครื่องที่มีใน ERP แต่ยังไม่มีข้อมูลจากเครื่อง (ยังไม่ต่อ IoT) -> แสดงไว้ให้รู้
            var erpOnly = new List<Dictionary<string, object>>();
            foreach (var kv in erp)
            {
                if (usedErp.Contains(kv.Key)) continue;
                if (!string.IsNullOrEmpty(process) && !string.Equals(process, "All", StringComparison.OrdinalIgnoreCase)
                    && !string.Equals(kv.Value.Process, process, StringComparison.OrdinalIgnoreCase)) continue;
                if (!string.IsNullOrEmpty(machine)) continue;
                erpOnly.Add(new Dictionary<string, object> {
                    { "eqid", kv.Value.Eqid }, { "process", kv.Value.Process }, { "batches", kv.Value.Batches },
                    { "erpGood", kv.Value.Out }, { "erpNg", kv.Value.Ng }, { "erpActual", kv.Value.Out + kv.Value.Ng } });
            }

            double? TA = Pct(tOp, tPlan);
            double? TP = tStd > 0 ? Math.Min(100.0, Math.Round(tStd * 100.0 / Math.Max(1, tOp), 1)) : (double?)null;
            double? TQ = (tGood + tNg) > 0 ? QPctUtil.Down(tGood * 100.0 / (tGood + tNg)) : (double?)null;
            double? TO = (TA.HasValue && TP.HasValue) ? Math.Round(TA.Value * TP.Value * (TQ ?? 100.0) / 10000.0, 1) : (double?)null;

            return new Dictionary<string, object> {
                { "ok", dbErr == null }, { "from", from.ToString("yyyy-MM-dd HH:mm") }, { "to", to.ToString("yyyy-MM-dd HH:mm") },
                { "process", process ?? "All" }, { "rows", rows }, { "erpOnly", erpOnly },
                { "total", new Dictionary<string, object> {
                    { "machines", rows.Count }, { "batches", tBatches },
                    { "plannedHours", Math.Round(tPlan / 3600.0, 1) }, { "runHours", Math.Round(tOp / 3600.0, 1) },
                    { "downHours", Math.Round((tPlan - tOp) / 3600.0, 1) },
                    { "shots", tShots }, { "pieces", tPieces }, { "erpGood", tGood }, { "erpNg", tNg }, { "erpActual", tErpOut },
                    { "availability", TA }, { "performance", TP }, { "quality", TQ }, { "oee", TO } } },
                { "dbError", dbErr }, { "erpError", erpErr },
                { "method", "A,P = machine status/shots (mc_daily, same as MC Monitor) · Q = ERP good/NG per EQID · day 08:00-08:00" }
            };
        }

        // OEE รายวันของเครื่องเดียว (แท็บ OEE ใน popup เครื่อง หน้า MC Monitor)
        //   GET CounterMachine.aspx?format=oeedaily&machine=MC13&from=yyyy-MM-dd&to=yyyy-MM-dd
        // Quality 2 ตำแหน่ง ปัดลง -> มี NG แม้ 1 ชิ้นจะไม่ขึ้น 100% (เช่น 4654 / 4656 = 99.95%)
        static double QPct(double good, double ng) { return QPctUtil.Down(good * 100.0 / (good + ng)); }

        public static Dictionary<string, object> Daily(string machine, DateTime fromDay, DateTime toDay)
        {
            if (toDay < fromDay) { var t = fromDay; fromDay = toDay; toDay = t; }
            int hh = CounterStore.DAY_START_HOUR;
            string dbErr, erpErr;
            var md = OeeDb.MachineDays(machine, fromDay, toDay, out dbErr);
            var erp = ErpQuality.DailyForMachine(machine, fromDay.Date.AddHours(hh), toDay.Date.AddDays(1).AddHours(hh), out erpErr);
            var byDay = new Dictionary<DateTime, OeeDb.MachineDay>();
            foreach (var x in md) byDay[x.Day] = x;

            var rows = new List<Dictionary<string, object>>();
            double tOp = 0, tLoss = 0, tOff = 0, tStd = 0, tGood = 0, tNg = 0; long tShots = 0, tPieces = 0; int tBatches = 0, nDays = 0;
            for (DateTime day = fromDay.Date; day <= toDay.Date; day = day.AddDays(1))
            {
                OeeDb.MachineDay d; ErpQuality.ErpAgg e;
                byDay.TryGetValue(day, out d); erp.TryGetValue(day, out e);
                if (d == null && e == null) { rows.Add(new Dictionary<string, object> { { "day", day.ToString("yyyy-MM-dd") }, { "noData", true } }); continue; }
                double op = d != null ? d.OperatingSec : 0, plan = d != null ? d.OperatingSec + d.LossSec + d.OfflineSec : 0;
                double? A = Pct(op, plan);
                double? P = d != null && d.StdShotSec > 0 ? Math.Min(100.0, Math.Round(d.StdShotSec * 100.0 / Math.Max(1, op), 1)) : (double?)null;
                double? Q = e != null && (e.Out + e.Ng) > 0 ? QPct(e.Out, e.Ng) : (double?)null;
                double? O = (A.HasValue && P.HasValue) ? Math.Round(A.Value * P.Value * (Q ?? 100.0) / 10000.0, 1) : (double?)null;
                rows.Add(new Dictionary<string, object> {
                    { "day", day.ToString("yyyy-MM-dd") }, { "noData", false },
                    { "plannedHours", Math.Round(plan / 3600.0, 2) }, { "runHours", Math.Round(op / 3600.0, 2) },
                    { "lossHours", d != null ? Math.Round(d.LossSec / 3600.0, 2) : 0 }, { "offlineHours", d != null ? Math.Round(d.OfflineSec / 3600.0, 2) : 0 },
                    { "shots", d != null ? d.Shots : 0 }, { "pieces", d != null ? d.Pieces : 0 }, { "stdCt", d != null ? d.StdCt : null },
                    { "batches", e != null ? e.Batches : 0 }, { "erpGood", e != null ? e.Out : (double?)null }, { "erpNg", e != null ? e.Ng : (double?)null },
                    { "availability", A }, { "performance", P }, { "quality", Q }, { "qualityAssumed", !Q.HasValue }, { "oee", O }
                });
                if (d != null) { tOp += d.OperatingSec; tLoss += d.LossSec; tOff += d.OfflineSec; tStd += d.StdShotSec; tShots += d.Shots; tPieces += d.Pieces; nDays++; }
                if (e != null) { tGood += e.Out; tNg += e.Ng; tBatches += e.Batches; }
            }
            double tPlan = tOp + tLoss + tOff;
            double? TA = Pct(tOp, tPlan);
            double? TP = tStd > 0 ? Math.Min(100.0, Math.Round(tStd * 100.0 / Math.Max(1, tOp), 1)) : (double?)null;
            double? TQ = (tGood + tNg) > 0 ? QPct(tGood, tNg) : (double?)null;
            double? TO = (TA.HasValue && TP.HasValue) ? Math.Round(TA.Value * TP.Value * (TQ ?? 100.0) / 10000.0, 1) : (double?)null;
            return new Dictionary<string, object> {
                { "ok", dbErr == null }, { "machine", machine }, { "eqid", ErpQuality.EqidFor(machine) },
                { "from", fromDay.ToString("yyyy-MM-dd") }, { "to", toDay.ToString("yyyy-MM-dd") }, { "rows", rows },
                { "total", new Dictionary<string, object> {
                    { "days", nDays }, { "plannedHours", Math.Round(tPlan / 3600.0, 1) }, { "runHours", Math.Round(tOp / 3600.0, 1) },
                    { "lossHours", Math.Round(tLoss / 3600.0, 1) }, { "offlineHours", Math.Round(tOff / 3600.0, 1) },
                    { "shots", tShots }, { "pieces", tPieces }, { "batches", tBatches }, { "erpGood", tGood }, { "erpNg", tNg },
                    { "availability", TA }, { "performance", TP }, { "quality", TQ }, { "oee", TO } } },
                { "dbError", dbErr }, { "erpError", erpErr }
            };
        }
    }
}
