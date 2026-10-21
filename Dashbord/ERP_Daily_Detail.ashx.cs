using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Web;
using System.Web.Script.Serialization;

namespace Dashbord
{
    // =========================================================
    // ERP_Daily_Detail.ashx
    //   ข้อมูลรายละเอียดสำหรับ Popup ของหน้า ERP_Daily_Report.aspx
    //
    //   ?kind=done|ng|wip
    //   &op=06            (ERP_OPID ว่าง = ทุก Process)
    //   &from=2026-10-05&to=2026-10-05   (วันกะ ใช้กับ done / ng)
    //   &type=0|1|2       (0 = All, 1 = In-house, 2 = Subcontract)
    // =========================================================
    public class ERP_Daily_Detail : IHttpHandler
    {
        const int MaxRows = 3000;

        public bool IsReusable { get { return false; } }

        // สูตร PO_Number เดียวกับหน้า PO Search
        const string PoExpr = @"
            CASE
                WHEN SOR.ID LIKE '5101-20260608001%' THEN 'PO:4500762127'
                WHEN SOR.ID LIKE '5101-2026062202%'  THEN 'PO:4500762994'
                WHEN M.DESCRIPTION IS NULL
                     OR LTRIM(RTRIM(M.DESCRIPTION)) = '' THEN 'No PO'
                ELSE LTRIM(RTRIM(M.DESCRIPTION))
            END";

        const string TypeFilter = @"
            (@Type = 0 OR SOR.ERP_OPID IN (SELECT ERP_OPID FROM OPERATION WHERE COMPLEXION = @Type))";

        public void ProcessRequest(HttpContext ctx)
        {
            ctx.Response.ContentType = "application/json";
            ctx.Response.Cache.SetCacheability(HttpCacheability.NoCache);

            JavaScriptSerializer js = new JavaScriptSerializer();
            js.MaxJsonLength = Int32.MaxValue;

            try
            {
                string kind = (ctx.Request["kind"] ?? "").ToLowerInvariant();
                string op = (ctx.Request["op"] ?? "").Trim();
                int type = 0;
                Int32.TryParse(ctx.Request["type"], out type);
                if (type != 1 && type != 2) type = 0;

                DateTime from = ParseDate(ctx.Request["from"]);
                DateTime to = ParseDate(ctx.Request["to"]);
                if (to < from) { DateTime t = from; from = to; to = t; }

                string sql;

                if (kind == "done" || kind == "ng")
                {
                    sql = @"
                        SELECT TOP (@Max)
                            SOR.OUTTIME                                     AS T,
                            CONVERT(VARCHAR(10), DATEADD(HOUR, -8, SOR.OUTTIME), 120) AS ShiftDate,
                            " + PoExpr + @"                                 AS PO,
                            SOR.ID                                          AS Batch,
                            M.MO022                                         AS Ball,
                            SOR.ERP_OPID                                    AS Op,
                            SOR.EQID                                        AS Machine,
                            SOR.ERP_WSID                                    AS Line,
                            CAST(SOR.OUTQTY - SOR.SURPLUSQTY + SOR.UNKNOWQTY + SOR.DEFECTQTY
                                 - SOR.OR034 - SOR.OR038 AS INT)            AS Completed,
                            CAST(ISNULL(SOR.ARRIVEQTY, 0) AS INT)           AS InQty,
                            CAST(ISNULL(SOR.OUTQTY, 0) AS INT)              AS OutQty,
                            CAST(ISNULL(SOR.DEFECTQTY, 0) AS INT)           AS NG,
                            CAST(ISNULL(SOR.UNKNOWQTY, 0) AS INT)           AS Loss,
                            ISNULL(STUFF((
                                SELECT ', ' + E.EXCEPTREASON + ' (' + CAST(CAST(E.EXCEPTQTY AS INT) AS VARCHAR(20)) + ')'
                                FROM SFT_OP_EXCEPT E
                                WHERE E.ID = SOR.ID
                                  AND E.ERP_OPID = SOR.ERP_OPID
                                  AND E.EXCEPTTYPE = 'defect'
                                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, ''), '') AS Reasons

                        FROM SFT_OP_REALRUN SOR
                        LEFT JOIN MODETAIL M ON SOR.ID = M.CMOID

                        WHERE SOR.OUTTIME >= DATEADD(HOUR, 8, CAST(@DateFrom AS DATETIME))
                          AND SOR.OUTTIME <  DATEADD(HOUR, 8, DATEADD(DAY, 1, CAST(@DateTo AS DATETIME)))
                          AND SOR.[SEQUENCE] = 0
                          AND (@Op = '' OR SOR.ERP_OPID = @Op)
                          AND " + TypeFilter +
                          (kind == "ng" ? " AND ISNULL(SOR.DEFECTQTY, 0) > 0" : "") + @"

                        ORDER BY SOR.OUTTIME DESC";
                }
                else if (kind == "wip")
                {
                    sql = @"
                        SELECT TOP (@Max)
                            SOR.ARRIVETIME                                  AS T,
                            " + PoExpr + @"                                 AS PO,
                            SOR.ID                                          AS Batch,
                            M.MO022                                         AS Ball,
                            SOR.ERP_OPID                                    AS Op,
                            SOR.EQID                                        AS Machine,
                            SOR.ERP_WSID                                    AS Line,
                            CAST(ISNULL(SOR.ARRIVEQTY, 0) AS INT)           AS InQty,
                            DATEDIFF(MINUTE, SOR.ARRIVETIME, GETDATE())     AS WaitMin

                        FROM SFT_OP_REALRUN SOR
                        LEFT JOIN MODETAIL M ON SOR.ID = M.CMOID

                        WHERE SOR.ARRIVETIME IS NOT NULL
                          AND (SOR.OUTTIME IS NULL OR ISNULL(SOR.OUTQTY, 0) = 0)
                          AND (@Op = '' OR SOR.ERP_OPID = @Op)
                          AND " + TypeFilter + @"

                        ORDER BY SOR.ARRIVETIME";
                }
                else
                {
                    ctx.Response.StatusCode = 400;
                    ctx.Response.Write(js.Serialize(new { error = "kind must be done, ng or wip" }));
                    return;
                }

                DataTable dt = new DataTable();
                string connStr = ConfigurationManager.ConnectionStrings["EMESConnectionString"].ConnectionString;

                using (SqlConnection conn = new SqlConnection(connStr))
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.CommandTimeout = 120;
                    cmd.Parameters.Add("@Max", SqlDbType.Int).Value = MaxRows + 1;
                    cmd.Parameters.Add("@DateFrom", SqlDbType.Date).Value = from;
                    cmd.Parameters.Add("@DateTo", SqlDbType.Date).Value = to;
                    cmd.Parameters.Add("@Op", SqlDbType.VarChar, 20).Value = op;
                    cmd.Parameters.Add("@Type", SqlDbType.Int).Value = type;

                    using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                    {
                        da.Fill(dt);
                    }
                }

                bool truncated = dt.Rows.Count > MaxRows;
                List<object> rows = new List<object>();

                foreach (DataRow r in dt.Rows)
                {
                    if (rows.Count >= MaxRows) break;

                    if (kind == "wip")
                    {
                        rows.Add(new
                        {
                            t = Dt(r["T"]),
                            tk = DtKey(r["T"]),
                            po = Str(r["PO"]),
                            batch = Str(r["Batch"]),
                            ball = Str(r["Ball"]),
                            op = Str(r["Op"]),
                            machine = Str(r["Machine"]),
                            line = Str(r["Line"]),
                            qty = ToInt(r["InQty"]),
                            wait = ToInt(r["WaitMin"])
                        });
                    }
                    else
                    {
                        rows.Add(new
                        {
                            t = Dt(r["T"]),
                            tk = DtKey(r["T"]),
                            shift = ShiftText(r["ShiftDate"]),
                            po = Str(r["PO"]),
                            batch = Str(r["Batch"]),
                            ball = Str(r["Ball"]),
                            op = Str(r["Op"]),
                            machine = Str(r["Machine"]),
                            line = Str(r["Line"]),
                            qty = ToInt(r["Completed"]),
                            inQty = ToInt(r["InQty"]),
                            outQty = ToInt(r["OutQty"]),
                            ng = ToInt(r["NG"]),
                            loss = ToInt(r["Loss"]),
                            reasons = Str(r["Reasons"])
                        });
                    }
                }

                ctx.Response.Write(js.Serialize(new { kind = kind, rows = rows, truncated = truncated, max = MaxRows }));
            }
            catch (Exception ex)
            {
                ctx.Response.StatusCode = 500;
                ctx.Response.Write(js.Serialize(new { error = ex.Message }));
            }
        }


        // =========================================================
        // Helpers
        // =========================================================
        static readonly string[] DateFormats = { "yyyy-MM-dd", "dd/MM/yyyy", "d/M/yyyy" };

        private static DateTime ParseDate(string s)
        {
            DateTime d;
            if (DateTime.TryParseExact((s ?? "").Trim(), DateFormats, CultureInfo.InvariantCulture, DateTimeStyles.None, out d))
                return d.Date;
            return DateTime.Now.AddHours(-8).Date;
        }

        private static string Str(object v)
        {
            return v == null || v == DBNull.Value ? "" : v.ToString().Trim();
        }

        private static int ToInt(object v)
        {
            return v == null || v == DBNull.Value ? 0 : Convert.ToInt32(v);
        }

        private static string Dt(object v)
        {
            if (v == null || v == DBNull.Value) return "";
            return Convert.ToDateTime(v).ToString("dd/MM/yyyy HH:mm", CultureInfo.InvariantCulture);
        }

        private static string DtKey(object v)
        {
            if (v == null || v == DBNull.Value) return "";
            return Convert.ToDateTime(v).ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture);
        }

        // "2026-10-05" -> "05/10/2026"
        private static string ShiftText(object v)
        {
            string s = Str(v);
            DateTime d;
            if (DateTime.TryParseExact(s, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d))
                return d.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture);
            return s;
        }
    }
}
