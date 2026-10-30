using System;
using System.Linq;

namespace Dashbord
{
    /// <summary>
    /// HrUsers.aspx — จัดการผู้ใช้ระบบ HR (เฉพาะ admin)
    ///   GET  ?format=list · ?format=log (ประวัติการใช้งานล่าสุด)
    ///   POST ?format=save {id, username, display_name, role, active, password} · delete {id}
    ///   ตั้ง / รีเซ็ตรหัสผ่าน -> ผู้ใช้ต้องเปลี่ยนรหัสเองตอนล็อกอินครั้งถัดไป
    /// </summary>
    public partial class HrUsers : HrPage
    {
        protected override bool AdminOnly { get { return true; } }

        protected void Page_Load(object sender, EventArgs e)
        {
            string fmt = (Request.QueryString["format"] ?? "").ToLowerInvariant();
            if (fmt == "") return;
            try
            {
                if (Request.HttpMethod == "GET")
                {
                    if (fmt == "list")
                    {
                        var depts = OeeDb.EmpList(false).Select(r => System.Convert.ToString(r["department"])).Where(x => x.Length > 0).Distinct().OrderBy(x => x).ToList();
                        Reply(200, new { ok = true, me = Me(), rows = OeeDb.HrUserList(), roles = HrAuth.ROLES, departments = depts }); return;
                    }
                    if (fmt == "log") { Reply(200, new { ok = true, rows = OeeDb.HrLogList(null, 300) }); return; }
                    Reply(400, new { ok = false, error = "unknown format" }); return;
                }
                if (Request.HttpMethod != "POST") { Reply(405, new { ok = false, error = "method not allowed" }); return; }
                var d = ReadBody();
                int id; int.TryParse(Str(d, "id"), out id);
                string ip = Request.UserHostAddress;
                if (fmt == "save")
                {
                    string act = Str(d, "active"), role = Str(d, "role");
                    if (role != "admin" && role != "hr" && Str(d, "depts").Trim().Length == 0)
                        throw new Exception("เลือกแผนกอย่างน้อย 1 แผนก (ยกเว้น admin / hr ที่เห็นทุกแผนก)");
                    id = OeeDb.HrUserSave(id, Str(d, "username"), Str(d, "display_name"), Str(d, "role"),
                                          act == "True" || act == "true" || act == "1", Str(d, "password"), HrUser.Id, HrUser.Username, ip, Str(d, "depts"));
                    Reply(200, new { ok = true, id = id });
                }
                else if (fmt == "delete")
                {
                    if (id <= 0) throw new Exception("missing id");
                    OeeDb.HrUserDelete(id, HrUser.Id, HrUser.Username, ip);
                    Reply(200, new { ok = true });
                }
                else Reply(400, new { ok = false, error = "unknown format" });
            }
            catch (Exception ex) { Reply(500, new { ok = false, error = ex.Message }); }
        }
    }
}
