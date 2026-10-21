<%@ Page Title="OEE Dashboard" MasterPageFile="~/Site.Master" Language="C#" AutoEventWireup="true"
    CodeBehind="OEE_Dashboard.aspx.cs"
    Inherits="Dashbord.OEE_Dashboard" %>

<%-- =========================================================
     OEE Dashboard : A × P × Q ต่อ Process / เครื่องจักร
     ========================================================= --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">

<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/flatpickr/4.6.13/flatpickr.min.css" />
<script src="https://cdnjs.cloudflare.com/ajax/libs/flatpickr/4.6.13/flatpickr.min.js"></script>

<style>

    :root {
        --card:#ffffff;
        --ink:#0f172a;
        --mute:#64748b;
        --line:#e2e8f0;
        --accent:#6366f1;
        --shadow:0 1px 2px rgba(15,23,42,.06), 0 8px 24px rgba(15,23,42,.06);

        --cA:#0284c7;   /* Availability */
        --cP:#7c3aed;   /* Performance  */
        --cQ:#059669;   /* Quality      */
    }

    .oee {
        display:grid;
        grid-template-columns:300px minmax(0, 1fr);
        grid-template-rows:auto auto 1fr;
        gap:16px;
        padding:16px;
        height:calc(100vh - var(--header-h, 64px));
        min-height:720px;
    }

    .oee > * , .gauges > * { min-width:0; }

    .card {
        background:var(--card);
        border:1px solid var(--line);
        border-radius:18px;
        box-shadow:var(--shadow);
    }

    /* ================= LEFT : FILTER ================= */
    .side {
        grid-row:1/4;
        display:flex; flex-direction:column; gap:16px;
        min-height:0; overflow:auto;
    }
    .side > * { flex-shrink:0; }

    .filter { padding:18px; }
    .filter h3, .info h3 {
        margin:0 0 14px; font-size:15px; font-weight:700;
        display:flex; align-items:center; gap:8px;
    }
    .filter h3::before, .info h3::before {
        content:""; width:9px; height:9px; border-radius:50%;
        background:linear-gradient(135deg,#6366f1,#ec4899);
    }
    .filter label {
        display:block; margin:12px 0 5px;
        font-size:12px; font-weight:700; letter-spacing:.06em;
        text-transform:uppercase; color:var(--mute);
    }
    .filter input[type=text], .filter select {
        width:100%; height:38px; padding:0 12px;
        border:1px solid #cbd5e1; border-radius:10px;
        background:#f8fafc; color:var(--ink);
        font:inherit; font-size:14px; outline:none;
    }
    .filter input[type=text]:focus, .filter select:focus {
        border-color:var(--accent); background:#fff;
        box-shadow:0 0 0 3px rgba(99,102,241,.18);
    }
    .two { display:grid; grid-template-columns:1fr 1fr; gap:8px; }
    .two label { margin-top:0; }

    .quick { display:grid; grid-template-columns:1fr 1fr; gap:6px; margin-top:10px; }
    .quick button {
        height:32px; border:1px solid var(--line); border-radius:9px;
        background:#fff; color:var(--mute);
        font:inherit; font-size:12px; font-weight:700; cursor:pointer;
    }
    .quick button:hover { background:#eef2ff; border-color:#c7d2fe; color:#4338ca; }

    .btn {
        width:100%; height:40px; margin-top:16px;
        border:0; border-radius:10px;
        background:linear-gradient(135deg,#6366f1,#8b5cf6); color:#fff;
        font:inherit; font-size:14px; font-weight:700; cursor:pointer;
        box-shadow:0 6px 16px rgba(99,102,241,.35);
    }

    .info { padding:18px; }
    .kv { display:flex; justify-content:space-between; padding:7px 0; border-bottom:1px dashed #eef2f7; font-size:14px; }
    .kv:last-child { border-bottom:0; }
    .kv span { color:var(--mute); }
    .kv b { font-variant-numeric:tabular-nums; }

    .how {
        padding:14px 16px; font-size:12.5px; line-height:1.55; color:#475569;
        background:#f8fafc; border:1px dashed #cbd5e1; border-radius:14px;
    }
    .how b { color:var(--ink); }
    .how code { font-size:11.5px; background:#eef2ff; padding:1px 5px; border-radius:5px; color:#4338ca; }

    /* ================= RIGHT TOP : A P Q OEE ================= */
    .gauges {
        display:grid;
        grid-template-columns:repeat(3, 1fr) 1.25fr;
        gap:16px;
    }

    .g {
        position:relative; overflow:hidden;
        padding:18px 20px;
        display:flex; align-items:center; gap:18px;
    }
    .gauge {
        --v:0; --c:#6366f1;
        width:92px; height:92px; border-radius:50%; flex-shrink:0;
        display:grid; place-items:center;
        background:conic-gradient(var(--c) calc(var(--v) * 1%), #eef2f7 0);
    }
    .gauge::after {
        content:""; width:72px; height:72px; border-radius:50%;
        background:#fff; grid-area:1/1;
    }
    .gauge b {
        grid-area:1/1; z-index:1;
        font-size:20px; font-weight:800; color:var(--c);
        font-variant-numeric:tabular-nums;
    }
    .g .t span {
        display:block; font-size:12px; font-weight:800; letter-spacing:.1em;
        color:var(--mute); text-transform:uppercase;
    }
    .g .t { min-width:0; }
    .g .t strong { display:block; font-size:22px; margin:2px 0 4px; }
    .g .t em { display:block; font-style:normal; font-size:12.5px; color:var(--mute); line-height:1.4; }

    .gA .gauge { --c:var(--cA); } .gA strong { color:var(--cA); }
    .gP .gauge { --c:var(--cP); } .gP strong { color:var(--cP); }
    .gQ .gauge { --c:var(--cQ); } .gQ strong { color:var(--cQ); }

    .gO {
        background:linear-gradient(135deg,#1e1b4b,#312e81 60%,#4338ca);
        color:#fff; border:0;
    }
    .gO .gauge { width:112px; height:112px; --c:#a5b4fc; background:conic-gradient(var(--c) calc(var(--v) * 1%), rgba(255,255,255,.15) 0); }
    .gO .gauge::after { width:88px; height:88px; background:#2a2770; }
    .gO .gauge b { font-size:24px; color:#fff; }
    .gO .t span { color:#a5b4fc; }
    .gO .t strong { color:#fff; font-size:26px; }
    .gO .t em { color:#c7d2fe; }
    .grade { display:inline-block; margin-top:6px; padding:3px 10px; border-radius:999px; font-size:12px; font-weight:800; }
    .gr-wc   { background:#d1fae5; color:#047857; }
    .gr-good { background:#e0f2fe; color:#0369a1; }
    .gr-mid  { background:#fef3c7; color:#b45309; }
    .gr-low  { background:#fee2e2; color:#b91c1c; }

    /* ================= RIGHT MIDDLE : DAILY ================= */
    .daily { padding:14px 20px 12px; }
    .daily-head { display:flex; align-items:center; gap:10px; margin-bottom:8px; }
    .daily-head h3 { margin:0; font-size:15px; }
    .daily-head small { margin-left:auto; color:var(--mute); font-size:12px; }
    .bars { display:flex; align-items:flex-end; gap:8px; height:110px; }
    .bar-col { flex:1; min-width:0; display:flex; flex-direction:column; align-items:center; gap:4px; height:100%; }
    .bar-col .v { font-size:11px; font-weight:700; color:var(--ink); }
    .bar-col .b {
        width:100%; max-width:56px; border-radius:8px 8px 4px 4px;
        background:linear-gradient(180deg,#818cf8,#6366f1);
        margin-top:auto;
    }
    .bar-col .d { font-size:11px; color:var(--mute); }
    .bars .target {
        position:absolute; left:0; right:0; border-top:2px dashed #10b981;
    }
    .bars-wrap { position:relative; }

    /* ================= RIGHT BOTTOM : TABLE ================= */
    .panel { padding:14px 18px; min-height:0; display:flex; flex-direction:column; }
    .panel-head { display:flex; align-items:center; gap:10px; margin-bottom:10px; flex-wrap:wrap; }

    .tabs { display:flex; gap:4px; padding:4px; background:#f1f5f9; border-radius:12px; }
    .tabs button {
        padding:7px 16px; border:0; border-radius:9px;
        background:transparent; color:var(--mute);
        font:inherit; font-size:13px; font-weight:700; cursor:pointer;
    }
    .tabs button.on {
        background:linear-gradient(135deg,#6366f1,#8b5cf6); color:#fff;
        box-shadow:0 4px 12px rgba(99,102,241,.35);
    }

    .search {
        height:34px; width:240px; padding:0 12px;
        border:1px solid #cbd5e1; border-radius:10px;
        font:inherit; font-size:13px; outline:none;
    }
    .search:focus { border-color:var(--accent); box-shadow:0 0 0 3px rgba(99,102,241,.18); }
    .note { font-size:12.5px; color:var(--mute); }

    .btn-export {
        margin-left:auto;
        display:inline-flex; align-items:center; gap:6px;
        height:34px; padding:0 14px;
        border:1px solid var(--line); border-radius:10px;
        background:#fff; color:var(--ink);
        font:inherit; font-size:13px; font-weight:700; cursor:pointer;
    }
    .btn-export:hover { background:#eef2ff; border-color:#c7d2fe; color:#4338ca; }

    .tbl-wrap { flex:1; min-height:0; overflow:auto; border:1px solid var(--line); border-radius:12px; }
    table.tb {
        width:100%; border-collapse:separate; border-spacing:0;
        font-size:14px; font-variant-numeric:tabular-nums;
    }

    /* หัวตาราง 2 ชั้น */
    table.tb thead th {
        position:sticky; z-index:2; background:#f8fafc;
        white-space:nowrap; text-align:left;
    }
    table.tb th.grp {
        top:0; height:30px; padding:6px 12px;
        font-size:11px; font-weight:800; letter-spacing:.12em; text-transform:uppercase;
        color:#6366f1; background:#eef2ff; text-align:center;
        border-bottom:1px solid #e0e7ff;
    }
    table.tb th.col {
        top:30px; padding:10px 10px;
        font-size:12.5px; font-weight:700; color:#475569;
        border-bottom:2px solid var(--line);
        cursor:pointer; user-select:none;
    }
    table.tb th.col:hover { color:var(--ink); background:#f1f5f9; }

    table.tb td {
        padding:11px 10px; white-space:nowrap;
        border-bottom:1px solid #f1f5f9; color:#1e293b;
    }
    table.tb tbody tr:nth-child(even) td { background:#fafbfd; }
    table.tb tbody tr:hover td { background:#eef2ff; }

    table.tb .num { text-align:right; }
    table.tb .gs { border-left:2px solid #e2e8f0; }
    table.tb td.key { font-weight:700; color:var(--ink); }
    table.tb td.pc { min-width:84px; }

    /* ค่าศูนย์ = จาง , NG/Loss/Down = สีเตือน */
    .z { color:#cbd5e1; }
    .w { color:#be123c; font-weight:600; }

    /* แท่ง % ในช่อง */
    .pbar {
        position:relative; height:24px; border-radius:7px;
        background:#f1f5f9; overflow:hidden; min-width:72px;
    }
    .pbar i { position:absolute; left:0; top:0; bottom:0; border-radius:7px; opacity:.9; }
    .pbar span {
        position:relative; z-index:1; display:block;
        padding:0 8px; line-height:24px;
        font-size:12.5px; font-weight:800; text-align:right; color:#0f172a;
    }
    .pbar.pc-wc   i { background:#6ee7b7; }
    .pbar.pc-good i { background:#7dd3fc; }
    .pbar.pc-mid  i { background:#fcd34d; }
    .pbar.pc-low  i { background:#fca5a5; }
    .pbar.main { height:28px; }
    .pbar.main span { line-height:28px; font-size:13.5px; }

    table.tb tfoot td {
        position:sticky; bottom:0; z-index:1;
        background:#eef2ff; font-weight:800; color:var(--ink);
        padding:12px; border-top:2px solid #c7d2fe;
    }

    .src { font-size:10.5px; font-weight:800; padding:1px 7px; border-radius:999px; letter-spacing:.03em; }
    .src.iot { background:#dcfce7; color:#15803d; }
    .src.erp { background:#f1f5f9; color:#64748b; }
    .dp { color:#15803d; font-weight:600; } .dn { color:#b45309; font-weight:600; }
    .stop { font-size:11px; font-weight:800; padding:1px 7px; border-radius:999px; background:#fee2e2; color:#b91c1c; }
    .empty { text-align:center; padding:40px; color:#94a3b8; }

    @media (max-width:1300px) {
        .gauges { grid-template-columns:1fr 1fr; }
    }
    @media (max-width:1000px) {
        .oee { display:block; height:auto; }
        .oee > * { margin-bottom:16px; }
        .gauges { grid-template-columns:1fr; }
        .panel { height:600px; }
    }

</style>

</asp:Content>


<asp:Content ID="cHeaderRight" ContentPlaceHolderID="HeaderRight" runat="server">
    <div class="refresh" id="rf" title="Click to refresh now">
        <div class="ring" id="rfRing"><b id="rfSec">60</b></div>
        <div>
            <small>REALTIME</small>
            <em id="rfTxt">Refresh every 60 sec</em>
        </div>
    </div>
</asp:Content>


<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<asp:Panel ID="pnlMain" runat="server" DefaultButton="btnSearch">
<div class="oee">

    <!-- =====================================================
         LEFT : FILTER + SUMMARY
         ===================================================== -->
    <div class="side">

        <div class="card filter">
            <h3>Filter</h3>

            <div class="two">
                <div>
                    <label>From</label>
                    <asp:TextBox ID="txtFrom" runat="server" autocomplete="off" />
                </div>
                <div>
                    <label>To</label>
                    <asp:TextBox ID="txtTo" runat="server" autocomplete="off" />
                </div>
            </div>

            <div class="quick">
                <button type="button" data-q="today">Today</button>
                <button type="button" data-q="yesterday">Yesterday</button>
                <button type="button" data-q="7">Last 7 days</button>
                <button type="button" data-q="month">This month</button>
            </div>

            <label>Process</label>
            <asp:DropDownList ID="ddlProcess" runat="server"
                AutoPostBack="true" OnSelectedIndexChanged="ddlProcess_Changed" />

            <label>Machine</label>
            <asp:DropDownList ID="ddlMachine" runat="server"
                AutoPostBack="true" OnSelectedIndexChanged="Filter_Changed" />

            <asp:Button ID="btnSearch" runat="server" Text="Calculate OEE"
                CssClass="btn" OnClick="btnSearch_Click" />
        </div>

        <div class="card info">
            <h3>Summary</h3>
            <div class="kv"><span>Machines</span><b id="sMc">0</b></div>
            <div class="kv"><span>Batches</span><b id="sBt">0</b></div>
            <div class="kv"><span>Planned time</span><b id="sPl">0 h</b></div>
            <div class="kv"><span>Run time</span><b id="sRn">0 h</b></div>
            <div class="kv"><span>Down time</span><b id="sDn">0 h</b></div>
            <div class="kv"><span>Ideal output</span><b id="sIq">0</b></div>
            <div class="kv"><span>Actual output</span><b id="sTt">0</b></div>
            <div class="kv"><span>Machine count (IoT)</span><b id="sMp">–</b></div>
            <div class="kv"><span>Good (Out)</span><b id="sGd">0</b></div>
            <div class="kv"><span>NG / Loss</span><b id="sNg">0 / 0</b></div>
        </div>

        <div class="how" id="howBox"></div>

    </div>


    <!-- =====================================================
         RIGHT TOP : A / P / Q / OEE
         ===================================================== -->
    <div class="gauges">

        <div class="card g gA">
            <div class="gauge" id="rA"><b id="vA">0%</b></div>
            <div class="t">
                <span>A</span>
                <strong>Availability</strong>
                <em id="eA">Run time / Planned time</em>
            </div>
        </div>

        <div class="card g gP">
            <div class="gauge" id="rP"><b id="vP">0%</b></div>
            <div class="t">
                <span>P</span>
                <strong>Performance</strong>
                <em id="eP">Actual / Ideal output</em>
            </div>
        </div>

        <div class="card g gQ">
            <div class="gauge" id="rQ"><b id="vQ">0%</b></div>
            <div class="t">
                <span>Q</span>
                <strong>Quality</strong>
                <em id="eQ">Good / Actual output</em>
            </div>
        </div>

        <div class="card g gO">
            <div class="gauge" id="rO"><b id="vO">0%</b></div>
            <div class="t">
                <span>Overall Equipment Effectiveness</span>
                <strong>OEE</strong>
                <em id="eO"></em>
                <span class="grade" id="gO">–</span>
            </div>
        </div>

    </div>


    <!-- =====================================================
         RIGHT MIDDLE : OEE รายวัน
         ===================================================== -->
    <div class="card daily" style="display:none" id="dailyCard">
        <div class="daily-head">
            <h3>OEE by Day</h3>
            <small>World-class target: 85%</small>
        </div>
        <div class="bars-wrap"><div class="bars" id="bars"></div></div>
    </div>


    <!-- =====================================================
         RIGHT BOTTOM : TABLE
         ===================================================== -->
    <div class="card panel">

        <div class="panel-head">
            <div class="tabs" id="tabs">
                <button type="button" class="on" data-t="m">By Machine</button>
                <button type="button" data-t="b">Batch Details</button>
            </div>
            <input type="text" class="search" id="q" placeholder="Search PO / Batch / Machine..." autocomplete="off" />
            <span class="note" id="tbNote"></span>
            <button type="button" class="btn-export" id="btnExport">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12 M7 10l5 5 5-5 M5 21h14"/></svg>
                Export
            </button>
        </div>

        <div class="tbl-wrap">
            <table class="tb">
                <thead id="tHead"></thead>
                <tbody id="tBody"></tbody>
                <tfoot><tr id="tFoot"></tr></tfoot>
            </table>
        </div>

    </div>

</div>
</asp:Panel>
</asp:Content>


<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">

<%-- ข้อมูล (JSON) อยู่นอก form จึงไม่ถูกส่งกลับตอน postback --%>
<script type="application/json" id="pageJson"><%= PageData %></script>

<script>
    // @ts-nocheck
    (function () {

        var D = {};
        try { D = JSON.parse(document.getElementById('pageJson').textContent) || {}; }
        catch (e) { console.error(e); }

        var btnSearch = document.getElementById('<%= btnSearch.ClientID %>');
        var txtFrom = document.getElementById('<%= txtFrom.ClientID %>');
        var txtTo = document.getElementById('<%= txtTo.ClientID %>');

        function fmt(n) { return Number(n || 0).toLocaleString('en-US'); }
        function f1(n) { return Number(n || 0).toLocaleString('en-US', { minimumFractionDigits: 1, maximumFractionDigits: 1 }); }
        function qf(n) { return (Math.floor(Number(n || 0) * 100 + 1e-7) / 100).toFixed(2); }   // Quality: 2 ตำแหน่ง ปัดลง (มี NG จะไม่โชว์ 100%)
        function esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;'); }

        // เกณฑ์สี (World-class : OEE 85 / A 90 / P 95 / Q 99)
        var TARGET = { oee: 85, a: 90, p: 95, q: 99 };
        function cls(v, target) {
            if (v >= target) return 'pc-wc';
            if (v >= target * 0.85) return 'pc-good';
            if (v >= target * 0.65) return 'pc-mid';
            return 'pc-low';
        }
        function badge(v, target) { return '<span class="pct ' + cls(v, target) + '">' + f1(v) + '%</span>'; }


        // =========================================================
        // Date picker + Quick range
        // =========================================================
        if (window.flatpickr) {
            var opts = {
                dateFormat: 'Y-m-d', altInput: true, altFormat: 'd/m/Y',
                onReady: function (d, s, inst) { inst.input.setAttribute('data-init', inst.input.value); },
                onChange: function (d, s, inst) {
                    if (!d.length || inst.input.getAttribute('data-init') === inst.input.value) return;
                    inst.input.setAttribute('data-init', inst.input.value);
                    btnSearch.click();
                }
            };
            flatpickr(txtFrom, opts);
            flatpickr(txtTo, opts);
        }

        function ymd(d) {
            var p = function (n) { return (n < 10 ? '0' : '') + n; };
            return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate());
        }
        function shiftToday() { var d = new Date(); d.setHours(d.getHours() - 8); d.setHours(0, 0, 0, 0); return d; }

        document.querySelector('.quick').addEventListener('click', function (e) {
            var b = e.target.closest('button'); if (!b) return;
            var q = b.getAttribute('data-q'), t = shiftToday(), f = new Date(t);
            if (q === 'yesterday') { t.setDate(t.getDate() - 1); f = new Date(t); }
            else if (q === '7') { f.setDate(f.getDate() - 6); }
            else if (q === 'month') { f = new Date(t.getFullYear(), t.getMonth(), 1); }
            txtFrom.value = ymd(f); txtTo.value = ymd(t);
            btnSearch.click();
        });


        // =========================================================
        // Gauges
        // =========================================================
        function setRing(id, v) {
            var r = document.getElementById('r' + id);
            r.style.setProperty('--v', Math.max(0, Math.min(100, v || 0)));
            document.getElementById('v' + id).textContent = (id === 'Q' ? qf(v) : f1(v)) + '%';
        }
        setRing('A', D.A); setRing('P', D.P); setRing('Q', D.Q); setRing('O', D.OEE);

        document.getElementById('eA').textContent = f1(D.run) + ' h run / ' + f1(D.planned) + ' h planned';
        document.getElementById('eP').textContent = fmt(D.total) + ' / ' + fmt(D.idealQty) + ' pcs (ideal)';
        document.getElementById('eQ').textContent = fmt(D.good) + ' good / ' + fmt(D.total) + ' pcs';
        document.getElementById('eO').textContent =
            (D.process || '') + ' · ' + (D.machine === 'All' ? 'All machines' : D.machine) + ' · ' +
            (D.dateFrom === D.dateTo ? D.dateFrom : D.dateFrom + ' – ' + D.dateTo);

        var g = document.getElementById('gO');
        var o = D.OEE || 0;
        if (o >= 85) { g.textContent = 'World-class ≥ 85%'; g.className = 'grade gr-wc'; }
        else if (o >= 60) { g.textContent = 'Typical 60–85%'; g.className = 'grade gr-good'; }
        else if (o >= 40) { g.textContent = 'Needs improvement'; g.className = 'grade gr-mid'; }
        else { g.textContent = 'Low < 40%'; g.className = 'grade gr-low'; }


        // =========================================================
        // Summary + วิธีคำนวณ
        // =========================================================
        document.getElementById('sMc').textContent = fmt(D.machineCount);
        document.getElementById('sBt').textContent = fmt(D.batches);
        document.getElementById('sPl').textContent = f1(D.planned) + ' h';
        document.getElementById('sRn').textContent = f1(D.run) + ' h';
        document.getElementById('sDn').textContent = f1(D.down) + ' h';
        document.getElementById('sIq').textContent = fmt(D.idealQty);
        document.getElementById('sTt').textContent = fmt(D.total);
        document.getElementById('sMp').textContent = D.iotCount ? fmt(D.mpcs) + ' pcs · ' + D.iotCount + '/' + D.machineCount + ' mc' : '–';
        document.getElementById('sGd').textContent = fmt(D.good);
        document.getElementById('sNg').textContent = fmt(D.ng) + ' / ' + fmt(D.loss);

        var C = D.cfg || {};
        document.getElementById('howBox').innerHTML =
            '<b>How OEE is calculated</b><br>' +
            '<b style="color:#15803d">IoT</b> machines (same as MC Monitor): <b>A</b> = machine run time / (run + stop + offline) · ' +
            '<b>P</b> = Σ(shots × Std CT) / run time<br>' +
            '<b style="color:#64748b">ERP</b> machines (no IoT yet): run time from check-out gaps (&gt;' + C.maxGap + ' h = down), ' +
            'ideal rate = P' + C.pct + ' of last ' + C.lookback + ' days<br>' +
            '<b>Q</b> = Good / (Good + NG) from ERP (all machines) · shift 08:00–08:00 · ' +
            '<b>Machine pcs</b> = shots × cavities, <b>Diff</b> = machine − ERP<br>' +
            (D.iotError ? '<span style="color:#b91c1c">IoT DB: ' + esc(D.iotError) + '</span><br>' : '') +
            (D.machineTypes ? 'Machines: type <b>' + esc(D.machineTypes) + '</b> only' +
                (D.strayBatches ? ' · <span style="color:#b45309">' + D.strayBatches + ' batch(es) of other machine types excluded (wrong process in ERP)</span>' : '') + '<br>' : '') +
            '<code>OEE = A × P × Q</code>';


        // =========================================================
        // OEE รายวัน
        // =========================================================
        (function () {
            var days = D.daily || [];
            if (days.length < 2) return;
            document.getElementById('dailyCard').style.display = '';
            var h = '';
            days.forEach(function (x) {
                h += '<div class="bar-col" title="A ' + f1(x.a) + '% · P ' + f1(x.p) + '% · Q ' + qf(x.q) + '%">' +
                     '<span class="v">' + f1(x.oee) + '%</span>' +
                     '<div class="b" style="height:' + Math.max(2, x.oee * 0.8) + 'px"></div>' +
                     '<span class="d">' + esc(x.d) + '</span></div>';
            });
            document.getElementById('bars').innerHTML = h;
        })();


        // =========================================================
        // ตาราง : By Machine / Batch Details
        // =========================================================
        var VIEW = {
            m: {
                rows: D.machines || [],
                file: 'OEE_by_Machine',
                cols: [
                    { k: 'machine', t: 'Machine',     g: '',               key: true },
                    { k: 'src',     t: 'Source',      g: '' },
                    { k: 'batches', t: 'Batches',     g: '',               num: true },
                    { k: 'planned', t: 'Planned',     g: 'Time (hours)',   num: true, f: f1 },
                    { k: 'run',     t: 'Run',         g: 'Time (hours)',   num: true, f: f1 },
                    { k: 'down',    t: 'Down',        g: 'Time (hours)',   num: true, f: f1, warn: true },
                    { k: 'total',   t: 'Actual',      g: 'Output (pcs)',   num: true },
                    { k: 'good',    t: 'Good',        g: 'Output (pcs)',   num: true },
                    { k: 'ng',      t: 'NG',          g: 'Output (pcs)',   num: true, warn: true },
                    { k: 'loss',    t: 'Loss',        g: 'Output (pcs)',   num: true, warn: true },
                    { k: 'mpcs',    t: 'Machine',     g: 'Machine vs ERP', num: true },
                    { k: 'diff',    t: 'Diff',        g: 'Machine vs ERP', num: true, diff: true },
                    { k: 'a',       t: 'Avail.', g: 'OEE (%)',       pct: 'a' },
                    { k: 'p',       t: 'Perf.',  g: 'OEE (%)',       pct: 'p' },
                    { k: 'q',       t: 'Quality',      g: 'OEE (%)',       pct: 'q' },
                    { k: 'oee',     t: 'OEE',          g: 'OEE (%)',       pct: 'oee', main: true }
                ],
                total: function () {
                    return { machine: 'Total', src: D.iotCount ? 'IoT ' + D.iotCount + '/' + D.machineCount : '', batches: D.batches,
                             planned: D.planned, run: D.run, down: D.down,
                             total: D.total, good: D.good, ng: D.ng, loss: D.loss, mpcs: D.iotCount ? D.mpcs : null, diff: null,
                             a: D.A, p: D.P, q: D.Q, oee: D.OEE };
                }
            },
            b: {
                rows: D.rows || [],
                file: 'OEE_Batch_Details',
                cols: [
                    { k: 't',       t: 'Check-Out',  g: 'Time',          sort: 'tk' },
                    { k: 'tin',     t: 'Check-In',   g: 'Time' },
                    { k: 'machine', t: 'Machine',    g: 'Batch',         key: true },
                    { k: 'batch',   t: 'Batch',      g: 'Batch' },
                    { k: 'po',      t: 'PO',         g: 'Batch' },
                    { k: 'ball',    t: 'Ball Model', g: 'Batch' },
                    { k: 'inQty',   t: 'In',         g: 'Quantity (pcs)', num: true },
                    { k: 'outQty',  t: 'Out',        g: 'Quantity (pcs)', num: true },
                    { k: 'ng',      t: 'NG',         g: 'Quantity (pcs)', num: true, warn: true },
                    { k: 'loss',    t: 'Loss',       g: 'Quantity (pcs)', num: true, warn: true },
                    { k: 'run',     t: 'Run (min)',  g: 'Speed',          num: true },
                    { k: 'rate',    t: 'pcs / h',    g: 'Speed',          num: true },
                    { k: 'stop',    t: 'Note',       g: 'Speed' }
                ],
                total: function () {
                    var t = { t: 'Total', inQty: 0, outQty: 0, ng: 0, loss: 0, run: 0 };
                    view.forEach(function (r) { t.inQty += r.inQty; t.outQty += r.outQty; t.ng += r.ng; t.loss += r.loss; t.run += r.run; });
                    t.rate = t.run > 0 ? Math.round((t.outQty + t.ng + t.loss) / (t.run / 60)) : 0;
                    return t;
                }
            }
        };

        var cur = 'm', sortKey = null, sortDir = 1, view = [];

        // แท่ง % : สีตามเกณฑ์ World-class
        function pbar(v, target, main, isQ) {
            v = Number(v || 0);
            var c = cls(v, target);
            return '<div class="pbar ' + c + (main ? ' main' : '') + '" title="Target ' + target + '%">' +
                   '<i style="width:' + Math.max(0, Math.min(100, v)) + '%"></i><span>' + (isQ ? qf(v) : f1(v)) + '%</span></div>';
        }

        function cellHtml(c, v, isFoot) {
            if (c.pct) return pbar(v, TARGET[c.pct], c.main, c.pct === 'q');
            if (c.k === 'src') return v === 'IoT' ? '<span class="src iot" title="A/P from machine status (same as MC Monitor)">IoT</span>'
                                    : v === 'ERP' ? '<span class="src erp" title="Estimated from ERP check-out (no IoT yet)">ERP</span>' : esc(v || '');
            if (c.diff) {
                if (v === null || v === undefined) return '';
                return '<span class="' + (v >= 0 ? 'dp' : 'dn') + '">' + (v > 0 ? '+' : '') + fmt(v) + '</span>';
            }
            if (c.k === 'stop') return v ? '<span class="stop" title="Machine stopped more than ' + D.cfg.maxGap + ' h before this batch">after stop</span>' : '';
            if (c.num) {
                if (v === null || v === undefined) return '';
                if (!v) return '<span class="z">–</span>';
                var t = c.f ? c.f(v) : fmt(v);
                return (c.warn && !isFoot) ? '<span class="w">' + t + '</span>' : t;
            }
            return esc(v);
        }

        function render() {
            var V = VIEW[cur];
            var q = document.getElementById('q').value.trim().toLowerCase();

            view = V.rows.filter(function (r) {
                if (!q) return true;
                return [r.machine, r.po, r.batch, r.ball].join(' ').toLowerCase().indexOf(q) >= 0;
            });

            if (sortKey !== null) {
                var sc = V.cols[sortKey], k = sc.sort || sc.k;
                view.sort(function (a, b) {
                    var x = a[k], y = b[k];
                    if (sc.num || sc.pct) return ((x || 0) - (y || 0)) * sortDir;
                    return String(x || '').localeCompare(String(y || '')) * sortDir;
                });
            }

            // ---------- หัวตาราง 2 ชั้น : กลุ่ม / คอลัมน์ ----------
            var g1 = '', i = 0;
            while (i < V.cols.length) {
                var gname = V.cols[i].g, span = 0;
                while (i + span < V.cols.length && V.cols[i + span].g === gname) span++;
                g1 += '<th colspan="' + span + '" class="grp' + (gname ? ' gs' : '') + '">' + esc(gname) + '</th>';
                i += span;
            }
            var g2 = V.cols.map(function (c, j) {
                var first = j > 0 && c.g && V.cols[j - 1].g !== c.g;
                var ar = sortKey === j ? (sortDir > 0 ? ' ▲' : ' ▼') : '';
                return '<th data-i="' + j + '" class="col' + (c.num || c.pct ? ' num' : '') + (first ? ' gs' : '') + '">' + esc(c.t) + ar + '</th>';
            }).join('');
            document.getElementById('tHead').innerHTML = '<tr>' + g1 + '</tr><tr>' + g2 + '</tr>';

            // ---------- แถวข้อมูล ----------
            function rowHtml(r, isFoot) {
                return V.cols.map(function (c, j) {
                    var first = j > 0 && c.g && V.cols[j - 1].g !== c.g;
                    var cl = (c.num || c.pct ? 'num' : '') + (first ? ' gs' : '') + (c.key ? ' key' : '') + (c.pct ? ' pc' : '');
                    return '<td class="' + cl + '">' + cellHtml(c, r[c.k], isFoot) + '</td>';
                }).join('');
            }

            if (!view.length) {
                document.getElementById('tBody').innerHTML =
                    '<tr><td class="empty" colspan="' + V.cols.length + '">No data found</td></tr>';
            } else {
                document.getElementById('tBody').innerHTML =
                    view.map(function (r) { return '<tr>' + rowHtml(r, false) + '</tr>'; }).join('');
            }

            document.getElementById('tFoot').innerHTML = view.length ? rowHtml(V.total(), true) : '';

            document.getElementById('tbNote').textContent =
                fmt(view.length) + ' rows' + (cur === 'b' && D.truncated ? ' (showing latest ' + fmt(D.maxRows) + ')' : '');
        }

        document.getElementById('tabs').addEventListener('click', function (e) {
            var b = e.target.closest('button'); if (!b) return;
            document.querySelectorAll('#tabs button').forEach(function (x) { x.classList.remove('on'); });
            b.classList.add('on');
            cur = b.getAttribute('data-t'); sortKey = null; sortDir = 1;
            render();
        });

        document.getElementById('tHead').addEventListener('click', function (e) {
            var th = e.target.closest('th[data-i]'); if (!th) return;
            var i = Number(th.getAttribute('data-i'));
            sortDir = sortKey === i ? -sortDir : 1; sortKey = i;
            render();
        });

        document.getElementById('q').addEventListener('input', render);


        // =========================================================
        // Export CSV
        // =========================================================
        document.getElementById('btnExport').addEventListener('click', function () {
            var V = VIEW[cur];
            function cell(v) { return '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"'; }
            var lines = [V.cols.map(function (c) { return cell(c.t); }).join(',')];
            view.forEach(function (r) {
                lines.push(V.cols.map(function (c) {
                    var v = r[c.k];
                    if (c.k === 'stop') v = v ? 'after stop' : '';
                    return cell(v);
                }).join(','));
            });
            if (cur === 'm') {
                lines.push(['Total', '', D.batches, D.planned, D.run, D.down, D.total, D.good, D.ng, D.loss, D.iotCount ? D.mpcs : '', '', D.A, D.P, D.Q, D.OEE].map(cell).join(','));
            }
            var blob = new Blob(['﻿' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
            var a = document.createElement('a');
            a.href = URL.createObjectURL(blob);
            a.download = V.file + '_' + D.qFrom + '_' + D.qTo + '.csv';
            document.body.appendChild(a); a.click(); a.remove();
        });

        render();


        // =========================================================
        // Auto Refresh ทุก 60 วินาที (หยุดนับขณะใช้งานช่องค้นหา / ปฏิทิน)
        // =========================================================
        var REFRESH_SEC = 60, secLeft = REFRESH_SEC;
        var loadedAt = new Date().toLocaleTimeString('en-GB');

        function showCountdown() {
            document.getElementById('rfSec').textContent = secLeft;
            document.getElementById('rfTxt').textContent = 'Updated ' + loadedAt;
            document.getElementById('rfRing').style.setProperty('--p', (secLeft / REFRESH_SEC * 360) + 'deg');
        }
        function isBusy() {
            var a = document.activeElement;
            if (a && (a.tagName === 'SELECT' || (a.tagName === 'INPUT' && a.type === 'text'))) return true;
            return !!document.querySelector('.flatpickr-calendar.open');
        }
        document.getElementById('rf').addEventListener('click', function () { btnSearch.click(); });
        setInterval(function () {
            if (isBusy()) { secLeft = REFRESH_SEC; showCountdown(); return; }
            secLeft--;
            if (secLeft <= 0) { secLeft = 0; showCountdown(); btnSearch.click(); return; }
            showCountdown();
        }, 1000);
        showCountdown();

    })();
</script>

</asp:Content>
