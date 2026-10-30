using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;

namespace Dashbord
{
    /// <summary>
    /// Maintenance.aspx — ระบบแจ้งซ่อม (แผนก Maintenance)
    ///   ขั้นตอน : แจ้งซ่อม (ทุกคน) → รับงาน (ช่าง ใส่ PIN) → ซ่อมเสร็จ (ช่าง ใส่ PIN + สาเหตุ / วิธีแก้ / รูปหลังซ่อม) → ปิดงาน (ผู้แจ้งยืนยัน) · ไม่ผ่าน = ส่งกลับไปซ่อมต่อ
    ///   LINE : ปิดอยู่ (LINE_NEW = false, URGENT_MIN = 0) · เปิดได้ที่ค่าตั้งค่าด้านล่าง
    ///   GET  ?format=list&from=&to=   งานค้างทั้งหมด + งานในช่วงวันที่
    ///   GET  ?format=get&id=          รายละเอียด + รายการรูป
    ///   GET  ?format=photo&id=        รูป (id ของรูป)
    ///   GET  ?format=machines         รายชื่อเครื่อง (ใช้เลือกตอนแจ้ง / ทำ QR)
    ///   GET  ?format=dash&from=&to=&proc=   MTTR / MTBF / Top เครื่องเสีย / แนวโน้มรายเดือน
    ///   POST ?format=create {machine, machineName, process, location, category, problem, priority, stop, reporter, photos:[dataUrl]}
    ///   POST ?format=checkpin {pin} · accept {pin, id, tech} · done {pin, id, cause, action, photos} · cancel {pin, id, by}
    ///   POST ?format=close {id, by, note} · reopen {id, by, note}   (ผู้แจ้งยืนยัน ไม่ต้องใช้ PIN)
    ///   ลิงก์ QR ติดเครื่อง : Maintenance.aspx?mc=MC13 → เปิดฟอร์มแจ้งซ่อมเครื่องนั้นทันที
    /// </summary>
    public partial class Maintenance : Page
    {
        // ===================== ตั้งค่า =====================
        public const string TECH_PIN = "ubg2026";           // รหัสช่าง (รับงาน / ซ่อมเสร็จ / ยกเลิก)
        public const string LINE_TO = "ALL";                // ALL = broadcast ทุกคนที่แอด OA · หรือ User ID / Group ID (U... / C...)
        public const bool LINE_NEW = false;                 // แจ้ง LINE เมื่อมีงานใหม่ (ปิดไว้ 2026-10-30 ตามที่ขอ · เปลี่ยนเป็น true เพื่อเปิด)
        public const int URGENT_MIN = 0;                    // งานด่วนยังไม่มีคนรับเกินกี่นาที -> เตือน LINE อีกครั้ง (0 = ไม่เตือน · ปิดไว้ 2026-10-30 · เปิดใช้ใส่ 15)
        public const string PAGE_URL = "http://192.168.100.20/Dashboard/Maintenance.aspx";
        const int MAX_PHOTOS = 3, MAX_PHOTO_BYTES = 3 * 1024 * 1024;
        // ==================================================

        static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        static System.Threading.Timer _remind;
        static readonly object RemindSync = new object();
        string _apiOutput;

        protected string JsVer { get { return FileVer("files/Maintenance.js") + "-" + FileVer("files/Maintenance.css"); } }
        string FileVer(string rel) { try { return File.GetLastWriteTime(Server.MapPath("~/" + rel)).ToString("yyMMddHHmmss"); } catch { return "1"; } }
        protected string ProcessJson { get { return Json.Serialize(AppMenu.Processes); } }

        protected void Page_Load(object sender, EventArgs e)
        {
            StartReminder();
            string fmt = (Request.QueryString["format"] ?? "").ToLowerInvariant();
            if (fmt == "") return;
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            try
            {
                if (Request.HttpMethod == "GET")
                {
                    if (fmt == "photo") { SendPhoto(); return; }
                    if (fmt == "list") { Reply(200, List()); return; }
                    if (fmt == "get") { Reply(200, Get(ToId(Request.QueryString["id"]))); return; }
                    if (fmt == "machines") { Reply(200, Machines()); return; }
                    if (fmt == "dash") { Reply(200, Dash()); return; }
                    Reply(400, new { ok = false, error = "unknown format" }); return;
                }
                if (Request.HttpMethod != "POST") { Reply(405, new { ok = false, error = "method not allowed" }); return; }
                string body;
                using (var r = new StreamReader(Request.InputStream, Encoding.UTF8)) body = r.ReadToEnd();
                var d = Json.Deserialize<Dictionary<string, object>>(body) ?? new Dictionary<string, object>();
                long id = ToId(Str(d, "id"));
                bool pinOk = TECH_PIN.Length == 0 || Str(d, "pin") == TECH_PIN;
                Func<bool> needPin = () => { if (pinOk) return true; Reply(403, new { ok = false, error = "รหัสช่างไม่ถูกต้อง / Wrong PIN" }); return false; };

                if (fmt == "create") { Reply(200, Create(d)); return; }
                if (fmt == "checkpin") { if (needPin()) Reply(200, new { ok = true }); return; }
                if (fmt == "accept")
                {
                    if (!needPin()) return;
                    string tech = Need(Str(d, "tech"), "กรุณาใส่ชื่อช่าง");
                    int n = OeeDb.MtSet(id, "status = 'doing', accepted_at = @now, technician = @tech", "status = 'open'", "@tech", Cut(tech, 120));
                    Reply(n > 0 ? 200 : 409, n > 0 ? (object)new { ok = true } : new { ok = false, error = "งานนี้มีคนรับไปแล้ว / สถานะเปลี่ยนแล้ว" }); return;
                }
                if (fmt == "done")
                {
                    if (!needPin()) return;
                    string action = Need(Str(d, "action"), "กรุณาใส่วิธีแก้ไข / สิ่งที่ทำ");
                    string tech = Str(d, "tech");
                    int n = OeeDb.MtSet(id, "status = 'done', done_at = @now, cause = @cause, action_taken = @act, technician = COALESCE(NULLIF(@tech, ''), technician), " +
                                            "accepted_at = COALESCE(accepted_at, @now)", "status IN ('open','doing')",
                                        "@cause", Cut(Str(d, "cause"), 2000), "@act", Cut(action, 2000), "@tech", Cut(tech ?? "", 120));
                    if (n == 0) { Reply(409, new { ok = false, error = "สถานะงานเปลี่ยนแล้ว" }); return; }
                    SavePhotos(id, "after", d);
                    Reply(200, new { ok = true }); return;
                }
                if (fmt == "cancel")
                {
                    if (!needPin()) return;
                    int n = OeeDb.MtSet(id, "status = 'cancel', closed_at = @now, closed_by = @by, close_note = @note", "status IN ('open','doing')",
                                        "@by", Cut(Str(d, "by") ?? "", 80), "@note", Cut(Str(d, "note") ?? "ยกเลิก", 1000));
                    Reply(n > 0 ? 200 : 409, n > 0 ? (object)new { ok = true } : new { ok = false, error = "ยกเลิกไม่ได้ (สถานะเปลี่ยนแล้ว)" }); return;
                }
                if (fmt == "close")
                {
                    string by = Need(Str(d, "by"), "กรุณาใส่ชื่อผู้ปิดงาน");
                    int n = OeeDb.MtSet(id, "status = 'closed', closed_at = @now, closed_by = @by, close_note = @note", "status = 'done'",
                                        "@by", Cut(by, 80), "@note", Cut(Str(d, "note") ?? "", 1000));
                    Reply(n > 0 ? 200 : 409, n > 0 ? (object)new { ok = true } : new { ok = false, error = "ปิดงานได้เฉพาะงานที่ซ่อมเสร็จแล้ว" }); return;
                }
                if (fmt == "reopen")
                {
                    string by = Need(Str(d, "by"), "กรุณาใส่ชื่อ");
                    string note = Need(Str(d, "note"), "กรุณาบอกว่ายังเสียอย่างไร");
                    int n = OeeDb.MtSet(id, "status = 'doing', done_at = NULL, close_note = CONCAT(COALESCE(close_note, ''), @note)", "status = 'done'",
                                        "@note", Cut("[" + DateTime.Now.ToString("dd/MM HH:mm") + " ส่งกลับโดย " + by + "] " + note + "\n", 1000));
                    Reply(n > 0 ? 200 : 409, n > 0 ? (object)new { ok = true } : new { ok = false, error = "สถานะงานเปลี่ยนแล้ว" }); return;
                }
                Reply(400, new { ok = false, error = "unknown format" });
            }
            catch (UserError ex) { Reply(400, new { ok = false, error = ex.Message }); }
            catch (Exception ex) { Reply(500, new { ok = false, error = ex.Message }); }
        }

        // ------------------------------------------------------------ แจ้งซ่อม
        object Create(Dictionary<string, object> d)
        {
            var r = new OeeDb.MtRow
            {
                Machine = Cut(Str(d, "machine"), 40), MachineName = Cut(Str(d, "machineName"), 120), Process = Cut(Str(d, "process"), 40),
                Location = Cut(Str(d, "location"), 120), Category = Cut(Str(d, "category"), 30),
                Problem = Cut(Need(Str(d, "problem"), "กรุณาใส่อาการเสีย"), 2000),
                Priority = Str(d, "priority") == "urgent" ? "urgent" : "normal",
                Stop = Str(d, "stop") == "1" || string.Equals(Str(d, "stop"), "true", StringComparison.OrdinalIgnoreCase),
                Reporter = Cut(Need(Str(d, "reporter"), "กรุณาใส่ชื่อผู้แจ้ง"), 80)
            };
            if (string.IsNullOrEmpty(r.Machine) && string.IsNullOrEmpty(r.MachineName)) throw new UserError("กรุณาเลือกเครื่อง / ใส่ชื่ออุปกรณ์");
            if (string.IsNullOrEmpty(r.MachineName)) r.MachineName = Name(r.Machine);
            long id = OeeDb.MtCreate(r, Request.UserHostAddress);
            SavePhotos(id, "before", d);
            r.Id = id; r.No = "MT" + id.ToString("00000"); r.Created = DateTime.Now;
            if (LINE_NEW) SendLineAsync(LineText(r, false));
            return new { ok = true, id, no = r.No };
        }

        void SavePhotos(long id, string kind, Dictionary<string, object> d)
        {
            var arr = d.ContainsKey("photos") ? d["photos"] as System.Collections.ArrayList : null;
            if (arr == null) return;
            int n = 0;
            foreach (object o in arr)
            {
                string data = o as string;
                if (string.IsNullOrEmpty(data) || ++n > MAX_PHOTOS) continue;
                int comma = data.IndexOf(',');
                string head = comma > 0 ? data.Substring(0, comma) : "";
                string mime = head.Contains("image/png") ? "image/png" : head.Contains("image/webp") ? "image/webp" : "image/jpeg";
                byte[] bytes = Convert.FromBase64String(comma >= 0 ? data.Substring(comma + 1) : data);
                if (bytes.Length > MAX_PHOTO_BYTES) throw new UserError("รูปใหญ่เกิน 3 MB");
                OeeDb.MtPhotoPut(id, kind, mime, bytes);
            }
        }

        void SendPhoto()
        {
            string mime;
            byte[] b = OeeDb.MtPhotoGet(ToId(Request.QueryString["id"]), out mime);
            if (b == null) { Response.StatusCode = 404; Response.End(); return; }
            Response.Clear();
            Response.ContentType = mime;
            Response.Cache.SetCacheability(HttpCacheability.Private);
            Response.Cache.SetMaxAge(TimeSpan.FromDays(30));
            Response.BinaryWrite(b);
            Response.End();
        }

        // ------------------------------------------------------------ อ่านข้อมูล
        static string Fmt(DateTime? t) { return t.HasValue ? t.Value.ToString("yyyy-MM-dd HH:mm:ss") : null; }
        static double? Min(DateTime? a, DateTime? b) { return a.HasValue && b.HasValue ? Math.Round((b.Value - a.Value).TotalMinutes, 1) : (double?)null; }

        static Dictionary<string, object> Row(OeeDb.MtRow r)
        {
            return new Dictionary<string, object> {
                { "id", r.Id }, { "no", r.No }, { "created", Fmt(r.Created) }, { "machine", r.Machine }, { "machineName", r.MachineName }, { "process", r.Process },
                { "location", r.Location }, { "category", r.Category }, { "problem", r.Problem }, { "priority", r.Priority }, { "stop", r.Stop }, { "reporter", r.Reporter },
                { "status", r.Status }, { "accepted", Fmt(r.Accepted) }, { "technician", r.Technician }, { "done", Fmt(r.Done) }, { "cause", r.Cause }, { "action", r.Action },
                { "closed", Fmt(r.Closed) }, { "closedBy", r.ClosedBy }, { "closeNote", r.CloseNote }, { "photoBefore", r.PhotoBefore }, { "photoAfter", r.PhotoAfter },
                { "waitMin", Min(r.Created, r.Accepted) }, { "repairMin", Min(r.Accepted, r.Done) }, { "totalMin", Min(r.Created, r.Done) } };
        }

        object List()
        {
            DateTime to = Day(Request.QueryString["to"], DateTime.Today).AddDays(1), from = Day(Request.QueryString["from"], DateTime.Today.AddDays(-30));
            var rows = OeeDb.MtList(from, to);
            return new { ok = true, now = Fmt(DateTime.Now), from = from.ToString("yyyy-MM-dd"), to = to.AddDays(-1).ToString("yyyy-MM-dd"),
                         pinRequired = TECH_PIN.Length > 0, rows = rows.Select(Row).ToList() };
        }

        object Get(long id)
        {
            var r = OeeDb.MtGet(id);
            if (r == null) return new { ok = false, error = "ไม่พบใบแจ้งซ่อม" };
            return new { ok = true, row = Row(r), photos = OeeDb.MtPhotos(id) };
        }

        static string Name(string mc)
        {
            if (string.IsNullOrEmpty(mc)) return "";
            string eq = ErpQuality.EqidFor(mc);
            return string.IsNullOrEmpty(eq) || string.Equals(eq, mc, StringComparison.OrdinalIgnoreCase) ? mc : eq;
        }

        object Machines()
        {
            var list = OeeDb.MtMachines();
            foreach (var m in list) m["name"] = Name(Convert.ToString(m["code"]));
            return new { ok = true, machines = list.OrderBy(m => Convert.ToString(m["process"])).ThenBy(m => Convert.ToString(m["name"]), StringComparer.OrdinalIgnoreCase).ToList() };
        }

        // ------------------------------------------------------------ Dashboard : MTTR / MTBF / Top เครื่องเสีย
        //   MTTR (นาที) = เวลาตั้งแต่แจ้ง → ซ่อมเสร็จ เฉลี่ย · รอช่าง = แจ้ง → รับงาน · เวลาซ่อม = รับงาน → เสร็จ
        //   MTBF (ชม.) ต่อเครื่อง = (ชั่วโมงในช่วงที่เลือก − เวลาเครื่องหยุดจากงานซ่อม) ÷ จำนวนครั้งที่เสีย
        object Dash()
        {
            DateTime to = Day(Request.QueryString["to"], DateTime.Today).AddDays(1), from = Day(Request.QueryString["from"], DateTime.Today.AddDays(-29));
            if (to > DateTime.Today.AddDays(1)) to = DateTime.Today.AddDays(1);
            string proc = Request.QueryString["proc"];
            var all = OeeDb.MtRange(from, to);
            if (!string.IsNullOrEmpty(proc) && proc != "All") all = all.Where(r => string.Equals(r.Process, proc, StringComparison.OrdinalIgnoreCase)).ToList();
            DateTime now = DateTime.Now, end = to < now ? to : now;
            double spanH = Math.Max(1, (end - from).TotalHours);
            Func<OeeDb.MtRow, double> downMin = r => r.Stop ? ((r.Done ?? now) - r.Created).TotalMinutes : 0;
            Func<IEnumerable<double>, double?> avg = xs => { var l = xs.ToList(); return l.Count > 0 ? Math.Round(l.Average(), 1) : (double?)null; };
            var fixedRows = all.Where(r => r.Done.HasValue).ToList();

            var byMc = all.GroupBy(r => string.IsNullOrEmpty(r.Machine) ? "~" + (r.MachineName ?? "") : r.Machine, StringComparer.OrdinalIgnoreCase)
                .Select(g =>
                {
                    double down = g.Sum(downMin);
                    var f = g.Where(r => r.Done.HasValue).ToList();
                    return new Dictionary<string, object> {
                        { "machine", g.First().Machine }, { "name", g.First().MachineName }, { "process", g.First().Process }, { "count", g.Count() },
                        { "downMin", Math.Round(down, 0) }, { "mttr", avg(f.Select(r => (r.Done.Value - r.Created).TotalMinutes)) },
                        { "mtbf", Math.Round(Math.Max(0, spanH - down / 60) / g.Count(), 1) },
                        { "open", g.Count(r => r.Status == "open" || r.Status == "doing") } };
                })
                .OrderByDescending(x => (int)x["count"]).ThenByDescending(x => (double)x["downMin"]).ToList();

            var byCat = all.GroupBy(r => string.IsNullOrEmpty(r.Category) ? "Other" : r.Category)
                .Select(g => new { category = g.Key, count = g.Count(), downMin = Math.Round(g.Sum(downMin), 0) }).OrderByDescending(x => x.count).ToList();

            // แนวโน้มรายเดือน 12 เดือนล่าสุด (ไม่ขึ้นกับช่วงที่เลือก)
            DateTime m0 = new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1).AddMonths(-11);
            var yr = OeeDb.MtRange(m0, DateTime.Today.AddDays(1));
            if (!string.IsNullOrEmpty(proc) && proc != "All") yr = yr.Where(r => string.Equals(r.Process, proc, StringComparison.OrdinalIgnoreCase)).ToList();
            var months = Enumerable.Range(0, 12).Select(i =>
            {
                DateTime a = m0.AddMonths(i), b = a.AddMonths(1);
                var g = yr.Where(r => r.Created >= a && r.Created < b).ToList();
                var f = g.Where(r => r.Done.HasValue).ToList();
                return new { month = a.ToString("yyyy-MM"), count = g.Count, urgent = g.Count(r => r.Priority == "urgent"),
                             mttr = avg(f.Select(r => (r.Done.Value - r.Created).TotalMinutes)), downMin = Math.Round(g.Sum(downMin), 0) };
            }).ToList();

            int cnt = all.Count;
            return new
            {
                ok = true, from = from.ToString("yyyy-MM-dd"), to = to.AddDays(-1).ToString("yyyy-MM-dd"), process = proc ?? "All", now = Fmt(now),
                total = new
                {
                    count = cnt, open = all.Count(r => r.Status == "open"), doing = all.Count(r => r.Status == "doing"), done = all.Count(r => r.Status == "done"),
                    closed = all.Count(r => r.Status == "closed"), urgent = all.Count(r => r.Priority == "urgent"), stop = all.Count(r => r.Stop),
                    mttr = avg(fixedRows.Select(r => (r.Done.Value - r.Created).TotalMinutes)),
                    wait = avg(all.Where(r => r.Accepted.HasValue).Select(r => (r.Accepted.Value - r.Created).TotalMinutes)),
                    repair = avg(fixedRows.Where(r => r.Accepted.HasValue).Select(r => (r.Done.Value - r.Accepted.Value).TotalMinutes)),
                    downMin = Math.Round(all.Sum(downMin), 0),
                    mtbf = byMc.Count > 0 ? Math.Round(byMc.Average(x => (double)x["mtbf"]), 1) : (double?)null
                },
                machines = byMc.Take(15).ToList(), categories = byCat, months,
                techs = fixedRows.Where(r => !string.IsNullOrEmpty(r.Technician)).GroupBy(r => r.Technician)
                    .Select(g => new { tech = g.Key, count = g.Count(), repair = avg(g.Where(r => r.Accepted.HasValue).Select(r => (r.Done.Value - r.Accepted.Value).TotalMinutes)) })
                    .OrderByDescending(x => x.count).Take(10).ToList()
            };
        }

        // ------------------------------------------------------------ LINE
        static string LineText(OeeDb.MtRow r, bool reminder)
        {
            var sb = new StringBuilder();
            if (reminder) sb.Append("⏰ งานด่วนยังไม่มีช่างรับ " + URGENT_MIN + " นาทีแล้ว\n");
            sb.Append(r.Priority == "urgent" ? "🚨 แจ้งซ่อมด่วน " : "🔧 แจ้งซ่อม ").Append(r.No).Append('\n');
            sb.Append("เครื่อง: ").Append(string.IsNullOrEmpty(r.MachineName) ? r.Machine : r.MachineName);
            if (!string.IsNullOrEmpty(r.Process)) sb.Append(" (").Append(r.Process).Append(')');
            sb.Append('\n');
            if (!string.IsNullOrEmpty(r.Location)) sb.Append("ตำแหน่ง: ").Append(r.Location).Append('\n');
            sb.Append("อาการ: ").Append(r.Problem).Append('\n');
            if (!string.IsNullOrEmpty(r.Category)) sb.Append("ประเภท: ").Append(r.Category).Append('\n');
            if (r.Stop) sb.Append("⛔ เครื่องหยุด\n");
            sb.Append("ผู้แจ้ง: ").Append(r.Reporter).Append(" · ").Append(r.Created.ToString("dd/MM HH:mm")).Append('\n');
            sb.Append(PAGE_URL).Append("?id=").Append(r.Id);
            return sb.ToString();
        }

        static void SendLineAsync(string text)
        {
            ThreadPool.QueueUserWorkItem(_ =>
            {
                try { string detail; LineAert_Water.SendLineMessage(LINE_TO, text, out detail); }
                catch { }   // ไม่มี token / ส่งไม่ได้ -> ข้าม (งานซ่อมยังบันทึกปกติ)
            });
        }

        /// <summary>เริ่มตัวตรวจงานด่วนค้าง (ทุก 1 นาที) · เรียกจากหน้านี้และ CounterMachine.aspx (Node-RED ส่งข้อมูลตลอด เว็บจึงตื่นอยู่)</summary>
        public static void StartReminder()
        {
            if (_remind != null || URGENT_MIN <= 0) return;
            lock (RemindSync)
            {
                if (_remind != null) return;
                _remind = new System.Threading.Timer(delegate { CheckReminders(); }, null, 30000, 60000);
            }
        }

        static int _checking;
        static void CheckReminders()
        {
            if (Interlocked.Exchange(ref _checking, 1) == 1) return;
            try
            {
                foreach (var r in OeeDb.MtDueReminders(URGENT_MIN))
                {
                    if (OeeDb.MtSet(r.Id, "remind_at = @now", "remind_at IS NULL") > 0) SendLineAsync(LineText(r, true));
                }
            }
            catch { }
            finally { Interlocked.Exchange(ref _checking, 0); }
        }

        // ------------------------------------------------------------ ตัวช่วย
        class UserError : Exception { public UserError(string m) : base(m) { } }
        static string Need(string s, string err) { if (string.IsNullOrWhiteSpace(s)) throw new UserError(err); return s.Trim(); }
        static string Cut(string s, int n) { if (s == null) return null; s = s.Trim(); return s.Length > n ? s.Substring(0, n) : s; }
        static long ToId(string s) { long v; return long.TryParse(s, out v) ? v : 0; }
        static DateTime Day(string s, DateTime def)
        {
            DateTime d;
            return DateTime.TryParseExact(s ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? d.Date : def.Date;
        }
        static string Str(Dictionary<string, object> d, string k)
        {
            object v; if (!d.TryGetValue(k, out v) || v == null) return null;
            if (v is bool) return (bool)v ? "1" : "0";
            return Convert.ToString(v, CultureInfo.InvariantCulture);
        }

        void Reply(int code, object body)
        {
            Response.StatusCode = code;
            Response.TrySkipIisCustomErrors = true;
            Response.ContentType = "application/json; charset=utf-8";
            _apiOutput = Json.Serialize(body);
        }

        protected override void Render(HtmlTextWriter writer)
        {
            if (_apiOutput != null) writer.Write(_apiOutput);
            else base.Render(writer);
        }
    }
}
