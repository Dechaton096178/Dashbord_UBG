using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;

namespace Dashbord
{
    /// <summary>
    /// ระบบแจ้งซ่อม (Maintenance.aspx) — ตารางใน MySQL OEE (สร้างเองครั้งแรก)
    ///   mt_request : 1 แถว = 1 ใบแจ้งซ่อม · สถานะ open (รอรับ) → doing (กำลังซ่อม) → done (ซ่อมเสร็จ รอปิด) → closed (ปิดงาน) · cancel
    ///   mt_photo   : รูปก่อนซ่อม (before) / หลังซ่อม (after) เก็บเป็น BLOB
    /// </summary>
    public static partial class OeeDb
    {
        static bool _mtTable;
        public static readonly string[] MT_STATUS = { "open", "doing", "done", "closed", "cancel" };

        public class MtRow
        {
            public long Id; public string No, Machine, MachineName, Process, Location, Category, Problem, Priority, Reporter, Status, Technician, Cause, Action, ClosedBy, CloseNote;
            public bool Stop; public DateTime Created; public DateTime? Accepted, Done, Closed, Reminded;
            public int PhotoBefore, PhotoAfter;
        }

        static void EnsureMt(DbConnection c)
        {
            if (_mtTable) return;
            Cmd(c, null, @"CREATE TABLE IF NOT EXISTS mt_request (
                id INT AUTO_INCREMENT PRIMARY KEY,
                req_no VARCHAR(20) NULL,
                created_at DATETIME NOT NULL,
                machine_code VARCHAR(40) NULL,
                machine_name VARCHAR(120) NULL,
                process VARCHAR(40) NULL,
                location VARCHAR(120) NULL,
                category VARCHAR(30) NULL,
                problem TEXT NULL,
                priority VARCHAR(10) NOT NULL DEFAULT 'normal',
                machine_stop TINYINT NOT NULL DEFAULT 0,
                reporter VARCHAR(80) NULL,
                reporter_ip VARCHAR(45) NULL,
                status VARCHAR(12) NOT NULL DEFAULT 'open',
                accepted_at DATETIME NULL,
                technician VARCHAR(120) NULL,
                done_at DATETIME NULL,
                cause TEXT NULL,
                action_taken TEXT NULL,
                closed_at DATETIME NULL,
                closed_by VARCHAR(80) NULL,
                close_note TEXT NULL,
                remind_at DATETIME NULL,
                updated_at DATETIME NULL,
                KEY ix_status (status), KEY ix_created (created_at), KEY ix_machine (machine_code)
            ) DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
            Cmd(c, null, @"CREATE TABLE IF NOT EXISTS mt_photo (
                id INT AUTO_INCREMENT PRIMARY KEY,
                req_id INT NOT NULL,
                kind VARCHAR(10) NOT NULL,
                mime VARCHAR(30) NOT NULL,
                data MEDIUMBLOB NOT NULL,
                created_at DATETIME NOT NULL,
                KEY ix_req (req_id)
            ) DEFAULT CHARSET=utf8mb4").ExecuteNonQuery();
            _mtTable = true;
        }

        static DbConnection MtOpen()
        {
            if (!Init()) throw new Exception(LastError ?? "DB not configured");
            DbConnection c = Open();
            EnsureMt(c);
            return c;
        }

        const string MT_COLS = @"r.id, r.req_no, r.created_at, r.machine_code, r.machine_name, r.process, r.location, r.category, r.problem, r.priority, r.machine_stop,
                                 r.reporter, r.status, r.accepted_at, r.technician, r.done_at, r.cause, r.action_taken, r.closed_at, r.closed_by, r.close_note, r.remind_at,
                                 (SELECT COUNT(*) FROM mt_photo p WHERE p.req_id = r.id AND p.kind = 'before') AS pb,
                                 (SELECT COUNT(*) FROM mt_photo p WHERE p.req_id = r.id AND p.kind = 'after') AS pa";

        static MtRow MtRead(DbDataReader rd)
        {
            Func<int, string> S = i => rd.IsDBNull(i) ? null : Convert.ToString(rd.GetValue(i));
            Func<int, DateTime?> T = i => rd.IsDBNull(i) ? (DateTime?)null : Convert.ToDateTime(rd.GetValue(i));
            return new MtRow
            {
                Id = Convert.ToInt64(rd.GetValue(0)), No = S(1), Created = Convert.ToDateTime(rd.GetValue(2)), Machine = S(3), MachineName = S(4), Process = S(5),
                Location = S(6), Category = S(7), Problem = S(8), Priority = S(9), Stop = !rd.IsDBNull(10) && Convert.ToInt32(rd.GetValue(10)) != 0,
                Reporter = S(11), Status = S(12), Accepted = T(13), Technician = S(14), Done = T(15), Cause = S(16), Action = S(17), Closed = T(18),
                ClosedBy = S(19), CloseNote = S(20), Reminded = T(21), PhotoBefore = Convert.ToInt32(rd.GetValue(22)), PhotoAfter = Convert.ToInt32(rd.GetValue(23))
            };
        }

        /// <summary>รายการแจ้งซ่อม : งานที่ยังไม่ปิดทั้งหมด + งานที่แจ้งในช่วง from–to (ปิดแล้ว / ยกเลิก)</summary>
        public static List<MtRow> MtList(DateTime from, DateTime to)
        {
            var list = new List<MtRow>();
            using (DbConnection c = MtOpen())
            using (DbDataReader rd = Cmd(c, null, "SELECT " + MT_COLS + @" FROM mt_request r
                     WHERE r.status IN ('open','doing','done') OR (r.created_at >= @f AND r.created_at < @t)
                     ORDER BY r.id DESC LIMIT 2000", "@f", from, "@t", to).ExecuteReader())
                while (rd.Read()) list.Add(MtRead(rd));
            return list;
        }

        /// <summary>ใบแจ้งซ่อมที่แจ้งในช่วง from–to (ใช้คำนวณ Dashboard)</summary>
        public static List<MtRow> MtRange(DateTime from, DateTime to)
        {
            var list = new List<MtRow>();
            using (DbConnection c = MtOpen())
            using (DbDataReader rd = Cmd(c, null, "SELECT " + MT_COLS + " FROM mt_request r WHERE r.created_at >= @f AND r.created_at < @t AND r.status <> 'cancel'",
                                         "@f", from, "@t", to).ExecuteReader())
                while (rd.Read()) list.Add(MtRead(rd));
            return list;
        }

        public static MtRow MtGet(long id)
        {
            using (DbConnection c = MtOpen())
            using (DbDataReader rd = Cmd(c, null, "SELECT " + MT_COLS + " FROM mt_request r WHERE r.id = @id", "@id", id).ExecuteReader())
                return rd.Read() ? MtRead(rd) : null;
        }

        public static List<object> MtPhotos(long id)
        {
            var list = new List<object>();
            using (DbConnection c = MtOpen())
            using (DbDataReader rd = Cmd(c, null, "SELECT id, kind, created_at FROM mt_photo WHERE req_id = @id ORDER BY id", "@id", id).ExecuteReader())
                while (rd.Read()) list.Add(new { id = Convert.ToInt64(rd.GetValue(0)), kind = rd.GetString(1), at = Convert.ToDateTime(rd.GetValue(2)).ToString("yyyy-MM-dd HH:mm") });
            return list;
        }

        public static byte[] MtPhotoGet(long photoId, out string mime)
        {
            mime = null;
            using (DbConnection c = MtOpen())
            using (DbDataReader rd = Cmd(c, null, "SELECT mime, data FROM mt_photo WHERE id = @id", "@id", photoId).ExecuteReader())
            {
                if (!rd.Read()) return null;
                mime = rd.GetString(0);
                return (byte[])rd.GetValue(1);
            }
        }

        public static void MtPhotoPut(long reqId, string kind, string mime, byte[] data)
        {
            using (DbConnection c = MtOpen())
                Cmd(c, null, "INSERT INTO mt_photo (req_id, kind, mime, data, created_at) VALUES (@r, @k, @m, @d, @t)",
                    "@r", reqId, "@k", kind, "@m", mime, "@d", data, "@t", DateTime.Now).ExecuteNonQuery();
        }

        /// <summary>สร้างใบแจ้งซ่อม · คืน id (เลขที่ = MT + id 5 หลัก)</summary>
        public static long MtCreate(MtRow r, string ip)
        {
            using (DbConnection c = MtOpen())
            {
                DateTime now = DateTime.Now;
                Cmd(c, null, @"INSERT INTO mt_request (created_at, machine_code, machine_name, process, location, category, problem, priority, machine_stop, reporter, reporter_ip, status, updated_at)
                               VALUES (@t, @mc, @mn, @p, @l, @c, @pr, @pri, @s, @rep, @ip, 'open', @t)",
                    "@t", now, "@mc", r.Machine, "@mn", r.MachineName, "@p", r.Process, "@l", r.Location, "@c", r.Category, "@pr", r.Problem,
                    "@pri", r.Priority, "@s", r.Stop ? 1 : 0, "@rep", r.Reporter, "@ip", ip).ExecuteNonQuery();
                long id = Convert.ToInt64(Cmd(c, null, "SELECT LAST_INSERT_ID()").ExecuteScalar());
                Cmd(c, null, "UPDATE mt_request SET req_no = @n WHERE id = @id", "@n", "MT" + id.ToString("00000"), "@id", id).ExecuteNonQuery();
                return id;
            }
        }

        /// <summary>เปลี่ยนสถานะ / บันทึกผล · คืนจำนวนแถวที่แก้ (0 = สถานะเดิมไม่ตรง)</summary>
        public static int MtSet(long id, string set, string where, params object[] nameValues)
        {
            using (DbConnection c = MtOpen())
            {
                var args = new List<object>(nameValues) { "@id", id, "@now", DateTime.Now };
                return Cmd(c, null, "UPDATE mt_request SET " + set + ", updated_at = @now WHERE id = @id" + (string.IsNullOrEmpty(where) ? "" : " AND (" + where + ")"),
                           args.ToArray()).ExecuteNonQuery();
            }
        }

        /// <summary>งานด่วนที่ยังไม่มีคนรับเกิน minutes นาที และยังไม่เคยเตือน</summary>
        public static List<MtRow> MtDueReminders(int minutes)
        {
            var list = new List<MtRow>();
            if (!Init()) return list;
            using (DbConnection c = MtOpen())
            using (DbDataReader rd = Cmd(c, null, "SELECT " + MT_COLS + @" FROM mt_request r
                     WHERE r.status = 'open' AND r.priority = 'urgent' AND r.remind_at IS NULL AND r.created_at <= @t AND r.created_at >= @t2",
                     "@t", DateTime.Now.AddMinutes(-minutes), "@t2", DateTime.Now.AddDays(-2)).ExecuteReader())
                while (rd.Read()) list.Add(MtRead(rd));
            return list;
        }

        /// <summary>รายชื่อเครื่องสำหรับเลือกตอนแจ้งซ่อม / ทำ QR (ตาราง machine + เครื่องที่เคยแจ้ง)</summary>
        public static List<Dictionary<string, object>> MtMachines()
        {
            var map = new Dictionary<string, Dictionary<string, object>>(StringComparer.OrdinalIgnoreCase);
            using (DbConnection c = MtOpen())
            {
                try
                {
                    using (DbDataReader rd = Cmd(c, null, "SELECT machine_code, process, machine_no FROM machine ORDER BY process, machine_code").ExecuteReader())
                        while (rd.Read())
                        {
                            string mc = rd.GetString(0);
                            map[mc] = new Dictionary<string, object> { { "code", mc }, { "process", rd.IsDBNull(1) ? "" : rd.GetString(1) }, { "no", rd.IsDBNull(2) ? "" : Convert.ToString(rd.GetValue(2)) } };
                        }
                }
                catch { }   // ไม่มีตาราง machine ก็ยังแจ้งซ่อมได้ (พิมพ์ชื่อเครื่องเอง)
                using (DbDataReader rd = Cmd(c, null, "SELECT DISTINCT machine_code, process, machine_name FROM mt_request WHERE machine_code IS NOT NULL AND machine_code <> ''").ExecuteReader())
                    while (rd.Read())
                    {
                        string mc = rd.GetString(0);
                        if (!map.ContainsKey(mc)) map[mc] = new Dictionary<string, object> { { "code", mc }, { "process", rd.IsDBNull(1) ? "" : rd.GetString(1) }, { "no", rd.IsDBNull(2) ? "" : rd.GetString(2) } };
                    }
            }
            return map.Values.ToList();
        }
    }
}
