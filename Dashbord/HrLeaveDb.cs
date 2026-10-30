using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Globalization;
using System.Linq;
using System.Web.Script.Serialization;

namespace Dashbord
{
    /// <summary>
    /// ใบลา + ใบขอ OT : ตารางใน MySQL OEE (สร้างเองอัตโนมัติ)
    ///   hr_leave        ใบลา 1 ใบ = 1 แถว (UBG-FM-HR-09)
    ///   hr_leave_quota  สิทธิ์วันลาที่ HR แก้รายคน (ไม่มีแถว = ใช้ค่าตั้งต้นจาก leave_config)
    ///   hr_ot / hr_ot_line  ใบขอ OT (UBG-FM-HR-07) : หัวใบ + รายชื่อคน
    ///   ช่องเซ็น : sup_* = หัวหน้า · appr_* = ผู้อนุมัติ · hr_* = ฝ่ายบุคคล
    /// </summary>
    public static partial class OeeDb
    {
        static bool _lvTables;

        static DbConnection LvOpen()
        {
            DbConnection c = TaOpen();
            if (_lvTables) return c;
            try
            {
                const string SIGN = @"
                                  sup_by      VARCHAR(40)  NULL, sup_at  DATETIME NULL,
                                  appr_by     VARCHAR(40)  NULL, appr_at DATETIME NULL,
                                  hr_by       VARCHAR(40)  NULL, hr_at   DATETIME NULL,
                                  reject_by   VARCHAR(40)  NULL, reject_at DATETIME NULL, reject_note VARCHAR(300) NULL,
                                  paper       TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '1 = เซ็นบนกระดาษแล้ว HR บันทึกเข้าระบบ',
                                  status      VARCHAR(12)  NOT NULL DEFAULT 'pending' COMMENT 'pending / approved / rejected / cancelled',
                                  created_by  VARCHAR(40)  NULL, created_at DATETIME NULL, updated_at DATETIME NULL,";
                Cmd(c, null, @"CREATE TABLE IF NOT EXISTS hr_leave (
                                  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                                  doc_no       VARCHAR(20)  NOT NULL,
                                  emp_code     VARCHAR(20)  NOT NULL,
                                  leave_type   CHAR(1)      NOT NULL COMMENT 'S ป่วย P กิจ V พักร้อน O อื่นๆ A ขาด L สาย',
                                  date_from    DATE         NOT NULL,
                                  date_to      DATE         NOT NULL,
                                  day_part     VARCHAR(6)   NOT NULL DEFAULT 'full' COMMENT 'full / am / pm / hours (portion เป็นคำสงวนใน MariaDB)',
                                  hours        DECIMAL(5,2) NULL,
                                  days         DECIMAL(6,2) NOT NULL DEFAULT 0,
                                  reason       VARCHAR(300) NULL,
                                  substitute   VARCHAR(20)  NULL COMMENT 'รหัสผู้ทำการแทน',
                                  written_date DATE         NULL COMMENT 'วันที่เขียนใบลา',
                                  med_cert     TINYINT(1)   NOT NULL DEFAULT 0," + SIGN + @"
                                  PRIMARY KEY (id), UNIQUE KEY ux_doc (doc_no), KEY ix_emp (emp_code, date_from), KEY ix_date (date_from, date_to)
                               ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
                Cmd(c, null, @"CREATE TABLE IF NOT EXISTS hr_leave_quota (
                                  emp_code   VARCHAR(20)  NOT NULL,
                                  year       SMALLINT     NOT NULL,
                                  leave_type CHAR(1)      NOT NULL,
                                  days       DECIMAL(6,2) NOT NULL,
                                  updated_by VARCHAR(40)  NULL, updated_at DATETIME NULL,
                                  PRIMARY KEY (emp_code, year, leave_type)
                               ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
                Cmd(c, null, @"CREATE TABLE IF NOT EXISTS hr_ot (
                                  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                                  doc_no      VARCHAR(20)  NOT NULL,
                                  department  VARCHAR(60)  NULL COMMENT 'แผนกขอทำโอที',
                                  ot_date     DATE         NOT NULL,
                                  note        VARCHAR(300) NULL," + SIGN + @"
                                  PRIMARY KEY (id), UNIQUE KEY ux_doc (doc_no), KEY ix_date (ot_date)
                               ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
                Cmd(c, null, @"CREATE TABLE IF NOT EXISTS hr_ot_line (
                                  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                                  ot_id      BIGINT UNSIGNED NOT NULL,
                                  seq        SMALLINT     NOT NULL DEFAULT 0,
                                  emp_code   VARCHAR(20)  NOT NULL,
                                  time_from  CHAR(5)      NOT NULL COMMENT 'เวลาเข้างาน OT',
                                  time_to    CHAR(5)      NOT NULL COMMENT 'เวลาเลิกงาน OT',
                                  job        VARCHAR(200) NULL COMMENT 'รายละเอียดของงาน',
                                  remark     VARCHAR(200) NULL,
                                  PRIMARY KEY (id), KEY ix_ot (ot_id), KEY ix_emp (emp_code)
                               ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
                _lvTables = true;
            }
            catch { c.Dispose(); throw; }
            return c;
        }

        // ------------------------------------------------------------ ค่าตั้งใบลา
        public static LeaveConfig LeaveConfigGet()
        {
            using (DbConnection c = LvOpen())
            {
                object v = Cmd(c, null, "SELECT v FROM hr_setting WHERE k = 'leave_config'").ExecuteScalar();
                LeaveConfig cfg = null;
                if (v != null && v != DBNull.Value) try { cfg = new JavaScriptSerializer().Deserialize<LeaveConfig>(Convert.ToString(v)); } catch { }
                return LeaveConfig.Fix(cfg);
            }
        }

        public static void LeaveConfigSet(LeaveConfig cfg, string user, string ip)
        {
            string json = new JavaScriptSerializer().Serialize(LeaveConfig.Fix(cfg));
            using (DbConnection c = LvOpen())
            {
                Cmd(c, null, @"INSERT INTO hr_setting (k, v, updated_at, updated_by) VALUES ('leave_config', @v, NOW(), @u)
                               ON DUPLICATE KEY UPDATE v = VALUES(v), updated_at = NOW(), updated_by = VALUES(updated_by)", "@v", json, "@u", user).ExecuteNonQuery();
                HrLog(c, user, "leave-settings", null, json, ip);
            }
        }

        static string NextDocNo(DbConnection c, string table, string prefix, int year)
        {
            string pre = prefix + year.ToString(CultureInfo.InvariantCulture) + "-";
            object max = Cmd(c, null, "SELECT MAX(doc_no) FROM " + table + " WHERE doc_no LIKE @p", "@p", pre + "%").ExecuteScalar();
            int n = 0;
            if (max != null && max != DBNull.Value) int.TryParse(Convert.ToString(max).Substring(pre.Length), out n);
            return pre + (n + 1).ToString("0000", CultureInfo.InvariantCulture);
        }

        static Dictionary<string, object> ReadRow(DbDataReader r)
        {
            var d = new Dictionary<string, object>();
            for (int i = 0; i < r.FieldCount; i++)
            {
                object v = r.GetValue(i); string n = r.GetName(i);
                if (v == DBNull.Value) d[n] = "";
                else if (v is DateTime)
                {
                    DateTime t = (DateTime)v;
                    d[n] = n.EndsWith("_at") ? t.ToString("yyyy-MM-dd HH:mm") : t.ToString("yyyy-MM-dd");
                }
                else if (v is decimal) d[n] = Convert.ToDouble(v);
                else if (n == "id" || n == "ot_id") d[n] = Convert.ToInt64(v);
                else if (n == "paper" || n == "med_cert") d[n] = Convert.ToInt32(v) != 0;
                else d[n] = Convert.ToString(v, CultureInfo.InvariantCulture);
            }
            return d;
        }

        // ------------------------------------------------------------ เซ็น / ไม่อนุมัติ / ยกเลิก (ใช้ร่วม ใบลา + ใบ OT)
        /// <summary>เซ็นช่อง step · ครบทุกช่อง = approved</summary>
        public static string DocSign(string table, long id, string[] steps, IEnumerable<string> signSteps, bool paper, string user, string ip)
        {
            using (DbConnection c = LvOpen())
            {
                string status = Convert.ToString(Cmd(c, null, "SELECT status FROM " + table + " WHERE id = @id", "@id", id).ExecuteScalar());
                if (status == "") throw new Exception("ไม่พบเอกสาร");
                if (status == "rejected" || status == "cancelled") throw new Exception("เอกสารนี้ " + status + " แล้ว");
                foreach (string st in signSteps)
                {
                    if (Array.IndexOf(steps, st) < 0) throw new Exception("bad step");
                    Cmd(c, null, "UPDATE " + table + " SET " + st + "_by = @u, " + st + "_at = NOW(), updated_at = NOW() WHERE id = @id AND " + st + "_by IS NULL",
                        "@u", user, "@id", id).ExecuteNonQuery();
                }
                if (paper) Cmd(c, null, "UPDATE " + table + " SET paper = 1 WHERE id = @id", "@id", id).ExecuteNonQuery();
                string cond = string.Join(" AND ", steps.Select(s => s + "_by IS NOT NULL"));
                Cmd(c, null, "UPDATE " + table + " SET status = 'approved' WHERE id = @id AND status = 'pending' AND " + cond, "@id", id).ExecuteNonQuery();
                string doc = Convert.ToString(Cmd(c, null, "SELECT doc_no FROM " + table + " WHERE id = @id", "@id", id).ExecuteScalar());
                HrLog(c, user, table.Replace("hr_", "") + (paper ? "-paper" : "-sign"), doc, string.Join(",", signSteps), ip);
                return Convert.ToString(Cmd(c, null, "SELECT status FROM " + table + " WHERE id = @id", "@id", id).ExecuteScalar());
            }
        }

        /// <summary>ไม่อนุมัติ (reject) หรือ ยกเลิก (cancel)</summary>
        public static void DocClose(string table, long id, bool reject, string note, string user, string ip)
        {
            using (DbConnection c = LvOpen())
            {
                string status = Convert.ToString(Cmd(c, null, "SELECT status FROM " + table + " WHERE id = @id", "@id", id).ExecuteScalar());
                if (status == "") throw new Exception("ไม่พบเอกสาร");
                if (status == "rejected" || status == "cancelled") return;
                Cmd(c, null, "UPDATE " + table + " SET status = @s, reject_by = @u, reject_at = NOW(), reject_note = @n, updated_at = NOW() WHERE id = @id",
                    "@s", reject ? "rejected" : "cancelled", "@u", user, "@n", NullIfEmpty(Cut(note, 300)), "@id", id).ExecuteNonQuery();
                string doc = Convert.ToString(Cmd(c, null, "SELECT doc_no FROM " + table + " WHERE id = @id", "@id", id).ExecuteScalar());
                HrLog(c, user, table.Replace("hr_", "") + (reject ? "-reject" : "-cancel"), doc, note, ip);
            }
        }

        // ------------------------------------------------------------ ใบลา
        /// <summary>ใบลาที่คาบเกี่ยวช่วง [from, to] (ไม่ใส่ = ทั้งหมด) · empCode ไม่ใส่ = ทุกคน</summary>
        public static List<Dictionary<string, object>> LeaveList(DateTime? from, DateTime? to, string empCode)
        {
            var list = new List<Dictionary<string, object>>();
            var where = new List<string>(); var args = new List<object>();
            if (from.HasValue) { where.Add("date_to >= @a"); args.Add("@a"); args.Add(from.Value); }
            if (to.HasValue) { where.Add("date_from <= @b"); args.Add("@b"); args.Add(to.Value); }
            if (!string.IsNullOrEmpty(empCode)) { where.Add("emp_code = @e"); args.Add("@e"); args.Add(empCode); }
            using (DbConnection c = LvOpen())
            using (DbDataReader r = Cmd(c, null, "SELECT *, day_part AS `portion` FROM hr_leave" + (where.Count > 0 ? " WHERE " + string.Join(" AND ", where) : "") +
                                                 " ORDER BY date_from DESC, id DESC", args.ToArray()).ExecuteReader())
                while (r.Read()) list.Add(ReadRow(r));
            return list;
        }

        public static Dictionary<string, object> LeaveGet(long id)
        {
            using (DbConnection c = LvOpen())
            using (DbDataReader r = Cmd(c, null, "SELECT *, day_part AS `portion` FROM hr_leave WHERE id = @id", "@id", id).ExecuteReader())
                return r.Read() ? ReadRow(r) : null;
        }

        /// <summary>บันทึกใบลา (id = 0 เพิ่มใหม่) · days คำนวณจากหน้าเว็บแล้ว</summary>
        public static long LeaveSave(long id, string emp, string type, DateTime from, DateTime to, string portion, double? hours, double days,
                                     string reason, string substitute, DateTime? written, bool medCert, string user, string ip)
        {
            using (DbConnection c = LvOpen())
            {
                object[] a = { "@e", emp, "@t", type, "@f", from, "@to", to, "@p", portion, "@h", hours, "@d", days, "@r", NullIfEmpty(Cut(reason, 300)),
                               "@s", NullIfEmpty(Cut(substitute, 20)), "@w", written, "@m", medCert ? 1 : 0, "@u", user, "@id", id };
                if (id > 0)
                {
                    if (Cmd(c, null, @"UPDATE hr_leave SET emp_code = @e, leave_type = @t, date_from = @f, date_to = @to, day_part = @p, hours = @h, days = @d, reason = @r,
                                         substitute = @s, written_date = @w, med_cert = @m, updated_at = NOW() WHERE id = @id", a).ExecuteNonQuery() == 0)
                        throw new Exception("ไม่พบใบลา");
                    HrLog(c, user, "leave-update", Convert.ToString(Cmd(c, null, "SELECT doc_no FROM hr_leave WHERE id = @id", "@id", id).ExecuteScalar()), emp + " " + type + " " + from.ToString("yyyy-MM-dd"), ip);
                    return id;
                }
                string doc = NextDocNo(c, "hr_leave", "L", from.Year);
                var b = a.ToList(); b.Add("@doc"); b.Add(doc);
                Cmd(c, null, @"INSERT INTO hr_leave (doc_no, emp_code, leave_type, date_from, date_to, day_part, hours, days, reason, substitute, written_date, med_cert, status, created_by, created_at, updated_at)
                               VALUES (@doc, @e, @t, @f, @to, @p, @h, @d, @r, @s, @w, @m, 'pending', @u, NOW(), NOW())", b.ToArray()).ExecuteNonQuery();
                long newId = Convert.ToInt64(Cmd(c, null, "SELECT LAST_INSERT_ID()").ExecuteScalar(), CultureInfo.InvariantCulture);
                HrLog(c, user, "leave-add", doc, emp + " " + type + " " + from.ToString("yyyy-MM-dd") + " " + days + "d", ip);
                return newId;
            }
        }

        /// <summary>สิทธิ์วันลาที่ HR แก้รายคน : key = emp|type</summary>
        public static Dictionary<string, double> LeaveQuota(int year)
        {
            var map = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
            using (DbConnection c = LvOpen())
            using (DbDataReader r = Cmd(c, null, "SELECT emp_code, leave_type, days FROM hr_leave_quota WHERE year = @y", "@y", year).ExecuteReader())
                while (r.Read()) map[r.GetString(0) + "|" + r.GetString(1)] = Convert.ToDouble(r.GetValue(2));
            return map;
        }

        /// <summary>days = null : กลับไปใช้ค่าตั้งต้น</summary>
        public static void LeaveQuotaSet(string emp, int year, string type, double? days, string user, string ip)
        {
            using (DbConnection c = LvOpen())
            {
                if (days.HasValue)
                    Cmd(c, null, @"INSERT INTO hr_leave_quota (emp_code, year, leave_type, days, updated_by, updated_at) VALUES (@e, @y, @t, @d, @u, NOW())
                                   ON DUPLICATE KEY UPDATE days = VALUES(days), updated_by = VALUES(updated_by), updated_at = NOW()",
                        "@e", emp, "@y", year, "@t", type, "@d", days.Value, "@u", user).ExecuteNonQuery();
                else Cmd(c, null, "DELETE FROM hr_leave_quota WHERE emp_code = @e AND year = @y AND leave_type = @t", "@e", emp, "@y", year, "@t", type).ExecuteNonQuery();
                HrLog(c, user, "leave-quota", emp, year + " " + type + " = " + (days.HasValue ? days.Value.ToString(CultureInfo.InvariantCulture) : "default"), ip);
            }
        }

        // ------------------------------------------------------------ ใบขอ OT
        public static List<Dictionary<string, object>> OtList(DateTime? from, DateTime? to, long? id)
        {
            var heads = new List<Dictionary<string, object>>();
            var where = new List<string>(); var args = new List<object>();
            if (id.HasValue) { where.Add("id = @id"); args.Add("@id"); args.Add(id.Value); }
            if (from.HasValue) { where.Add("ot_date >= @a"); args.Add("@a"); args.Add(from.Value); }
            if (to.HasValue) { where.Add("ot_date <= @b"); args.Add("@b"); args.Add(to.Value); }
            using (DbConnection c = LvOpen())
            {
                using (DbDataReader r = Cmd(c, null, "SELECT * FROM hr_ot" + (where.Count > 0 ? " WHERE " + string.Join(" AND ", where) : "") + " ORDER BY ot_date DESC, id DESC", args.ToArray()).ExecuteReader())
                    while (r.Read()) { var h = ReadRow(r); h["lines"] = new List<Dictionary<string, object>>(); heads.Add(h); }
                if (heads.Count > 0)
                {
                    var byId = heads.ToDictionary(h => (long)h["id"]);
                    using (DbDataReader r = Cmd(c, null, "SELECT * FROM hr_ot_line WHERE ot_id IN (" + string.Join(",", byId.Keys) + ") ORDER BY ot_id, seq, id").ExecuteReader())
                        while (r.Read()) { var l = ReadRow(r); ((List<Dictionary<string, object>>)byId[(long)l["ot_id"]]["lines"]).Add(l); }
                }
            }
            return heads;
        }

        public class OtLine { public string Emp, From, To, Job, Remark; }

        public static long OtSave(long id, string dept, DateTime date, string note, List<OtLine> lines, string user, string ip)
        {
            using (DbConnection c = LvOpen())
            {
                string doc;
                if (id > 0)
                {
                    if (Cmd(c, null, "UPDATE hr_ot SET department = @d, ot_date = @t, note = @n, updated_at = NOW() WHERE id = @id",
                            "@d", NullIfEmpty(Cut(dept, 60)), "@t", date, "@n", NullIfEmpty(Cut(note, 300)), "@id", id).ExecuteNonQuery() == 0)
                        throw new Exception("ไม่พบใบขอ OT");
                    Cmd(c, null, "DELETE FROM hr_ot_line WHERE ot_id = @id", "@id", id).ExecuteNonQuery();
                    doc = Convert.ToString(Cmd(c, null, "SELECT doc_no FROM hr_ot WHERE id = @id", "@id", id).ExecuteScalar());
                }
                else
                {
                    doc = NextDocNo(c, "hr_ot", "OT", date.Year);
                    Cmd(c, null, @"INSERT INTO hr_ot (doc_no, department, ot_date, note, status, created_by, created_at, updated_at) VALUES (@doc, @d, @t, @n, 'pending', @u, NOW(), NOW())",
                        "@doc", doc, "@d", NullIfEmpty(Cut(dept, 60)), "@t", date, "@n", NullIfEmpty(Cut(note, 300)), "@u", user).ExecuteNonQuery();
                    id = Convert.ToInt64(Cmd(c, null, "SELECT LAST_INSERT_ID()").ExecuteScalar(), CultureInfo.InvariantCulture);
                }
                int seq = 0;
                foreach (var l in lines)
                    Cmd(c, null, "INSERT INTO hr_ot_line (ot_id, seq, emp_code, time_from, time_to, job, remark) VALUES (@o, @s, @e, @f, @t, @j, @r)",
                        "@o", id, "@s", ++seq, "@e", l.Emp, "@f", l.From, "@t", l.To, "@j", NullIfEmpty(Cut(l.Job, 200)), "@r", NullIfEmpty(Cut(l.Remark, 200))).ExecuteNonQuery();
                HrLog(c, user, "ot-save", doc, (dept ?? "") + " " + date.ToString("yyyy-MM-dd") + " · " + lines.Count + " people", ip);
                return id;
            }
        }

        /// <summary>ชื่อที่แสดงของผู้ใช้ (ใช้แสดงชื่อคนเซ็น)</summary>
        public static Dictionary<string, string> HrUserNames()
        {
            var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            using (DbConnection c = HrOpen())
            using (DbDataReader r = Cmd(c, null, "SELECT username, display_name FROM hr_user").ExecuteReader())
                while (r.Read()) map[r.GetString(0)] = r.IsDBNull(1) || r.GetString(1) == "" ? r.GetString(0) : r.GetString(1);
            return map;
        }
    }
}
