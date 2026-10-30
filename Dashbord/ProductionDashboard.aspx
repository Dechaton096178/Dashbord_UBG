<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="ProductionDashboard.aspx.cs" Inherits="Dashbord.ProductionDashboard" Title="Production Dashboard" %>

<%-- =====================================================================
     Production Dashboard (แทนหน้า Power BI)
     - ซ้าย : Process ที่เลือก + ยอดรวม / ตารางยอดผลิตวันนี้ทุก Process (กดแถวเพื่อเลือก)
     - ขวาบน : ยอดผลิตตามเครื่องจักร (กดแท่งเพื่อกรอง NG เฉพาะเครื่อง)
     - ขวาล่าง : ยอด NG รายชั่วโมง แยกตามสาเหตุ
     - ข้อมูล : ProductionDashboard.aspx?format=json&day=yyyy-MM-dd&op=03 (EMES_UNIVERSAL)
     - ลิงก์ตรง : ?op=03 &day=2026-10-09 &tv=1 (โหมดจอทีวี) &rotate=20 (วนทุก Process ทุก 20 วิ)
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<style>
    /* ===== ธีมสว่าง ===== */
    .pd {
        --u:1;   /* ตัวคูณขนาด: JS ตั้งตามขนาดจอ (จอทีวี 4K ตัวอักษรจะใหญ่ตาม) */
        --bg:#eef2f8; --bg2:#e6ecf5; --card:#ffffff; --card-bd:#e3e8f0; --ink:#0f172a; --ink2:#334155; --mute:#64748b; --line:#e5e9f0; --grid:#e9eef5;
        --row:#f7f9fc; --sel:#eef2ff; --sel-bd:#6366f1; --accent:#4f46e5; --accent2:#0ea5e9;
        --bar:#2a78d6; --bar-top:#4b93e8; --bar-dim:#cfdcf0; --dbar:rgba(42,120,214,.45); --dbar-sel:#4f46e5;
        --s1:#2a78d6; --s2:#eb6834; --s3:#1baf7a; --s4:#eda100; --s5:#e87ba4; --s6:#008300; --s7:#4a3aa7; --s-other:#94a3b8;
        --ng:#dc2626; --chip:rgba(99,102,241,.06); --card-solid:#f9faff;
        --shadow:0 calc(1px*var(--u)) calc(2px*var(--u)) rgba(15,23,42,.04), 0 calc(6px*var(--u)) calc(20px*var(--u)) rgba(15,23,42,.06);
        --hero-bg:linear-gradient(135deg, #ffffff 0%, #f5f7ff 100%); --card-bd:#e2e6f5;
        --hero-num:#0f172a; --glow:none;
        padding:calc(14px*var(--u)); background:linear-gradient(180deg, var(--bg) 0%, var(--bg2) 100%); color:var(--ink);
        font-variant-numeric:tabular-nums;
    }
    /* ===== ธีมมืด (ห้องควบคุม) ===== */
    .pd.dark {
        --bg:#0a1122; --bg2:#050913; --card:rgba(17,26,46,.92); --card-bd:#1d2a47; --ink:#f1f5f9; --ink2:#cbd5e1; --mute:#8193b2; --line:#1d2a47; --grid:#18233c;
        --row:rgba(255,255,255,.025); --sel:rgba(99,102,241,.18); --sel-bd:#818cf8; --accent:#a5b4fc; --accent2:#38bdf8;
        --bar:#3987e5; --bar-top:#67a8f5; --bar-dim:#1c3256; --dbar:rgba(57,135,229,.55); --dbar-sel:#818cf8;
        --s1:#3987e5; --s2:#d95926; --s3:#199e70; --s4:#c98500; --s5:#d55181; --s6:#008300; --s7:#9085e9; --s-other:#64748b;
        --ng:#f87171; --chip:rgba(129,140,248,.08); --card-solid:#121b33;
        --shadow:0 calc(1px*var(--u)) 0 rgba(255,255,255,.04) inset, 0 calc(10px*var(--u)) calc(30px*var(--u)) rgba(0,0,0,.45);
        --hero-bg:linear-gradient(135deg, rgba(30,41,82,.95) 0%, rgba(14,22,42,.95) 60%);
        --hero-num:#ffffff; --glow:0 0 calc(28px*var(--u)) rgba(56,189,248,.35);
        background:radial-gradient(calc(1200px*var(--u)) calc(600px*var(--u)) at 20% -10%, #14203d 0%, transparent 60%), linear-gradient(180deg, var(--bg) 0%, var(--bg2) 100%);
    }

    /* ---------- แถบบน ---------- */
    .pd-bar { display:flex; align-items:center; gap:calc(10px*var(--u)); flex-wrap:wrap; margin-bottom:calc(12px*var(--u)); }
    .pd-bar h2 { margin:0; font-size:calc(20px*var(--u)); font-weight:800; letter-spacing:-.01em; display:flex; align-items:center; gap:calc(9px*var(--u)); }
    .pd-bar h2::before { content:""; width:calc(10px*var(--u)); height:calc(10px*var(--u)); border-radius:50%; background:#10b981; box-shadow:0 0 0 calc(4px*var(--u)) rgba(16,185,129,.18); animation:pdPulse 2s infinite; }
    @keyframes pdPulse { 0%,100% { box-shadow:0 0 0 calc(3px*var(--u)) rgba(16,185,129,.25); } 50% { box-shadow:0 0 0 calc(7px*var(--u)) rgba(16,185,129,.05); } }
    .pd-bar .sp { flex:1; }
    .pd-btn, .pd-date {
        font:inherit; font-size:calc(13px*var(--u)); font-weight:700; color:var(--ink2); background:var(--card);
        border:calc(1px*var(--u)) solid var(--card-bd); border-radius:calc(9px*var(--u)); padding:calc(6px*var(--u)) calc(11px*var(--u)); cursor:pointer; line-height:1.2;
    }
    .pd-date { cursor:text; padding:calc(5px*var(--u)) calc(9px*var(--u)); color-scheme:light; }
    .pd.dark .pd-date { color-scheme:dark; }
    .pd-btn:hover { border-color:var(--sel-bd); color:var(--accent); }
    .pd-btn.on { background:var(--sel); border-color:var(--sel-bd); color:var(--accent); }
    .pd-zoom { display:inline-flex; gap:calc(4px*var(--u)); }
    .pd-zoom #pdZoomLv { min-width:calc(78px*var(--u)); }
    .pd-msg { font-size:calc(12.5px*var(--u)); color:var(--mute); }
    .pd-msg.err { color:#ef4444; font-weight:700; }

    /* ---------- เลย์เอาต์ ---------- */
    .pd-grid {
        display:grid; gap:calc(12px*var(--u));
        grid-template-columns:minmax(calc(360px*var(--u)), 5fr) 7fr;
        grid-template-rows:minmax(0, 1fr) minmax(0, 1fr);
        height:calc(100vh - calc(150px*var(--u))); min-height:calc(620px*var(--u));
    }
    .pd-left { grid-row:1 / span 2; display:flex; flex-direction:column; gap:calc(12px*var(--u)); min-height:0; }
    .card {
        background:var(--hero-bg); border:calc(1px*var(--u)) solid var(--card-bd); border-radius:calc(16px*var(--u)); box-shadow:var(--shadow);
        padding:calc(14px*var(--u)) calc(16px*var(--u)); min-height:0; display:flex; flex-direction:column; position:relative;
    }
    .card h3 { margin:0; font-size:calc(15px*var(--u)); font-weight:800; color:var(--ink); display:flex; align-items:center; gap:calc(8px*var(--u)); }
    .card h3::before { content:""; width:calc(4px*var(--u)); height:calc(16px*var(--u)); border-radius:calc(4px*var(--u)); background:linear-gradient(180deg, var(--accent2), var(--accent)); flex:none; }
    .card .sub { font-size:calc(12px*var(--u)); color:var(--mute); margin-top:calc(3px*var(--u)); padding-left:calc(12px*var(--u)); }

    /* ---------- Hero ---------- */
    .hero { background:var(--hero-bg); padding:calc(16px*var(--u)) calc(20px*var(--u)) calc(14px*var(--u)); overflow:hidden; }
    .hero::after { content:""; position:absolute; right:-60px; top:-60px; width:calc(220px*var(--u)); height:calc(220px*var(--u)); border-radius:50%;
                   background:radial-gradient(circle, rgba(99,102,241,.14), transparent 70%); pointer-events:none; }
    .hero-top { display:flex; align-items:flex-end; gap:calc(16px*var(--u)); }
    .hero .name { font-size:calc(32px*var(--u)); font-weight:800; line-height:1.05; letter-spacing:-.02em; flex:1; min-width:0; }
    .hero .name small { display:inline-block; font-size:calc(12px*var(--u)); font-weight:800; color:var(--accent); letter-spacing:.02em;
                        background:var(--sel); border:calc(1px*var(--u)) solid var(--sel-bd); border-radius:calc(99px*var(--u)); padding:calc(2px*var(--u)) calc(10px*var(--u)); margin-bottom:calc(8px*var(--u)); }
    .hero .num { text-align:right; white-space:nowrap; }
    .hero .num b { font-size:calc(58px*var(--u)); font-weight:800; letter-spacing:-.03em; line-height:1; color:var(--hero-num); text-shadow:var(--glow); }
    .hero .num span { font-size:calc(24px*var(--u)); font-weight:700; color:var(--ink2); margin-left:calc(6px*var(--u)); }
    .kpis { display:grid; grid-template-columns:repeat(4, minmax(0, 1fr)); gap:calc(8px*var(--u)); margin-top:calc(14px*var(--u)); }
    .kpi { background:var(--chip); border:calc(1px*var(--u)) solid var(--card-bd); border-radius:calc(11px*var(--u)); padding:calc(7px*var(--u)) calc(10px*var(--u)); min-width:0; }
    .kpi span { display:block; font-size:calc(11px*var(--u)); font-weight:700; color:var(--mute); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .kpi b { display:block; font-size:calc(19px*var(--u)); font-weight:800; color:var(--ink); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; margin-top:calc(1px*var(--u)); }
    .kpi b.ng { color:var(--ng); }
    .kpi b small { font-size:calc(12px*var(--u)); font-weight:700; color:var(--mute); margin-left:calc(3px*var(--u)); }

    /* ---------- ตาราง ---------- */
    .tbl { flex:1; }
    .tbl h3 { justify-content:center; font-size:calc(20px*var(--u)); margin-bottom:calc(6px*var(--u)); }
    .tbl h3::before { display:none; }
    .tbl-wrap { flex:1; min-height:0; overflow:auto; }
    .tbl table { width:100%; height:100%; border-collapse:separate; border-spacing:0; }   /* แถวยืดเต็มกรอบเมื่อจอสูง */
    .tbl th { position:sticky; top:0; background:var(--card-solid); text-align:left; font-size:calc(12px*var(--u)); font-weight:700; color:var(--mute);
              padding:calc(6px*var(--u)) calc(10px*var(--u)); border-bottom:calc(1px*var(--u)) solid var(--line); z-index:1; text-transform:uppercase; letter-spacing:.04em; }
    .pd.dark .tbl th { background:#111a2e; }
    .tbl th.r, .tbl td.r { text-align:right; }
    .tbl td { font-size:calc(19px*var(--u)); padding:calc(6px*var(--u)) calc(10px*var(--u)); color:var(--ink); white-space:nowrap; }
    .tbl td:first-child { border-radius:calc(9px*var(--u)) 0 0 calc(9px*var(--u)); color:var(--mute); font-weight:700; }
    .tbl td:last-child { border-radius:0 calc(9px*var(--u)) calc(9px*var(--u)) 0; }
    .tbl tbody tr { cursor:pointer; }
    .tbl tbody tr:nth-child(even) td { background:var(--row); }
    .tbl tbody tr:hover td { background:var(--sel); }
    .tbl tbody tr.sel td { background:var(--sel); font-weight:800; color:var(--ink); }
    .tbl tbody tr.sel td:first-child { box-shadow:inset calc(4px*var(--u)) 0 0 var(--sel-bd); color:var(--accent); }
    .tbl tbody tr.zero td { color:var(--mute); opacity:.75; }
    .tbl td.qty { position:relative; width:38%; }
    .tbl td.qty .db { position:absolute; left:calc(4px*var(--u)); bottom:calc(5px*var(--u)); height:calc(4px*var(--u)); border-radius:calc(4px*var(--u)); background:var(--dbar); }
    .tbl tbody tr.sel td.qty .db { background:var(--dbar-sel); }
    .tbl td.qty .v { position:relative; }
    .tbl tfoot td { position:sticky; bottom:0; background:var(--card-solid); font-size:calc(21px*var(--u)); font-weight:800; color:var(--ink);
                    border-top:calc(2px*var(--u)) solid var(--accent); padding-top:calc(8px*var(--u)); border-radius:0; }
    .pd.dark .tbl tfoot td { background:#111a2e; }
    .tbl tfoot td:first-child, .tbl tfoot td:last-child { border-radius:0; color:var(--ink); }

    /* ---------- กราฟ ---------- */
    .chart-head { display:flex; align-items:flex-start; gap:calc(12px*var(--u)); }
    .chart-head .t { flex:1; min-width:0; }
    .clock { background:var(--chip); border:calc(1px*var(--u)) solid var(--card-bd); border-radius:calc(12px*var(--u)); padding:calc(6px*var(--u)) calc(14px*var(--u)); text-align:left; }
    .clock b { display:block; font-size:calc(28px*var(--u)); font-weight:800; letter-spacing:.01em; line-height:1.1; }
    .clock span { font-size:calc(11.5px*var(--u)); color:var(--mute); font-weight:600; }
    .ng-total { text-align:right; white-space:nowrap; background:var(--chip); border:calc(1px*var(--u)) solid var(--card-bd); border-radius:calc(12px*var(--u)); padding:calc(5px*var(--u)) calc(14px*var(--u)); }
    .ng-total b { font-size:calc(24px*var(--u)); font-weight:800; color:var(--ng); }
    .ng-total span { font-size:calc(13px*var(--u)); color:var(--mute); margin-left:calc(4px*var(--u)); }
    .ng-total em { display:block; font-style:normal; font-size:calc(11.5px*var(--u)); font-weight:600; color:var(--mute); }
    .legend { display:flex; flex-wrap:wrap; gap:calc(5px*var(--u)) calc(14px*var(--u)); margin:calc(8px*var(--u)) 0 calc(2px*var(--u)) calc(12px*var(--u)); font-size:calc(12px*var(--u)); color:var(--ink2); }
    .legend i { display:inline-block; width:calc(10px*var(--u)); height:calc(10px*var(--u)); border-radius:calc(3px*var(--u)); margin-right:calc(5px*var(--u)); vertical-align:-1px; }
    .legend span { max-width:calc(240px*var(--u)); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
    .legend b { color:var(--mute); font-weight:700; margin-left:calc(4px*var(--u)); }
    .plot { flex:1; min-height:0; position:relative; margin-top:calc(4px*var(--u)); }
    .plot svg { position:absolute; inset:0; width:100%; height:100%; overflow:visible; }
    .plot .empty { position:absolute; inset:0; display:flex; align-items:center; justify-content:center; color:var(--mute); font-size:calc(14px*var(--u)); }
    .ax { fill:var(--mute); font-size:calc(11px*var(--u)); }
    .vl { fill:var(--ink2); font-size:calc(12px*var(--u)); font-weight:800; }
    .vl.top { fill:var(--ink); }
    .seg-l { fill:#fff; font-size:calc(11px*var(--u)); font-weight:800; pointer-events:none; }
    .gl { stroke:var(--grid); stroke-width:1; stroke-dasharray:3 4; }
    .base { stroke:var(--line); stroke-width:1.5; }
    .hit { cursor:pointer; }
    .filter-chip { display:inline-flex; align-items:center; gap:calc(6px*var(--u)); margin-left:calc(4px*var(--u)); font-size:calc(12px*var(--u)); font-weight:700; color:var(--accent);
                   background:var(--sel); border:calc(1px*var(--u)) solid var(--sel-bd); border-radius:calc(99px*var(--u)); padding:calc(1px*var(--u)) calc(4px*var(--u)) calc(1px*var(--u)) calc(9px*var(--u)); }
    .filter-chip button { border:0; background:none; color:inherit; cursor:pointer; font-size:calc(13px*var(--u)); padding:0 calc(4px*var(--u)); }

    .tip { position:fixed; z-index:50; pointer-events:none; background:#0f172a; color:#f8fafc; border:calc(1px*var(--u)) solid #1e293b; border-radius:calc(10px*var(--u)); padding:calc(8px*var(--u)) calc(11px*var(--u));
           font-size:calc(12.5px*var(--u)); line-height:1.5; box-shadow:0 calc(10px*var(--u)) calc(30px*var(--u)) rgba(0,0,0,.3); display:none; max-width:calc(300px*var(--u)); }
    .tip b { font-weight:800; }
    .tip .mu { color:#94a3b8; }

    /* ---------- จอเล็ก ---------- */
    @media (max-width: 1000px) {
        .pd-grid { grid-template-columns:1fr; grid-template-rows:auto; height:auto; }
        .pd-left { grid-row:auto; }
        .pd-grid > .card { height:calc(360px*var(--u)); }
        .hero .name { font-size:calc(24px*var(--u)); } .hero .num b { font-size:calc(40px*var(--u)); }
        .kpis { grid-template-columns:repeat(2, minmax(0, 1fr)); }
        .tbl td { font-size:calc(15px*var(--u)); }
    }

    /* ---------- โหมด TV ---------- */
    body.pd-tv .site-header { display:none !important; }
    body.pd-tv { padding:0 !important; margin:0 !important; overflow:hidden; }
    body.pd-tv form { margin:0 !important; padding:0 !important; max-width:none !important; }
    .pd.tv { padding:calc(10px*var(--u)) calc(12px*var(--u)); height:100vh; box-sizing:border-box; display:flex; flex-direction:column; }
    .pd.tv .pd-bar { margin-bottom:calc(8px*var(--u)); }
    .pd.tv .pd-bar h2 { font-size:calc(17px*var(--u)); }
    .pd.tv .pd-grid { flex:1; height:auto; min-height:0; }
    .pd.tv .pd-hide-tv { display:none; }
    .pd.tv #pdTv { opacity:.35; } .pd.tv #pdTv:hover { opacity:1; }
</style>
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="pd" id="pdRoot">
    <div class="pd-bar">
        <h2>Production Dashboard</h2>
        <button type="button" class="pd-btn" id="pdPrev" title="Previous day">◀</button>
        <input type="date" class="pd-date" id="pdDay" />
        <button type="button" class="pd-btn" id="pdNext" title="Next day">▶</button>
        <button type="button" class="pd-btn" id="pdToday">Today</button>
        <span class="pd-msg" id="pdMsg">Loading...</span>
        <span class="sp"></span>
        <span class="pd-zoom" title="Zoom · shortcuts + / - / 0 (auto)">
            <button type="button" class="pd-btn" id="pdZoomDn" title="Smaller (-)">A−</button>
            <button type="button" class="pd-btn" id="pdZoomLv" title="Back to auto size for this screen (0)">Auto</button>
            <button type="button" class="pd-btn" id="pdZoomUp" title="Larger (+)">A+</button>
        </span>
        <button type="button" class="pd-btn" id="pdRotate" title="Rotate through every process with output, every 20 s (direct link ?rotate=20)">⟳ Rotate</button>
        <button type="button" class="pd-btn" id="pdTheme" title="Toggle light / dark theme">☾</button>
        <button type="button" class="pd-btn" id="pdTv" title="TV mode: hide menu + full screen (Esc to exit) · direct link ?tv=1">📺 TV</button>
    </div>

    <div class="pd-grid">
        <div class="pd-left">
            <div class="card hero">
                <div class="hero-top">
                    <div class="name"><small id="hCode">Process</small><br /><span id="hName">–</span></div>
                    <div class="num"><b id="hNum">–</b><span>pcs</span></div>
                </div>
                <div class="kpis">
                    <div class="kpi"><span>NG Today</span><b class="ng" id="kNg">–</b></div>
                    <div class="kpi"><span>% NG</span><b id="kNgp">–</b></div>
                    <div class="kpi"><span>Active Machines</span><b id="kMc">–</b></div>
                    <div class="kpi"><span>Top Machine</span><b id="kTop" style="font-size:calc(15px*var(--u));line-height:calc(22px*var(--u))">–</b></div>
                </div>
            </div>
            <div class="card tbl">
                <h3>Today's Production</h3>
                <div class="tbl-wrap">
                    <table>
                        <thead><tr><th>Equipment</th><th>Process Name</th><th>Type</th><th class="r">Completed</th></tr></thead>
                        <tbody id="tBody"></tbody>
                        <tfoot><tr><td colspan="3">Total</td><td class="r" id="tTotal">–</td></tr></tfoot>
                    </table>
                </div>
            </div>
        </div>

        <div class="card">
            <div class="chart-head">
                <div class="t"><h3>Production by Machine</h3><div class="sub" id="mcSub">&nbsp;</div></div>
                <div class="clock"><b id="clk">--:--:--</b><span>Last Update Time</span></div>
            </div>
            <div class="plot" id="mcPlot"></div>
        </div>

        <div class="card">
            <div class="chart-head">
                <div class="t"><h3>NG <span id="ngFilter"></span></h3><div class="sub">By reason · per hour</div></div>
                <div class="ng-total"><b id="ngTotal">–</b><span>pcs</span><em id="ngPct">&nbsp;</em></div>
            </div>
            <div class="legend" id="ngLegend"></div>
            <div class="plot" id="ngPlot"></div>
        </div>
    </div>
    <div class="tip" id="tip"></div>
</div>

<script>
// @ts-nocheck  (JavaScript ธรรมดา: ปิดการตรวจแบบ TypeScript ของ Visual Studio ซึ่งไม่ใช่ error ตอน Build)
(function () {
    var REFRESH_MS = 60000;
    var root = document.getElementById('pdRoot');
    var $ = function (id) { return document.getElementById(id); };
    var qs = new URLSearchParams(location.search);
    function ls(k, v) { try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) { return null; } }

    // ---------- state ----------
    var st = {
        day: qs.get('day') || '',
        op: qs.get('op') || ls('pd.op') || '03',
        eq: '',
        data: null,
        rotate: parseInt(qs.get('rotate') || ls('pd.rotate') || '0', 10) || 0
    };
    function shiftToday() { var d = new Date(Date.now() - 8 * 3600e3); return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
    function pad(n) { return (n < 10 ? '0' : '') + n; }
    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function fmt(n) { return Math.round(n || 0).toLocaleString('en-US'); }
    function fmtK(n) {
        n = n || 0; var a = Math.abs(n);
        if (a >= 1e6) return (n / 1e6).toFixed(a >= 1e7 ? 0 : 1).replace(/\.0$/, '') + 'M';
        if (a >= 1e3) return (n / 1e3).toFixed(a >= 1e5 ? 0 : 1).replace(/\.0$/, '') + 'K';
        return String(Math.round(n));
    }
    function hourLabel(h) { var ap = h < 12 ? 'AM' : 'PM'; var x = h % 12; return (x === 0 ? 12 : x) + ' ' + ap; }
    function shiftOrder(h) { return (h - 8 + 24) % 24; }
    if (!st.day) st.day = shiftToday();
    $('pdDay').value = st.day;

    // ---------- theme ----------
    var dark = ls('pd.dark') === '1' || qs.get('dark') === '1';
    function applyTheme() { root.classList.toggle('dark', dark); $('pdTheme').textContent = dark ? '☀' : '☾'; }
    $('pdTheme').onclick = function () { dark = !dark; ls('pd.dark', dark ? '1' : '0'); applyTheme(); render(); };
    applyTheme();

    // ---------- TV ----------
    var tvOn = qs.get('tv') === '1' || (qs.get('tv') !== '0' && ls('pd.tv') === '1');
    function applyTv() {
        document.body.classList.toggle('pd-tv', tvOn);
        root.classList.toggle('tv', tvOn);
        $('pdTv').classList.toggle('on', tvOn);
        setTimeout(render, 50);
    }
    $('pdTv').onclick = function () {
        tvOn = !tvOn; ls('pd.tv', tvOn ? '1' : '0'); applyTv();
        try {
            if (tvOn && document.documentElement.requestFullscreen && !document.fullscreenElement) document.documentElement.requestFullscreen();
            if (!tvOn && document.fullscreenElement) document.exitFullscreen();
        } catch (e) { }
    };
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape' && tvOn && !document.fullscreenElement) { tvOn = false; ls('pd.tv', '0'); applyTv(); }
    });
    applyTv();

    // ---------- date ----------
    function setDay(d) { st.day = d; st.follow = d === shiftToday(); $('pdDay').value = d; st.eq = ''; syncUrl(); load(); }
    st.follow = st.day === shiftToday();   // กำลังดู "วันนี้" -> ข้ามวันผลิต (08:00) แล้วเปลี่ยนวันให้เอง
    function addDays(d, n) { var x = new Date(d + 'T12:00:00'); x.setDate(x.getDate() + n); return x.getFullYear() + '-' + pad(x.getMonth() + 1) + '-' + pad(x.getDate()); }
    $('pdDay').onchange = function () { if (this.value) setDay(this.value); };
    $('pdPrev').onclick = function () { setDay(addDays(st.day, -1)); };
    $('pdNext').onclick = function () { setDay(addDays(st.day, 1)); };
    $('pdToday').onclick = function () { setDay(shiftToday()); };

    function syncUrl() {
        var p = new URLSearchParams(location.search);
        p.set('op', st.op);
        if (st.day !== shiftToday()) p.set('day', st.day); else p.delete('day');
        try { history.replaceState(null, '', location.pathname + '?' + p.toString()); } catch (e) { }
    }

    // ---------- rotate ----------
    var rotTimer = null;
    function applyRotate() {
        $('pdRotate').classList.toggle('on', st.rotate > 0);
        $('pdRotate').textContent = st.rotate > 0 ? '⟳ Every ' + st.rotate + ' s' : '⟳ Rotate';
        clearInterval(rotTimer);
        if (st.rotate > 0) rotTimer = setInterval(function () {
            if (!st.data) return;
            var list = st.data.processes.filter(function (p) { return p.num > 0; });
            if (!list.length) return;
            var i = list.findIndex(function (p) { return p.op === st.op; });
            selectOp(list[(i + 1) % list.length].op, true);
        }, st.rotate * 1000);
    }
    $('pdRotate').onclick = function () { st.rotate = st.rotate > 0 ? 0 : 20; ls('pd.rotate', String(st.rotate)); applyRotate(); };
    applyRotate();

    // ---------- load ----------
    var loading = false, pending = false;
    function load() {
        if (loading) { pending = true; return; }
        loading = true;
        var url = 'ProductionDashboard.aspx?format=json&day=' + encodeURIComponent(st.day) + '&op=' + encodeURIComponent(st.op) +
                  (st.eq ? '&eq=' + encodeURIComponent(st.eq) : '') + '&_=' + Date.now();
        fetch(url, { cache: 'no-store' }).then(function (r) { return r.json(); }).then(function (d) {
            if (d.error) throw new Error(d.error);
            st.data = d;
            $('pdMsg').className = 'pd-msg';
            $('pdMsg').textContent = 'Production day ' + d.from.slice(5).replace('-', '/') + ' → ' + d.to.slice(5).replace('-', '/') + ' · refreshes every 1 min';
            render();
        }).catch(function (e) {
            $('pdMsg').className = 'pd-msg err';
            $('pdMsg').textContent = 'Failed to load data: ' + e.message;
        }).then(function () {
            loading = false;
            if (pending) { pending = false; load(); }
        });
    }
    function selectOp(op, keepRotate) {
        if (op === st.op) return;
        st.op = op; st.eq = ''; ls('pd.op', op); syncUrl();
        if (!keepRotate && st.rotate > 0) { st.rotate = 0; ls('pd.rotate', '0'); applyRotate(); }
        render(true); load();
    }

    // ---------- tooltip ----------
    var tip = $('tip');
    function showTip(html, ev) {
        tip.innerHTML = html; tip.style.display = 'block';
        var w = tip.offsetWidth, h = tip.offsetHeight, x = ev.clientX + 14, y = ev.clientY + 14;
        if (x + w > innerWidth - 8) x = ev.clientX - w - 14;
        if (y + h > innerHeight - 8) y = ev.clientY - h - 14;
        tip.style.left = x + 'px'; tip.style.top = y + 'px';
    }
    function hideTip() { tip.style.display = 'none'; }

    // ---------- ขยายตามขนาดจอ (ออกแบบที่ 1600x900, จอ 4K = x2.4) ----------
    //   ?scale=1.5 ในลิงก์ > ระดับที่กดปุ่ม A− / A+ ไว้ (จำแยกแต่ละจอ) > อัตโนมัติ
    var U = 1, LEVELS = [0.75, 0.9, 1, 1.15, 1.3, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3, 3.5];
    var fixedU = (function () {
        var v = parseFloat(qs.get('scale') || ls('pd.scale') || '0');
        return v > 0 ? Math.max(0.5, Math.min(4, v)) : 0;
    })();
    function applyScale() {
        U = fixedU > 0 ? fixedU : Math.max(1, Math.min(3, Math.min(innerWidth / 1600, innerHeight / 900)));
        root.style.setProperty('--u', U.toFixed(3));
        var lv = $('pdZoomLv');
        lv.textContent = (fixedU > 0 ? '' : 'Auto ') + Math.round(U * 100) + '%';
        lv.classList.toggle('on', !(fixedU > 0));
    }
    function setZoom(v) { fixedU = v; ls('pd.scale', v > 0 ? String(v) : ''); applyScale(); render(); }
    function stepZoom(dir) {
        var i, next = U;
        if (dir > 0) { for (i = 0; i < LEVELS.length; i++) if (LEVELS[i] > U + 0.01) { next = LEVELS[i]; break; } }
        else { for (i = LEVELS.length - 1; i >= 0; i--) if (LEVELS[i] < U - 0.01) { next = LEVELS[i]; break; } }
        setZoom(next);
    }
    $('pdZoomDn').onclick = function () { stepZoom(-1); };
    $('pdZoomUp').onclick = function () { stepZoom(1); };
    $('pdZoomLv').onclick = function () { setZoom(0); };
    document.addEventListener('keydown', function (e) {
        if (e.ctrlKey || e.metaKey || e.altKey) return;
        var t = e.target && e.target.tagName;
        if (t === 'INPUT' || t === 'SELECT' || t === 'TEXTAREA') return;
        if (e.key === '+' || e.key === '=') { stepZoom(1); e.preventDefault(); }
        else if (e.key === '-' || e.key === '_') { stepZoom(-1); e.preventDefault(); }
        else if (e.key === '0') { setZoom(0); e.preventDefault(); }
    });
    applyScale();

    // ---------- render ----------
    function render(partial) {
        var d = st.data; if (!d) return;
        var procs = d.processes || [];
        var cur = procs.filter(function (p) { return p.op === st.op; })[0] || { code: st.op, name: st.op, num: 0 };
        var stale = d.op !== st.op;        // กดเลือก Process แล้วข้อมูลใหม่ยังไม่มา

        // hero
        $('hCode').textContent = 'Process ' + cur.code + (d.day ? ' · ' + d.day.split('-').reverse().join('/') : '');
        $('hName').textContent = cur.name;
        $('hNum').textContent = fmt(cur.num);
        var mcList = stale ? [] : (d.machines || []);
        var ngAll = stale ? null : mcList.reduce(function (s, m) { return s + (m.ng || 0); }, 0);
        var active = mcList.filter(function (m) { return m.num > 0; });
        $('kNg').textContent = ngAll == null ? '–' : fmt(ngAll);
        $('kNgp').textContent = ngAll == null ? '–' : (cur.num > 0 ? (Math.ceil((ngAll / cur.num * 100) * 100 - 1e-7) / 100).toFixed(2) + '%' : '0%');
        $('kMc').innerHTML = stale ? '–' : active.length + '<small>' + (active.length === 1 ? 'machine' : 'machines') + '</small>';
        $('kTop').textContent = active.length ? active[0].eq.replace(/^\d+\./, '').replace(/^UB-MC-/, '') + ' · ' + fmtK(active[0].num) : '–';

        // table
        var tot = 0, html = '', pmax = Math.max.apply(null, procs.map(function (p) { return p.num; }).concat([0]));
        procs.forEach(function (p) {
            tot += p.num;
            html += '<tr data-op="' + esc(p.op) + '" class="' + (p.op === st.op ? 'sel' : '') + (p.num ? '' : ' zero') + '">' +
                '<td>' + esc(p.code) + '</td><td>' + esc(p.name) + '</td><td>' + esc(p.type) + '</td>' +
                '<td class="r qty"><span class="db" style="width:' + (pmax > 0 ? Math.max(0, p.num) / pmax * 92 : 0).toFixed(1) + '%"></span><span class="v">' + fmt(p.num) + '</span></td></tr>';
        });
        $('tBody').innerHTML = html;
        $('tTotal').textContent = fmt(tot);
        var u = (d.updated || '').split(' ')[1] || '--:--:--';
        $('clk').textContent = u;

        if (stale) {
            $('mcPlot').innerHTML = '<div class="empty">Loading ' + esc(cur.name) + '...</div>';
            $('ngPlot').innerHTML = ''; $('ngLegend').innerHTML = ''; $('ngTotal').textContent = '–'; $('ngPct').innerHTML = '&nbsp;'; $('mcSub').innerHTML = '&nbsp;';
            return;
        }
        drawMachines(d.machines || [], cur);
        drawNg(d.ng || []);
    }
    $('tBody').onclick = function (e) {
        var tr = e.target.closest('tr'); if (tr) selectOp(tr.getAttribute('data-op'));
    };

    function svgEl(w, h) {
        return '<svg viewBox="0 0 ' + w + ' ' + h + '" width="' + w + '" height="' + h + '" xmlns="http://www.w3.org/2000/svg">';
    }
    // แท่งมุมบนโค้ง 4px ฐานตรง
    function barPath(x, y, w, h, r) {
        r = Math.min(r, w / 2, h);
        if (h <= 0) return '';
        return 'M' + x + ',' + (y + h) + 'V' + (y + r) + 'Q' + x + ',' + y + ' ' + (x + r) + ',' + y +
               'H' + (x + w - r) + 'Q' + (x + w) + ',' + y + ' ' + (x + w) + ',' + (y + r) + 'V' + (y + h) + 'Z';
    }
    // ขั้นของแกน Y ให้เป็นเลขกลมๆ (1, 2, 2.5, 5 x 10^n)
    function niceStep(v) {
        if (v <= 0) return 1;
        var p = Math.pow(10, Math.floor(Math.log10(v))), n = v / p;
        return (n <= 1 ? 1 : n <= 2 ? 2 : n <= 2.5 ? 2.5 : n <= 5 ? 5 : 10) * p;
    }
    // คืน { max, ticks } : ขั้นกลมๆ และเพดานใกล้ค่าจริงที่สุด
    function niceScale(v) {
        v = Math.max(v, 1);
        var step = niceStep(v / 4), n = Math.ceil(v / step);
        return { max: n * step, ticks: n };
    }
    function yAxis(svg, max, x0, x1, top, bottom, ticks) {
        var out = '';
        for (var i = 0; i <= ticks; i++) {
            var v = max / ticks * i, y = bottom - (bottom - top) * i / ticks;
            out += '<line class="' + (i === 0 ? 'base' : 'gl') + '" x1="' + x0 + '" x2="' + x1 + '" y1="' + y + '" y2="' + y + '"/>';
            out += '<text class="ax" x="' + (x0 - 6 * U) + '" y="' + (y + 4 * U) + '" text-anchor="end">' + fmtK(v) + '</text>';
        }
        return out;
    }

    // ---------- กราฟเครื่องจักร ----------
    function drawMachines(list, cur) {
        var box = $('mcPlot'), W = box.clientWidth, H = box.clientHeight;
        $('mcSub').innerHTML = list.length ? esc(cur.name) + ' · ' + list.length + (list.length === 1 ? ' machine' : ' machines') + ' · click a bar to see NG for that machine' : '&nbsp;';
        if (!list.length) { box.innerHTML = '<div class="empty">No output for ' + esc(cur.name) + ' on this day</div>'; return; }
        if (W < 50 || H < 50) return;

        var longest = list.reduce(function (m, r) { return Math.max(m, r.eq.length); }, 0);
        var L = 44 * U, R = 8 * U, T = 22 * U;
        var slot = (W - L - R) / list.length;
        var rotate = slot < longest * 6.6 * U;
        var B = (rotate ? Math.min(90, 14 + longest * 4.6) : 26) * U;
        var sc = niceScale(Math.max.apply(null, list.map(function (m) { return m.num; })) * 1.08), max = sc.max;
        var bw = Math.max(6 * U, Math.min(72 * U, slot * 0.62));
        var s = svgEl(W, H) + '<defs><linearGradient id="gBar" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="var(--bar-top)"/><stop offset="1" stop-color="var(--bar)"/></linearGradient></defs>' +
                yAxis(null, max, L, W - R, T, H - B, sc.ticks);
        list.forEach(function (m, i) {
            var cx = L + slot * i + slot / 2, h = (H - B - T) * Math.max(0, m.num) / max, y = H - B - h;
            var dim = st.eq && st.eq !== m.eq;
            s += '<path d="' + barPath(cx - bw / 2, y, bw, h, 4 * U) + '" fill="' + (dim ? 'var(--bar-dim)' : 'url(#gBar)') + '"/>';
            if (slot > 26 * U) s += '<text class="vl' + (i === 0 ? ' top' : '') + '" x="' + cx + '" y="' + (y - 6 * U) + '" text-anchor="middle">' + fmtK(m.num) + '</text>';
            if (rotate) s += '<text class="ax" transform="translate(' + (cx + 4 * U) + ',' + (H - B + 12 * U) + ') rotate(-30)" text-anchor="end">' + esc(m.eq) + '</text>';
            else s += '<text class="ax" x="' + cx + '" y="' + (H - B + 16 * U) + '" text-anchor="middle">' + esc(m.eq) + '</text>';
            s += '<rect class="hit" data-i="' + i + '" x="' + (L + slot * i) + '" y="' + T + '" width="' + slot + '" height="' + (H - B - T + 6 * U) + '" fill="transparent"/>';
        });
        box.innerHTML = s + '</svg>';
        box.querySelectorAll('.hit').forEach(function (el) {
            var m = list[+el.getAttribute('data-i')];
            el.onmousemove = function (ev) {
                showTip('<b>' + esc(m.eq) + '</b><br>Output <b>' + fmt(m.num) + '</b> pcs' +
                    '<br>NG <b>' + fmt(m.ng) + '</b> pcs' + (m.num > 0 ? ' <span class="mu">(' + (Math.ceil((m.ng / m.num * 100) * 100 - 1e-7) / 100).toFixed(2) + '%)</span>' : '') +
                    '<br><span class="mu">' + (st.eq === m.eq ? 'Click again to show all machines' : 'Click to see NG for this machine only') + '</span>', ev);
            };
            el.onmouseleave = hideTip;
            el.onclick = function () { st.eq = st.eq === m.eq ? '' : m.eq; hideTip(); setFilterChip(); load(); render(); };
        });
    }
    function setFilterChip() {
        $('ngFilter').innerHTML = st.eq ? '<span class="filter-chip">' + esc(st.eq) + '<button type="button" title="Show all machines">✕</button></span>' : '';
        var b = $('ngFilter').querySelector('button');
        if (b) b.onclick = function () { st.eq = ''; setFilterChip(); load(); render(); };
    }

    // ---------- กราฟ NG (stacked) ----------
    var SLOTS = ['--s1', '--s2', '--s3', '--s4', '--s5', '--s6', '--s7'];
    function drawNg(rows) {
        var box = $('ngPlot'), W = box.clientWidth, H = box.clientHeight;
        if (st.data && (st.data.eq || '') !== st.eq) { box.innerHTML = '<div class="empty">Loading...</div>'; return; }
        setFilterChip();
        var total = rows.reduce(function (s, r) { return s + r.qty; }, 0);
        $('ngTotal').textContent = fmt(total);
        var base = 0, cp = (st.data.processes || []).filter(function (p) { return p.op === st.op; })[0];
        if (st.eq) { var mm = (st.data.machines || []).filter(function (m) { return m.eq === st.eq; })[0]; base = mm ? mm.num : 0; }
        else base = cp ? cp.num : 0;
        $('ngPct').textContent = base > 0 ? (Math.ceil(total / base * 10000 - 1e-7) / 100).toFixed(2) + '% of output' : '\u00a0';   // ปัดขึ้น: มี NG จะไม่โชว์ 0%

        // สาเหตุ เรียงตามยอดรวม 7 อันดับแรกได้สีของตัวเอง ที่เหลือรวมเป็น "อื่นๆ"
        var byReason = {};
        rows.forEach(function (r) { var k = r.reason || r.group || '(Unspecified)'; byReason[k] = (byReason[k] || 0) + r.qty; });
        var reasons = Object.keys(byReason).sort(function (a, b) { return byReason[b] - byReason[a]; });
        var top = reasons.slice(0, reasons.length > SLOTS.length ? SLOTS.length - 1 : SLOTS.length);
        var color = {}; top.forEach(function (k, i) { color[k] = 'var(' + SLOTS[i] + ')'; });
        var hasOther = reasons.length > top.length;
        var keyOf = function (r) { var k = r.reason || r.group || '(Unspecified)'; return color[k] ? k : 'Other'; };
        var keys = top.concat(hasOther ? ['Other'] : []);
        if (hasOther) color['Other'] = 'var(--s-other)';

        $('ngLegend').innerHTML = keys.map(function (k) {
            var v = k === 'Other' ? reasons.slice(top.length).reduce(function (s, x) { return s + byReason[x]; }, 0) : byReason[k];
            return '<span title="' + esc(k) + ' : ' + fmt(v) + '"><i style="background:' + color[k] + '"></i>' + esc(k) + '<b>' + fmt(v) + '</b></span>';
        }).join('');

        if (!rows.length) { box.innerHTML = '<div class="empty">No NG' + (st.eq ? ' for ' + esc(st.eq) : '') + ' on this day</div>'; return; }
        if (W < 50 || H < 50) return;

        // จัดกลุ่มตามชั่วโมง (เรียงตามกะ 08:00 → 07:00)
        var hours = {}, hl = [];
        rows.forEach(function (r) {
            if (!hours[r.h]) { hours[r.h] = {}; hl.push(r.h); }
            var k = keyOf(r); hours[r.h][k] = (hours[r.h][k] || 0) + r.qty;
        });
        hl.sort(function (a, b) { return shiftOrder(a) - shiftOrder(b); });
        var colTot = hl.map(function (h) { return keys.reduce(function (s, k) { return s + (hours[h][k] || 0); }, 0); });

        var L = 40 * U, R = 8 * U, T = 20 * U, B = 24 * U;
        var sc = niceScale(Math.max.apply(null, colTot) * 1.1), max = sc.max;
        var slot = (W - L - R) / hl.length, bw = Math.max(8 * U, Math.min(90 * U, slot * 0.6));
        var s = svgEl(W, H) + yAxis(null, max, L, W - R, T, H - B, sc.ticks);
        var segs = [];
        hl.forEach(function (h, i) {
            var cx = L + slot * i + slot / 2, x = cx - bw / 2, y = H - B, n = 0;
            var present = keys.filter(function (k) { return hours[h][k]; });
            present.forEach(function (k, j) {
                var v = hours[h][k], hh = (H - B - T) * v / max;
                var isTop = j === present.length - 1;
                var gap = j > 0 ? 2 * U : 0;                          // ช่องว่าง 2px ระหว่างชั้น
                var segH = Math.max(0, hh - gap);
                y -= hh;
                s += isTop ? '<path d="' + barPath(x, y, bw, segH, 4 * U) + '" fill="' + color[k] + '"/>'
                           : '<rect x="' + x + '" y="' + y + '" width="' + bw + '" height="' + segH + '" fill="' + color[k] + '"/>';
                if (segH >= 16 * U && bw >= 22 * U) s += '<text class="seg-l" x="' + cx + '" y="' + (y + segH / 2 + 4 * U) + '" text-anchor="middle">' + fmt(v) + '</text>';
                segs.push({ x: x, y: y, w: bw, h: hh, hour: h, key: k, v: v, tot: colTot[i] });
                n++;
            });
            s += '<text class="vl" x="' + cx + '" y="' + (y - 6 * U) + '" text-anchor="middle">' + fmt(colTot[i]) + '</text>';
            s += '<text class="ax" x="' + cx + '" y="' + (H - B + 16 * U) + '" text-anchor="middle">' + hourLabel(h) + '</text>';
        });
        segs.forEach(function (g, i) {
            s += '<rect class="seg-hit" data-i="' + i + '" x="' + (g.x - 4) + '" y="' + g.y + '" width="' + (g.w + 8) + '" height="' + Math.max(g.h, 6) + '" fill="transparent"/>';
        });
        box.innerHTML = s + '</svg>';
        box.querySelectorAll('.seg-hit').forEach(function (el) {
            var g = segs[+el.getAttribute('data-i')];
            el.onmousemove = function (ev) {
                showTip('<b>' + hourLabel(g.hour) + '</b> <span class="mu">(' + pad(g.hour) + ':00–' + pad(g.hour) + ':59)</span><br>' +
                        '<span style="display:inline-block;width:9px;height:9px;border-radius:2px;background:' + color[g.key] + '"></span> ' +
                        esc(g.key) + '<br>NG <b>' + fmt(g.v) + '</b> pcs <span class="mu">· hour total ' + fmt(g.tot) + '</span>', ev);
            };
            el.onmouseleave = hideTip;
        });
    }

    // ---------- start ----------
    var rT = null;
    window.addEventListener('resize', function () { applyScale(); clearTimeout(rT); rT = setTimeout(render, 120); });
    syncUrl();
    load();
    // รีเฟรชทุก 1 นาที · ถ้ากำลังดูวันนี้แล้วข้ามวันผลิต -> เปลี่ยนเป็นวันใหม่ (จอทีวีเปิดค้าง)
    setInterval(function () { var t = shiftToday(); if (st.follow && st.day !== t) { setDay(t); return; } load(); }, REFRESH_MS);
    setInterval(function () { var t = shiftToday(); if (st.follow && st.day !== t) setDay(t); }, 15000);
})();
</script>
</asp:Content>
