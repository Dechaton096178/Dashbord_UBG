<%@ Page Title="Hourly Output by Process" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="HourlySummary.aspx.cs" Inherits="Dashbord.HourlySummary" %>

<%-- =====================================================================
     Summary by Process — ยอดผลิตรายชั่วโมง (07:45 – 07:44 · ช่องแรก 07:45–07:59, ช่องท้าย 07:00–07:44) แต่ละ Process · กดที่ Process เพื่อดูรายเครื่อง
     ข้อมูล : ?format=json (HourlySummary.aspx.cs) · ชิ้น = Shot × Cavity · ชุดเดียวกับ MC Monitor
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<style>
    .hs { --ink:#e5e7eb; --mute:#94a3b8; --line:#1e293b; --line2:#172036; --bg:#070b16; --card:#0f172a; --card2:#111c33; --acc:#6366f1;
          background:var(--bg); color:var(--ink); min-height:calc(100vh - 64px); padding:16px 18px 30px; font-variant-numeric:tabular-nums; }
    .hs * { box-sizing:border-box; }
    .hs-top { display:flex; align-items:center; gap:10px; flex-wrap:wrap; margin-bottom:12px; }
    .hs-top h2 { margin:0 8px 0 0; font-size:21px; font-weight:900; }
    .hs-top h2 small { display:block; font-size:12px; font-weight:600; color:var(--mute); }
    .hs-ctl { display:flex; align-items:center; gap:6px; flex-wrap:wrap; }
    .hs-ctl button, .hs-ctl input { font:inherit; font-size:13px; border:1px solid var(--line); background:var(--card2); color:var(--ink); border-radius:9px; padding:6px 11px; color-scheme:dark; }
    .hs-ctl button { font-weight:800; color:var(--mute); cursor:pointer; }
    .hs-ctl button:hover { color:var(--ink); } .hs-ctl button.on { color:var(--ink); border-color:var(--acc); }
    .hs-ctl button:disabled { opacity:.35; cursor:default; }
    .hs-sp { flex:1; }
    .hs-upd { font-size:12px; color:var(--mute); }

    .hs-kpi { display:grid; grid-template-columns:repeat(auto-fill, minmax(170px, 1fr)); gap:10px; margin-bottom:12px; }
    .hs-kpi div { border:1px solid var(--line); border-radius:12px; padding:10px 14px; background:var(--card); cursor:pointer; }
    .hs-kpi div:hover { border-color:#334155; }
    .hs-kpi span { display:block; font-size:11px; font-weight:800; letter-spacing:.07em; text-transform:uppercase; color:var(--mute); }
    .hs-kpi b { display:block; font-size:22px; font-weight:900; margin-top:2px; }
    .hs-kpi em { font-style:normal; font-size:12px; color:var(--mute); }

    .hs-card { border:1px solid var(--line); border-radius:14px; background:var(--card); overflow:auto; }
    .hs table { width:100%; min-width:2750px; border-collapse:collapse; table-layout:fixed; font-size:12.5px; color:var(--ink); }
    .hs th, .hs td { border:1px solid var(--line); padding:7px 3px; text-align:right; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .hs thead th { background:var(--card2); color:var(--mute); font-weight:800; font-size:11.5px; text-align:center; position:sticky; top:0; z-index:2; }
    .hs th.nm, .hs td.nm { text-align:left; width:200px; padding-left:10px; position:sticky; left:0; background:var(--card); z-index:1; }
    .hs thead th.nm { z-index:3; background:var(--card2); }
    .hs th.tot, .hs td.tot { width:78px; background:rgba(99,102,241,.16); font-weight:900; }
    .hs th.avg, .hs td.avg { width:66px; color:var(--mute); }
    .hs tr.pr td { font-weight:800; cursor:pointer; }
    .hs tr.pr:hover td { background:rgba(99,102,241,.08); }
    .hs tr.pr td.nm::before { content:'▸'; display:inline-block; width:14px; color:var(--mute); transition:transform .15s; }
    .hs tr.pr.open td.nm::before { transform:rotate(90deg); }
    .hs tr.mc td { font-size:11.5px; color:#cbd5e1; background:rgba(17,28,51,.55); }
    .hs tr.mc td.nm { padding-left:28px; color:#cbd5e1; background:#0c1424; }
    .hs tr.mc td.nm small { color:var(--mute); margin-left:6px; }
    .hs th.hr { width:96px; font-size:12px; letter-spacing:.2px; }   /* หัวคอลัมน์ช่วงเวลา 1 บรรทัด · ตารางกว้าง -> เลื่อนด้วย scrollbar */
    .hs-card { scrollbar-color:#475569 #0b1220; }
    .hs-card::-webkit-scrollbar { height:12px; width:12px; } .hs-card::-webkit-scrollbar-track { background:#0b1220; border-radius:8px; }
    .hs-card::-webkit-scrollbar-thumb { background:#475569; border-radius:8px; border:2px solid #0b1220; } .hs-card::-webkit-scrollbar-thumb:hover { background:#64748b; }
    .hs td.cur, .hs th.cur { background:rgba(99,102,241,.14) !important; }
    .hs td.z { color:#64748b !important; font-weight:600; }
    .hs td.best { color:#34d399 !important; }
    .hs td.low { color:#f87171 !important; font-weight:800; }
    .hs tfoot td { font-weight:900; background:var(--card2); border-top:2px solid #334155; }
    .hs tfoot td.nm { background:var(--card2); }
    .hs-msg { padding:40px; text-align:center; color:var(--mute); }
    .hs-note { font-size:12px; color:var(--mute); margin-top:8px; }
    .hs-note b { color:#34d399; } .hs-note i { color:#f87171; font-style:normal; font-weight:800; }
</style>
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="hs">
    <div class="hs-top">
        <h2>Summary by Process<small>Output per hour · production day <span id="dsTxt">07:45 – 07:45</span></small></h2>
        <div class="hs-ctl">
            <button type="button" id="dPrev" title="Previous day">&#9664;</button>
            <input type="date" id="dDay" />
            <button type="button" id="dNext" title="Next day">&#9654;</button>
            <button type="button" id="dToday">Today</button>
            <button type="button" id="uPcs" class="on" title="Pieces = shots × cavities">Pcs</button>
            <button type="button" id="uShots">Shots</button>
            <button type="button" id="btnAll" title="Expand / collapse all machines">Expand all</button>
            <button type="button" id="btnCsv">Export</button>
        </div>
        <span class="hs-sp"></span>
        <span class="hs-upd" id="upd"></span>
    </div>
    <div class="hs-kpi" id="kpi"></div>
    <div class="hs-card"><div id="out"><div class="hs-msg">Loading…</div></div></div>
    <div class="hs-note"><b>Green</b> = best hour of the row · <i>Red</i> = hour with 0 output while other hours produced · highlighted column = current hour · click a process to see each machine</div>
</div>
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
    function slotEnd(i) {                                       // เวลาสิ้นสุดช่อง เช่น 07:59 · 08:59 · 07:44
        var e = DS_M && i === NSLOT - 1 ? DS_M - 1 : 59, h = DS_M && i === NSLOT - 1 ? DS_H : (DS_H + i) % 24;
        return ('0' + h).slice(-2) + ':' + ('0' + e).slice(-2);
    }
    function slotRange(i) { return slotLbl(i) + '-' + slotEnd(i); }                 // 07:45-07:59
    function slotTh(i) { return slotLbl(i) + '-<br>' + slotEnd(i); }                // หัวคอลัมน์ 2 บรรทัดในช่องเดียว
    function slotMin(i) { return DS_M && i === 0 ? 60 - DS_M : DS_M && i === NSLOT - 1 ? DS_M : 60; }   // ความยาวช่อง (นาที)
    function slotHours(n) { var s = 0; for (var i = 0; i < n && i < NSLOT; i++) s += slotMin(i); return s / 60; }   // ชั่วโมงรวมของ n ช่องแรก
(function () {
    var $ = function (id) { return document.getElementById(id); };
    var ORDER = JSON.parse($('procJson').textContent || '[]');
    var st = { day: '', unit: 'pcs', open: {}, data: null };

    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function fmt(v) { return v == null ? '' : Math.round(v).toLocaleString('en-US'); }
    function dayStr(d) { return d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2); }
    function prodDay() { var d = new Date(); if (beforeDs(d)) d.setDate(d.getDate() - 1); return dayStr(d); }
    function addDays(s, n) { var d = new Date(s + 'T00:00:00'); d.setDate(d.getDate() + n); return dayStr(d); }
    function cur() { return st.day || prodDay(); }
    function mname(m) { var e = String(m.eqid || '').replace(/^\s*\d+\s*[.\-:]\s*/, '').trim(); return e || m.machineNo || m.machine; }
    var HRS = []; for (var i = 0; i < NSLOT; i++) HRS.push(slotLbl(i));
    if ($('dsTxt')) $('dsTxt').textContent = DS_TXT + ' – ' + DS_TXT;

    (function () { var p = new URLSearchParams(location.search); if (/^\d{4}-\d{2}-\d{2}$/.test(p.get('day') || '')) st.day = p.get('day'); if (p.get('unit') === 'shots') st.unit = 'shots'; })();
    function setDay(v) { if (!v) return; if (v > prodDay()) v = prodDay(); st.day = v === prodDay() ? '' : v; load(); }
    $('dDay').onchange = function () { setDay(this.value); };
    $('dPrev').onclick = function () { setDay(addDays(cur(), -1)); };
    $('dNext').onclick = function () { setDay(addDays(cur(), 1)); };
    $('dToday').onclick = function () { setDay(prodDay()); };
    $('uPcs').onclick = function () { st.unit = 'pcs'; render(); };
    $('uShots').onclick = function () { st.unit = 'shots'; render(); };
    $('btnAll').onclick = function () {
        var any = Object.keys(st.open).some(function (k) { return st.open[k]; });
        groups().forEach(function (g) { st.open[g.name] = !any; }); render();
    };

    function load() {
        var d = cur();
        $('dDay').value = d; $('dDay').max = prodDay(); $('dNext').disabled = d >= prodDay(); $('dToday').classList.toggle('on', d === prodDay());
        history.replaceState(null, '', location.pathname + '?' + (st.day ? 'day=' + st.day + '&' : '') + (st.unit === 'shots' ? 'unit=shots' : '').replace(/&$/, ''));
        fetch('HourlySummary.aspx?format=json&day=' + d, { cache: 'no-store' }).then(function (r) { return r.json(); })
            .then(function (j) { if (j.ok === false && j.error && !(j.machines || []).length) throw new Error(j.error); st.data = j; render(); })
            .catch(function (e) { $('out').innerHTML = '<div class="hs-msg">Failed to load: ' + esc(e.message) + '</div>'; });
    }

    function val(m, i) { var s = (m.shots || [])[i] || 0; return st.unit === 'pcs' ? s * (m.cav || 1) : s; }
    function groups() {
        var d = st.data; if (!d) return [];
        var g = {};
        (d.machines || []).forEach(function (m) { (g[m.process] = g[m.process] || []).push(m); });
        return Object.keys(g).map(function (k) {
            var list = g[k].sort(function (a, b) { return mname(a).localeCompare(mname(b), undefined, { numeric: true }); });
            var h = HRS.map(function (_, i) { return list.reduce(function (s, m) { return s + val(m, i); }, 0); });
            return { name: k, list: list, h: h };
        }).filter(function (x) { return x.h.some(function (v) { return v > 0; }); })
          .sort(function (a, b) { var x = ORDER.indexOf(a.name), y = ORDER.indexOf(b.name); return (x < 0 ? 99 : x) - (y < 0 ? 99 : y); });
    }

    function cells(h, curH, isProcess) {
        var past = h.slice(0, Math.min(NSLOT, curH + 1)), tot = past.reduce(function (a, b) { return a + b; }, 0);
        var mx = Math.max.apply(null, past.concat([0])), anyProd = tot > 0;
        var full = slotHours(Math.max(0, curH));   // ชั่วโมงที่ครบแล้ว (ไม่รวมช่องปัจจุบัน · ช่อง 07:45 = 0.25 ชม.)
        var html = h.map(function (v, i) {
            if (i > curH) return '<td></td>';
            var c = (i === curH ? 'cur ' : '') + (v === 0 ? (anyProd && i < curH ? 'low ' : 'z ') : '') + (v === mx && v > 0 ? 'best' : '');
            return '<td class="' + c + '">' + fmt(v) + '</td>';
        }).join('');
        var avg = full > 0 ? past.slice(0, curH).reduce(function (a, b) { return a + b; }, 0) / full : (curH >= 0 ? tot : 0);
        return html + '<td class="tot">' + fmt(tot) + '</td><td class="avg">' + fmt(avg) + '</td>';
    }

    function render() {
        var d = st.data; if (!d) return;
        $('uPcs').classList.toggle('on', st.unit === 'pcs'); $('uShots').classList.toggle('on', st.unit === 'shots');
        var curH = d.today ? d.curHour : NSLOT - 1, gs = groups();
        $('upd').textContent = (d.today ? 'live · updated ' + String(d.now).slice(11, 16) + ' · refresh 1 min' : d.day) + (d.error ? ' · ⚠ ' + d.error : '');
        // KPI : ยอดรวมวันนี้ของแต่ละ Process + เฉลี่ยต่อชั่วโมง
        $('kpi').innerHTML = gs.map(function (g) {
            var past = g.h.slice(0, curH + 1), tot = past.reduce(function (a, b) { return a + b; }, 0);
            var done = d.today ? Math.max(0.25, slotHours(curH)) : 24;
            return '<div data-p="' + esc(g.name) + '"><span>' + esc(g.name) + '</span><b>' + fmt(tot) + '</b><em>' + fmt(d.today && curH > 0 ? past.slice(0, curH).reduce(function (a, b) { return a + b; }, 0) / done : tot / done) + ' / h · ' + g.list.length + ' mc</em></div>';
        }).join('') || '';
        if (!gs.length) { $('out').innerHTML = '<div class="hs-msg">No output recorded on ' + esc(d.day) + '</div>'; return; }
        var head = '<thead><tr><th class="nm">Process / Machine</th>' + HRS.map(function (h, i) { return '<th class="hr' + (i === curH && d.today ? ' cur' : '') + '" title="' + slotRange(i) + '">' + slotRange(i) + '</th>'; }).join('') +
            '<th class="tot">Total</th><th class="avg" title="Average per completed hour">Avg/h</th></tr></thead>';
        var body = '', grand = HRS.map(function () { return 0; });
        gs.forEach(function (g) {
            g.h.forEach(function (v, i) { grand[i] += v; });
            var op = !!st.open[g.name];
            body += '<tr class="pr' + (op ? ' open' : '') + '" data-p="' + esc(g.name) + '"><td class="nm">' + esc(g.name) + ' <small style="color:var(--mute);font-weight:600">(' + g.list.length + ')</small></td>' + cells(g.h, curH) + '</tr>';
            if (op) g.list.forEach(function (m) {
                body += '<tr class="mc"><td class="nm" title="' + esc(m.machine) + '">' + esc(mname(m)) + (st.unit === 'pcs' && m.cav > 1 ? '<small>×' + m.cav + '</small>' : '') + '</td>' + cells(HRS.map(function (_, i) { return val(m, i); }), curH) + '</tr>';
            });
        });
        var foot = '<tfoot><tr><td class="nm">All processes</td>' + cells(grand, curH) + '</tr></tfoot>';
        $('out').innerHTML = '<table>' + head + '<tbody>' + body + '</tbody>' + foot + '</table>';
        [].forEach.call(document.querySelectorAll('.hs tr.pr'), function (tr) { tr.onclick = function () { var p = tr.getAttribute('data-p'); st.open[p] = !st.open[p]; render(); }; });
    }
    $('kpi').addEventListener('click', function (e) { var c = e.target.closest('[data-p]'); if (!c) return; var p = c.getAttribute('data-p'); st.open[p] = !st.open[p]; render(); });

    // Export CSV (ตามหน่วยที่เลือก · รวมรายเครื่อง)
    $('btnCsv').onclick = function () {
        var d = st.data; if (!d) return;
        var curH = d.today ? d.curHour : NSLOT - 1, lines = [['Process', 'Machine'].concat(HRS.map(function (_, i) { return slotRange(i); })).concat(['Total']).join(',')];
        groups().forEach(function (g) {
            function row(name, mc, h) { var p = h.map(function (v, i) { return i > curH ? '' : v; }); return [name, mc].concat(p).concat([h.slice(0, curH + 1).reduce(function (a, b) { return a + b; }, 0)]).join(','); }
            lines.push(row(g.name, 'ALL', g.h));
            g.list.forEach(function (m) { lines.push(row(g.name, '"' + mname(m) + '"', HRS.map(function (_, i) { return val(m, i); }))); });
        });
        var blob = new Blob(['﻿' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' }), a = document.createElement('a');
        a.href = URL.createObjectURL(blob); a.download = 'Hourly_' + d.day + '_' + st.unit + '.csv'; a.click();
    };

    load();
    setInterval(function () { if (!document.hidden && !st.day) load(); }, 60000);
})();
</script>
</asp:Content>
