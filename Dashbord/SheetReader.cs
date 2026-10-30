using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Text;
using System.Xml;

namespace Dashbord
{
    /// <summary>
    /// อ่านไฟล์ Excel (.xlsx ทุกแผ่น) / CSV เป็นตาราง string โดยไม่ต้องลงไลบรารีเพิ่ม (ZipArchive + XML)
    ///   ใช้กับหน้านำเข้าข้อมูล เช่น HrEmployee.aspx
    /// </summary>
    public static class SheetReader
    {
        public class Sheet
        {
            public string Name;
            public bool Hidden;
            public List<List<string>> Rows = new List<List<string>>();
            public string Cell(int r, int c) { return r < Rows.Count && c >= 0 && c < Rows[r].Count ? (Rows[r][c] ?? "") : ""; }
        }

        /// <summary>อ่านจาก base64 (data URL ก็ได้) ตามนามสกุลไฟล์</summary>
        public static List<Sheet> ReadBase64(string fileName, string b64)
        {
            if (string.IsNullOrEmpty(b64)) throw new Exception("ไม่มีไฟล์");
            int comma = b64.IndexOf(',');
            if (comma >= 0 && b64.StartsWith("data:")) b64 = b64.Substring(comma + 1);
            byte[] bytes = Convert.FromBase64String(b64);
            if ((fileName ?? "").EndsWith(".csv", StringComparison.OrdinalIgnoreCase))
                return new List<Sheet> { new Sheet { Name = Path.GetFileNameWithoutExtension(fileName), Rows = ReadCsv(bytes) } };
            if ((fileName ?? "").EndsWith(".xls", StringComparison.OrdinalIgnoreCase))
                throw new Exception("ไฟล์ .xls แบบเก่าอ่านไม่ได้ กรุณา Save As เป็น .xlsx");
            return ReadXlsx(bytes);
        }

        public static List<List<string>> ReadCsv(byte[] bytes)
        {
            string text = Encoding.UTF8.GetString(bytes).TrimStart('﻿');
            var rows = new List<List<string>>(); var row = new List<string>(); var cell = new StringBuilder(); bool q = false;
            for (int i = 0; i < text.Length; i++)
            {
                char c = text[i];
                if (q) { if (c == '"') { if (i + 1 < text.Length && text[i + 1] == '"') { cell.Append('"'); i++; } else q = false; } else cell.Append(c); }
                else if (c == '"') q = true;
                else if (c == ',') { row.Add(cell.ToString()); cell.Clear(); }
                else if (c == '\n' || c == '\r')
                {
                    if (c == '\r' && i + 1 < text.Length && text[i + 1] == '\n') i++;
                    row.Add(cell.ToString()); cell.Clear(); rows.Add(row); row = new List<string>();
                }
                else cell.Append(c);
            }
            if (cell.Length > 0 || row.Count > 0) { row.Add(cell.ToString()); rows.Add(row); }
            return rows;
        }

        static XmlDocument Xml(ZipArchive zip, string path)
        {
            var e = zip.GetEntry(path); if (e == null) return null;
            var d = new XmlDocument(); using (var st = e.Open()) d.Load(st); return d;
        }

        public static List<Sheet> ReadXlsx(byte[] bytes)
        {
            var result = new List<Sheet>();
            using (var zip = new ZipArchive(new MemoryStream(bytes), ZipArchiveMode.Read))
            {
                var shared = new List<string>();
                var sd = Xml(zip, "xl/sharedStrings.xml");
                if (sd != null)
                    foreach (XmlNode si in sd.GetElementsByTagName("si"))
                    {
                        var sb = new StringBuilder();
                        foreach (XmlNode t in ((XmlElement)si).GetElementsByTagName("t"))
                            if (t.ParentNode == null || t.ParentNode.LocalName != "rPh") sb.Append(t.InnerText);   // ไม่เอาคำอ่าน (phonetic)
                        shared.Add(sb.ToString());
                    }

                var wb = Xml(zip, "xl/workbook.xml");
                var rel = Xml(zip, "xl/_rels/workbook.xml.rels");
                if (wb == null) throw new Exception("อ่านไฟล์ Excel ไม่ได้");
                var targets = new Dictionary<string, string>();
                if (rel != null)
                    foreach (XmlNode n in rel.GetElementsByTagName("Relationship"))
                    {
                        string tg = n.Attributes["Target"].Value;
                        targets[n.Attributes["Id"].Value] = tg.StartsWith("/") ? tg.TrimStart('/') : "xl/" + tg;
                    }

                int idx = 0;
                foreach (XmlNode s in wb.GetElementsByTagName("sheet"))
                {
                    idx++;
                    string rid = null;
                    foreach (XmlAttribute a in s.Attributes) if (a.LocalName == "id") rid = a.Value;
                    string path;
                    if (rid == null || !targets.TryGetValue(rid, out path)) path = "xl/worksheets/sheet" + idx + ".xml";
                    var doc = Xml(zip, path);
                    if (doc == null) continue;
                    var st = s.Attributes["state"];
                    var sh = new Sheet { Name = s.Attributes["name"] != null ? s.Attributes["name"].Value : "Sheet" + idx, Hidden = st != null && st.Value != "visible" };
                    ReadSheet(doc, shared, sh.Rows);
                    result.Add(sh);
                }
            }
            return result;
        }

        static void ReadSheet(XmlDocument doc, List<string> shared, List<List<string>> rows)
        {
            foreach (XmlNode r in doc.GetElementsByTagName("row"))
            {
                int rIdx = r.Attributes["r"] != null ? int.Parse(r.Attributes["r"].Value, CultureInfo.InvariantCulture) - 1 : rows.Count;
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
                        decimal dv;
                        if (decimal.TryParse(val, NumberStyles.Float, CultureInfo.InvariantCulture, out dv) && dv == Math.Truncate(dv))
                            val = Math.Truncate(dv).ToString(CultureInfo.InvariantCulture);
                    }
                    row.Add(val);
                }
                if (rows.Count == rIdx) rows.Add(row); else rows[rIdx] = row;
            }
        }

        static int ColIndex(string cellRef)
        {
            int n = 0;
            foreach (char ch in cellRef) { if (!char.IsLetter(ch)) break; n = n * 26 + (char.ToUpperInvariant(ch) - 'A' + 1); }
            return n - 1;
        }

        /// <summary>แปลงวันที่จาก Excel (ตัวเลข) / d/M/yyyy / yyyy-MM-dd → yyyy-MM-dd · อ่านไม่ได้ = null · ปี พ.ศ. แปลงเป็น ค.ศ.</summary>
        public static string NormDate(string s)
        {
            if (string.IsNullOrWhiteSpace(s)) return "";
            s = s.Trim();
            double oa;
            if (double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out oa))
                return oa > 1000 && oa < 80000 ? DateTime.FromOADate(oa).ToString("yyyy-MM-dd") : null;
            DateTime dt;
            string[] fm = { "yyyy-MM-dd", "yyyy/MM/dd", "d/M/yyyy", "dd/MM/yyyy", "d-M-yyyy", "d.M.yyyy", "yyyy-MM-dd HH:mm:ss", "d/M/yyyy H:mm:ss", "d-MMM-yy", "d-MMM-yyyy", "d MMM yyyy" };
            if (!DateTime.TryParseExact(s, fm, CultureInfo.InvariantCulture, DateTimeStyles.None, out dt)) return null;
            if (dt.Year > 2400) dt = dt.AddYears(-543);
            if (dt.Year < 2000 && System.Text.RegularExpressions.Regex.IsMatch(s, @"[^\d]\d{2}$")) dt = dt.AddYears(100);   // ปี 2 หลัก "27-Feb-30" = 2030 ไม่ใช่ 1930
            return dt.ToString("yyyy-MM-dd");
        }

        /// <summary>ตัดช่องว่าง / ตัวพิเศษออก + ตัวเล็ก (ใช้เทียบหัวตาราง)</summary>
        public static string Key(string s)
        {
            var sb = new StringBuilder();
            foreach (char ch in (s ?? "").ToLowerInvariant()) if (char.IsLetterOrDigit(ch)) sb.Append(ch);
            return sb.ToString();
        }
    }
}
