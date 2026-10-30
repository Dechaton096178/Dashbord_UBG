using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;

namespace Dashbord
{
    // =========================================================
    // HR : ผู้ใช้ที่ล็อกอินอยู่ (เก็บใน Session)
    //   role : admin (ทุกอย่าง + จัดการผู้ใช้) · hr (เพิ่ม/แก้/ลบ พนักงาน) · viewer (ดูอย่างเดียว ไม่เห็นข้อมูลส่วนตัว)
    // =========================================================
    [Serializable]
    public class HrSessionUser
    {
        public int Id;
        public string Username, DisplayName, Role;
        public bool MustChange;
        public List<string> Depts = new List<string>();   // ไม่ใช่ admin / hr : เห็นได้เฉพาะแผนกเหล่านี้ (ว่าง = ไม่เห็นแผนกใดเลย)
        public bool IsAdmin { get { return Role == "admin"; } }
        public bool IsHr { get { return Role == "admin" || Role == "hr"; } }
        public bool CanEdit { get { return Role == "admin" || Role == "hr"; } }
        public bool CanSeeSensitive { get { return CanEdit; } }
        /// <summary>เขียนใบลา / ใบขอ OT ได้</summary>
        public bool CanRequest { get { return Role == "admin" || Role == "hr" || Role == "manager" || Role == "supervisor"; } }
        /// <summary>พนักงานแผนกนี้อยู่ในความดูแลไหม · admin / hr = ทุกแผนก · คนอื่นเฉพาะแผนกที่ติ๊กไว้ใน HR Users</summary>
        public bool InScope(string dept)
        {
            if (IsHr) return true;
            if (Depts == null || Depts.Count == 0) return false;
            return Depts.Any(d => string.Equals(d.Trim(), (dept ?? "").Trim(), StringComparison.OrdinalIgnoreCase));
        }
    }

    // =========================================================
    // HrAuth : ล็อกอิน / ล็อกเอาต์ / เข้ารหัสผ่าน (PBKDF2) / กันเดารหัส
    // =========================================================
    public static class HrAuth
    {
        public const string LOGIN_PAGE = "HrLogin.aspx";
        public const string HOME_PAGE = "HrEmployee.aspx";
        public const string USER_HOME = "OtRequest.aspx";   // หน้าแรกของคนที่ไม่ใช่ admin / hr (เข้า Employee Directory ไม่ได้)
        public const int SESSION_MIN = 480;          // อยู่ในระบบได้ 8 ชม. ถ้าไม่ได้ใช้งาน
        public const int MIN_PW_LEN = 6;
        public static readonly string[] ROLES = { "admin", "hr", "manager", "supervisor", "viewer" };

        const string KEY = "HR_USER";
        const int MAX_FAIL = 5;                      // ใส่รหัสผิดเกิน 5 ครั้ง -> ล็อก 5 นาที
        const int LOCK_MIN = 5;
        const int PBKDF2_ITER = 50000;

        public static HrSessionUser Current(HttpContext ctx)
        {
            return ctx != null && ctx.Session != null ? ctx.Session[KEY] as HrSessionUser : null;
        }

        public static void SignIn(HttpContext ctx, HrSessionUser u)
        {
            ctx.Session[KEY] = u;
            ctx.Session.Timeout = SESSION_MIN;
        }

        public static void SignOut(HttpContext ctx)
        {
            if (ctx.Session == null) return;
            ctx.Session.Remove(KEY);
            ctx.Session.Abandon();
        }

        // ---------- รหัสผ่าน : pbkdf2$iter$salt$hash (SHA-256) ----------
        public static string HashPassword(string pw)
        {
            byte[] salt = new byte[16];
            using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(salt);
            byte[] h;
            using (var kdf = new Rfc2898DeriveBytes(pw ?? "", salt, PBKDF2_ITER, HashAlgorithmName.SHA256)) h = kdf.GetBytes(32);
            return "pbkdf2$" + PBKDF2_ITER.ToString(CultureInfo.InvariantCulture) + "$" + Convert.ToBase64String(salt) + "$" + Convert.ToBase64String(h);
        }

        public static bool VerifyPassword(string pw, string stored)
        {
            try
            {
                string[] p = (stored ?? "").Split('$');
                if (p.Length != 4 || p[0] != "pbkdf2") return false;
                int iter = int.Parse(p[1], CultureInfo.InvariantCulture);
                byte[] salt = Convert.FromBase64String(p[2]), want = Convert.FromBase64String(p[3]), got;
                using (var kdf = new Rfc2898DeriveBytes(pw ?? "", salt, iter, HashAlgorithmName.SHA256)) got = kdf.GetBytes(want.Length);
                int diff = 0;
                for (int i = 0; i < want.Length; i++) diff |= want[i] ^ got[i];   // เทียบแบบเวลาคงที่
                return diff == 0;
            }
            catch { return false; }
        }

        public static string CheckNewPassword(string pw)
        {
            if (string.IsNullOrEmpty(pw) || pw.Length < MIN_PW_LEN) return "รหัสผ่านต้องยาวอย่างน้อย " + MIN_PW_LEN + " ตัวอักษร";
            if (pw.Length > 100) return "รหัสผ่านยาวเกินไป";
            return null;
        }

        // ---------- กันเดารหัสผ่าน (นับตาม username + IP) ----------
        class Fail { public int Count; public DateTime Until; }
        static readonly Dictionary<string, Fail> _fails = new Dictionary<string, Fail>(StringComparer.OrdinalIgnoreCase);

        public static string LockedMessage(string user, string ip)
        {
            lock (_fails)
            {
                Fail f;
                if (_fails.TryGetValue(user + "|" + ip, out f) && f.Until > DateTime.Now)
                    return "ใส่รหัสผิดหลายครั้ง กรุณารอ " + Math.Ceiling((f.Until - DateTime.Now).TotalMinutes) + " นาที";
            }
            return null;
        }

        public static void RecordFail(string user, string ip)
        {
            lock (_fails)
            {
                string k = user + "|" + ip; Fail f;
                if (!_fails.TryGetValue(k, out f) || (f.Until != DateTime.MinValue && f.Until <= DateTime.Now)) _fails[k] = f = new Fail();
                if (++f.Count >= MAX_FAIL) f.Until = DateTime.Now.AddMinutes(LOCK_MIN);
            }
        }

        public static void ClearFail(string user, string ip)
        {
            lock (_fails) _fails.Remove(user + "|" + ip);
        }

        /// <summary>ReturnUrl ต้องเป็น path ภายในเว็บนี้เท่านั้น (กันพาไปเว็บอื่น)</summary>
        public static string SafeReturnUrl(string url, string fallback)
        {
            if (string.IsNullOrEmpty(url) || !url.StartsWith("/") || url.StartsWith("//") || url.Contains("\\") || url.Contains(":")) return fallback;
            if (url.IndexOf(LOGIN_PAGE, StringComparison.OrdinalIgnoreCase) >= 0) return fallback;
            return url;
        }
    }

    // =========================================================
    // HrPage : หน้าแม่ของทุกหน้า HR -> ยังไม่ล็อกอิน = ไปหน้า HrLogin.aspx ก่อน
    //   มี JSON API ในตัว (เหมือนหน้า EmailList) : GET/POST ?format=...
    // =========================================================
    public abstract class HrPage : Page
    {
        protected static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        protected HrSessionUser HrUser;
        string _apiOutput;

        /// <summary>true = เฉพาะ admin</summary>
        protected virtual bool AdminOnly { get { return false; } }
        /// <summary>true = เฉพาะ admin / hr</summary>
        protected virtual bool HrOnly { get { return false; } }

        protected bool IsApi { get { return Request.QueryString["format"] != null; } }

        protected override void OnInit(EventArgs e)
        {
            base.OnInit(e);
            HrUser = HrAuth.Current(Context);

            // เช็คกับ DB ทุกครั้ง : ผู้ใช้ถูกปิด / เปลี่ยนสิทธิ์ -> มีผลทันที
            if (HrUser != null)
            {
                HrSessionUser fresh = null;
                try { fresh = OeeDb.HrUserSession(HrUser.Id); } catch { fresh = HrUser; }   // DB ล่มชั่วคราว ใช้ของเดิม
                if (fresh == null) { HrAuth.SignOut(Context); HrUser = null; }
                else { HrUser = fresh; Session["HR_USER"] = fresh; }
            }

            if (HrUser == null || HrUser.MustChange)
            {
                if (IsApi) Deny(403, "กรุณาเข้าสู่ระบบ / Please log in", true);   // ไม่ใช้ 401 : IIS / Forms auth จะเปลี่ยนเป็นหน้า login ของมันเอง
                Response.Redirect(ResolveUrl("~/" + HrAuth.LOGIN_PAGE) + "?ReturnUrl=" + HttpUtility.UrlEncode(Request.RawUrl), true);
                return;
            }
            if (AdminOnly && !HrUser.IsAdmin)
            {
                if (IsApi) Deny(403, "เฉพาะผู้ดูแลระบบ (admin)", false);
                Response.Redirect(ResolveUrl("~/" + HrAuth.HOME_PAGE), true);
                return;
            }
            if (HrOnly && !HrUser.IsHr)
            {
                if (IsApi) Deny(403, "เฉพาะ HR / admin", false);
                Response.Redirect(ResolveUrl("~/" + HrAuth.USER_HOME), true);
                return;
            }
            // กัน CSRF : POST ต้องมี header X-HR (ส่งจาก fetch ของหน้าเราเท่านั้น)
            if (IsApi && Request.HttpMethod == "POST" && Request.Headers["X-HR"] != "1") Deny(403, "bad request", false);
        }

        void Deny(int code, string err, bool login)
        {
            Response.Clear();
            Response.StatusCode = code;
            Response.TrySkipIisCustomErrors = true;
            Response.ContentType = "application/json; charset=utf-8";
            Response.Write(Json.Serialize(new { ok = false, error = err, login = login }));
            Response.End();
        }

        protected Dictionary<string, object> ReadBody()
        {
            string body;
            using (var r = new StreamReader(Request.InputStream, Encoding.UTF8)) body = r.ReadToEnd();
            return Json.Deserialize<Dictionary<string, object>>(body) ?? new Dictionary<string, object>();
        }

        protected static string Str(Dictionary<string, object> d, string k)
        {
            object o; return d.TryGetValue(k, out o) && o != null ? Convert.ToString(o, CultureInfo.InvariantCulture) : null;
        }

        protected object Me()
        {
            return new { id = HrUser.Id, user = HrUser.Username, name = HrUser.DisplayName, role = HrUser.Role, canEdit = HrUser.CanEdit, sensitive = HrUser.CanSeeSensitive, admin = HrUser.IsAdmin,
                         hr = HrUser.IsHr, canRequest = HrUser.CanRequest, depts = HrUser.Depts };
        }

        protected void Reply(int code, object body)
        {
            Response.StatusCode = code;
            Response.TrySkipIisCustomErrors = true;
            Response.ContentType = "application/json; charset=utf-8";
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            _apiOutput = Json.Serialize(body);
        }

        protected void SendCsv(string fileName, StringBuilder sb)
        {
            Response.Clear();
            Response.ContentType = "text/csv; charset=utf-8";
            Response.AddHeader("Content-Disposition", "attachment; filename=" + fileName);
            Response.BinaryWrite(Encoding.UTF8.GetPreamble());
            Response.BinaryWrite(Encoding.UTF8.GetBytes(sb.ToString()));
            Response.Flush();
            Response.SuppressContent = true;
            Context.ApplicationInstance.CompleteRequest();
        }

        protected static string Csv(string s)
        {
            s = s ?? "";
            return s.IndexOfAny(new[] { ',', '"', '\n', '\r' }) >= 0 ? "\"" + s.Replace("\"", "\"\"") + "\"" : s;
        }

        protected override void Render(HtmlTextWriter writer)
        {
            if (_apiOutput != null) writer.Write(_apiOutput);
            else base.Render(writer);
        }

        /// <summary>ชื่อผู้ใช้ + ปุ่มออกจากระบบ (ใส่ใน HeaderRight ของหน้า HR)</summary>
        protected string UserBadge()
        {
            if (HrUser == null) return "";
            string login = ResolveUrl("~/" + HrAuth.LOGIN_PAGE);
            return "<div class=\"hr-user\"><span class=\"hr-av\">" + HttpUtility.HtmlEncode((HrUser.DisplayName ?? HrUser.Username ?? "?").Substring(0, 1).ToUpperInvariant()) + "</span>" +
                   "<span class=\"hr-un\"><b>" + HttpUtility.HtmlEncode(HrUser.DisplayName) + "</b><em>" + HttpUtility.HtmlEncode(HrUser.Role == "supervisor" ? "leader" : HrUser.Role) + "</em></span>" +
                   "<a href=\"" + login + "?change=1\" title=\"Change password\">Password</a>" +
                   "<a href=\"" + login + "?logout=1\">Logout</a></div>";
        }
    }
}
