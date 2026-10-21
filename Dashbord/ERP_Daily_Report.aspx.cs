using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Web.Script.Serialization;
using System.Web.UI.WebControls;

namespace Dashbord
{
    public partial class ERP_Daily_Report : System.Web.UI.Page
    {
        string connStr =
            ConfigurationManager
            .ConnectionStrings["EMESConnectionString"]
            .ConnectionString;

        // JSON ให้หน้าเว็บ (อ่านผ่าน <%= PageData %>)
        public string PageData = "{}";

        static readonly string[] DateFormats =
        {
            "yyyy-MM-dd", "dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "yyyy/MM/dd"
        };


        // =========================================================
        // Page Load
        // =========================================================
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                // วันกะปัจจุบัน : กะเริ่ม 08:00 ถ้ายังไม่ถึง 08:00 ถือเป็นกะของเมื่อวาน
                DateTime shiftToday = DateTime.Now.AddHours(-8).Date;
                txtFrom.Text = shiftToday.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                txtTo.Text = shiftToday.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

                LoadData();
            }
        }

        protected void btnSearch_Click(object sender, EventArgs e)
        {
            LoadData();
        }

        protected void Filter_Changed(object sender, EventArgs e)
        {
            LoadData();
        }


        // =========================================================
        // Get Value
        // =========================================================
        private DateTime GetFrom()
        {
            DateTime d;
            if (DateTime.TryParseExact((txtFrom.Text ?? "").Trim(), DateFormats,
                    CultureInfo.InvariantCulture, DateTimeStyles.None, out d)) return d.Date;
            return DateTime.Now.AddHours(-8).Date;
        }

        private DateTime GetTo()
        {
            DateTime d;
            if (DateTime.TryParseExact((txtTo.Text ?? "").Trim(), DateFormats,
                    CultureInfo.InvariantCulture, DateTimeStyles.None, out d)) return d.Date;
            return DateTime.Now.AddHours(-8).Date;
        }

        private string GetType_()
        {
            return String.IsNullOrEmpty(ddlType.SelectedValue) ? "All" : ddlType.SelectedValue;
        }


        // =========================================================
        // ข้อมูลหลัก
        //   - Completed / NG : ตามวันกะ (ShiftDate = OUTTIME - 8 ชม.)
        //                      ช่วง From 08:00 ถึง (To + 1 วัน) 08:00, SEQUENCE = 0
        //                      สูตร Completed เหมือน Power BI :
        //                      OUTQTY - SURPLUSQTY + UNKNOWQTY + DEFECTQTY - OR034 - OR038
        //   - WIP (กำลังทำอยู่) : สถานะ ณ ปัจจุบัน ไม่ขึ้นกับวันที่
        //                      Check-In แล้ว แต่ยังไม่ Check-Out
        // =========================================================
        private void LoadData()
        {
            DateTime from = GetFrom();
            DateTime to = GetTo();
            if (to < from) { DateTime t = from; from = to; to = t; }

            string sql = @"
                SELECT
                    CASE
                        WHEN T.ERP_OPID = '12' THEN '08.12'
                        WHEN T.ERP_OPID = '13' THEN '10.13'
                        ELSE T.ERP_OPID
                    END AS Code,

                    T.ERP_OPID AS OpId,
                    T.NAME AS ProcessName,

                    CASE
                        WHEN T.COMPLEXION = 1 THEN N'In-house'
                        WHEN T.COMPLEXION = 2 THEN N'Subcontract'
                        ELSE N'Other'
                    END AS ProcessType,

                    ISNULL(S.Completed, 0) AS Completed,
                    ISNULL(S.NG, 0)        AS NG,
                    ISNULL(S.Loss, 0)      AS Loss,
                    ISNULL(W.WipBatch, 0)  AS WipBatch,
                    ISNULL(W.WipQty, 0)    AS WipQty

                FROM
                (
                    SELECT DISTINCT ERP_OPID, NAME, COMPLEXION
                    FROM OPERATION
                ) T

                LEFT JOIN
                (
                    -- Completed / NG ตามช่วงวันกะ
                    SELECT
                        SOR.ERP_OPID,
                        CAST(SUM(OUTQTY - SURPLUSQTY + UNKNOWQTY + DEFECTQTY - OR034 - OR038) AS INT) AS Completed,
                        CAST(SUM(ISNULL(DEFECTQTY, 0)) AS INT) AS NG,
                        CAST(SUM(ISNULL(UNKNOWQTY, 0)) AS INT) AS Loss
                    FROM SFT_OP_REALRUN SOR
                    WHERE SOR.OUTTIME >= DATEADD(HOUR, 8, CAST(@DateFrom AS DATETIME))
                      AND SOR.OUTTIME <  DATEADD(HOUR, 8, DATEADD(DAY, 1, CAST(@DateTo AS DATETIME)))
                      AND SOR.[SEQUENCE] = 0
                    GROUP BY SOR.ERP_OPID
                ) S
                    ON T.ERP_OPID = S.ERP_OPID

                LEFT JOIN
                (
                    -- WIP ปัจจุบัน : Check-In แล้ว ยังไม่ Check-Out
                    SELECT
                        W.ERP_OPID,
                        COUNT(DISTINCT W.ID)                       AS WipBatch,
                        CAST(SUM(ISNULL(W.ARRIVEQTY, 0)) AS INT)   AS WipQty
                    FROM SFT_OP_REALRUN W
                    WHERE W.ARRIVETIME IS NOT NULL
                      AND (W.OUTTIME IS NULL OR ISNULL(W.OUTQTY, 0) = 0)
                    GROUP BY W.ERP_OPID
                ) W
                    ON T.ERP_OPID = W.ERP_OPID

                WHERE (@Type = 0 OR T.COMPLEXION = @Type)

                ORDER BY
                    CASE
                        WHEN T.ERP_OPID = '12' THEN '08.12'
                        WHEN T.ERP_OPID = '13' THEN '10.13'
                        ELSE T.ERP_OPID
                    END";

            int type = 0;
            if (GetType_() == "1") type = 1;
            else if (GetType_() == "2") type = 2;

            DataTable dt = new DataTable();

            using (SqlConnection conn = new SqlConnection(connStr))
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.CommandTimeout = 120;
                cmd.Parameters.Add("@DateFrom", SqlDbType.Date).Value = from;
                cmd.Parameters.Add("@DateTo", SqlDbType.Date).Value = to;
                cmd.Parameters.Add("@Type", SqlDbType.Int).Value = type;

                using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                {
                    da.Fill(dt);
                }
            }

            // ---------- JSON ----------
            List<object> rows = new List<object>();
            long sumDone = 0, sumNg = 0, sumLoss = 0, sumWipB = 0, sumWipQ = 0;

            foreach (DataRow r in dt.Rows)
            {
                int done = ToInt(r["Completed"]);
                int ng = ToInt(r["NG"]);
                int loss = ToInt(r["Loss"]);
                int wipB = ToInt(r["WipBatch"]);
                int wipQ = ToInt(r["WipQty"]);

                sumDone += done; sumNg += ng; sumLoss += loss; sumWipB += wipB; sumWipQ += wipQ;

                rows.Add(new
                {
                    code = Str(r["Code"]),
                    op = Str(r["OpId"]),
                    name = Str(r["ProcessName"]),
                    type = Str(r["ProcessType"]),
                    done = done,
                    ng = ng,
                    loss = loss,
                    wipB = wipB,
                    wipQ = wipQ
                });
            }

            var data = new
            {
                rows = rows,
                sumDone = sumDone,
                sumNg = sumNg,
                sumLoss = sumLoss,
                sumWipB = sumWipB,
                sumWipQ = sumWipQ,
                dateFrom = from.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture),
                dateTo = to.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture),
                // สำหรับเรียก Popup (ERP_Daily_Detail.ashx)
                qFrom = from.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                qTo = to.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                type = type,
                detailUrl = ResolveUrl("~/ERP_Daily_Detail.ashx")
            };

            JavaScriptSerializer js = new JavaScriptSerializer();
            js.MaxJsonLength = Int32.MaxValue;
            PageData = js.Serialize(data);
        }


        // =========================================================
        // Helpers
        // =========================================================
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
