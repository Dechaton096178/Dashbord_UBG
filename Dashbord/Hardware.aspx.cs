using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net.NetworkInformation;
using System.Text;
using System.Threading.Tasks;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;
using System.Xml;

namespace Dashbord
{
    /// <summary>
    /// Hardware.aspx — รายการอุปกรณ์ IT (Raspberry pi, IOT BOX, ...) · เพิ่ม / แก้ไข / ลบ / นำเข้า Excel / เช็ค Online (Ping)
    ///   GET  ?format=list                       รายการทั้งหมด
    ///   GET  ?format=ping                       Ping ทุก IP จาก Server (เก็บผลไว้ 20 วินาที)
    ///   GET  ?format=csv                        ดาวน์โหลด CSV (เปิดด้วย Excel ได้)
    ///   POST ?format=checkpin {pin}
    ///   POST ?format=save     {pin, id, name, ...}
    ///   POST ?format=delete   {pin, id}
    ///   POST ?format=import   {pin, name, data(base64), commit}   ตรวจ (commit=false) / นำเข้า (commit=true)
    ///   ข้อมูลอยู่ใน MySQL OEE : it_hardware (สร้าง + นำเข้าข้อมูลตั้งต้นเองครั้งแรก)
    /// </summary>
    public partial class Hardware : Page
    {
        // ===================== ตั้งค่า =====================
        public const string EDIT_PIN = "ubg2026";     // รหัสสำหรับแก้ไข / Import (ว่าง = ใครก็แก้ได้)
        const int PING_TIMEOUT_MS = 1000;
        const int PING_CACHE_SEC = 20;
        // ==================================================

        static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        string _apiOutput;

        protected string HardwareVer
        {
            get
            {
                long t = 0;
                foreach (string f in new[] { "~/files/Hardware.js", "~/files/Hardware.css" })
                    try { t = Math.Max(t, File.GetLastWriteTimeUtc(Server.MapPath(f)).Ticks); } catch { }
                return (t / 10000000).ToString(CultureInfo.InvariantCulture);
            }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            string fmt = (Request.QueryString["format"] ?? "").ToLowerInvariant();
            if (fmt == "") return;
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            try
            {
                if (Request.HttpMethod == "GET")
                {
                    if (fmt == "list") { Reply(200, new { ok = true, rows = OeeDb.HwList(), pinRequired = EDIT_PIN.Length > 0 }); return; }
                    if (fmt == "ping") { Reply(200, new { ok = true, at = DateTime.Now.ToString("HH:mm:ss"), result = PingAll(Request.QueryString["force"] == "1") }); return; }
                    if (fmt == "csv") { SendCsv(); return; }
                    Reply(400, new { ok = false, error = "unknown format" }); return;
                }
                if (Request.HttpMethod != "POST") { Reply(405, new { ok = false, error = "method not allowed" }); return; }

                string body;
                using (var r = new StreamReader(Request.InputStream, Encoding.UTF8)) body = r.ReadToEnd();
                var d = Json.Deserialize<Dictionary<string, object>>(body) ?? new Dictionary<string, object>();
                if (EDIT_PIN.Length > 0 && Str(d, "pin") != EDIT_PIN) { Reply(403, new { ok = false, error = "รหัสแก้ไขไม่ถูกต้อง / Wrong PIN" }); return; }
                string ip = Request.UserHostAddress;
                int id; int.TryParse(Str(d, "id"), out id);

                if (fmt == "checkpin") Reply(200, new { ok = true });
                else if (fmt == "save")
                {
                    var v = new Dictionary<string, string>();
                    foreach (string f in OeeDb.HW_FIELDS) v[f] = Str(d, f);
                    id = OeeDb.HwSave(id, v, ip);
                    Reply(200, new { ok = true, id = id });
                }
                else if (fmt == "delete")
                {
                    if (id <= 0) throw new Exception("missing id");
                    OeeDb.HwDelete(id);
                    Reply(200, new { ok = true });
                }
                else if (fmt == "import")
                {
                    string c = Str(d, "commit");
                    Reply(200, Import(Str(d, "name"), Str(d, "data"), c == "True" || c == "true", ip));
                }
                else Reply(400, new { ok = false, error = "unknown format" });
            }
            catch (Exception ex) { Reply(500, new { ok = false, error = ex.Message }); }
        }

        // ------------------------------------------------------------ Ping (จาก Server IIS)
        static readonly object _pingLock = new object();
        static DateTime _pingAt = DateTime.MinValue;
        static Dictionary<string, object> _pingCache = new Dictionary<string, object>();

        static Dictionary<string, object> PingAll(bool force)
        {
            lock (_pingLock)
            {
                if (!force && (DateTime.Now - _pingAt).TotalSeconds < PING_CACHE_SEC) return _pingCache;
                var ips = OeeDb.HwList().Select(r => Convert.ToString(r["ip"]).Trim()).Where(x => x.Length > 0).Distinct().ToList();
                var res = new System.Collections.Concurrent.ConcurrentDictionary<string, object>();
                Parallel.ForEach(ips, new ParallelOptions { MaxDegreeOfParallelism = 32 }, ipx =>
                {
                    try
                    {
                        using (var p = new Ping())
                        {
                            PingReply rp = p.Send(ipx, PING_TIMEOUT_MS);
                            res[ipx] = rp.Status == IPStatus.Success ? (object)new { ok = true, ms = rp.RoundtripTime } : new { ok = false, ms = (long)-1 };
                        }
                    }
                    catch { res[ipx] = new { ok = false, ms = (long)-1 }; }
                });
                _pingCache = res.ToDictionary(k => k.Key, k => k.Value);
                _pingAt = DateTime.Now;
                return _pingCache;
            }
        }

        // ------------------------------------------------------------ CSV
        void SendCsv()
        {
            var sb = new StringBuilder();
            sb.Append("No,Name,Type,IP Address,Location,Owner,Serial number,Start date,Remark\r\n");
            foreach (var r in OeeDb.HwList())
                sb.Append(string.Join(",", new[] { "item_no", "name", "hw_type", "ip", "location", "owner", "serial_no", "start_date", "remark" }
                    .Select(f => Csv(Convert.ToString(r[f], CultureInfo.InvariantCulture))))).Append("\r\n");
            Response.Clear();
            Response.ContentType = "text/csv; charset=utf-8";
            Response.AddHeader("Content-Disposition", "attachment; filename=Hardware_" + DateTime.Now.ToString("yyyyMMdd") + ".csv");
            Response.BinaryWrite(Encoding.UTF8.GetPreamble());
            Response.BinaryWrite(Encoding.UTF8.GetBytes(sb.ToString()));
            Response.Flush();
            Response.SuppressContent = true;
            Context.ApplicationInstance.CompleteRequest();
        }
        static string Csv(string s)
        {
            s = s ?? "";
            return s.IndexOfAny(new[] { ',', '"', '\n', '\r' }) >= 0 ? "\"" + s.Replace("\"", "\"\"") + "\"" : s;
        }

        // ------------------------------------------------------------ Import Excel / CSV
        //   หัวตาราง (แถวที่มีคำว่า Name) : No · Name · Type · IP Address · Location · Owner · serial number · start date · Remark
        //   จับคู่กับของเดิม : IP เดียวกัน = อัปเดต · ไม่มี IP → Name + Location เดียวกัน = อัปเดต · ไม่เจอ = เพิ่มใหม่
        static readonly Dictionary<string, string> HEAD = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) {
            { "no", "item_no" }, { "ลำดับ", "item_no" }, { "item", "item_no" }, { "itemno", "item_no" },
            { "name", "name" }, { "ชื่อ", "name" }, { "devicename", "name" }, { "hardwarename", "name" },
            { "type", "hw_type" }, { "ประเภท", "hw_type" }, { "devicetype", "hw_type" },
            { "ipaddress", "ip" }, { "ip", "ip" }, { "ipaddr", "ip" },
            { "location", "location" }, { "สถานที่", "location" }, { "ตำแหน่ง", "location" },
            { "owner", "owner" }, { "onwer", "owner" }, { "ผู้รับผิดชอบ", "owner" }, { "เจ้าของ", "owner" },
            { "serialnumber", "serial_no" }, { "serialno", "serial_no" }, { "serial", "serial_no" }, { "sn", "serial_no" },
            { "startdate", "start_date" }, { "วันที่เริ่มใช้", "start_date" }, { "date", "start_date" },
            { "remark", "remark" }, { "หมายเหตุ", "remark" }, { "note", "remark" },
        };

        static object Import(string name, string b64, bool commit, string ip)
        {
            if (string.IsNullOrEmpty(b64)) throw new Exception("ไม่มีไฟล์");
            int comma = b64.IndexOf(','); if (comma >= 0 && b64.StartsWith("data:")) b64 = b64.Substring(comma + 1);
            byte[] bytes = Convert.FromBase64String(b64);
            List<List<string>> grid = (name ?? "").EndsWith(".csv", StringComparison.OrdinalIgnoreCase) ? ReadCsv(bytes) : ReadXlsx(bytes);

            // หาแถวหัวตาราง (แถวแรกที่มีคอลัมน์ Name)
            int hr = -1; var map = new Dictionary<int, string>();
            for (int i = 0; i < grid.Count && i < 20 && hr < 0; i++)
            {
                var m = new Dictionary<int, string>();
                for (int c = 0; c < grid[i].Count; c++)
                {
                    string k = Key(grid[i][c]); string f;
                    if (k.Length > 0 && HEAD.TryGetValue(k, out f) && !m.ContainsValue(f)) m[c] = f;
                }
                if (m.ContainsValue("name")) { hr = i; map = m; }
            }
            // ไฟล์ของเดิม : คอลัมน์ A ไม่มีหัว แต่เป็นลำดับ (1, 2, 3 ...)
            if (hr >= 0 && !map.ContainsValue("item_no") && !map.ContainsKey(0)) map[0] = "item_no";
            if (hr < 0) throw new Exception("ไม่พบหัวตาราง (ต้องมีคอลัมน์ Name)");

            var existing = OeeDb.HwList();
            var byIp = new Dictionary<string, Dictionary<string, object>>(StringComparer.OrdinalIgnoreCase);
            var byNameLoc = new Dictionary<string, Dictionary<string, object>>(StringComparer.OrdinalIgnoreCase);
            foreach (var e in existing)
            {
                string eip = Convert.ToString(e["ip"]).Trim();
                if (eip.Length > 0 && !byIp.ContainsKey(eip)) byIp[eip] = e;
                string nk = Key(Convert.ToString(e["name"])) + "|" + Key(Convert.ToString(e["location"]));
                if (!byNameLoc.ContainsKey(nk)) byNameLoc[nk] = e;
            }

            var preview = new List<object>(); int nAdd = 0, nUpd = 0, nSame = 0, nErr = 0;
            var seenIp = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            for (int i = hr + 1; i < grid.Count; i++)
            {
                var row = grid[i];
                var v = new Dictionary<string, string>();
                foreach (var kv in map) v[kv.Value] = kv.Key < row.Count ? (row[kv.Key] ?? "").Trim() : "";
                foreach (string f in OeeDb.HW_FIELDS) if (!v.ContainsKey(f)) v[f] = null;   // ไม่มีคอลัมน์นี้ในไฟล์ = ไม่แก้ค่าเดิม
                if (string.IsNullOrWhiteSpace(v["name"])) continue;
                if (v["start_date"] != null) v["start_date"] = NormDate(v["start_date"]);
                if (v["item_no"] != null) { decimal dn; v["item_no"] = decimal.TryParse(v["item_no"], NumberStyles.Float, CultureInfo.InvariantCulture, out dn) ? ((int)dn).ToString(CultureInfo.InvariantCulture) : ""; }

                string rip = (v["ip"] ?? "").Trim(), note = "";
                Dictionary<string, object> match = null;
                if (rip.Length > 0) byIp.TryGetValue(rip, out match);
                if (match == null) byNameLoc.TryGetValue(Key(v["name"]) + "|" + Key(v["location"] ?? ""), out match);
                if (rip.Length > 0 && !seenIp.Add(rip)) note = "IP ซ้ำในไฟล์";

                // รวมกับค่าเดิม (คอลัมน์ที่ไม่มีในไฟล์ใช้ค่าเดิม)
                var full = new Dictionary<string, string>();
                foreach (string f in OeeDb.HW_FIELDS)
                    full[f] = v[f] ?? (match != null ? Convert.ToString(match[f], CultureInfo.InvariantCulture) : "");

                string action;
                if (match == null) action = "add";
                else
                {
                    bool same = OeeDb.HW_FIELDS.All(f => (full[f] ?? "").Trim() == Convert.ToString(match[f], CultureInfo.InvariantCulture).Trim());
                    action = same ? "same" : "update";
                }
                int newId = match != null ? Convert.ToInt32(match["id"]) : 0;
                if (commit && action != "same")
                {
                    try { newId = OeeDb.HwSave(newId, full, ip); }
                    catch (Exception ex) { action = "error"; note = ex.Message; }
                }
                if (action == "add") nAdd++; else if (action == "update") nUpd++; else if (action == "same") nSame++; else nErr++;
                preview.Add(new { row = i + 1, action = action, note = note, name = full["name"], hw_type = full["hw_type"], ip = full["ip"], location = full["location"], owner = full["owner"] });
            }
            return new { ok = true, committed = commit, add = nAdd, update = nUpd, same = nSame, error = nErr, rows = preview };
        }

        static string Key(string s) { return new string((s ?? "").ToLowerInvariant().Where(ch => char.IsLetterOrDigit(ch)).ToArray()); }

        static string NormDate(string s)
        {
            if (string.IsNullOrWhiteSpace(s)) return "";
            double oa;
            if (double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out oa) && oa > 20000 && oa < 80000)
                return DateTime.FromOADate(oa).ToString("yyyy-MM-dd");   // วันที่ใน Excel เก็บเป็นตัวเลข
            DateTime dt;
            string[] fm = { "yyyy-MM-dd", "yyyy/MM/dd", "d/M/yyyy", "dd/MM/yyyy", "M/d/yyyy", "yyyy-MM-dd HH:mm:ss", "d-MMM-yy", "d-MMM-yyyy" };
            if (DateTime.TryParseExact(s.Trim(), fm, CultureInfo.InvariantCulture, DateTimeStyles.None, out dt)) return dt.ToString("yyyy-MM-dd");
            return "";
        }

        static List<List<string>> ReadCsv(byte[] bytes)
        {
            string text = Encoding.UTF8.GetString(bytes).TrimStart('﻿');
            var rows = new List<List<string>>(); var row = new List<string>(); var cell = new StringBuilder(); bool q = false;
            for (int i = 0; i < text.Length; i++)
            {
                char c = text[i];
                if (q) { if (c == '"') { if (i + 1 < text.Length && text[i + 1] == '"') { cell.Append('"'); i++; } else q = false; } else cell.Append(c); }
                else if (c == '"') q = true;
                else if (c == ',') { row.Add(cell.ToString()); cell.Clear(); }
                else if (c == '\n' || c == '\r') { if (c == '\r' && i + 1 < text.Length && text[i + 1] == '\n') i++; row.Add(cell.ToString()); cell.Clear(); rows.Add(row); row = new List<string>(); }
                else cell.Append(c);
            }
            if (cell.Length > 0 || row.Count > 0) { row.Add(cell.ToString()); rows.Add(row); }
            return rows;
        }

        // ---------- อ่าน .xlsx (แผ่นแรก) ด้วย ZipArchive + XML ----------
        static XmlDocument Xml(ZipArchive zip, string path)
        {
            var e = zip.GetEntry(path); if (e == null) return null;
            var d = new XmlDocument(); using (var st = e.Open()) d.Load(st); return d;
        }

        static List<List<string>> ReadXlsx(byte[] bytes)
        {
            var rows = new List<List<string>>();
            using (var zip = new ZipArchive(new MemoryStream(bytes), ZipArchiveMode.Read))
            {
                var shared = new List<string>();
                var sd = Xml(zip, "xl/sharedStrings.xml");
                if (sd != null)
                    foreach (XmlNode si in sd.GetElementsByTagName("si"))
                    {
                        var sb = new StringBuilder(); foreach (XmlNode t in ((XmlElement)si).GetElementsByTagName("t")) sb.Append(t.InnerText);
                        shared.Add(sb.ToString());
                    }
                // แผ่นแรกตาม workbook.xml
                string sheetPath = "xl/worksheets/sheet1.xml";
                try
                {
                    var wb = Xml(zip, "xl/workbook.xml");
                    var rel = Xml(zip, "xl/_rels/workbook.xml.rels");
                    string rid = wb.GetElementsByTagName("sheet")[0].Attributes["r:id"].Value;
                    foreach (XmlNode n in rel.GetElementsByTagName("Relationship"))
                        if (n.Attributes["Id"].Value == rid)
                        {
                            string tg = n.Attributes["Target"].Value;
                            sheetPath = tg.StartsWith("/") ? tg.TrimStart('/') : "xl/" + tg;
                        }
                }
                catch { }
                var doc = Xml(zip, sheetPath) ?? Xml(zip, "xl/worksheets/sheet1.xml");
                if (doc == null) throw new Exception("อ่านไฟล์ Excel ไม่ได้");

                foreach (XmlNode r in doc.GetElementsByTagName("row"))
                {
                    int rIdx = r.Attributes["r"] != null ? int.Parse(r.Attributes["r"].Value) - 1 : rows.Count;
                    while (rows.Count < rIdx) rows.Add(new List<string>());
                    var row = new List<string>();
                    foreach (XmlNode c in r.ChildNodes)
                    {
                        if (c.LocalName != "c") continue;
                        string refc = c.Attributes["r"] != null ? c.Attributes["r"].Value : null;
                        int col = refc != null ? ColIndex(refc) : row.Count;
                        while (row.Count < col) row.Add("");
                        string type = c.Attributes["t"] != null ? c.Attributes["t"].Value : "";
                        string val = "";
                        foreach (XmlNode x in c.ChildNodes)
                        {
                            if (x.LocalName == "v") val = x.InnerText;
                            else if (x.LocalName == "is") val = x.InnerText;
                        }
                        if (type == "s") { int k; val = int.TryParse(val, out k) && k < shared.Count ? shared[k] : ""; }
                        else if (type == "e") val = "";
                        else if (type != "str" && type != "inlineStr" && type != "b")
                        {
                            decimal dv; if (decimal.TryParse(val, NumberStyles.Float, CultureInfo.InvariantCulture, out dv)) val = dv == Math.Truncate(dv) ? Math.Truncate(dv).ToString(CultureInfo.InvariantCulture) : val;
                        }
                        row.Add(val);
                    }
                    if (rows.Count == rIdx) rows.Add(row); else rows[rIdx] = row;
                }
            }
            return rows;
        }

        static int ColIndex(string cellRef)
        {
            int n = 0; foreach (char ch in cellRef) { if (!char.IsLetter(ch)) break; n = n * 26 + (char.ToUpperInvariant(ch) - 'A' + 1); }
            return n - 1;
        }

        static string Str(Dictionary<string, object> d, string k)
        {
            object o; return d.TryGetValue(k, out o) && o != null ? Convert.ToString(o, CultureInfo.InvariantCulture) : null;
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
