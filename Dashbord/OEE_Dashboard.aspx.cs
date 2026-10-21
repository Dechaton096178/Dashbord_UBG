using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Web.Script.Serialization;
using System.Web.UI.WebControls;

namespace Dashbord
{
    // =====================================================================
    // OEE Dashboard  (คำนวณจากข้อมูล Check-Out ใน SFT_OP_REALRUN)
    //
    //   ระบบยังไม่มีข้อมูลเวลาเครื่องหยุด / Cycle Time มาตรฐาน
    //   จึงประมาณจากเวลา Check-Out ของแต่ละ Batch บนเครื่องเดียวกัน:
    //
    //   Run Time ของ Batch   = เวลา Check-Out นี้ − Check-Out ก่อนหน้า (เครื่องเดียวกัน)
    //                           ถ้าห่างเกิน MaxGapHours ถือว่าช่วงที่เกินคือ "เครื่องหยุด"
    //   Planned Time          = ชั่วโมงในช่วงวันกะที่เลือก × (HoursPerDay / 24)
    //   Ideal Rate (ชิ้น/ชม.) = P75 ของอัตราผลิตจริงของเครื่องนั้น ย้อนหลัง RateLookbackDays วัน
    //
    //   A (Availability) = Run Time / Planned Time
    //   P (Performance)  = ชิ้นที่ผลิตทั้งหมด / (Ideal Rate × Run Time)
    //   Q (Quality)      = ของดี (OUTQTY) / ชิ้นที่ผลิตทั้งหมด (OUT + NG + Loss)
    //   OEE              = A × P × Q
    //
    //   [ปรับให้ตรงกับ MC Monitor] เครื่องที่ต่อ IoT แล้ว (มีข้อมูลใน OEE.mc_daily)
    //     A = เวลาเดินจริง / (เดิน + หยุด + offline)       <- สถานะจากเครื่อง ชุดเดียวกับ MC Monitor
    //     P = Σ(Shot × Std CT) / เวลาเดินจริง              <- Shot จากเครื่อง
    //     Q = Good / (Good + NG) จาก ERP                    <- สูตรเดียวกับ MC Monitor
    //   เครื่องที่ยังไม่ต่อ IoT -> ใช้วิธีประมาณจาก Check-Out แบบเดิม (Source = ERP)
    // =====================================================================
    public partial class OEE_Dashboard : System.Web.UI.Page
    {
        // ---------------- ค่าที่ปรับได้ ----------------
        const double HoursPerDay = 24;      // เวลาวางแผนเดินเครื่องต่อวัน (ชม.)
        const double MaxGapHours = 4;       // ห่างจาก Batch ก่อนเกินนี้ = เครื่องหยุด
        const int RateLookbackDays = 30;    // ช่วงย้อนหลังที่ใช้หา Ideal Rate
        const double RatePercentile = 0.75; // P75 ของอัตราจริง = Ideal Rate (ตัดค่าโดดจากการสแกนติดกัน)
        const int MaxDetailRows = 3000;
        // ---------------------------------------------

        string connStr =
            ConfigurationManager
            .ConnectionStrings["EMESConnectionString"]
            .ConnectionString;

        public string PageData = "{}";

        // ---------------- กรองเครื่องให้ตรงแผนก ----------------
        //   ใน ERP มีบาง Batch ที่บันทึก Process ผิด (เช่น เครื่อง SF / VM โผล่ใน Injection)
        //   -> แสดงเฉพาะเครื่องที่ "ชนิดเครื่อง" ตรงกับแผนก (ดูจากรหัส UB-MC-XX-...)
        //   ใส่ไว้ที่นี่ = บังคับ ; แผนกที่ไม่ได้ใส่ -> เลือกชนิดเครื่องที่มีงานมากที่สุดให้อัตโนมัติ
        static readonly Dictionary<string, string[]> OpMachineTypes = new Dictionary<string, string[]> {
            { "03", new[] { "CM" } },   // Core Molding
            { "06", new[] { "PV" } },   // Injection
            { "07", new[] { "SF" } },   // Seambuffing
            { "08", new[] { "VM" } },   // Vanmark
        };
        const double AutoTypeMinShare = 0.2;   // แผนกที่ไม่ได้ตั้ง : ชนิดที่มีงาน >= 20% ของชนิดที่มากสุด

        // "1.UB-MC-PV-1-1" -> "PV" , "2.UB-MC-SF-001" -> "SF"
        static string MachineType(string eqid)
        {
            var m = System.Text.RegularExpressions.Regex.Match(eqid ?? "", @"MC-([A-Za-z]+)", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            return m.Success ? m.Groups[1].Value.ToUpperInvariant() : "";
        }

        HashSet<string> AllowedTypes
        {
            get { var a = ViewState["types"] as string; return a == null ? null : new HashSet<string>(a.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)); }
            set { ViewState["types"] = value == null ? null : string.Join(",", value); }
        }
        bool TypeOk(string eqid)
        {
            var t = AllowedTypes;
            return t == null || t.Count == 0 || t.Contains(MachineType(eqid));
        }

        static readonly string[] DateFormats = { "yyyy-MM-dd", "dd/MM/yyyy", "d/M/yyyy" };


        // =========================================================
        // Page Load / Events
        // =========================================================
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                DateTime shiftToday = DateTime.Now.AddHours(-8).Date;
                txtFrom.Text = shiftToday.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);   // ค่าเริ่มต้น = วันกะปัจจุบัน
                txtTo.Text = shiftToday.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

                LoadProcess();
                LoadMachine();
                LoadData();
            }
        }

        protected void ddlProcess_Changed(object sender, EventArgs e)
        {
            LoadMachine();
            LoadData();
        }

        protected void Filter_Changed(object sender, EventArgs e)
        {
            LoadData();
        }

        protected void btnSearch_Click(object sender, EventArgs e)
        {
            LoadData();
        }


        // =========================================================
        // Get Value
        // =========================================================
        private DateTime ParseDate(string s, DateTime def)
        {
            DateTime d;
            if (DateTime.TryParseExact((s ?? "").Trim(), DateFormats, CultureInfo.InvariantCulture, DateTimeStyles.None, out d))
                return d.Date;
            return def;
        }

        private string GetOp()
        {
            return String.IsNullOrEmpty(ddlProcess.SelectedValue) ? "06" : ddlProcess.SelectedValue;
        }

        private string GetMachine()
        {
            return String.IsNullOrEmpty(ddlMachine.SelectedValue) ? "All" : ddlMachine.SelectedValue;
        }


        // =========================================================
        // Process (OPERATION) — ค่าเริ่มต้น 06 Injection
        // =========================================================
        private void LoadProcess()
        {
            string sql = @"
                SELECT DISTINCT ERP_OPID, NAME
                FROM OPERATION
                WHERE ERP_OPID IS NOT NULL
                ORDER BY ERP_OPID";

            ddlProcess.Items.Clear();

            using (SqlConnection conn = new SqlConnection(connStr))
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                conn.Open();
                using (SqlDataReader dr = cmd.ExecuteReader())
                {
                    while (dr.Read())
                    {
                        string op = dr["ERP_OPID"].ToString().Trim();
                        string code = op == "12" ? "08.12" : (op == "13" ? "10.13" : op);
                        ddlProcess.Items.Add(new ListItem(code + " " + dr["NAME"].ToString().Trim(), op));
                    }
                }
            }

            if (ddlProcess.Items.FindByValue("06") != null) ddlProcess.SelectedValue = "06";
        }


        // =========================================================
        // เครื่องจักรใน Process ที่เลือก (ที่มีการผลิตใน 90 วันล่าสุด)
        // =========================================================
        private void LoadMachine()
        {
            string sql = @"
                SELECT LTRIM(RTRIM(EQID)) AS EQID, COUNT(*) AS N
                FROM SFT_OP_REALRUN
                WHERE ERP_OPID = @Op
                  AND EQID IS NOT NULL AND LTRIM(RTRIM(EQID)) <> ''
                  AND OUTTIME >= DATEADD(DAY, -90, GETDATE())
                GROUP BY LTRIM(RTRIM(EQID))
                ORDER BY EQID";

            string old = ddlMachine.SelectedValue;
            ddlMachine.Items.Clear();
            ddlMachine.Items.Add(new ListItem("All machines", "All"));

            using (SqlConnection conn = new SqlConnection(connStr))
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.Add("@Op", SqlDbType.VarChar, 20).Value = GetOp();
                conn.Open();
                var eqs = new List<KeyValuePair<string, int>>();
                using (SqlDataReader dr = cmd.ExecuteReader())
                    while (dr.Read()) eqs.Add(new KeyValuePair<string, int>(dr["EQID"].ToString(), Convert.ToInt32(dr["N"])));

                // ชนิดเครื่องที่ถือว่าเป็นของแผนกนี้
                string[] forced;
                HashSet<string> types;
                if (OpMachineTypes.TryGetValue(GetOp(), out forced)) types = new HashSet<string>(forced);
                else
                {
                    var byType = eqs.GroupBy(x => MachineType(x.Key)).ToDictionary(g => g.Key, g => g.Sum(x => x.Value));
                    int max = byType.Count > 0 ? byType.Values.Max() : 0;
                    types = new HashSet<string>(byType.Where(x => x.Value >= max * AutoTypeMinShare).Select(x => x.Key));
                }
                AllowedTypes = types;

                foreach (var e in eqs)
                    if (TypeOk(e.Key)) ddlMachine.Items.Add(new ListItem(e.Key, e.Key));
            }

            ddlMachine.SelectedValue = (!String.IsNullOrEmpty(old) && ddlMachine.Items.FindByValue(old) != null) ? old : "All";
        }


        // =========================================================
        // ข้อมูลหลัก + คำนวณ OEE
        // =========================================================
        class Batch
        {
            public string Machine, Batch_, PO, Ball, Line;
            public DateTime Out;
            public DateTime? Prev, CheckIn;
            public int InQty, OutQty, NG, Loss;
            public int Total { get { return OutQty + NG + Loss; } }
            public double RunH;     // ชั่วโมงที่นับเป็นเวลาเดินเครื่องของ Batch นี้
            public double GapH;     // ช่วงห่างจริงจาก Batch ก่อน (ชม.)
        }

        private void LoadData()
        {
            DateTime from = ParseDate(txtFrom.Text, DateTime.Now.AddHours(-8).Date);
            DateTime to = ParseDate(txtTo.Text, DateTime.Now.AddHours(-8).Date);
            if (to < from) { DateTime t = from; from = to; to = t; }

            DateTime start = from.AddHours(8);                 // วันกะเริ่ม 08:00
            DateTime end = to.AddDays(1).AddHours(8);           // ถึง 08:00 ของวันถัดไป
            DateTime effEnd = end > DateTime.Now ? DateTime.Now : end;   // วันนี้นับถึงเวลาปัจจุบัน
            DateTime rateStart = effEnd.AddDays(-RateLookbackDays);
            DateTime queryStart = rateStart < start ? rateStart : start;

            string op = GetOp();
            string machine = GetMachine();

            // ---------- ดึง Batch ที่ Check-Out บนเครื่อง (ย้อนหลังพอสำหรับหา Ideal Rate) ----------
            string sql = @"
                WITH R AS
                (
                    SELECT
                        SOR.ID,
                        SOR.ERP_OPID,
                        LTRIM(RTRIM(SOR.EQID)) AS EQID,
                        SOR.ERP_WSID,
                        SOR.OUTTIME,
                        CAST(ISNULL(SOR.OUTQTY, 0)    AS INT) AS OutQty,
                        CAST(ISNULL(SOR.DEFECTQTY, 0) AS INT) AS NG,
                        CAST(ISNULL(SOR.UNKNOWQTY, 0) AS INT) AS Loss,
                        LAG(SOR.OUTTIME) OVER (PARTITION BY LTRIM(RTRIM(SOR.EQID)) ORDER BY SOR.OUTTIME) AS PrevOut
                    FROM SFT_OP_REALRUN SOR
                    WHERE SOR.ERP_OPID = @Op
                      AND SOR.EQID IS NOT NULL AND LTRIM(RTRIM(SOR.EQID)) <> ''
                      AND (@EQID = 'All' OR LTRIM(RTRIM(SOR.EQID)) = @EQID)
                      AND SOR.OUTTIME >= DATEADD(DAY, -1, @QStart)
                      AND SOR.OUTTIME <  @End
                )
                SELECT
                    R.*,
                    CASE
                        WHEN R.ID LIKE '5101-20260608001%' THEN 'PO:4500762127'
                        WHEN R.ID LIKE '5101-2026062202%'  THEN 'PO:4500762994'
                        WHEN M.DESCRIPTION IS NULL OR LTRIM(RTRIM(M.DESCRIPTION)) = '' THEN 'No PO'
                        ELSE LTRIM(RTRIM(M.DESCRIPTION))
                    END AS PO,
                    M.MO022 AS Ball,
                    CI.ARRIVETIME AS CheckIn,
                    CAST(ISNULL(CI.ARRIVEQTY, 0) AS INT) AS InQty
                FROM R
                LEFT JOIN MODETAIL M ON R.ID = M.CMOID
                OUTER APPLY
                (
                    -- เวลา / จำนวน Check-In ของ Batch เดียวกัน (อยู่อีกแถว)
                    SELECT TOP 1 C.ARRIVETIME, C.ARRIVEQTY
                    FROM SFT_OP_REALRUN C
                    WHERE C.ID = R.ID AND C.ERP_OPID = R.ERP_OPID AND C.ARRIVETIME IS NOT NULL
                    ORDER BY C.ARRIVETIME DESC
                ) CI
                WHERE R.OUTTIME >= @QStart
                ORDER BY R.EQID, R.OUTTIME";

            List<Batch> all = new List<Batch>();

            using (SqlConnection conn = new SqlConnection(connStr))
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.CommandTimeout = 120;
                cmd.Parameters.Add("@Op", SqlDbType.VarChar, 20).Value = op;
                cmd.Parameters.Add("@EQID", SqlDbType.VarChar, 50).Value = machine;
                cmd.Parameters.Add("@QStart", SqlDbType.DateTime).Value = queryStart;
                cmd.Parameters.Add("@End", SqlDbType.DateTime).Value = end;

                conn.Open();
                using (SqlDataReader dr = cmd.ExecuteReader())
                {
                    while (dr.Read())
                    {
                        Batch b = new Batch
                        {
                            Machine = Str(dr["EQID"]),
                            Batch_ = Str(dr["ID"]),
                            PO = Str(dr["PO"]),
                            Ball = Str(dr["Ball"]),
                            Line = Str(dr["ERP_WSID"]),
                            Out = Convert.ToDateTime(dr["OUTTIME"]),
                            Prev = dr["PrevOut"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["PrevOut"]),
                            CheckIn = dr["CheckIn"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["CheckIn"]),
                            InQty = ToInt(dr["InQty"]),
                            OutQty = ToInt(dr["OutQty"]),
                            NG = ToInt(dr["NG"]),
                            Loss = ToInt(dr["Loss"])
                        };
                        b.GapH = b.Prev.HasValue ? (b.Out - b.Prev.Value).TotalHours : -1;
                        all.Add(b);
                    }
                }
            }

            // ตัด Batch ของเครื่องต่างแผนก (บันทึก Process ผิดใน ERP)
            int strayBatches = all.Count(x => x.Out >= start && x.Out < end && !TypeOk(x.Machine));
            all = all.Where(x => TypeOk(x.Machine)).ToList();

            // ---------- Ideal Rate ต่อเครื่อง : P75 ของอัตราจริงย้อนหลัง ----------
            Dictionary<string, double> idealRate = new Dictionary<string, double>();
            List<double> allRates = new List<double>();

            foreach (var g in all.Where(x => x.Out >= rateStart && x.GapH >= 5.0 / 60 && x.GapH <= MaxGapHours && x.Total > 0)
                                 .GroupBy(x => x.Machine))
            {
                List<double> rates = g.Select(x => x.Total / x.GapH).ToList();
                allRates.AddRange(rates);
                idealRate[g.Key] = Percentile(rates, RatePercentile);
            }
            double fallbackRate = allRates.Count > 0 ? Percentile(allRates, RatePercentile) : 0;

            // ---------- Batch ในช่วงที่เลือก + Run Time ----------
            List<Batch> inRange = all.Where(x => x.Out >= start && x.Out < end).ToList();

            foreach (Batch b in inRange)
            {
                double rate = idealRate.ContainsKey(b.Machine) ? idealRate[b.Machine] : fallbackRate;

                if (b.GapH >= 0 && b.GapH <= MaxGapHours)
                    b.RunH = b.GapH;                                   // เดินต่อเนื่อง
                else if (rate > 0)
                    b.RunH = Math.Min(b.Total / rate, MaxGapHours);    // หลังเครื่องหยุด : ประมาณจาก Ideal Rate
                else
                    b.RunH = 0;

                // ไม่นับเวลาก่อนเริ่มช่วงที่เลือก
                double sinceStart = (b.Out - start).TotalHours;
                if (b.RunH > sinceStart) b.RunH = Math.Max(0, sinceStart);
            }

            // ---------- สรุปต่อเครื่อง ----------
            double plannedPerMachine = Math.Max(0, (effEnd - start).TotalHours) * (HoursPerDay / 24.0);

            List<string> machines;
            if (machine == "All")
                machines = ddlMachine.Items.Cast<ListItem>().Where(i => i.Value != "All").Select(i => i.Value).ToList();
            else
                machines = new List<string> { machine };

            // เครื่องที่ไม่มีอยู่ในรายการแต่มีข้อมูล
            foreach (string m in inRange.Select(x => x.Machine).Distinct())
                if (!machines.Contains(m)) machines.Add(m);

            // ---------- ข้อมูลจากเครื่อง (IoT) ช่วงเดียวกัน : ตาราง OEE.mc_daily ----------
            string iotErr;
            var iot = new Dictionary<string, OeeDb.DayAgg>(StringComparer.OrdinalIgnoreCase);
            foreach (var x in OeeDb.DailyRange(from, to, out iotErr)) iot[x.Machine] = x;
            int iotCount = 0;
            double sumPRun = 0;
            long sumShots = 0, sumMpcs = 0;

            List<object> machineRows = new List<object>();
            double sumPlanned = 0, sumRun = 0, sumIdealQty = 0;
            long sumTotal = 0, sumGood = 0, sumNg = 0, sumLoss = 0;
            int sumBatches = 0;

            foreach (string m in machines.OrderBy(x => x))
            {
                List<Batch> bs = inRange.Where(x => x.Machine == m).ToList();
                double rate = idealRate.ContainsKey(m) ? idealRate[m] : fallbackRate;

                long total = bs.Sum(x => (long)x.Total);
                long good = bs.Sum(x => (long)x.OutQty);
                long ng = bs.Sum(x => (long)x.NG);
                long loss = bs.Sum(x => (long)x.Loss);

                // เครื่องนี้ต่อ IoT แล้วหรือยัง
                string code = ErpQuality.MachineForEqid(m);
                OeeDb.DayAgg ia = null;
                bool hasIot = code != null && iot.TryGetValue(code, out ia) && (ia.OperatingSec + ia.LossSec + ia.OfflineSec) > 0;

                double planned, run, a, p, idealQty;
                if (hasIot)
                {
                    double planSec = ia.OperatingSec + ia.LossSec + ia.OfflineSec;
                    planned = planSec / 3600.0;
                    run = ia.OperatingSec / 3600.0;
                    a = ia.OperatingSec / planSec;
                    if (ia.StdShotSec > 0 && ia.OperatingSec > 0)
                        p = Math.Min(1, ia.StdShotSec / ia.OperatingSec);                       // สูตรเดียวกับ MC Monitor
                    else
                    {
                        double iq = rate * run;                                               // ยังไม่ได้ตั้ง Std CT -> ใช้ Ideal rate จาก ERP
                        p = iq > 0 ? Math.Min(1, total / iq) : 0;
                    }
                    idealQty = (ia.StdCt.HasValue && ia.StdCt.Value > 0) ? ia.OperatingSec / ia.StdCt.Value * ia.Cavities : rate * run;
                    iotCount++;
                    sumShots += ia.Shots; sumMpcs += ia.Pieces;
                }
                else
                {
                    planned = plannedPerMachine;
                    run = Math.Min(bs.Sum(x => x.RunH), plannedPerMachine);
                    a = plannedPerMachine > 0 ? run / plannedPerMachine : 0;
                    idealQty = rate * run;
                    p = idealQty > 0 ? Math.Min(1, total / idealQty) : 0;
                }
                double q = (good + ng) > 0 ? (double)good / (good + ng) : 0;                // สูตรเดียวกับ MC Monitor

                sumPlanned += planned; sumRun += run; sumIdealQty += idealQty; sumPRun += p * run;
                sumTotal += total; sumGood += good; sumNg += ng; sumLoss += loss; sumBatches += bs.Count;

                machineRows.Add(new
                {
                    machine = m,
                    src = hasIot ? "IoT" : "ERP",
                    batches = bs.Count,
                    planned = Math.Round(planned, 1),
                    run = Math.Round(run, 1),
                    down = Math.Round(Math.Max(0, planned - run), 1),
                    rate = Math.Round(rate, 0),
                    total = total,
                    good = good,
                    ng = ng,
                    loss = loss,
                    shots = hasIot ? (long?)ia.Shots : null,
                    mpcs = hasIot ? (long?)ia.Pieces : null,                                  // ยอดชิ้นจากเครื่อง (Shot × Cavities)
                    diff = hasIot ? (long?)(ia.Pieces - total) : null,                       // ยอดเครื่อง − ยอด ERP
                    a = Math.Round(a * 100, 1),
                    p = Math.Round(p * 100, 1),
                    q = QPctUtil.Down(q * 100),
                    oee = Math.Round(a * p * q * 100, 1)
                });
            }

            double A = sumPlanned > 0 ? sumRun / sumPlanned : 0;
            double P = sumRun > 0 ? Math.Min(1, sumPRun / sumRun) : 0;                      // เฉลี่ยถ่วงด้วยเวลาเดิน
            double Q = (sumGood + sumNg) > 0 ? (double)sumGood / (sumGood + sumNg) : 0;

            // ---------- OEE รายวัน (กราฟแท่งเล็ก) ----------
            List<object> daily = new List<object>();
            for (DateTime d = from; d <= to; d = d.AddDays(1))
            {
                DateTime ds = d.AddHours(8), de = d.AddDays(1).AddHours(8);
                if (ds >= effEnd) break;
                DateTime dEnd = de > effEnd ? effEnd : de;
                List<Batch> bs = inRange.Where(x => x.Out >= ds && x.Out < de).ToList();

                double pl = (dEnd - ds).TotalHours * (HoursPerDay / 24.0) * machines.Count;
                double rn = 0, iq = 0;
                foreach (var g in bs.GroupBy(x => x.Machine))
                {
                    double r = idealRate.ContainsKey(g.Key) ? idealRate[g.Key] : fallbackRate;
                    double mr = Math.Min(g.Sum(x => x.RunH), (dEnd - ds).TotalHours * (HoursPerDay / 24.0));
                    rn += mr; iq += r * mr;
                }
                long tt = bs.Sum(x => (long)x.Total), gd = bs.Sum(x => (long)x.OutQty);

                double da = pl > 0 ? rn / pl : 0;
                double dp = iq > 0 ? Math.Min(1, tt / iq) : 0;
                double dq = tt > 0 ? (double)gd / tt : 0;

                daily.Add(new
                {
                    d = d.ToString("dd/MM", CultureInfo.InvariantCulture),
                    oee = Math.Round(da * dp * dq * 100, 1),
                    a = Math.Round(da * 100, 1),
                    p = Math.Round(dp * 100, 1),
                    q = QPctUtil.Down(dq * 100)
                });
            }

            // ---------- รายละเอียด Batch ----------
            List<object> batchRows = new List<object>();
            foreach (Batch b in inRange.OrderByDescending(x => x.Out).Take(MaxDetailRows))
            {
                batchRows.Add(new
                {
                    t = b.Out.ToString("dd/MM/yyyy HH:mm", CultureInfo.InvariantCulture),
                    tk = b.Out.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture),
                    tin = b.CheckIn.HasValue ? b.CheckIn.Value.ToString("dd/MM/yyyy HH:mm", CultureInfo.InvariantCulture) : "",
                    po = b.PO,
                    batch = b.Batch_,
                    ball = b.Ball,
                    machine = b.Machine,
                    line = b.Line,
                    inQty = b.InQty,
                    outQty = b.OutQty,
                    ng = b.NG,
                    loss = b.Loss,
                    total = b.Total,
                    run = Math.Round(b.RunH * 60, 0),                                      // นาที
                    rate = b.RunH > 0 ? Math.Round(b.Total / b.RunH, 0) : 0,
                    stop = b.GapH > MaxGapHours                                             // มีเครื่องหยุดก่อน Batch นี้
                });
            }

            var data = new
            {
                A = Math.Round(A * 100, 1),
                P = Math.Round(P * 100, 1),
                Q = QPctUtil.Down(Q * 100),
                OEE = Math.Round(A * P * Q * 100, 1),
                planned = Math.Round(sumPlanned, 1),
                run = Math.Round(sumRun, 1),
                down = Math.Round(Math.Max(0, sumPlanned - sumRun), 1),
                total = sumTotal,
                good = sumGood,
                ng = sumNg,
                loss = sumLoss,
                idealQty = Math.Round(sumIdealQty, 0),
                batches = sumBatches,
                machineCount = machines.Count,
                iotCount = iotCount,
                strayBatches = strayBatches,
                machineTypes = AllowedTypes == null ? "" : string.Join(", ", AllowedTypes),
                iotError = iotErr,
                shots = sumShots,
                mpcs = sumMpcs,
                machines = machineRows,
                daily = daily,
                rows = batchRows,
                truncated = inRange.Count > MaxDetailRows,
                maxRows = MaxDetailRows,
                process = ddlProcess.SelectedItem != null ? ddlProcess.SelectedItem.Text : op,
                machine = machine,
                dateFrom = from.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture),
                dateTo = to.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture),
                qFrom = from.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                qTo = to.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                cfg = new { hoursPerDay = HoursPerDay, maxGap = MaxGapHours, lookback = RateLookbackDays, pct = (int)(RatePercentile * 100) }
            };

            JavaScriptSerializer js = new JavaScriptSerializer();
            js.MaxJsonLength = Int32.MaxValue;
            PageData = js.Serialize(data);
        }


        // =========================================================
        // Helpers
        // =========================================================
        private static double Percentile(List<double> values, double p)
        {
            if (values == null || values.Count == 0) return 0;
            List<double> s = values.OrderBy(x => x).ToList();
            double idx = p * (s.Count - 1);
            int lo = (int)Math.Floor(idx), hi = (int)Math.Ceiling(idx);
            return s[lo] + (s[hi] - s[lo]) * (idx - lo);
        }

        private static string Str(object v)
        {
            return v == null || v == DBNull.Value ? "" : v.ToString().Trim();
        }

        private static int ToInt(object v)
        {
            return v == null || v == DBNull.Value ? 0 : Convert.ToInt32(v);
        }
    }
}
