<%@ Page Title="Factory System" Language="C#" MasterPageFile="~/Site.Master"
    AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="Dashbord._Default" %>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<style>
    .home { max-width:1400px; margin:0 auto; padding:24px 18px 40px; }

    .hero {
        padding:26px 28px;
        border-radius:20px;
        background:#fff;
        border:1px solid #e2e8f0;
        box-shadow:0 1px 2px rgba(15,23,42,.06), 0 8px 24px rgba(15,23,42,.06);
        display:flex; align-items:center; gap:20px; flex-wrap:wrap;
    }
    .hero h1 { margin:0; font-size:26px; }
    .hero p { margin:4px 0 0; color:#64748b; }
    .hero .stat { margin-left:auto; display:flex; gap:12px; }
    .hero .stat div {
        padding:10px 18px; border-radius:14px; background:#f8fafc; border:1px solid #e2e8f0; text-align:center;
    }
    .hero .stat b { display:block; font-size:24px; color:#4f46e5; }
    .hero .stat span { font-size:12px; color:#64748b; letter-spacing:.06em; }

    .depts {
        margin-top:18px;
        display:grid;
        grid-template-columns:repeat(auto-fill, minmax(300px, 1fr));
        gap:16px;
    }

    .dept {
        background:#fff;
        border:1px solid #e2e8f0;
        border-radius:18px;
        box-shadow:0 1px 2px rgba(15,23,42,.06), 0 8px 24px rgba(15,23,42,.06);
        padding:18px;
    }
    .dept-head { display:flex; align-items:center; gap:12px; margin-bottom:12px; }
    .dept-head .ic {
        width:42px; height:42px; border-radius:12px;
        display:grid; place-items:center;
        background:linear-gradient(135deg,#6366f1,#8b5cf6); color:#fff;
    }
    .dept-head h2 { margin:0; font-size:18px; }
    .dept-head small { color:#64748b; font-size:12px; }

    .dept a {
        display:flex; align-items:center; gap:10px;
        padding:10px 12px; margin-top:6px;
        border-radius:12px;
        border:1px solid #eef2f7;
        color:#0f172a; text-decoration:none; font-size:14px;
        transition:background .15s, border-color .15s, transform .15s;
    }
    .dept a:hover { background:#eef2ff; border-color:#c7d2fe; transform:translateX(2px); }
    .dept a .dot { width:8px; height:8px; border-radius:50%; background:#10b981; }
    .dept a .go { margin-left:auto; color:#6366f1; font-weight:700; }
    .dept a.soon { color:#94a3b8; cursor:default; }
    .dept a.soon:hover { background:transparent; border-color:#eef2f7; transform:none; }
    .dept a.soon .dot { background:#cbd5e1; }
    .dept a.soon .go {
        font-size:10px; letter-spacing:.06em; padding:2px 7px; border-radius:999px;
        background:#f1f5f9; color:#94a3b8;
    }

    /* เมนูย่อย (กดแล้วกางออก) */
    .dept .grp > a.has-sub .go { transition:transform .15s; }
    .dept .grp.open > a.has-sub { background:#eef2ff; border-color:#c7d2fe; }
    .dept .grp.open > a.has-sub .go { transform:rotate(90deg); }
    .dept .sub {
        display:none; margin:6px 0 2px 14px; padding-left:10px; border-left:2px solid #e0e7ff;
        grid-template-columns:1fr 1fr; gap:4px;
    }
    .dept .grp.open > .sub { display:grid; }
    .dept .sub a { margin-top:0; padding:7px 10px; font-size:13px; }
    .dept .sub a .dot { width:6px; height:6px; background:#a5b4fc; }
</style>
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="home">

    <div class="hero">
        <div>
            <h1>Factory Management System</h1>
            <p>ERP + OEE · เลือกเมนูตามแผนกด้านล่าง หรือจากแถบเมนูด้านบน</p>
        </div>
        <div class="stat">
            <asp:Literal ID="litStats" runat="server" />
        </div>
    </div>

    <div class="depts">
        <asp:Literal ID="litDepts" runat="server" />
    </div>

</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script>
    // @ts-nocheck
    // กดเมนูที่มีเมนูย่อย (เช่น MC Monitor) = กาง/หุบรายการ
    document.addEventListener('click', function (e) {
        var a = e.target.closest('.dept a.has-sub');
        if (!a) return;
        e.preventDefault();
        a.parentNode.classList.toggle('open');
    });
</script>
</asp:Content>
