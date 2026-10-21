using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Xml;
using System.Linq;
using System.Text;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;

namespace Dashbord
{
    /// <summary>
    /// MasterSample.aspx — ยิงบาร์โค้ด → แสดง Master Sample Sheet (ข้อมูล + รูป 9 ช่อง) · เพิ่ม/แก้ไข/อัปโหลดรูป
    ///   GET  ?format=find&q=...            ค้นหา (บาร์โค้ด / Product Number / ชื่อ)
    ///   GET  ?format=list                  รายการทั้งหมด
    ///   GET  ?format=photo&id=&slot=&v=    รูป
    ///   POST ?format=save    {id, product_name, ...}      (ต้องใส่ pin ถ้าตั้ง EDIT_PIN)
    ///   POST ?format=delete  {id}
    ///   POST ?format=upload  {id, slot, data:"data:image/jpeg;base64,..."}
    ///   POST ?format=delphoto {id, slot}
    ///   POST ?format=checkpin {pin}
    ///   POST ?format=chunk   {pin, uid, idx, data}  อัปโหลดไฟล์เป็นชิ้น (ไฟล์ Excel ที่มีรูป)
    ///   POST ?format=import  {pin, name, uid, commit}  → ตรวจ (commit=false) / นำเข้า (commit=true) รวมรูปในไฟล์
    ///   ข้อมูลอยู่ใน MySQL OEE : master_sample / master_sample_photo (สร้าง + นำเข้าข้อมูลตั้งต้นเองครั้งแรก)
    /// </summary>
    public partial class MasterSample : Page
    {
        // ===================== ตั้งค่า =====================
        public const string EDIT_PIN = "ubg2026";     // รหัสสำหรับ Edit mode / Import (ว่าง = ใครก็แก้ได้)
        public const int MAX_PHOTO_BYTES = 3000000;   // รูปละไม่เกิน ~3 MB (หน้าเว็บย่อรูปให้ก่อนส่งอยู่แล้ว)
        // ==================================================
        public static readonly string[] SLOTS = { "logo1", "logo2", "side1", "side2", "sleeve_front", "sleeve_barcode", "box_lid", "box_base", "box_barcode" };

        static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };

        /// <summary>เลขเวอร์ชันของ files/MasterSample.js + .css (จากเวลาแก้ไฟล์) → เบราว์เซอร์โหลดใหม่เองเมื่อไฟล์เปลี่ยน</summary>
        protected string MasterSampleVer
        {
            get
            {
                long t = 0;
                foreach (string f in new[] { "~/files/MasterSample.js", "~/files/MasterSample.css" })
                    try { t = Math.Max(t, File.GetLastWriteTimeUtc(Server.MapPath(f)).Ticks); } catch { }
                return (t / 10000000).ToString(CultureInfo.InvariantCulture);
            }
        }
        string _apiOutput;

        protected void Page_Load(object sender, EventArgs e)
        {
            string fmt = (Request.QueryString["format"] ?? "").ToLowerInvariant();
            if (fmt == "") return;
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            try
            {
                if (fmt == "photo") { SendPhoto(); return; }
                if (Request.HttpMethod == "GET")
                {
                    if (fmt == "find") { Reply(200, Find(Request.QueryString["q"])); return; }
                    if (fmt == "list") { Reply(200, new { ok = true, rows = OeeDb.MsList(), pinRequired = EDIT_PIN.Length > 0 }); return; }
                    Reply(400, new { ok = false, error = "unknown format" }); return;
                }
                if (Request.HttpMethod != "POST") { Reply(405, new { ok = false, error = "method not allowed" }); return; }

                string body;
                using (var r = new StreamReader(Request.InputStream, Encoding.UTF8)) body = r.ReadToEnd();
                var d = Json.Deserialize<Dictionary<string, object>>(body) ?? new Dictionary<string, object>();
                if (EDIT_PIN.Length > 0 && Str(d, "pin") != EDIT_PIN) { Reply(403, new { ok = false, error = "รหัสแก้ไขไม่ถูกต้อง / Wrong PIN" }); return; }
                string ip = Request.UserHostAddress;
                int id; int.TryParse(Str(d, "id"), out id);

                if (fmt == "checkpin") { Reply(200, new { ok = true }); return; }
                if (fmt == "chunk") { int ci; int.TryParse(Str(d, "idx"), out ci); Reply(200, Chunk(Str(d, "uid"), ci, Str(d, "data"))); return; }
                if (fmt == "import") { Reply(200, Import(Str(d, "name"), Str(d, "uid"), Str(d, "data"), Str(d, "commit") == "True" || Str(d, "commit") == "true", ip)); return; }
                if (fmt == "save")
                {
                    var v = new Dictionary<string, string>();
                    foreach (string f in OeeDb.MS_FIELDS) v[f] = Str(d, f);
                    id = OeeDb.MsSave(id, v, ip);
                    Reply(200, new { ok = true, row = OeeDb.MsGet(id) });
                }
                else if (fmt == "delete")
                {
                    if (id <= 0) throw new Exception("missing id");
                    OeeDb.MsDelete(id);
                    Reply(200, new { ok = true });
                }
                else if (fmt == "upload")
                {
                    string slot = Slot(Str(d, "slot"));
                    string data = Str(d, "data") ?? "";
                    int comma = data.IndexOf(',');
                    if (id <= 0 || comma < 0 || !data.StartsWith("data:image/")) throw new Exception("ข้อมูลรูปไม่ถูกต้อง");
                    string ct = data.Substring(5, data.IndexOf(';') - 5);
                    if (ct != "image/jpeg" && ct != "image/png" && ct != "image/webp") throw new Exception("รองรับเฉพาะ JPG / PNG / WEBP");
                    byte[] bytes = Convert.FromBase64String(data.Substring(comma + 1));
                    if (bytes.Length > MAX_PHOTO_BYTES) throw new Exception("รูปใหญ่เกินไป");
                    OeeDb.MsPhotoPut(id, slot, ct, bytes, ip);
                    Reply(200, new { ok = true, row = OeeDb.MsGet(id) });
                }
                else if (fmt == "delphoto")
                {
                    OeeDb.MsPhotoDelete(id, Slot(Str(d, "slot")));
                    Reply(200, new { ok = true, row = OeeDb.MsGet(id) });
                }
                else Reply(400, new { ok = false, error = "unknown format" });
            }
            catch (Exception ex) { Reply(500, new { ok = false, error = ex.Message }); }
        }

        // ------------------------------------------------------------ ค้นหา
        static string Digits(string s) { return new string((s ?? "").Where(char.IsDigit).ToArray()); }
        static string Norm(string s) { return new string((s ?? "").ToUpperInvariant().Where(char.IsLetterOrDigit).ToArray()); }

        static object Find(string q)
        {
            q = (q ?? "").Trim();
            if (q.Length == 0) return new { ok = true, q = q, exact = false, rows = new object[0] };
            var all = OeeDb.MsList();
            string qd = Digits(q), qn = Norm(q);

            // 1) บาร์โค้ด / Product Number ตรงกัน (ไม่สนช่องว่าง, รองรับ UPC 12 หลัก vs EAN 13 / GTIN 14 ที่มีเลขนำหน้า)
            Func<string, bool> codeMatch = stored =>
            {
                string sd = Digits(stored);
                if (sd.Length < 6 || qd.Length < 6) return Norm(stored) == qn && qn.Length > 0;
                if (sd == qd) return true;
                string a = sd.TrimStart('0'), b = qd.TrimStart('0');
                if (a == b) return true;
                // GTIN-14 (เช่น 10197193565748) กับ UPC-12 : เทียบ 11 หลักกลาง (ตัดหลักนำหน้าและหลักตรวจสอบ)
                if (a.Length >= 12 && b.Length >= 12)
                {
                    string ca = a.Substring(a.Length - 12, 11), cb = b.Substring(b.Length - 12, 11);
                    if (ca == cb) return true;
                }
                return false;
            };
            var exact = all.Where(r => codeMatch((string)r["barcode"]) || codeMatch((string)r["barcode2"]) || codeMatch((string)r["product_number"])).ToList();
            if (exact.Count > 0) return new { ok = true, q = q, exact = true, rows = exact };

            // 2) ค้นจากข้อความ (ชื่อ / ชื่อย่อ / Product Number / Supplier) ทุกคำต้องเจอ
            var words = q.ToUpperInvariant().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            var part = all.Where(r =>
            {
                string hay = ((string)r["product_name"] + " " + r["short_name"] + " " + r["product_number"] + " " + r["barcode"] + " " + r["barcode2"] + " " + r["supplier"]).ToUpperInvariant();
                return words.All(w => hay.Contains(w));
            }).Take(50).ToList();
            return new { ok = true, q = q, exact = false, rows = part };
        }

        // ------------------------------------------------------------ นำเข้า Excel / CSV (+ รูปในไฟล์ Excel)
        //   หัวคอลัมน์ : Product name | Product Number | Supplier | BarCode 1 | BarCode 2 | SQE/SI | Prepared | Supplier Approver | Sample Location | ShortName | Comment
        //   คอลัมน์รูป : 1st Logo | 2nd Logo | Side Mark 1 | Side Mark 2 | Sleeve Front | Sleeve Barcode Side | Box Lid | Box Base | Box Barcode
        //     รูปที่ "วางในเซลล์" (Place in Cell) หรือรูปลอยที่มุมซ้ายบนอยู่ในเซลล์นั้น = รูปของแถว/คอลัมน์นั้น
        //   รายการเดิม = บาร์โค้ดตรงกัน (หรือ Product Number + ชื่อ ถ้าบาร์โค้ดเป็น N/A) + Supplier เดียวกัน → อัปเดต · ไม่เจอ → เพิ่มใหม่
        //   ไฟล์ใหญ่ส่งเป็นชิ้น (format=chunk) เก็บชั่วคราวใน %TEMP% ไม่ต้องแก้ maxRequestLength ใน Web.config
        static readonly Dictionary<string, string> HEAD = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) {
            { "productname", "product_name" }, { "name", "product_name" },
            { "productnumber", "product_number" }, { "product", "product_number" }, { "productno", "product_number" },
            { "supplier", "supplier" }, { "vendor", "supplier" },
            { "barcode", "barcode" }, { "barcode1", "barcode" }, { "unitbarcode", "barcode" }, { "upc", "barcode" },
            { "barcode2", "barcode2" }, { "casebarcode", "barcode2" }, { "gtin", "barcode2" }, { "gtin14", "barcode2" },
            { "sqesi", "sqe" }, { "sqe", "sqe" },
            { "prepared", "prepared" }, { "date", "prepared" },
            { "supplierapprover", "supplier_approver" }, { "approvedby", "supplier_approver" },
            { "samplelocation", "sample_location" }, { "location", "sample_location" },
            { "shortname", "short_name" }, { "comment", "comment" } };
        static readonly Dictionary<string, string> PHOTO_HEAD = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) {
            { "1stlogo", "logo1" }, { "logo1", "logo1" }, { "2ndlogo", "logo2" }, { "logo2", "logo2" },
            { "sidemark1", "side1" }, { "sidemark2", "side2" },
            { "sleevefront", "sleeve_front" }, { "sleevephotofront", "sleeve_front" }, { "front", "sleeve_front" },
            { "sleevebarcodeside", "sleeve_barcode" }, { "sleevephotobarcodeside", "sleeve_barcode" }, { "barcodeside", "sleeve_barcode" },
            { "boxlid", "box_lid" }, { "boxphotolidphoto", "box_lid" }, { "lidphoto", "box_lid" },
            { "boxbase", "box_base" }, { "boxphotobasephoto", "box_base" }, { "basephoto", "box_base" },
            { "boxbarcode", "box_barcode" }, { "boxphotobarcodephoto", "box_barcode" }, { "barcodephoto", "box_barcode" } };

        static string TempPath(string uid)
        {
            if (string.IsNullOrEmpty(uid) || !uid.All(ch => char.IsLetterOrDigit(ch)) || uid.Length > 40) throw new Exception("upload id ไม่ถูกต้อง");
            return Path.Combine(Path.GetTempPath(), "ms_import_" + uid + ".bin");
        }
        static object Chunk(string uid, int idx, string b64)
        {
            string p = TempPath(uid);
            if (idx == 0)
            {   // ลบไฟล์ค้างเก่า (> 2 ชม.)
                try { foreach (var f in Directory.GetFiles(Path.GetTempPath(), "ms_import_*.bin")) if (File.GetLastWriteTime(f) < DateTime.Now.AddHours(-2)) File.Delete(f); } catch { }
                if (File.Exists(p)) File.Delete(p);
            }
            byte[] b = Convert.FromBase64String(b64 ?? "");
            using (var fs = new FileStream(p, FileMode.Append, FileAccess.Write)) fs.Write(b, 0, b.Length);
            if (new FileInfo(p).Length > 60 * 1024 * 1024) { File.Delete(p); throw new Exception("ไฟล์ใหญ่เกิน 60 MB"); }
            return new { ok = true };
        }

        static object Import(string name, string uid, string b64, bool commit, string ip)
        {
            byte[] bytes;
            if (!string.IsNullOrEmpty(uid)) { string p = TempPath(uid); if (!File.Exists(p)) throw new Exception("ไม่พบไฟล์ที่อัปโหลด (หมดเวลา) กรุณาเลือกไฟล์ใหม่"); bytes = File.ReadAllBytes(p); }
            else if (!string.IsNullOrEmpty(b64)) bytes = Convert.FromBase64String(b64);
            else throw new Exception("ไม่มีไฟล์");

            var images = new Dictionary<long, byte[]>();   // key = row * 10000 + col (เริ่ม 0)
            List<List<string>> grid = (name ?? "").EndsWith(".csv", StringComparison.OrdinalIgnoreCase) ? ReadCsv(bytes) : ReadXlsx(bytes, images);
            if (grid.Count < 2) throw new Exception("ไฟล์ไม่มีข้อมูล");
            int hr = grid.FindIndex(r => r.Any(c => Key(c) == "productname"));
            if (hr < 0) throw new Exception("ไม่พบหัวคอลัมน์ 'Product name'");
            var map = new Dictionary<int, string>(); var pmap = new Dictionary<int, string>();
            for (int i = 0; i < grid[hr].Count; i++)
            {
                string k = Key(grid[hr][i]), f;
                if (HEAD.TryGetValue(k, out f) && !map.ContainsValue(f)) map[i] = f;
                else if (PHOTO_HEAD.TryGetValue(k, out f) && !pmap.ContainsValue(f)) pmap[i] = f;
            }

            var existing = OeeDb.MsList();
            var result = new List<object>(); int nNew = 0, nUpd = 0, nSame = 0, nErr = 0, nPhoto = 0;
            for (int r = hr + 1; r < grid.Count; r++)
            {
                var v = new Dictionary<string, string>();
                foreach (string f in OeeDb.MS_FIELDS) v[f] = "";
                foreach (var kv in map) if (kv.Key < grid[r].Count) v[kv.Value] = (grid[r][kv.Key] ?? "").Trim();
                var photos = new Dictionary<string, byte[]>();
                foreach (var kv in pmap) { byte[] im; if (images.TryGetValue((long)r * 10000 + kv.Key, out im)) photos[kv.Value] = im; }
                if (v.Values.All(x => x.Length == 0) && photos.Count == 0) continue;
                if (v["barcode"].Equals("N/A", StringComparison.OrdinalIgnoreCase)) v["barcode"] = "N/A";
                if (v["barcode2"].Equals("N/A", StringComparison.OrdinalIgnoreCase)) v["barcode2"] = "N/A";
                v["prepared"] = NormDate(v["prepared"]);
                string action, note = "";
                Dictionary<string, object> hit = null;
                if (v["product_name"].Length == 0) { action = "error"; note = "ไม่มี Product name"; }
                else
                {
                    string bc = Digits(v["barcode"]), bc2 = Digits(v["barcode2"]);
                    hit = existing.FirstOrDefault(x => string.Equals((string)x["supplier"], v["supplier"], StringComparison.OrdinalIgnoreCase) &&
                        (bc.Length >= 6 ? Digits((string)x["barcode"]) == bc
                       : bc2.Length >= 6 ? Digits((string)x["barcode2"]) == bc2
                                        : Norm((string)x["product_number"]) == Norm(v["product_number"]) && Norm((string)x["product_name"]) == Norm(v["product_name"])));
                    if (hit == null) action = "new";
                    else
                    {
                        var diff = OeeDb.MS_FIELDS.Where(f => v[f].Length > 0 && !string.Equals(v[f], (string)hit[f], StringComparison.Ordinal)).ToList();
                        if (diff.Count == 0 && photos.Count == 0) action = "same";
                        else { action = "update"; note = string.Join(", ", diff); foreach (string f in OeeDb.MS_FIELDS) if (v[f].Length == 0) v[f] = (string)hit[f]; }
                    }
                }
                if (photos.Count > 0 && action != "error") note = (note.Length > 0 ? note + " · " : "") + photos.Count + " photo(s): " + string.Join(", ", photos.Keys);
                if (commit && (action == "new" || action == "update"))
                {
                    try
                    {
                        int id = OeeDb.MsSave(action == "update" ? (int)hit["id"] : 0, v, ip);
                        foreach (var ph in photos) { string ct; byte[] jpg = Shrink(ph.Value, out ct); OeeDb.MsPhotoPut(id, ph.Key, ct, jpg, ip); nPhoto++; }
                        if (action == "new") existing.Add(OeeDb.MsGet(id));
                    }
                    catch (Exception ex) { action = "error"; note = ex.Message; }
                }
                else if (!commit && action != "error") nPhoto += photos.Count;
                if (action == "new") nNew++; else if (action == "update") nUpd++; else if (action == "same") nSame++; else nErr++;
                result.Add(new { row = r + 1, action = action, note = note, photos = photos.Count, product_name = v["product_name"], barcode = v["barcode"], barcode2 = v["barcode2"], supplier = v["supplier"], product_number = v["product_number"] });
            }
            if (commit && !string.IsNullOrEmpty(uid)) try { File.Delete(TempPath(uid)); } catch { }
            return new { ok = true, commit = commit, total = result.Count, added = nNew, updated = nUpd, same = nSame, errors = nErr, photos = nPhoto,
                         photoColumns = pmap.Values.ToArray(), rows = result };
        }

        // ย่อรูปจาก Excel ให้ด้านยาวไม่เกิน 1600px แล้วบันทึกเป็น JPEG (ถ้าย่อไม่ได้ เก็บไฟล์เดิม)
        static byte[] Shrink(byte[] data, out string contentType)
        {
            contentType = "image/jpeg";
            try
            {
                using (var ms = new MemoryStream(data))
                using (var img = System.Drawing.Image.FromStream(ms))
                {
                    double k = Math.Min(1.0, 1600.0 / Math.Max(img.Width, img.Height));
                    int w = Math.Max(1, (int)(img.Width * k)), h = Math.Max(1, (int)(img.Height * k));
                    using (var bmp = new System.Drawing.Bitmap(w, h))
                    {
                        using (var g = System.Drawing.Graphics.FromImage(bmp))
                        {
                            g.Clear(System.Drawing.Color.White);
                            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                            g.DrawImage(img, 0, 0, w, h);
                        }
                        var enc = System.Drawing.Imaging.ImageCodecInfo.GetImageEncoders().First(c => c.MimeType == "image/jpeg");
                        var ep = new System.Drawing.Imaging.EncoderParameters(1);
                        ep.Param[0] = new System.Drawing.Imaging.EncoderParameter(System.Drawing.Imaging.Encoder.Quality, 85L);
                        using (var outMs = new MemoryStream()) { bmp.Save(outMs, enc, ep); return outMs.ToArray(); }
                    }
                }
            }
            catch
            {
                contentType = data.Length > 3 && data[0] == 0x89 && data[1] == 0x50 ? "image/png" : "image/jpeg";
                return data;
            }
        }

        static string Key(string s) { return new string((s ?? "").ToLowerInvariant().Where(char.IsLetterOrDigit).ToArray()); }

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
        static string Combine(string baseDir, string target)   // แปลง Target ใน .rels เป็น path ใน zip
        {
            if (target.StartsWith("/")) return target.TrimStart('/');
            var parts = new List<string>(baseDir.Split('/').Where(x => x.Length > 0));
            foreach (var seg in target.Split('/')) { if (seg == "..") { if (parts.Count > 0) parts.RemoveAt(parts.Count - 1); } else if (seg != ".") parts.Add(seg); }
            return string.Join("/", parts);
        }
        static Dictionary<string, string> Rels(ZipArchive zip, string partPath)
        {
            var res = new Dictionary<string, string>();
            string dir = partPath.Contains("/") ? partPath.Substring(0, partPath.LastIndexOf('/')) : "";
            string relPath = dir + "/_rels/" + partPath.Substring(partPath.LastIndexOf('/') + 1) + ".rels";
            var d = Xml(zip, relPath.TrimStart('/'));
            if (d == null) return res;
            foreach (XmlNode n in d.GetElementsByTagName("Relationship"))
                res[n.Attributes["Id"].Value] = n.Attributes["TargetMode"] != null && n.Attributes["TargetMode"].Value == "External" ? null : Combine(dir, n.Attributes["Target"].Value);
            return res;
        }
        static byte[] Entry(ZipArchive zip, string path)
        {
            var e = path == null ? null : zip.GetEntry(path); if (e == null) return null;
            using (var st = e.Open()) using (var ms = new MemoryStream()) { st.CopyTo(ms); return ms.ToArray(); }
        }

        static List<List<string>> ReadXlsx(byte[] bytes, Dictionary<long, byte[]> images)
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
                    var wb = Xml(zip, "xl/workbook.xml"); var rel = Rels(zip, "xl/workbook.xml");
                    var first = wb.GetElementsByTagName("sheet")[0];
                    string rid = first.Attributes["r:id"].Value;
                    if (rel.ContainsKey(rid) && rel[rid] != null) sheetPath = rel[rid];
                }
                catch { }
                var doc = Xml(zip, sheetPath) ?? Xml(zip, "xl/worksheets/sheet1.xml");
                if (doc == null) throw new Exception("อ่านไฟล์ Excel ไม่ได้");

                // รูปแบบ "วางในเซลล์" (Excel 365) : vm → rich value → รูป
                var cellImgByVm = images == null ? null : RichValueImages(zip);

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
                        if (c.Attributes["vm"] != null && cellImgByVm != null)
                        {
                            int vm; byte[] im;
                            if (int.TryParse(c.Attributes["vm"].Value, out vm) && cellImgByVm.TryGetValue(vm, out im)) images[(long)rIdx * 10000 + col] = im;
                            val = "";
                        }
                        else if (type == "s") { int k; val = int.TryParse(val, out k) && k < shared.Count ? shared[k] : ""; }
                        else if (type == "e") val = "";
                        else if (type != "str" && type != "inlineStr" && type != "b")
                        {   // ตัวเลขยาว เช่น บาร์โค้ด 197193442479 ไม่ให้เป็น 1.97E+11
                            decimal dv; if (decimal.TryParse(val, NumberStyles.Float, CultureInfo.InvariantCulture, out dv)) val = dv == Math.Truncate(dv) ? Math.Truncate(dv).ToString(CultureInfo.InvariantCulture) : val;
                        }
                        row.Add(val);
                    }
                    if (rows.Count == rIdx) rows.Add(row); else rows[rIdx] = row;
                }

                // รูปลอย (Insert Picture) : มุมซ้ายบนอยู่เซลล์ไหน = รูปของเซลล์นั้น
                if (images != null)
                {
                    var sheetRels = Rels(zip, sheetPath);
                    foreach (XmlNode dn in doc.GetElementsByTagName("drawing"))
                    {
                        var idAttr = dn.Attributes["r:id"]; string dPath;
                        if (idAttr == null || !sheetRels.TryGetValue(idAttr.Value, out dPath) || dPath == null) continue;
                        var dd = Xml(zip, dPath); if (dd == null) continue;
                        var dRels = Rels(zip, dPath);
                        foreach (XmlNode anchor in dd.DocumentElement.ChildNodes)
                        {
                            if (anchor.LocalName != "twoCellAnchor" && anchor.LocalName != "oneCellAnchor") continue;
                            int col = -1, row = -1; string embed = null;
                            foreach (XmlNode ch in anchor.ChildNodes)
                                if (ch.LocalName == "from")
                                    foreach (XmlNode f in ch.ChildNodes) { if (f.LocalName == "col") col = int.Parse(f.InnerText); else if (f.LocalName == "row") row = int.Parse(f.InnerText); }
                            foreach (XmlNode blip in ((XmlElement)anchor).GetElementsByTagName("a:blip"))
                            {
                                var a = blip.Attributes["r:embed"]; if (a != null) { embed = a.Value; break; }
                            }
                            string media; byte[] im;
                            if (col < 0 || row < 0 || embed == null || !dRels.TryGetValue(embed, out media) || (im = Entry(zip, media)) == null) continue;
                            long key = (long)row * 10000 + col;
                            if (!images.ContainsKey(key)) images[key] = im;
                        }
                    }
                }
            }
            return rows;
        }

        // vm (เริ่ม 1) → ไฟล์รูป สำหรับรูปแบบ "Place in Cell"
        static Dictionary<int, byte[]> RichValueImages(ZipArchive zip)
        {
            var res = new Dictionary<int, byte[]>();
            try
            {
                var rv = Xml(zip, "xl/richData/rdrichvalue.xml"); if (rv == null) return res;
                // ตำแหน่ง key _rvRel:LocalImageIdentifier ในแต่ละ structure
                var structPos = new List<int>();
                var st = Xml(zip, "xl/richData/rdrichvaluestructure.xml");
                if (st != null)
                    foreach (XmlNode s in st.GetElementsByTagName("s"))
                    {
                        int pos = 0, i = 0;
                        foreach (XmlNode k in s.ChildNodes) { if (k.LocalName != "k") continue; if (k.Attributes["n"].Value == "_rvRel:LocalImageIdentifier") pos = i; i++; }
                        structPos.Add(pos);
                    }
                // rel index → media
                var relList = new List<string>();
                var rr = Xml(zip, "xl/richData/richValueRel.xml");
                var rrRels = Rels(zip, "xl/richData/richValueRel.xml");
                if (rr != null)
                    foreach (XmlNode n in rr.DocumentElement.ChildNodes)
                    {
                        if (n.LocalName != "rel") continue;
                        string id = null; foreach (XmlAttribute at in n.Attributes) if (at.LocalName == "id") id = at.Value;
                        string target; relList.Add(id != null && rrRels.TryGetValue(id, out target) ? target : null);
                    }
                var rvImages = new List<byte[]>();
                foreach (XmlNode v in rv.GetElementsByTagName("rv"))
                {
                    int sIdx = v.Attributes["s"] != null ? int.Parse(v.Attributes["s"].Value) : 0;
                    int pos = sIdx < structPos.Count ? structPos[sIdx] : 0;
                    var vals = v.ChildNodes.Cast<XmlNode>().Where(x => x.LocalName == "v").ToList();
                    int relIdx; byte[] im = null;
                    if (pos < vals.Count && int.TryParse(vals[pos].InnerText, out relIdx) && relIdx < relList.Count) im = Entry(zip, relList[relIdx]);
                    rvImages.Add(im);
                }
                // metadata.xml : valueMetadata bk (ลำดับ = vm) → futureMetadata XLRICHVALUE bk → rvb i
                var md = Xml(zip, "xl/metadata.xml");
                var vmToRv = new List<int>();
                if (md != null)
                {
                    var futureIdx = new List<int>();
                    foreach (XmlNode fm in md.GetElementsByTagName("futureMetadata"))
                        if (fm.Attributes["name"] != null && fm.Attributes["name"].Value == "XLRICHVALUE")
                            foreach (XmlNode bk in fm.ChildNodes)
                            {
                                if (bk.LocalName != "bk") continue;
                                int iv = -1;
                                foreach (XmlNode x in ((XmlElement)bk).GetElementsByTagName("*")) if (x.LocalName == "rvb" && x.Attributes["i"] != null) iv = int.Parse(x.Attributes["i"].Value);
                                futureIdx.Add(iv);
                            }
                    foreach (XmlNode vmb in md.GetElementsByTagName("valueMetadata"))
                        foreach (XmlNode bk in vmb.ChildNodes)
                        {
                            if (bk.LocalName != "bk") continue;
                            int target = -1;
                            foreach (XmlNode rc in bk.ChildNodes) if (rc.LocalName == "rc" && rc.Attributes["v"] != null) { int vv = int.Parse(rc.Attributes["v"].Value); target = vv < futureIdx.Count ? futureIdx[vv] : vv; }
                            vmToRv.Add(target);
                        }
                }
                int count = vmToRv.Count > 0 ? vmToRv.Count : rvImages.Count;
                for (int vm = 1; vm <= count; vm++)
                {
                    int rIdx = vmToRv.Count > 0 ? vmToRv[vm - 1] : vm - 1;
                    if (rIdx >= 0 && rIdx < rvImages.Count && rvImages[rIdx] != null) res[vm] = rvImages[rIdx];
                }
            }
            catch { }
            return res;
        }

        static int ColIndex(string cellRef)
        {
            int n = 0; foreach (char ch in cellRef) { if (!char.IsLetter(ch)) break; n = n * 26 + (char.ToUpperInvariant(ch) - 'A' + 1); }
            return n - 1;
        }

        // ------------------------------------------------------------ รูป
        void SendPhoto()
        {
            int id; int.TryParse(Request.QueryString["id"], out id);
            string slot = Slot(Request.QueryString["slot"]);
            string ct; DateTime up;
            byte[] data = OeeDb.MsPhotoGet(id, slot, out ct, out up);
            Response.Clear();
            if (data == null) { Response.StatusCode = 404; Response.TrySkipIisCustomErrors = true; }
            else
            {
                Response.ContentType = ct;
                Response.Cache.SetCacheability(HttpCacheability.Private);
                Response.Cache.SetMaxAge(TimeSpan.FromDays(30));   // URL มี &v=เวลาอัปเดต → เปลี่ยนรูปแล้ว URL เปลี่ยนเอง
                Response.BinaryWrite(data);
            }
            Response.Flush();
            Response.SuppressContent = true;
            Context.ApplicationInstance.CompleteRequest();
        }

        static string Slot(string s)
        {
            s = (s ?? "").Trim().ToLowerInvariant();
            if (Array.IndexOf(SLOTS, s) < 0) throw new Exception("slot ไม่ถูกต้อง");
            return s;
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
