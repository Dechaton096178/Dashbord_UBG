<%@ Page Title="PO Search" MasterPageFile="~/Site.Master" Language="C#" AutoEventWireup="true"
    CodeBehind="PO_Search.aspx.cs"
    Inherits="Dashbord.PO_Search" %>

<%-- =========================================================
     ใช้ Site.Master (Header + เมนูแผนก)
     ========================================================= --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<!-- Date picker (dd/mm/yyyy) -->
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/flatpickr/4.6.13/flatpickr.min.css" />
<script src="https://cdnjs.cloudflare.com/ajax/libs/flatpickr/4.6.13/flatpickr.min.js"></script>

<style>

    :root {
        --bg:#eef2f7;
        --card:#ffffff;
        --ink:#0f172a;
        --mute:#64748b;
        --line:#e2e8f0;
        --accent:#6366f1;
        --shadow:0 1px 2px rgba(15,23,42,.06), 0 8px 24px rgba(15,23,42,.06);
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
        grid-template-columns:330px 1fr;
        grid-template-rows:auto 1fr;
        gap:16px;
        padding:16px;
        height:calc(100vh - var(--header-h, 64px));
        min-height:720px;
    }

    .card {
        background:var(--card);
        border:1px solid var(--line);
        border-radius:18px;
        box-shadow:var(--shadow);
    }

    /* ---------- HEADER ---------- */
    .topbar {
        grid-column:1/-1;
        display:flex;
        align-items:center;
        gap:14px;
        padding:14px 20px;
        border-radius:18px;
        background:linear-gradient(135deg,#1e1b4b,#312e81 60%,#4338ca);
        color:#fff;
        box-shadow:var(--shadow);
    }

    .topbar .logo {
        width:46px; height:46px;
        border-radius:12px;
        display:grid; place-items:center;
        background:rgba(255,255,255,.14);
        border:1px solid rgba(255,255,255,.25);
    }

    .topbar h1 { margin:0; font-size:22px; font-weight:700; line-height:1.2; }

    .topbar small {
        display:block;
        font-size:12px;
        font-weight:700;
        letter-spacing:.18em;
        color:#a5b4fc;
    }

    /* LAST UPDATED */
    .updated { margin-left:auto; text-align:right; }
    .updated small { display:block; font-size:10px; font-weight:700; letter-spacing:.14em; color:#a5b4fc; }
    .updated em { font-style:normal; font-size:14px; font-weight:600; color:#fff; font-variant-numeric:tabular-nums; }

    /* REALTIME (not used) */
    .refresh {
        margin-left:auto;
        display:flex; align-items:center; gap:8px;
        padding:4px 14px 4px 5px;
        border:1px solid rgba(255,255,255,.22);
        border-radius:999px;
        background:rgba(255,255,255,.1);
        cursor:pointer; user-select:none;
    }
    .refresh:hover { background:rgba(255,255,255,.18); }
    .ring {
        --p:360deg;
        width:38px; height:38px; border-radius:50%;
        display:grid; place-items:center;
        background:conic-gradient(#a5b4fc var(--p), rgba(255,255,255,.18) 0);
    }
    .ring b {
        width:30px; height:30px; border-radius:50%;
        background:#312e81; color:#fff;
        display:grid; place-items:center;
        font-size:13px; font-weight:700;
        font-variant-numeric:tabular-nums;
    }
    .refresh small { display:flex; align-items:center; gap:6px; font-size:10px; color:#6ee7b7; letter-spacing:.1em; }
    .refresh small::before {
        content:""; width:8px; height:8px; border-radius:50%;
        background:#10b981; animation:pulse 1.4s infinite;
    }
    .refresh em { display:block; font-style:normal; font-size:12px; line-height:1.2; color:#c7d2fe; }
    @keyframes pulse {
        0%   { box-shadow:0 0 0 0 rgba(16,185,129,.6); }
        100% { box-shadow:0 0 0 9px rgba(16,185,129,0); }
    }

    /* ---------- FILTER ---------- */
    .filters {
        grid-column:1/-1;
        display:flex;
        flex-wrap:wrap;
        gap:14px;
        align-items:flex-end;
        padding:14px 18px;
    }

    .filters label {
        display:block;
        font-weight:600;
        font-size:12px;
        letter-spacing:.06em;
        text-transform:uppercase;
        color:var(--mute);
        margin-bottom:5px;
    }

    .search-box { position:relative; }

    .search-box svg {
        position:absolute; left:11px; top:50%;
        transform:translateY(-50%);
        color:#94a3b8; pointer-events:none;
    }

    .filters input[type=text],
    .filters select {
        height:38px;
        padding:0 12px;
        border:1px solid #cbd5e1;
        border-radius:10px;
        background:#f8fafc;
        color:var(--ink);
        font:inherit;
        font-size:14px;
        outline:none;
        transition:border-color .15s, box-shadow .15s, background .15s;
    }

    .filters input[type=text] { width:240px; padding-left:34px; }

    .dates { display:flex; align-items:center; gap:6px; }
    .dates .to { font-size:13px; color:var(--mute); }
    .filters .dates input { width:128px !important; padding-left:12px !important; cursor:pointer; }
    .filters select { min-width:190px; }

    .filters input[type=text]:focus,
    .filters select:focus {
        border-color:var(--accent);
        background:#fff;
        box-shadow:0 0 0 3px rgba(99,102,241,.18);
    }

    .toggle {
        display:flex; align-items:center; gap:8px;
        height:38px; padding:0 12px;
        border:1px solid var(--line); border-radius:10px;
        background:#f8fafc; font-size:14px; cursor:pointer;
    }
    .toggle > span { display:flex; align-items:center; gap:8px; }
    .toggle input { margin:0; width:16px; height:16px; accent-color:var(--accent); }
    .toggle label { margin:0; text-transform:none; letter-spacing:0; font-size:14px; color:var(--ink); cursor:pointer; }

    .btn {
        height:38px; padding:0 22px;
        border:0; border-radius:10px;
        font:inherit; font-size:14px; font-weight:600;
        cursor:pointer;
        transition:transform .15s, box-shadow .15s;
    }
    .btn-primary {
        background:linear-gradient(135deg,#6366f1,#8b5cf6);
        color:#fff;
        box-shadow:0 6px 16px rgba(99,102,241,.35);
    }
    .btn-primary:hover { transform:translateY(-1px); box-shadow:0 10px 20px rgba(99,102,241,.4); }
    .btn + .btn { margin-left:6px; }
    .btn-ghost { background:#f1f5f9; color:var(--mute); }
    .btn-ghost:hover { background:#e2e8f0; color:var(--ink); }

    /* ---------- LEFT : KPI ---------- */
    .side {
        display:flex;
        flex-direction:column;
        gap:12px;
        min-height:0;
        overflow:auto;
        padding-right:2px;
    }

    .side > * { flex-shrink:0; }

    .total {
        padding:18px;
        text-align:center;
        background:linear-gradient(135deg,#ffffff 35%,#eef2ff 100%);
        position:relative; overflow:hidden;
    }
    .total::before {
        content:""; position:absolute; left:0; top:0; bottom:0; width:8px;
        background:#4f46e5;
    }
    .total b { display:block; font-size:48px; font-weight:800; line-height:1; color:#4f46e5; font-variant-numeric:tabular-nums; }
    .total span { display:block; margin-top:8px; font-size:13px; font-weight:700; letter-spacing:.08em; color:var(--mute); }

    .tiles {
        display:grid;
        grid-template-columns:1fr 1fr;
        gap:10px;
    }

    .tile {
        padding:12px 10px;
        text-align:center;
        cursor:pointer;
        border:1px solid var(--line);
        border-radius:14px;
        background:#fff;
        box-shadow:var(--shadow);
        transition:transform .15s, border-color .15s, box-shadow .15s;
    }
    .tile:hover { transform:translateY(-2px); border-color:#c7d2fe; }
    .tile.on { border-color:var(--accent); box-shadow:0 0 0 3px rgba(99,102,241,.18); }
    .tile b { display:block; font-size:30px; font-weight:800; line-height:1.1; font-variant-numeric:tabular-nums; color:#cbd5e1; }
    .tile.has b { color:#0284c7; }
    .tile span { display:block; font-size:13px; color:var(--mute); margin-top:2px; }
    .tile em { display:block; font-style:normal; font-size:11px; color:#94a3b8; margin-top:4px; min-height:14px; }

    .tile.finish { background:linear-gradient(135deg,#fff 35%,#d1fae5 100%); }
    .tile.finish b { color:#059669; }

    /* ---------- RIGHT : TABLE ---------- */
    .panel {
        padding:16px 18px;
        min-width:0; min-height:0;
        display:flex; flex-direction:column;
    }

    .panel-head {
        display:flex; align-items:center; gap:10px;
        margin-bottom:10px;
    }
    .panel-head h2 {
        margin:0; font-size:18px; font-weight:700;
        display:flex; align-items:center; gap:10px;
    }
    .panel-head h2::before {
        content:""; width:10px; height:10px; border-radius:50%;
        background:linear-gradient(135deg,#6366f1,#ec4899);
    }
    .panel-head .note { margin-left:auto; font-size:13px; color:var(--mute); }

    .tbl-wrap { flex:1; min-height:0; overflow:auto; border-radius:12px; }

    table.tb {
        border-collapse:separate; border-spacing:0;
        width:100%; font-size:14px;
        font-variant-numeric:tabular-nums;
    }

    table.tb th {
        position:sticky; top:0; z-index:2;
        background:#fff;
        text-align:left;
        font-size:12px; font-weight:700;
        letter-spacing:.04em;
        color:var(--mute);
        padding:9px 10px;
        border-bottom:2px solid var(--line);
        white-space:nowrap;
        cursor:pointer; user-select:none;
    }
    table.tb th:hover { color:var(--ink); }
    table.tb th.num, table.tb td.num { text-align:right; }
    table.tb th .ar { font-size:10px; margin-left:4px; opacity:.6; }

    table.tb td {
        padding:8px 10px;
        border-bottom:1px solid #f1f5f9;
        white-space:nowrap;
    }
    table.tb tbody tr:nth-child(even) td { background:#fafbfd; }
    table.tb tbody tr:hover td { background:#eef2ff; }

    table.tb tfoot td {
        position:sticky; bottom:0;
        background:#f1f5f9;
        font-weight:700;
        padding:10px;
        border-top:2px solid var(--line);
    }

    .badge {
        display:inline-block;
        padding:2px 10px;
        border-radius:999px;
        font-size:12px; font-weight:700;
    }
    .b-Finished { background:#d1fae5; color:#047857; }
    .b-WIP      { background:#fef3c7; color:#b45309; }
    .b-Resting  { background:#e0f2fe; color:#0369a1; }
    .b-History  { background:#f1f5f9; color:#64748b; }

    .empty { text-align:center; padding:40px; color:#94a3b8; }

    /* ---------- MOBILE ---------- */
    @media(max-width:1000px) {
        .grid { display:block; height:auto; }
        .grid > * { margin-bottom:16px; }
        .filters input[type=text] { width:100%; }
        .filters > div { flex:1 1 100%; }
        .panel { height:600px; }
    }

</style>
</asp:Content>


<asp:Content ID="cHeaderRight" ContentPlaceHolderID="HeaderRight" runat="server">
    <!-- นับถอยหลังรีเฟรช : คลิกเพื่อรีเฟรชทันที -->
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


<div class="grid">
    <!-- =====================================================
         FILTERS
         ===================================================== -->

    <div class="card filters">

        <!-- [NEW] Check-In Date From / To -->
        <div>
            <label>Check-In Date</label>
            <div class="dates">
                <asp:TextBox ID="txtFrom" runat="server" placeholder="From" autocomplete="off" />
                <span class="to">to</span>
                <asp:TextBox ID="txtTo" runat="server" placeholder="To" autocomplete="off" />
            </div>
        </div>

        <div>
            <label>PO Number</label>
            <div class="search-box">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>
                <asp:TextBox ID="txtPO" runat="server" placeholder="e.g. 4500765561"
                    list="poList" autocomplete="off" />
            </div>
            <datalist id="poList"></datalist>
        </div>

        <div>
            <label>Batch MO</label>
            <div class="search-box">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>
                <asp:TextBox ID="txtBatch" runat="server" placeholder="e.g. 5101-2026071704"
                    autocomplete="off" />
            </div>
        </div>

        <div>
            <label>Process</label>
            <asp:DropDownList ID="ddlProcess" runat="server"
                AutoPostBack="true" OnSelectedIndexChanged="Filter_Changed" />
        </div>

        <div>
            <label>&nbsp;</label>
            <div class="toggle">
                <asp:CheckBox ID="chkAllSteps" runat="server"
                    AutoPostBack="true" OnCheckedChanged="Filter_Changed"
                    Text="Show all steps" />
            </div>
        </div>

        <div>
            <label>&nbsp;</label>
            <asp:Button ID="btnSearch" runat="server" Text="Search"
                CssClass="btn btn-primary" OnClick="btnSearch_Click" />
            <asp:Button ID="btnClear" runat="server" Text="Clear"
                CssClass="btn btn-ghost" OnClick="btnClear_Click" />
        </div>

    </div>


    <!-- =====================================================
         LEFT : KPI
         ===================================================== -->

    <div class="side">

        <div class="card total">
            <b id="kBatch">0</b>
            <span>TOTAL BATCHES</span>
        </div>

        <div class="tiles" id="tiles"></div>

    </div>


    <!-- =====================================================
         RIGHT : TABLE
         ===================================================== -->

    <div class="card panel">

        <div class="panel-head">
            <h2 id="tbTitle">Latest Status by Batch</h2>
            <span class="note" id="tbNote"></span>
        </div>

        <div class="tbl-wrap">
            <table class="tb">
                <thead>
                    <tr id="tbHead"></tr>
                </thead>
                <tbody id="tbBody"></tbody>
                <tfoot>
                    <tr id="tbFoot"></tr>
                </tfoot>
            </table>
        </div>

    </div>


</div>


</asp:Panel>
</asp:Content>


<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<%-- ข้อมูล (JSON) อยู่นอก <form> จึงไม่ถูกส่งกลับตอน postback --%>
<script type="application/json" id="pageJson"><%= PageData %></script>
<script type="application/json" id="poJson"><%= POListJson %></script>


<script>
    // @ts-nocheck
    // ห่อทั้งหมดใน (function(){...})() ให้ฟังก์ชันเป็นของหน้านี้เท่านั้น
    // (กัน Visual Studio ฟ้อง Duplicate function กับหน้าอื่น เช่น IOT_NGDashcord.aspx)
    (function () {

    // =========================================================
    // Data
    // =========================================================

    function readJson(id, def) {
        try { return JSON.parse(document.getElementById(id).textContent) || def; }
        catch (e) { console.error(id, e); return def; }
    }

    var D = readJson('pageJson', {});
    var PO_LIST = readJson('poJson', []);

    var ddlProcess = document.getElementById('<%= ddlProcess.ClientID %>');
    var btnSearch = document.getElementById('<%= btnSearch.ClientID %>');

    function esc(s) {
        return String(s == null ? '' : s)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }

    function fmt(n) { return Number(n || 0).toLocaleString('en-US'); }


    // =========================================================
    // Date picker : แสดง dd/mm/yyyy ส่งให้ C# เป็น yyyy-MM-dd
    // =========================================================

    if (window.flatpickr) {
        var fpOpts = {
            dateFormat: 'Y-m-d',
            altInput: true,
            altFormat: 'd/m/Y',
            // ค้นหาทันทีเมื่อเลือกวันที่ใหม่ (เทียบกับค่าตอนโหลดหน้า กัน postback วนซ้ำ)
            onReady: function (dates, str, inst) {
                inst.input.setAttribute('data-init', inst.input.value);
            },
            onChange: function (dates, str, inst) {
                if (!dates.length) return;
                if (inst.input.getAttribute('data-init') === inst.input.value) return;
                inst.input.setAttribute('data-init', inst.input.value);
                btnSearch.click();
            }
        };
        flatpickr('#<%= txtFrom.ClientID %>', fpOpts);
        flatpickr('#<%= txtTo.ClientID %>', fpOpts);
    }


    // =========================================================
    // PO autocomplete
    // =========================================================

    document.getElementById('poList').innerHTML =
        PO_LIST.map(function (p) { return '<option value="' + esc(p) + '">'; }).join('');


    // =========================================================
    // KPI + Process tiles (คลิกเพื่อกรอง Process นั้น)
    // =========================================================

    document.getElementById('kBatch').textContent = fmt(D.batchCount);

    (function () {
        var html = '';

        (D.tiles || []).forEach(function (t) {
            var n = t.wip + t.rest;
            var on = D.process === t.name ? ' on' : '';
            var detail = n ? ('WIP ' + t.wip + ' · Resting ' + t.rest) : '';
            html += '<div class="tile' + (n ? ' has' : '') + on + '" data-p="' + esc(t.name) + '">' +
                    '<b>' + fmt(n) + '</b><span>in ' + esc(t.name) + '</span><em>' + detail + '</em></div>';
        });

        html += '<div class="tile finish" data-p="Packing"><b>' + fmt(D.finish) +
                '</b><span>Finish</span><em></em></div>';

        var box = document.getElementById('tiles');
        box.innerHTML = html;

        box.addEventListener('click', function (e) {
            var tile = e.target.closest('.tile');
            if (!tile) return;
            var p = tile.getAttribute('data-p');
            // คลิกซ้ำที่ Process เดิม = ยกเลิกการกรอง
            ddlProcess.value = (D.process === p) ? 'All' : p;
            btnSearch.click();
        });
    })();


    // =========================================================
    // Table (คลิกหัวคอลัมน์เพื่อเรียง)
    // =========================================================

    var COLS = [
        { k: 'po',   t: 'PO Number' },
        { k: 'st',   t: 'Status' },
        { k: 'qin',  t: 'Check-In Qty', num: true },
        { k: 'tin',  t: 'Check-In Time', sort: 'tinK' },
        { k: 'tout', t: 'Check-Out Time', sort: 'toutK' },
        { k: 'mo',   t: 'Batch MO' },
        { k: 'ball', t: 'Ball Model' },
        { k: 'proc', t: 'Process' },
        { k: 'qout', t: 'Check-Out Qty', num: true },
        { k: 'ng',   t: 'NG', num: true }
    ];

    var rows = (D.rows || []).slice();
    var sortKey = null, sortDir = 1;

    function renderHead() {
        document.getElementById('tbHead').innerHTML = COLS.map(function (c, i) {
            var ar = (sortKey === i) ? (sortDir > 0 ? '▲' : '▼') : '';
            return '<th data-i="' + i + '" class="' + (c.num ? 'num' : '') + '">' +
                   esc(c.t) + '<span class="ar">' + ar + '</span></th>';
        }).join('');
    }

    function renderBody() {
        var body = document.getElementById('tbBody');

        if (!rows.length) {
            body.innerHTML = '<tr><td class="empty" colspan="' + COLS.length + '">No data found</td></tr>';
            return;
        }

        var html = '';
        rows.forEach(function (r) {
            html += '<tr>';
            COLS.forEach(function (c) {
                var v = r[c.k];
                if (c.k === 'st') v = '<span class="badge b-' + esc(v) + '">' + esc(v) + '</span>';
                else if (c.num) v = fmt(v);
                else v = esc(v);
                html += '<td class="' + (c.num ? 'num' : '') + '">' + v + '</td>';
            });
            html += '</tr>';
        });
        body.innerHTML = html;
    }

    function renderFoot() {
        var html = '';
        COLS.forEach(function (c, i) {
            var v = '';
            if (i === 0) v = 'Total';
            else if (c.k === 'qin') v = fmt(D.sumIn);
            else if (c.k === 'qout') v = fmt(D.sumOut);
            else if (c.k === 'ng') v = fmt(D.sumNg);
            html += '<td class="' + (c.num ? 'num' : '') + '">' + v + '</td>';
        });
        document.getElementById('tbFoot').innerHTML = html;
    }

    document.getElementById('tbHead').addEventListener('click', function (e) {
        var th = e.target.closest('th');
        if (!th) return;
        var i = Number(th.getAttribute('data-i'));
        sortDir = (sortKey === i) ? -sortDir : 1;
        sortKey = i;

        var c = COLS[i];
        var k = c.sort || c.k;
        rows.sort(function (a, b) {
            var x = a[k], y = b[k];
            if (c.num) return (x - y) * sortDir;
            return String(x).localeCompare(String(y)) * sortDir;
        });

        renderHead();
        renderBody();
    });

    // หัวตาราง + หมายเหตุ
    document.getElementById('tbTitle').textContent =
        D.allSteps ? 'All Steps by Batch' : 'Latest Status by Batch';

    document.getElementById('tbNote').textContent =
        'Check-In ' + D.dateFrom + ' – ' + D.dateTo + '  ·  ' +
        fmt(D.matched) + ' rows' +
        (D.matched > D.maxRows ? ' (showing first ' + fmt(D.maxRows) + ' — please narrow your search)' : '');

    renderHead();
    renderBody();
    renderFoot();


    // =========================================================
    // Auto Refresh ทุก 60 วินาที
    //   หยุดนับเมื่อ : กำลังพิมพ์ค้นหา / เปิดปฏิทินอยู่
    // =========================================================

    var REFRESH_SEC = 60;
    var secLeft = REFRESH_SEC;
    var loadedAt = new Date().toLocaleTimeString('en-GB');

    function refreshNow() { btnSearch.click(); }

    function showCountdown() {
        document.getElementById('rfSec').textContent = secLeft;
        document.getElementById('rfTxt').textContent = 'Updated ' + loadedAt;
        document.getElementById('rfRing').style.setProperty('--p', (secLeft / REFRESH_SEC * 360) + 'deg');
    }

    function isBusy() {
        var a = document.activeElement;
        if (a && (a.tagName === 'INPUT' && a.type === 'text' || a.tagName === 'SELECT')) return true;
        return !!document.querySelector('.flatpickr-calendar.open');
    }

    document.getElementById('rf').addEventListener('click', refreshNow);

    setInterval(function () {
        if (isBusy()) { secLeft = REFRESH_SEC; showCountdown(); return; }
        secLeft--;
        if (secLeft <= 0) { secLeft = 0; showCountdown(); refreshNow(); return; }
        showCountdown();
    }, 1000);

    showCountdown();


    })();

</script>
</asp:Content>
