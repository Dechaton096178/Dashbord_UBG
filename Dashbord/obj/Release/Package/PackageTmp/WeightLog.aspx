<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="WeightLog.aspx.cs" Inherits="Dashbord.WeightLog" Title="Weight Log" %>

<%-- =====================================================================
     Weight Log : scale weights (sent by Node-RED once per weighing, weight > 1.0 g)
     - API        : POST WeightLog.aspx  {"machine":"Extruder03","weight":40.12,"unit":"g","stable":true,"model":"Super Range","barcode":"S-Range","min":40,"max":40.3,"result":"OK"}
     - Data       : WeightLog.aspx?format=json&machine=Extruder03&day=yyyy-MM-dd  (production day 07:45-07:45)
     - Live       : WeightLog.aspx?format=live&machine=Extruder03  (live scale value, memory only, polled every 0.4 s)
     - Direct link: WeightLog.aspx?machine=Extruder03&day=2026-10-12
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<style>
    .wl { --bg:#eef2f8; --bg2:#e6ecf5; --card-bd:#e2e6f5; --ink:#0f172a; --ink2:#334155; --mute:#64748b; --line:#e5e9f0; --grid:#e9eef5;
          --accent:#4f46e5; --accent2:#0ea5e9; --sel:#eef2ff; --sel-bd:#6366f1; --chip:rgba(99,102,241,.06); --solid:#f9faff;
          --card:linear-gradient(135deg, #ffffff 0%, #f5f7ff 100%); --pt:#2a78d6; --avg:#f59e0b; --bar:#4b93e8; --ok:#16a34a; --warn:#d97706;
          --shadow:0 1px 2px rgba(15,23,42,.04), 0 6px 20px rgba(15,23,42,.06);
          padding:14px; background:linear-gradient(180deg, var(--bg), var(--bg2)); color:var(--ink); font-variant-numeric:tabular-nums; min-height:calc(100vh - 70px); box-sizing:border-box; }
    .wl.dark { --bg:#0a1122; --bg2:#050913; --card-bd:#1d2a47; --ink:#f1f5f9; --ink2:#cbd5e1; --mute:#8193b2; --line:#1d2a47; --grid:#18233c;
          --accent:#a5b4fc; --accent2:#38bdf8; --sel:rgba(99,102,241,.18); --sel-bd:#818cf8; --chip:rgba(129,140,248,.08); --solid:#121b33;
          --card:linear-gradient(135deg, rgba(30,41,82,.95) 0%, rgba(14,22,42,.95) 60%); --pt:#67a8f5; --avg:#fbbf24; --bar:#3987e5; --ok:#4ade80; --warn:#fbbf24;
          --shadow:0 10px 30px rgba(0,0,0,.45); }
    .wl * { box-sizing:border-box; }
    .wl-bar { display:flex; align-items:center; gap:8px; flex-wrap:wrap; margin-bottom:12px; }
    .wl-bar h2 { margin:0 6px 0 0; font-size:20px; font-weight:800; display:flex; align-items:center; gap:9px; }
    .wl-bar h2::before { content:""; width:10px; height:10px; border-radius:50%; background:#10b981; box-shadow:0 0 0 4px rgba(16,185,129,.18); }
    .wl-bar .sp { flex:1; }
    .wl-btn, .wl-in { font:inherit; font-size:13px; font-weight:700; color:var(--ink2); background:var(--solid); border:1px solid var(--card-bd); border-radius:9px; padding:6px 11px; cursor:pointer; line-height:1.2; }
    .wl-in { cursor:text; padding:5px 9px; color-scheme:light; } .wl.dark .wl-in { color-scheme:dark; }
    select.wl-in { cursor:pointer; }
    .wl-btn:hover { border-color:var(--sel-bd); color:var(--accent); }
    .wl-msg { font-size:12.5px; color:var(--mute); } .wl-msg.err { color:#ef4444; font-weight:700; }

    .wl-grid { display:grid; grid-template-columns:minmax(0, 1.1fr) minmax(0, 1.9fr); gap:12px; }
    .card { background:var(--card); border:1px solid var(--card-bd); border-radius:16px; box-shadow:var(--shadow); padding:14px 16px; min-width:0; position:relative; }
    .card h3 { margin:0 0 2px; font-size:15px; font-weight:800; display:flex; align-items:center; gap:8px; }
    .card h3::before { content:""; width:4px; height:16px; border-radius:4px; background:linear-gradient(180deg, var(--accent2), var(--accent)); }
    .card .sub { font-size:12px; color:var(--mute); padding-left:12px; }

    .hero { overflow:hidden; }
    .hero .tag { display:inline-block; font-size:12px; font-weight:800; color:var(--accent); border:1px solid var(--sel-bd); border-radius:999px; padding:1px 9px; background:var(--sel); }
    .hero .mc { font-size:30px; font-weight:800; margin-top:6px; letter-spacing:-.02em; }
    .hero .big { display:flex; align-items:baseline; gap:8px; margin-top:6px; }
    .hero .big b { font-size:64px; font-weight:800; letter-spacing:-.03em; line-height:1; }
    .hero .big span { font-size:24px; font-weight:700; color:var(--ink2); }
    .hero .when { font-size:13px; color:var(--mute); margin-top:4px; }
    .live { display:inline-flex; align-items:center; gap:6px; font-size:12px; font-weight:800; padding:2px 9px; border-radius:999px; margin-left:8px; vertical-align:middle; }
    .live.on { color:var(--ok); background:rgba(22,163,74,.1); } .live.off { color:var(--mute); background:var(--chip); }
    .kpis { display:grid; grid-template-columns:repeat(3, minmax(0, 1fr)); gap:8px; margin-top:14px; }
    .kpi { background:var(--chip); border:1px solid var(--card-bd); border-radius:11px; padding:7px 10px; min-width:0; }
    .kpi span { display:block; font-size:11px; font-weight:700; color:var(--mute); white-space:nowrap; }
    .kpi b { display:block; font-size:19px; font-weight:800; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .kpi b small { font-size:12px; color:var(--mute); margin-left:3px; }

    .plot { height:300px; margin-top:6px; } .plot.sm { height:190px; }
    .wl-btn.sm { font-size:12px; padding:4px 9px; } .seg { display:inline-flex; } .seg .wl-btn { border-radius:0; } .seg .wl-btn:first-child { border-radius:8px 0 0 8px; } .seg .wl-btn:last-child { border-radius:0 8px 8px 0; margin-left:-1px; }
    .wl-btn.on { background:var(--sel); border-color:var(--sel-bd); color:var(--accent); }
    #wCard.big { grid-column:1 / -1; } #wCard.big .plot { height:520px; }   /* ⤢ Expand : เต็มความกว้าง + สูงขึ้น */
    .plot svg { display:block; width:100%; height:100%; overflow:visible; }
    .gl { stroke:var(--grid); stroke-width:1; } .base { stroke:var(--line); stroke-width:1.2; }
    .ax { fill:var(--mute); font-size:11px; } .vl { fill:var(--ink2); font-size:11px; font-weight:800; }
    .empty { height:100%; display:flex; align-items:center; justify-content:center; color:var(--mute); font-size:14px; }

    .tblw { max-height:420px; overflow:auto; margin-top:8px; }
    .tbl { width:100%; border-collapse:collapse; }
    .tbl th { position:sticky; top:0; background:var(--solid); text-align:left; font-size:12px; color:var(--mute); font-weight:700; padding:6px 7px; border-bottom:1px solid var(--line); text-transform:uppercase; }
    .tbl td { font-size:14px; padding:6px 7px; border-bottom:1px solid var(--line); white-space:nowrap; }
    .tbl .r { text-align:right; } .tbl tr:nth-child(even) td { background:var(--chip); }
    .st { font-size:12px; font-weight:800; } .st.ok { color:var(--ok); } .st.us { color:var(--warn); }
    .res { display:inline-block; min-width:36px; text-align:center; font-size:12px; font-weight:800; padding:2px 8px; border-radius:999px; }
    .res.ok { color:#fff; background:var(--ok); } .res.ng { color:#fff; background:var(--ng); }
    .wl { --ng:#dc2626; } .wl.dark { --ng:#f87171; }
    .kpi b.ok { color:var(--ok); } .kpi b.ng { color:var(--ng); }
    .hero .model { font-size:15px; font-weight:800; color:var(--ink2); margin-top:4px; }
    .hero .model em { font-style:normal; color:var(--mute); font-weight:700; margin-left:6px; }
    .big b.ok { color:var(--ok); } .big b.ng { color:var(--ng); }
    .hero .big b { transition:color .2s; }
    .big b.run { color:var(--accent2); } .big b.idle { color:var(--mute); opacity:.55; }
    .live.rec { color:#fff; background:#10b981; } .live.rec.st-ok { background:var(--ok); } .live.rec.st-ng { background:var(--ng); } .live.rec.st-run { background:var(--accent2); }
    .pulse { animation:wlPulse 1s ease-in-out infinite; } @keyframes wlPulse { 50% { opacity:.45; } }
    .hero .when b { color:var(--ink2); }
    .mtbl td, .mtbl th { font-size:14px; }
    .bc { display:inline-block; font-family:Consolas, "Courier New", monospace; font-size:11.5px; font-weight:700; color:var(--ink2); background:var(--chip); border:1px solid var(--card-bd); border-radius:6px; padding:0 6px; margin-left:6px; vertical-align:1px; white-space:nowrap; }
    .mtbl .bc { margin-left:0; }
    .bcs { display:block; font-family:Consolas, "Courier New", monospace; font-size:11px; font-weight:700; color:var(--mute); line-height:1.1; }
    .tip { position:fixed; pointer-events:none; background:#0f172a; color:#f8fafc; font-size:12.5px; padding:7px 10px; border-radius:8px; box-shadow:0 8px 24px rgba(0,0,0,.25); display:none; z-index:40; }
    .full { grid-column:1 / -1; }
    /* ---- Weight Standard : บาร์โค้ดรุ่นให้พนักงานยิง (ตารางเดียวกับ Node-RED) ---- */
    .std { width:100%; border-collapse:collapse; margin-top:8px; }
    .std th { text-align:left; font-size:12px; color:var(--mute); font-weight:700; padding:6px 8px; border-bottom:1px solid var(--line); text-transform:uppercase; }
    .std td { padding:6px 8px; border-bottom:1px solid var(--line); font-size:14px; vertical-align:middle; }
    .std td.bcw { width:350px; } .std td.bcw svg { display:block; border-radius:6px; }   /* 2 px ต่อแท่งเล็กสุด -> ยิงจากจอได้ */
    .std td.rg { font-weight:800; white-space:nowrap; } .std td.no { color:var(--mute); width:36px; }
    .std tr.now td { background:var(--sel); } .std tr.now td.no { color:var(--accent); font-weight:800; }
    .std tr.now td.no::after { content:" ◀ now"; font-size:11px; }
    .std .nm { font-weight:800; } .std .bct { font-family:Consolas,monospace; font-size:12px; color:var(--mute); }


    /* ===================== โหมดทีวี (?tv=1 / ปุ่ม 📺) =====================
       ออกแบบที่ 1600×900 แล้วขยายทั้งหน้าด้วย zoom ให้เต็มจอ (ทีวี 4K = ×2.4) · เหลือเฉพาะ น้ำหนักสด / กราฟ / รายการล่าสุด / รายชั่วโมง */
    body.wl-tvmode { overflow:hidden; }
    body.wl-tvmode .site-header { display:none !important; }
    body.wl-tvmode form { margin:0 !important; padding:0 !important; max-width:none !important; }
    .wl.tv { height:900px; min-height:0; padding:10px 14px; display:flex; flex-direction:column; overflow:hidden; }
    .wl.tv .wl-bar { margin-bottom:8px; flex:none; }
    .wl.tv .wl-bar h2 { font-size:22px; }
    .wl.tv .tv-hide, .wl.tv #wlModel, .wl.tv #wlPrev, .wl.tv #wlNext, .wl.tv #wlDay, .wl.tv #wlToday, .wl.tv #wlCsv, .wl.tv #wzBig, .wl.tv .seg,
    .wl.tv .card.full, .wl.tv #stdCard, .wl.tv .card .sub { display:none !important; }
    .wl .tv-clock { display:none; }
    .wl.tv .tv-clock { display:inline; font-size:26px; font-weight:800; color:var(--ink); font-variant-numeric:tabular-nums; }
    .wl.tv .wl-msg { font-size:14px; }
    .wl.tv .wl-grid { flex:1; min-height:0; grid-template-columns:540px minmax(0, 1fr); grid-template-rows:minmax(0, 1fr) 300px; gap:10px; }
    .wl.tv .card { display:flex; flex-direction:column; min-height:0; padding:12px 16px; }
    .wl.tv .card h3 { font-size:19px; }
    .wl.tv .card h3::before { height:20px; }
    .wl.tv .plot { flex:1; height:auto; min-height:0; }
    .wl.tv .ax { font-size:14px; } .wl.tv .vl { font-size:14px; }
    .wl.tv .hero .tag { font-size:15px; padding:2px 12px; }
    .wl.tv .hero .mc { font-size:40px; margin-top:4px; }
    .wl.tv .live { font-size:16px; padding:3px 12px; }
    .wl.tv .hero .model { font-size:26px; margin-top:6px; line-height:1.25; }
    .wl.tv .hero .model em { display:block; margin:2px 0 0; font-size:22px; color:var(--ink2); }
    .wl.tv .hero .model .res { font-size:24px; padding:2px 14px; }
    .wl.tv .hero .big { margin-top:8px; }
    .wl.tv .hero .big b { font-size:150px; }
    .wl.tv .hero .big span { font-size:44px; }
    .wl.tv .hero .when { font-size:19px; margin-top:6px; }
    .wl.tv .kpis { margin-top:auto; gap:8px; }
    .wl.tv .kpi { padding:8px 12px; }
    .wl.tv .kpi span { font-size:15px; }
    .wl.tv .kpi b { font-size:30px; }
    .wl.tv .kpi b small { font-size:16px; }
    .wl.tv .tblw { flex:1; max-height:none; overflow:hidden; margin-top:6px; }
    .wl.tv .tbl th { font-size:14px; padding:5px 8px; }
    .wl.tv .tbl td { font-size:19px; padding:5px 8px; }
    .wl.tv .tbl .bcs { font-size:13px; }
    .wl.tv .tbl th:nth-child(4), .wl.tv .tbl td:nth-child(4) { display:none; }   /* Spec มีที่การ์ดซ้ายแล้ว */

    /* ---- จอน้ำหนัก : การ์ดพื้นดำแบบหน้าจอเครื่องชั่ง (ทั้งหน้าปกติและโหมดทีวี) ---- */
    .hero .big { background:#0b0f19; border:1px solid #1f2937; border-radius:14px; padding:10px 18px 12px; box-shadow:inset 0 2px 12px rgba(0,0,0,.6), 0 4px 14px rgba(15,23,42,.18); justify-content:flex-end; }
    .hero .big b { color:#e5e7eb; font-family:'Sarabun',Tahoma,sans-serif; font-variant-numeric:tabular-nums; text-shadow:0 0 18px rgba(255,255,255,.08); }
    .hero .big span { color:#9ca3af; }
    .hero .big b.idle { color:#64748b; opacity:1; }
    .hero .big b.run { color:#38bdf8; text-shadow:0 0 22px rgba(56,189,248,.35); }
    .hero .big b.ok { color:#22c55e; text-shadow:0 0 24px rgba(34,197,94,.4); }
    .hero .big b.ng { color:#f43f5e; text-shadow:0 0 24px rgba(244,63,94,.45); }
    .wl.tv .hero .big { padding:6px 22px 10px; border-radius:18px; }
    @media (max-width: 900px) { .wl-grid { grid-template-columns:1fr; } .hero .big b { font-size:48px; } .kpis { grid-template-columns:repeat(2, minmax(0, 1fr)); } }
</style>
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="wl" id="wlRoot">
    <div class="wl-bar">
        <h2>Weight Log</h2>
        <select class="wl-in" id="wlMc" title="Machine"></select>
        <select class="wl-in" id="wlModel" title="Model"><option value="">All models</option></select>
        <button type="button" class="wl-btn" id="wlPrev" title="Previous day">◀</button>
        <input type="date" class="wl-in" id="wlDay" />
        <button type="button" class="wl-btn" id="wlNext" title="Next day">▶</button>
        <button type="button" class="wl-btn" id="wlToday">Today</button>
        <span class="wl-msg" id="wlMsg">Loading...</span>
        <span class="sp"></span>
        <span class="tv-clock" id="tvClock"></span>
        <button type="button" class="wl-btn" id="wlTv" title="โหมดทีวี : เต็มจอ ตัวใหญ่ · ลิงก์ตรง ?tv=1 · Esc = ออก">📺 TV</button>
        <button type="button" class="wl-btn" id="wlCsv">⬇ CSV</button>
        <button type="button" class="wl-btn" id="wlTheme" title="Toggle theme">☾</button>
    </div>

    <div class="wl-grid">
        <div class="card hero">
            <span class="tag" id="wlTag">Production day</span>
            <div class="mc"><span id="wlMcName">–</span><span class="live off" id="wlLive">● No data</span></div>
            <div class="model" id="wlModelNow">&nbsp;</div>
            <div class="big"><b id="wlLast">–</b><span id="wlUnit"></span></div>
            <div class="when" id="wlWhen">&nbsp;</div>
            <div class="kpis">
                <div class="kpi"><span>Weighings</span><b id="kCnt">–</b></div>
                <div class="kpi"><span>OK / NG</span><b id="kOkNg">–</b></div>
                <div class="kpi"><span>Average</span><b id="kAvg">–</b></div>
                <div class="kpi"><span>Min</span><b id="kMin">–</b></div>
                <div class="kpi"><span>Max</span><b id="kMax">–</b></div>
                <div class="kpi"><span>Yield (OK %)</span><b id="kYield">–</b></div>
            </div>
        </div>

        <div class="card" id="wCard">
            <h3>Weight per Weighing
                <span class="seg" style="margin-left:auto">
                    <button type="button" class="wl-btn sm" id="wzFit" title="Zoom time axis to the weighings">Fit data</button><button type="button" class="wl-btn sm" id="wzDay" title="Show the whole production day">Full day</button>
                </span>
                <button type="button" class="wl-btn sm" id="wzBig" title="Make the chart full width and taller">⤢ Expand</button>
            </h3>
            <div class="sub" id="wSub">green = OK · red = NG · orange dashed line = average</div>
            <div class="plot" id="pW"></div>
        </div>

        <div class="card">
            <h3>Weighing Records</h3>
            <div class="sub" id="tSub">Newest first</div>
            <div class="tblw">
                <table class="tbl"><thead><tr><th>Time</th><th>Model</th><th class="r">Weight</th><th>Spec</th><th class="r" title="Weight outside spec: below Min = negative, above Max = positive, within spec = 0">Diff</th><th>Result</th></tr></thead><tbody id="tBody"></tbody></table>
            </div>
        </div>

        <div class="card">
            <h3>Weighings per Hour</h3>
            <div class="sub">Hover a bar for hourly total weight</div>
            <div class="plot sm" id="pH"></div>
        </div>
        <div class="card full">
            <h3>By Model</h3>
            <div class="sub">Production day summary per model · click a row to filter</div>
            <div class="tblw" style="max-height:none">
                <table class="tbl mtbl"><thead><tr><th>Model</th><th>Barcode</th><th>Spec (g)</th><th class="r">Weighings</th><th class="r">OK</th><th class="r">NG</th><th class="r">Yield</th><th class="r">Avg</th><th class="r">Min</th><th class="r">Max</th></tr></thead><tbody id="mBody"></tbody></table>
            </div>
        </div>
        <div class="card full" id="stdCard">
            <h3>Weight Standard — Model Barcodes <a class="wl-btn" href="files/Weight_Standard_Barcode.xlsx" download style="margin-left:auto;text-decoration:none" title="Weight Standard with barcode images (Excel)">⬇ Excel</a><button type="button" class="wl-btn" id="stdPrint">🖨 Print barcodes</button></h3>
            <div class="sub">Scan the model barcode into PRODUCTION NAME on the HMI before weighing · not scanned / unknown barcode = tower light off (Not ScanBarcode)</div>
            <div class="tblw" style="max-height:none"><table class="std"><thead><tr><th>No.</th><th>Barcode</th><th>Name</th><th>Mold size / Barwell</th><th>Mold size / Panstone</th><th>Weight setup / Panstone</th><th>Weight range</th></tr></thead><tbody id="stdBody"></tbody></table></div>
        </div>
    </div>
    <div class="tip" id="tip"></div>
</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script>
// @ts-nocheck
// ---- เวลาเริ่มวันผลิต (จาก CounterStore.DAY_START บน Server) · ช่องรายชั่วโมง 07:45–07:59 | 08:00–08:59 | ... | 07:00–07:44 ----
<%= Dashbord.CounterStore.JsDayStart %>
var DS_TXT = ('0' + DS_H).slice(-2) + ':' + ('0' + DS_M).slice(-2);
function slotLbl(i) { return i === 0 ? DS_TXT : ('0' + ((DS_H + i) % 24)).slice(-2) + ':00'; }
function slotOf(t0, t) {                                   // t0, t = ms · ช่องของเวลา t ในวันที่เริ่ม t0 (-1 = นอกวัน)
    var m = (t - t0) / 60000, f = DS_M ? 60 - DS_M : 0;
    if (m < 0 || m >= 1440) return -1;
    if (f && m < f) return 0;
    var i = Math.floor((m - f) / 60) + (f ? 1 : 0);
    return i < NSLOT ? i : -1;
}
function curSlot(t0, t) { return t >= t0 + 864e5 ? NSLOT - 1 : slotOf(t0, t); }
function tickLbl(h) { var m = DS_H * 60 + DS_M + h * 60; return ('0' + (Math.floor(m / 60) % 24)).slice(-2) + ':' + ('0' + (m % 60)).slice(-2); }
function beforeDs(d) { return d.getHours() * 60 + d.getMinutes() < DS_H * 60 + DS_M; }
function slotMin(i) { return DS_M && i === 0 ? 60 - DS_M : DS_M && i === NSLOT - 1 ? DS_M : 60; }   // ความยาวช่อง (นาที)
function slotHours(n) { var s = 0; for (var i = 0; i < n && i < NSLOT; i++) s += slotMin(i); return s / 60; }   // ชั่วโมงรวมของ n ช่องแรก
function slotRange(i) {                                     // เช่น 07:45–07:59 · 08:00–08:59 · 07:00–07:44
    var e = DS_M && i === 0 ? 59 : DS_M && i === NSLOT - 1 ? DS_M - 1 : 59, h = (DS_H + i) % 24;
    return slotLbl(i) + '–' + ('0' + h).slice(-2) + ':' + ('0' + e).slice(-2);
}
(function () {
    var $ = function (id) { return document.getElementById(id); };
    var qs = new URLSearchParams(location.search);
    function ls(k, v) { try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) { return null; } }
    function pad(n) { return (n < 10 ? '0' : '') + n; }
    function ymd(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
    function prodToday() { var d = new Date(); if (beforeDs(d)) d.setDate(d.getDate() - 1); return ymd(d); }
    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
    function fmt(v, dp) { return v == null || isNaN(v) ? '–' : Number(v).toLocaleString('en-US', { minimumFractionDigits: dp || 0, maximumFractionDigits: dp == null ? 3 : dp }); }
    function pt(s) { var a = s.split(/[- :]/); return new Date(+a[0], a[1] - 1, +a[2], +a[3], +a[4], +(a[5] || 0)); }

    var st = { mc: qs.get('machine') || ls('wl.mc') || '', day: qs.get('day') || prodToday(), model: qs.get('model') || '', data: null };
    var root = $('wlRoot');
    if (ls('wl.dark') === '1') root.classList.add('dark');
    $('wlTheme').onclick = function () { root.classList.toggle('dark'); ls('wl.dark', root.classList.contains('dark') ? '1' : '0'); };
    $('wlDay').value = st.day;
    function shift(n) { var d = pt(st.day + ' 00:00:00'); d.setDate(d.getDate() + n); st.day = ymd(d); $('wlDay').value = st.day; sync(); load(); }
    $('wlPrev').onclick = function () { shift(-1); };
    $('wlNext').onclick = function () { shift(1); };
    $('wlToday').onclick = function () { st.day = prodToday(); $('wlDay').value = st.day; sync(); load(); };
    $('wlDay').onchange = function () { if (this.value) { st.day = this.value; sync(); load(); } };
    $('wlMc').onchange = function () { st.mc = this.value; ls('wl.mc', st.mc); sync(); load(); };
    $('wlModel').onchange = function () { st.model = this.value; sync(); render(); };
    function sync() { var u = new URL(location.href); u.searchParams.set('machine', st.mc); u.searchParams.set('day', st.day); if (st.model) u.searchParams.set('model', st.model); else u.searchParams.delete('model'); history.replaceState(null, '', u); }
    function specTxt(r) { return r.mn != null && r.mx != null ? fmt(r.mn) + '–' + fmt(r.mx) : ''; }
    // ส่วนต่างจาก Spec: ต่ำกว่า Min = น้ำหนัก - Min (ติดลบ) · เกิน Max = น้ำหนัก - Max (บวก) · อยู่ในช่วง = 0
    function specDiff(r) { if (r.mn == null || r.mx == null) return null; return r.w < r.mn ? r.w - r.mn : r.w > r.mx ? r.w - r.mx : 0; }
    function diffHtml(r) {
        var d = specDiff(r); if (d == null) return '<span style="color:var(--mute)">–</span>';
        if (Math.abs(d) < 0.0005) return '<span style="color:var(--mute)">0</span>';
        return '<b style="color:var(--ng)" title="' + (d < 0 ? 'Under min ' : 'Over max ') + fmt(d < 0 ? r.mn : r.mx) + '">' + (d > 0 ? '+' : '−') + fmt(Math.abs(d)) + '</b>';
    }
    function bcHtml(b) { return b ? '<span class="bc" title="Barcode">' + esc(b) + '</span>' : ''; }
    function resHtml(r) { return r.r === 'OK' ? '<span class="res ok">OK</span>' : r.r === 'NG' ? '<span class="res ng">NG</span>' : ''; }

    // ---------- live scale value (follows the scale, then settles) ----------
    var live = null, liveWas = false, shown = null, tween = null, lastStable = false;
    function liveOn() { return !!(live && live.online && live.machine === st.mc && st.day === prodToday()); }
    function setBig(v) {
        var el = $('wlLast'), from = shown == null ? v : shown;
        if (tween) cancelAnimationFrame(tween);
        if (Math.abs(v - from) < 0.0005) { shown = v; el.textContent = v.toFixed(3); return; }
        var t0 = performance.now(), dur = 320;
        (function step(t) {
            var k = Math.min(1, (t - t0) / dur), e = 1 - Math.pow(1 - k, 3);
            shown = from + (v - from) * e; el.textContent = shown.toFixed(3);
            if (k < 1) tween = requestAnimationFrame(step); else { tween = null; shown = v; el.textContent = v.toFixed(3); }
        })(t0);
    }
    function paintLive() {
        var w = +live.weight || 0, g = String(live.unit || 'g').toLowerCase() === 'kg' ? w * 1000 : w, loaded = g > 1;
        var res = live.stable && loaded ? (live.result || (live.min != null && live.max != null ? (w >= live.min && w <= live.max ? 'OK' : 'NG') : '')) : '';
        setBig(loaded ? w : 0);
        $('wlLast').className = !loaded ? 'idle' : !live.stable ? 'run' : res === 'OK' ? 'ok' : res === 'NG' ? 'ng' : '';
        $('wlUnit').textContent = live.unit || 'g';
        var spec = live.min != null && live.max != null ? fmt(live.min) + '–' + fmt(live.max) : '';
        markStd(live.model ? live.barcode : '');
        $('wlModelNow').innerHTML = (live.model ? esc(live.model) + bcHtml(live.barcode) : 'Model not set — scan the model barcode') + (spec ? '<em>Spec ' + spec + ' ' + esc(live.unit || 'g') + '</em>' : '') + (res ? ' <span class="res ' + res.toLowerCase() + '">' + res + '</span>' : '');
        $('wlWhen').innerHTML = !loaded ? 'Scale ready — place a part on the scale' : !live.stable ? '<b class="pulse">Weighing…</b> waiting for the scale to settle' : '<b>Stable</b> · ' + (res === 'OK' ? 'within spec' : res === 'NG' ? (w < live.min ? 'under spec by ' + fmt(live.min - w) : 'over spec by ' + fmt(w - live.max)) + ' ' + esc(live.unit || 'g') : '');
        var b = $('wlLive');
        b.className = 'live rec ' + (!loaded ? '' : !live.stable ? 'st-run' : res === 'NG' ? 'st-ng' : 'st-ok');
        b.innerHTML = '<span class="pulse">●</span> LIVE' + (!loaded ? '' : !live.stable ? ' · WEIGHING' : ' · STABLE');
        // part removed after a stable reading -> reload records soon (new row is saved by Node-RED)
        if (lastStable && !loaded) setTimeout(load, 1200);
        lastStable = loaded && !!live.stable;
    }
    var liveBusy = false, liveTimer = null;
    function pollLive() {
        clearTimeout(liveTimer);
        var today = st.day === prodToday();
        if (!st.mc || !today || document.hidden || liveBusy) { liveTimer = setTimeout(pollLive, today ? 1000 : 5000); return; }
        liveBusy = true;
        fetch('WeightLog.aspx?format=live&machine=' + encodeURIComponent(st.mc) + '&_=' + Date.now(), { cache: 'no-store' })
            .then(function (r) { return r.json(); })
            .then(function (d) { live = d; })
            .catch(function () { live = null; })
            .then(function () {
                liveBusy = false;
                var on = liveOn();
                if (on) paintLive();
                else if (liveWas && st.data) { shown = null; render(); }   // live stopped -> back to last saved record
                liveWas = on;
                liveTimer = setTimeout(pollLive, on ? 400 : 3000);
            });
    }

    var loading = false;
    function load() {
        if (loading) return; loading = true;
        fetch('WeightLog.aspx?format=json&machine=' + encodeURIComponent(st.mc) + '&day=' + st.day + '&_=' + Date.now(), { cache: 'no-store' })
            .then(function (r) { return r.json(); })
            .then(function (d) {
                if (d.error) throw new Error(d.error);
                st.data = d; if (!st.mc && d.machine) st.mc = d.machine;
                $('wlMsg').className = 'wl-msg';
                $('wlMsg').textContent = 'Production day ' + d.dayStart.slice(5) + ' → ' + d.dayEnd.slice(5) + (st.day === prodToday() ? ' · auto-refresh every 10 s' : '');
                render();
            })
            .catch(function (e) { $('wlMsg').className = 'wl-msg err'; $('wlMsg').textContent = 'Failed to load data: ' + e.message; })
            .then(function () { loading = false; });
    }

    function render() {
        var d = st.data, all = d.rows || [];
        // ตัวกรองรุ่น
        var models = []; all.forEach(function (r) { var m = r.m || '(no model)'; if (models.indexOf(m) < 0) models.push(m); });
        if (st.model && models.indexOf(st.model) < 0) models.push(st.model);
        $('wlModel').innerHTML = '<option value="">All models</option>' + models.map(function (m) { return '<option' + (m === st.model ? ' selected' : '') + '>' + esc(m) + '</option>'; }).join('');
        var rows = st.model ? all.filter(function (r) { return (r.m || '(no model)') === st.model; }) : all;
        var sel = $('wlMc'), ms = (d.machines || []).slice();
        if (st.mc && ms.indexOf(st.mc) < 0) ms.unshift(st.mc);
        sel.innerHTML = ms.length ? ms.map(function (m) { return '<option' + (m === st.mc ? ' selected' : '') + '>' + esc(m) + '</option>'; }).join('') : '<option value="">(no machine has sent data yet)</option>';
        $('wlMcName').textContent = st.mc || '–';
        $('wlTag').textContent = 'Production day ' + st.day.split('-').reverse().join('/');
        var unit = rows.length ? (rows[rows.length - 1].u || '') : '';
        var ws = rows.map(function (r) { return r.w; });
        var sum = ws.reduce(function (a, b) { return a + b; }, 0), n = ws.length;
        var last = rows[n - 1];
        var liveNow = liveOn();
        if (!liveNow) { shown = null; $('wlLast').textContent = last ? fmt(last.w) : '–'; }
        if (!liveNow) $('wlLast').className = last && last.r === 'OK' ? 'ok' : last && last.r === 'NG' ? 'ng' : '';
        if (!liveNow) $('wlModelNow').innerHTML = last && last.m ? esc(last.m) + bcHtml(last.b) + (specTxt(last) ? '<em>Spec ' + specTxt(last) + ' ' + esc(last.u) + '</em>' : '') + ' ' + resHtml(last) : '&nbsp;';
        if (!liveNow) $('wlUnit').textContent = unit;
        var live = $('wlLive');
        if (liveNow) paintLive();
        else if (last) {
            var ago = Math.max(0, Math.round((pt(d.now) - pt(last.t)) / 1000));
            $('wlWhen').textContent = 'Last weighed ' + last.t.slice(11) + ' · ' + (ago < 60 ? ago + ' s ago' : ago < 3600 ? Math.round(ago / 60) + ' min ago' : Math.round(ago / 3600) + ' h ago');
            var on = ago < 600 && st.day === prodToday();
            live.className = 'live ' + (on ? 'on' : 'off'); live.textContent = on ? '● Active' : '● Idle';
        } else { $('wlWhen').innerHTML = 'No weighings this day yet'; live.className = 'live off'; live.textContent = '● No data'; }
        var u = unit ? '<small>' + esc(unit) + '</small>' : '';
        $('kCnt').innerHTML = fmt(n, 0) + '<small>times</small>';
        var nOk = rows.filter(function (r) { return r.r === 'OK'; }).length, nNg = rows.filter(function (r) { return r.r === 'NG'; }).length;
        $('kOkNg').innerHTML = n ? '<i style="font-style:normal;color:var(--ok)">' + fmt(nOk, 0) + '</i> / <i style="font-style:normal;color:var(--ng)">' + fmt(nNg, 0) + '</i>' : '–';
        $('kAvg').innerHTML = n ? fmt(sum / n) + u : '–';
        $('kMin').innerHTML = n ? fmt(Math.min.apply(null, ws)) + u : '–';
        $('kMax').innerHTML = n ? fmt(Math.max.apply(null, ws)) + u : '–';
        $('kYield').innerHTML = nOk + nNg ? (Math.floor(nOk / (nOk + nNg) * 1000 + 1e-7) / 10).toFixed(1) + '<small>%</small>' : '–';   // ปัดลง: มี NG จะไม่โชว์ 100%

        var show = rows.slice(tvOn ? -12 : -500).reverse(), html = '';
        show.forEach(function (r, i) {
            html += '<tr><td>' + r.t.slice(11) + '</td><td>' + esc(r.m) + (r.b ? '<small class="bcs">' + esc(r.b) + '</small>' : '') + '</td><td class="r"><b>' + fmt(r.w) + '</b> ' + esc(r.u) + '</td><td>' + specTxt(r) + '</td><td class="r">' + diffHtml(r) + '</td><td>' + resHtml(r) + '</td></tr>';
        });
        $('tBody').innerHTML = html || '<tr><td colspan="6" style="color:var(--mute)">No data</td></tr>';
        $('tSub').textContent = n > 500 ? 'Showing latest 500 of ' + fmt(n, 0) + ' (download CSV for all)' : 'Newest first';
        drawModels(all);
        drawW(rows, unit, n ? sum / n : null);
        drawH(rows, unit);
    }

    // ---------- สรุปตามรุ่น ----------
    function drawModels(all) {
        var g = {};
        all.forEach(function (r) {
            var m = r.m || '(no model)', x = g[m] || (g[m] = { n: 0, ok: 0, ng: 0, sum: 0, min: 1e9, max: -1e9, spec: '', bc: '' });
            x.n++; x.sum += r.w; if (r.w < x.min) x.min = r.w; if (r.w > x.max) x.max = r.w;
            if (r.r === 'OK') x.ok++; else if (r.r === 'NG') x.ng++;
            if (specTxt(r)) x.spec = specTxt(r);
            if (r.b) x.bc = r.b;
        });
        var keys = Object.keys(g).sort(function (a, b) { return g[b].n - g[a].n; }), html = '';
        keys.forEach(function (m) {
            var x = g[m], y = x.ok + x.ng ? Math.floor(x.ok / (x.ok + x.ng) * 1000 + 1e-7) / 10 : null;
            html += '<tr data-m="' + esc(m) + '" style="cursor:pointer' + (m === st.model ? ';outline:2px solid var(--sel-bd)' : '') + '"><td><b>' + esc(m) + '</b></td><td>' + bcHtml(x.bc) + '</td><td>' + x.spec + '</td><td class="r">' + fmt(x.n, 0) +
                '</td><td class="r" style="color:var(--ok)">' + fmt(x.ok, 0) + '</td><td class="r" style="color:var(--ng)">' + fmt(x.ng, 0) + '</td><td class="r"><b>' + (y == null ? '–' : fmt(y, 1) + '%') +
                '</b></td><td class="r">' + fmt(x.sum / x.n) + '</td><td class="r">' + fmt(x.min) + '</td><td class="r">' + fmt(x.max) + '</td></tr>';
        });
        $('mBody').innerHTML = html || '<tr><td colspan="10" style="color:var(--mute)">No data</td></tr>';
        $('mBody').querySelectorAll('tr[data-m]').forEach(function (tr) {
            tr.onclick = function () { var m = tr.getAttribute('data-m'); st.model = st.model === m ? '' : m; sync(); render(); };
        });
    }

    // ---------- charts ----------
    var tip = $('tip');
    function showTip(h, ev) { tip.innerHTML = h; tip.style.display = 'block'; var x = ev.clientX + 14, y = ev.clientY + 14; if (x + tip.offsetWidth > innerWidth - 8) x = ev.clientX - tip.offsetWidth - 14; if (y + tip.offsetHeight > innerHeight - 8) y = ev.clientY - tip.offsetHeight - 14; tip.style.left = x + 'px'; tip.style.top = y + 'px'; }
    function hideTip() { tip.style.display = 'none'; }
    function niceStep(v) { if (v <= 0) return 1; var p = Math.pow(10, Math.floor(Math.log10(v))), k = v / p; return (k <= 1 ? 1 : k <= 2 ? 2 : k <= 2.5 ? 2.5 : k <= 5 ? 5 : 10) * p; }
    function fk(v) { return Math.abs(v) >= 100000 ? Math.round(v / 1000) + 'K' : Number(v).toLocaleString('en-US', { maximumFractionDigits: 2 }); }

    function drawW(rows, unit, avg) {
        var box = $('pW'), W = box.clientWidth, H = box.clientHeight;
        if (!rows.length) { box.innerHTML = '<div class="empty">No weighings yet</div>'; return; }
        var L = 52, R = 10, T = 12, B = 26, t0 = pt(st.day + ' ' + DS_TXT + ':00').getTime(), span = 86400000, dayT0 = t0;
        var fit = st.zoom !== 'day';
        if (fit) {   // Fit data : แกนเวลาเริ่มที่ชั่งครั้งแรก ถึงครั้งล่าสุด (อย่างน้อย 10 นาที) -> จุดไม่อัดกันทางซ้าย
            var ta = pt(rows[0].t).getTime(), tb = pt(rows[rows.length - 1].t).getTime();
            if (tb - ta < 600000) { var mid = (ta + tb) / 2; ta = mid - 300000; tb = mid + 300000; }
            var padT = (tb - ta) * 0.03; t0 = Math.max(dayT0, ta - padT); span = Math.min(dayT0 + 86400000, tb + padT) - t0;
        }
        // แกนน้ำหนัก : ใช้ช่วง 3–97% ของค่าที่ชั่ง (ค่าหลุดมาก ๆ ไม่ทำให้กราฟแบนจนมองไม่เห็นแถบ Spec) · ค่าที่เกินแกนวาดเป็น ▲ / ▼ ที่ขอบ
        var ws = rows.map(function (r) { return r.w; }).sort(function (a, b) { return a - b; });
        var q = function (p) { return ws[Math.min(ws.length - 1, Math.max(0, Math.round((ws.length - 1) * p)))]; };
        var lo = ws.length >= 20 ? q(0.03) : ws[0], hi = ws.length >= 20 ? q(0.97) : ws[ws.length - 1];
        // แถบ Spec ตามช่วงเวลา : แถวติดกันที่ Spec เดียวกัน = 1 ช่วง (เปลี่ยนรุ่น / แก้ Spec กลางวัน ก็ยังเห็นขอบ Spec ของแต่ละช่วง)
        var bands = [];
        rows.forEach(function (r, i) {
            var k = r.mn != null && r.mx != null ? r.mn + '|' + r.mx : '', b = bands[bands.length - 1];
            if (b && b.k === k) b.j = i; else bands.push({ k: k, i: i, j: i, mn: r.mn, mx: r.mx });
        });
        bands = bands.filter(function (b) { return b.k; });
        bands.forEach(function (b) { lo = Math.min(lo, b.mn); hi = Math.max(hi, b.mx); });
        var pad0 = (hi - lo) * 0.2 || hi * 0.01 || 1; lo = Math.max(0, lo - pad0); hi = hi + pad0;
        var step = niceStep((hi - lo) / 4); lo = Math.floor(lo / step) * step; hi = Math.ceil(hi / step) * step;
        var X = function (t) { return L + (W - L - R) * (pt(t).getTime() - t0) / span; }, Y = function (v) { return H - B - (H - B - T) * (v - lo) / (hi - lo); }, Yc = function (v) { return Math.max(T, Math.min(H - B, Y(v))); };
        var s = '<svg viewBox="0 0 ' + W + ' ' + H + '">';
        for (var v = lo; v <= hi + step / 2; v += step) s += '<line class="' + (v === lo ? 'base' : 'gl') + '" x1="' + L + '" x2="' + (W - R) + '" y1="' + Y(v) + '" y2="' + Y(v) + '"/><text class="ax" x="' + (L - 6) + '" y="' + (Y(v) + 4) + '" text-anchor="end">' + fk(v) + '</text>';
        if (!fit) for (var h = 0, hs = W < 520 ? 6 : W < 900 ? 4 : 2; h <= 24; h += hs) { var x = L + (W - L - R) * h / 24; s += '<text class="ax" x="' + x + '" y="' + (H - 8) + '" text-anchor="middle">' + tickLbl(h) + '</text>'; }
        else {   // ขีดเวลาแบบปัดตัวเลขสวย (1, 2, 5, 10, 15, 30 นาที ... ) ราว 1 ขีดต่อ 90 px
            var want = Math.max(2, Math.floor((W - L - R) / 90)), stepM = [1, 2, 5, 10, 15, 20, 30, 60, 120, 180, 240].filter(function (m) { return span / 60000 / m <= want; })[0] || 240;
            var tz = new Date(t0); tz.setSeconds(0, 0); tz.setMinutes(Math.ceil(tz.getMinutes() / stepM) * stepM);
            for (var tk = tz.getTime(); tk <= t0 + span; tk += stepM * 60000) {
                var xx = L + (W - L - R) * (tk - t0) / span, dk = new Date(tk);
                s += '<line class="gl" x1="' + xx + '" x2="' + xx + '" y1="' + T + '" y2="' + (H - B) + '" stroke-opacity=".5"/><text class="ax" x="' + xx + '" y="' + (H - 8) + '" text-anchor="middle">' + pad(dk.getHours()) + ':' + pad(dk.getMinutes()) + '</text>';
            }
        }
        var xc = function (x) { return Math.max(L, Math.min(W - R, x)); }, lastLbl = null;
        bands.forEach(function (b, n) {
            // เริ่มที่จุดแรกของช่วง (ช่วงแรกเริ่มจากขอบซ้าย) ถึงจุดแรกของช่วงถัดไป (ช่วงสุดท้ายถึงขอบขวา)
            var nxt = n + 1 < bands.length ? bands[n + 1] : null;
            var x1 = n === 0 ? L : xc(X(rows[b.i].t)), x2 = nxt ? xc(X(rows[nxt.i].t)) : W - R;
            if (b.j + 1 < rows.length && nxt && nxt.i > b.j + 1) x2 = xc(X(rows[b.j].t) + 2);   // ตามด้วยแถวไม่มี Spec -> จบที่จุดสุดท้ายของช่วง
            if (x2 - x1 < 2) x2 = x1 + 2;
            s += '<rect x="' + x1.toFixed(1) + '" y="' + Y(b.mx) + '" width="' + (x2 - x1).toFixed(1) + '" height="' + Math.max(1.5, Y(b.mn) - Y(b.mx)) + '" fill="var(--ok)" fill-opacity=".13" stroke="var(--ok)" stroke-opacity=".7" stroke-width="1.2" stroke-dasharray="4 3"/>';
            if (b.k !== lastLbl && x2 - x1 > 70) s += '<text class="ax" x="' + (x2 - 4) + '" y="' + (Y(b.mx) - 4) + '" text-anchor="end" style="fill:var(--ok);font-weight:700">Spec ' + fmt(b.mn) + '–' + fmt(b.mx) + '</text>';
            lastLbl = b.k;
        });
        if (avg != null) s += '<line x1="' + L + '" x2="' + (W - R) + '" y1="' + Y(avg) + '" y2="' + Y(avg) + '" stroke="var(--avg)" stroke-width="1.6" stroke-dasharray="6 4"/>';
        if (rows.length > 1 && rows.length < 3000) s += '<polyline fill="none" stroke="var(--pt)" stroke-opacity=".35" stroke-width="1.2" points="' + rows.map(function (r) { return X(r.t).toFixed(1) + ',' + Yc(r.w).toFixed(1); }).join(' ') + '"/>';
        var rad = rows.length > 800 ? 2 : st.big ? 5 : 4;
        var off = 0;
        rows.forEach(function (r, i) {
            var col = r.r === 'OK' ? 'var(--ok)' : r.r === 'NG' ? 'var(--ng)' : 'var(--pt)', x = X(r.t), k = rad + 1.5;
            if (r.w > hi) { off++; s += '<path d="M' + (x - k) + ',' + (T + k * 1.6) + 'L' + x + ',' + T + 'L' + (x + k) + ',' + (T + k * 1.6) + 'Z" fill="' + col + '"/>'; }
            else if (r.w < lo) { off++; s += '<path d="M' + (x - k) + ',' + (H - B - k * 1.6) + 'L' + x + ',' + (H - B) + 'L' + (x + k) + ',' + (H - B - k * 1.6) + 'Z" fill="' + col + '"/>'; }
            else s += '<circle data-i="' + i + '" cx="' + x.toFixed(1) + '" cy="' + Y(r.w).toFixed(1) + '" r="' + rad + '" fill="' + col + '"/>';
        });
        if (off) s += '<text class="ax" x="' + (L + 6) + '" y="' + (T + 12) + '" style="font-weight:700">▲▼ ' + off + ' off scale (hover for value)</text>';
        box.innerHTML = s + '</svg>';
        var svg = box.querySelector('svg');
        svg.onmousemove = function (ev) {
            var bb = svg.getBoundingClientRect(), mx = ev.clientX - bb.left, best = -1, bd = 1e9;
            rows.forEach(function (r, i) { var dx = Math.abs(X(r.t) - mx); if (dx < bd) { bd = dx; best = i; } });
            if (best < 0 || bd > 30) return hideTip();
            var r = rows[best]; showTip('<b>#' + (best + 1) + '</b> · ' + r.t.slice(11) + (r.m ? ' · ' + esc(r.m) : '') + '<br>Weight <b>' + fmt(r.w) + ' ' + esc(unit) + '</b> ' + (r.r ? '<b style="color:' + (r.r === 'OK' ? '#4ade80' : '#f87171') + '">' + r.r + '</b>' : '') + (specTxt(r) ? '<br>Spec ' + specTxt(r) : '') + (avg ? '<br><span style="color:#94a3b8">vs avg ' + (r.w >= avg ? '+' : '') + fmt(r.w - avg) + '</span>' : ''), ev);
        };
        svg.onmouseleave = hideTip;
    }

    function drawH(rows, unit) {
        var box = $('pH'), W = box.clientWidth, H = box.clientHeight;
        var cnt = new Array(NSLOT).fill(0), sm = new Array(NSLOT).fill(0), t0 = pt(st.day + ' ' + DS_TXT + ':00').getTime();
        rows.forEach(function (r) { var k = slotOf(t0, pt(r.t).getTime()); if (k >= 0) { cnt[k]++; sm[k] += r.w; } });
        var mx = Math.max.apply(null, cnt);
        if (!mx) { box.innerHTML = '<div class="empty">No weighings yet</div>'; return; }
        var L = 34, R = 6, T = 16, B = 22, step = niceStep(mx / 3), top = Math.ceil(mx / step) * step, slot = (W - L - R) / NSLOT, bw = Math.max(3, slot * 0.66);
        var Y = function (v) { return H - B - (H - B - T) * v / top; };
        var s = '<svg viewBox="0 0 ' + W + ' ' + H + '">';
        for (var v = 0; v <= top; v += step) s += '<line class="' + (v ? 'gl' : 'base') + '" x1="' + L + '" x2="' + (W - R) + '" y1="' + Y(v) + '" y2="' + Y(v) + '"/><text class="ax" x="' + (L - 5) + '" y="' + (Y(v) + 4) + '" text-anchor="end">' + v + '</text>';
        cnt.forEach(function (c, k) {
            var x = L + slot * k + (slot - bw) / 2;
            if (c) { s += '<rect x="' + x + '" y="' + Y(c) + '" width="' + bw + '" height="' + (H - B - Y(c)) + '" rx="3" fill="var(--bar)"/>'; if (slot > 22) s += '<text class="vl" x="' + (x + bw / 2) + '" y="' + (Y(c) - 4) + '" text-anchor="middle">' + c + '</text>'; }
            if (k % (slot > 30 ? 1 : 2) === 0) s += '<text class="ax" x="' + (L + slot * k + slot / 2) + '" y="' + (H - 6) + '" text-anchor="middle">' + (k === 0 && DS_M ? slotLbl(0) : pad((DS_H + k) % 24)) + '</text>';
            s += '<rect class="hb" data-k="' + k + '" x="' + (L + slot * k) + '" y="' + T + '" width="' + slot + '" height="' + (H - B - T) + '" fill="transparent"/>';
        });
        box.innerHTML = s + '</svg>';
        box.querySelectorAll('.hb').forEach(function (el) {
            var k = +el.getAttribute('data-k');
            el.onmousemove = function (ev) { showTip('<b>' + slotRange(k) + '</b><br><b>' + cnt[k] + '</b> weighings' + (cnt[k] ? '<br>Total ' + fmt(sm[k]) + ' ' + esc(unit) + ' · avg ' + fmt(sm[k] / cnt[k]) : ''), ev); };
            el.onmouseleave = hideTip;
        });
    }

    // ---------- Weight Standard (ตารางเดียวกับ SPECS ใน Node-RED "ตัดสิน OK / NG" · แก้ค่าต้องแก้ทั้ง 2 ที่) ----------
    //   [No, บาร์โค้ด, ชื่อรุ่น, Mold Barwell, Mold Panstone, Weight setup, Min g, Max g] · จาก Weight_Standard_Barcode.xlsx (2026-10-28)
    var STD = [
        [1, 'S-Range',   'Super Range',    '16mm/280',     '15-16mm/190', '40.3', 40,    40.3],
        [2, 'C-Practi',  'CG Practice',    '16mm/280',     '15-16mm/190', '40.3', 40,    40.3],
        [3, 'P-Practi',  'Pro Practice',   '15mm/190-200', '15-16mm/150', '36.3', 36,    36.3],
        [4, 'L-Fling',   'LTD Flight',     '18mm/280',     '17.5mm/155',  '39.2', 38.8,  39.2],
        [5, 'S-Soft',    'SUPER SOFT2027', '14mm/190-200', '12-13mm/130', '',     41.1,  41.4],
        [6, 'W-BIRD',    'WAR BIRD',       '16mm/190-200', '15-16mm/130', '40.3', 40.5,  40.5],
        [7, 'HE-DIABLO', 'HEX DIABLO',     '14mm/190-200', '13-14mm/130', '42.2', 41.8,  42.2],
        [8, 'S-FAST',    'SUPER FAST',     '14mm/190-200', '12-13mm/130', '41.3', 41.1,  41.3],
        [9, 'S-SO25',    'SUPER SOFT2025', '14mm/190-200', '12-13mm/130', '',     41.35, 41.5]
    ];
    // Code 128 (B) วาดเป็น SVG ไม่ต้องใช้ไลบรารี
    var C128 = '212222,222122,222221,121223,121322,131222,122213,122312,132212,221213,221312,231212,112232,122132,122231,113222,123122,123221,223211,221132,221231,213212,223112,312131,311222,321122,321221,312212,322112,322211,212123,212321,232121,111323,131123,131321,112313,132113,132311,211313,231113,231311,112133,112331,132131,113123,113321,133121,313121,211331,231131,213113,213311,213131,311123,311321,331121,312113,312311,332111,314111,221411,431111,111224,111422,121124,121421,141122,141221,112214,112412,122114,122411,142112,142211,241211,221114,413111,241112,134111,111242,121142,121241,114212,124112,124211,411212,421112,421211,212141,214121,412121,111143,111341,131141,114113,114311,411113,411311,113141,114131,311141,411131,211412,211214,211232,2331112'.split(',');
    function bcSvg(text, h) {
        h = h || 60;
        var v = [104], i; for (i = 0; i < text.length; i++) { var c = text.charCodeAt(i); v.push(c < 32 || c > 126 ? 31 : c - 32); }
        var sum = v[0]; for (i = 1; i < v.length; i++) sum += v[i] * i; v.push(sum % 103); v.push(106);
        var x = 10, r = '';
        v.forEach(function (k) { var p = C128[k]; for (var j = 0; j < p.length; j++) { var wd = +p[j]; if (j % 2 === 0) r += '<rect x="' + x + '" y="4" width="' + wd + '" height="' + h + '"/>'; x += wd; } });
        var W = x + 10;
        return '<svg xmlns="http://www.w3.org/2000/svg" width="' + (W * 2) + '" height="' + ((h + 16) * 2) + '" viewBox="0 0 ' + W + ' ' + (h + 16) + '" shape-rendering="crispEdges"><rect width="100%" height="100%" fill="#fff"/><g fill="#000">' + r + '</g>' +
               '<text x="' + (W / 2) + '" y="' + (h + 13) + '" text-anchor="middle" font-family="Consolas,monospace" font-size="9" font-weight="700" fill="#000">' + esc(text) + '</text></svg>';
    }
    function stdKey(t) { return String(t || '').toUpperCase().replace(/\s+/g, ''); }
    function stdRange(s) { return fmt(s[6]) + '–' + fmt(s[7]) + ' g'; }
    function renderStd() {
        $('stdBody').innerHTML = STD.map(function (s) {
            return '<tr data-bc="' + esc(stdKey(s[1])) + '"><td class="no">' + s[0] + '</td><td class="bcw">' + bcSvg(s[1], 26) + '</td><td><span class="nm">' + esc(s[2]) + '</span></td>' +
                   '<td>' + esc(s[3]) + '</td><td>' + esc(s[4]) + '</td><td>' + esc(s[5] || '–') + '</td><td class="rg">' + stdRange(s) + '</td></tr>';
        }).join('');
    }
    function markStd(bc) {   // ไฮไลต์รุ่นที่ยิงอยู่ตอนนี้ (HMI ตัดเหลือ 8 ตัว -> เทียบแบบขึ้นต้นด้วย)
        var k = stdKey(bc);
        Array.prototype.forEach.call(document.querySelectorAll('#stdBody tr'), function (tr) { var b = tr.getAttribute('data-bc'); tr.classList.toggle('now', !!k && (b === k || b.indexOf(k) === 0 || k.indexOf(b) === 0)); });
    }
    $('stdPrint').onclick = function () {   // พิมพ์ A4 : บาร์โค้ดใหญ่ 1 รุ่นต่อแถว ตัดแปะหน้าเครื่องได้
        var w = window.open('', '_blank'); if (!w) return;
        var rows = STD.map(function (s) {
            return '<tr><td class="no">' + s[0] + '</td><td class="bc">' + bcSvg(s[1], 36) + '</td><td><b>' + esc(s[2]) + '</b><br><span>' + esc(s[3]) + ' · ' + esc(s[4]) + '</span></td><td class="rg">' + stdRange(s) + (s[5] ? '<br><span>setup ' + esc(s[5]) + '</span>' : '') + '</td></tr>';
        }).join('');
        w.document.write('<!doctype html><html><head><meta charset="utf-8"><title>Weight Standard Barcodes</title><style>' +
            '@page{size:A4;margin:10mm} body{font-family:Segoe UI,Tahoma,sans-serif;color:#000;margin:0} h1{font-size:18px;margin:0 0 2px} p{margin:0 0 8px;font-size:12px;color:#444}' +
            'table{width:100%;border-collapse:collapse} td{border:1px solid #999;padding:6px 8px;font-size:15px;vertical-align:middle} td.no{width:28px;text-align:center;font-weight:700}' +
            'td.bc{width:300px} td.bc svg{display:block;width:290px;height:auto} td.rg{font-size:20px;font-weight:800;white-space:nowrap} span{font-size:12px;color:#444;font-weight:400} tr{page-break-inside:avoid}' +
            '</style></head><body><h1>UNIVERSAL BASE GOLF BALL — Weight Standard / มาตรฐานน้ำหนัก</h1><p>Scan the model barcode into PRODUCTION NAME on the HMI before weighing · printed ' + new Date().toLocaleString() + '</p>' +
            '<table>' + rows + '</table><script>setTimeout(function(){print()},300)<\/script></body></html>');
        w.document.close();
    };
    renderStd();
    // ---------- ซูมกราฟน้ำหนัก : Fit data / Full day · ⤢ Expand (จำค่าไว้ในเบราว์เซอร์) ----------
    st.zoom = ls('wl.zoom') === 'day' ? 'day' : 'fit'; st.big = ls('wl.big') === '1';
    function zoomUi() {
        $('wzFit').classList.toggle('on', st.zoom !== 'day'); $('wzDay').classList.toggle('on', st.zoom === 'day');
        $('wzBig').classList.toggle('on', st.big); $('wzBig').textContent = st.big ? '⤡ Normal' : '⤢ Expand'; $('wCard').classList.toggle('big', st.big);
        $('wSub').textContent = (st.zoom === 'day' ? DS_TXT + ' → ' + DS_TXT : 'Zoomed to the weighings') + ' · green = OK · red = NG · orange dashed line = average';
    }
    $('wzFit').onclick = function () { st.zoom = 'fit'; ls('wl.zoom', 'fit'); zoomUi(); if (st.data) render(); };
    $('wzDay').onclick = function () { st.zoom = 'day'; ls('wl.zoom', 'day'); zoomUi(); if (st.data) render(); };
    $('wzBig').onclick = function () { st.big = !st.big; ls('wl.big', st.big ? '1' : '0'); zoomUi(); if (st.data) render(); };
    zoomUi();
    $('wlCsv').onclick = function () {
        var rows = (st.data && st.data.rows) || []; if (!rows.length) return;
        if (st.model) rows = rows.filter(function (r) { return (r.m || '(no model)') === st.model; });
        var q = function (v) { v = v == null ? '' : String(v); return /[",]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; };
        var csv = '\ufeffNo,Machine,Time,Model,Barcode,Weight,Unit,Spec Min,Spec Max,Diff from Spec,Result\r\n' + rows.map(function (r, i) { var d = specDiff(r); return [i + 1, st.mc, r.t, q(r.m), q(r.b), r.w, r.u, r.mn, r.mx, d == null ? '' : +d.toFixed(3), r.r].join(','); }).join('\r\n');
        var a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' })); a.download = 'weight_' + st.mc + '_' + st.day + '.csv'; a.click();
    };

    // ---------- โหมดทีวี : ขยายทั้งหน้าตามขนาดจอ (ออกแบบ 1600×900) ----------
    var tvOn = qs.get('tv') === '1' || (qs.get('tv') !== '0' && ls('wl.tv') === '1');
    if (qs.get('tv')) ls('wl.tv', qs.get('tv') === '1' ? '1' : '0');
    function tvFit() {
        if (!tvOn) { root.style.zoom = ''; root.style.width = ''; return; }
        var z = Math.max(0.5, Math.min(window.innerWidth / 1600, window.innerHeight / 900));
        root.style.zoom = z.toFixed(4);
        root.style.width = (window.innerWidth / z) + 'px';           // ให้กว้างเต็มจอ (จอที่ไม่ใช่ 16:9)
        root.style.height = (window.innerHeight / z) + 'px';
    }
    function applyTv() {
        document.body.classList.toggle('wl-tvmode', tvOn); root.classList.toggle('tv', tvOn);
        $('wlTv').textContent = tvOn ? '✕ Exit TV' : '📺 TV'; $('wlTv').classList.toggle('on', tvOn);
        if (!tvOn) root.style.height = '';
        if (tvOn && st.zoom === 'day') { st.zoom = 'fit'; }                // ทีวีใช้ Fit data เสมอ
        tvFit();
        if (st.data) render();
    }
    $('wlTv').onclick = function () { tvOn = !tvOn; ls('wl.tv', tvOn ? '1' : '0'); applyTv(); };
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && tvOn) { tvOn = false; ls('wl.tv', '0'); applyTv(); } });
    setInterval(function () {
        var n = new Date(); $('tvClock').textContent = pad(n.getHours()) + ':' + pad(n.getMinutes()) + ':' + pad(n.getSeconds());
        // เปิดค้างข้ามวันผลิต (07:45) ขณะดูวันนี้ -> เปลี่ยนเป็นวันใหม่เอง
        if (st.day !== prodToday() && st.wasToday) { st.day = prodToday(); $('wlDay').value = st.day; sync(); load(); }
        st.wasToday = st.day === prodToday();
    }, 1000);
    applyTv();
    var rt; window.addEventListener('resize', function () { clearTimeout(rt); rt = setTimeout(function () { tvFit(); if (st.data) render(); }, 150); });
    setInterval(function () { if (st.day === prodToday() && !document.hidden) load(); }, 10000);
    load();
    pollLive();
})();
</script>
</asp:Content>
