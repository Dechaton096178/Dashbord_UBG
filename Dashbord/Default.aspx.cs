using System;
using System.Text;
using System.Web;

namespace Dashbord
{
    public partial class _Default : System.Web.UI.Page
    {
        int DeptCount = 0;
        int ReadyCount = 0;
        int SoonCount = 0;

        // หน้าแรก : การ์ดแผนก สร้างจากเมนูเดียวกับ Site.Master (AppMenu.MenuData)
        protected void Page_Load(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder();

            foreach (AppMenu.Dept d in AppMenu.MenuData)
            {
                DeptCount++;
                int ready = 0;
                foreach (AppMenu.MenuItem m in d.Items) if (m.Url != null) ready++;

                sb.Append("<div class=\"dept\"><div class=\"dept-head\"><span class=\"ic\">");
                sb.Append("<svg width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"" + d.Icon + "\"/></svg>");
                sb.Append("</span><div><h2>" + Enc(d.Name) + "</h2><small>" + ready + " / " + d.Items.Count + " pages ready</small></div></div>");

                foreach (AppMenu.MenuItem m in d.Items)
                {
                    if (m.Url == null)
                    {
                        SoonCount++;
                        sb.Append("<a class=\"soon\"><span class=\"dot\"></span>" + Enc(m.Title) + "<span class=\"go\">SOON</span></a>");
                    }
                    else if (m.HasChildren)
                    {
                        // เมนูที่มีเมนูย่อย : กดแล้วกางรายการออก
                        ReadyCount++;
                        sb.Append("<div class=\"grp\"><a class=\"has-sub\" href=\"" + ResolveUrl("~/" + m.Url) + "\"><span class=\"dot\"></span>" +
                                  Enc(m.Title) + "<span class=\"go\">▸</span></a><div class=\"sub\">");
                        foreach (AppMenu.MenuItem c in m.Children)
                            sb.Append("<a href=\"" + ResolveUrl("~/" + c.Url) + "\"><span class=\"dot\"></span>" + Enc(c.Title) + "</a>");
                        sb.Append("</div></div>");
                    }
                    else
                    {
                        ReadyCount++;
                        sb.Append("<a href=\"" + ResolveUrl("~/" + m.Url) + "\"><span class=\"dot\"></span>" + Enc(m.Title) + "<span class=\"go\">→</span></a>");
                    }
                }

                sb.Append("</div>");
            }

            litDepts.Text = sb.ToString();

            // ตัวเลขสรุปบนหัวหน้า
            litStats.Text =
                "<div><b>" + DeptCount + "</b><span>DEPARTMENTS</span></div>" +
                "<div><b>" + ReadyCount + "</b><span>READY</span></div>" +
                "<div><b>" + SoonCount + "</b><span>COMING SOON</span></div>";
        }

        private static string Enc(string s) { return HttpUtility.HtmlEncode(s); }
    }
}
