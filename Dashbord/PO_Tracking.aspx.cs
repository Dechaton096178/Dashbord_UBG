using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Web.Script.Serialization;

namespace Dashbord
{
    // =====================================================================
    // PO Tracking : PO นี้ผลิตถึง Process ไหนแล้ว
    //   - ทุก Batch (MO) ของ PO -> ทุกขั้นตอนใน SFT_OP_REALRUN (Check-In / Check-Out)
    //   - สรุปราย Process : เริ่ม / จบ / In / Good / NG / Loss / สถานะ
    //   - NG แยกสาเหตุจาก SFT_OP_EXCEPT (EXCEPTTYPE = 'defect')
    //   GET ?format=json&po=4500762127[&batch=...]   -> ข้อมูล PO
    //   GET ?format=list[&q=...]                     -> รายการ PO ล่าสุด (ช่องค้นหา)
    // =====================================================================
    public partial class PO_Tracking : System.Web.UI.Page
    {
        const string CONN_NAME = "EMESConnectionString";
        const int LIST_DAYS = 120;

        // สูตร PO เดียวกับหน้า PO Search
        const string PoExpr = @"
            CASE
                WHEN A.ID LIKE '5101-20260608001%' THEN 'PO:4500762127'
                WHEN A.ID LIKE '5101-2026062202%'  THEN 'PO:4500762994'
                WHEN M.DESCRIPTION IS NULL OR LTRIM(RTRIM(M.DESCRIPTION)) = '' THEN 'No PO'
                ELSE LTRIM(RTRIM(M.DESCRIPTION))
            END";

        protected void Page_Load(object sender, EventArgs e)
        {
            string fmt = Request.QueryString["format"];
            if (fmt != "json" && fmt != "list") return;

            Response.Clear();
            Response.ContentType = "application/json";
            Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
            var js = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
            try
            {
                if (fmt == "list") Response.Write(js.Serialize(PoList((Request.QueryString["q"] ?? "").Trim())));
                else Response.Write(js.Serialize(Build((Request.QueryString["po"] ?? "").Trim(), (Request.QueryString["batch"] ?? "").Trim())));
            }
            catch (Exception ex)
            {
                Response.StatusCode = 500;
                Response.Write(js.Serialize(new Dictionary<string, object> { { "error", ex.Message } }));
            }
            Response.Flush();
            Response.SuppressContent = true;
            Context.ApplicationInstance.CompleteRequest();
        }

        static SqlConnection Open()
        {
            var cs = ConfigurationManager.ConnectionStrings[CONN_NAME];
            if (cs == null) throw new Exception(CONN_NAME + " not found in Web.config");
            var c = new SqlConnection(cs.ConnectionString);
            c.Open();
            return c;
        }

        // 12 -> 08.12 , 13 -> 10.13
        static string DisplayOp(string op) { return op == "12" ? "08.12" : op == "13" ? "10.13" : op; }
        static double SortKey(string op)
        {
            double d;
            return double.TryParse(DisplayOp(op), NumberStyles.Float, CultureInfo.InvariantCulture, out d) ? d : 999;
        }
        static string Dt(DateTime? t) { return t.HasValue ? t.Value.ToString("yyyy-MM-dd HH:mm:ss") : null; }

        // ------------------------------------------------------------ รายการ PO ล่าสุด
        static List<Dictionary<string, object>> PoList(string q)
        {
            var list = new List<Dictionary<string, object>>();
            using (var c = Open())
            using (var cmd = c.CreateCommand())
            {
                cmd.CommandTimeout = 60;
                cmd.CommandText = @"
                    SELECT TOP 300 P.PO_Number, COUNT(DISTINCT A.ID) AS Batches, MAX(A.ARRIVETIME) AS LastTime,
                           MAX(LTRIM(RTRIM(M.MO022))) AS Ball
                      FROM SFT_OP_REALRUN A
                      LEFT JOIN MODETAIL M ON A.ID = M.CMOID
                     CROSS APPLY (SELECT " + PoExpr + @" AS PO_Number) P
                     WHERE A.ARRIVETIME >= DATEADD(DAY, -@Days, GETDATE())
                       AND P.PO_Number <> 'No PO'
                       AND (@Q = '' OR P.PO_Number LIKE '%' + @Q + '%')
                     GROUP BY P.PO_Number
                     ORDER BY MAX(A.ARRIVETIME) DESC";
                cmd.Parameters.Add("@Days", SqlDbType.Int).Value = LIST_DAYS;
                cmd.Parameters.Add("@Q", SqlDbType.NVarChar, 100).Value = q;
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                        list.Add(new Dictionary<string, object> {
                            { "po", Convert.ToString(r["PO_Number"]) },
                            { "batches", Convert.ToInt32(r["Batches"]) },
                            { "ball", r["Ball"] == DBNull.Value ? "" : Convert.ToString(r["Ball"]) },
                            { "last", r["LastTime"] == DBNull.Value ? null : Dt(Convert.ToDateTime(r["LastTime"])) } });
            }
            return list;
        }

        // ------------------------------------------------------------ ข้อมูล PO
        class Step
        {
            public string Batch, Ball, Op, Proc, Line, Eqid, Po;
            public DateTime? In, Out;
            public long InQty, OutQty, Ng, Loss;
            public long Defect, Surplus, Or034, Or038, OutSum; public int OutRows; public DateTime? FirstOut;
            // In - Good - NG - Loss (เฉพาะขั้นที่ Check-Out แล้ว) = ยอดที่ไม่ได้อยู่ใน 3 ช่องนี้
            public long Diff { get { return Wip ? 0 : InQty - OutQty - Ng - Loss; } }
            public bool Wip { get { return !Out.HasValue || OutQty == 0; } }
        }

        static long HD(System.Data.IDataRecord r, string head, string detail)
        {
            long h = r[head] == DBNull.Value ? 0 : Convert.ToInt64(r[head]);
            long d = r[detail] == DBNull.Value ? 0 : Convert.ToInt64(r[detail]);
            return Math.Max(h, d);
        }

        static Dictionary<string, object> Build(string po, string batch)
        {
            if (po == "" && batch == "") throw new Exception("Please enter a PO or Batch");
            var steps = new List<Step>();
            var opName = new Dictionary<string, string>();
            var reasons = new List<Dictionary<string, object>>();

            using (var c = Open())
            {
                // ---------- ทุกขั้นตอนของทุก Batch ใน PO ----------
                //   1 Batch / 1 Process อาจมีหลายแถว (Check-In / Check-Out) -> รวมเป็นแถวเดียว
                using (var cmd = c.CreateCommand())
                {
                    cmd.CommandTimeout = 120;
                    cmd.CommandText = @"
                        WITH B AS (
                            SELECT DISTINCT A.ID
                              FROM SFT_OP_REALRUN A
                              LEFT JOIN MODETAIL M ON A.ID = M.CMOID
                             CROSS APPLY (SELECT " + PoExpr + @" AS PO_Number) P
                             WHERE (@PO = '' OR P.PO_Number = @PO OR P.PO_Number = 'PO:' + @PO OR REPLACE(P.PO_Number, 'PO:', '') = @PO)
                               AND (@Batch = '' OR A.ID LIKE '%' + @Batch + '%')
                        )
                        SELECT A.ID, A.ERP_OPID, MAX(" + PoExpr.Replace("\n", " ") + @") AS PO_Number,
                               MAX(LTRIM(RTRIM(M.MO022)))                         AS Ball,
                               MAX(LTRIM(RTRIM(W.MW002)))                         AS ProcName,
                               MAX(LTRIM(RTRIM(A.ERP_WSID)))                      AS Line,
                               MAX(CASE WHEN LTRIM(RTRIM(ISNULL(A.EQID,''))) <> '' THEN LTRIM(RTRIM(A.EQID)) END) AS Eqid,
                               MIN(A.ARRIVETIME)                                  AS InTime,
                               MAX(A.OUTTIME)                                     AS OutTime,
                               -- SEQUENCE 0 = แถวหัว (Check-In / ยอดรวม) · SEQUENCE >= 1 = Check-Out แต่ละครั้ง (ออกได้หลายครั้ง)
                               MAX(CAST(ISNULL(A.ARRIVEQTY, 0) AS BIGINT))        AS InQty,
                               MAX(CASE WHEN A.SEQUENCE = 0 THEN CAST(ISNULL(A.OUTQTY, 0) AS BIGINT) END)           AS OutH,
                               SUM(CASE WHEN A.SEQUENCE > 0 THEN CAST(ISNULL(A.OUTQTY, 0) AS BIGINT) ELSE 0 END)    AS OutD,
                               MAX(CASE WHEN A.SEQUENCE = 0 THEN CAST(ISNULL(A.ALERADYDEFECTQTY, 0) AS BIGINT) END) AS NgH,
                               SUM(CASE WHEN A.SEQUENCE > 0 THEN CAST(ISNULL(A.ALERADYDEFECTQTY, 0) AS BIGINT) ELSE 0 END) AS NgD,
                               MAX(CASE WHEN A.SEQUENCE = 0 THEN CAST(ISNULL(A.UNKNOWQTY, 0) AS BIGINT) END)        AS LossH,
                               SUM(CASE WHEN A.SEQUENCE > 0 THEN CAST(ISNULL(A.UNKNOWQTY, 0) AS BIGINT) ELSE 0 END) AS LossD,
                               MAX(CASE WHEN A.SEQUENCE = 0 THEN CAST(ISNULL(A.DEFECTQTY, 0) AS BIGINT) END)        AS DefH,
                               SUM(CASE WHEN A.SEQUENCE > 0 THEN CAST(ISNULL(A.DEFECTQTY, 0) AS BIGINT) ELSE 0 END) AS DefD,
                               MAX(CASE WHEN A.SEQUENCE = 0 THEN CAST(ISNULL(A.SURPLUSQTY, 0) AS BIGINT) END)       AS SurH,
                               SUM(CASE WHEN A.SEQUENCE > 0 THEN CAST(ISNULL(A.SURPLUSQTY, 0) AS BIGINT) ELSE 0 END) AS SurD,
                               MAX(CASE WHEN A.SEQUENCE = 0 THEN CAST(ISNULL(A.OR034, 0) AS BIGINT) END)            AS O34H,
                               SUM(CASE WHEN A.SEQUENCE > 0 THEN CAST(ISNULL(A.OR034, 0) AS BIGINT) ELSE 0 END)     AS O34D,
                               MAX(CASE WHEN A.SEQUENCE = 0 THEN CAST(ISNULL(A.OR038, 0) AS BIGINT) END)            AS O38H,
                               SUM(CASE WHEN A.SEQUENCE > 0 THEN CAST(ISNULL(A.OR038, 0) AS BIGINT) ELSE 0 END)     AS O38D,
                               SUM(CASE WHEN A.SEQUENCE > 0 AND ISNULL(A.OUTQTY, 0) > 0 THEN 1 ELSE 0 END)          AS OutRows,
                               MIN(CASE WHEN A.SEQUENCE > 0 AND ISNULL(A.OUTQTY, 0) > 0 THEN A.OUTTIME END)         AS FirstOut
                          FROM SFT_OP_REALRUN A
                          JOIN B ON B.ID = A.ID
                          LEFT JOIN MODETAIL M ON A.ID = M.CMOID
                          LEFT JOIN UNIVERSAL.dbo.CMSMW W ON A.ERP_OPID = W.MW001
                         GROUP BY A.ID, A.ERP_OPID";
                    cmd.Parameters.Add("@PO", SqlDbType.NVarChar, 100).Value = po;
                    cmd.Parameters.Add("@Batch", SqlDbType.NVarChar, 100).Value = batch;
                    using (var r = cmd.ExecuteReader())
                        while (r.Read())
                        {
                            var s = new Step {
                                Batch = Convert.ToString(r["ID"]).Trim(),
                                Po = r["PO_Number"] == DBNull.Value ? "" : Convert.ToString(r["PO_Number"]).Trim(),
                                Op = Convert.ToString(r["ERP_OPID"]).Trim(),
                                Ball = r["Ball"] == DBNull.Value ? "" : Convert.ToString(r["Ball"]),
                                Proc = r["ProcName"] == DBNull.Value ? "" : Convert.ToString(r["ProcName"]),
                                Line = r["Line"] == DBNull.Value ? "" : Convert.ToString(r["Line"]),
                                Eqid = r["Eqid"] == DBNull.Value ? "" : Convert.ToString(r["Eqid"]),
                                In = r["InTime"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(r["InTime"]),
                                Out = r["OutTime"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(r["OutTime"]),
                                InQty = Convert.ToInt64(r["InQty"]),
                                // ยอดรวมของ Batch = ค่ามากกว่าระหว่าง "แถวหัว" กับ "ผลรวมทุกครั้งที่ Check-Out"
                                OutQty = HD(r, "OutH", "OutD"), Ng = HD(r, "NgH", "NgD"), Loss = HD(r, "LossH", "LossD"),
                                Defect = HD(r, "DefH", "DefD"), Surplus = HD(r, "SurH", "SurD"),
                                Or034 = HD(r, "O34H", "O34D"), Or038 = HD(r, "O38H", "O38D"),
                                OutRows = Convert.ToInt32(r["OutRows"]), OutSum = Convert.ToInt64(r["OutD"]),
                                FirstOut = r["FirstOut"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(r["FirstOut"])
                            };
                            if (!s.In.HasValue && !s.Out.HasValue) continue;
                            steps.Add(s);
                        }
                }

                // ---------- ชื่อ Process (กรณี CMSMW ไม่มี) ----------
                using (var cmd = c.CreateCommand())
                {
                    cmd.CommandText = "SELECT DISTINCT ERP_OPID, NAME FROM OPERATION";
                    using (var r = cmd.ExecuteReader())
                        while (r.Read())
                        {
                            string k = Convert.ToString(r["ERP_OPID"]).Trim();
                            if (!opName.ContainsKey(k)) opName[k] = Convert.ToString(r["NAME"]).Trim();
                        }
                }

                // ---------- NG แยกสาเหตุ ----------
                if (steps.Count > 0)
                    using (var cmd = c.CreateCommand())
                    {
                        cmd.CommandTimeout = 120;
                        var ids = steps.Select(x => x.Batch).Distinct().ToList();
                        var pn = new List<string>();
                        for (int i = 0; i < ids.Count && i < 1500; i++) { pn.Add("@b" + i); cmd.Parameters.AddWithValue("@b" + i, ids[i]); }
                        cmd.CommandText = @"
                            SELECT E.ERP_OPID, LTRIM(RTRIM(ISNULL(E.EXCEPTGROUP, ''))) AS Grp,
                                   LTRIM(RTRIM(ISNULL(E.EXCEPTREASON, ''))) AS Reason, SUM(E.EXCEPTQTY) AS Qty
                              FROM SFT_OP_EXCEPT E
                             WHERE E.EXCEPTTYPE = 'defect' AND E.ID IN (" + string.Join(",", pn) + @")
                             GROUP BY E.ERP_OPID, LTRIM(RTRIM(ISNULL(E.EXCEPTGROUP, ''))), LTRIM(RTRIM(ISNULL(E.EXCEPTREASON, '')))";
                        using (var r = cmd.ExecuteReader())
                            while (r.Read())
                            {
                                double q = r["Qty"] == DBNull.Value ? 0 : Convert.ToDouble(r["Qty"]);
                                if (q <= 0) continue;
                                reasons.Add(new Dictionary<string, object> {
                                    { "op", Convert.ToString(r["ERP_OPID"]).Trim() },
                                    { "group", Convert.ToString(r["Grp"]) },
                                    { "reason", Convert.ToString(r["Reason"]) }, { "qty", q } });
                            }
                    }
            }

            foreach (var s in steps) if (string.IsNullOrEmpty(s.Proc)) s.Proc = opName.ContainsKey(s.Op) ? opName[s.Op] : s.Op;

            DateTime now = DateTime.Now;
            var res = new Dictionary<string, object>();
            res["po"] = po; res["batch"] = batch; res["now"] = Dt(now);
            if (steps.Count == 0) { res["found"] = false; return res; }
            res["found"] = true;

            // ---------- ราย Process (เรียงตามลำดับขั้นตอน) ----------
            //   Batch ที่ "ยังไม่มาถึง" ขั้นนี้ = ยังไม่มี Check-In ที่ขั้นนี้ และขั้นล่าสุดของ Batch อยู่ก่อนขั้นนี้ (ยังค้างอยู่ขั้นก่อนหน้า)
            //   -> ขั้นนี้จะขึ้น Done ได้ก็ต่อเมื่อทุก Batch ของ PO มาถึงและ Check-Out ครบแล้ว
            var byBatch = steps.GroupBy(x => x.Batch).ToDictionary(b => b.Key, b => b.ToList());
            var procs = new List<Dictionary<string, object>>();
            foreach (var g in steps.GroupBy(x => x.Op).OrderBy(g => SortKey(g.Key)))
            {
                var list = g.ToList();
                int wip = list.Count(x => x.Wip);
                double k = SortKey(g.Key);
                var here = new HashSet<string>(list.Select(x => x.Batch));
                var notArrived = byBatch.Where(b => !here.Contains(b.Key) && b.Value.Max(x => SortKey(x.Op)) < k)
                                        .Select(b => new { id = b.Key, last = b.Value.OrderBy(x => SortKey(x.Op)).ThenBy(x => x.In ?? x.Out).Last() })
                                        .OrderBy(b => b.id).ToList();
                int na = notArrived.Count;
                DateTime? first = list.Where(x => x.In.HasValue).Select(x => x.In).Min();
                DateTime? lastOut = list.Where(x => x.Out.HasValue).Select(x => x.Out).Max();
                long inQ = list.Sum(x => x.InQty), outQ = list.Sum(x => x.OutQty), ng = list.Sum(x => x.Ng), loss = list.Sum(x => x.Loss);
                double busyH = list.Where(x => x.In.HasValue).Sum(x => ((x.Out ?? now) - x.In.Value).TotalHours);
                procs.Add(new Dictionary<string, object> {
                    { "op", g.Key }, { "code", DisplayOp(g.Key) }, { "name", list[0].Proc },
                    { "batches", list.Count }, { "wip", wip }, { "done", list.Count - wip },
                    { "notArrived", na },
                    { "notArrivedQty", notArrived.Sum(b => b.last.Wip ? b.last.InQty : b.last.OutQty) },
                    { "notArrivedList", notArrived.Take(30).Select(b => new Dictionary<string, object> {
                        { "batch", b.id }, { "op", DisplayOp(b.last.Op) }, { "proc", b.last.Proc }, { "wip", b.last.Wip },
                        { "qty", b.last.Wip ? b.last.InQty : b.last.OutQty }, { "since", Dt(b.last.Out ?? b.last.In) } }).ToList() },
                    { "status", wip == 0 && na == 0 ? "done" : (wip == list.Count ? "wip" : "partial") },
                    { "start", Dt(first) }, { "end", wip == 0 && na == 0 ? Dt(lastOut) : null }, { "lastOut", Dt(lastOut) },
                    { "spanHours", first.HasValue ? Math.Round(((wip == 0 && na == 0 && lastOut.HasValue ? lastOut.Value : now) - first.Value).TotalHours, 1) : (double?)null },
                    { "batchHours", Math.Round(busyH, 1) },
                    { "inQty", inQ }, { "outQty", outQ }, { "ng", ng }, { "loss", loss },
                    { "diff", list.Sum(x => x.Diff) }, { "defect", list.Sum(x => x.Defect) }, { "surplus", list.Sum(x => x.Surplus) },
                    { "or034", list.Sum(x => x.Or034) }, { "or038", list.Sum(x => x.Or038) },
                    { "multiOut", list.Count(x => x.OutRows > 1) }, { "outSum", list.Sum(x => x.OutSum) },
                    { "ngPct", (outQ + ng) > 0 ? QPctUtil.Up(ng * 100.0 / (outQ + ng)) : (double?)null },
                    { "yield", inQ > 0 ? QPctUtil.Down(outQ * 100.0 / inQ) : (double?)null },
                    { "machines", list.Where(x => x.Eqid != "").Select(x => x.Eqid).Distinct().OrderBy(x => x).ToList() }
                });
            }
            res["processes"] = procs;

            // ---------- ราย Batch : ขั้นตอนล่าสุด ----------
            var batches = new List<Dictionary<string, object>>();
            foreach (var g in steps.GroupBy(x => x.Batch).OrderBy(g => g.Key))
            {
                var list = g.OrderBy(x => x.In ?? x.Out).ToList();
                var cur = list.Last();
                bool packed = list.Any(x => !x.Wip && x.Proc.IndexOf("Packing", StringComparison.OrdinalIgnoreCase) >= 0);
                batches.Add(new Dictionary<string, object> {
                    { "batch", g.Key }, { "ball", list[0].Ball },
                    { "curOp", cur.Op }, { "curProc", cur.Proc },
                    { "state", packed ? "finished" : cur.Wip ? "wip" : "waiting" },   // waiting = จบขั้นนี้แล้ว รอขั้นถัดไป
                    { "start", Dt(list.Where(x => x.In.HasValue).Select(x => x.In).Min()) },
                    { "lastMove", Dt(list.Select(x => x.Out ?? x.In).Max()) },
                    { "steps", list.Select(x => new Dictionary<string, object> {
                        { "op", x.Op }, { "proc", x.Proc }, { "line", x.Line }, { "eqid", x.Eqid },
                        { "in", Dt(x.In) }, { "out", Dt(x.Out) }, { "wip", x.Wip },
                        { "inQty", x.InQty }, { "outQty", x.OutQty }, { "ng", x.Ng }, { "loss", x.Loss },
                        { "diff", x.Diff }, { "defect", x.Defect }, { "surplus", x.Surplus }, { "or034", x.Or034 }, { "or038", x.Or038 },
                        { "outRows", x.OutRows }, { "outSum", x.OutSum }, { "firstOut", Dt(x.FirstOut) } }).ToList() }
                });
            }
            res["batches"] = batches;
            res["reasons"] = reasons;

            // ---------- สรุป PO ----------
            DateTime? poStart = steps.Where(x => x.In.HasValue).Select(x => x.In).Min();
            DateTime? poLast = steps.Select(x => x.Out ?? x.In).Max();
            var firstProc = procs.First(); var lastProc = procs.Last();
            int finished = batches.Count(b => (string)b["state"] == "finished");
            res["summary"] = new Dictionary<string, object> {
                { "pos", steps.Select(x => x.Po).Where(x => x != "").Distinct().OrderBy(x => x).ToList() },
                { "balls", steps.Select(x => x.Ball).Where(x => x != "").Distinct().ToList() },
                { "batchCount", batches.Count }, { "finished", finished },
                { "wipBatches", batches.Count(b => (string)b["state"] == "wip") },
                { "start", Dt(poStart) }, { "lastMove", Dt(poLast) },
                { "leadHours", poStart.HasValue ? Math.Round(((finished == batches.Count && poLast.HasValue ? poLast.Value : now) - poStart.Value).TotalHours, 1) : (double?)null },
                { "furthestOp", lastProc["op"] }, { "furthestName", lastProc["name"] },
                { "startQty", firstProc["inQty"] }, { "lastGood", lastProc["outQty"] },
                { "totalNg", steps.Sum(x => x.Ng) }, { "totalLoss", steps.Sum(x => x.Loss) },
                { "status", finished == batches.Count ? "finished" : "inprogress" }
            };
            return res;
        }
    }
}
