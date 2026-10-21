using System;
using System.Globalization;
using System.IO;
using System.Text;
using System.Web;

namespace Dashbord
{
    public partial class SiteMaster : System.Web.UI.MasterPage
    {
        // =========================================================
        // Page Load : สร้าง HTML ของเมนู + ไฮไลต์แผนก/หน้าปัจจุบัน
        // =========================================================
        protected void Page_Load(object sender, EventArgs e)
        {
            // เทียบชื่อหน้าแบบไม่สนนามสกุล รองรับทั้ง /PO_Search.aspx และ /PO_Search (FriendlyUrls)
            string current = Path.GetFileNameWithoutExtension(Request.Path ?? "").ToLowerInvariant();
            string curProc = Request.QueryString["proc"] ?? "";
            StringBuilder sb = new StringBuilder();

            // Home
            bool isHome = current == "default" || current == "";
            sb.Append("<li class=\"" + (isHome ? "active" : "") + "\">");
            sb.Append("<a href=\"" + ResolveUrl("~/Default.aspx") + "\">");
            sb.Append(Svg("M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"));
            sb.Append("Home</a></li>");

            foreach (AppMenu.Dept d in AppMenu.MenuData)
            {
                bool deptActive = false;
                foreach (AppMenu.MenuItem m in d.Items)
                {
                    if (m.Url != null && PageKey(m.Url) == current) deptActive = true;
                }

                sb.Append("<li class=\"" + (deptActive ? "active" : "") + "\">");
                sb.Append("<a data-dept=\"1\">" + Svg(d.Icon) + Enc(d.Name) + "<span class=\"caret\">▼</span></a>");
                sb.Append("<ul class=\"menu\"><li><h6>" + Enc(d.Name) + "</h6></li>");

                foreach (AppMenu.MenuItem m in d.Items)
                {
                    if (m.Url == null)
                    {
                        sb.Append("<li><a class=\"soon\"><span class=\"dot\"></span>" + Enc(m.Title) +
                                  "<span class=\"tag\">SOON</span></a></li>");
                    }
                    else if (m.HasChildren)
                    {
                        // เมนูที่มีเมนูย่อย : กดแล้วกางรายการออก (เปิดค้างไว้ถ้าอยู่หน้านั้น)
                        bool cur = PageKey(m.Url) == current;
                        sb.Append("<li class=\"has-sub" + (cur ? " sub-open" : "") + "\">");
                        sb.Append("<a data-sub=\"1\"" + (cur ? " class=\"current\"" : "") + "><span class=\"dot\"></span>" +
                                  Enc(m.Title) + "<span class=\"sub-caret\">▸</span></a><ul class=\"submenu\">");
                        foreach (AppMenu.MenuItem c in m.Children)
                        {
                            bool curChild = cur && QueryProc(c.Url) == curProc;
                            sb.Append("<li><a href=\"" + ResolveUrl("~/" + c.Url) + "\"" + (curChild ? " class=\"current\"" : "") +
                                      "><span class=\"dot\"></span>" + Enc(c.Title) + "</a></li>");
                        }
                        sb.Append("</ul></li>");
                    }
                    else
                    {
                        bool cur = PageKey(m.Url) == current;
                        sb.Append("<li><a href=\"" + ResolveUrl("~/" + m.Url) + "\"" + (cur ? " class=\"current\"" : "") +
                                  "><span class=\"dot\"></span>" + Enc(m.Title) + "</a></li>");
                    }
                }

                sb.Append("</ul></li>");
            }

            litMenu.Text = sb.ToString();

            // ---------- นับยอดเข้าชมหน้า (เฉพาะเปิดหน้าจริง : GET, ไม่ใช่ postback, ไม่ใช่ API ?format=) ----------
            try
            {
                if (Request.HttpMethod == "GET" && !Page.IsPostBack && Request.QueryString["format"] == null &&
                    !Response.SuppressContent && (Response.ContentType ?? "text/html").StartsWith("text/html", StringComparison.OrdinalIgnoreCase))
                {
                    OeeDb.ViewStat v = OeeDb.TrackView(isHome ? "default" : current, Request.UserHostAddress);
                    if (v != null)
                    {
                        CultureInfo ci = CultureInfo.InvariantCulture;
                        string tip = "Page views (this page)\nTotal: " + v.Total.ToString("N0", ci) +
                                     (v.Since.HasValue ? " since " + v.Since.Value.ToString("dd MMM yyyy", ci) : "") +
                                     "\nToday: " + v.Today.ToString("N0", ci) + " views · " + v.TodayVisitors.ToString("N0", ci) + " people (unique PC/IP)" +
                                     "\nSame PC reopening within " + OeeDb.VIEW_REPEAT_MIN + " min counts once";
                        ViewLabel = "<div class=\"pv-badge\" title=\"" + Enc(tip) + "\">" +
                                    "<svg width=\"12\" height=\"12\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.2\"><path d=\"M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z\"/><circle cx=\"12\" cy=\"12\" r=\"3\"/></svg>" +
                                    "<b>" + v.Total.ToString("N0", ci) + "</b><span>· Today " + v.Today.ToString("N0", ci) + "</span></div>";
                    }
                }
            }
            catch { }
        }

        /// <summary>ป้ายยอดเข้าชมมุมขวาล่าง (ว่าง = DB ไม่พร้อม / ไม่ได้นับ)</summary>
        protected string ViewLabel = "";

        private static string PageKey(string url)
        {
            int q = url.IndexOf('?');                 // ตัด query (?proc=...) ออกก่อน
            if (q >= 0) url = url.Substring(0, q);
            return Path.GetFileNameWithoutExtension(url).ToLowerInvariant();
        }

        private static string QueryProc(string url)
        {
            int q = url.IndexOf("proc=", StringComparison.OrdinalIgnoreCase);
            return q < 0 ? "" : Uri.UnescapeDataString(url.Substring(q + 5));
        }

        private static string Svg(string path)
        {
            return "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" " +
                   "stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"" + path + "\"/></svg>";
        }

        private static string Enc(string s)
        {
            return HttpUtility.HtmlEncode(s);
        }
    }
}
