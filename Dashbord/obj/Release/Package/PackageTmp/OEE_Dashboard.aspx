<%@ Page Title="OEE Dashboard" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="OEE_Dashboard.aspx.cs" Inherits="Dashbord.OEE_Dashboard" %>

<%-- =====================================================================
     OEE Dashboard — กระดาน OEE รายวัน (ออกแบบให้อ่านจากจอทีวีได้ : ปุ่ม TV หรือ ?tv=1)
     A, P จากเครื่อง (IoT) · Q จาก ERP · วันผลิต 07:45–07:45 · ตัวเลขชุดเดียวกับ MC Monitor
     ข้อมูล : ?format=hist (สรุป OEE) + ?format=timeline (สถานะเครื่องทั้งวัน) ดู OEE_Dashboard.aspx.cs
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<style>
    .oh { --ink:#e5e7eb; --mute:#94a3b8; --line:#1e293b; --line2:#162036; --bg:#070b16; --card:#0f172a; --card2:#111c33; --track:#1a2540;
          --acc:#6366f1; --run:#10b981; --idle:#f59e0b; --down:#ef4444; --off:#64748b; --cA:#38bdf8; --cP:#a78bfa; --cQ:#34d399;
          background:var(--bg); color:var(--ink); min-height:calc(100vh - 64px); padding:16px 18px 30px; font-size:14px; }
    .oh * { box-sizing:border-box; }
    .oh-wrap { max-width:1680px; margin:0 auto; }

    /* ---------- หัว + ตัวเลือก ---------- */
    .oh-top { display:flex; align-items:center; gap:10px; flex-wrap:wrap; margin-bottom:12px; }
    .oh-top h2 { margin:0 8px 0 0; font-size:1.55em; font-weight:900; letter-spacing:-.01em; white-space:nowrap; }
    .oh-top h2 small { display:block; font-size:.5em; font-weight:600; color:var(--mute); letter-spacing:0; }
    .oh-ctl { display:flex; align-items:center; gap:6px; flex-wrap:wrap; }
    .oh-ctl button, .oh-ctl select, .oh-ctl input { font:inherit; font-size:13px; border:1px solid var(--line); background:var(--card2); color:var(--ink); border-radius:9px; padding:6px 11px; color-scheme:dark; }
    .oh-ctl button { font-weight:800; color:var(--mute); cursor:pointer; }
    .oh-ctl button:hover { color:var(--ink); } .oh-ctl button.on { color:var(--ink); border-color:var(--acc); }
    .oh-ctl button:disabled { opacity:.35; cursor:default; }
    .oh-ctl label { font-size:12px; font-weight:800; color:var(--mute); display:inline-flex; align-items:center; gap:5px; margin-left:8px; }
    .oh-ctl select { min-width:150px; }
    .oh-sp { flex:1; }
    .oh-clock { text-align:right; line-height:1.1; }
    .oh-clock b { display:block; font-size:1.7em; font-weight:900; font-variant-numeric:tabular-nums; }
    .oh-clock span { font-size:.85em; color:var(--mute); }
    .oh-info { font-size:12.5px; color:var(--mute); margin:-4px 0 12px; }
    .oh-info b { color:var(--ink); }

    /* ---------- KPI ---------- */
    .oh-kpi { display:grid; grid-template-columns:1.35fr repeat(3, 1fr) 1.25fr; gap:12px; margin-bottom:12px; }
    .k { border:1px solid var(--line); border-radius:16px; background:var(--card); padding:14px 16px; display:flex; align-items:center; gap:16px; min-width:0; }
    .k .ring { --v:0; width:5.6em; height:5.6em; border-radius:50%; flex-shrink:0; display:grid; place-items:center;
               background:conic-gradient(var(--c) calc(var(--v) * 1%), var(--track) 0); }
    .k .ring::after { content:""; width:78%; height:78%; border-radius:50%; background:var(--card); grid-area:1/1; }
    .k .ring b { grid-area:1/1; z-index:1; font-size:1.25em; font-weight:900; color:var(--c); font-variant-numeric:tabular-nums; }
    .k .t { min-width:0; }
    .k .t > span:first-child { display:block; font-size:.8em; font-weight:800; letter-spacing:.1em; text-transform:uppercase; color:var(--mute); }
    .k .t strong { display:block; font-size:1.45em; color:var(--c); line-height:1.2; }
    .k .t em { display:block; font-style:normal; font-size:.88em; color:var(--mute); line-height:1.45; }
    .k.kA { --c:var(--cA); } .k.kP { --c:var(--cP); } .k.kQ { --c:var(--cQ); }
    .k.kO { --c:#c7d2fe; background:linear-gradient(135deg,#1e1b4b,#312e81 60%,#4338ca); border:0; }
    .k.kO .ring { width:7em; height:7em; background:conic-gradient(var(--oc, #a5b4fc) calc(var(--v) * 1%), rgba(255,255,255,.14) 0); }
    .k.kO .ring::after { background:#272468; }
    .k.kO .ring b { font-size:1.75em; color:#fff; }
    .k.kO .t > span:first-child { color:#a5b4fc; } .k.kO .t strong { color:#fff; font-size:2em; } .k.kO .t em { color:#c7d2fe; }
    .grade { display:inline-block; margin-top:6px; padding:3px 10px; border-radius:999px; font-size:.82em; font-weight:800; }
    .gr-wc { background:#d1fae5; color:#047857; } .gr-good { background:#e0f2fe; color:#0369a1; } .gr-mid { background:#fef3c7; color:#b45309; } .gr-low { background:#fee2e2; color:#b91c1c; }
    .k.kN { flex-direction:column; align-items:stretch; gap:8px; justify-content:center; }
    .k.kN > span { font-size:.8em; font-weight:800; letter-spacing:.1em; text-transform:uppercase; color:var(--mute); }
    .nowg { display:grid; grid-template-columns:repeat(4, 1fr); gap:6px; }
    .nowg div { border-radius:10px; padding:6px 4px; text-align:center; background:var(--card2); border:1px solid var(--line); }
    .nowg b { display:block; font-size:1.6em; font-weight:900; line-height:1.1; font-variant-numeric:tabular-nums; }
    .nowg i { font-style:normal; font-size:.72em; font-weight:800; letter-spacing:.06em; color:var(--mute); }
    .nowg .run b { color:var(--run); } .nowg .idle b { color:var(--idle); } .nowg .down b { color:var(--down); } .nowg .off b { color:var(--off); }
    .nowg .down.hot { background:rgba(239,68,68,.15); border-color:rgba(239,68,68,.5); }
    .k.kN em { font-style:normal; font-size:.85em; color:var(--mute); text-align:center; }

    /* ---------- กระดานเครื่อง ---------- */
    .board { border:1px solid var(--line); border-radius:16px; background:var(--card); padding:6px 14px 10px; }
    .bh, .br { display:grid; grid-template-columns:minmax(150px,12%) 7.5em 5.6em 13em 1fr 7.5em; gap:14px; align-items:center; }
    .bh { padding:8px 0 6px; border-bottom:1px solid var(--line); font-size:.74em; font-weight:800; letter-spacing:.08em; text-transform:uppercase; color:var(--mute); }
    .bh .sort { cursor:pointer; } .bh .sort:hover, .bh .sort.on { color:var(--ink); }
    .bh .r, .br .r { text-align:right; }
    .tlax { position:relative; height:1.2em; font-size:.95em; letter-spacing:0; text-transform:none; font-weight:700; }
    .tlax span { position:absolute; top:0; transform:translateX(-50%); white-space:nowrap; }
    .tlax span:first-child { transform:none; } .tlax span.last { transform:translateX(-100%); }
    .br { position:relative; min-height:var(--rh, 46px); padding:4px 0; border-bottom:1px solid var(--line2); cursor:pointer; }
    .br:last-child { border-bottom:0; }
    .br:hover { background:rgba(99,102,241,.06); }
    .br::before { content:""; position:absolute; left:-14px; top:6px; bottom:6px; width:4px; border-radius:0 4px 4px 0; background:var(--sc, transparent); }
    .nm { min-width:0; }
    .nm b { display:block; font-size:1.06em; font-weight:900; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .nm small { display:block; font-size:.78em; color:var(--mute); font-weight:600; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .now { display:inline-flex; flex-direction:column; align-items:flex-start; gap:1px; }
    .now span { display:inline-flex; align-items:center; gap:6px; font-size:.8em; font-weight:900; letter-spacing:.05em; padding:3px 9px; border-radius:99px; }
    .now span::before { content:""; width:.6em; height:.6em; border-radius:50%; background:currentColor; }
    .now.run span { color:var(--run); background:rgba(16,185,129,.14); } .now.idle span { color:var(--idle); background:rgba(245,158,11,.15); }
    .now.down span { color:var(--down); background:rgba(239,68,68,.17); } .now.off span { color:#94a3b8; background:rgba(100,116,139,.18); }
    .now.down span::before { animation:blink 1s infinite; }
    @keyframes blink { 50% { opacity:.2; } }
    .now em { font-style:normal; font-size:.78em; color:var(--mute); padding-left:4px; font-variant-numeric:tabular-nums; }
    .oee { font-size:1.55em; font-weight:900; font-variant-numeric:tabular-nums; line-height:1; text-align:right; }
    .apq { display:grid; grid-template-columns:repeat(3, 1fr); gap:8px; }
    .apq div { min-width:0; font-variant-numeric:tabular-nums; line-height:1.15; }
    .apq div > span { display:block; font-size:.86em; font-weight:800; white-space:nowrap; }
    .apq div > span em { font-style:normal; font-size:.78em; color:var(--mute); margin-right:3px; font-weight:900; }
    .apq .bar { display:block; height:4px; margin-top:3px; border-radius:99px; background:var(--track); overflow:hidden; }
    .apq .bar i { display:block; height:100%; border-radius:99px; }
    .tl { position:relative; height:calc(var(--rh, 46px) * .56); min-height:18px; border-radius:7px; overflow:hidden; background:var(--track); }
    .tl i { position:absolute; top:0; bottom:0; }
    .tl i.run { background:var(--run); } .tl i.idle { background:var(--idle); } .tl i.down { background:var(--down); } .tl i.off { background:var(--off); }
    .tl .gl { position:absolute; top:0; bottom:0; width:1px; background:rgba(7,11,22,.55); }
    .tl .nw { position:absolute; top:-2px; bottom:-2px; width:2px; background:#f8fafc; box-shadow:0 0 6px #fff; }
    .out { text-align:right; font-variant-numeric:tabular-nums; line-height:1.25; }
    .out b { display:block; font-size:1.02em; }
    .out span { font-size:.8em; color:var(--mute); }
    .out .ng { color:var(--down); font-weight:800; }
    .board.compact .nm small, .board.compact .now em { display:none; }
    .board.compact .apq .bar { display:none; }
    .board.compact .out span { display:none; }
    .g { color:var(--run); } .w { color:var(--idle); } .b { color:var(--down); } .na { color:var(--mute); }
    .lg { display:flex; gap:14px; font-size:.78em; color:var(--mute); font-weight:700; padding:8px 0 0; flex-wrap:wrap; }
    .lg i { display:inline-block; width:.8em; height:.8em; border-radius:3px; vertical-align:-1px; margin-right:5px; }
    .lg .sp { flex:1; }

    /* ---------- เครื่องเดียว : รายการหยุด ---------- */
    .stops { margin-top:12px; border:1px solid var(--line); border-radius:16px; background:var(--card); padding:12px 16px; }
    .stops h4 { margin:0 0 8px; font-size:1em; }
    .stops table { width:100%; border-collapse:collapse; font-size:.92em; color:var(--ink); font-variant-numeric:tabular-nums; }
    .stops th { text-align:left; font-size:.75em; letter-spacing:.07em; text-transform:uppercase; color:var(--mute); padding:6px 8px; border-bottom:1px solid var(--line); }
    .stops td { padding:6px 8px; border-bottom:1px solid var(--line2); }
    .stops .r { text-align:right; }
    .back { border:1px solid var(--line); background:var(--card2); color:var(--ink); font:inherit; font-size:12.5px; font-weight:800; padding:5px 12px; border-radius:9px; cursor:pointer; margin-bottom:10px; }

    .oh-msg { padding:40px; text-align:center; color:var(--mute); }
    .oh-warn { padding:7px 12px; margin-bottom:10px; border-radius:10px; border:1px solid rgba(245,158,11,.4); color:#fbbf24; font-size:12.5px; background:rgba(245,158,11,.08); }
    .tvx { display:none; }

    /* ---------- โหมดทีวี (ปุ่ม TV / ?tv=1) ---------- */
    body.oh-tv .site-header, body.oh-tv .pv-badge, body.oh-tv header, body.oh-tv nav, body.oh-tv footer { display:none !important; }
    body.oh-tv { overflow:hidden; background:#070b16; }
    body.oh-tv .oh { position:fixed; inset:0; z-index:50; min-height:0; padding:1.2vh 1.2vw; font-size:clamp(13px, 0.95vw, 30px); overflow:hidden; }
    body.oh-tv .oh-wrap { max-width:none; height:100%; display:flex; flex-direction:column; }
    body.oh-tv .oh-ctl .nt { display:none; }
    body.oh-tv .oh-ctl button, body.oh-tv .oh-ctl select { font-size:.85em; }
    body.oh-tv .oh-info { display:none; }
    body.oh-tv .board { flex:1; min-height:0; overflow:hidden; display:flex; flex-direction:column; }
    body.oh-tv .rows { flex:1; min-height:0; overflow:hidden; }
    body.oh-tv .tvx { display:inline-block; }
    body.oh-tv .stops { display:none; }

    @media (max-width:1200px) { .oh-kpi { grid-template-columns:repeat(2, 1fr); } .k.kO { grid-column:1 / -1; } }
    @media (max-width:900px) {
        .bh { display:none; }
        .br { grid-template-columns:1fr auto; grid-template-areas:"nm oee" "now out" "tl tl" "apq apq"; }
        .br .nm { grid-area:nm; } .br .oee { grid-area:oee; } .br .nowc { grid-area:now; } .br .out { grid-area:out; } .br .tlc { grid-area:tl; } .br .apq { grid-area:apq; }
    }
</style>
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="oh" id="oh"><div class="oh-wrap">
    <div class="oh-top">
        <h2 id="ttl">OEE Board<small>A, P from machine (IoT) · Q from ERP</small></h2>
        <div class="oh-ctl">
            <button type="button" id="dPrev" title="Previous day">&#9664;</button>
            <input type="date" id="dDay" />
            <button type="button" id="dNext" title="Next day">&#9654;</button>
            <button type="button" id="dToday">Today</button>
            <label class="nt">Process</label><select id="selProc"></select>
            <label class="nt">Machine</label><select id="selMc"><option value="">All machines</option></select>
            <button type="button" id="btnRf" class="nt" title="Reload">&#8635;</button>
            <button type="button" id="btnTv" class="nt" title="TV mode (full screen, auto refresh)">&#128250; TV</button>
            <button type="button" id="btnFull" class="tvx" title="Full screen">&#x26F6;</button>
            <button type="button" id="btnTvExit" class="tvx">Exit TV</button>
        </div>
        <span class="oh-sp"></span>
        <div class="oh-clock"><b id="clk">--:--</b><span id="upd"></span></div>
    </div>
    <div class="oh-info" id="info"></div>
    <div id="warn"></div>
    <div class="oh-kpi" id="kpi"></div>
    <div class="board" id="board"><div class="oh-msg">Loading…</div></div>
    <div id="stops"></div>
</div></div>
<script type="application/json" id="procJson"><%= ProcessJson %></script>
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
(function () {
    var $ = function (id) { return document.getElementById(id); };
    var PROCS = JSON.parse($('procJson').textContent || '[]');
    var st = { day: '', proc: 'All', mc: '', sort: 'name', tv: false, hist: null, tl: null, key: '', loading: false };
    var CAT = { run: 'RUN', idle: 'IDLE', down: 'DOWN', off: 'OFF' };
    var CATL = { run: 'Running', idle: 'Idle', down: 'Breakdown', off: 'Offline' };

    // ---------- util ----------
    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function fmt(v) { return v == null ? '–' : Math.round(v).toLocaleString('en-US'); }
    function pct(v) { return v == null ? '–' : v.toFixed(1) + '%'; }
    function qpct(v) { return v == null ? '–' : v.toFixed(2) + '%'; }
    function cls(v) { return v == null ? 'na' : v >= 85 ? 'g' : v >= 60 ? 'w' : 'b'; }
    function col(v) { return v == null ? '#475569' : v >= 85 ? '#10b981' : v >= 60 ? '#f59e0b' : '#ef4444'; }
    // ชื่อที่แสดง = EQID (ตัดเลขนำหน้า "1.UB-MC-PV-1-2" → "UB-MC-PV-1-2") · ไม่มี EQID ใช้รหัสเครื่อง
    function mname(m) { var e = String((m && m.eqid) || '').replace(/^\s*\d+\s*[.\-:]\s*/, '').trim(); return e || (m && m.machine) || ''; }
    function dayStr(d) { return d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2); }
    function prodDay() { var d = new Date(); if (beforeDs(d)) d.setDate(d.getDate() - 1); return dayStr(d); }
    function addDays(s, n) { var d = new Date(s + 'T00:00:00'); d.setDate(d.getDate() + n); return dayStr(d); }
    function tms(s) { return new Date(String(s).replace(' ', 'T')).getTime(); }
    function hm(s) { return String(s || '').slice(11, 16); }
    function dur(sec) { sec = Math.max(0, Math.round(sec || 0)); var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60); return h ? h + 'h ' + ('0' + m).slice(-2) + 'm' : m + 'm'; }
    function curDay() { return st.day || prodDay(); }
    function isToday() { return curDay() === prodDay(); }

    // ---------- URL ----------
    (function readUrl() {
        var p = new URLSearchParams(location.search);
        if (p.get('proc')) st.proc = p.get('proc');
        if (p.get('machine')) st.mc = p.get('machine');
        if (/^\d{4}-\d{2}-\d{2}$/.test(p.get('day') || '')) st.day = p.get('day');
        if (p.get('sort') === 'oee') st.sort = 'oee';
        st.tv = p.get('tv') === '1';
    })();
    function writeUrl() {
        var p = new URLSearchParams();
        if (st.tv) p.set('tv', '1');
        if (st.proc !== 'All') p.set('proc', st.proc);
        if (st.mc) p.set('machine', st.mc);
        if (st.day) p.set('day', st.day);
        if (st.sort !== 'name') p.set('sort', st.sort);
        history.replaceState(null, '', location.pathname + (p.toString() ? '?' + p : ''));
    }
    if (st.tv) document.body.classList.add('oh-tv');

    // ---------- ตัวเลือก ----------
    $('selProc').innerHTML = ['All'].concat(PROCS).map(function (p) { return '<option value="' + esc(p) + '">' + (p === 'All' ? 'All processes' : esc(p)) + '</option>'; }).join('');
    $('selProc').value = st.proc;
    $('selProc').onchange = function () { st.proc = this.value; st.mc = ''; load(); };
    $('selMc').onchange = function () { st.mc = this.value; load(); };
    function setDay(v) { if (!v) return; if (v > prodDay()) v = prodDay(); st.day = v === prodDay() ? '' : v; load(); }
    $('dDay').onchange = function () { setDay(this.value); };
    $('dPrev').onclick = function () { setDay(addDays(curDay(), -1)); };
    $('dNext').onclick = function () { setDay(addDays(curDay(), 1)); };
    $('dToday').onclick = function () { setDay(prodDay()); };
    $('btnRf').onclick = function () { load(); };
    $('btnTv').onclick = function () { st.tv = true; document.body.classList.add('oh-tv'); writeUrl(); goFull(); render(); };
    $('btnTvExit').onclick = function () { st.tv = false; document.body.classList.remove('oh-tv'); if (document.fullscreenElement) document.exitFullscreen(); writeUrl(); render(); };
    $('btnFull').onclick = function () { if (document.fullscreenElement) document.exitFullscreen(); else goFull(); };
    function goFull() { try { if (!document.fullscreenElement && document.documentElement.requestFullscreen) document.documentElement.requestFullscreen(); } catch (e) { } }
    function syncCtl() {
        var d = curDay(), today = prodDay();
        $('dDay').value = d; $('dDay').max = today; $('dNext').disabled = d >= today; $('dToday').classList.toggle('on', d === today);
    }

    // ---------- นาฬิกา ----------
    function tick() { var n = new Date(); $('clk').textContent = ('0' + n.getHours()).slice(-2) + ':' + ('0' + n.getMinutes()).slice(-2) + ':' + ('0' + n.getSeconds()).slice(-2); }
    tick(); setInterval(tick, 1000);

    // ---------- โหลด ----------
    function load(silent) {
        var day = curDay(), key = [day, st.proc, st.mc].join('|');
        st.key = key; syncCtl(); writeUrl();
        if (!silent) { st.hist = st.hist && st.hist._key === key ? st.hist : null; if (!st.hist) $('board').innerHTML = '<div class="oh-msg">Loading…</div>'; }
        fetch('OEE_Dashboard.aspx?format=hist&from=' + day + '&to=' + day + '&proc=' + encodeURIComponent(st.proc) + '&machine=' + encodeURIComponent(st.mc), { cache: 'no-store' })
            .then(function (r) { return r.json(); })
            .then(function (h) {
                if (st.key !== key) return;
                if (h.ok === false && h.error) throw new Error(h.error);
                h._key = key;
                var rows = (h.summary && h.summary.rows) || [];
                var list = st.mc ? [st.mc] : rows.map(function (m) { return m.machine; });
                if (!list.length) { st.hist = h; st.tl = { items: {} }; render(); return; }
                return fetch('OEE_Dashboard.aspx?format=timeline&day=' + day + '&machines=' + encodeURIComponent(list.join(',')), { cache: 'no-store' })
                    .then(function (r) { return r.json(); })
                    .then(function (t) { if (st.key !== key) return; st.hist = h; st.tl = t; render(); });
            })
            .catch(function (e) { if (st.key === key && !silent) $('board').innerHTML = '<div class="oh-msg">Failed to load: ' + esc(e.message) + '</div>'; });
    }

    // ---------- คำนวณสถานะ / ช่วงเวลา ----------
    function win() {   // ช่วงที่แสดงบน Timeline : วันนี้ = 07:45 → ตอนนี้ (+30 นาที) · วันก่อน = 07:45 → 07:45
        var t0 = tms(curDay() + ' ' + DS_TXT + ':00'), full = t0 + 24 * 3600e3;
        if (!isToday()) return { a: t0, b: full, now: null };
        var now = Date.now(), b = Math.min(full, Math.max(t0 + 4 * 3600e3, now + 30 * 60e3));
        b = Math.ceil((b - t0) / 3600e3) * 3600e3 + t0;
        return { a: t0, b: Math.min(full, b), now: now };
    }
    function machineState(mc) {
        var it = (st.tl && st.tl.items && st.tl.items[mc]) || {}, ev = it.events || [], last = ev[ev.length - 1];
        var tot = { run: 0, idle: 0, down: 0, off: 0 }, cnt = { idle: 0, down: 0, off: 0 };
        ev.forEach(function (e) { tot[e.cat] = (tot[e.cat] || 0) + (e.sec || 0); if (cnt[e.cat] != null) cnt[e.cat]++; });
        var now = isToday() && last && !last.end ? { cat: last.cat, sec: last.sec, text: last.text } : null;
        return { ev: ev, tot: tot, cnt: cnt, now: now, err: it.error };
    }

    // ---------- แสดงผล ----------
    function render() {
        var h = st.hist; if (!h) return;
        var t = h.total || {}, sm = h.summary || {}, rows = (sm.rows || []).slice();
        var day = curDay(), wd = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][new Date(day + 'T00:00:00').getDay()];

        // ตัวเลือกเครื่อง
        if (!st.mc) {
            var opts = rows.slice().sort(function (a, b) { return mname(a).localeCompare(mname(b), undefined, { numeric: true }); });
            $('selMc').innerHTML = '<option value="">All machines (' + opts.length + ')</option>' + opts.map(function (m) { return '<option value="' + esc(m.machine) + '">' + esc(mname(m)) + (st.proc === 'All' ? ' · ' + esc(m.process) : '') + '</option>'; }).join('');
        } else if (!$('selMc').querySelector('option[value="' + st.mc + '"]')) {
            $('selMc').insertAdjacentHTML('beforeend', '<option value="' + esc(st.mc) + '">' + esc(rows[0] ? mname(rows[0]) : st.mc) + '</option>');
        }
        $('selMc').value = st.mc;

        var title = st.mc ? (rows[0] ? mname(rows[0]) : st.mc) : (st.proc === 'All' ? 'All Processes' : st.proc);
        $('ttl').innerHTML = 'OEE · ' + esc(title) + '<small>' + wd + ' ' + day + ' · production day ' + DS_TXT + ' – ' + DS_TXT + (isToday() ? ' · live' : '') + '</small>';
        $('upd').textContent = 'updated ' + new Date().toTimeString().slice(0, 5) + (isToday() ? (st.tv ? ' · refresh 1 min' : ' · refresh 3 min') : '');
        $('info').innerHTML = '<b>' + rows.length + '</b> machines with data · A, P from machine (IoT) · Q from ERP · same numbers as MC Monitor';
        $('warn').innerHTML = (h.dbError ? '<div class="oh-warn">Machine DB: ' + esc(h.dbError) + '</div>' : '') + (h.erpError ? '<div class="oh-warn">ERP: ' + esc(h.erpError) + ' — Quality assumed 100%</div>' : '');

        // สถานะตอนนี้ (นับเครื่อง)
        var nowCnt = { run: 0, idle: 0, down: 0, off: 0 }, states = {};
        rows.forEach(function (m) { var s = machineState(m.machine); states[m.machine] = s; if (s.now) nowCnt[s.now.cat] = (nowCnt[s.now.cat] || 0) + 1; });
        if (st.mc && !rows.length) states[st.mc] = machineState(st.mc);

        // KPI
        function ring(v, txt) { return '<div class="ring" style="--v:' + (v == null ? 0 : Math.max(0, Math.min(100, v))) + '"><b>' + txt + '</b></div>'; }
        var o = t.oee, grade = o == null ? '' : o >= 85 ? '<span class="grade gr-wc">World-class ≥ 85%</span>' : o >= 60 ? '<span class="grade gr-good">Typical 60–85%</span>'
            : o >= 40 ? '<span class="grade gr-mid">Needs improvement</span>' : '<span class="grade gr-low">Low &lt; 40%</span>';
        var nowTile = isToday()
            ? '<div class="k kN"><span>Machines now</span><div class="nowg"><div class="run"><b>' + nowCnt.run + '</b><i>RUN</i></div><div class="idle"><b>' + nowCnt.idle + '</b><i>IDLE</i></div>' +
              '<div class="down' + (nowCnt.down ? ' hot' : '') + '"><b>' + nowCnt.down + '</b><i>DOWN</i></div><div class="off"><b>' + nowCnt.off + '</b><i>OFF</i></div></div>' +
              '<em>Output ' + fmt(t.pieces) + ' pcs · NG ' + fmt(t.erpNg) + '</em></div>'
            : '<div class="k kN"><span>Output</span><div class="nowg" style="grid-template-columns:1fr 1fr"><div><b>' + fmt(t.pieces) + '</b><i>PIECES</i></div><div class="down"><b>' + fmt(t.erpNg) + '</b><i>NG</i></div></div><em>' + fmt(t.shots) + ' shots · Good ' + fmt(t.erpGood) + '</em></div>';
        $('kpi').innerHTML =
            '<div class="k kO" style="--oc:' + col(o) + '">' + ring(o, pct(o)) + '<div class="t"><span>Overall Equipment Effectiveness</span><strong>OEE</strong><em>A × P × Q</em>' + grade + '</div></div>' +
            '<div class="k kA">' + ring(t.availability, pct(t.availability)) + '<div class="t"><span>A</span><strong>Availability</strong><em>Run ' + fmt(t.runHours) + ' h / ' + fmt(t.plannedHours) + ' h</em></div></div>' +
            '<div class="k kP">' + ring(t.performance, pct(t.performance)) + '<div class="t"><span>P</span><strong>Performance</strong><em>' + fmt(t.shots) + ' shots<br>' + fmt(t.pieces) + ' pcs</em></div></div>' +
            '<div class="k kQ">' + ring(t.quality, qpct(t.quality)) + '<div class="t"><span>Q</span><strong>Quality</strong><em>Good ' + fmt(t.erpGood) + '<br>NG ' + fmt(t.erpNg) + '</em></div></div>' +
            nowTile;

        // กระดานเครื่อง
        var W = win(), span = W.b - W.a, hours = Math.round(span / 3600e3), step = hours <= 8 ? 1 : hours <= 16 ? 2 : 4;
        var ticks = []; for (var hh = 0; hh <= hours; hh += step) ticks.push(hh);
        var ax = '<div class="tlax">' + ticks.map(function (x, i) { return '<span' + (x * 3600e3 >= span ? ' class="last"' : '') + ' style="left:' + (x * 3600e3 * 100 / span) + '%">' + tickLbl(x) + '</span>'; }).join('') + '</div>';
        if (st.mc && !rows.length) rows = [{ machine: st.mc }];
        rows.sort(function (a, b) {
            if (st.sort === 'oee') { var x = a.oee == null ? 999 : a.oee, y = b.oee == null ? 999 : b.oee; return x - y; }
            return mname(a).localeCompare(mname(b), undefined, { numeric: true });
        });
        var head = '<div class="bh"><span class="sort' + (st.sort === 'name' ? ' on' : '') + '" data-s="name">Machine ' + (st.sort === 'name' ? '▲' : '') + '</span><span>Now</span>' +
            '<span class="r sort' + (st.sort === 'oee' ? ' on' : '') + '" data-s="oee">OEE ' + (st.sort === 'oee' ? '▲ low first' : '') + '</span><span>A · P · Q</span><span>' + ax + '</span><span class="r">Output · NG</span></div>';
        var body = rows.map(function (m) {
            var s = states[m.machine] || machineState(m.machine);
            var segs = '';
            s.ev.forEach(function (e) {
                var a = Math.max(W.a, tms(e.start)), b = Math.min(W.b, tms(e.start) + (e.sec || 0) * 1000); if (W.now) b = Math.min(b, W.now);
                if (b <= a) return;
                segs += '<i class="' + esc(e.cat) + '" style="left:' + ((a - W.a) * 100 / span).toFixed(3) + '%;width:' + Math.max(0.12, (b - a) * 100 / span).toFixed(3) + '%" title="' +
                    esc(CATL[e.cat] + ' ' + hm(e.start) + '–' + (e.end ? hm(e.end) : 'now') + ' · ' + dur((b - a) / 1000) + (e.text ? ' · ' + e.text : '') + (e.reason ? ' · ' + e.reason : '')) + '"></i>';
            });
            var gl = ticks.slice(1, -1).map(function (x) { return '<span class="gl" style="left:' + (x * 3600e3 * 100 / span) + '%"></span>'; }).join('');
            var nw = W.now ? '<span class="nw" style="left:' + ((W.now - W.a) * 100 / span) + '%"></span>' : '';
            var now = s.now ? '<div class="now ' + s.now.cat + '"><span>' + CAT[s.now.cat] + '</span><em>' + dur(s.now.sec) + '</em></div>' : '<div class="now"><em>' + (isToday() ? 'no signal' : '–') + '</em></div>';
            var sc = s.now ? 'var(--' + s.now.cat + ')' : 'transparent';
            function bar(v, c, q) { return '<div><span style="color:' + c[1] + '"><em>' + c[0] + '</em>' + (v == null ? '–' : q ? v.toFixed(1) + '%' : Math.round(v) + '%') + '</span><span class="bar"><i style="width:' + Math.min(100, v || 0) + '%;background:' + c[1] + '"></i></span></div>'; }
            return '<div class="br" data-mc="' + esc(m.machine) + '" style="--sc:' + sc + '">' +
                '<div class="nm"><b>' + esc(mname(m)) + '</b><small>' + esc(m.process || '') + (s.cnt.down ? ' · ' + s.cnt.down + ' stops' : '') + '</small></div>' +
                '<div class="nowc">' + now + '</div>' +
                '<div class="oee ' + cls(m.oee) + '">' + pct(m.oee) + '</div>' +
                '<div class="apq">' + bar(m.availability, ['A', 'var(--cA)']) + bar(m.performance, ['P', 'var(--cP)']) + bar(m.quality, ['Q', 'var(--cQ)'], 1) + '</div>' +
                '<div class="tlc"><div class="tl">' + gl + segs + nw + '</div></div>' +
                '<div class="out"><b>' + fmt(m.pieces) + '</b><span>pcs · NG <span class="' + (m.erpNg ? 'ng' : '') + '">' + fmt(m.erpNg) + '</span></span></div></div>';
        }).join('') || '<div class="oh-msg">No machine data on this day</div>';
        var lg = '<div class="lg"><span><i style="background:var(--run)"></i>Run</span><span><i style="background:var(--idle)"></i>Idle</span><span><i style="background:var(--down)"></i>Breakdown</span><span><i style="background:var(--off)"></i>Offline</span>' +
            '<span><i style="background:#f8fafc"></i>Now</span><span class="sp"></span><span>OEE ≥85% green · 60–85% amber · &lt;60% red</span></div>';
        $('board').innerHTML = (st.mc ? '<button type="button" class="back" id="btnAll">← All machines' + (st.proc !== 'All' ? ' in ' + esc(st.proc) : '') + '</button>' : '') +
            head + '<div class="rows" id="rows">' + body + '</div>' + lg;
        fitRows(rows.length);

        [].forEach.call(document.querySelectorAll('.bh .sort'), function (el) { el.onclick = function () { st.sort = el.getAttribute('data-s'); writeUrl(); render(); }; });
        [].forEach.call(document.querySelectorAll('#rows .br'), function (el) { el.onclick = function () { if (st.mc) return; st.mc = el.getAttribute('data-mc'); load(); }; });
        var ba = $('btnAll'); if (ba) ba.onclick = function () { st.mc = ''; load(); };

        // เครื่องเดียว : รายการหยุด เรียงนานสุด
        if (st.mc) {
            var s1 = states[st.mc] || machineState(st.mc), stops = s1.ev.filter(function (e) { return e.cat !== 'run'; }).sort(function (a, b) { return b.sec - a.sec; });
            $('stops').innerHTML = '<div class="stops"><h4>Stops · ' + stops.length + ' times · Idle ' + dur(s1.tot.idle) + ' · Breakdown ' + dur(s1.tot.down) + ' · Offline ' + dur(s1.tot.off) + '</h4>' +
                (stops.length ? '<table><thead><tr><th>Time</th><th>Status</th><th>Code / Message</th><th class="r">Duration</th><th>Reason</th></tr></thead><tbody>' +
                stops.slice(0, 50).map(function (e) { return '<tr><td>' + hm(e.start) + ' – ' + (e.end ? hm(e.end) : 'now') + '</td><td class="' + (e.cat === 'down' ? 'b' : e.cat === 'idle' ? 'w' : 'na') + '"><b>' + CATL[e.cat] + '</b></td><td>' + esc(e.text || (e.code != null ? 'Code ' + e.code : '–')) + '</td><td class="r">' + dur(e.sec) + '</td><td>' + esc(e.reason || '') + '</td></tr>'; }).join('') +
                '</tbody></table>' : '<div class="oh-msg" style="padding:16px">No stops</div>') + '</div>';
        } else $('stops').innerHTML = '';
    }

    // ความสูงแถวให้พอดีจอ (โหมดทีวี : ทุกเครื่องอยู่ในจอเดียว)
    function fitRows(n) {
        var rowsEl = $('rows'); if (!rowsEl) return;
        var rh = 50;
        if (st.tv && n) { var avail = rowsEl.clientHeight || (window.innerHeight * .55); rh = Math.max(28, Math.min(120, Math.floor(avail / n) - 9)); }
        $('oh').style.setProperty('--rh', rh + 'px');
        $('board').classList.toggle('compact', st.tv && rh < 54);
    }
    window.addEventListener('resize', function () { if (st.hist) render(); });

    load();
    // รีเฟรช : ทีวี 1 นาที · ปกติ 3 นาที (เฉพาะวันนี้) · ทีวีที่ค้างวันเก่า -> กลับมาวันนี้ตอนเริ่มวันผลิต (07:45)
    var lastLoad = Date.now();
    setInterval(function () { if (document.hidden || !isToday()) return; if (st.tv || Date.now() - lastLoad > 170000) { lastLoad = Date.now(); load(true); } }, 60000);
    setInterval(function () { if (st.tv && st.day && st.day !== prodDay() && new Date().getHours() === DS_H && new Date().getMinutes() >= DS_M && new Date().getMinutes() < DS_M + 2) { st.day = ''; load(true); } }, 60000);
})();
</script>
</asp:Content>
