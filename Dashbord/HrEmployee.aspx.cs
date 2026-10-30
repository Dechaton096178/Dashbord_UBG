using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace Dashbord
{
    /// <summary>
    /// HrEmployee.aspx — ทะเบียนพนักงาน (แผนก HR) · ต้องล็อกอินก่อน (HrLogin.aspx)
    ///   GET  ?format=list          รายการทั้งหมด (+ สิทธิ์ของผู้ใช้)
    ///   GET  ?format=csv           ดาวน์โหลด CSV
    ///   GET  ?format=template      ไฟล์หัวตารางเปล่า (CSV) สำหรับกรอกแล้วนำเข้า
    ///   GET  ?format=log&code=...  ประวัติการแก้ไข
    ///   POST ?format=save {id, ...} · delete {id} · import {name, data(base64), commit}
    ///   ข้อมูลอยู่ใน MySQL OEE : hr_employee (สร้างเองครั้งแรก · ดู HrDb.cs)
    /// </summary>
    public partial class HrEmployee : HrPage
    {
        protected override bool HrOnly { get { return true; } }   // เข้าได้เฉพาะ admin / hr

        protected void Page_Load(object sender, EventArgs e)
        {
            string fmt = (Request.QueryString["format"] ?? "").ToLowerInvariant();
            if (fmt == "") return;
            try
            {
                if (Request.HttpMethod == "GET")
                {
                    if (fmt == "list") { Reply(200, new { ok = true, me = Me(), rows = ListWithScan(), processes = AppMenu.Processes, scanData = _hasScan }); return; }
                    if (fmt == "csv") { ExportCsv(); return; }
                    if (fmt == "template") { SendCsv("Employee_Template.csv", new StringBuilder(string.Join(",", CSV_HEAD.Select(h => h.Value)) + "\r\n")); return; }
                    if (fmt == "log") { Reply(200, new { ok = true, rows = OeeDb.HrLogList(Request.QueryString["code"], 200) }); return; }
                    Reply(400, new { ok = false, error = "unknown format" }); return;
                }
                if (Request.HttpMethod != "POST") { Reply(405, new { ok = false, error = "method not allowed" }); return; }
                if (!HrUser.CanEdit) { Reply(403, new { ok = false, error = "บัญชีนี้ดูได้อย่างเดียว (viewer)" }); return; }

                var d = ReadBody();
                int id; int.TryParse(Str(d, "id"), out id);
                string ip = Request.UserHostAddress;
                if (fmt == "save")
                {
                    var v = new Dictionary<string, string>();
                    foreach (string f in OeeDb.EMP_FIELDS) v[f] = Str(d, f);
                    Reply(200, new { ok = true, id = OeeDb.EmpSave(id, v, HrUser.Username, ip) });
                }
                else if (fmt == "delete")
                {
                    if (id <= 0) throw new Exception("missing id");
                    OeeDb.EmpDelete(id, HrUser.Username, ip);
                    Reply(200, new { ok = true });
                }
                else if (fmt == "bulkresign")
                {
                    var map = new Dictionary<int, string>();
                    var items = d.ContainsKey("items") ? d["items"] as System.Collections.ArrayList : null;
                    if (items != null)
                        foreach (var it in items)
                        {
                            var o = it as Dictionary<string, object>; if (o == null) continue;
                            int eid; if (int.TryParse(Str(o, "id"), out eid) && eid > 0) map[eid] = Str(o, "date");
                        }
                    if (map.Count == 0) throw new Exception("ไม่มีรายการ");
                    int n = OeeDb.EmpBulkResign(map, "Resigned: no scans " + TimeAttendance.UNSEEN_DAYS + "+ days (" + DateTime.Today.ToString("yyyy-MM-dd") + ")", HrUser.Username, ip);
                    Reply(200, new { ok = true, updated = n });
                }
                else if (fmt == "import")
                {
                    string c = Str(d, "commit");
                    string rm = Str(d, "resignMissing");
                    Reply(200, Import(Str(d, "name"), Str(d, "data"), c == "True" || c == "true", ip, rm == "True" || rm == "true"));
                }
                else Reply(400, new { ok = false, error = "unknown format" });
            }
            catch (Exception ex) { Reply(500, new { ok = false, error = ex.Message }); }
        }

        // ------------------------------------------------------------ รายชื่อ + สแกนล่าสุด (จาก Time Attendance)
        bool _hasScan;
        List<Dictionary<string, object>> ListWithScan()
        {
            var rows = OeeDb.EmpList(HrUser.CanSeeSensitive);
            Dictionary<string, DateTime> last = null;
            try { last = OeeDb.TaLastScan(new DateTime(2000, 1, 1), DateTime.Today.AddDays(2)); } catch { }
            _hasScan = last != null && last.Count > 0;
            foreach (var r in rows)
            {
                DateTime t; string k = TaCalc.ScanKey(Convert.ToString(r["emp_code"]));
                r["last_scan"] = last != null && k != null && last.TryGetValue(k, out t) ? t.ToString("yyyy-MM-dd") : "";
            }
            return rows;
        }

        // ------------------------------------------------------------ CSV
        static readonly KeyValuePair<string, string>[] CSV_HEAD = {
            P("emp_code", "Code"), P("emp_group", "Group"), P("prefix", "Prefix"), P("name_th", "Name (TH)"), P("name_en", "Name (EN)"),
            P("nickname", "Nickname"), P("gender", "Gender"), P("nationality", "Nationality"), P("department", "Department"),
            P("position", "Position"), P("emp_type", "Type"), P("start_date", "Start date"), P("contract_end", "Contract end"),
            P("locker_no", "Locker"), P("phone", "Phone"), P("id_card", "ID card"), P("birth_date", "Birth date"),
            P("address", "Address"), P("status", "Status"), P("resign_date", "Resign date"), P("remark", "Remark"),
            P("passport_no", "Passport no."), P("passport_exp", "Passport expiry"), P("visa_exp", "Visa expiry"), P("permit_type", "Permit type"),
            P("wp_no", "Work permit no."), P("wp_exp", "Work permit expiry"), P("pink_no", "Pink card no."), P("pink_exp", "Pink card expiry") };
        static KeyValuePair<string, string> P(string k, string v) { return new KeyValuePair<string, string>(k, v); }

        void ExportCsv()
        {
            var cols = CSV_HEAD.Where(h => HrUser.CanSeeSensitive || Array.IndexOf(OeeDb.EMP_SENSITIVE, h.Key) < 0).ToList();
            var sb = new StringBuilder(string.Join(",", cols.Select(h => h.Value)) + "\r\n");
            foreach (var r in OeeDb.EmpList(HrUser.CanSeeSensitive))
                sb.Append(string.Join(",", cols.Select(h => Csv(Convert.ToString(r[h.Key], CultureInfo.InvariantCulture))))).Append("\r\n");
            OeeDb.HrLog(HrUser.Username, "export-csv", null, null, Request.UserHostAddress);
            SendCsv("Employee_" + DateTime.Now.ToString("yyyyMMdd") + ".csv", sb);
        }

        // ------------------------------------------------------------ Import Excel (ทุกแผ่น) / CSV
        //   รองรับไฟล์ "ทะเบียนลูกจ้าง" เดิม : No. · ชื่อ-นามสกุล (ไทย | อังกฤษ) · รหัส · วันที่เริ่มงาน · วันหมดสัญญา · แผนก/ตำแหน่ง · เบอร์ล็อกเกอร์ · ประเทศ · เพศ
        //   และไฟล์ที่ Export จากหน้านี้ · จับคู่ด้วยรหัสพนักงาน : มีแล้ว = อัปเดต · ไม่มี = เพิ่มใหม่
        //   ชื่อแผ่นงาน = กลุ่ม (UBG / DMM / นักศึกษา) ถ้าไฟล์ไม่มีคอลัมน์ Group
        static readonly string[][] HEAD_RULES = {      // { field, คำที่ต้องมีในหัวตาราง ... } ตรวจตามลำดับ
            // เอกสารคนต่างชาติ (ไฟล์ PassWork : สถานะการหมดอายุ Passport / Visa / ใบอนุญาตทำงาน) · ตรวจก่อนคำทั่วไป
            new[] { "pink_exp", "วันหมดอายุบัตรชมพู", "pinkcardexpiry", "pinkexp" },
            new[] { "wp_exp", "วันหมดอายุใบอนุญาตทำงาน", "workpermitexpiry", "wpexp" },
            new[] { "passport_exp", "วันหมดอายุพาส", "passportexpiry", "passportexp" },
            new[] { "visa_exp", "วันหมดอายุวีซ่า", "visaexpiry", "visaexp", "วีซ่า" },
            new[] { "permit_type", "ประเภทใบอนุญาต", "permittype" },
            new[] { "wp_no", "ใบอนุญาตทำงาน", "workpermit", "wpno" },
            new[] { "pink_no", "บัตรชมพู", "pinkcard", "pinkno" },
            new[] { "passport_no", "พาสปอร์ต", "passport" },
            new[] { "id_card", "เลขบัตร", "บัตรประชาชน", "idcard" },
            new[] { "name_en", "ชื่ออังกฤษ", "英名", "nameen", "englishname", "=name" },
            new[] { "nickname", "ชื่อเล่น", "nickname" },
            new[] { "name_th", "ชื่อไทย", "ชื่อ-นามสกุล", "泰名", "nameth", "thainame", "fullname", "=ชื่อ" },
            new[] { "emp_code", "รหัส", "序號", "code", "employeeid", "empid" },
            new[] { "contract_end", "หมดสัญญา", "合約", "contract" },
            new[] { "resign_date", "ลาออก", "resign" },
            new[] { "start_date", "เริ่มงาน", "進工", "startdate", "hiredate" },
            new[] { "birth_date", "วันเกิด", "birth" },
            new[] { "phone", "โทร", "phone", "mobile", "tel" },
            new[] { "locker_no", "ล็อกเกอร์", "ล๊อกเกอร์", "locker" },
            new[] { "nationality", "สัญชาติ", "ประเทศ", "國籍", "nationality", "country" },
            new[] { "gender", "เพศ", "性別", "gender", "sex" },
            new[] { "position", "ตำแหน่ง", "職位", "position" },
            new[] { "department", "แผนก", "部門", "department", "dept" },
            new[] { "prefix", "คำนำหน้า", "prefix" },
            new[] { "emp_group", "กลุ่ม", "group", "company" },
            new[] { "emp_type", "ประเภท", "type" },
            new[] { "status", "สถานะ", "status" },
            new[] { "address", "ที่อยู่", "address" },
            new[] { "remark", "หมายเหตุ", "remark", "note" },
        };

        static string HeadField(string text)
        {
            string k = SheetReader.Key(text);
            if (k.Length == 0) return null;
            foreach (var rule in HEAD_RULES)
                for (int i = 1; i < rule.Length; i++)
                {
                    bool exact = rule[i].StartsWith("=");                         // "=ชื่อ" = ต้องตรงทั้งคำ
                    string a = SheetReader.Key(exact ? rule[i].Substring(1) : rule[i]);
                    bool ascii = a.All(ch => ch < 128);
                    if (a.Length > 0 && (exact || (ascii && a.Length <= 4) ? k == a : k.Contains(a))) return rule[0];   // คำอังกฤษสั้น (code, type, tel) ต้องตรงทั้งคำ
                }
            return null;
        }

        object Import(string fileName, string b64, bool commit, string ip, bool resignMissing)
        {
            List<SheetReader.Sheet> sheets = SheetReader.ReadBase64(fileName, b64);
            var existing = OeeDb.EmpList(true).ToDictionary(r => Convert.ToString(r["emp_code"]).Trim(), StringComparer.OrdinalIgnoreCase);
            ImportPlan plan = BuildImport(sheets, existing);
            var preview = plan.Preview; var toSave = plan.ToSave; var saveIdx = plan.SaveIdx;

            if (commit && toSave.Count > 0)
            {
                List<string> errs = OeeDb.EmpSaveMany(toSave, HrUser.Username, ip);
                for (int i = 0; i < errs.Count; i++)
                    if (errs[i] != null) { preview[saveIdx[i]]["action"] = "error"; preview[saveIdx[i]]["note"] = errs[i]; }
                OeeDb.HrLog(HrUser.Username, "import", null, fileName + " : " + toSave.Count + " rows", ip);
            }
            int resigned = 0;
            if (commit && resignMissing && plan.Missing.Count > 0)
                resigned = OeeDb.EmpBulkResign(plan.Missing.ToDictionary(m => (int)m["id"], m => ""), "Not in register file " + fileName + " (" + DateTime.Today.ToString("yyyy-MM-dd") + ")", HrUser.Username, ip);
            Func<string, int> n = a => preview.Count(p => (string)p["action"] == a);
            return new { ok = true, committed = commit, add = n("add"), update = n("update"), same = n("same"), skip = n("skip"), error = n("error"), sheets = plan.Sheets, rows = preview,
                         docMode = plan.DocMode, missing = plan.Missing, resigned = resigned };
        }

        public class ImportPlan
        {
            public List<Dictionary<string, object>> Preview = new List<Dictionary<string, object>>();
            public List<KeyValuePair<int, Dictionary<string, string>>> ToSave = new List<KeyValuePair<int, Dictionary<string, string>>>();
            public List<int> SaveIdx = new List<int>();
            public List<object> Sheets = new List<object>();
            public bool DocMode;   // ไฟล์เอกสาร (พาสปอร์ต / ใบอนุญาตทำงาน) : แก้เฉพาะช่องเอกสาร
            /// <summary>พนักงาน Active ในกลุ่มเดียวกับแผ่นงานในไฟล์ แต่ไม่มีในไฟล์ (ทะเบียนใหม่ไม่มีแล้ว = ลาออก?)</summary>
            public List<Dictionary<string, object>> Missing = new List<Dictionary<string, object>>();
        }

        /// <summary>อ่านแถวพนักงานจากทุกแผ่น -> รายการที่จะเพิ่ม / อัปเดต (ยังไม่บันทึก)</summary>
        public static ImportPlan BuildImport(List<SheetReader.Sheet> sheets, Dictionary<string, Dictionary<string, object>> existing)
        {
            var plan = new ImportPlan();
            var preview = plan.Preview;
            var toSave = plan.ToSave;
            var saveIdx = plan.SaveIdx;                       // แถวไหนใน preview ตรงกับรายการที่จะบันทึก
            var seen = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);   // รหัส -> แผ่น!แถว ที่เจอก่อน
            var sheetInfo = plan.Sheets;
            var registerGroups = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (var sh in sheets)
            {
                // ---- หาแถวหัวตาราง : แถวแรกที่มีทั้ง "รหัส" และ "ชื่อ" (+ แถวถัดไปเป็นหัวรอง เช่น ชื่อไทย | ชื่ออังกฤษ)
                int hr = -1; var map = new Dictionary<int, string>();
                for (int i = 0; i < sh.Rows.Count && i < 30 && hr < 0; i++)
                {
                    var m = MapRow(sh.Rows[i], new Dictionary<int, string>());
                    if (m.ContainsValue("emp_code") && (m.ContainsValue("name_th") || m.ContainsValue("name_en") || m.Values.Any(f => OeeDb.EMP_DOCS.Contains(f)))) { hr = i; map = m; }
                }
                if (hr < 0) { sheetInfo.Add(new { name = sh.Name, rows = 0, note = "ไม่พบหัวตาราง (ต้องมีคอลัมน์ รหัส + ชื่อ) - ข้าม" }); continue; }
                if (hr + 1 < sh.Rows.Count) map = MapRow(sh.Rows[hr + 1], map);
                bool hasGroup = map.ContainsValue("emp_group");
                // ไฟล์เอกสาร = มีคอลัมน์พาสปอร์ต / ใบอนุญาต แต่ไม่มีวันเริ่มงาน / ตำแหน่ง -> แก้เฉพาะช่องเอกสาร ไม่แตะชื่อ / แผนก / สถานะ
                bool docMode = map.Values.Any(f => OeeDb.EMP_DOCS.Contains(f)) && !map.ContainsValue("start_date") && !map.ContainsValue("position");
                if (docMode) { plan.DocMode = true; map = map.Where(kv => kv.Value == "emp_code" || OeeDb.EMP_DOCS.Contains(kv.Value)).ToDictionary(kv => kv.Key, kv => kv.Value); }
                else registerGroups.Add(sh.Name.Trim());
                int count = 0;

                for (int i = hr + 1; i < sh.Rows.Count; i++)
                {
                    var v = new Dictionary<string, string>();
                    foreach (var kv in map) v[kv.Value] = Clean(sh.Cell(i, kv.Key));
                    string code = NormCode(v["emp_code"]);
                    if (code == null) continue;                                   // แถวว่าง / หัวรอง / แถวสรุป
                    v["emp_code"] = code;
                    string th = Get(v, "name_th"), en = Get(v, "name_en");
                    if (!docMode && th == "" && en == "") continue;
                    count++;
                    string where = sh.Name + "!" + (i + 1);
                    var notes = new List<string>();
                    string prev;
                    if (seen.TryGetValue(code, out prev)) notes.Add("ซ้ำกับ " + prev + " (ใช้แถวนี้แทน)");
                    seen[code] = where;
                    if (!hasGroup && !docMode) v["emp_group"] = sh.Name.Trim();

                    Dictionary<string, object> old;
                    existing.TryGetValue(code, out old);
                    if (docMode && old == null)
                    {
                        preview.Add(new Dictionary<string, object> { { "where", where }, { "action", "skip" }, { "note", "ไม่มีในทะเบียนพนักงาน - เพิ่มพนักงานก่อน" },
                            { "emp_code", code }, { "name", "" }, { "group", "" }, { "department", "" }, { "position", "" }, { "start_date", "" } });
                        continue;
                    }
                    Dictionary<string, string> full = Transform(v, old, notes);

                    string action;
                    if (old == null) action = "add";
                    else action = OeeDb.EMP_FIELDS.All(f => (full[f] ?? "") == Convert.ToString(old[f], CultureInfo.InvariantCulture)) ? "same" : "update";

                    // รหัสเดียวกันหลายแถวในไฟล์ : ให้แถวหลังทับแถวก่อน
                    int dupAt = toSave.FindIndex(x => string.Equals(x.Value["emp_code"], code, StringComparison.OrdinalIgnoreCase));
                    if (dupAt >= 0) { preview[saveIdx[dupAt]]["action"] = "skip"; toSave.RemoveAt(dupAt); saveIdx.RemoveAt(dupAt); }
                    if (action != "same")
                    {
                        toSave.Add(new KeyValuePair<int, Dictionary<string, string>>(old != null ? Convert.ToInt32(old["id"]) : 0, full));
                        saveIdx.Add(preview.Count);
                    }
                    preview.Add(new Dictionary<string, object> {
                        { "where", where }, { "action", action }, { "note", string.Join(" · ", notes) },
                        { "emp_code", code }, { "name", (full["prefix"] + full["name_th"]).Trim() != "" ? (full["prefix"] + full["name_th"]) : full["name_en"] },
                        { "group", full["emp_group"] }, { "department", full["department"] }, { "position", full["position"] }, { "start_date", full["start_date"] },
                    });
                }
                sheetInfo.Add(new { name = sh.Name, rows = count, note = (docMode ? "Passport / visa / work permit : update document columns only" : "") + (sh.Hidden ? " แผ่นงานซ่อนอยู่" : "") });
            }
            // ทะเบียน (แผ่น UBG / DMM / นักศึกษา) : คน Active ในกลุ่มเดียวกันที่ไม่มีในไฟล์แล้ว
            if (registerGroups.Count > 0)
                foreach (var e in existing.Values)
                {
                    string code = Convert.ToString(e["emp_code"]);
                    if (Convert.ToString(e["status"]) == "Resigned" || seen.ContainsKey(code) || !registerGroups.Contains(Convert.ToString(e["emp_group"]).Trim())) continue;
                    plan.Missing.Add(new Dictionary<string, object> { { "id", Convert.ToInt32(e["id"]) }, { "emp_code", code }, { "group", e["emp_group"] },
                        { "name", (Convert.ToString(e["prefix"]) + Convert.ToString(e["name_th"])).Trim() }, { "department", e["department"] } });
                }
            plan.Missing.Sort((a, b) => string.CompareOrdinal(Convert.ToString(a["emp_code"]), Convert.ToString(b["emp_code"])));
            return plan;
        }

        static Dictionary<int, string> MapRow(List<string> row, Dictionary<int, string> map)
        {
            var m = new Dictionary<int, string>(map);
            for (int c = 0; c < row.Count; c++)
            {
                if (m.ContainsKey(c)) continue;
                string f = HeadField(row[c]);
                if (f != null && !m.ContainsValue(f)) m[c] = f;
            }
            return m;
        }

        static string Clean(string s) { return Regex.Replace((s ?? "").Replace(' ', ' '), @"\s+", " ").Trim(); }
        static string Get(Dictionary<string, string> v, string k) { string s; return v.TryGetValue(k, out s) && s != null ? s : ""; }

        /// <summary>รหัสพนักงานต้องมีตัวเลข (กันหัวตารางรอง เช่น 序號) · "U - 0002" -> "U-0002"</summary>
        static string NormCode(string s)
        {
            s = Regex.Replace(s ?? "", @"\s+", "").ToUpperInvariant();
            return s.Length == 0 || s.Length > 20 || !s.Any(char.IsDigit) ? null : s;
        }

        static readonly string[] TH_PREFIX = { "นางสาว", "น.ส.", "นาง", "นาย", "ด.ช.", "ด.ญ." };
        static readonly Regex EN_PREFIX = new Regex(@"^(mr|mrs|ms|miss)\.?\s*", RegexOptions.IgnoreCase);

        /// <summary>
        /// แปลงแถวจาก Excel เป็นข้อมูลพนักงาน : แยกคำนำหน้า / ชื่อเล่น / แผนก / ประเภท · คอลัมน์ที่ไม่มีในไฟล์ = ใช้ค่าเดิม
        /// ค่าที่ระบบเดาเอง (แผนก, ประเภท, เพศ ...) ใส่เฉพาะตอนค่าเดิมว่าง ไม่ทับที่ HR แก้ไว้
        /// </summary>
        static Dictionary<string, string> Transform(Dictionary<string, string> v, Dictionary<string, object> old, List<string> notes)
        {
            Func<string, string> o = f => old != null ? Convert.ToString(old[f], CultureInfo.InvariantCulture) : "";
            var guess = new Dictionary<string, string>();

            // ---- ชื่อไทย : แยกคำนำหน้า (เฉพาะไฟล์ที่ไม่มีคอลัมน์ Prefix แยก)
            bool hasPrefix = v.ContainsKey("prefix");
            if (v.ContainsKey("name_th") && !hasPrefix)
            {
                string th = v["name_th"];
                foreach (string p in TH_PREFIX)
                    if (th.StartsWith(p)) { guess["prefix"] = p == "น.ส." ? "นางสาว" : p; th = th.Substring(p.Length).Trim(); break; }
                v["name_th"] = th;
            }
            // ---- ชื่ออังกฤษ : ตัด Mr./Ms. และ (ชื่อเล่น) (เฉพาะไฟล์ที่ไม่มีคอลัมน์ Prefix แยก)
            if (v.ContainsKey("name_en") && !hasPrefix)
            {
                string en = v["name_en"];
                Match nm = Regex.Match(en, @"\(([^)]{1,40})\)\s*$");
                if (nm.Success) { guess["nickname"] = nm.Groups[1].Value.Trim(); en = en.Substring(0, nm.Index).Trim(); }
                Match pm = EN_PREFIX.Match(en);
                if (pm.Success && pm.Length > 0)
                {
                    string p = pm.Groups[1].Value.ToLowerInvariant();
                    if (!guess.ContainsKey("prefix")) guess["prefix"] = p == "mr" ? "Mr." : p == "mrs" ? "Mrs." : "Ms.";
                    if (!guess.ContainsKey("gender")) guess["gender"] = p == "mr" ? "M" : "F";
                    en = en.Substring(pm.Length).Trim();
                }
                v["name_en"] = en;
            }
            if (guess.ContainsKey("prefix") && !guess.ContainsKey("gender"))
                guess["gender"] = guess["prefix"] == "นาย" || guess["prefix"] == "ด.ช." ? "M" : "F";

            // ---- เพศ : ช / ญ / ชาย / หญิง / M / F
            if (v.ContainsKey("gender"))
            {
                string g = v["gender"].ToLowerInvariant();
                v["gender"] = g.StartsWith("ช") || g == "m" || g == "male" ? "M" : g.StartsWith("ญ") || g.StartsWith("ห") || g == "f" || g == "female" ? "F" : "";
            }
            if (v.ContainsKey("nationality")) v["nationality"] = v["nationality"] == "เมียนม่า" ? "เมียนมา" : v["nationality"];
            if (v.ContainsKey("locker_no") && (v["locker_no"] == "-" || v["locker_no"] == "0")) v["locker_no"] = "";
            foreach (string f in new[] { "passport_no", "wp_no", "pink_no", "permit_type", "id_card", "phone" })      // "-" = ไม่มี
                if (v.ContainsKey(f) && v[f] != null && v[f].Trim('-', ' ', '.') == "") v[f] = "";

            // ---- วันที่ : อ่านไม่ได้ -> ย้ายข้อความไปหมายเหตุ (เช่น ช่องวันหมดสัญญามีข้อความ)
            var extraRemark = new List<string>();
            foreach (string f in OeeDb.EMP_DATES)
            {
                if (!v.ContainsKey(f) || v[f] == "") continue;
                if (v[f].Trim('-', ' ', '.') == "") { v[f] = ""; continue; }       // "-" = ไม่มี
                string d = SheetReader.NormDate(v[f]);
                if (d == null)
                {
                    extraRemark.Add((f == "contract_end" ? "วันหมดสัญญา" : f == "start_date" ? "วันเริ่มงาน" : f == "visa_exp" ? "วีซ่า" : f == "passport_exp" ? "พาสปอร์ตหมดอายุ" :
                                     f == "wp_exp" ? "ใบอนุญาตทำงานหมดอายุ" : f == "pink_exp" ? "บัตรชมพูหมดอายุ" : f) + ": " + v[f]);
                    notes.Add(f + " ไม่ใช่วันที่ -> ใส่หมายเหตุ");
                    v[f] = null;     // ใช้ค่าเดิม
                }
                else v[f] = d;
            }

            // ---- แผนก + ประเภท จากข้อความตำแหน่ง (เช่น "ชั่วคราว/Injection", "นักศึกษา BDI / IPQC")
            if (v.ContainsKey("position") && v["position"] != "")
            {
                string pos = v["position"];
                if (!v.ContainsKey("department")) { string dept = GuessDept(pos); if (dept != null) guess["department"] = dept; }
                if (!v.ContainsKey("emp_type"))
                    guess["emp_type"] = pos.Contains("นักศึกษา") ? "Student" : pos.Contains("ชั่วคราว") ? "Temporary" : "Regular";
            }

            // ---- รวมกับค่าเดิม
            var full = new Dictionary<string, string>();
            foreach (string f in OeeDb.EMP_FIELDS)
            {
                string val;
                if (v.TryGetValue(f, out val) && val != null) full[f] = val;
                else if (guess.ContainsKey(f) && o(f) == "") full[f] = guess[f];
                else full[f] = o(f);
            }
            if (extraRemark.Count > 0)
            {
                string add = string.Join(" · ", extraRemark);
                if (!(full["remark"] ?? "").Contains(add)) full["remark"] = ((full["remark"] ?? "") + (string.IsNullOrEmpty(full["remark"]) ? "" : " · ") + add);
            }
            if (string.IsNullOrEmpty(full["status"])) full["status"] = "Active";
            return full;
        }

        // คำในตำแหน่ง -> แผนก (ตรวจตามลำดับ · คำเขียนผิดที่พบในไฟล์เดิมก็ใส่ไว้ เช่น Extuder, Injeciton, Accouting)
        static readonly string[][] DEPT_RULES = {
            new[] { "QC Vanmark", "qcvanmark" }, new[] { "QC Stamping", "qcstamping" }, new[] { "QC Painting", "qcpainting" },
            new[] { "IPQC", "ipqc" }, new[] { "IQC", "iqc" }, new[] { "FQC", "fqc" }, new[] { "QA", "qa", "qe", "ตัดยาง" },
            new[] { "Mixing", "mixing", "ชั่งเคมี", "chemical" }, new[] { "Extruder", "extruder", "extuder" },
            new[] { "QC Core", "qccore" }, new[] { "Core Molding", "coremolding", "coremold" }, new[] { "Glebar", "glebar", "glebaar" },
            new[] { "Seambuffing", "seambuffing" }, new[] { "Injection", "injection", "injeciton", "mixplastic" },
            new[] { "Vanmark", "vanmark" }, new[] { "Painting", "painting" }, new[] { "Stamping", "stamping" },
            new[] { "Packing", "packing" }, new[] { "Grinding", "grinding" }, new[] { "Store", "store", "สโตร์" },
            new[] { "Maintenance", "ซ่อมบำรุง", "維修", "maintenance", "technician" },
            new[] { "Accounting", "accouting", "accounting", "บัญชี" }, new[] { "Purchasing", "จัดซื้อ", "採購", "purchas" },
            new[] { "Production", "ผลิต", "生產", "production" }, new[] { "Safety", "safety" }, new[] { "HR", "hr" },
            new[] { "IT", "iiot" }, new[] { "Planning", "planning" }, new[] { "Sales", "sales" }, new[] { "Import-Export", "import", "export" },
            new[] { "Admin", "ธุรการ", "แม่บ้าน", "ล่าม", "คนขับรถ" }, new[] { "Engineering", "engineer", "procese", "process" },
            new[] { "Production", "pd" }, new[] { "QC", "qc" },
        };

        static string GuessDept(string position)
        {
            string p = position;
            int moved = p.IndexOf("ย้ายไป", StringComparison.Ordinal);      // "ชั่วคราว/Injection ย้ายไป Mixing" -> Mixing
            if (moved >= 0) p = p.Substring(moved + "ย้ายไป".Length);
            string k = SheetReader.Key(p);
            foreach (var rule in DEPT_RULES)
                for (int i = 1; i < rule.Length; i++)
                {
                    string a = SheetReader.Key(rule[i]);
                    if (a.All(ch => ch < 128) && a.Length <= 2 ? Regex.IsMatch(" " + p.ToLowerInvariant() + " ", @"[^a-z]" + a + "[^a-z]") : k.Contains(a)) return rule[0];
                }
            return null;
        }
    }
}
