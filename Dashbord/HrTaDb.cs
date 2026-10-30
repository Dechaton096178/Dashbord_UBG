using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;

namespace Dashbord
{
    /// <summary>
    /// Time Attendance : ตารางใน MySQL OEE (สร้างเองอัตโนมัติ)
    ///   hr_punch    เวลาสแกนนิ้ว / หน้า ทุกครั้ง (1 แถว = 1 ครั้ง) · นำเข้าจากไฟล์ Excel ของเครื่องสแกน หรือ HR เพิ่มเอง (manual)
    ///   hr_setting  ค่าตั้ง (กะทำงาน, เวลาสาย, OT ...) เก็บเป็น JSON
    /// </summary>
    public static partial class OeeDb
    {
        static bool _taTables;

        static DbConnection TaOpen()
        {
            DbConnection c = HrOpen();
            if (_taTables) return c;
            try
            {
                Cmd(c, null, @"CREATE TABLE IF NOT EXISTS hr_punch (
                                  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                                  scan_id    VARCHAR(20)  NOT NULL COMMENT 'รหัสในเครื่องสแกน (เช่น 104 = U-0104)',
                                  punch_at   DATETIME     NOT NULL,
                                  source     VARCHAR(10)  NOT NULL DEFAULT 'scanner' COMMENT 'scanner / manual',
                                  is_void    TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '1 = ไม่นับ (HR กดยกเลิก)',
                                  scan_name  VARCHAR(80)  NULL COMMENT 'ชื่อในเครื่องสแกน',
                                  scan_dept  VARCHAR(40)  NULL COMMENT 'แผนกในเครื่องสแกน',
                                  note       VARCHAR(200) NULL,
                                  created_at DATETIME     NULL,
                                  created_by VARCHAR(40)  NULL,
                                  PRIMARY KEY (id),
                                  UNIQUE KEY ux_scan_time (scan_id, punch_at),
                                  KEY ix_time (punch_at)
                               ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
                Cmd(c, null, @"CREATE TABLE IF NOT EXISTS hr_setting (
                                  k          VARCHAR(40)   NOT NULL,
                                  v          TEXT          NULL,
                                  updated_at DATETIME      NULL,
                                  updated_by VARCHAR(40)   NULL,
                                  PRIMARY KEY (k)
                               ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
                Cmd(c, null, @"CREATE TABLE IF NOT EXISTS hr_shift_plan (
                                  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                                  emp_code   VARCHAR(20)  NOT NULL,
                                  shift_code VARCHAR(10)  NOT NULL COMMENT 'รหัสกะใน Settings (D, N, D02 ...)',
                                  date_from  DATE         NOT NULL,
                                  date_to    DATE         NULL COMMENT 'ว่าง = จนกว่าจะเปลี่ยน',
                                  note       VARCHAR(200) NULL,
                                  created_at DATETIME     NULL,
                                  created_by VARCHAR(40)  NULL,
                                  PRIMARY KEY (id),
                                  KEY ix_emp (emp_code, date_from)
                               ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
                _taTables = true;
            }
            catch { c.Dispose(); throw; }
            return c;
        }

        // ------------------------------------------------------------ ค่าตั้ง
        public static TaConfig TaConfigGet()
        {
            using (DbConnection c = TaOpen())
            {
                object v = Cmd(c, null, "SELECT v FROM hr_setting WHERE k = 'ta_config'").ExecuteScalar();
                TaConfig cfg = null;
                if (v != null && v != DBNull.Value)
                    try { cfg = new JavaScriptSerializer().Deserialize<TaConfig>(Convert.ToString(v)); } catch { }
                return TaConfig.Fix(cfg);
            }
        }

        public static void TaConfigSet(TaConfig cfg, string user, string ip)
        {
            cfg = TaConfig.Fix(cfg);
            string json = new JavaScriptSerializer().Serialize(cfg);
            using (DbConnection c = TaOpen())
            {
                Cmd(c, null, @"INSERT INTO hr_setting (k, v, updated_at, updated_by) VALUES ('ta_config', @v, NOW(), @u)
                               ON DUPLICATE KEY UPDATE v = VALUES(v), updated_at = NOW(), updated_by = VALUES(updated_by)", "@v", json, "@u", user).ExecuteNonQuery();
                HrLog(c, user, "ta-settings", null, json, ip);
            }
        }

        // ------------------------------------------------------------ แผนกะ (เปลี่ยนกะ)
        public static List<TaPlan> TaPlans(string empCode)
        {
            var list = new List<TaPlan>();
            using (DbConnection c = TaOpen())
            using (DbDataReader r = (string.IsNullOrEmpty(empCode)
                        ? Cmd(c, null, "SELECT * FROM hr_shift_plan")
                        : Cmd(c, null, "SELECT * FROM hr_shift_plan WHERE emp_code = @e ORDER BY date_from DESC, id DESC", "@e", empCode)).ExecuteReader())
                while (r.Read())
                {
                    string code = Convert.ToString(r["emp_code"]);
                    list.Add(new TaPlan
                    {
                        Id = Convert.ToInt64(r["id"], CultureInfo.InvariantCulture), EmpCode = code, Scan = TaCalc.ScanKey(code),
                        ShiftCode = Convert.ToString(r["shift_code"]),
                        From = Convert.ToDateTime(r["date_from"], CultureInfo.InvariantCulture).Date,
                        To = r["date_to"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(r["date_to"], CultureInfo.InvariantCulture).Date,
                        Note = r["note"] == DBNull.Value ? "" : Convert.ToString(r["note"]),
                        By = r["created_by"] == DBNull.Value ? "" : Convert.ToString(r["created_by"]),
                        CreatedAt = r["created_at"] == DBNull.Value ? DateTime.MinValue : Convert.ToDateTime(r["created_at"], CultureInfo.InvariantCulture),
                    });
                }
            return list;
        }

        /// <summary>เปลี่ยนกะให้หลายคนพร้อมกัน · to = null : ตั้งแต่ from เป็นต้นไป · มี to : ชั่วคราวช่วงนั้น แล้วกลับไปกะเดิม</summary>
        public static int TaPlanAdd(List<string> empCodes, string shiftCode, DateTime from, DateTime? to, string note, string user, string ip)
        {
            if (empCodes == null || empCodes.Count == 0) throw new Exception("ยังไม่ได้เลือกพนักงาน");
            if (string.IsNullOrWhiteSpace(shiftCode)) throw new Exception("ยังไม่ได้เลือกกะ");
            if (to.HasValue && to.Value < from) throw new Exception("วันสิ้นสุดต้องไม่ก่อนวันเริ่ม");
            int n = 0;
            using (DbConnection c = TaOpen())
            {
                foreach (string code in empCodes.Where(x => !string.IsNullOrWhiteSpace(x)).Distinct(StringComparer.OrdinalIgnoreCase))
                {
                    // เปลี่ยนถาวรซ้ำวันเดิม = แทนของเดิม (ไม่ให้แผนซ้อนกันเต็มไปหมด)
                    if (!to.HasValue)
                        Cmd(c, null, "DELETE FROM hr_shift_plan WHERE emp_code = @e AND date_from = @f AND date_to IS NULL", "@e", code.Trim(), "@f", from).ExecuteNonQuery();
                    n += Cmd(c, null, "INSERT INTO hr_shift_plan (emp_code, shift_code, date_from, date_to, note, created_at, created_by) VALUES (@e, @s, @f, @t, @n, NOW(), @u)",
                             "@e", code.Trim(), "@s", shiftCode.Trim(), "@f", from, "@t", to, "@n", NullIfEmpty(Cut(note, 200)), "@u", user).ExecuteNonQuery();
                }
                HrLog(c, user, "shift-plan", shiftCode, n + " people · " + from.ToString("yyyy-MM-dd") + (to.HasValue ? " to " + to.Value.ToString("yyyy-MM-dd") : " onward") +
                      (string.IsNullOrEmpty(note) ? "" : " · " + note), ip);
            }
            return n;
        }

        public static void TaPlanDelete(long id, string user, string ip)
        {
            using (DbConnection c = TaOpen())
            {
                string info = null;
                using (DbDataReader r = Cmd(c, null, "SELECT emp_code, shift_code, date_from FROM hr_shift_plan WHERE id = @id", "@id", id).ExecuteReader())
                    if (r.Read()) info = r.GetString(0) + " " + r.GetString(1) + " from " + Convert.ToDateTime(r.GetValue(2)).ToString("yyyy-MM-dd");
                if (info == null) return;
                Cmd(c, null, "DELETE FROM hr_shift_plan WHERE id = @id", "@id", id).ExecuteNonQuery();
                HrLog(c, user, "shift-plan-delete", null, info, ip);
            }
        }

        // ------------------------------------------------------------ เวลาสแกน
        public static List<TaPunch> TaPunches(DateTime from, DateTime to)
        {
            var list = new List<TaPunch>();
            using (DbConnection c = TaOpen())
            using (DbDataReader r = Cmd(c, null, "SELECT * FROM hr_punch WHERE punch_at >= @a AND punch_at < @b ORDER BY scan_id, punch_at",
                                        "@a", from, "@b", to).ExecuteReader())
                while (r.Read())
                    list.Add(new TaPunch
                    {
                        Id = Convert.ToInt64(r["id"], CultureInfo.InvariantCulture),
                        ScanId = Convert.ToString(r["scan_id"]),
                        At = Convert.ToDateTime(r["punch_at"], CultureInfo.InvariantCulture),
                        Source = Convert.ToString(r["source"]),
                        Void = Convert.ToInt32(r["is_void"], CultureInfo.InvariantCulture) != 0,
                        ScanName = r["scan_name"] == DBNull.Value ? "" : Convert.ToString(r["scan_name"]),
                        ScanDept = r["scan_dept"] == DBNull.Value ? "" : Convert.ToString(r["scan_dept"]),
                        Note = r["note"] == DBNull.Value ? "" : Convert.ToString(r["note"]),
                        By = r["created_by"] == DBNull.Value ? "" : Convert.ToString(r["created_by"]),
                    });
            return list;
        }

        /// <summary>ช่วงวันที่ที่มีข้อมูลสแกน (null = ยังไม่มี)</summary>
        public static DateTime?[] TaRange()
        {
            using (DbConnection c = TaOpen())
            using (DbDataReader r = Cmd(c, null, "SELECT MIN(punch_at), MAX(punch_at), COUNT(*) FROM hr_punch").ExecuteReader())
            {
                if (!r.Read() || r.IsDBNull(0)) return new DateTime?[] { null, null };
                return new DateTime?[] { Convert.ToDateTime(r.GetValue(0)), Convert.ToDateTime(r.GetValue(1)) };
            }
        }

        /// <summary>วันที่ที่มีข้อมูลสแกนแล้ว (นำเข้าไฟล์แล้ว)</summary>
        public static HashSet<DateTime> TaDataDays(DateTime from, DateTime to)
        {
            var set = new HashSet<DateTime>();
            using (DbConnection c = TaOpen())
            using (DbDataReader r = Cmd(c, null, "SELECT DISTINCT DATE(punch_at) FROM hr_punch WHERE is_void = 0 AND punch_at >= @a AND punch_at < @b", "@a", from, "@b", to).ExecuteReader())
                while (r.Read()) set.Add(Convert.ToDateTime(r.GetValue(0)).Date);
            return set;
        }

        /// <summary>สแกนล่าสุดของแต่ละรหัส ในช่วง [from, to) (ไม่นับที่ยกเลิก)</summary>
        public static Dictionary<string, DateTime> TaLastScan(DateTime from, DateTime to)
        {
            var map = new Dictionary<string, DateTime>();
            using (DbConnection c = TaOpen())
            using (DbDataReader r = Cmd(c, null, "SELECT scan_id, MAX(punch_at) FROM hr_punch WHERE is_void = 0 AND punch_at >= @a AND punch_at < @b GROUP BY scan_id",
                                        "@a", from, "@b", to).ExecuteReader())
                while (r.Read()) map[r.GetString(0)] = Convert.ToDateTime(r.GetValue(1));
            return map;
        }

        /// <summary>เวลาสแกนที่มีอยู่แล้ว (ใช้ตอนตรวจไฟล์ก่อนนำเข้า) key = scan_id|yyyy-MM-dd HH:mm:ss</summary>
        public static HashSet<string> TaExistingKeys(DateTime from, DateTime to)
        {
            var set = new HashSet<string>();
            foreach (var p in TaPunches(from, to)) set.Add(p.Key);
            return set;
        }

        /// <summary>บันทึกเวลาสแกนจากไฟล์ (ซ้ำ = ข้าม) · คืนจำนวนที่เพิ่มจริง</summary>
        public static int TaPunchInsertMany(List<TaPunch> punches, string user, string ip, string fileName)
        {
            int added = 0;
            using (DbConnection c = TaOpen())
            {
                for (int i = 0; i < punches.Count; i += 200)
                {
                    var part = punches.Skip(i).Take(200).ToList();
                    var args = new List<object>(); var vals = new List<string>();
                    for (int k = 0; k < part.Count; k++)
                    {
                        vals.Add("(@s" + k + ", @t" + k + ", 'scanner', @n" + k + ", @d" + k + ", NOW(), @u)");
                        args.Add("@s" + k); args.Add(part[k].ScanId);
                        args.Add("@t" + k); args.Add(part[k].At);
                        args.Add("@n" + k); args.Add(NullIfEmpty(Cut(part[k].ScanName, 80)));
                        args.Add("@d" + k); args.Add(NullIfEmpty(Cut(part[k].ScanDept, 40)));
                    }
                    args.Add("@u"); args.Add(user);
                    added += Cmd(c, null, "INSERT IGNORE INTO hr_punch (scan_id, punch_at, source, scan_name, scan_dept, created_at, created_by) VALUES " +
                                          string.Join(", ", vals), args.ToArray()).ExecuteNonQuery();
                }
                HrLog(c, user, "ta-import", null, fileName + " : " + added + " new of " + punches.Count, ip);
            }
            return added;
        }

        static string Cut(string s, int n) { return s != null && s.Length > n ? s.Substring(0, n) : s; }

        /// <summary>HR เพิ่มเวลาเอง (ลืมสแกน / เครื่องเสีย) ต้องมีเหตุผล</summary>
        public static void TaPunchAddManual(string scanId, DateTime at, string note, string user, string ip)
        {
            if (string.IsNullOrWhiteSpace(scanId)) throw new Exception("missing scan id");
            if (string.IsNullOrWhiteSpace(note)) throw new Exception("กรุณาใส่เหตุผล");
            using (DbConnection c = TaOpen())
            {
                object dup = Cmd(c, null, "SELECT id FROM hr_punch WHERE scan_id = @s AND punch_at = @t", "@s", scanId, "@t", at).ExecuteScalar();
                if (dup != null)
                {
                    Cmd(c, null, "UPDATE hr_punch SET is_void = 0, note = @n WHERE id = @id", "@n", Cut(note, 200), "@id", dup).ExecuteNonQuery();
                }
                else
                    Cmd(c, null, "INSERT INTO hr_punch (scan_id, punch_at, source, note, created_at, created_by) VALUES (@s, @t, 'manual', @n, NOW(), @u)",
                        "@s", scanId, "@t", at, "@n", Cut(note, 200), "@u", user).ExecuteNonQuery();
                HrLog(c, user, "ta-punch-add", scanId, at.ToString("yyyy-MM-dd HH:mm") + " · " + note, ip);
            }
        }

        /// <summary>ยกเลิก / คืนค่า เวลาสแกน 1 ครั้ง (ไม่ลบจริง เก็บประวัติไว้) · เวลาที่ HR เพิ่มเอง = ลบจริง</summary>
        public static void TaPunchVoid(long id, bool isVoid, string note, string user, string ip)
        {
            using (DbConnection c = TaOpen())
            {
                string scan = null, src = null; DateTime at = DateTime.MinValue;
                using (DbDataReader r = Cmd(c, null, "SELECT scan_id, punch_at, source FROM hr_punch WHERE id = @id", "@id", id).ExecuteReader())
                    if (r.Read()) { scan = r.GetString(0); at = Convert.ToDateTime(r.GetValue(1)); src = r.GetString(2); }
                if (scan == null) throw new Exception("ไม่พบรายการ");
                if (src == "manual" && isVoid)
                    Cmd(c, null, "DELETE FROM hr_punch WHERE id = @id", "@id", id).ExecuteNonQuery();
                else
                    Cmd(c, null, "UPDATE hr_punch SET is_void = @v, note = COALESCE(@n, note) WHERE id = @id",
                        "@v", isVoid ? 1 : 0, "@n", NullIfEmpty(Cut(note, 200)), "@id", id).ExecuteNonQuery();
                HrLog(c, user, isVoid ? "ta-punch-void" : "ta-punch-restore", scan, at.ToString("yyyy-MM-dd HH:mm") + (string.IsNullOrEmpty(note) ? "" : " · " + note), ip);
            }
        }
    }
}
