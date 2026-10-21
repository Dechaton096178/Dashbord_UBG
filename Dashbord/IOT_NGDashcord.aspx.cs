using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web.Script.Serialization;
using System.Web.UI.WebControls;

namespace Dashbord
{
    public partial class IOT_NGDashcord : System.Web.UI.Page
    {
        // =========================================================
        // Connection String
        // =========================================================
        string connStr =
            ConfigurationManager
            .ConnectionStrings["EMESConnectionString"]
            .ConnectionString;

        public string ChartData = "[]";

        // =========================================================
        // [NEW] เงื่อนไข Process ใช้ในทุก query
        //   เลือก All     -> ทุก Process
        //   เลือก Process -> เฉพาะรหัสนั้น (MW001)
        // =========================================================
        // [NEW] Ball Model ที่ไม่ต้องแสดงในรายการ (เพิ่มได้ เช่น "'A','B'")
        const string HiddenBallModels = "'Core Yellow PVC White'";

        const string ProcessFilter = "(@ERP_OPID = 'All' OR A.ERP_OPID = @ERP_OPID)";


        // =========================================================
        // Page Load
        // =========================================================
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                // Start Date ย้อนหลัง 7 วัน, End Date = วันนี้
                // (เก็บเป็น yyyy-MM-dd ส่วนหน้าจอแสดง dd/mm/yyyy ด้วย flatpickr)
                txtFrom.Text = DateTime.Now.AddDays(-7).ToString("yyyy-MM-dd");
                txtTo.Text = DateTime.Now.ToString("yyyy-MM-dd");

                LoadProcess();      // [NEW] Process จาก CMSMW
                LoadMachine();
                LoadBallModel();
                LoadReason();
                LoadDashboard();
            }
        }


        // =========================================================
        // Events
        // =========================================================
        protected void ddlProcess_SelectedIndexChanged(object sender, EventArgs e)
        {
            LoadMachine();
            LoadBallModel();
            LoadReason();
            LoadDashboard();
        }

        protected void ddlMachine_SelectedIndexChanged(object sender, EventArgs e)
        {
            LoadBallModel();
            LoadReason();
            LoadDashboard();
        }

        protected void Filter_Changed(object sender, EventArgs e)
        {
            LoadDashboard();
        }

        // ปุ่ม Search / เปลี่ยนวันที่
        protected void btnSearch_Click(object sender, EventArgs e)
        {
            LoadBallModel();
            LoadReason();
            LoadDashboard();
        }


        // =========================================================
        // Get Value
        // =========================================================
        private DateTime GetStartDate()
        {
            DateTime result;
            if (DateTime.TryParse(txtFrom.Text, out result)) return result.Date;
            return DateTime.Today;
        }

        private DateTime GetEndDate()
        {
            DateTime result;
            if (DateTime.TryParse(txtTo.Text, out result)) return result.Date;
            return DateTime.Today;
        }

        private string GetMachine()
        {
            if (String.IsNullOrEmpty(ddlMachine.SelectedValue)) return "All";
            return ddlMachine.SelectedValue.Trim();
        }

        private string GetRoutingCode()
        {
            // [CHANGED] รหัส Process (MW001) ที่เลือก หรือ "All"
            if (String.IsNullOrEmpty(ddlProcess.SelectedValue)) return "All";
            return ddlProcess.SelectedValue.Trim();
        }

        private string GetBallModel()
        {
            if (ddlBall.SelectedValue == null) return "All";
            return ddlBall.SelectedValue.Trim();
        }

        private string GetReason()
        {
            if (ddlReason.SelectedValue == null) return "All";
            return ddlReason.SelectedValue.Trim();
        }


        // =========================================================
        // Load Dashboard ทั้งหมด
        // =========================================================
        private void LoadDashboard()
        {
            LoadInjectionCount();
            LoadDefectCount();
            LoadDefectTotalCount();
            LoadDefectAGVCount();
            Yield();
            LoadChartData();
            lblMatrixMachine.Text = GetMachine();   // "All" = ทุกเครื่อง
        }


        // =========================================================
        // [NEW] Load Process  (UNIVERSAL.dbo.CMSMW)
        //   Text  = MW002 (ชื่อ Process)
        //   Value = MW001 (รหัส = ERP_OPID ใน SFT_OP_REALRUN)
        //   แสดงทุก Process + All อยู่บนสุด
        //   ค่าเริ่มต้น = All
        // =========================================================
        private void LoadProcess()
        {
            string sql = @"
                SELECT DISTINCT
                    LTRIM(RTRIM(B.MW001)) AS MW001,
                    LTRIM(RTRIM(B.MW002)) AS MW002
                FROM UNIVERSAL.dbo.CMSMW B
                WHERE B.MW002 IS NOT NULL
                  AND LTRIM(RTRIM(B.MW002)) <> ''
                ORDER BY MW001";

            string oldValue = ddlProcess.SelectedValue;

            ddlProcess.Items.Clear();
            ddlProcess.Items.Add(new ListItem("All", "All"));   // [NEW] All อยู่บนสุด

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    conn.Open();

                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            string code = dr["MW001"].ToString();
                            string name = dr["MW002"].ToString();

                            if (!String.IsNullOrEmpty(code))
                            {
                                ddlProcess.Items.Add(new ListItem(name, code));
                            }
                        }
                    }
                }
            }

            // คงค่าที่เคยเลือก ถ้าไม่มีให้เป็น All
            if (!String.IsNullOrEmpty(oldValue) && ddlProcess.Items.FindByValue(oldValue) != null)
                ddlProcess.SelectedValue = oldValue;
            else
                ddlProcess.SelectedValue = "All";
        }


        // =========================================================
        // Load Reason
        // =========================================================
        private void LoadReason()
        {
            string sql = @"
                SELECT DISTINCT
                    E.EXCEPTREASON
                FROM SFT_OP_REALRUN A

                LEFT JOIN SFT_OP_EXCEPT E
                    ON A.ID = E.ID
                    AND A.ERP_OPID = E.ERP_OPID
                    AND E.EXCEPTTYPE = 'defect'

                LEFT JOIN MODETAIL M
                    ON A.ID = M.CMOID

                WHERE " + ProcessFilter + @"
                  AND E.EXCEPTREASON IS NOT NULL
                  AND E.EXCEPTREASON <> ''

                ORDER BY E.EXCEPTREASON";

            ddlReason.Items.Clear();
            ddlReason.Items.Add(new ListItem("All", "All"));

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.Add("@ERP_OPID", SqlDbType.VarChar).Value = GetRoutingCode();
                    conn.Open();

                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            string reason = dr["EXCEPTREASON"].ToString();

                            if (!String.IsNullOrEmpty(reason))
                            {
                                ddlReason.Items.Add(new ListItem(reason, reason));
                            }
                        }
                    }
                }
            }

            ddlReason.SelectedValue = "All";
        }


        // =========================================================
        // Load Machine
        // =========================================================
        private void LoadMachine()
        {
            string sql = @"
                SELECT DISTINCT
                    A.EQID
                FROM SFT_OP_REALRUN A
                WHERE A.EQID IS NOT NULL
                  AND A.EQID <> '' AND " + ProcessFilter + @"
                ORDER BY A.EQID";

            string oldValue = GetMachine();

            ddlMachine.Items.Clear();
            ddlMachine.Items.Add(new ListItem("All", "All"));   // [NEW] ตัวเลือก All อยู่บนสุด

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.Add("@ERP_OPID", SqlDbType.VarChar).Value = GetRoutingCode();
                    conn.Open();

                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            string machine = dr["EQID"].ToString();
                            ddlMachine.Items.Add(new ListItem(machine, machine));
                        }
                    }
                }
            }

            // [CHANGED] ค่าเริ่มต้น = All (ถ้าเคยเลือกเครื่องไว้ ให้คงค่าเดิม)
            ListItem item = String.IsNullOrEmpty(oldValue) ? null : ddlMachine.Items.FindByValue(oldValue);
            ddlMachine.SelectedValue = (item != null) ? oldValue : "All";
        }


        // =========================================================
        // Load Ball Model
        // =========================================================
        private void LoadBallModel()
        {
            string sql = @"
                SELECT DISTINCT
                    M.MO022 AS Ball_Model
                FROM SFT_OP_REALRUN A

                LEFT JOIN MODETAIL M
                    ON A.ID = M.CMOID

                WHERE M.MO022 IS NOT NULL
                  AND M.MO022 <> ''
                  AND LTRIM(RTRIM(M.MO022)) NOT IN (" + HiddenBallModels + @")   -- [NEW] ซ่อนบางรุ่น

                ORDER BY M.MO022";

            string oldValue = ddlBall.SelectedValue;

            ddlBall.Items.Clear();
            ddlBall.Items.Add(new ListItem("All", "All"));

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    conn.Open();

                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            string ballModel = dr["Ball_Model"].ToString();

                            if (!String.IsNullOrEmpty(ballModel))
                            {
                                ddlBall.Items.Add(new ListItem(ballModel, ballModel));
                            }
                        }
                    }
                }
            }

            if (!String.IsNullOrEmpty(oldValue))
            {
                ListItem item = ddlBall.Items.FindByValue(oldValue);

                if (item != null) ddlBall.SelectedValue = oldValue;
                else ddlBall.SelectedValue = "All";
            }
            else
            {
                ddlBall.SelectedValue = "All";
            }
        }


        // =========================================================
        // Total Inspections
        // =========================================================
        private void LoadInjectionCount()
        {
            string sql = @"
                SELECT
                    COUNT(DISTINCT A.ID)

                FROM SFT_OP_REALRUN A

                LEFT JOIN UNIVERSAL.dbo.CMSMW B
                    ON A.ERP_OPID = B.MW001

                LEFT JOIN SFT_OP_EXCEPT E
                    ON A.ID = E.ID
                    AND A.ERP_OPID = E.ERP_OPID
                    AND E.EXCEPTTYPE = 'defect'

                LEFT JOIN MODETAIL M
                    ON A.ID = M.CMOID

                WHERE
                    CONVERT(DATE, A.OUTTIME) BETWEEN @StartDate AND @EndDate
                    AND (@EQID = 'All' OR A.EQID = @EQID)   -- [CHANGED] รองรับ All
                    AND " + ProcessFilter;

            // [FIXED] เดิมไม่กรอง Ball Model / NG Reason -> Total Inspections ไม่เปลี่ยนตาม filter
            if (GetBallModel() != "All")
            {
                sql += @"
                    AND M.MO022 = @BallModel";
            }

            if (GetReason() != "All")
            {
                sql += @"
                    AND E.EXCEPTREASON = @Reason";
            }

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.Add("@StartDate", SqlDbType.DateTime).Value = GetStartDate();
                    cmd.Parameters.Add("@EndDate", SqlDbType.DateTime).Value = GetEndDate();
                    cmd.Parameters.Add("@EQID", SqlDbType.VarChar).Value = GetMachine();
                    cmd.Parameters.Add("@ERP_OPID", SqlDbType.VarChar).Value = GetRoutingCode();

                    if (GetBallModel() != "All")
                    {
                        cmd.Parameters.Add("@BallModel", SqlDbType.VarChar).Value = GetBallModel();
                    }

                    if (GetReason() != "All")
                    {
                        cmd.Parameters.Add("@Reason", SqlDbType.NVarChar).Value = GetReason();
                    }

                    conn.Open();

                    object result = cmd.ExecuteScalar();

                    if (result == null || result == DBNull.Value)
                        lblInsp.Text = "0";
                    else
                        lblInsp.Text = Convert.ToInt32(result).ToString();
                }
            }
        }


        // =========================================================
        // Total Defect
        // [FIXED] เพิ่ม LEFT JOIN MODETAIL M
        //         เดิมไม่มี JOIN แต่ใช้ M.MO022 -> SQL Error ตอนเลือก Ball Model
        // =========================================================
        private void LoadDefectCount()
        {
            string sql = @"
                SELECT
                    SUM(CAST(E.EXCEPTQTY AS INT)) AS [Defect_QTY]

                FROM SFT_OP_REALRUN A

                INNER JOIN SFT_OP_EXCEPT E
                    ON A.ID = E.ID
                    AND A.ERP_OPID = E.ERP_OPID
                    AND E.EXCEPTTYPE = 'defect'

                LEFT JOIN MODETAIL M
                    ON A.ID = M.CMOID

                WHERE
                    CONVERT(DATE, A.OUTTIME) BETWEEN @StartDate AND @EndDate
                    AND (@EQID = 'All' OR A.EQID = @EQID)
                    -- [FIXED] 1 MO มี 2 แถวใน SFT_OP_REALRUN : แถว EQID ว่าง (Check-In) + แถวเครื่อง (Check-Out)
                    --         defect ถูก JOIN เข้าทั้ง 2 แถว -> ยอดเป็น 2 เท่า (36.22K แทน 18.11K)
                    --         นับ defect เฉพาะแถวที่มีเครื่อง
                    AND A.EQID IS NOT NULL AND A.EQID <> ''
                    AND " + ProcessFilter;

            if (GetBallModel() != "All")
            {
                sql += @"
                    AND M.MO022 = @BallModel";
            }

            if (GetReason() != "All")
            {
                sql += @"
                    AND E.EXCEPTREASON = @Reason";
            }

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.Add("@StartDate", SqlDbType.DateTime).Value = GetStartDate();
                    cmd.Parameters.Add("@EndDate", SqlDbType.DateTime).Value = GetEndDate();
                    cmd.Parameters.Add("@EQID", SqlDbType.VarChar).Value = GetMachine();
                    cmd.Parameters.Add("@ERP_OPID", SqlDbType.VarChar).Value = GetRoutingCode();

                    if (GetBallModel() != "All")
                    {
                        cmd.Parameters.Add("@BallModel", SqlDbType.VarChar).Value = GetBallModel();
                    }

                    if (GetReason() != "All")
                    {
                        cmd.Parameters.Add("@Reason", SqlDbType.NVarChar).Value = GetReason();
                    }

                    conn.Open();

                    object result = cmd.ExecuteScalar();

                    decimal totalDefect = 0;

                    if (result != null && result != DBNull.Value)
                    {
                        totalDefect = Convert.ToDecimal(result);
                    }

                    // ส่งเป็นตัวเลขดิบ (เช่น 2480.00) หน้าเว็บจะแปลงเป็น 2.48K เอง
                    lblDefect.Text = totalDefect.ToString("0.00");
                }
            }
        }


        // =========================================================
        // Total Count
        // =========================================================
        private void LoadDefectTotalCount()
        {
            string sql = @"
                SELECT
                    SUM(X.Check_In_QTY) AS [Total Count]
                FROM
                (
                    SELECT
                        A.ID AS [Mo],
                        MAX(A.ARRIVEQTY) AS [Check_In_QTY],
                        MAX(A.ALERADYDEFECTQTY) AS [Total_NG]

                    FROM SFT_OP_REALRUN A

                    LEFT JOIN SFT_OP_EXCEPT E
                        ON A.ID = E.ID
                        AND A.ERP_OPID = E.ERP_OPID
                        AND E.EXCEPTTYPE = 'defect'

                    LEFT JOIN MODETAIL M
                        ON A.ID = M.CMOID

                    WHERE A.OUTTIME >= @StartDate
                      AND A.OUTTIME < DATEADD(DAY, 1, @EndDate)
                      AND (@EQID = 'All'
                           OR A.ID IN (SELECT R.ID FROM SFT_OP_REALRUN R
                                       WHERE R.EQID = @EQID AND R.ERP_OPID = A.ERP_OPID))
                      -- [FIXED] Check-In QTY อยู่ในแถวที่ EQID ว่าง ถ้ากรอง A.EQID = เครื่อง ตรง ๆ
                      --         Total Count จะเป็น 0 -> เลือก MO ที่ผ่านเครื่องนั้น แล้วใช้ทุกแถวของ MO
                      AND " + ProcessFilter;

            if (GetBallModel() != "All")
            {
                sql += @"
                      AND M.MO022 = @BallModel";
            }

            if (GetReason() != "All")
            {
                sql += @"
                      AND E.EXCEPTREASON = @Reason";
            }

            sql += @"
                    GROUP BY A.ID
                ) X";

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.Add("@StartDate", SqlDbType.DateTime).Value = GetStartDate();
                    cmd.Parameters.Add("@EndDate", SqlDbType.DateTime).Value = GetEndDate();
                    cmd.Parameters.Add("@EQID", SqlDbType.VarChar).Value = GetMachine();
                    cmd.Parameters.Add("@ERP_OPID", SqlDbType.VarChar).Value = GetRoutingCode();

                    if (GetBallModel() != "All")
                    {
                        cmd.Parameters.Add("@BallModel", SqlDbType.VarChar).Value = GetBallModel();
                    }

                    if (GetReason() != "All")
                    {
                        cmd.Parameters.Add("@Reason", SqlDbType.NVarChar).Value = GetReason();
                    }

                    conn.Open();

                    object result = cmd.ExecuteScalar();

                    decimal totalCount = 0;

                    if (result != null && result != DBNull.Value)
                    {
                        totalCount = Convert.ToDecimal(result);
                    }

                    lblCount.Text = totalCount.ToString("0.00");
                }
            }
        }


        // =========================================================
        // Defect %
        // =========================================================
        private void LoadDefectAGVCount()
        {
            decimal totalDefect = 0;
            decimal totalCount = 0;

            Decimal.TryParse(lblDefect.Text, out totalDefect);
            Decimal.TryParse(lblCount.Text, out totalCount);

            decimal defectPct = 0;

            if (totalCount > 0)
            {
                defectPct = totalDefect * 100 / totalCount;
            }

            lblDefPct.Text = defectPct.ToString("0.00") + "%";

            decimal yield = 100 - defectPct;
            if (yield < 0) yield = 0;

            lblYield.Text = yield.ToString("0.00") + "%";
        }

        private void Yield()
        {
            decimal defect = 0;
            decimal count = 0;

            Decimal.TryParse(lblDefect.Text, out defect);
            Decimal.TryParse(lblCount.Text, out count);

            decimal yield = 0;

            if (count > 0)
            {
                yield = (1 - (defect / count)) * 100;
            }

            lblYield.Text = yield.ToString("0.00") + "%";
        }


        // =========================================================
        // Chart Data -> JSON (หน้าเว็บอ่านผ่าน <%= ChartData %>)
        // =========================================================
        private void LoadChartData()
        {
            // [CHANGED] รวมยอด (GROUP BY) ใน SQL ส่งเฉพาะ field ที่กราฟ/Matrix ใช้
            //           เดิมส่งทุกแถวดิบ -> เลือก All แล้ว JSON ใหญ่มากจน
            //           "Maximum request length exceeded" ตอน postback
            string sql = @"
                SELECT
                    X.Machine,
                    X.Ball_Model,
                    X.Defect_Reason,
                    SUM(X.Defect_QTY) AS Defect_QTY,
                    X.CheckOut_Date,
                    X.Hour_Num,
                    X.CheckOut_Hour,
                    X.Month_Group,
                    X.Week_Group
                FROM
                (
                    SELECT
                        A.EQID AS Machine,
                        M.MO022 AS Ball_Model,
                        E.EXCEPTREASON AS Defect_Reason,
                        CAST(E.EXCEPTQTY AS DECIMAL(18,2)) AS Defect_QTY,
                        CONVERT(varchar(10), A.OUTTIME, 23) AS CheckOut_Date,
                        DATEPART(HOUR, A.OUTTIME) AS Hour_Num,
                        FORMAT(A.OUTTIME, 'h tt', 'en-US') AS CheckOut_Hour,
                        FORMAT(A.OUTTIME, 'yyyy-MM') AS Month_Group,
                        'WK ' + FORMAT(DATEADD(wk, DATEDIFF(wk, 0, A.OUTTIME), 0), 'yyyy MM/dd') AS Week_Group

                    FROM SFT_OP_REALRUN A

                    INNER JOIN SFT_OP_EXCEPT E
                        ON A.ID = E.ID
                        AND A.ERP_OPID = E.ERP_OPID
                        AND E.EXCEPTTYPE = 'defect'

                    LEFT JOIN MODETAIL M
                        ON A.ID = M.CMOID

                    WHERE A.OUTTIME >= @StartDate
                      AND A.OUTTIME < DATEADD(DAY, 1, @EndDate)
                      AND (@EQID = 'All' OR A.EQID = @EQID)
                      -- [FIXED] 1 MO มี 2 แถวใน SFT_OP_REALRUN : แถว EQID ว่าง (Check-In) + แถวเครื่อง (Check-Out)
                      --         defect ถูก JOIN เข้าทั้ง 2 แถว -> ยอดเป็น 2 เท่า (36.22K แทน 18.11K)
                      --         นับ defect เฉพาะแถวที่มีเครื่อง
                      AND A.EQID IS NOT NULL AND A.EQID <> ''
                      AND " + ProcessFilter + @"
                      AND E.EXCEPTREASON IS NOT NULL";

            if (GetBallModel() != "All")
            {
                sql += @"
                      AND M.MO022 = @BallModel";
            }

            if (GetReason() != "All")
            {
                sql += @"
                      AND E.EXCEPTREASON = @Reason";
            }

            sql += @"
                ) X
                GROUP BY X.Machine, X.Ball_Model, X.Defect_Reason,
                         X.CheckOut_Date, X.Hour_Num, X.CheckOut_Hour,
                         X.Month_Group, X.Week_Group
                ORDER BY X.CheckOut_Date, X.Hour_Num, X.Defect_Reason";

            DataTable dt = new DataTable();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.Add("@StartDate", SqlDbType.DateTime).Value = GetStartDate();
                    cmd.Parameters.Add("@EndDate", SqlDbType.DateTime).Value = GetEndDate();
                    cmd.Parameters.Add("@EQID", SqlDbType.VarChar).Value = GetMachine();
                    cmd.Parameters.Add("@ERP_OPID", SqlDbType.VarChar).Value = GetRoutingCode();

                    if (GetBallModel() != "All")
                    {
                        cmd.Parameters.Add("@BallModel", SqlDbType.VarChar).Value = GetBallModel();
                    }

                    if (GetReason() != "All")
                    {
                        cmd.Parameters.Add("@Reason", SqlDbType.NVarChar).Value = GetReason();
                    }

                    conn.Open();

                    using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                    {
                        da.Fill(dt);
                    }
                }
            }

            List<Dictionary<string, object>> rows = new List<Dictionary<string, object>>();

            foreach (DataRow dr in dt.Rows)
            {
                Dictionary<string, object> row = new Dictionary<string, object>();

                foreach (DataColumn col in dt.Columns)
                {
                    row[col.ColumnName] = dr[col] == DBNull.Value ? null : dr[col];
                }

                rows.Add(row);
            }

            JavaScriptSerializer serializer = new JavaScriptSerializer();
            serializer.MaxJsonLength = Int32.MaxValue;

            // [CHANGED] ไม่ใส่ HiddenField แล้ว (HiddenField ถูกส่งกลับทุก postback)
            //           หน้า .aspx อ่านจาก <%= ChartData %> โดยตรง
            ChartData = serializer.Serialize(rows);
        }
    }
}
