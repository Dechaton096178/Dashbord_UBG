using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Globalization;
using System.Linq;

namespace Dashbord
{
    /// <summary>
    /// HR : ตารางใน MySQL OEE (สร้างเองอัตโนมัติครั้งแรก)
    ///   hr_user     ผู้ใช้ระบบ HR (รหัสผ่านเก็บแบบ hash PBKDF2)
    ///   hr_employee ทะเบียนพนักงาน
    ///   hr_log      ประวัติการเพิ่ม / แก้ / ลบ / เข้าระบบ
    /// </summary>
    public static partial class OeeDb
    {
        static bool _hrTables;
        public const string HR_DEFAULT_ADMIN = "admin";
        public const string HR_DEFAULT_PW = "admin1234";   // ใช้ครั้งแรกเท่านั้น -> ระบบบังคับเปลี่ยนตอนล็อกอิน

        static void EnsureHrTables(DbConnection c)
        {
            if (_hrTables) return;
            Cmd(c, null, @"CREATE TABLE IF NOT EXISTS hr_user (
                              id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
                              username      VARCHAR(40)  NOT NULL,
                              display_name  VARCHAR(80)  NULL,
                              role          VARCHAR(20)  NOT NULL DEFAULT 'viewer' COMMENT 'admin / hr / viewer',
                              pw_hash       VARCHAR(200) NOT NULL,
                              must_change   TINYINT(1)   NOT NULL DEFAULT 0,
                              active        TINYINT(1)   NOT NULL DEFAULT 1,
                              last_login    DATETIME     NULL,
                              created_at    DATETIME     NULL,
                              updated_at    DATETIME     NULL,
                              PRIMARY KEY (id),
                              UNIQUE KEY ux_username (username)
                           ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
            Cmd(c, null, @"CREATE TABLE IF NOT EXISTS hr_employee (
                              id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
                              emp_code      VARCHAR(20)  NOT NULL COMMENT 'รหัสพนักงาน เช่น U-0002',
                              emp_group     VARCHAR(40)  NULL COMMENT 'UBG / DMM / นักศึกษา ...',
                              prefix        VARCHAR(20)  NULL COMMENT 'นาย / นาง / นางสาว',
                              name_th       VARCHAR(120) NULL,
                              name_en       VARCHAR(120) NULL,
                              nickname      VARCHAR(40)  NULL,
                              gender        VARCHAR(1)   NULL COMMENT 'M / F',
                              nationality   VARCHAR(40)  NULL,
                              department    VARCHAR(60)  NULL COMMENT 'แผนก / Process',
                              position      VARCHAR(120) NULL COMMENT 'ตำแหน่ง',
                              emp_type      VARCHAR(20)  NULL COMMENT 'Regular / Temporary / Student',
                              start_date    DATE         NULL,
                              contract_end  DATE         NULL,
                              locker_no     VARCHAR(20)  NULL,
                              phone         VARCHAR(40)  NULL,
                              id_card       VARCHAR(30)  NULL COMMENT 'เลขบัตรประชาชน / Passport / Work permit',
                              birth_date    DATE         NULL,
                              address       VARCHAR(300) NULL,
                              status        VARCHAR(20)  NOT NULL DEFAULT 'Active' COMMENT 'Active / Resigned',
                              resign_date   DATE         NULL,
                              remark        VARCHAR(500) NULL,
                              passport_no   VARCHAR(30)  NULL,
                              passport_exp  DATE         NULL,
                              visa_exp      DATE         NULL,
                              permit_type   VARCHAR(60)  NULL COMMENT 'ประเภทใบอนุญาต เช่น มติ 24 ก.ย. 67',
                              wp_no         VARCHAR(30)  NULL COMMENT 'เลขใบอนุญาตทำงาน',
                              wp_exp        DATE         NULL,
                              pink_no       VARCHAR(30)  NULL COMMENT 'เลขบัตรชมพู',
                              pink_exp      DATE         NULL,
                              created_at    DATETIME     NULL,
                              created_by    VARCHAR(40)  NULL,
                              updated_at    DATETIME     NULL,
                              updated_by    VARCHAR(40)  NULL,
                              updated_ip    VARCHAR(45)  NULL,
                              PRIMARY KEY (id),
                              UNIQUE KEY ux_emp_code (emp_code),
                              KEY ix_dept (department),
                              KEY ix_status (status)
                           ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
            Cmd(c, null, @"CREATE TABLE IF NOT EXISTS hr_log (
                              id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                              at        DATETIME     NOT NULL,
                              username  VARCHAR(40)  NULL,
                              action    VARCHAR(30)  NOT NULL,
                              ref       VARCHAR(40)  NULL,
                              detail    VARCHAR(1000) NULL,
                              ip        VARCHAR(45)  NULL,
                              PRIMARY KEY (id),
                              KEY ix_at (at),
                              KEY ix_ref (ref)
                           ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
            // เพิ่มคอลัมน์ใหม่ให้ตารางเดิม (อัปเกรด)
            if (Convert.ToInt32(Cmd(c, null, "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hr_user' AND COLUMN_NAME = 'depts'").ExecuteScalar(), CultureInfo.InvariantCulture) == 0)
                Cmd(c, null, "ALTER TABLE hr_user ADD COLUMN depts VARCHAR(500) NULL COMMENT 'supervisor / manager : แผนกที่ดูแล คั่นด้วย ,' AFTER role").ExecuteNonQuery();
            // ข้อมูลเอกสารคนต่างชาติ (เพิ่ม 2026-10-29) : เพิ่มคอลัมน์ให้ตารางที่สร้างไว้ก่อนแล้ว
            foreach (var col in new[] { "passport_no VARCHAR(30) NULL", "passport_exp DATE NULL", "visa_exp DATE NULL", "permit_type VARCHAR(60) NULL",
                                        "wp_no VARCHAR(30) NULL", "wp_exp DATE NULL", "pink_no VARCHAR(30) NULL", "pink_exp DATE NULL" })
            {
                string name = col.Split(' ')[0];
                if (Convert.ToInt32(Cmd(c, null, "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hr_employee' AND COLUMN_NAME = @n",
                                        "@n", name).ExecuteScalar(), CultureInfo.InvariantCulture) == 0)
                    Cmd(c, null, "ALTER TABLE hr_employee ADD COLUMN " + col).ExecuteNonQuery();
            }
            // ผู้ใช้คนแรก (ตารางว่าง) : admin / admin1234 -> ต้องเปลี่ยนรหัสตอนเข้าครั้งแรก
            if (Convert.ToInt32(Cmd(c, null, "SELECT COUNT(*) FROM hr_user").ExecuteScalar(), CultureInfo.InvariantCulture) == 0)
                Cmd(c, null, @"INSERT INTO hr_user (username, display_name, role, pw_hash, must_change, active, created_at, updated_at)
                               VALUES (@u, 'Administrator', 'admin', @h, 1, 1, NOW(), NOW())",
                    "@u", HR_DEFAULT_ADMIN, "@h", HrAuth.HashPassword(HR_DEFAULT_PW)).ExecuteNonQuery();
            _hrTables = true;
        }

        static DbConnection HrOpen()
        {
            if (!Init()) throw new Exception(LastError ?? "DB ยังไม่ได้ตั้งค่า");
            DbConnection c = Open();
            try { EnsureHrTables(c); }
            catch { c.Dispose(); throw; }
            return c;
        }

        public static void HrLog(string user, string action, string reference, string detail, string ip)
        {
            try { using (DbConnection c = HrOpen()) HrLog(c, user, action, reference, detail, ip); } catch { }
        }

        static void HrLog(DbConnection c, string user, string action, string reference, string detail, string ip)
        {
            if (detail != null && detail.Length > 1000) detail = detail.Substring(0, 1000);
            Cmd(c, null, "INSERT INTO hr_log (at, username, action, ref, detail, ip) VALUES (NOW(), @u, @a, @r, @d, @ip)",
                "@u", user, "@a", action, "@r", reference, "@d", detail, "@ip", ip).ExecuteNonQuery();
        }

        // =====================================================================
        // ผู้ใช้ (hr_user)
        // =====================================================================
        public class HrUserRow
        {
            public int Id; public string Username, DisplayName, Role, PwHash, Depts; public bool MustChange, Active;
            public HrSessionUser ToSession()
            {
                return new HrSessionUser { Id = Id, Username = Username, DisplayName = DisplayName ?? Username, Role = Role, MustChange = MustChange,
                    Depts = (Depts ?? "").Split(',').Select(x => x.Trim()).Where(x => x.Length > 0).ToList() };
            }
        }

        static HrUserRow ReadUser(DbDataReader r)
        {
            return new HrUserRow
            {
                Id = Convert.ToInt32(r["id"], CultureInfo.InvariantCulture),
                Username = Convert.ToString(r["username"]),
                DisplayName = r["display_name"] == DBNull.Value ? null : Convert.ToString(r["display_name"]),
                Role = Convert.ToString(r["role"]),
                Depts = r["depts"] == DBNull.Value ? "" : Convert.ToString(r["depts"]),
                PwHash = Convert.ToString(r["pw_hash"]),
                MustChange = Convert.ToInt32(r["must_change"], CultureInfo.InvariantCulture) != 0,
                Active = Convert.ToInt32(r["active"], CultureInfo.InvariantCulture) != 0,
            };
        }

        public static HrUserRow HrUserFind(string username)
        {
            using (DbConnection c = HrOpen())
            using (DbDataReader r = Cmd(c, null, "SELECT * FROM hr_user WHERE username = @u", "@u", (username ?? "").Trim()).ExecuteReader())
                return r.Read() ? ReadUser(r) : null;
        }

        static HrUserRow HrUserById(DbConnection c, int id)
        {
            using (DbDataReader r = Cmd(c, null, "SELECT * FROM hr_user WHERE id = @id", "@id", id).ExecuteReader())
                return r.Read() ? ReadUser(r) : null;
        }

        /// <summary>ข้อมูลผู้ใช้ล่าสุดสำหรับ Session (null = ถูกลบ / ปิดใช้งาน)</summary>
        public static HrSessionUser HrUserSession(int id)
        {
            using (DbConnection c = HrOpen())
            {
                HrUserRow u = HrUserById(c, id);
                return u != null && u.Active ? u.ToSession() : null;
            }
        }

        public static void HrUserLoggedIn(int id, string ip)
        {
            using (DbConnection c = HrOpen())
            {
                Cmd(c, null, "UPDATE hr_user SET last_login = NOW() WHERE id = @id", "@id", id).ExecuteNonQuery();
                HrUserRow u = HrUserById(c, id);
                HrLog(c, u != null ? u.Username : null, "login", null, null, ip);
            }
        }

        public static void HrUserSetPassword(int id, string newPw, bool mustChange, string byUser, string ip)
        {
            string err = HrAuth.CheckNewPassword(newPw);
            if (err != null) throw new Exception(err);
            using (DbConnection c = HrOpen())
            {
                if (Cmd(c, null, "UPDATE hr_user SET pw_hash = @h, must_change = @m, updated_at = NOW() WHERE id = @id",
                        "@h", HrAuth.HashPassword(newPw), "@m", mustChange ? 1 : 0, "@id", id).ExecuteNonQuery() == 0)
                    throw new Exception("ไม่พบผู้ใช้");
                HrUserRow u = HrUserById(c, id);
                HrLog(c, byUser, mustChange ? "reset-password" : "change-password", u != null ? u.Username : id.ToString(CultureInfo.InvariantCulture), null, ip);
            }
        }

        public static List<Dictionary<string, object>> HrUserList()
        {
            var list = new List<Dictionary<string, object>>();
            using (DbConnection c = HrOpen())
            using (DbDataReader r = Cmd(c, null, "SELECT * FROM hr_user ORDER BY active DESC, role, username").ExecuteReader())
                while (r.Read())
                    list.Add(new Dictionary<string, object> {
                        { "id", Convert.ToInt32(r["id"], CultureInfo.InvariantCulture) },
                        { "username", Convert.ToString(r["username"]) },
                        { "display_name", r["display_name"] == DBNull.Value ? "" : Convert.ToString(r["display_name"]) },
                        { "role", Convert.ToString(r["role"]) },
                        { "depts", r["depts"] == DBNull.Value ? "" : Convert.ToString(r["depts"]) },
                        { "active", Convert.ToInt32(r["active"], CultureInfo.InvariantCulture) != 0 },
                        { "must_change", Convert.ToInt32(r["must_change"], CultureInfo.InvariantCulture) != 0 },
                        { "last_login", r["last_login"] == DBNull.Value ? "" : Convert.ToDateTime(r["last_login"], CultureInfo.InvariantCulture).ToString("yyyy-MM-dd HH:mm") },
                    });
            return list;
        }

        /// <summary>เพิ่ม / แก้ผู้ใช้ (id = 0 = เพิ่ม ต้องมีรหัสผ่าน) · newPw ว่าง = ไม่เปลี่ยนรหัส</summary>
        public static int HrUserSave(int id, string username, string displayName, string role, bool active, string newPw, int selfId, string byUser, string ip, string depts)
        {
            depts = string.Join(", ", (depts ?? "").Split(',').Select(x => x.Trim()).Where(x => x.Length > 0).Distinct(StringComparer.OrdinalIgnoreCase));
            if (depts.Length > 500) depts = depts.Substring(0, 500);
            username = (username ?? "").Trim();
            displayName = (displayName ?? "").Trim();
            if (!System.Text.RegularExpressions.Regex.IsMatch(username, @"^[A-Za-z0-9._-]{3,40}$")) throw new Exception("Username ใช้ได้เฉพาะ a-z 0-9 . _ - (3-40 ตัว)");
            if (Array.IndexOf(HrAuth.ROLES, role) < 0) throw new Exception("Role ไม่ถูกต้อง");
            if (displayName.Length > 80) displayName = displayName.Substring(0, 80);
            if (id == selfId && (!active || role != "admin")) throw new Exception("แก้สิทธิ์ / ปิดใช้งานบัญชีตัวเองไม่ได้");
            if (id == 0 || !string.IsNullOrEmpty(newPw)) { string err = HrAuth.CheckNewPassword(newPw); if (err != null) throw new Exception(err); }

            using (DbConnection c = HrOpen())
            {
                object dup = Cmd(c, null, "SELECT id FROM hr_user WHERE username = @u AND id <> @id", "@u", username, "@id", id).ExecuteScalar();
                if (dup != null) throw new Exception("มี Username นี้แล้ว");
                if (id > 0)
                {
                    if (Cmd(c, null, "UPDATE hr_user SET username = @u, display_name = @d, role = @r, depts = @dp, active = @a, updated_at = NOW() WHERE id = @id",
                            "@u", username, "@d", NullIfEmpty(displayName), "@r", role, "@dp", NullIfEmpty(depts), "@a", active ? 1 : 0, "@id", id).ExecuteNonQuery() == 0)
                        throw new Exception("ไม่พบผู้ใช้");
                    if (!string.IsNullOrEmpty(newPw))
                        Cmd(c, null, "UPDATE hr_user SET pw_hash = @h, must_change = 1 WHERE id = @id", "@h", HrAuth.HashPassword(newPw), "@id", id).ExecuteNonQuery();
                    HrLog(c, byUser, "user-update", username, "role=" + role + " active=" + active + (string.IsNullOrEmpty(newPw) ? "" : " password-reset"), ip);
                }
                else
                {
                    Cmd(c, null, @"INSERT INTO hr_user (username, display_name, role, depts, pw_hash, must_change, active, created_at, updated_at)
                                   VALUES (@u, @d, @r, @dp, @h, 1, @a, NOW(), NOW())",
                        "@u", username, "@d", NullIfEmpty(displayName), "@r", role, "@dp", NullIfEmpty(depts), "@h", HrAuth.HashPassword(newPw), "@a", active ? 1 : 0).ExecuteNonQuery();
                    id = Convert.ToInt32(Cmd(c, null, "SELECT LAST_INSERT_ID()").ExecuteScalar(), CultureInfo.InvariantCulture);
                    HrLog(c, byUser, "user-add", username, "role=" + role, ip);
                }
                return id;
            }
        }

        public static void HrUserDelete(int id, int selfId, string byUser, string ip)
        {
            if (id == selfId) throw new Exception("ลบบัญชีตัวเองไม่ได้");
            using (DbConnection c = HrOpen())
            {
                HrUserRow u = HrUserById(c, id);
                if (u == null) return;
                Cmd(c, null, "DELETE FROM hr_user WHERE id = @id", "@id", id).ExecuteNonQuery();
                HrLog(c, byUser, "user-delete", u.Username, null, ip);
            }
        }

        // =====================================================================
        // พนักงาน (hr_employee)
        // =====================================================================
        public static readonly string[] EMP_FIELDS = {
            "emp_code", "emp_group", "prefix", "name_th", "name_en", "nickname", "gender", "nationality",
            "department", "position", "emp_type", "start_date", "contract_end", "locker_no",
            "phone", "id_card", "birth_date", "address", "status", "resign_date", "remark",
            "passport_no", "passport_exp", "visa_exp", "permit_type", "wp_no", "wp_exp", "pink_no", "pink_exp" };
        /// <summary>เอกสารคนต่างชาติ (พาสปอร์ต / วีซ่า / ใบอนุญาตทำงาน / บัตรชมพู)</summary>
        public static readonly string[] EMP_DOCS = { "passport_no", "passport_exp", "visa_exp", "permit_type", "wp_no", "wp_exp", "pink_no", "pink_exp" };
        /// <summary>ข้อมูลส่วนตัว : เห็นเฉพาะ role admin / hr</summary>
        public static readonly string[] EMP_SENSITIVE = { "phone", "id_card", "birth_date", "address", "passport_no", "wp_no", "pink_no" };
        public static readonly string[] EMP_DATES = { "start_date", "contract_end", "birth_date", "resign_date", "passport_exp", "visa_exp", "wp_exp", "pink_exp" };
        static readonly Dictionary<string, int> EMP_MAX = new Dictionary<string, int> {
            { "emp_code", 20 }, { "emp_group", 40 }, { "prefix", 20 }, { "name_th", 120 }, { "name_en", 120 }, { "nickname", 40 },
            { "gender", 1 }, { "nationality", 40 }, { "department", 60 }, { "position", 120 }, { "emp_type", 20 }, { "locker_no", 20 },
            { "phone", 40 }, { "id_card", 30 }, { "address", 300 }, { "status", 20 }, { "remark", 500 },
            { "passport_no", 30 }, { "permit_type", 60 }, { "wp_no", 30 }, { "pink_no", 30 } };

        public static List<Dictionary<string, object>> EmpList(bool sensitive)
        {
            var list = new List<Dictionary<string, object>>();
            using (DbConnection c = HrOpen())
            using (DbDataReader r = Cmd(c, null, "SELECT * FROM hr_employee ORDER BY emp_code").ExecuteReader())
                while (r.Read())
                {
                    var d = new Dictionary<string, object>();
                    d["id"] = Convert.ToInt32(r["id"], CultureInfo.InvariantCulture);
                    foreach (string f in EMP_FIELDS)
                    {
                        object v = r[f];
                        if (v == DBNull.Value || (!sensitive && Array.IndexOf(EMP_SENSITIVE, f) >= 0)) d[f] = "";
                        else if (Array.IndexOf(EMP_DATES, f) >= 0) d[f] = Convert.ToDateTime(v, CultureInfo.InvariantCulture).ToString("yyyy-MM-dd");
                        else d[f] = Convert.ToString(v, CultureInfo.InvariantCulture);
                    }
                    d["updated_at"] = r["updated_at"] == DBNull.Value ? "" : Convert.ToDateTime(r["updated_at"], CultureInfo.InvariantCulture).ToString("yyyy-MM-dd HH:mm");
                    d["updated_by"] = r["updated_by"] == DBNull.Value ? "" : Convert.ToString(r["updated_by"]);
                    list.Add(d);
                }
            return list;
        }

        /// <summary>บันทึก 1 คน (id = 0 → เพิ่ม) · คืน id</summary>
        public static int EmpSave(int id, Dictionary<string, string> v, string user, string ip)
        {
            using (DbConnection c = HrOpen()) return EmpSaveCore(c, id, v, user, ip, "emp-");
        }

        /// <summary>บันทึกหลายคน (นำเข้า Excel) ใช้ connection เดียว · คืนข้อความ error ของแต่ละแถว (null = สำเร็จ)</summary>
        public static List<string> EmpSaveMany(List<KeyValuePair<int, Dictionary<string, string>>> rows, string user, string ip)
        {
            var errs = new List<string>();
            using (DbConnection c = HrOpen())
            {
                foreach (var kv in rows)
                {
                    try { EmpSaveCore(c, kv.Key, kv.Value, user, ip, "import-"); errs.Add(null); }
                    catch (Exception ex) { errs.Add(ex.Message); }
                }
            }
            return errs;
        }

        static int EmpSaveCore(DbConnection c, int id, Dictionary<string, string> v, string user, string ip, string logPrefix)
        {
            var args = new List<object>();
            string code = null;
            foreach (string f in EMP_FIELDS)
            {
                string s; v.TryGetValue(f, out s); s = (s ?? "").Trim();
                object val = s.Length == 0 ? null : (object)s;
                if (val != null && Array.IndexOf(EMP_DATES, f) >= 0)
                {
                    DateTime dt;
                    if (!DateTime.TryParseExact(s, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out dt) || dt.Year < 1900 || dt.Year > 2200)
                        throw new Exception(f + " : วันที่ไม่ถูกต้อง (" + s + ")");
                    val = dt;
                }
                else if (val != null && EMP_MAX.ContainsKey(f) && s.Length > EMP_MAX[f]) val = s.Substring(0, EMP_MAX[f]);
                if (f == "emp_code") code = (string)val;
                if (f == "status" && val == null) val = "Active";
                args.Add("@" + f); args.Add(val);
            }
            if (string.IsNullOrEmpty(code)) throw new Exception("ต้องใส่รหัสพนักงาน");
            string th, en; v.TryGetValue("name_th", out th); v.TryGetValue("name_en", out en);
            if (string.IsNullOrWhiteSpace(th) && string.IsNullOrWhiteSpace(en)) throw new Exception("ต้องใส่ชื่อ (ไทย หรือ อังกฤษ)");

            object dup = Cmd(c, null, "SELECT id FROM hr_employee WHERE emp_code = @c AND id <> @id", "@c", code, "@id", id).ExecuteScalar();
            if (dup != null) throw new Exception("รหัส " + code + " มีอยู่แล้ว");

            args.Add("@by"); args.Add(user); args.Add("@uip"); args.Add(ip); args.Add("@id"); args.Add(id);
            if (id > 0)
            {
                var sets = EMP_FIELDS.Select(f => f + " = @" + f);
                if (Cmd(c, null, "UPDATE hr_employee SET " + string.Join(", ", sets) + ", updated_at = NOW(), updated_by = @by, updated_ip = @uip WHERE id = @id", args.ToArray()).ExecuteNonQuery() == 0)
                    throw new Exception("ไม่พบรายการ id " + id);
                HrLog(c, user, logPrefix + "update", code, null, ip);
                return id;
            }
            Cmd(c, null, "INSERT INTO hr_employee (" + string.Join(", ", EMP_FIELDS) + ", created_at, created_by, updated_at, updated_by, updated_ip) VALUES (" +
                         string.Join(", ", EMP_FIELDS.Select(f => "@" + f)) + ", NOW(), @by, NOW(), @by, @uip)", args.ToArray()).ExecuteNonQuery();
            int newId = Convert.ToInt32(Cmd(c, null, "SELECT LAST_INSERT_ID()").ExecuteScalar(), CultureInfo.InvariantCulture);
            HrLog(c, user, logPrefix + "add", code, null, ip);
            return newId;
        }

        /// <summary>ปรับเป็นลาออกหลายคน (เช่น คนที่ไม่มีสแกนเลย 30 วัน) · resignDates : id -> yyyy-MM-dd (ว่าง = ไม่ใส่วันที่)</summary>
        public static int EmpBulkResign(Dictionary<int, string> resignDates, string note, string user, string ip)
        {
            int n = 0;
            using (DbConnection c = HrOpen())
                foreach (var kv in resignDates)
                {
                    DateTime d; object rd = DateTime.TryParseExact(kv.Value ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? (object)d : null;
                    object code = Cmd(c, null, "SELECT emp_code FROM hr_employee WHERE id = @id AND status <> 'Resigned'", "@id", kv.Key).ExecuteScalar();
                    if (code == null) continue;
                    n += Cmd(c, null, @"UPDATE hr_employee SET status = 'Resigned', resign_date = COALESCE(resign_date, @rd),
                                          remark = LEFT(CONCAT_WS(' · ', NULLIF(remark, ''), @note), 500), updated_at = NOW(), updated_by = @u, updated_ip = @ip WHERE id = @id",
                                 "@rd", rd, "@note", note, "@u", user, "@ip", ip, "@id", kv.Key).ExecuteNonQuery();
                    HrLog(c, user, "emp-resign", Convert.ToString(code), note, ip);
                }
            return n;
        }

        public static void EmpDelete(int id, string user, string ip)
        {
            using (DbConnection c = HrOpen())
            {
                object code = Cmd(c, null, "SELECT emp_code FROM hr_employee WHERE id = @id", "@id", id).ExecuteScalar();
                if (code == null) return;
                Cmd(c, null, "DELETE FROM hr_employee WHERE id = @id", "@id", id).ExecuteNonQuery();
                HrLog(c, user, "emp-delete", Convert.ToString(code), null, ip);
            }
        }

        /// <summary>ประวัติการแก้ไขล่าสุด (ของพนักงาน 1 คน หรือทั้งหมด)</summary>
        public static List<Dictionary<string, object>> HrLogList(string reference, int limit)
        {
            var list = new List<Dictionary<string, object>>();
            using (DbConnection c = HrOpen())
            using (DbDataReader r = (string.IsNullOrEmpty(reference)
                        ? Cmd(c, null, "SELECT * FROM hr_log ORDER BY id DESC LIMIT " + Math.Max(1, Math.Min(limit, 1000)))
                        : Cmd(c, null, "SELECT * FROM hr_log WHERE ref = @r ORDER BY id DESC LIMIT " + Math.Max(1, Math.Min(limit, 1000)), "@r", reference)).ExecuteReader())
                while (r.Read())
                    list.Add(new Dictionary<string, object> {
                        { "at", Convert.ToDateTime(r["at"], CultureInfo.InvariantCulture).ToString("yyyy-MM-dd HH:mm") },
                        { "user", r["username"] == DBNull.Value ? "" : Convert.ToString(r["username"]) },
                        { "action", Convert.ToString(r["action"]) },
                        { "ref", r["ref"] == DBNull.Value ? "" : Convert.ToString(r["ref"]) },
                        { "detail", r["detail"] == DBNull.Value ? "" : Convert.ToString(r["detail"]) },
                    });
            return list;
        }
    }
}
