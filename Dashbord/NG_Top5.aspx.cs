using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Web.Script.Serialization;

namespace Dashbord
{
    // =====================================================================
    // NG Top 5 by Process : ปัญหางานเสีย 5 อันดับแรกของแต่ละ Process (ERP)
    //   - NG  = SFT_OP_EXCEPT (EXCEPTTYPE = 'defect') ของ Batch ที่ Check-Out ในช่วงที่เลือก
    //   - Good = OUTQTY (แถวหัว SEQUENCE 0 หรือผลรวม Check-Out SEQUENCE >= 1 ใช้ค่าที่มากกว่า) -> NG % = NG / (Good + NG)
    //   - 1 Batch x 1 Process นับครั้งเดียว (รวมแถวใน SFT_OP_REALRUN ก่อน JOIN NG -> ไม่นับซ้ำ)
    //   - วันผลิต 08:00 -> 08:00
    //   GET ?format=json&from=yyyy-MM-dd&to=yyyy-MM-dd
    // =====================================================================
    public partial class NG_Top5 : System.Web.UI.Page
    {
        const string CONN_NAME = "EMESConnectionString";
        const int DAY_START_HOUR = 8;
        const int MAX_DAYS = 92;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (Request.QueryString["format"] != "json") return;
            Response.Clear();
            Response.ContentType = "application/json";
            Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
            var js = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
            try
            {
                var ci = CultureInfo.InvariantCulture;
                DateTime now = DateTime.Now, today = (now.Hour < DAY_START_HOUR ? now.AddDays(-1) : now).Date, f, t;
                if (!DateTime.TryParseExact(Request.QueryString["to"] ?? "", "yyyy-MM-dd", ci, DateTimeStyles.None, out t)) t = today;
                if (!DateTime.TryParseExact(Request.QueryString["from"] ?? "", "yyyy-MM-dd", ci, DateTimeStyles.None, out f)) f = t;
                if (f > t) { var x = f; f = t; t = x; }
                if ((t - f).TotalDays >= MAX_DAYS) f = t.AddDays(-(MAX_DAYS - 1));
                Response.Write(js.Serialize(Build(f, t)));
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

        static string DisplayOp(string op) { return op == "12" ? "08.12" : op == "13" ? "10.13" : op; }
        static double SortKey(string op)
        {
            double d;
            return double.TryParse(DisplayOp(op), NumberStyles.Float, CultureInfo.InvariantCulture, out d) ? d : 999;
        }

        // Batch x Process ที่ Check-Out ในช่วงเวลา (รวมหลายแถวเป็นแถวเดียว)
        const string R_CTE = @"
            WITH R AS (
                SELECT A.ID, LTRIM(RTRIM(A.ERP_OPID)) AS OP,
                       MAX(CASE WHEN LTRIM(RTRIM(ISNULL(A.EQID, ''))) <> '' THEN LTRIM(RTRIM(A.EQID)) END) AS EQ,
                       MAX(CASE WHEN A.SEQUENCE = 0 THEN CAST(ISNULL(A.OUTQTY, 0) AS BIGINT) END)        AS OutH,
                       SUM(CASE WHEN A.SEQUENCE > 0 THEN CAST(ISNULL(A.OUTQTY, 0) AS BIGINT) ELSE 0 END) AS OutD,
                       MAX(LTRIM(RTRIM(W.MW002))) AS ProcName
                  FROM SFT_OP_REALRUN A
                  LEFT JOIN UNIVERSAL.dbo.CMSMW W ON A.ERP_OPID = W.MW001
                 WHERE A.OUTTIME >= @From AND A.OUTTIME < @To
                 GROUP BY A.ID, LTRIM(RTRIM(A.ERP_OPID))
            )";

        static Dictionary<string, object> Build(DateTime fromDay, DateTime toDay)
        {
            DateTime from = fromDay.Date.AddHours(DAY_START_HOUR), to = toDay.Date.AddDays(1).AddHours(DAY_START_HOUR);
            var procs = new Dictionary<string, Dictionary<string, object>>();
            var rows = new List<Dictionary<string, object>>();
            var opName = new Dictionary<string, string>();

            var cs = ConfigurationManager.ConnectionStrings[CONN_NAME];
            if (cs == null) throw new Exception(CONN_NAME + " not found in Web.config");
            using (var c = new SqlConnection(cs.ConnectionString))
            {
                c.Open();
                // ---------- ยอดดี / จำนวน Batch ต่อ Process ----------
                using (var cmd = c.CreateCommand())
                {
                    cmd.CommandTimeout = 90;
                    cmd.CommandText = R_CTE + @"
                        SELECT OP, MAX(ProcName) AS ProcName, COUNT(*) AS Lots,
                               SUM(CASE WHEN ISNULL(OutH, 0) > OutD THEN ISNULL(OutH, 0) ELSE OutD END) AS Good
                          FROM R GROUP BY OP";
                    cmd.Parameters.Add("@From", SqlDbType.DateTime).Value = from;
                    cmd.Parameters.Add("@To", SqlDbType.DateTime).Value = to;
                    using (var r = cmd.ExecuteReader())
                        while (r.Read())
                        {
                            string op = Convert.ToString(r["OP"]);
                            procs[op] = new Dictionary<string, object> {
                                { "op", op }, { "code", DisplayOp(op) }, { "name", r["ProcName"] == DBNull.Value ? "" : Convert.ToString(r["ProcName"]) },
                                { "lots", Convert.ToInt32(r["Lots"]) }, { "good", Convert.ToInt64(r["Good"]) } };
                        }
                }
                // ---------- NG ต่อ Process x สาเหตุ x เครื่อง ----------
                using (var cmd = c.CreateCommand())
                {
                    cmd.CommandTimeout = 90;
                    cmd.CommandText = R_CTE + @"
                        SELECT R.OP, ISNULL(R.EQ, '') AS EQ,
                               LTRIM(RTRIM(ISNULL(E.EXCEPTGROUP, '')))  AS Grp,
                               LTRIM(RTRIM(ISNULL(E.EXCEPTREASON, ''))) AS Reason,
                               SUM(CAST(ISNULL(E.EXCEPTQTY, 0) AS BIGINT)) AS Qty,
                               COUNT(DISTINCT R.ID) AS Lots
                          FROM R
                          JOIN SFT_OP_EXCEPT E ON E.ID = R.ID AND LTRIM(RTRIM(E.ERP_OPID)) = R.OP AND E.EXCEPTTYPE = 'defect'
                         GROUP BY R.OP, ISNULL(R.EQ, ''), LTRIM(RTRIM(ISNULL(E.EXCEPTGROUP, ''))), LTRIM(RTRIM(ISNULL(E.EXCEPTREASON, '')))
                        HAVING SUM(CAST(ISNULL(E.EXCEPTQTY, 0) AS BIGINT)) > 0";
                    cmd.Parameters.Add("@From", SqlDbType.DateTime).Value = from;
                    cmd.Parameters.Add("@To", SqlDbType.DateTime).Value = to;
                    using (var r = cmd.ExecuteReader())
                        while (r.Read())
                            rows.Add(new Dictionary<string, object> {
                                { "op", Convert.ToString(r["OP"]) }, { "eq", Convert.ToString(r["EQ"]) },
                                { "grp", Convert.ToString(r["Grp"]) }, { "reason", Convert.ToString(r["Reason"]) },
                                { "qty", Convert.ToInt64(r["Qty"]) }, { "lots", Convert.ToInt32(r["Lots"]) } });
                }
                // ---------- ชื่อ Process สำรอง (กรณี CMSMW ไม่มี) ----------
                try
                {
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
                }
                catch { }
            }

            foreach (var p in procs.Values)
                if (string.IsNullOrEmpty((string)p["name"])) p["name"] = opName.ContainsKey((string)p["op"]) ? opName[(string)p["op"]] : (string)p["op"];
            var list = new List<Dictionary<string, object>>(procs.Values);
            list.Sort((a, b) => SortKey((string)a["op"]).CompareTo(SortKey((string)b["op"])));

            return new Dictionary<string, object> {
                { "from", fromDay.ToString("yyyy-MM-dd") }, { "to", toDay.ToString("yyyy-MM-dd") },
                { "fromTime", from.ToString("yyyy-MM-dd HH:mm") }, { "toTime", to.ToString("yyyy-MM-dd HH:mm") },
                { "now", DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") },
                { "processes", list }, { "rows", rows }
            };
        }
    }
}
