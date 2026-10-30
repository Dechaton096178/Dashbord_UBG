<%@ Page Title="ERP Daily Report" MasterPageFile="~/Site.Master" Language="C#" AutoEventWireup="true"
    CodeBehind="ERP_Daily_Report.aspx.cs"
    Inherits="Dashbord.ERP_Daily_Report" %>

<%-- =========================================================
     ERP Daily Report : Completed / NG / WIP ของแต่ละ Process
     ========================================================= --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">

<!-- Date picker (dd/mm/yyyy) -->
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
    }

    .page {
        display:grid;
        grid-template-columns:repeat(4, 1fr);
        grid-template-rows:auto auto 1fr;
        gap:16px;
        padding:16px;
        height:calc(100vh - var(--header-h, 64px));
        min-height:640px;
    }

    .card {
        background:var(--card);
        border:1px solid var(--line);
        border-radius:18px;
        box-shadow:var(--shadow);
    }

    /* ---------- FILTER ---------- */
    .filters {
        grid-column:1/-1;
        display:flex; flex-wrap:wrap; gap:14px; align-items:flex-end;
        padding:14px 18px;
    }
    .filters label {
        display:block;
        font-weight:600; font-size:12px; letter-spacing:.06em;
        text-transform:uppercase; color:var(--mute);
        margin-bottom:5px;
    }
    .filters input[type=text],
    .filters select {
        height:38px; padding:0 12px;
        border:1px solid #cbd5e1; border-radius:10px;
        background:#f8fafc; color:var(--ink);
        font:inherit; font-size:14px; outline:none;
        transition:border-color .15s, box-shadow .15s, background .15s;
    }
    .filters input[type=text]:focus,
    .filters select:focus {
        border-color:var(--accent); background:#fff;
        box-shadow:0 0 0 3px rgba(99,102,241,.18);
    }
    .dates { display:flex; align-items:center; gap:6px; }
    .dates .to { font-size:13px; color:var(--mute); }
    .dates input { width:128px; cursor:pointer; }
    .filters select { min-width:170px; }

    .quick { display:flex; gap:6px; }
    .quick button {
        height:38px; padding:0 12px;
        border:1px solid var(--line); border-radius:10px;
        background:#fff; color:var(--mute);
        font:inherit; font-size:13px; font-weight:600; cursor:pointer;
    }
    .quick button:hover { color:var(--ink); border-color:#c7d2fe; background:#eef2ff; }

    .btn {
        height:38px; padding:0 22px;
        border:0; border-radius:10px;
        font:inherit; font-size:14px; font-weight:600; cursor:pointer;
        background:linear-gradient(135deg,#6366f1,#8b5cf6); color:#fff;
        box-shadow:0 6px 16px rgba(99,102,241,.35);
    }
    .btn:hover { transform:translateY(-1px); }

    .shift-note { margin-left:auto; font-size:13px; color:var(--mute); }
    .shift-note b { color:var(--ink); }

    /* ---------- KPI ---------- */
    .kpi {
        position:relative; overflow:hidden;
        padding:16px 18px 16px 24px;
        background:linear-gradient(135deg,#fff 40%, var(--t) 100%);
    }
    .kpi::before {
        content:""; position:absolute; left:0; top:0; bottom:0; width:8px;
        background:var(--k);
    }
    .kpi span {
        display:block; font-size:12px; font-weight:700; letter-spacing:.08em;
        color:var(--mute); text-transform:uppercase;
    }
    .kpi b {
        display:block; margin-top:6px;
        font-size:38px; font-weight:800; line-height:1.05;
        color:var(--k); font-variant-numeric:tabular-nums;
    }
    .kpi em { display:block; font-style:normal; font-size:13px; color:var(--mute); margin-top:4px; }

    .k1 { --k:#059669; --t:#d1fae5; }
    .k2 { --k:#db2777; --t:#fce7f3; }
    .k3 { --k:#d97706; --t:#fef3c7; }
    .k4 { --k:#4f46e5; --t:#eef2ff; }

    /* ---------- TABLE ---------- */
    .panel {
        grid-column:1/-1;
        padding:16px 18px;
        min-height:0;
        display:flex; flex-direction:column;
    }
    .panel-head { display:flex; align-items:center; gap:10px; margin-bottom:10px; flex-wrap:wrap; }
    .panel-head h2 {
        margin:0; font-size:18px; font-weight:700;
        display:flex; align-items:center; gap:10px;
    }
    .panel-head h2::before {
        content:""; width:10px; height:10px; border-radius:50%;
        background:linear-gradient(135deg,#6366f1,#ec4899);
    }
    .legend { margin-left:auto; display:flex; gap:14px; font-size:12px; color:var(--mute); }
    .legend i { display:inline-block; width:10px; height:10px; border-radius:3px; margin-right:5px; vertical-align:-1px; }

    .tbl-wrap { flex:1; min-height:0; overflow:auto; }

    table.tb {
        width:100%;
        border-collapse:separate; border-spacing:0;
        font-size:14px; font-variant-numeric:tabular-nums;
    }
    table.tb th {
        position:sticky; top:0; z-index:2;
        background:#fff;
        text-align:left;
        font-size:12px; font-weight:700; letter-spacing:.04em;
        color:var(--mute);
        padding:9px 10px;
        border-bottom:2px solid var(--line);
        white-space:nowrap;
    }
    table.tb th.num, table.tb td.num { text-align:right; }
    table.tb td {
        padding:9px 10px;
        border-bottom:1px solid #f1f5f9;
        white-space:nowrap;
    }
    table.tb tbody tr:hover td { background:#f8fafc; }
    table.tb tbody tr.zero td { color:#94a3b8; }

    table.tb tfoot td {
        position:sticky; bottom:0;
        background:#f1f5f9; font-weight:700;
        padding:10px; border-top:2px solid var(--line);
    }

    .code { font-weight:700; color:var(--mute); }

    .bar-cell { width:22%; min-width:140px; }
    .bar {
        position:relative; height:22px; border-radius:6px;
        background:#f1f5f9; overflow:hidden;
    }
    .bar .done { position:absolute; left:0; top:0; bottom:0; background:#34d399; }
    .bar .ng   { position:absolute; top:0; bottom:0; background:#f472b6; }
    .bar .wip  { position:absolute; top:0; bottom:0; background:#fbbf24; opacity:.85; }

    .pct {
        display:inline-block; min-width:62px;
        padding:2px 8px; border-radius:999px;
        font-size:12px; font-weight:700; text-align:center;
    }
    .p-ok   { background:#d1fae5; color:#047857; }
    .p-warn { background:#fef3c7; color:#b45309; }
    .p-bad  { background:#fee2e2; color:#b91c1c; }
    .p-none { background:#f1f5f9; color:#94a3b8; }

    .type { font-size:12px; padding:2px 8px; border-radius:999px; background:#eef2ff; color:#4338ca; font-weight:600; }
    .type.sub { background:#fef3c7; color:#b45309; }

    /* ---------- คลิกได้ (เปิด Popup) ---------- */
    .kpi.click { cursor:pointer; transition:transform .15s, box-shadow .15s; }
    .kpi.click:hover { transform:translateY(-2px); box-shadow:0 12px 28px rgba(15,23,42,.12); }
    .kpi .hint { position:absolute; right:14px; top:14px; font-size:11px; font-weight:700; color:#94a3b8; letter-spacing:.06em; }

    a.dl {
        color:inherit; text-decoration:none; cursor:pointer;
        border-bottom:1px dashed #c7d2fe; padding-bottom:1px;
    }
    a.dl:hover { color:#4338ca; border-bottom-color:#4338ca; }

    /* ---------- ปุ่ม Completed / NG / WIP ในแต่ละแถว ---------- */
    .act-col { width:1%; white-space:nowrap; }
    .acts { display:flex; gap:6px; justify-content:flex-end; }
    .ab {
        display:inline-flex; align-items:center; justify-content:center;
        width:96px; height:30px; padding:0;   /* ปุ่มขนาดเท่ากันทุกปุ่ม */
        border-radius:8px; border:1px solid;
        font:inherit; font-size:12px; font-weight:700;
        cursor:pointer; background:#fff;
        transition:background .15s, transform .15s;
    }
    .ab span {
        font-weight:800; font-size:11px;
        padding:1px 6px; border-radius:999px; color:#fff;
        font-variant-numeric:tabular-nums;
    }
    .ab:hover { transform:translateY(-1px); }
    .ab-done { color:#047857; border-color:#a7f3d0; }
    .ab-done span { background:#059669; }
    .ab-done:hover { background:#ecfdf5; }
    .ab-ng { color:#be185d; border-color:#fbcfe8; }
    .ab-ng span { background:#db2777; }
    .ab-ng:hover { background:#fdf2f8; }
    .ab-wip { color:#b45309; border-color:#fde68a; }
    .ab-wip span { background:#d97706; }
    .ab-wip:hover { background:#fffbeb; }
    .ab.empty { opacity:.45; }
    .ab.empty span { background:#94a3b8; }

    /* ---------- ปุ่ม Export (ทุกตาราง) ---------- */
    .btn-export {
        display:inline-flex; align-items:center; gap:6px;
        height:34px; padding:0 14px;
        border:1px solid var(--line); border-radius:10px;
        background:#fff; color:var(--ink);
        font:inherit; font-size:13px; font-weight:700; cursor:pointer;
    }
    .btn-export:hover { background:#eef2ff; border-color:#c7d2fe; color:#4338ca; }

    /* ---------- MODAL ---------- */
    .md-back {
        position:fixed; inset:0; z-index:2000;
        background:rgba(15,23,42,.45);
        display:none; align-items:center; justify-content:center;
        padding:24px;
    }
    .md-back.show { display:flex; }

    .md {
        width:min(1280px, 100%);
        max-height:calc(100vh - 48px);
        display:flex; flex-direction:column;
        background:#fff; border-radius:18px;
        box-shadow:0 30px 80px rgba(15,23,42,.35);
        overflow:hidden;
        font-family:'Sarabun',Tahoma,sans-serif;
    }

    .md-head {
        display:flex; align-items:center; gap:12px;
        padding:16px 20px;
        border-bottom:1px solid var(--line);
    }
    .md-head .tag {
        font-size:12px; font-weight:800; letter-spacing:.06em;
        padding:4px 10px; border-radius:999px; color:#fff;
    }
    .tag.done { background:#059669; }
    .tag.ng   { background:#db2777; }
    .tag.wip  { background:#d97706; }
    .md-head h3 { margin:0; font-size:18px; }
    .md-head small { display:block; color:var(--mute); font-size:13px; }
    .md-close {
        margin-left:auto;
        width:36px; height:36px; border-radius:10px;
        border:1px solid var(--line); background:#fff;
        font-size:20px; line-height:1; cursor:pointer; color:var(--mute);
    }
    .md-close:hover { background:#f1f5f9; color:var(--ink); }

    .md-tools {
        display:flex; align-items:center; gap:10px; flex-wrap:wrap;
        padding:12px 20px;
        background:#f8fafc; border-bottom:1px solid var(--line);
    }
    .md-tools input {
        height:36px; width:280px; padding:0 12px;
        border:1px solid #cbd5e1; border-radius:10px;
        font:inherit; font-size:14px; outline:none;
    }
    .md-tools input:focus { border-color:var(--accent); box-shadow:0 0 0 3px rgba(99,102,241,.18); }
    .md-sum { display:flex; gap:16px; font-size:13px; color:var(--mute); }
    .md-sum b { color:var(--ink); font-size:15px; }
    .md-tools .btn2 {
        margin-left:auto;
        height:36px; padding:0 14px;
        border:1px solid var(--line); border-radius:10px;
        background:#fff; font:inherit; font-size:13px; font-weight:600; cursor:pointer;
    }
    .md-tools .btn2:hover { background:#eef2ff; border-color:#c7d2fe; }

    .md-body { flex:1; min-height:0; overflow:auto; }
    .md-body table.tb td { white-space:nowrap; }
    .md-body table.tb td.reason { white-space:normal; min-width:260px; color:#be185d; font-size:13px; }
    .md-body table.tb th { cursor:pointer; user-select:none; }
    .md-msg { padding:50px; text-align:center; color:#94a3b8; }
    .md-warn { padding:8px 20px; background:#fef3c7; color:#92400e; font-size:13px; }

    .wait { font-size:12px; font-weight:700; padding:2px 8px; border-radius:999px; }
    .w-ok  { background:#d1fae5; color:#047857; }
    .w-mid { background:#fef3c7; color:#b45309; }
    .w-old { background:#fee2e2; color:#b91c1c; }

    @media (max-width:1000px) {
        .page { display:block; height:auto; }
        .page > * { margin-bottom:16px; }
        .panel { height:620px; }
        .shift-note { margin-left:0; width:100%; }
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
<div class="page">

    <!-- =====================================================
         FILTERS
         ===================================================== -->
    <div class="card filters">

        <div>
            <label>Shift Date</label>
            <div class="dates">
                <asp:TextBox ID="txtFrom" runat="server" placeholder="From" autocomplete="off" />
                <span class="to">to</span>
                <asp:TextBox ID="txtTo" runat="server" placeholder="To" autocomplete="off" />
            </div>
        </div>

        <div>
            <label>&nbsp;</label>
            <div class="quick">
                <button type="button" data-q="today">Today</button>
                <button type="button" data-q="yesterday">Yesterday</button>
                <button type="button" data-q="7">Last 7 days</button>
                <button type="button" data-q="month">This month</button>
            </div>
        </div>

        <div>
            <label>Type</label>
            <asp:DropDownList ID="ddlType" runat="server"
                AutoPostBack="true" OnSelectedIndexChanged="Filter_Changed">
                <asp:ListItem Text="All" Value="All" Selected="True" />
                <asp:ListItem Text="In-house" Value="1" />
                <asp:ListItem Text="Subcontract" Value="2" />
            </asp:DropDownList>
        </div>

        <div>
            <label>&nbsp;</label>
            <asp:Button ID="btnSearch" runat="server" Text="Search"
                CssClass="btn" OnClick="btnSearch_Click" />
        </div>

        <div class="shift-note">
            Shift day = <b>08:00 → 08:00</b> next day<br />
            <span id="rangeTxt"></span>
        </div>

    </div>


    <!-- =====================================================
         KPI
         ===================================================== -->
    <div class="card kpi k1 click" data-kind="done" data-op="" title="Click to see details">
        <i class="hint">DETAILS ›</i>
        <span>Completed</span>
        <b id="kDone">0</b>
        <em>pcs · in selected shift date</em>
    </div>

    <div class="card kpi k2 click" data-kind="ng" data-op="" title="Click to see details">
        <i class="hint">DETAILS ›</i>
        <span>NG</span>
        <b id="kNg">0</b>
        <em id="kNgPct">0.00% of completed</em>
    </div>

    <div class="card kpi k3 click" data-kind="wip" data-op="" title="Click to see details">
        <i class="hint">DETAILS ›</i>
        <span>In Progress (WIP)</span>
        <b id="kWipQ">0</b>
        <em id="kWipB">0 batches · current</em>
    </div>

    <div class="card kpi k4">
        <span>Yield</span>
        <b id="kYield">0.00%</b>
        <em id="kLoss">Loss 0 pcs</em>
    </div>


    <!-- =====================================================
         TABLE
         ===================================================== -->
    <div class="card panel">

        <div class="panel-head">
            <h2>Output by Process</h2>
            <div class="legend">
                <span><i style="background:#34d399"></i>Completed</span>
                <span><i style="background:#f472b6"></i>NG</span>
                <span><i style="background:#fbbf24"></i>WIP (current)</span>
            </div>
            <button type="button" class="btn-export" id="btnExportMain" title="Export this table to Excel (CSV)">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12 M7 10l5 5 5-5 M5 21h14"/></svg>
                Export
            </button>
        </div>

        <div class="tbl-wrap">
            <table class="tb">
                <thead>
                    <tr>
                        <th>Code</th>
                        <th>Process</th>
                        <th>Type</th>
                        <th class="num">Completed</th>
                        <th class="num">NG</th>
                        <th class="num">NG %</th>
                        <th class="num">Loss</th>
                        <th class="num">WIP Batch</th>
                        <th class="num">WIP Qty</th>
                        <th class="bar-cell">Volume</th>
                        <th class="act-col">Details</th>
                    </tr>
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

<%-- ข้อมูล (JSON) อยู่นอก form จึงไม่ถูกส่งกลับตอน postback --%>
<script type="application/json" id="pageJson"><%= PageData %></script>

<!-- =====================================================
     POPUP รายละเอียด (Completed / NG / WIP)
     ===================================================== -->
<div class="md-back" id="mdBack">
    <div class="md" role="dialog" aria-modal="true">
        <div class="md-head">
            <span class="tag" id="mdTag">NG</span>
            <div>
                <h3 id="mdTitle">Details</h3>
                <small id="mdSub"></small>
            </div>
            <button type="button" class="md-close" id="mdClose" aria-label="Close">×</button>
        </div>
        <div class="md-tools">
            <input type="text" id="mdSearch" placeholder="Search PO / Batch / Machine / Reason..." autocomplete="off" />
            <div class="md-sum" id="mdSum"></div>
            <button type="button" class="btn-export" id="mdCsv" style="margin-left:auto">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12 M7 10l5 5 5-5 M5 21h14"/></svg>
                Export
            </button>
        </div>
        <div class="md-warn" id="mdWarn" style="display:none"></div>
        <div class="md-body">
            <table class="tb">
                <thead><tr id="mdHead"></tr></thead>
                <tbody id="mdBody"></tbody>
            </table>
        </div>
    </div>
</div>

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
        function esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;'); }
        function pct(a, b) { return b ? (a * 100 / b) : 0; }

        function pctBadge(ng, done) {
            if (!done) return '<span class="pct p-none">–</span>';
            var p = pct(ng, done);
            var cls = p < 1 ? 'p-ok' : (p < 3 ? 'p-warn' : 'p-bad');
            return '<span class="pct ' + cls + '">' + p.toFixed(2) + '%</span>';
        }


        // =========================================================
        // Date picker + ปุ่มเลือกช่วงด่วน
        // =========================================================

        var fpFrom = null, fpTo = null;

        if (window.flatpickr) {
            var opts = {
                dateFormat: 'Y-m-d',
                altInput: true,
                altFormat: 'd/m/Y',
                onReady: function (d, s, inst) { inst.input.setAttribute('data-init', inst.input.value); },
                onChange: function (d, s, inst) {
                    if (!d.length) return;
                    if (inst.input.getAttribute('data-init') === inst.input.value) return;
                    inst.input.setAttribute('data-init', inst.input.value);
                    btnSearch.click();
                }
            };
            fpFrom = flatpickr(txtFrom, opts);
            fpTo = flatpickr(txtTo, opts);
        }

        function ymd(d) {
            var p = function (n) { return (n < 10 ? '0' : '') + n; };
            return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate());
        }

        // วันกะปัจจุบัน (ก่อน 08:00 = กะของเมื่อวาน)
        function shiftToday() {
            var d = new Date();
            d.setHours(d.getHours() - 8);
            d.setHours(0, 0, 0, 0);
            return d;
        }

        document.querySelector('.quick').addEventListener('click', function (e) {
            var b = e.target.closest('button');
            if (!b) return;
            var q = b.getAttribute('data-q');
            var t = shiftToday(), f = new Date(t);

            if (q === 'yesterday') { t.setDate(t.getDate() - 1); f = new Date(t); }
            else if (q === '7') { f.setDate(f.getDate() - 6); }
            else if (q === 'month') { f = new Date(t.getFullYear(), t.getMonth(), 1); }

            txtFrom.value = ymd(f);
            txtTo.value = ymd(t);
            btnSearch.click();
        });


        // =========================================================
        // KPI
        // =========================================================

        document.getElementById('rangeTxt').textContent =
            D.dateFrom === D.dateTo ? ('Showing ' + D.dateFrom) : ('Showing ' + D.dateFrom + ' – ' + D.dateTo);

        document.getElementById('kDone').textContent = fmt(D.sumDone);
        document.getElementById('kNg').textContent = fmt(D.sumNg);
        document.getElementById('kNgPct').textContent = pct(D.sumNg, D.sumDone).toFixed(2) + '% of completed';
        document.getElementById('kWipQ').textContent = fmt(D.sumWipQ);
        document.getElementById('kWipB').textContent = fmt(D.sumWipB) + ' batches · current';
        document.getElementById('kYield').textContent =
            (D.sumDone ? (100 - pct(D.sumNg, D.sumDone)) : 0).toFixed(2) + '%';
        document.getElementById('kLoss').textContent = 'Loss ' + fmt(D.sumLoss) + ' pcs';


        // =========================================================
        // Table
        // =========================================================

        var rows = D.rows || [];
        var maxVol = 1;
        rows.forEach(function (r) { maxVol = Math.max(maxVol, r.done + r.wipQ); });

        // ตัวเลขที่ไม่ใช่ 0 = คลิกเปิด Popup
        function link(kind, r, v) {
            if (!v) return fmt(v);
            return '<a class="dl" data-kind="' + kind + '" data-op="' + esc(r.op) + '" data-name="' +
                   esc(r.code + ' ' + r.name) + '">' + fmt(v) + '</a>';
        }

        // [NEW] ปุ่ม Completed / NG / WIP ทุกแถว ทุก Process
        function actBtns(r) {
            var name = esc(r.code ? (r.code + ' ' + r.name) : r.name);
            function b(kind, label, n) {
                return '<button type="button" class="ab ab-' + kind + (n ? '' : ' empty') + '" data-kind="' + kind +
                       '" data-op="' + esc(r.op) + '" data-name="' + name + '" title="' + label + ' details">' +
                       label + '</button>';
            }
            return '<div class="acts">' + b('done', 'Completed', r.done) + b('ng', 'NG', r.ng) + b('wip', 'WIP', r.wipB) + '</div>';
        }

        var html = '';

        rows.forEach(function (r) {
            var zero = !r.done && !r.ng && !r.wipQ;
            var wDone = (r.done - r.ng) / maxVol * 100;
            var wNg = r.ng / maxVol * 100;
            var wWip = r.wipQ / maxVol * 100;
            if (wDone < 0) wDone = 0;

            html += '<tr class="' + (zero ? 'zero' : '') + '">' +
                '<td class="code">' + esc(r.code) + '</td>' +
                '<td>' + esc(r.name) + '</td>' +
                '<td><span class="type' + (r.type === 'Subcontract' ? ' sub' : '') + '">' + esc(r.type) + '</span></td>' +
                '<td class="num">' + link('done', r, r.done) + '</td>' +
                '<td class="num">' + link('ng', r, r.ng) + '</td>' +
                '<td class="num">' + pctBadge(r.ng, r.done) + '</td>' +
                '<td class="num">' + fmt(r.loss) + '</td>' +
                '<td class="num">' + link('wip', r, r.wipB) + '</td>' +
                '<td class="num">' + link('wip', r, r.wipQ) + '</td>' +
                '<td class="bar-cell"><div class="bar" title="Completed ' + fmt(r.done) + ' · NG ' + fmt(r.ng) + ' · WIP ' + fmt(r.wipQ) + '">' +
                    '<div class="done" style="width:' + wDone + '%"></div>' +
                    '<div class="ng" style="left:' + wDone + '%;width:' + wNg + '%"></div>' +
                    '<div class="wip" style="left:' + (wDone + wNg) + '%;width:' + wWip + '%"></div>' +
                '</div></td>' +
                '<td class="act-col">' + actBtns(r) + '</td>' +
                '</tr>';
        });

        if (!rows.length) html = '<tr><td colspan="11" style="text-align:center;padding:40px;color:#94a3b8">No data found</td></tr>';

        document.getElementById('tbBody').innerHTML = html;

        document.getElementById('tbFoot').innerHTML =
            '<td colspan="3">Total</td>' +
            '<td class="num">' + fmt(D.sumDone) + '</td>' +
            '<td class="num">' + fmt(D.sumNg) + '</td>' +
            '<td class="num">' + pctBadge(D.sumNg, D.sumDone) + '</td>' +
            '<td class="num">' + fmt(D.sumLoss) + '</td>' +
            '<td class="num">' + fmt(D.sumWipB) + '</td>' +
            '<td class="num">' + fmt(D.sumWipQ) + '</td>' +
            '<td></td>' +
            '<td class="act-col">' + actBtns({ op: '', code: '', name: 'All Processes', done: D.sumDone, ng: D.sumNg, wipB: D.sumWipB }) + '</td>';


        // =========================================================
        // Export CSV (เปิดใน Excel ได้ ภาษาไทยไม่เพี้ยน)
        // =========================================================

        function downloadCsv(filename, header, data) {
            function cell(v) { return '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"'; }
            var lines = [header.map(cell).join(',')];
            data.forEach(function (row) { lines.push(row.map(cell).join(',')); });
            var blob = new Blob(['\ufeff' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
            var a = document.createElement('a');
            a.href = URL.createObjectURL(blob);
            a.download = filename;
            document.body.appendChild(a); a.click(); a.remove();
        }

        // ตารางหลัก : Output by Process
        document.getElementById('btnExportMain').addEventListener('click', function () {
            var header = ['Code', 'Process', 'Type', 'Completed', 'NG', 'NG %', 'Loss', 'WIP Batch', 'WIP Qty'];
            var data = (D.rows || []).map(function (r) {
                return [r.code, r.name, r.type, r.done, r.ng,
                        r.done ? (r.ng * 100 / r.done).toFixed(2) : '', r.loss, r.wipB, r.wipQ];
            });
            data.push(['Total', '', '', D.sumDone, D.sumNg,
                       D.sumDone ? (D.sumNg * 100 / D.sumDone).toFixed(2) : '', D.sumLoss, D.sumWipB, D.sumWipQ]);
            downloadCsv('ERP_Daily_Report_' + D.qFrom + '_' + D.qTo + '.csv', header, data);
        });


        // =========================================================
        // POPUP
        // =========================================================

        var MD = {
            back: document.getElementById('mdBack'),
            kind: '', rows: [], view: [], cols: [], sortKey: null, sortDir: 1
        };

        var COLS = {
            done: [
                { k: 't',       t: 'Check-Out', sort: 'tk' },
                { k: 'shift',   t: 'Shift Date' },
                { k: 'po',      t: 'PO' },
                { k: 'batch',   t: 'Batch' },
                { k: 'ball',    t: 'Ball Model' },
                { k: 'machine', t: 'Machine' },
                { k: 'line',    t: 'Line' },
                { k: 'inQty',   t: 'In', num: true },
                { k: 'outQty',  t: 'Out', num: true },
                { k: 'ng',      t: 'NG', num: true },
                { k: 'loss',    t: 'Loss', num: true },
                { k: 'qty',     t: 'Completed', num: true }
            ],
            ng: [
                { k: 't',       t: 'Check-Out', sort: 'tk' },
                { k: 'shift',   t: 'Shift Date' },
                { k: 'po',      t: 'PO' },
                { k: 'batch',   t: 'Batch' },
                { k: 'ball',    t: 'Ball Model' },
                { k: 'machine', t: 'Machine' },
                { k: 'inQty',   t: 'In', num: true },
                { k: 'outQty',  t: 'Out', num: true },
                { k: 'ng',      t: 'NG', num: true },
                { k: 'loss',    t: 'Loss', num: true },
                { k: 'qty',     t: 'Completed', num: true },
                { k: 'ngp',     t: 'NG %', num: true },
                { k: 'reasons', t: 'NG Reason', cls: 'reason' }
            ],
            wip: [
                { k: 't',       t: 'Check-In', sort: 'tk' },
                { k: 'wait',    t: 'Waiting', num: true },
                { k: 'po',      t: 'PO' },
                { k: 'batch',   t: 'Batch' },
                { k: 'ball',    t: 'Ball Model' },
                { k: 'opName',  t: 'Process' },
                { k: 'machine', t: 'Machine' },
                { k: 'line',    t: 'Line' },
                { k: 'qty',     t: 'Check-In Qty', num: true }
            ]
        };

        var LABEL = { done: 'COMPLETED', ng: 'NG', wip: 'WIP' };

        // ชื่อ Process จากรหัส (ใช้ในตาราง WIP)
        var OPNAME = {};
        (D.rows || []).forEach(function (r) { OPNAME[r.op] = r.code + ' ' + r.name; });

        function waitText(min) {
            var h = Math.floor(min / 60), d = Math.floor(h / 24);
            var txt = d >= 1 ? (d + 'd ' + (h % 24) + 'h') : (h + 'h ' + (min % 60) + 'm');
            var cls = h < 8 ? 'w-ok' : (h < 48 ? 'w-mid' : 'w-old');
            return '<span class="wait ' + cls + '">' + txt + '</span>';
        }

        function openModal(kind, op, name) {
            MD.kind = kind;
            MD.cols = COLS[kind];
            MD.sortKey = null; MD.sortDir = 1;

            var tag = document.getElementById('mdTag');
            tag.textContent = LABEL[kind];
            tag.className = 'tag ' + kind;

            document.getElementById('mdTitle').textContent = name || 'All Processes';
            document.getElementById('mdSub').textContent =
                kind === 'wip' ? 'Checked-in, not yet checked-out · current status'
                               : ('Shift date ' + (D.dateFrom === D.dateTo ? D.dateFrom : D.dateFrom + ' – ' + D.dateTo) + ' (08:00 → 08:00)');

            document.getElementById('mdSearch').value = '';
            document.getElementById('mdSum').innerHTML = '';
            document.getElementById('mdWarn').style.display = 'none';
            document.getElementById('mdHead').innerHTML = '';
            document.getElementById('mdBody').innerHTML = '<tr><td class="md-msg">Loading...</td></tr>';
            MD.back.classList.add('show');

            var url = D.detailUrl + '?kind=' + kind +
                      '&op=' + encodeURIComponent(op || '') +
                      '&from=' + D.qFrom + '&to=' + D.qTo + '&type=' + (D.type || 0) +
                      '&_=' + Date.now();

            fetch(url, { credentials: 'same-origin' })
                .then(function (res) { return res.json(); })
                .then(function (j) {
                    if (j.error) throw new Error(j.error);
                    MD.rows = (j.rows || []).map(function (r) {
                        r.ngp = r.qty ? (r.ng * 100 / r.qty) : 0;
                        r.opName = OPNAME[r.op] || r.op;
                        return r;
                    });
                    var w = document.getElementById('mdWarn');
                    if (j.truncated) {
                        w.textContent = 'Showing first ' + fmt(j.max) + ' rows only — please narrow the date range.';
                        w.style.display = 'block';
                    }
                    renderModal();
                })
                .catch(function (err) {
                    document.getElementById('mdBody').innerHTML =
                        '<tr><td class="md-msg">Cannot load data: ' + esc(err.message) + '</td></tr>';
                });
        }

        function closeModal() { MD.back.classList.remove('show'); }

        function renderModal() {
            var q = document.getElementById('mdSearch').value.trim().toLowerCase();

            MD.view = MD.rows.filter(function (r) {
                if (!q) return true;
                return [r.po, r.batch, r.ball, r.machine, r.line, r.reasons, r.opName]
                    .join(' ').toLowerCase().indexOf(q) >= 0;
            });

            if (MD.sortKey !== null) {
                var c = MD.cols[MD.sortKey], k = c.sort || c.k;
                MD.view.sort(function (a, b) {
                    var x = a[k], y = b[k];
                    if (c.num) return ((x || 0) - (y || 0)) * MD.sortDir;
                    return String(x || '').localeCompare(String(y || '')) * MD.sortDir;
                });
            }

            document.getElementById('mdHead').innerHTML = MD.cols.map(function (c, i) {
                var ar = MD.sortKey === i ? (MD.sortDir > 0 ? ' ▲' : ' ▼') : '';
                return '<th data-i="' + i + '" class="' + (c.num ? 'num' : '') + '">' + esc(c.t) + ar + '</th>';
            }).join('');

            if (!MD.view.length) {
                document.getElementById('mdBody').innerHTML =
                    '<tr><td class="md-msg" colspan="' + MD.cols.length + '">No data found</td></tr>';
            } else {
                var h = '';
                MD.view.forEach(function (r) {
                    h += '<tr>';
                    MD.cols.forEach(function (c) {
                        var v = r[c.k];
                        if (c.k === 'wait') v = waitText(v || 0);
                        else if (c.k === 'ngp') v = v ? v.toFixed(2) + '%' : '–';
                        else if (c.num) v = fmt(v);
                        else v = esc(v);
                        h += '<td class="' + (c.num ? 'num ' : '') + (c.cls || '') + '">' + v + '</td>';
                    });
                    h += '</tr>';
                });
                document.getElementById('mdBody').innerHTML = h;
            }

            // สรุป
            var batches = {}, qty = 0, ng = 0, qin = 0, qout = 0, loss = 0;
            MD.view.forEach(function (r) {
                batches[r.batch] = 1; qty += r.qty || 0; ng += r.ng || 0;
                qin += r.inQty || 0; qout += r.outQty || 0; loss += r.loss || 0;
            });
            var nb = Object.keys(batches).length;
            var sum = '<span><b>' + fmt(MD.view.length) + '</b> rows</span>' +
                      '<span><b>' + fmt(nb) + '</b> batches</span>';
            if (MD.kind === 'wip') sum += '<span><b>' + fmt(qty) + '</b> pcs in progress</span>';
            else sum += '<span>In <b>' + fmt(qin) + '</b></span><span>Out <b>' + fmt(qout) + '</b></span>' +
                        '<span>NG <b>' + fmt(ng) + '</b></span><span>Loss <b>' + fmt(loss) + '</b></span>' +
                        '<span>Completed <b>' + fmt(qty) + '</b></span>';
            document.getElementById('mdSum').innerHTML = sum;
        }

        function exportCsv() {
            var cols = MD.cols;
            var lines = [cols.map(function (c) { return c.t; }).join(',')];
            MD.view.forEach(function (r) {
                lines.push(cols.map(function (c) {
                    var v = r[c.k];
                    if (c.k === 'ngp') v = v ? v.toFixed(2) : '';
                    v = String(v == null ? '' : v).replace(/"/g, '""');
                    return '"' + v + '"';
                }).join(','));
            });
            var blob = new Blob(['\ufeff' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
            var a = document.createElement('a');
            a.href = URL.createObjectURL(blob);
            a.download = 'ERP_' + MD.kind + '_' + D.qFrom + '_' + D.qTo + '.csv';
            document.body.appendChild(a); a.click(); a.remove();
        }

        // เปิด Popup : การ์ด KPI + ตัวเลขในตาราง
        document.addEventListener('click', function (e) {
            var el = e.target.closest('[data-kind]');
            if (!el) return;
            e.preventDefault();
            openModal(el.getAttribute('data-kind'), el.getAttribute('data-op'), el.getAttribute('data-name'));
        });

        document.getElementById('mdClose').addEventListener('click', closeModal);
        MD.back.addEventListener('click', function (e) { if (e.target === MD.back) closeModal(); });
        document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeModal(); });
        document.getElementById('mdSearch').addEventListener('input', renderModal);
        document.getElementById('mdCsv').addEventListener('click', exportCsv);
        document.getElementById('mdHead').addEventListener('click', function (e) {
            var th = e.target.closest('th'); if (!th) return;
            var i = Number(th.getAttribute('data-i'));
            MD.sortDir = MD.sortKey === i ? -MD.sortDir : 1;
            MD.sortKey = i;
            renderModal();
        });


        // =========================================================
        // Auto Refresh ทุก 60 วินาที (หยุดนับขณะเลือกวันที่ / dropdown)
        // =========================================================

        var REFRESH_SEC = 60;
        var secLeft = REFRESH_SEC;
        var loadedAt = new Date().toLocaleTimeString('en-GB');

        function showCountdown() {
            document.getElementById('rfSec').textContent = secLeft;
            document.getElementById('rfTxt').textContent = 'Updated ' + loadedAt;
            document.getElementById('rfRing').style.setProperty('--p', (secLeft / REFRESH_SEC * 360) + 'deg');
        }

        function isBusy() {
            var a = document.activeElement;
            if (a && (a.tagName === 'SELECT' || (a.tagName === 'INPUT' && a.type === 'text'))) return true;
            if (MD.back.classList.contains('show')) return true;   // เปิด Popup อยู่
            return !!document.querySelector('.flatpickr-calendar.open');
        }

        // ข้ามวันกะ (08:00) : ถ้าช่วงที่ดูจบที่ "วันนี้" ตอนเปิดหน้า -> เลื่อนทั้งช่วงไปตามวันใหม่ก่อนรีเฟรช
        var loadToday = ymd(shiftToday());
        function setFp(el, v) { if (el._flatpickr) el._flatpickr.setDate(v, false); else el.value = v; }
        function rollDay() {
            var t = ymd(shiftToday());
            if (t === loadToday || txtTo.value !== loadToday) return;
            var n = Math.round((new Date(t + 'T00:00:00') - new Date(loadToday + 'T00:00:00')) / 864e5), f = new Date(txtFrom.value + 'T00:00:00');
            if (!isNaN(f)) { f.setDate(f.getDate() + n); setFp(txtFrom, ymd(f)); }
            setFp(txtTo, t);
        }
        document.getElementById('rf').addEventListener('click', function () { rollDay(); btnSearch.click(); });

        setInterval(function () {
            if (isBusy()) { secLeft = REFRESH_SEC; showCountdown(); return; }
            secLeft--;
            if (secLeft <= 0) { secLeft = 0; showCountdown(); rollDay(); btnSearch.click(); return; }
            showCountdown();
        }, 1000);

        showCountdown();

    })();
</script>

</asp:Content>
