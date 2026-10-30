using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;

namespace Dashbord
{
    /// <summary>
    /// HrLogin.aspx — เข้าสู่ระบบ HR (หน้า HR ทุกหน้าส่งมาที่นี่ถ้ายังไม่ล็อกอิน)
    ///   ?ReturnUrl=...   ล็อกอินเสร็จกลับไปหน้านั้น
    ///   ?logout=1        ออกจากระบบ
    ///   ?change=1        เปลี่ยนรหัสผ่าน (ต้องล็อกอินอยู่)
    ///   POST ?format=login {username, password} · changepw {old, new}
    ///   ผู้ใช้คนแรก : admin / admin1234 (ระบบบังคับเปลี่ยนรหัสตอนเข้าครั้งแรก) · เพิ่มผู้ใช้ที่หน้า HrUsers.aspx
    /// </summary>
    public partial class HrLogin : Page
    {
        static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
        string _apiOutput;

        protected string Mode = "login";     // login | change
        protected string NextUrl;
        protected string WhoName = "";
        protected string DbError = "";

        protected void Page_Load(object sender, EventArgs e)
        {
            string home = ResolveUrl("~/" + HrAuth.HOME_PAGE);
            NextUrl = HrAuth.SafeReturnUrl(Request.QueryString["ReturnUrl"], home);
            HrSessionUser me = HrAuth.Current(Context);
            string fmt = (Request.QueryString["format"] ?? "").ToLowerInvariant();

            if (fmt != "") { Api(fmt, me); return; }

            if (Request.QueryString["logout"] == "1")
            {
                if (me != null) OeeDb.HrLog(me.Username, "logout", null, null, Request.UserHostAddress);
                HrAuth.SignOut(Context);
                Response.Redirect(ResolveUrl("~/" + HrAuth.LOGIN_PAGE), false);
                Context.ApplicationInstance.CompleteRequest();
                return;
            }
            if (me != null && (me.MustChange || Request.QueryString["change"] == "1"))
            {
                Mode = "change";
                WhoName = me.DisplayName ?? me.Username;
                if (!me.MustChange && Request.UrlReferrer != null && Request.UrlReferrer.Host == Request.Url.Host)
                    NextUrl = HrAuth.SafeReturnUrl(Request.UrlReferrer.PathAndQuery, home);   // เปลี่ยนรหัสเสร็จ กลับหน้าเดิม
            }
            else if (me != null)
            {
                Response.Redirect(NextUrl, false);
                Context.ApplicationInstance.CompleteRequest();
                return;
            }
            // เช็ค DB ตั้งแต่เปิดหน้า (สร้างตาราง + ผู้ใช้ admin ครั้งแรก)
            try { OeeDb.HrUserFind("-"); } catch (Exception ex) { DbError = "Database error: " + ex.Message; }
        }

        void Api(string fmt, HrSessionUser me)
        {
            try
            {
                if (Request.HttpMethod != "POST" || Request.Headers["X-HR"] != "1") { Reply(400, new { ok = false, error = "bad request" }); return; }
                string body;
                using (var r = new StreamReader(Request.InputStream, Encoding.UTF8)) body = r.ReadToEnd();
                var d = Json.Deserialize<Dictionary<string, object>>(body) ?? new Dictionary<string, object>();
                string ip = Request.UserHostAddress;

                if (fmt == "login")
                {
                    string user = (Str(d, "username") ?? "").Trim(), pw = Str(d, "password") ?? "";
                    if (user.Length == 0 || pw.Length == 0) { Reply(400, new { ok = false, error = "กรุณาใส่ Username และ Password" }); return; }
                    string locked = HrAuth.LockedMessage(user, ip);
                    if (locked != null) { Reply(429, new { ok = false, error = locked }); return; }
                    OeeDb.HrUserRow u = OeeDb.HrUserFind(user);
                    if (u == null || !HrAuth.VerifyPassword(pw, u.PwHash))
                    {
                        HrAuth.RecordFail(user, ip);
                        OeeDb.HrLog(user, "login-fail", null, null, ip);
                        Reply(403, new { ok = false, error = "Username หรือ Password ไม่ถูกต้อง" });
                        return;
                    }
                    if (!u.Active) { Reply(403, new { ok = false, error = "บัญชีนี้ถูกปิดใช้งาน กรุณาติดต่อผู้ดูแลระบบ" }); return; }
                    HrAuth.ClearFail(user, ip);
                    HrAuth.SignIn(Context, u.ToSession());
                    OeeDb.HrUserLoggedIn(u.Id, ip);
                    Reply(200, new { ok = true, mustChange = u.MustChange, name = u.DisplayName ?? u.Username });
                }
                else if (fmt == "changepw")
                {
                    if (me == null) { Reply(403, new { ok = false, error = "กรุณาเข้าสู่ระบบก่อน" }); return; }
                    string oldPw = Str(d, "old") ?? "", newPw = Str(d, "new") ?? "";
                    OeeDb.HrUserRow u = OeeDb.HrUserFind(me.Username);
                    if (u == null || !u.Active) { HrAuth.SignOut(Context); Reply(403, new { ok = false, error = "ไม่พบผู้ใช้" }); return; }
                    if (!HrAuth.VerifyPassword(oldPw, u.PwHash)) { Reply(400, new { ok = false, error = "รหัสผ่านเดิมไม่ถูกต้อง" }); return; }
                    if (oldPw == newPw) { Reply(400, new { ok = false, error = "รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสเดิม" }); return; }
                    OeeDb.HrUserSetPassword(u.Id, newPw, false, u.Username, ip);
                    me.MustChange = false;
                    HrAuth.SignIn(Context, me);
                    Reply(200, new { ok = true });
                }
                else Reply(400, new { ok = false, error = "unknown format" });
            }
            catch (Exception ex) { Reply(500, new { ok = false, error = ex.Message }); }
        }

        static string Str(Dictionary<string, object> d, string k)
        {
            object o; return d.TryGetValue(k, out o) && o != null ? Convert.ToString(o, CultureInfo.InvariantCulture) : null;
        }

        protected string JsStr(string s) { return HttpUtility.JavaScriptStringEncode(s ?? "", true); }

        void Reply(int code, object body)
        {
            Response.StatusCode = code;
            Response.TrySkipIisCustomErrors = true;
            Response.ContentType = "application/json; charset=utf-8";
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            _apiOutput = Json.Serialize(body);
        }

        protected override void Render(HtmlTextWriter writer)
        {
            if (_apiOutput != null) writer.Write(_apiOutput);
            else base.Render(writer);
        }
    }
}
