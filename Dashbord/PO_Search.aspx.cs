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
    public partial class PO_Search : System.Web.UI.Page
    {
        // =========================================================
        // Connection String (ฐานเดียวกับ NG Dashboard : EMES_UNIVERSAL)
        // =========================================================
        string connStr =
            ConfigurationManager
            .ConnectionStrings["EMESConnectionString"]
            .ConnectionString;

        // JSON ส่งให้หน้าเว็บ (อ่านผ่าน <%= PageData %>)
        public string PageData = "{}";

        // แสดงในตารางได้สูงสุดกี่แถว (กันหน้าเว็บหนักเกิน)
        const int MaxRows = 5000;


        // =========================================================
        // Page Load
        // =========================================================
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                SetDefaultDates();
                LoadProcess();
                LoadData();
            }
        }


        // =========================================================
        // Events
        // =========================================================
        protected void btnSearch_Click(object sender, EventArgs e)
        {
            LoadData();
        }

        protected void Filter_Changed(object sender, EventArgs e)
        {
            LoadData();
        }

        protected void btnClear_Click(object sender, EventArgs e)
        {
            txtPO.Text = "";
            txtBatch.Text = "";
            SetDefaultDates();
            ddlProcess.SelectedValue = "All";
            chkAllSteps.Checked = false;
            LoadData();
        }


        // =========================================================
        // Get Value
        // =========================================================
        // [NEW] ค่าเริ่มต้น : ย้อนหลัง 2 เดือน ถึง วันนี้ (เก็บเป็น yyyy-MM-dd)
        private void SetDefaultDates()
        {
            txtFrom.Text = DateTime.Today.AddMonths(-2).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            txtTo.Text = DateTime.Today.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        }

        // [FIXED] รับได้ทั้ง yyyy-MM-dd (จากปฏิทิน) และ dd/MM/yyyy (กรณีพิมพ์เอง / ปฏิทินโหลดไม่ขึ้น)
        static readonly string[] DateFormats =
        {
            "yyyy-MM-dd", "dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "yyyy/MM/dd"
        };

        private DateTime GetFrom()
        {
            DateTime d;
            if (DateTime.TryParseExact((txtFrom.Text ?? "").Trim(), DateFormats, CultureInfo.InvariantCulture, DateTimeStyles.None, out d)) return d.Date;
            return DateTime.Today.AddMonths(-2);
        }

        private DateTime GetTo()
        {
            DateTime d;
            if (DateTime.TryParseExact((txtTo.Text ?? "").Trim(), DateFormats, CultureInfo.InvariantCulture, DateTimeStyles.None, out d)) return d.Date;
            return DateTime.Today;
        }

        private string GetPO()
        {
            return (txtPO.Text ?? "").Trim();
        }

        private string GetBatch()
        {
            return (txtBatch.Text ?? "").Trim();
        }

        private string GetProcess()
        {
            if (String.IsNullOrEmpty(ddlProcess.SelectedValue)) return "All";
            return ddlProcess.SelectedValue.Trim();
        }


        // =========================================================
        // Process (UNIVERSAL.dbo.CMSMW)  — เรียงตามรหัส MW001
        // =========================================================
        private void LoadProcess()
        {
            string sql = @"
                SELECT
                    MIN(LTRIM(RTRIM(MW001))) AS MW001,
                    LTRIM(RTRIM(MW002))      AS MW002
                FROM UNIVERSAL.dbo.CMSMW
                WHERE MW002 IS NOT NULL
                  AND LTRIM(RTRIM(MW002)) <> ''
                GROUP BY LTRIM(RTRIM(MW002))
                ORDER BY MIN(LTRIM(RTRIM(MW001)))";

            ddlProcess.Items.Clear();
            ddlProcess.Items.Add(new ListItem("All", "All"));

            using (SqlConnection conn = new SqlConnection(connStr))
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                conn.Open();
                using (SqlDataReader dr = cmd.ExecuteReader())
                {
                    while (dr.Read())
                    {
                        string name = dr["MW002"].ToString();
                        ddlProcess.Items.Add(new ListItem(name, name));
                    }
                }
            }

            ddlProcess.SelectedValue = "All";
        }


        // =========================================================
        // รายการ PO สำหรับช่องค้นหา (autocomplete) — ตามช่วงวันที่ที่เลือก
        // =========================================================
        public string POListJson = "[]";

        private void LoadPOList()
        {
            string sql = @"
                SELECT DISTINCT P.PO_Number
                FROM SFT_OP_REALRUN A
                LEFT JOIN MODETAIL M ON A.ID = M.CMOID
                CROSS APPLY (SELECT " + PoExpr + @" AS PO_Number) P
                WHERE A.ARRIVETIME >= @From
                  AND A.ARRIVETIME < DATEADD(DAY, 1, @To)
                ORDER BY P.PO_Number";

            List<string> list = new List<string>();

            using (SqlConnection conn = new SqlConnection(connStr))
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.Add("@From", SqlDbType.DateTime).Value = GetFrom();
                cmd.Parameters.Add("@To", SqlDbType.DateTime).Value = GetTo();
                conn.Open();
                using (SqlDataReader dr = cmd.ExecuteReader())
                {
                    while (dr.Read()) list.Add(dr["PO_Number"].ToString());
                }
            }

            POListJson = new JavaScriptSerializer().Serialize(list);
        }


        // =========================================================
        // สูตร PO_Number (ใช้ร่วมกันทุก query)
        // =========================================================
        const string PoExpr = @"
            CASE
                WHEN A.ID LIKE '5101-20260608001%' THEN 'PO:4500762127'
                WHEN A.ID LIKE '5101-2026062202%'  THEN 'PO:4500762994'
                WHEN M.DESCRIPTION IS NULL
                     OR LTRIM(RTRIM(M.DESCRIPTION)) = '' THEN 'No PO'
                ELSE LTRIM(RTRIM(M.DESCRIPTION))
            END";


        // =========================================================
        // ข้อมูลหลัก
        //   - กรอง PO / Batch ภายใน subquery (ไม่กระทบ RowNum เพราะแบ่งตาม MO)
        //   - ค้นหา PO / Batch แบบ "มีคำนี้อยู่" (LIKE %...%)
        //   - [CHANGED] ช่วงวันที่ From/To : เลือก Batch ที่มี Check-In ในช่วงนั้น
        //               แล้วดึง "ทุกขั้นตอน" ของ Batch นั้น (RowNum / สถานะล่าสุดจึงถูกต้อง)
        //   - Process / แสดงทุกขั้นตอน กรองใน C# (ไม่ต้อง query ซ้ำ)
        // =========================================================
        private void LoadData()
        {
            LoadPOList();   // รายการ PO (autocomplete) ตามช่วงวันที่

            string sql = @"
                SELECT
                    PO_Number,
                    Batch_MO,
                    Ball_Model,
                    Routing_Code,
                    Routing_Name,
                    Line,
                    CheckIn_QTY,
                    CheckIn_Time,
                    CheckOut_QTY,
                    CheckOut_Time,
                    Total_NG,
                    Total_Loss,
                    Job_Status,
                    RowNum,

                    CASE
                        WHEN Batch_MO LIKE '5105%'
                             AND Routing_Name = 'Glebar'
                             AND Job_Status = 'Completed'           THEN 'History'
                        WHEN RowNum = 1
                             AND Routing_Name = 'Packing'
                             AND Job_Status = 'Completed'           THEN 'Finished'
                        WHEN RowNum = 1 AND Job_Status = 'Completed' THEN 'Resting'
                        WHEN RowNum = 1 AND Job_Status = 'WIP'       THEN 'WIP'
                        ELSE 'History'
                    END AS Realtime_Status

                FROM
                (
                    SELECT
                        P.PO_Number,
                        A.ID                               AS Batch_MO,
                        M.MO022                            AS Ball_Model,
                        A.ERP_OPID                         AS Routing_Code,
                        LTRIM(RTRIM(B.MW002))              AS Routing_Name,
                        A.ERP_WSID                         AS Line,
                        CAST(A.ARRIVEQTY AS INT)           AS CheckIn_QTY,
                        A.ARRIVETIME                       AS CheckIn_Time,
                        CAST(A.OUTQTY AS INT)              AS CheckOut_QTY,
                        A.OUTTIME                          AS CheckOut_Time,
                        CAST(A.ALERADYDEFECTQTY AS INT)    AS Total_NG,
                        CAST(A.UNKNOWQTY AS INT)           AS Total_Loss,

                        CASE
                            WHEN A.OUTTIME IS NULL
                                 OR A.OUTQTY IS NULL
                                 OR CAST(A.OUTQTY AS INT) = 0 THEN 'WIP'
                            ELSE 'Completed'
                        END AS Job_Status,

                        ROW_NUMBER() OVER
                        (
                            PARTITION BY A.ID
                            ORDER BY A.ARRIVETIME DESC
                        ) AS RowNum

                    FROM SFT_OP_REALRUN A

                    LEFT JOIN MODETAIL M
                        ON A.ID = M.CMOID

                    LEFT JOIN UNIVERSAL.dbo.CMSMW B
                        ON A.ERP_OPID = B.MW001

                    CROSS APPLY (SELECT " + PoExpr + @" AS PO_Number) P

                    WHERE A.ARRIVETIME IS NOT NULL
                      AND A.ID IN
                      (
                          SELECT R.ID
                          FROM SFT_OP_REALRUN R
                          WHERE R.ARRIVETIME >= @From
                            AND R.ARRIVETIME < DATEADD(DAY, 1, @To)
                      )
                      AND (@PO = ''    OR P.PO_Number LIKE '%' + @PO + '%')
                      AND (@Batch = '' OR A.ID LIKE '%' + @Batch + '%')
                ) AS BaseData

                ORDER BY Batch_MO, CheckIn_Time";

            DataTable dt = new DataTable();

            using (SqlConnection conn = new SqlConnection(connStr))
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.CommandTimeout = 120;
                cmd.Parameters.Add("@From", SqlDbType.DateTime).Value = GetFrom();
                cmd.Parameters.Add("@To", SqlDbType.DateTime).Value = GetTo();
                cmd.Parameters.Add("@PO", SqlDbType.NVarChar, 100).Value = GetPO();
                cmd.Parameters.Add("@Batch", SqlDbType.NVarChar, 100).Value = GetBatch();

                using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                {
                    da.Fill(dt);
                }
            }

            BuildPageData(dt);
        }


        // =========================================================
        // สรุป KPI + ตาราง -> JSON
        // =========================================================
        private void BuildPageData(DataTable dt)
        {
            string process = GetProcess();
            bool allSteps = chkAllSteps.Checked;

            // ---------- KPI : ใช้สถานะล่าสุดของแต่ละ Batch (RowNum = 1) ----------
            HashSet<string> batches = new HashSet<string>();
            Dictionary<string, int[]> inProcess = new Dictionary<string, int[]>(); // [WIP, Resting]
            int finish = 0;

            // [NEW] ใช้เฉพาะแถวที่ Check-In อยู่ในช่วงวันที่ที่เลือก
            //       (RowNum / สถานะล่าสุด ยังคำนวณจากทุกขั้นตอนของ Batch จึงถูกต้อง)
            DateTime from = GetFrom();
            DateTime toExcl = GetTo().AddDays(1);

            List<DataRow> inRange = new List<DataRow>();
            foreach (DataRow r in dt.Rows)
            {
                if (r["CheckIn_Time"] == DBNull.Value) continue;
                DateTime t = Convert.ToDateTime(r["CheckIn_Time"]);
                if (t >= from && t < toExcl) inRange.Add(r);
            }

            foreach (DataRow r in inRange)
            {
                batches.Add(Str(r["Batch_MO"]));

                if (ToLong(r["RowNum"]) != 1) continue;

                string status = Str(r["Realtime_Status"]);
                string proc = Str(r["Routing_Name"]);

                if (status == "Finished" || status == "History")
                {
                    finish++;
                }
                else
                {
                    if (!inProcess.ContainsKey(proc)) inProcess[proc] = new int[2];
                    if (status == "WIP") inProcess[proc][0]++;
                    else inProcess[proc][1]++;
                }
            }

            List<object> tiles = new List<object>();
            foreach (ListItem li in ddlProcess.Items)
            {
                if (li.Value == "All") continue;
                int[] c = inProcess.ContainsKey(li.Value) ? inProcess[li.Value] : new int[2];
                tiles.Add(new { name = li.Value, wip = c[0], rest = c[1] });
            }

            // ---------- ตาราง ----------
            List<object> rows = new List<object>();
            long sumIn = 0, sumOut = 0, sumNg = 0;
            int matched = 0;

            foreach (DataRow r in inRange)
            {
                if (!allSteps && ToLong(r["RowNum"]) != 1) continue;
                if (process != "All" && Str(r["Routing_Name"]) != process) continue;

                matched++;
                int qIn = ToInt(r["CheckIn_QTY"]);
                int qOut = ToInt(r["CheckOut_QTY"]);
                int ng = ToInt(r["Total_NG"]);
                sumIn += qIn; sumOut += qOut; sumNg += ng;

                if (rows.Count >= MaxRows) continue;

                rows.Add(new
                {
                    po = Str(r["PO_Number"]),
                    st = Str(r["Realtime_Status"]),
                    qin = qIn,
                    tin = Dt(r["CheckIn_Time"]),
                    tinK = DtKey(r["CheckIn_Time"]),
                    tout = Dt(r["CheckOut_Time"]),
                    toutK = DtKey(r["CheckOut_Time"]),
                    mo = Str(r["Batch_MO"]),
                    ball = Str(r["Ball_Model"]),
                    proc = Str(r["Routing_Name"]),
                    line = Str(r["Line"]),
                    qout = qOut,
                    ng = ng
                });
            }

            var data = new
            {
                batchCount = batches.Count,
                finish = finish,
                tiles = tiles,
                rows = rows,
                matched = matched,
                maxRows = MaxRows,
                sumIn = sumIn,
                sumOut = sumOut,
                sumNg = sumNg,
                process = process,
                dateFrom = from.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture),
                dateTo = GetTo().ToString("dd/MM/yyyy", CultureInfo.InvariantCulture),
                allSteps = allSteps
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

        private static long ToLong(object v)
        {
            return v == null || v == DBNull.Value ? 0 : Convert.ToInt64(v);
        }

        // dd/MM/yyyy HH:mm:ss (ใช้ InvariantCulture กันปีเป็น พ.ศ.)
        private static string Dt(object v)
        {
            if (v == null || v == DBNull.Value) return "";
            return Convert.ToDateTime(v).ToString("dd/MM/yyyy HH:mm:ss", CultureInfo.InvariantCulture);
        }

        // key สำหรับเรียงตามเวลา
        private static string DtKey(object v)
        {
            if (v == null || v == DBNull.Value) return "";
            return Convert.ToDateTime(v).ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture);
        }
    }
}
