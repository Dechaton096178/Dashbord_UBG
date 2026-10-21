<%@ Page Title="NG Dashboard" MasterPageFile="~/Site.Master" Language="C#" AutoEventWireup="true"
    CodeBehind="IOT_NGDashcord.aspx.cs"
    Inherits="Dashbord.IOT_NGDashcord" %>

<%-- =========================================================
     ใช้ Site.Master (Header + เมนูแผนก)
     ========================================================= --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<!-- [NEW] ปฏิทินแบบ dd/mm/yyyy -->
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/flatpickr/4.6.13/flatpickr.min.css" />
<script src="https://cdnjs.cloudflare.com/ajax/libs/flatpickr/4.6.13/flatpickr.min.js"></script>

<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js"></script>

<script>
    window.hasOwnProperty('Chart') ||
        document.write('<script src="Scripts/chart.umd.min.js"><\/script>');
</script>

<style>

    :root {
        --u:1;   /* ตัวคูณขนาดตามจอ (จอทีวีใหญ่ = ตัวใหญ่ขึ้น) ตั้งโดยสคริปต์ด้านล่าง */
        --bg:#eef2f7;
        --card:#ffffff;
        --ink:#0f172a;
        --mute:#64748b;
        --line:#e2e8f0;
        --accent:#6366f1;
        --shadow:0 calc(1px*var(--u)) calc(2px*var(--u)) rgba(15,23,42,.06), 0 calc(8px*var(--u)) calc(24px*var(--u)) rgba(15,23,42,.06);
    }

    * { box-sizing:border-box; }

    body {
        margin:0;
        font-family:'Sarabun',Tahoma,sans-serif;
        color:var(--ink);
        background:var(--bg);
    }

    .grid {
        display:grid;
        grid-template-columns:minmax(calc(250px*var(--u)), 15%) minmax(0, 1fr) minmax(calc(400px*var(--u)), 26%);   /* สัดส่วนตามความกว้างจอ */
        grid-template-rows:auto 1fr 1fr;
        gap:calc(16px*var(--u));
        padding:calc(16px*var(--u));
        height:calc(100vh - var(--header-h, 64px) * var(--u));
        min-height:calc(700px*var(--u));
    }

    /* ---------- CARD (ใช้ร่วมกัน) ---------- */
    .filters, .kpi, .panel {
        background:var(--card);
        border:calc(1px*var(--u)) solid var(--line);
        border-radius:calc(18px*var(--u));
        box-shadow:var(--shadow);
    }

    /* ---------- HEADER ---------- */
    .topbar {
        grid-column:1/-1;
        display:flex;
        align-items:center;
        gap:calc(14px*var(--u));
        padding:calc(14px*var(--u)) calc(20px*var(--u));
        border-radius:calc(18px*var(--u));
        background:linear-gradient(135deg,#1e1b4b,#312e81 60%,#4338ca);
        color:#fff;
        box-shadow:var(--shadow);
    }

    .topbar .logo {
        width:calc(46px*var(--u)); height:calc(46px*var(--u));
        border-radius:calc(12px*var(--u));
        display:grid; place-items:center;
        background:rgba(255,255,255,.14);
        border:calc(1px*var(--u)) solid rgba(255,255,255,.25);
    }

    .topbar h1 { margin:0; font-size:calc(22px*var(--u)); font-weight:700; line-height:1.2; }

    .topbar small {
        display:block;
        font-size:calc(12px*var(--u));
        font-weight:700;
        letter-spacing:.18em;
        color:#a5b4fc;
    }

    /* ---------- FILTER ---------- */
    .filters {
        grid-column:1/-1;
        display:flex;
        flex-wrap:wrap;
        gap:calc(14px*var(--u));
        align-items:flex-end;
        padding:calc(12px*var(--u)) calc(16px*var(--u));
    }

    .filters label {
        display:block;
        font-weight:600;
        font-size:calc(12px*var(--u));
        letter-spacing:.06em;
        text-transform:uppercase;
        color:var(--mute);
        margin-bottom:calc(5px*var(--u));
    }

    .filters input,
    .filters select {
        height:calc(36px*var(--u));
        min-width:calc(140px*var(--u));
        padding:0 calc(10px*var(--u));
        border:calc(1px*var(--u)) solid #cbd5e1;
        border-radius:calc(10px*var(--u));
        background:#f8fafc;
        color:var(--ink);
        font:inherit;
        font-size:calc(13px*var(--u));
        outline:none;
        transition:border-color .15s, box-shadow .15s, background .15s;
    }

    .filters input:focus,
    .filters select:focus {
        border-color:var(--accent);
        background:#fff;
        box-shadow:0 0 0 calc(3px*var(--u)) rgba(99,102,241,.18);
    }

    .dates { display:flex; gap:calc(8px*var(--u)); }

    .dates input { min-width:0!important; width:calc(132px*var(--u)); cursor:pointer; }

    .filters input.filter-button {
        height:calc(38px*var(--u));
        min-width:0;
        padding:0 calc(22px*var(--u));
        border:0;
        border-radius:calc(10px*var(--u));
        background:linear-gradient(135deg,#6366f1,#8b5cf6);
        color:#fff;
        font-family:inherit;
        font-size:calc(14px*var(--u));
        font-weight:600;
        cursor:pointer;
        box-shadow:0 calc(6px*var(--u)) calc(16px*var(--u)) rgba(99,102,241,.35);
        transition:transform .15s, box-shadow .15s;
    }

    .filters input.filter-button:hover {
        transform:translateY(-1px);
        box-shadow:0 calc(10px*var(--u)) calc(20px*var(--u)) rgba(99,102,241,.4);
    }

    /* ---------- KPI ---------- */
    .kpis {
        grid-row:2/4;
        display:flex;
        flex-direction:column;
        gap:calc(16px*var(--u));
        min-height:0;
    }

    .kpi {
        flex:1;
        position:relative;
        overflow:hidden;
        display:flex;
        flex-direction:column;
        justify-content:center;
        align-items:center;
        padding:calc(8px*var(--u)) calc(12px*var(--u));
        transition:transform .15s;
    }

    .kpi:hover { transform:translateY(-2px); }

    .kpi::before {
        content:"";
        position:absolute;
        left:0; top:0; bottom:0;
        width:calc(6px*var(--u));
        background:var(--k, #6366f1);
    }

    .kpi:nth-child(1) { --k:#4f46e5; --t:#eef2ff; }
    .kpi:nth-child(2) { --k:#0284c7; --t:#e0f2fe; }
    .kpi:nth-child(3) { --k:#db2777; --t:#fce7f3; }
    .kpi:nth-child(4) { --k:#d97706; --t:#fef3c7; }
    .kpi:nth-child(5) { --k:#059669; --t:#d1fae5; }

    .kpi {
        background:linear-gradient(135deg,#ffffff 35%, var(--t, #fff) 100%);
    }

    .kpi::before { width:calc(8px*var(--u)); }

    /* ตัวเลขใหญ่ + สีตามการ์ด */
    .kpi b {
        font-size:clamp(calc(34px*var(--u)), 3.4vw, calc(54px*var(--u)));   /* [CHANGED] เล็กลงจาก 52-80px */
        font-weight:800;
        line-height:1;
        letter-spacing:-.03em;
        color:var(--k);
        font-variant-numeric:tabular-nums;
        white-space:nowrap;          /* [NEW] ห้ามตัดบรรทัด ให้ JS ย่อฟอนต์แทน */
    }

    /* [NEW] ตัว K / M เล็กกว่าตัวเลข */
    .kpi b small.unit {
        font-size:.6em;
        font-weight:700;
        margin-left:calc(3px*var(--u));
        letter-spacing:0;
    }

    /* Label ของ ASP.NET เป็น <span> ต้องไม่ถูกสไตล์ caption ทับ */
    .kpi b span {
        font:inherit;
        color:inherit;
        letter-spacing:inherit;
        text-transform:none;
        margin:0;
    }

    /* ชื่อรายการ */
    .kpi > span {
        margin-top:calc(10px*var(--u));
        color:var(--ink);
        opacity:.7;
        font-size:calc(14px*var(--u));
        font-weight:700;
        letter-spacing:.1em;
        text-transform:uppercase;
    }

    /* ---------- REFRESH (นับถอยหลัง) ---------- */
    .refresh {
        margin-left:auto;
        display:flex;
        align-items:center;
        gap:calc(8px*var(--u));
        padding:calc(4px*var(--u)) calc(14px*var(--u)) calc(4px*var(--u)) calc(5px*var(--u));
        border:calc(1px*var(--u)) solid var(--line);
        border-radius:calc(999px*var(--u));
        background:#f8fafc;
        cursor:pointer;
        user-select:none;
        transition:box-shadow .15s, background .15s;
    }

    .refresh:hover { background:#fff; box-shadow:0 calc(4px*var(--u)) calc(14px*var(--u)) rgba(15,23,42,.1); }

    .ring {
        --p:360deg;
        width:calc(38px*var(--u));
        height:calc(38px*var(--u));
        border-radius:50%;
        display:grid;
        place-items:center;
        background:conic-gradient(#6366f1 var(--p), #e2e8f0 0);
    }

    .ring b {
        width:calc(30px*var(--u));
        height:calc(30px*var(--u));
        border-radius:50%;
        background:#fff;
        display:grid;
        place-items:center;
        font-size:calc(13px*var(--u));
        font-weight:700;
        font-variant-numeric:tabular-nums;
    }

    .refresh small {
        display:flex;
        align-items:center;
        gap:calc(6px*var(--u));
        font-size:calc(10px*var(--u));
        font-weight:700;
        letter-spacing:.1em;
        color:#059669;
    }

    .refresh small::before {
        content:"";
        width:calc(8px*var(--u));
        height:calc(8px*var(--u));
        border-radius:50%;
        background:#10b981;
        animation:pulse 1.4s infinite;
    }

    .refresh em { display:block; font-style:normal; font-size:calc(12px*var(--u)); line-height:1.2; color:var(--mute); }

    @keyframes pulse {
        0%   { box-shadow:0 0 0 0 rgba(16,185,129,.6); }
        100% { box-shadow:0 0 0 calc(9px*var(--u)) rgba(16,185,129,0); }
    }

    /* [NEW] REALTIME บนแบนเนอร์ (พื้นเข้ม) */
    .topbar .refresh {
        background:rgba(255,255,255,.1);
        border-color:rgba(255,255,255,.22);
    }
    .topbar .refresh:hover { background:rgba(255,255,255,.18); box-shadow:none; }
    .topbar .ring { background:conic-gradient(#a5b4fc var(--p), rgba(255,255,255,.18) 0); }
    .topbar .ring b { background:#312e81; color:#fff; }
    .topbar .refresh small { color:#6ee7b7; }
    .topbar .refresh em { color:#c7d2fe; }

    /* ---------- PANEL ---------- */
    .panel {
        padding:calc(16px*var(--u)) calc(20px*var(--u));
        min-width:0;
        min-height:0;
        display:flex;
        flex-direction:column;
    }

    .panel h2 {
        margin:0 0 calc(8px*var(--u));
        font-size:calc(18px*var(--u));
        font-weight:700;
        display:flex;
        align-items:center;
        gap:calc(10px*var(--u));
    }

    .panel h2::before {
        content:"";
        width:calc(10px*var(--u));
        height:calc(10px*var(--u));
        border-radius:50%;
        background:linear-gradient(135deg,#6366f1,#ec4899);
    }

    .hour { grid-column:2/4; }

    .matrix { overflow:hidden; }

    .cv { position:relative; flex:1; min-height:0; }

    /* ---------- TABS ---------- */
    .tabs {
        display:flex;
        gap:calc(4px*var(--u));
        padding:calc(4px*var(--u));
        margin:0 0 calc(12px*var(--u));
        background:#f1f5f9;
        border-radius:calc(12px*var(--u));
    }

    .tabs button {
        flex:1;
        padding:calc(7px*var(--u)) calc(8px*var(--u));
        border:0;
        border-radius:calc(9px*var(--u));
        background:transparent;
        color:var(--mute);
        font:inherit;
        font-size:calc(14px*var(--u));
        font-weight:600;
        cursor:pointer;
        transition:background .15s, color .15s;
    }

    .tabs button:hover { color:var(--ink); }

    .tabs button.on {
        background:linear-gradient(135deg,#6366f1,#8b5cf6);
        color:#fff;
        box-shadow:0 calc(4px*var(--u)) calc(12px*var(--u)) rgba(99,102,241,.35);
    }

    /* ---------- MATRIX ---------- */
    table.mx {
        border-collapse:separate;
        border-spacing:0;
        font-size:calc(14px*var(--u));
        min-width:100%;
        font-variant-numeric:tabular-nums;
    }

    table.mx th {
        text-align:right;
        font-size:calc(12px*var(--u));
        font-weight:700;
        letter-spacing:.06em;
        text-transform:uppercase;
        color:var(--mute);
        padding:calc(8px*var(--u)) calc(10px*var(--u));
        border-bottom:calc(2px*var(--u)) solid var(--line);
    }

    table.mx th:first-child,
    table.mx td:first-child { text-align:left; }

    table.mx td {
        padding:calc(9px*var(--u)) calc(10px*var(--u));
        text-align:right;
        border-bottom:calc(1px*var(--u)) solid #f1f5f9;
    }

    table.mx tbody tr:hover td { background:#f8fafc; }

    table.mx tr.tot td {
        font-weight:700;
        background:#f1f5f9;
        border-bottom:0;
    }

    table.mx tr.tot td:first-child { border-radius:calc(10px*var(--u)) 0 0 calc(10px*var(--u)); }
    table.mx tr.tot td:last-child  { border-radius:0 calc(10px*var(--u)) calc(10px*var(--u)) 0; }

    table.mx td.tot { font-weight:700; }

    /* [NEW] Matrix หลายคอลัมน์ : เลื่อนแนวนอนได้ คอลัมน์แรก/หัวตาราง/Total ติดอยู่กับที่ */
    .mx-wrap { flex:1; min-height:0; overflow:auto; }

    table.mx th, table.mx td { white-space:nowrap; }

    table.mx thead th {
        position:sticky; top:0; z-index:2;
        background:#fff;
    }

    table.mx th:first-child,
    table.mx td:first-child {
        position:sticky; left:0; z-index:1;
        background:#fff;
        border-right:calc(1px*var(--u)) solid var(--line);
    }

    table.mx thead th:first-child { z-index:3; }

    table.mx tr.tot td {
        position:sticky; bottom:0;
    }

    table.mx tr.tot td:first-child { z-index:2; background:#f1f5f9; }

    table.mx tbody tr:hover td:first-child { background:#f8fafc; }

    table.mx td.empty { color:#cbd5e1; }

    /* ---------- MOBILE ---------- */
    @media(max-width:1000px) {
        .grid { display:block; height:auto; }
        .grid > * { margin-bottom:calc(16px*var(--u)); }
        .kpis { flex-direction:row; flex-wrap:wrap; }
        .kpi { min-width:46%; padding:calc(18px*var(--u)) calc(12px*var(--u)); }
        .panel { height:calc(360px*var(--u)); }
    }


    /* ---------- ขยายตามจอทีวี ---------- */
    .site-header { zoom:var(--u); }   /* เมนูด้านบนของ Site.Master ขยายตามด้วย */
</style>

<style>
    /* ---------- ปุ่มปรับขนาด (A− / A+) ---------- */
    .zm { display:inline-flex; align-items:center; gap:calc(4px*var(--u)); height:calc(38px*var(--u)); padding:calc(3px*var(--u));
          background:#f8fafc; border:calc(1px*var(--u)) solid #cbd5e1; border-radius:calc(10px*var(--u)); }
    .zm button { font:inherit; font-size:calc(14px*var(--u)); font-weight:800; color:#4338ca; background:transparent; border:0;
                 height:100%; border-radius:calc(7px*var(--u)); padding:0 calc(10px*var(--u)); cursor:pointer; line-height:1; }
    .zm button:hover { background:#eef2ff; }
    .zm .lv { min-width:calc(84px*var(--u)); font-size:calc(13px*var(--u)); font-weight:700; color:#334155; background:#fff;
              border:calc(1px*var(--u)) solid #e2e8f0 !important; }
    .zm .lv.auto { color:#059669; }
</style>
<script>
    // ===== ขยายทั้งหน้าตามขนาดจอ (ออกแบบที่ 1600x900 / จอ 4K = ประมาณ x2.4) =====
    //   ลำดับ: ?scale=1.5 ในลิงก์ > ระดับที่กดปุ่มเลือกไว้ (จำแยกแต่ละจอ) > อัตโนมัติตามจอ
    (function () {
        var LEVELS = [0.75, 0.9, 1, 1.15, 1.3, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3, 3.5];
        function autoU() { return Math.max(1, Math.min(3, Math.min(window.innerWidth / 1600, window.innerHeight / 900))); }
        function saved() {
            var m = /[?&]scale=([\d.]+)/.exec(location.search);
            if (m) return Math.max(0.5, Math.min(4, parseFloat(m[1])));
            try { var v = parseFloat(localStorage.getItem('ng.scale')); if (v > 0) return v; } catch (e) { }
            return 0;   // 0 = อัตโนมัติ
        }
        var fixed = saved();
        function calcU() { return fixed > 0 ? fixed : autoU(); }
        function apply(redraw) {
            var u = calcU();
            var changed = Math.abs(u - (window.NG_U || 0)) >= 0.01;
            window.NG_U = u;
            document.documentElement.style.setProperty('--u', u.toFixed(3));
            var lv = document.getElementById('zmLv');
            if (lv) {
                lv.textContent = (fixed > 0 ? '' : 'Auto ') + Math.round(u * 100) + '%';
                lv.className = 'lv' + (fixed > 0 ? '' : ' auto');
            }
            if (redraw && changed && window.ngRebuildCharts) window.ngRebuildCharts();
        }
        function setFixed(v) {
            fixed = v;
            try { if (v > 0) localStorage.setItem('ng.scale', String(v)); else localStorage.removeItem('ng.scale'); } catch (e) { }
            apply(true);
        }
        function step(dir) {
            var u = calcU(), i, next = u;
            if (dir > 0) { for (i = 0; i < LEVELS.length; i++) if (LEVELS[i] > u + 0.01) { next = LEVELS[i]; break; } }
            else { for (i = LEVELS.length - 1; i >= 0; i--) if (LEVELS[i] < u - 0.01) { next = LEVELS[i]; break; } }
            setFixed(next);
        }
        window.ngZoom = { up: function () { step(1); }, down: function () { step(-1); }, auto: function () { setFixed(0); } };
        apply(false);
        document.addEventListener('DOMContentLoaded', function () { apply(false); });
        window.addEventListener('resize', function () { if (!(fixed > 0)) apply(true); });
        // คีย์ลัด: Ctrl ไม่ต้องกด  + / - / 0
        document.addEventListener('keydown', function (e) {
            if (e.ctrlKey || e.metaKey || e.altKey) return;
            var t = e.target && e.target.tagName;
            if (t === 'INPUT' || t === 'SELECT' || t === 'TEXTAREA') return;
            if (e.key === '+' || e.key === '=') { step(1); e.preventDefault(); }
            else if (e.key === '-' || e.key === '_') { step(-1); e.preventDefault(); }
            else if (e.key === '0') { setFixed(0); e.preventDefault(); }
        });
    })();
</script>
</asp:Content>


<asp:Content ID="cHeaderRight" ContentPlaceHolderID="HeaderRight" runat="server">
    <!-- นับถอยหลังรีเฟรช : คลิกเพื่อรีเฟรชทันที -->
    <div class="refresh" id="rf" title="คลิกเพื่อรีเฟรชทันที">
            <div class="ring" id="rfRing"><b id="rfSec">60</b></div>
            <div>
                <small>REALTIME</small>
                <em id="rfTxt">รีเฟรชทุก 60 วินาที</em>
            </div>
        </div>
</asp:Content>


<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="grid">
    <!-- =====================================================
         FILTERS
         ===================================================== -->

    <div class="filters">

        <!-- DATE : [CHANGED] ใช้ flatpickr แสดง dd/mm/yyyy
             ค่าที่ส่งไป C# ยังเป็น yyyy-MM-dd เหมือนเดิม -->
        <div>
            <label>Created Date:</label>
            <div class="dates">
                <asp:TextBox ID="txtFrom" runat="server" autocomplete="off"
                    OnTextChanged="btnSearch_Click" />
                <asp:TextBox ID="txtTo" runat="server" autocomplete="off"
                    OnTextChanged="btnSearch_Click" />
            </div>
        </div>

        <!-- PROCESS -->
        <div>
            <label>Process:</label>
            <asp:DropDownList ID="ddlProcess" runat="server"
                AutoPostBack="true"
                OnSelectedIndexChanged="ddlProcess_SelectedIndexChanged">
                <%-- [CHANGED] รายการโหลดจาก UNIVERSAL.dbo.CMSMW (MW002) ใน C# --%>
            </asp:DropDownList>
        </div>

        <!-- NG REASON -->
        <div>
            <label>NG Reason:</label>
            <asp:DropDownList ID="ddlReason" runat="server"
                AutoPostBack="true"
                OnSelectedIndexChanged="Filter_Changed">
                <asp:ListItem Text="All" Value="All" />
            </asp:DropDownList>
        </div>

        <!-- BALL MODEL -->
        <div>
            <label>Ball Model:</label>
            <asp:DropDownList ID="ddlBall" runat="server"
                AutoPostBack="true"
                OnSelectedIndexChanged="Filter_Changed">
                <asp:ListItem Text="All" Value="All" />
            </asp:DropDownList>
        </div>

        <!-- MACHINE -->
        <div>
            <label>Machine:</label>
            <asp:DropDownList ID="ddlMachine" runat="server"
                AutoPostBack="true"
                OnSelectedIndexChanged="ddlMachine_SelectedIndexChanged" />
        </div>

        <!-- SEARCH -->
        <div>
            <label>&nbsp;</label>
            <asp:Button ID="btnSearch" runat="server" Text="Search"
                CssClass="filter-button" OnClick="btnSearch_Click" />
        </div>

        <!-- ปรับขนาดหน้าจอ (จำค่าแยกแต่ละเครื่อง / คีย์ลัด + - 0) -->
        <div>
            <label>Screen Size:</label>
            <div class="zm" title="ปรับขนาดหน้าจอ · คีย์ลัด + / - / 0 (อัตโนมัติ)">
                <button type="button" onclick="ngZoom.down()" title="เล็กลง (-)">A−</button>
                <button type="button" class="lv auto" id="zmLv" onclick="ngZoom.auto()" title="กลับเป็นอัตโนมัติตามขนาดจอ (0)">Auto</button>
                <button type="button" onclick="ngZoom.up()" title="ใหญ่ขึ้น (+)">A+</button>
            </div>
        </div>

    </div>


    <!-- =====================================================
         KPI
         ===================================================== -->

    <div class="kpis">

        <div class="kpi">
            <b><asp:Label ID="lblInsp" runat="server" Text="0" /></b>
            <span>Total Inspections</span>
        </div>

        <div class="kpi">
            <b><asp:Label ID="lblCount" runat="server" Text="0.00" /></b>
            <span>Total Count</span>
        </div>

        <div class="kpi">
            <b><asp:Label ID="lblDefect" runat="server" Text="0.00" /></b>
            <span>Total Defect</span>
        </div>

        <div class="kpi">
            <b><asp:Label ID="lblDefPct" runat="server" Text="0.00%" /></b>
            <span>Defect (%)</span>
        </div>

        <div class="kpi">
            <b><asp:Label ID="lblYield" runat="server" Text="100.00%" /></b>
            <span>Yield (%)</span>
        </div>

    </div>


    <!-- =====================================================
         STACKED BAR
         ===================================================== -->

    <div class="panel hour">
        <h2>สรุปผล NG</h2>
        <div class="cv"><canvas id="cHour"></canvas></div>
    </div>


    <!-- =====================================================
         MATRIX
         ===================================================== -->

    <div class="panel matrix">

        <!-- [CHANGED] แต่ละแท็บบอกว่าจะใช้ field ไหนเป็นคอลัมน์ -->
        <div class="tabs" id="tabs">
            <button type="button" class="on" data-col="Machine">Machine</button>
            <button type="button" data-col="Ball_Model">Ball Model</button>
            <button type="button" data-col="Week_Group">By Week</button>
            <button type="button" data-col="Month_Group">By Month</button>
        </div>

        <div class="mx-wrap">
            <table class="mx">
                <thead id="matrixHead"></thead>
                <tbody id="matrixBody"></tbody>
            </table>
        </div>

        <!-- เก็บไว้ให้ C# ที่อ้างถึง lblMatrixMachine ยัง compile ได้ -->
        <asp:Label ID="lblMatrixMachine" runat="server" Visible="false" />

    </div>


    <!-- =====================================================
         NG %
         ===================================================== -->

    <div class="panel">
        <h2>NG %</h2>
        <div class="cv"><canvas id="cPct"></canvas></div>
    </div>


</div>


    <asp:Button ID="btnRefresh" runat="server" Text="Refresh"
        OnClick="Filter_Changed" style="display:none" />
</asp:Content>


<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<%-- [CHANGED] ข้อมูลกราฟ (JSON) อยู่นอก <form> จึงไม่ถูกส่งกลับตอน postback --%>
<script type="application/json" id="chartJson"><%= ChartData %></script>


<script>

    // =========================================================
    // [NEW] วันที่ dd/mm/yyyy
    // =========================================================

    // "2026-09-25" -> "25/09/2026"
    function toDMY(ymd) {
        if (!ymd) return '';
        var p = String(ymd).substr(0, 10).split('-');
        return p.length === 3 ? p[2] + '/' + p[1] + '/' + p[0] : ymd;
    }

    if (window.flatpickr) {
        var fpOpts = {
            dateFormat: 'Y-m-d',   // ค่าจริงที่ส่งให้ C# (DateTime.Parse อ่านได้)
            altInput: true,
            altFormat: 'd/m/Y',    // ที่ผู้ใช้เห็น
            allowInput: false,
            onChange: function (dates) {
                // เลือกวันที่แล้วค้นหาใหม่ทันที (แทน AutoPostBack เดิม)
                if (dates.length) {
                    document.getElementById('<%= btnSearch.ClientID %>').click();
                }
            }
        };
        flatpickr('#<%= txtFrom.ClientID %>', fpOpts);
        flatpickr('#<%= txtTo.ClientID %>', fpOpts);
    }


    // =========================================================
    // [NEW] KPI : >= 1,000 แสดงเป็น K (>= 1,000,000 เป็น M)
    //       และย่อฟอนต์ไม่ให้ล้นการ์ด
    // =========================================================

    function shortNum(n) {
        var a = Math.abs(n);
        // ปัดเศษแบบ Math.round กัน 5.305 -> 5.30 (ควรเป็น 5.31)
        if (a >= 1000000) return { v: (Math.round(n / 10000) / 100).toFixed(2), u: 'M' };
        if (a >= 1000)    return { v: (Math.round(n / 10) / 100).toFixed(2), u: 'K' };
        return null;
    }

    function formatKpiLabel(id) {
        var el = document.getElementById(id);
        if (!el) return;

        var raw = el.textContent.replace(/,/g, '').trim();
        var n = Number(raw);
        if (raw === '' || isNaN(n)) return;

        var s = shortNum(n);
        var b = el.parentElement;

        if (s) {
            el.innerHTML = s.v + '<small class="unit">' + s.u + '</small>';
            el.title = n.toLocaleString('en-US');   // เอาเมาส์ชี้ดูเลขเต็ม
            b.classList.add('is-k');
        } else {
            var dec = raw.indexOf('.') >= 0 ? raw.split('.')[1].length : 0;
            el.textContent = n.toLocaleString('en-US', {
                minimumFractionDigits: dec,
                maximumFractionDigits: dec
            });
            b.classList.remove('is-k');
        }
    }

    // หาขนาดฟอนต์ที่ "ทุกการ์ด" ใส่ได้พอดี แล้วใช้ขนาดเดียวกันทั้งหมด
    // (การ์ดที่ตัวเลขยาวสุดเป็นตัวกำหนด ตัวเลขทุกใบจึงสูงเท่ากัน)
    function fitKpis() {
        var all = document.querySelectorAll('.kpi b');
        var size = 999;

        all.forEach(function (b) {
            b.style.fontSize = '';
            var max = b.parentElement.clientWidth - 36;
            var s = parseFloat(getComputedStyle(b).fontSize);
            while (b.scrollWidth > max && s > 24) {
                s -= 2;
                b.style.fontSize = s + 'px';
            }
            if (s < size) size = s;
        });

        all.forEach(function (b) { b.style.fontSize = size + 'px'; });
    }

    formatKpiLabel('<%= lblInsp.ClientID %>');
    formatKpiLabel('<%= lblCount.ClientID %>');
    formatKpiLabel('<%= lblDefect.ClientID %>');

    fitKpis();
    window.addEventListener('resize', fitKpis);
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(fitKpis);


    // =========================================================
    // Chart Data จาก C# (ChartData)
    // =========================================================

    // [CHANGED] ฝัง JSON ลงหน้าโดยตรง ไม่ใช้ HiddenField
    //           (HiddenField ถูกส่งกลับ server ทุกครั้งที่ postback -> request ใหญ่เกิน)
    var chartData = [];
    try {
        chartData = JSON.parse(document.getElementById('chartJson').textContent || '[]');
    } catch (e) {
        console.error('ChartData parse error', e);
    }

    // Total Count (ตัวหารของ %) — อ่านจากค่าดิบฝั่ง server ไม่ใช่ค่าที่แสดงเป็น K
    var totalCount = Number('<%= lblCount.Text %>') || 0;

    // กัน VS ฟ้อง type ของ Chart
    var W = new Function('return window')();

    // ธีมกราฟ
    W.Chart.defaults.font.family = "'Sarabun', Tahoma, sans-serif";
    var U = window.NG_U || 1;   // ตัวคูณขนาดตามจอ
    W.Chart.defaults.font.size = Math.round(13 * U);
    W.Chart.defaults.plugins.legend.labels.boxWidth = Math.round(12 * U);
    W.Chart.defaults.plugins.tooltip.titleFont = { size: Math.round(13 * U) };
    W.Chart.defaults.plugins.tooltip.bodyFont = { size: Math.round(13 * U) };
    W.Chart.defaults.color = '#64748b';
    W.Chart.defaults.borderColor = '#e2e8f0';

    var hourChart = null;
    var pctChart = null;

    var chartColors = [
        '#ec4899', '#7c3aed', '#06b6d4', '#f59e0b', '#10b981',
        '#ef4444', '#3b82f6', '#84cc16', '#a855f7', '#14b8a6'
    ];

    function pctTick(value) { return value + '%'; }

    function number2(value) { return Number(Number(value || 0).toFixed(2)); }

    function esc(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;'); }


    // =========================================================
    // กราฟแท่งซ้อน : Defect ต่อชั่วโมง แยกตาม Reason
    // =========================================================

    function buildHourChart() {

        var canvas = document.getElementById('cHour');
        if (!canvas) return;
        if (hourChart) hourChart.destroy();

        // เลือกหลายวัน -> ใส่วันที่นำหน้า ไม่ให้ชั่วโมงเดียวกันรวมกัน
        var multiDay = chartData.length > 0 &&
            chartData[0].CheckOut_Date !== chartData[chartData.length - 1].CheckOut_Date;

        var hourMap = {};
        var reasonSet = {};

        chartData.forEach(function (row) {

            if (!row.CheckOut_Hour) return;

            // [CHANGED] key = "yyyy-MM-dd|10 AM" เพื่อแปลงเป็น dd/mm/yyyy ตอนแสดง
            var hour = multiDay
                ? row.CheckOut_Date + '|' + row.CheckOut_Hour
                : row.CheckOut_Hour;

            var reason = row.Defect_Reason || 'No Defect';
            var qty = Number(row.Defect_QTY || 0);

            if (!hourMap[hour]) hourMap[hour] = {};
            hourMap[hour][reason] = (hourMap[hour][reason] || 0) + qty;

            reasonSet[reason] = true;
        });

        // SQL เรียงตามเวลาอยู่แล้ว ลำดับ key จึงเรียงตามเวลา
        var keys = Object.keys(hourMap);
        var reasons = Object.keys(reasonSet);

        // [CHANGED] label 2 บรรทัด : 25/09/2026 / 10 AM
        var labels = keys.map(function (k) {
            var p = k.split('|');
            return p.length > 1 ? [toDMY(p[0]), p[1]] : p[0];
        });

        var datasets = reasons.map(function (reason, index) {
            return {
                label: reason,
                backgroundColor: chartColors[index % chartColors.length],
                borderRadius: 6,
                maxBarThickness: 90,
                data: keys.map(function (k) {
                    return number2(hourMap[k][reason]);
                })
            };
        });

        hourChart = new W.Chart(canvas, {
            type: 'bar',
            data: { labels: labels, datasets: datasets },
            options: {
                maintainAspectRatio: false,
                plugins: {
                    legend: { position: 'top', align: 'start', labels: { usePointStyle: true, boxWidth: 8 } },
                    tooltip: {
                        callbacks: {
                            title: function (items) {
                                var l = items[0].label;
                                return Array.isArray(l) ? l.join(' ') : l;
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        stacked: true,
                        title: { display: true, text: 'CheckOut_Hour' },
                        grid: { display: false },
                        ticks: { maxRotation: 0, autoSkip: true }
                    },
                    y: {
                        stacked: true,
                        beginAtZero: true,
                        title: { display: true, text: 'Total Defect' }
                    }
                }
            }
        });
    }


    // =========================================================
    // กราฟ NG % : Defect ของแต่ละ Reason / Total Count
    // =========================================================

    function buildPctChart() {

        var canvas = document.getElementById('cPct');
        if (!canvas) return;
        if (pctChart) pctChart.destroy();

        var defectMap = {};

        chartData.forEach(function (row) {
            if (!row.Defect_Reason) return;
            defectMap[row.Defect_Reason] =
                (defectMap[row.Defect_Reason] || 0) + Number(row.Defect_QTY || 0);
        });

        var labels = Object.keys(defectMap);

        var values = labels.map(function (reason) {
            return totalCount === 0 ? 0 : number2(defectMap[reason] * 100 / totalCount);
        });

        pctChart = new W.Chart(canvas, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{ backgroundColor: '#ec4899', borderRadius: 6, maxBarThickness: 36, data: values }]
            },
            options: {
                indexAxis: 'y',
                maintainAspectRatio: false,
                plugins: { legend: { display: false } },
                scales: {
                    x: {
                        min: 0,
                        title: { display: true, text: 'Defect (%)' },
                        ticks: { callback: pctTick }
                    },
                    y: { title: { display: true, text: 'Defect_Reason' } }
                }
            }
        });
    }


    // =========================================================
    // Matrix
    // =========================================================

    // [CHANGED] แถว = Defect_Reason, คอลัมน์ = field ตามแท็บที่เลือก
    //   Machine / Ball_Model / Week_Group / Month_Group
    //   ค่าในช่อง = Defect_QTY * 100 / Total Count (ตัวหารเดียวกับการ์ด KPI)

    var matrixCol = 'Machine';

    // แปลงชื่อคอลัมน์ให้อ่านง่าย + วันที่เป็น dd/mm/yyyy
    function colLabel(field, key) {
        if (key === '(Blank)') return key;
        if (field === 'Week_Group') {
            // "WK 2026 09/21" -> "WK 21/09/2026"
            var m = /(\d{4}) (\d{2})\/(\d{2})/.exec(key);
            return m ? 'WK ' + m[3] + '/' + m[2] + '/' + m[1] : key;
        }
        if (field === 'Month_Group') {
            // "2026-09" -> "09/2026"
            var p = key.split('-');
            return p.length === 2 ? p[1] + '/' + p[0] : key;
        }
        return key;
    }

    function buildMatrix() {

        var head = document.getElementById('matrixHead');
        var body = document.getElementById('matrixBody');
        if (!head || !body) return;

        var field = matrixCol;
        var cell = {};        // cell[reason][col]
        var rowTot = {};
        var colTot = {};
        var colSet = {};
        var totalDefect = 0;

        chartData.forEach(function (row) {
            if (!row.Defect_Reason) return;

            var reason = row.Defect_Reason;
            var col = (row[field] == null || row[field] === '') ? '(Blank)' : String(row[field]).trim();
            var qty = Number(row.Defect_QTY || 0);

            if (!cell[reason]) cell[reason] = {};
            cell[reason][col] = (cell[reason][col] || 0) + qty;
            rowTot[reason] = (rowTot[reason] || 0) + qty;
            colTot[col] = (colTot[col] || 0) + qty;
            colSet[col] = true;
            totalDefect += qty;
        });

        // คอลัมน์ : Week/Month เรียงตามเวลา, อื่น ๆ เรียงตามชื่อ
        var cols = Object.keys(colSet).sort();
        var reasons = Object.keys(cell).sort();

        function pct(v) {
            return (totalCount === 0 ? 0 : v * 100 / totalCount).toFixed(2) + '%';
        }

        // หัวตาราง
        var h = '<tr><th>Defect_Reason</th>';
        cols.forEach(function (c) { h += '<th>' + esc(colLabel(field, c)) + '</th>'; });
        h += '<th>Total</th></tr>';
        head.innerHTML = h;

        // ข้อมูล (ช่องที่ไม่มีข้อมูลเว้นว่าง เหมือน Power BI)
        var html = '';

        reasons.forEach(function (reason) {
            html += '<tr><td>' + esc(reason) + '</td>';
            cols.forEach(function (c) {
                var v = cell[reason][c];
                html += v === undefined ? '<td class="empty"></td>' : '<td>' + pct(v) + '</td>';
            });
            html += '<td class="tot">' + pct(rowTot[reason]) + '</td></tr>';
        });

        if (!reasons.length) {
            html += '<tr><td colspan="' + (cols.length + 2) + '" style="text-align:center;color:#94a3b8">ไม่มีข้อมูล</td></tr>';
        }

        // แถว Total
        html += '<tr class="tot"><td>Total</td>';
        cols.forEach(function (c) { html += '<td>' + pct(colTot[c]) + '</td>'; });
        html += '<td>' + pct(totalDefect) + '</td></tr>';

        body.innerHTML = html;
    }


    // =========================================================
    // Tabs : เปลี่ยนคอลัมน์ของ Matrix
    // =========================================================

    var tabBtns = document.querySelectorAll('#tabs button');

    function selectTab(btn) {
        tabBtns.forEach(function (x) { x.classList.remove('on'); });
        btn.classList.add('on');
        matrixCol = btn.getAttribute('data-col');
        try { sessionStorage.setItem('ngMatrixTab', matrixCol); } catch (e) { }
        buildMatrix();
    }

    tabBtns.forEach(function (b) {
        b.addEventListener('click', function () { selectTab(b); });
    });

    // จำแท็บที่เลือกไว้ หลัง Auto Refresh / เปลี่ยน filter จะไม่เด้งกลับไป Machine
    (function () {
        var saved = null;
        try { saved = sessionStorage.getItem('ngMatrixTab'); } catch (e) { }
        tabBtns.forEach(function (b) {
            if (b.getAttribute('data-col') === saved) {
                tabBtns.forEach(function (x) { x.classList.remove('on'); });
                b.classList.add('on');
                matrixCol = saved;
            }
        });
    })();


    // =========================================================
    // Start
    // =========================================================

    buildHourChart();
    buildPctChart();
    buildMatrix();

    // จอเปลี่ยนขนาด -> วาดกราฟใหม่ด้วยตัวอักษรขนาดใหม่
    window.ngRebuildCharts = function () {
        U = window.NG_U || 1;
        W.Chart.defaults.font.size = Math.round(13 * U);
        W.Chart.defaults.plugins.legend.labels.boxWidth = Math.round(12 * U);
        buildHourChart();
        buildPctChart();
        if (typeof fitKpis === 'function') fitKpis();
    };


    // =========================================================
    // Auto Refresh ทุก 60 วินาที (นับถอยหลังมุมบนขวา)
    // =========================================================

    var REFRESH_SEC = 60;
    var secLeft = REFRESH_SEC;
    var loadedAt = new Date().toLocaleTimeString('th-TH');

    function refreshNow() {
        document.getElementById('<%= btnRefresh.ClientID %>').click();
    }

    function showCountdown() {
        document.getElementById('rfSec').textContent = secLeft;
        document.getElementById('rfTxt').textContent =
            'อัปเดต ' + loadedAt;
        document.getElementById('rfRing').style.setProperty(
            '--p', (secLeft / REFRESH_SEC * 360) + 'deg');
    }

    document.getElementById('rf').addEventListener('click', refreshNow);

    setInterval(function () {
        secLeft--;
        if (secLeft <= 0) {
            secLeft = 0;
            showCountdown();
            refreshNow();
            return;
        }
        showCountdown();
    }, 1000);

    showCountdown();

</script>
</asp:Content>
