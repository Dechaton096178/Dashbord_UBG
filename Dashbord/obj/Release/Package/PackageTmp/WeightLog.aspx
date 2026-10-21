<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="WeightLog.aspx.cs" Inherits="Dashbord.WeightLog" Title="Weight Log" %>

<%-- =====================================================================
     Weight Log : scale weights (sent by Node-RED once per weighing, weight > 1.0 g)
     - API        : POST WeightLog.aspx  {"machine":"Extruder03","weight":40.12,"unit":"g","stable":true,"model":"Super Range","barcode":"S-Range","min":40,"max":40.3,"result":"OK"}
     - Data       : WeightLog.aspx?format=json&machine=Extruder03&day=yyyy-MM-dd  (production day 08:00-08:00)
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

        <div class="card">
            <h3>Weight per Weighing</h3>
            <div class="sub" id="wSub">08:00 → 08:00 · green = OK · red = NG · orange dashed line = average</div>
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
    </div>
    <div class="tip" id="tip"></div>
</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script>
// @ts-nocheck
(function () {
    var $ = function (id) { return document.getElementById(id); };
    var qs = new URLSearchParams(location.search);
    function ls(k, v) { try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) { return null; } }
    function pad(n) { return (n < 10 ? '0' : '') + n; }
    function ymd(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
    function prodToday() { var d = new Date(); if (d.getHours() < 8) d.setDate(d.getDate() - 1); return ymd(d); }
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

        var show = rows.slice(-500).reverse(), html = '';
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
        var L = 52, R = 10, T = 12, B = 26, t0 = pt(st.day + ' 08:00:00').getTime(), span = 86400000;
        var lo = Math.min.apply(null, rows.map(function (r) { return r.w; })), hi = Math.max.apply(null, rows.map(function (r) { return r.w; }));
        // แถบ Spec: แสดงเมื่อทุกแถวที่แสดงใช้ Spec เดียวกัน
        var specs = {}; rows.forEach(function (r) { if (r.mn != null && r.mx != null) specs[r.mn + '|' + r.mx] = [r.mn, r.mx]; });
        var sk = Object.keys(specs), band = sk.length === 1 ? specs[sk[0]] : null;
        if (band) { lo = Math.min(lo, band[0]); hi = Math.max(hi, band[1]); }
        var pad0 = (hi - lo) * 0.15 || hi * 0.1 || 1; lo = Math.max(0, lo - pad0); hi = hi + pad0;
        var step = niceStep((hi - lo) / 4); lo = Math.floor(lo / step) * step; hi = Math.ceil(hi / step) * step;
        var X = function (t) { return L + (W - L - R) * (pt(t).getTime() - t0) / span; }, Y = function (v) { return H - B - (H - B - T) * (v - lo) / (hi - lo); };
        var s = '<svg viewBox="0 0 ' + W + ' ' + H + '">';
        for (var v = lo; v <= hi + step / 2; v += step) s += '<line class="' + (v === lo ? 'base' : 'gl') + '" x1="' + L + '" x2="' + (W - R) + '" y1="' + Y(v) + '" y2="' + Y(v) + '"/><text class="ax" x="' + (L - 6) + '" y="' + (Y(v) + 4) + '" text-anchor="end">' + fk(v) + '</text>';
        for (var h = 0, hs = W < 520 ? 6 : W < 900 ? 4 : 2; h <= 24; h += hs) { var x = L + (W - L - R) * h / 24; s += '<text class="ax" x="' + x + '" y="' + (H - 8) + '" text-anchor="middle">' + pad((8 + h) % 24) + ':00</text>'; }
        if (band) s += '<rect x="' + L + '" y="' + Y(band[1]) + '" width="' + (W - L - R) + '" height="' + Math.max(1, Y(band[0]) - Y(band[1])) + '" fill="var(--ok)" fill-opacity=".12" stroke="var(--ok)" stroke-opacity=".5" stroke-dasharray="4 3"/>' +
                       '<text class="ax" x="' + (W - R - 4) + '" y="' + (Y(band[1]) - 4) + '" text-anchor="end" style="fill:var(--ok);font-weight:700">Spec ' + fmt(band[0]) + '–' + fmt(band[1]) + '</text>';
        if (avg != null) s += '<line x1="' + L + '" x2="' + (W - R) + '" y1="' + Y(avg) + '" y2="' + Y(avg) + '" stroke="var(--avg)" stroke-width="1.6" stroke-dasharray="6 4"/>';
        if (rows.length > 1 && rows.length < 3000) s += '<polyline fill="none" stroke="var(--pt)" stroke-opacity=".35" stroke-width="1.2" points="' + rows.map(function (r) { return X(r.t).toFixed(1) + ',' + Y(r.w).toFixed(1); }).join(' ') + '"/>';
        var rad = rows.length > 800 ? 2 : 3.5;
        rows.forEach(function (r, i) { s += '<circle data-i="' + i + '" cx="' + X(r.t).toFixed(1) + '" cy="' + Y(r.w).toFixed(1) + '" r="' + rad + '" fill="' + (r.r === 'OK' ? 'var(--ok)' : r.r === 'NG' ? 'var(--ng)' : 'var(--pt)') + '"/>'; });
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
        var cnt = new Array(24).fill(0), sm = new Array(24).fill(0), t0 = pt(st.day + ' 08:00:00').getTime();
        rows.forEach(function (r) { var k = Math.floor((pt(r.t).getTime() - t0) / 3600000); if (k >= 0 && k < 24) { cnt[k]++; sm[k] += r.w; } });
        var mx = Math.max.apply(null, cnt);
        if (!mx) { box.innerHTML = '<div class="empty">No weighings yet</div>'; return; }
        var L = 34, R = 6, T = 16, B = 22, step = niceStep(mx / 3), top = Math.ceil(mx / step) * step, slot = (W - L - R) / 24, bw = Math.max(3, slot * 0.66);
        var Y = function (v) { return H - B - (H - B - T) * v / top; };
        var s = '<svg viewBox="0 0 ' + W + ' ' + H + '">';
        for (var v = 0; v <= top; v += step) s += '<line class="' + (v ? 'gl' : 'base') + '" x1="' + L + '" x2="' + (W - R) + '" y1="' + Y(v) + '" y2="' + Y(v) + '"/><text class="ax" x="' + (L - 5) + '" y="' + (Y(v) + 4) + '" text-anchor="end">' + v + '</text>';
        cnt.forEach(function (c, k) {
            var x = L + slot * k + (slot - bw) / 2;
            if (c) { s += '<rect x="' + x + '" y="' + Y(c) + '" width="' + bw + '" height="' + (H - B - Y(c)) + '" rx="3" fill="var(--bar)"/>'; if (slot > 22) s += '<text class="vl" x="' + (x + bw / 2) + '" y="' + (Y(c) - 4) + '" text-anchor="middle">' + c + '</text>'; }
            if (k % (slot > 30 ? 1 : 2) === 0) s += '<text class="ax" x="' + (L + slot * k + slot / 2) + '" y="' + (H - 6) + '" text-anchor="middle">' + pad((8 + k) % 24) + '</text>';
            s += '<rect class="hb" data-k="' + k + '" x="' + (L + slot * k) + '" y="' + T + '" width="' + slot + '" height="' + (H - B - T) + '" fill="transparent"/>';
        });
        box.innerHTML = s + '</svg>';
        box.querySelectorAll('.hb').forEach(function (el) {
            var k = +el.getAttribute('data-k');
            el.onmousemove = function (ev) { showTip('<b>' + pad((8 + k) % 24) + ':00–' + pad((8 + k) % 24) + ':59</b><br><b>' + cnt[k] + '</b> weighings' + (cnt[k] ? '<br>Total ' + fmt(sm[k]) + ' ' + esc(unit) + ' · avg ' + fmt(sm[k] / cnt[k]) : ''), ev); };
            el.onmouseleave = hideTip;
        });
    }

    $('wlCsv').onclick = function () {
        var rows = (st.data && st.data.rows) || []; if (!rows.length) return;
        if (st.model) rows = rows.filter(function (r) { return (r.m || '(no model)') === st.model; });
        var q = function (v) { v = v == null ? '' : String(v); return /[",]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; };
        var csv = '\ufeffNo,Machine,Time,Model,Barcode,Weight,Unit,Spec Min,Spec Max,Diff from Spec,Result\r\n' + rows.map(function (r, i) { var d = specDiff(r); return [i + 1, st.mc, r.t, q(r.m), q(r.b), r.w, r.u, r.mn, r.mx, d == null ? '' : +d.toFixed(3), r.r].join(','); }).join('\r\n');
        var a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' })); a.download = 'weight_' + st.mc + '_' + st.day + '.csv'; a.click();
    };

    var rt; window.addEventListener('resize', function () { clearTimeout(rt); rt = setTimeout(function () { if (st.data) render(); }, 150); });
    setInterval(function () { if (st.day === prodToday() && !document.hidden) load(); }, 10000);
    load();
    pollLive();
})();
</script>
</asp:Content>
