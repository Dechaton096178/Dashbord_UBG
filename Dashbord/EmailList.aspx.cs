using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;

namespace Dashbord
{
    /// <summary>
    /// EmailList.aspx — รายชื่ออีเมลบริษัท (แผนก IT) · เพิ่ม / แก้ไข / ลบ (ต้องใส่รหัส EDIT_PIN) · ไม่เก็บรหัสผ่าน
    ///   GET  ?format=list      รายการทั้งหมด
    ///   GET  ?format=csv       ดาวน์โหลด CSV
    ///   POST ?format=checkpin {pin} · save {pin, id, ...} · delete {pin, id}
    ///   ข้อมูลอยู่ใน MySQL OEE : it_email (สร้าง + นำเข้าข้อมูลตั้งต้นเองครั้งแรก)
    /// </summary>
    public partial class EmailList : Page
    {
        public const string EDIT_PIN = "ubg2026";     // รหัสแก้ไข (ว่าง = ใครก็แก้ได้)
        static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        string _apiOutput;

        protected void Page_Load(object sender, EventArgs e)
        {
            string fmt = (Request.QueryString["format"] ?? "").ToLowerInvariant();
            if (fmt == "") return;
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            try
            {
                if (Request.HttpMethod == "GET")
                {
                    if (fmt == "list") { Reply(200, new { ok = true, rows = OeeDb.EmList() }); return; }
                    if (fmt == "csv") { SendCsv(); return; }
                    Reply(400, new { ok = false, error = "unknown format" }); return;
                }
                if (Request.HttpMethod != "POST") { Reply(405, new { ok = false, error = "method not allowed" }); return; }
                string body;
                using (var r = new StreamReader(Request.InputStream, Encoding.UTF8)) body = r.ReadToEnd();
                var d = Json.Deserialize<Dictionary<string, object>>(body) ?? new Dictionary<string, object>();
                if (EDIT_PIN.Length > 0 && Str(d, "pin") != EDIT_PIN) { Reply(403, new { ok = false, error = "รหัสแก้ไขไม่ถูกต้อง / Wrong PIN" }); return; }
                int id; int.TryParse(Str(d, "id"), out id);
                if (fmt == "checkpin") Reply(200, new { ok = true });
                else if (fmt == "save")
                {
                    var v = new Dictionary<string, string>();
                    foreach (string f in OeeDb.EM_FIELDS) v[f] = Str(d, f);
                    Reply(200, new { ok = true, id = OeeDb.EmSave(id, v, Request.UserHostAddress) });
                }
                else if (fmt == "delete")
                {
                    if (id <= 0) throw new Exception("missing id");
                    OeeDb.EmDelete(id);
                    Reply(200, new { ok = true });
                }
                else Reply(400, new { ok = false, error = "unknown format" });
            }
            catch (Exception ex) { Reply(500, new { ok = false, error = ex.Message }); }
        }

        void SendCsv()
        {
            var sb = new StringBuilder("No,Email,Type,Position,Name (TH),Name (EN),Code,Status,Remark\r\n");
            foreach (var r in OeeDb.EmList())
                sb.Append(string.Join(",", new[] { "item_no", "email", "mail_type", "position", "name_th", "name_en", "emp_code", "status", "remark" }
                    .Select(f => Csv(Convert.ToString(r[f], CultureInfo.InvariantCulture))))).Append("\r\n");
            Response.Clear();
            Response.ContentType = "text/csv; charset=utf-8";
            Response.AddHeader("Content-Disposition", "attachment; filename=EmailList_" + DateTime.Now.ToString("yyyyMMdd") + ".csv");
            Response.BinaryWrite(Encoding.UTF8.GetPreamble());
            Response.BinaryWrite(Encoding.UTF8.GetBytes(sb.ToString()));
            Response.Flush();
            Response.SuppressContent = true;
            Context.ApplicationInstance.CompleteRequest();
        }
        static string Csv(string s) { s = s ?? ""; return s.IndexOfAny(new[] { ',', '"', '\n', '\r' }) >= 0 ? "\"" + s.Replace("\"", "\"\"") + "\"" : s; }
        static string Str(Dictionary<string, object> d, string k) { object o; return d.TryGetValue(k, out o) && o != null ? Convert.ToString(o, CultureInfo.InvariantCulture) : null; }

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
