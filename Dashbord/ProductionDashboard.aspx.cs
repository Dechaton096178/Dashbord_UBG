using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Globalization;
using System.Web.Script.Serialization;

namespace Dashbord
{
    // =========================================================
    // Production Dashboard : ยอดผลิตวันนี้ทุก Process + ยอดตามเครื่องจักร + ยอด NG รายชั่วโมง
    //   ข้อมูลจาก EMES_UNIVERSAL (EMESConnectionString)
    //   วันผลิต = 08:00 ถึง 08:00 วันถัดไป (เหมือน DATEADD(HOUR,-8,OUTTIME))
    //   GET ?format=json&day=yyyy-MM-dd&op=03[&eq=2.UB-MC-CM-008]
    // =========================================================
    public partial class ProductionDashboard : System.Web.UI.Page
    {
        const string CONN_NAME = "EMESConnectionString";
        const int CACHE_SEC = 30;   // หลายจอเปิดพร้อมกัน ไม่ต้องยิง SQL ทุกครั้ง

        // ยอดผลิต (สูตรเดียวกับ Power BI)
        const string QTY = "(S.OUTQTY - S.SURPLUSQTY + S.UNKNOWQTY + S.DEFECTQTY - S.OR034 - S.OR038)";

        static readonly object _lock = new object();
        static readonly Dictionary<string, KeyValuePair<DateTime, string>> _cache = new Dictionary<string, KeyValuePair<DateTime, string>>();

        protected void Page_Load(object sender, EventArgs e)
        {
            if (Request.QueryString["format"] != "json") return;

            Response.Clear();
            Response.ContentType = "application/json";
            Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
            try
            {
                DateTime day;
                if (!DateTime.TryParseExact(Request.QueryString["day"] ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out day))
                    day = DateTime.Now.AddHours(-8).Date;
                string op = Clean(Request.QueryString["op"], 4);
                if (op == "") op = "03";
                string eq = Clean(Request.QueryString["eq"], 40);

                string key = day.ToString("yyyyMMdd") + "|" + op + "|" + eq;
                string json = null;
                lock (_lock)
                {
                    KeyValuePair<DateTime, string> hit;
                    if (_cache.TryGetValue(key, out hit) && (DateTime.Now - hit.Key).TotalSeconds < CACHE_SEC) json = hit.Value;
                }
                if (json == null)
                {
                    json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue }.Serialize(Build(day, op, eq));
                    lock (_lock)
                    {
                        if (_cache.Count > 200) _cache.Clear();
                        _cache[key] = new KeyValuePair<DateTime, string>(DateTime.Now, json);
                    }
                }
                Response.Write(json);
            }
            catch (Exception ex)
            {
                Response.StatusCode = 500;
                Response.Write(new JavaScriptSerializer().Serialize(new Dictionary<string, object> { { "error", ex.Message } }));
            }
            Response.Flush();
            Response.SuppressContent = true;
            Context.ApplicationInstance.CompleteRequest();
        }

        static string Clean(string s, int max)
        {
            s = (s ?? "").Trim();
            if (s.Length > max) s = s.Substring(0, max);
            return s;
        }

        // 12 -> 08.12 , 13 -> 10.13 (เหมือนรายงานเดิม)
        static string DisplayOp(string op)
        {
            if (op == "12") return "08.12";
            if (op == "13") return "10.13";
            return op;
        }
        static double SortKey(string disp)
        {
            double d;
            return double.TryParse(disp, NumberStyles.Float, CultureInfo.InvariantCulture, out d) ? d : 999;
        }

        static Dictionary<string, object> Build(DateTime day, string op, string eq)
        {
            DateTime from = day.AddHours(8), to = from.AddDays(1);
            var res = new Dictionary<string, object>();
            res["day"] = day.ToString("yyyy-MM-dd");
            res["from"] = from.ToString("yyyy-MM-dd HH:mm");
            res["to"] = to.ToString("yyyy-MM-dd HH:mm");
            res["op"] = op;
            res["eq"] = eq;
            res["updated"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");

            ConnectionStringSettings cs = ConfigurationManager.ConnectionStrings[CONN_NAME];
            if (cs == null) throw new Exception(CONN_NAME + " not found in Web.config");

            using (var c = new SqlConnection(cs.ConnectionString))
            {
                c.Open();

                // ---------- 1) ยอดผลิตวันนี้ ทุก Process ----------
                var procs = new List<Dictionary<string, object>>();
                using (var cmd = c.CreateCommand())
                {
                    cmd.CommandTimeout = 60;
                    cmd.CommandText = @"
                        SELECT T.ERP_OPID, T.NAME, T.COMPLEXION, ISNULL(X.NUM, 0) AS NUM
                          FROM (SELECT DISTINCT ERP_OPID, NAME, COMPLEXION FROM OPERATION) T
                          LEFT JOIN (
                                SELECT S.ERP_OPID, CAST(SUM(" + QTY + @") AS INT) AS NUM
                                  FROM SFT_OP_REALRUN S
                                 WHERE S.OUTTIME >= @From AND S.OUTTIME < @To
                                   AND S.EQID IS NOT NULL AND LTRIM(RTRIM(S.EQID)) <> ''
                                 GROUP BY S.ERP_OPID
                          ) X ON X.ERP_OPID = T.ERP_OPID";
                    cmd.Parameters.AddWithValue("@From", from);
                    cmd.Parameters.AddWithValue("@To", to);
                    using (var r = cmd.ExecuteReader())
                        while (r.Read())
                        {
                            string id = Convert.ToString(r["ERP_OPID"]).Trim();
                            string cx = Convert.ToString(r["COMPLEXION"]).Trim();
                            string disp = DisplayOp(id);
                            procs.Add(new Dictionary<string, object> {
                                { "op", id }, { "code", disp },
                                { "name", Convert.ToString(r["NAME"]).Trim() },
                                { "type", cx == "1" ? "In-house" : cx == "2" ? "Subcontract" : "Other" },
                                { "num", Convert.ToInt64(r["NUM"]) },
                                { "sort", SortKey(disp) }
                            });
                        }
                }
                procs.Sort((a, b) => ((double)a["sort"]).CompareTo((double)b["sort"]));
                foreach (var p in procs) p.Remove("sort");
                res["processes"] = procs;

                // ---------- 2) ยอดผลิตตามเครื่องจักร (Process ที่เลือก) + NG รายเครื่อง ----------
                var mcs = new List<Dictionary<string, object>>();
                using (var cmd = c.CreateCommand())
                {
                    cmd.CommandTimeout = 60;
                    cmd.CommandText = @"
                        SELECT P.EQID, P.NUM, ISNULL(N.NG, 0) AS NG
                          FROM (
                                SELECT LTRIM(RTRIM(S.EQID)) AS EQID, CAST(SUM(" + QTY + @") AS INT) AS NUM
                                  FROM SFT_OP_REALRUN S
                                 WHERE S.ERP_OPID = @Op AND S.OUTTIME >= @From AND S.OUTTIME < @To
                                   AND S.EQID IS NOT NULL AND LTRIM(RTRIM(S.EQID)) <> ''
                                 GROUP BY LTRIM(RTRIM(S.EQID))
                          ) P
                          LEFT JOIN (
                                SELECT LTRIM(RTRIM(A.EQID)) AS EQID, SUM(E.EXCEPTQTY) AS NG
                                  FROM SFT_OP_REALRUN A
                                  JOIN SFT_OP_EXCEPT E ON E.ID = A.ID AND E.ERP_OPID = A.ERP_OPID AND E.EXCEPTTYPE = 'defect'
                                 WHERE A.ERP_OPID = @Op AND A.OUTTIME >= @From AND A.OUTTIME < @To
                                 GROUP BY LTRIM(RTRIM(A.EQID))
                          ) N ON N.EQID = P.EQID";
                    cmd.Parameters.AddWithValue("@Op", op);
                    cmd.Parameters.AddWithValue("@From", from);
                    cmd.Parameters.AddWithValue("@To", to);
                    using (var r = cmd.ExecuteReader())
                        while (r.Read())
                            mcs.Add(new Dictionary<string, object> {
                                { "eq", Convert.ToString(r["EQID"]) },
                                { "num", r["NUM"] == DBNull.Value ? 0L : Convert.ToInt64(r["NUM"]) },
                                { "ng", Convert.ToDouble(r["NG"]) }
                            });
                }
                mcs.Sort((a, b) => ((long)b["num"]).CompareTo((long)a["num"]));
                res["machines"] = mcs;

                // ---------- 3) ยอด NG รายชั่วโมง ตามสาเหตุ ----------
                var ng = new List<Dictionary<string, object>>();
                using (var cmd = c.CreateCommand())
                {
                    cmd.CommandTimeout = 60;
                    cmd.CommandText = @"
                        SELECT DATEPART(HOUR, A.OUTTIME) AS H,
                               LTRIM(RTRIM(ISNULL(E.EXCEPTGROUP, ''))) AS GRP,
                               LTRIM(RTRIM(ISNULL(E.EXCEPTREASON, ''))) AS REASON,
                               SUM(E.EXCEPTQTY) AS QTY
                          FROM SFT_OP_REALRUN A
                          JOIN SFT_OP_EXCEPT E ON E.ID = A.ID AND E.ERP_OPID = A.ERP_OPID AND E.EXCEPTTYPE = 'defect'
                         WHERE A.ERP_OPID = @Op AND A.OUTTIME >= @From AND A.OUTTIME < @To
                           AND A.EQID IS NOT NULL AND LTRIM(RTRIM(A.EQID)) <> ''" +
                           (eq != "" ? " AND LTRIM(RTRIM(A.EQID)) = @Eq" : "") + @"
                         GROUP BY DATEPART(HOUR, A.OUTTIME), LTRIM(RTRIM(ISNULL(E.EXCEPTGROUP, ''))), LTRIM(RTRIM(ISNULL(E.EXCEPTREASON, '')))";
                    cmd.Parameters.AddWithValue("@Op", op);
                    cmd.Parameters.AddWithValue("@From", from);
                    cmd.Parameters.AddWithValue("@To", to);
                    if (eq != "") cmd.Parameters.AddWithValue("@Eq", eq);
                    using (var r = cmd.ExecuteReader())
                        while (r.Read())
                        {
                            double q = r["QTY"] == DBNull.Value ? 0 : Convert.ToDouble(r["QTY"]);
                            if (q == 0) continue;
                            ng.Add(new Dictionary<string, object> {
                                { "h", Convert.ToInt32(r["H"]) },
                                { "group", Convert.ToString(r["GRP"]) },
                                { "reason", Convert.ToString(r["REASON"]) },
                                { "qty", q }
                            });
                        }
                }
                res["ng"] = ng;
            }
            return res;
        }
    }
}
