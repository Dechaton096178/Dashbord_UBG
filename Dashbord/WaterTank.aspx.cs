using System;
using System.Collections.Generic;
using System.Configuration;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using System.Threading;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;

namespace Dashbord
{
    /// <summary>
    /// WaterTank.aspx — ถังน้ำ (Relay ระดับน้ำ 3 ตัว → 4 ระดับ) + แจ้งเตือน LINE
    ///   Relay1 = EMPTY (DI1) · Relay2 = MID (DI2) · Relay3 = FULL (DI3)
    ///     ติด ติด ติด = full (เต็ม) · ติด ติด ดับ = normal (ปกติ) · ติด ดับ ดับ = low (ใกล้หมด) · ดับ ดับ ดับ = empty (หมด) · แบบอื่น = fault
    ///   POST (JSON) {"tank":"Water1","level":"full|normal|low|empty|fault","di1":1,"di2":1,"di3":0}   ← Node-RED ส่งเมื่อเปลี่ยน + ทุก 60 วิ
    ///               {"test":true,"notify":false,...}  ← ปุ่มจำลองบนหน้า (?test=1) ไม่ส่ง LINE ถ้า notify=false
    ///   GET ?format=json&tank=Water1&day=yyyy-MM-dd   → สถานะ + ประวัติของวัน (00:00-24:00)
    ///   แจ้ง LINE (ALL = ทุกคนที่แอด OA) :
    ///     - น้ำหมด (ครั้งเดียว ไม่แจ้งซ้ำจนกว่าจะเติม)       - ใกล้หมด (ลดจาก ปกติ/เต็ม → ใกล้หมด)
    ///     - มีน้ำแล้ว (กลับมาปกติ/เต็ม หลังจากแจ้งน้ำหมด)    - Relay ผิดปกติ (สัญญาณไม่เรียงลำดับ)
    ///     - สรุปประจำวัน DAILY_HOUR:00 (ส่งตอน Node-RED ส่งค่าเข้ามาครั้งแรกหลังเวลานั้น)
    ///     - เรื่องเดียวกันไม่แจ้งซ้ำภายใน REPEAT_MIN นาที (กันลูกลอยกระเพื่อม)
    /// </summary>
    public partial class WaterTank : Page
    {
        // ===================== ตั้งค่า =====================
        public const string DEFAULT_TANK = "Water1";
        public const string TANK_NAME = "ถังน้ำ";              // ชื่อที่แสดงในข้อความ LINE
        public const string LINE_TO = "ALL";                   // ALL = broadcast ทุกคนที่แอด OA · หรือใส่ User ID (U...)
        public const int DAILY_HOUR = 8;                       // ส่งสรุปประจำวันกี่โมง (-1 = ไม่ส่ง)
        public const bool ALERT_LOW = true;                    // แจ้งตอนใกล้หมด
        public const bool ALERT_REFILL = true;                 // แจ้งตอนมีน้ำกลับมา (ปกติ/เต็ม หลังจากแจ้งน้ำหมด)
        public const int REPEAT_MIN = 60;                      // เรื่องเดียวกันห้ามแจ้งซ้ำภายในกี่นาที
        public const int OFFLINE_SEC = 180;                    // ไม่มีข้อมูลเกินกี่วินาที = ออฟไลน์
        public const string PAGE_URL = "http://192.168.100.20/Dashboard/WaterTank.aspx";
        // ==================================================

        static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        static readonly object Sync = new object();
        static new readonly Dictionary<string, OeeDb.WaterState> Cache = new Dictionary<string, OeeDb.WaterState>(StringComparer.OrdinalIgnoreCase);
        static object _quota; static DateTime _quotaAt = DateTime.MinValue;
        string _apiOutput;

        protected void Page_Load(object sender, EventArgs e)
        {
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            string method = Request.HttpMethod.ToUpperInvariant();
            try
            {
                if (method == "POST") { HandlePost(); return; }
                if (method == "GET" && string.Equals(Request.QueryString["format"], "json", StringComparison.OrdinalIgnoreCase)) { Reply(200, Report()); return; }
            }
            catch (Exception ex) { Reply(500, new { ok = false, error = ex.Message }); }
        }

        // ------------------------------------------------------------ รับค่าจาก Node-RED
        void HandlePost()
        {
            if (CounterStore.API_KEY.Length > 0 && Request.Headers["X-Api-Key"] != CounterStore.API_KEY)
            { Reply(401, new { ok = false, error = "invalid api key" }); return; }
            string body;
            using (var r = new StreamReader(Request.InputStream, Encoding.UTF8)) body = r.ReadToEnd();
            Dictionary<string, object> d;
            try { d = Json.Deserialize<Dictionary<string, object>>(body); }
            catch (Exception ex) { Reply(400, new { ok = false, error = "bad json: " + ex.Message }); return; }
            if (d == null) { Reply(400, new { ok = false, error = "empty body" }); return; }

            string tank = Clean(Str(d, "tank")); if (string.IsNullOrEmpty(tank)) tank = DEFAULT_TANK;
            string level = NormLevel(Str(d, "level"));
            if (level == null) { Reply(400, new { ok = false, error = "level ต้องเป็น full / normal / low / empty / fault" }); return; }
            bool test = IsTrue(Str(d, "test"));
            bool notify = !test || IsTrue(Str(d, "notify"));
            int? di1 = ToBit(Str(d, "di1")), di2 = ToBit(Str(d, "di2")), di3 = ToBit(Str(d, "di3"));

            var sends = new List<LineAlert>();
            DateTime now = DateTime.Now;
            string prev;
            lock (Sync)
            {
                OeeDb.WaterState st;
                if (!Cache.TryGetValue(tank, out st)) { st = OeeDb.WaterLoad(tank); Cache[tank] = st; }
                prev = st.Level;
                st.LastSeen = now; st.Di1 = di1; st.Di2 = di2; st.Di3 = di3;

                if (level != st.Level)
                {
                    st.Level = level; st.Since = now;
                    OeeDb.WaterAddEvent(tank, now, "level", level, prev, null, test ? "test" : null);
                    if (prev != null)   // ค่าแรกหลังเริ่มระบบ ไม่แจ้ง
                    {
                        Func<string, LineAlert> mk = t => new LineAlert { Type = t, Level = level, D1 = di1, D2 = di2, D3 = di3, At = now };
                        if (level == "empty")
                            Queue(st, sends, mk("empty"), now);
                        else if (level == "low" && (prev == "normal" || prev == "full") && ALERT_LOW)
                            Queue(st, sends, mk("low"), now);
                        else if ((level == "normal" || level == "full") && st.AlertType == "empty" && ALERT_REFILL)
                        {
                            var a = mk("refill");
                            if (st.AlertAt.HasValue) { a.NoteTh = "น้ำหมดอยู่ " + Span(now - st.AlertAt.Value, true); a.NoteEn = "Was empty for " + Span(now - st.AlertAt.Value, false); }
                            Queue(st, sends, a, now);
                        }
                        else if (level == "fault")
                            Queue(st, sends, mk("fault"), now);
                        if ((level == "normal" || level == "full") && st.AlertType == "empty") st.AlertType = "refill";   // มีน้ำแล้ว = รอบหน้าน้ำหมดจะแจ้งใหม่ได้
                    }
                }

                // สรุปประจำวัน (ส่งครั้งเดียวต่อวัน ภายใน 4 ชม. หลังเวลาที่ตั้ง)
                string today = now.ToString("yyyy-MM-dd");
                if (!test && DAILY_HOUR >= 0 && now.Hour >= DAILY_HOUR && now.Hour < DAILY_HOUR + 4 && st.DailyDay != today)
                {
                    st.DailyDay = today;
                    sends.Add(DailyAlert(tank, st, now));
                }
                OeeDb.WaterSave(st);
            }

            if (notify)
                foreach (var s in sends)
                {
                    var item = s; string t = tank;
                    ThreadPool.QueueUserWorkItem(delegate { SendLine(t, item); });
                }
            Reply(200, new { ok = true, tank = tank, level = level, prev = prev, alerts = sends.ConvertAll(x => x.Type), notify = notify });
        }

        public class LineAlert { public string Type, Level, NoteTh, NoteEn; public int? D1, D2, D3; public DateTime At; }

        static void Queue(OeeDb.WaterState st, List<LineAlert> sends, LineAlert a, DateTime now)
        {
            string type = a.Type;
            bool same = st.AlertType == type || (type == "low" && st.AlertType == "empty");
            if (same && st.AlertAt.HasValue && (now - st.AlertAt.Value).TotalMinutes < REPEAT_MIN) return;   // กันแจ้งซ้ำ
            if (type == "empty" && st.AlertType == "empty") return;                                          // น้ำหมด แจ้งครั้งเดียวจนกว่าจะเติมเต็ม
            sends.Add(a);
            st.AlertType = type; st.AlertAt = now;
        }

        static LineAlert DailyAlert(string tank, OeeDb.WaterState st, DateTime now)
        {
            int empty = 0, low = 0, refill = 0; string before;
            try
            {
                foreach (var e in OeeDb.WaterEvents(tank, now.AddDays(-1), now, out before))
                {
                    if ((string)e["kind"] != "level") continue;
                    string l = (string)e["level"], p = (string)e["prev"];
                    if (l == "empty") empty++;
                    else if (l == "low" && (p == "normal" || p == "full")) low++;
                    else if ((l == "normal" || l == "full") && (p == "empty" || p == "low")) refill++;
                }
            }
            catch { }
            return new LineAlert {
                Type = "daily", Level = st.Level, D1 = st.Di1, D2 = st.Di2, D3 = st.Di3, At = now,
                NoteTh = "24 ชม.ที่ผ่านมา: หมด " + empty + " · ใกล้หมด " + low + " · เติม " + refill + " ครั้ง",
                NoteEn = "Last 24 h: empty " + empty + " · low " + low + " · refill " + refill };
        }

        // ------------------------------------------------------------ ข้อความ LINE (Flex = รูปถังน้ำ + ไทย/อังกฤษ)
        static readonly Dictionary<string, string[]> LV_TXT = new Dictionary<string, string[]> {
            //            ไทย        อังกฤษ     % น้ำในรูป
            { "full",   new[] { "เต็ม",     "FULL",   "92" } },
            { "normal", new[] { "ปกติ",     "NORMAL", "62" } },
            { "low",    new[] { "ใกล้หมด",  "LOW",    "28" } },
            { "empty",  new[] { "หมด",      "EMPTY",  "4"  } },
            { "fault",  new[] { "ผิดปกติ",  "FAULT",  "50" } } };
        static readonly Dictionary<string, string[]> TYPE_TXT = new Dictionary<string, string[]> {
            //            สีหัว       ไอคอน  ข้อความไทย                              ข้อความอังกฤษ
            { "empty",  new[] { "#dc2626", "🚨", "น้ำหมด! กรุณาเติมน้ำด่วน",           "Tank is EMPTY! Please refill now" } },
            { "low",    new[] { "#d97706", "⚠️", "น้ำใกล้หมด เตรียมเติมน้ำ",           "Water is LOW, prepare to refill" } },
            { "refill", new[] { "#16a34a", "✅", "มีน้ำแล้ว",                          "Water is back" } },
            { "fault",  new[] { "#7c3aed", "⚠️", "สัญญาณ Relay ผิดปกติ ตรวจสอบเซนเซอร์/สายไฟ", "Relay signal fault, check sensors/wiring" } },
            { "daily",  new[] { "#0284c7", "💧", "รายงานประจำวัน",                     "Daily report" } } };

        static Dictionary<string, object> Txt(string t, string size, string color, bool bold = false, bool wrap = true)
        {
            var d = new Dictionary<string, object> { { "type", "text" }, { "text", string.IsNullOrEmpty(t) ? " " : t }, { "size", size }, { "wrap", wrap } };
            if (color != null) d["color"] = color;
            if (bold) d["weight"] = "bold";
            return d;
        }
        static Dictionary<string, object> Box(string layout, params object[] contents)
        {
            return new Dictionary<string, object> { { "type", "box" }, { "layout", layout }, { "contents", new List<object>(contents) } };
        }
        static Dictionary<string, object> With(Dictionary<string, object> d, params object[] kv)
        {
            for (int i = 0; i + 1 < kv.Length; i += 2) d[(string)kv[i]] = kv[i + 1];
            return d;
        }

        public static string BuildFlex(LineAlert a, out string altText)
        {
            string[] tt = TYPE_TXT.ContainsKey(a.Type) ? TYPE_TXT[a.Type] : TYPE_TXT["daily"];
            string[] lv = a.Level != null && LV_TXT.ContainsKey(a.Level) ? LV_TXT[a.Level] : new[] { "-", "NO DATA", "0" };
            int pct = int.Parse(lv[2], CultureInfo.InvariantCulture);
            string water = a.Level == "fault" ? "#cbd5e1" : "#38bdf8";

            // รูปถัง : กล่องสูง 150px ข้างบนว่าง ข้างล่างน้ำสีฟ้า ตามสัดส่วน
            var tank = With(Box("vertical",
                                With(Box("vertical", new Dictionary<string, object> { { "type", "filler" } }), "flex", Math.Max(1, 100 - pct)),
                                With(Box("vertical", new Dictionary<string, object> { { "type", "filler" } }), "flex", Math.Max(1, pct), "backgroundColor", water)),
                            "width", "70px", "height", "150px", "borderWidth", "3px", "borderColor", "#64748b",
                            "cornerRadius", "14px", "backgroundColor", "#f1f5f9", "flex", 0);

            Func<string, int?, Dictionary<string, object>> relay = (name, v) =>
                Box("baseline", Txt(v == 1 ? "●" : "○", "sm", v == 1 ? "#16a34a" : "#94a3b8", false, false),
                                With(Txt(name + (v == 1 ? "  ติด / ON" : v == 0 ? "  ดับ / OFF" : "  -"), "xs", "#475569", false, false), "margin", "sm"));

            var info = new List<object> {
                Txt("ระดับ / Level", "xxs", "#94a3b8"),
                Txt(lv[0] + " · " + lv[1], "xl", tt[0], true),
                With(Txt(tt[2], "sm", "#0f172a", true), "margin", "md"),
                Txt(tt[3], "xs", "#64748b") };
            if (!string.IsNullOrEmpty(a.NoteTh)) { info.Add(With(Txt(a.NoteTh, "xs", "#0f172a"), "margin", "sm")); info.Add(Txt(a.NoteEn, "xxs", "#64748b")); }
            info.Add(With(new Dictionary<string, object> { { "type", "separator" } }, "margin", "md"));
            info.Add(With(relay("FULL (R3)", a.D3), "margin", "md"));
            info.Add(relay("MID (R2)", a.D2));
            info.Add(relay("EMPTY (R1)", a.D1));

            var bubble = new Dictionary<string, object> {
                { "type", "bubble" }, { "size", "mega" },
                { "header", With(Box("vertical",
                                     Txt(tt[1] + " " + TANK_NAME + " · Water Tank", "sm", "#ffffff", true),
                                     Txt(a.At.ToString("dd/MM/yyyy HH:mm", CultureInfo.InvariantCulture), "xs", "#ffffffcc")),
                                 "backgroundColor", tt[0], "paddingAll", "14px") },
                { "body", With(Box("horizontal", tank, With(Box("vertical", info.ToArray()), "flex", 1, "paddingStart", "14px")),
                               "paddingAll", "16px") },
                { "footer", With(Box("vertical",
                                     new Dictionary<string, object> { { "type", "button" }, { "style", "link" }, { "height", "sm" },
                                         { "action", new Dictionary<string, object> { { "type", "uri" }, { "label", "ดู Dashboard / Open dashboard" }, { "uri", PAGE_URL } } } }),
                                 "paddingAll", "4px") }
            };
            altText = tt[1] + " " + TANK_NAME + ": " + tt[2] + " / Water Tank: " + tt[3] + " (" + lv[0] + " · " + lv[1] + ") " + a.At.ToString("HH:mm");
            if (altText.Length > 390) altText = altText.Substring(0, 390);
            var msg = new Dictionary<string, object> { { "type", "flex" }, { "altText", altText }, { "contents", bubble } };
            return Json.Serialize(new object[] { msg });
        }

        static void SendLine(string tank, LineAlert a)
        {
            string detail, alt = a.Type; bool ok;
            try
            {
                string flex = BuildFlex(a, out alt);
                ok = LineAert_Water.SendLineRaw(LINE_TO, flex, out detail);
                if (!ok && detail.StartsWith("HTTP 400"))   // Flex ไม่ผ่าน -> ส่งเป็นข้อความธรรมดาแทน
                {
                    string d1 = detail;
                    ok = LineAert_Water.SendLineMessage(LINE_TO, alt + (string.IsNullOrEmpty(a.NoteTh) ? "" : "\n" + a.NoteTh + " / " + a.NoteEn) + "\n" + PAGE_URL, out detail);
                    detail = "flex failed (" + d1 + ") → text " + (ok ? "OK" : detail);
                }
            }
            catch (Exception ex) { ok = false; detail = ex.Message; }
            OeeDb.WaterAddEvent(tank, DateTime.Now, "line", a.Level, a.Type, ok, (ok ? (detail.StartsWith("flex failed") ? detail + " · " : "") : "ERROR " + detail + " · ") + alt);
        }

        static string Span(TimeSpan t, bool th)
        {
            int h = (int)t.TotalHours, m = t.Minutes;
            return th ? (h > 0 ? h + " ชม. " : "") + m + " นาที" : (h > 0 ? h + " h " : "") + m + " min";
        }

        // ------------------------------------------------------------ ข้อมูลให้หน้าเว็บ
        Dictionary<string, object> Report()
        {
            string tank = Clean(Request.QueryString["tank"]); if (string.IsNullOrEmpty(tank)) tank = DEFAULT_TANK;
            DateTime now = DateTime.Now, day;
            if (!DateTime.TryParseExact(Request.QueryString["day"] ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out day)) day = now.Date;
            OeeDb.WaterState st;
            lock (Sync) { if (!Cache.TryGetValue(tank, out st)) { st = OeeDb.WaterLoad(tank); Cache[tank] = st; } }
            string before;
            var ev = OeeDb.WaterEvents(tank, day, day.AddDays(1), out before);
            double? age = st.LastSeen.HasValue ? (now - st.LastSeen.Value).TotalSeconds : (double?)null;
            return new Dictionary<string, object> {
                { "ok", true }, { "tank", tank }, { "name", TANK_NAME }, { "now", now.ToString("yyyy-MM-dd HH:mm:ss") },
                { "day", day.ToString("yyyy-MM-dd") },
                { "level", st.Level }, { "since", Fmt(st.Since) }, { "lastSeen", Fmt(st.LastSeen) },
                { "ageSec", age.HasValue ? (object)Math.Round(age.Value) : null }, { "online", age.HasValue && age.Value < OFFLINE_SEC },
                { "di1", st.Di1 }, { "di2", st.Di2 }, { "di3", st.Di3 },
                { "alertType", st.AlertType }, { "alertAt", Fmt(st.AlertAt) },
                { "levelBefore", before }, { "events", ev },
                { "lineMonth", OeeDb.WaterLineCountMonth(tank) }, { "quota", Quota() },
                { "cfg", new Dictionary<string, object> { { "dailyHour", DAILY_HOUR }, { "alertLow", ALERT_LOW }, { "alertRefill", ALERT_REFILL },
                                                          { "repeatMin", REPEAT_MIN }, { "to", LINE_TO } } }
            };
        }

        // โควตาข้อความ LINE ของเดือนนี้ (ถาม LINE ทุก 10 นาที)
        static object Quota()
        {
            if (_quota != null && (DateTime.Now - _quotaAt).TotalMinutes < 10) return _quota;
            string token = ConfigurationManager.AppSettings["LineChannelAccessToken"];
            if (string.IsNullOrWhiteSpace(token)) return null;
            try
            {
                ServicePointManager.SecurityProtocol |= (SecurityProtocolType)3072;
                var limit = Json.Deserialize<Dictionary<string, object>>(LineGet("https://api.line.me/v2/bot/message/quota", token));
                var used = Json.Deserialize<Dictionary<string, object>>(LineGet("https://api.line.me/v2/bot/message/quota/consumption", token));
                object v;
                _quota = new Dictionary<string, object> {
                    { "type", limit.TryGetValue("type", out v) ? v : null }, { "limit", limit.TryGetValue("value", out v) ? v : null },
                    { "used", used.TryGetValue("totalUsage", out v) ? v : null } };
            }
            catch (Exception ex) { _quota = new Dictionary<string, object> { { "error", ex.Message } }; }
            _quotaAt = DateTime.Now;
            return _quota;
        }

        static string LineGet(string url, string token)
        {
            var req = (HttpWebRequest)WebRequest.Create(url);
            req.Headers.Add("Authorization", "Bearer " + token.Trim());
            req.Timeout = 8000;
            using (var res = (HttpWebResponse)req.GetResponse())
            using (var sr = new StreamReader(res.GetResponseStream(), Encoding.UTF8)) return sr.ReadToEnd();
        }

        // ------------------------------------------------------------ helpers
        static string NormLevel(string s)
        {
            switch ((s ?? "").Trim().ToLowerInvariant())
            {
                case "full": case "high": case "3": case "เต็ม": return "full";
                case "normal": case "mid": case "middle": case "2": case "ปกติ": return "normal";
                case "low": case "near_empty": case "1": case "ใกล้หมด": return "low";
                case "empty": case "0": case "หมด": return "empty";
                case "fault": case "error": case "ผิดปกติ": return "fault";
                default: return null;
            }
        }
        public static string LevelTh(string l)
        {
            return l == "full" ? "เต็ม" : l == "normal" ? "ปกติ" : l == "low" ? "ใกล้หมด" : l == "empty" ? "หมด" : l == "fault" ? "Relay ผิดปกติ" : "-";
        }
        static string OnOff(int? v) { return v == 1 ? "ติด" : v == 0 ? "ดับ" : "?"; }
        static string Duration(string pre, DateTime? from, DateTime? to, string post)
        {
            if (!from.HasValue) return "";
            if (!to.HasValue) return pre + from.Value.ToString(from.Value.Date == DateTime.Today ? "HH:mm" : "dd/MM HH:mm") + post;
            TimeSpan t = to.Value - from.Value;
            return pre + (t.TotalHours >= 1 ? (int)t.TotalHours + " ชม. " : "") + t.Minutes + " นาที" + post;
        }
        static string Fmt(DateTime? t) { return t.HasValue ? t.Value.ToString("yyyy-MM-dd HH:mm:ss") : null; }
        static bool IsTrue(string s) { return s != null && (s.Equals("true", StringComparison.OrdinalIgnoreCase) || s == "1"); }
        static int? ToBit(string s)
        {
            if (string.IsNullOrEmpty(s)) return null;
            return s == "1" || s.Equals("true", StringComparison.OrdinalIgnoreCase) || s.Equals("on", StringComparison.OrdinalIgnoreCase) ? 1 : 0;
        }
        static string Str(Dictionary<string, object> d, string k)
        {
            object o; return d.TryGetValue(k, out o) && o != null ? Convert.ToString(o, CultureInfo.InvariantCulture).Trim() : null;
        }
        static string Clean(string s)
        {
            if (string.IsNullOrEmpty(s)) return s;
            var sb = new StringBuilder();
            foreach (char ch in s) if (char.IsLetterOrDigit(ch) || ch == '-' || ch == '_' || ch == '.') sb.Append(ch);
            return sb.Length > 40 ? sb.ToString(0, 40) : sb.ToString();
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
