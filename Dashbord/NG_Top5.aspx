<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="NG_Top5.aspx.cs" Inherits="Dashbord.NG_Top5" Title="NG Top 5 by Process" %>

<%-- =====================================================================
     NG Top 5 by Process : ปัญหางานเสีย 5 อันดับแรกของแต่ละ Process
     - ข้อมูล : NG_Top5.aspx?format=json&from=yyyy-MM-dd&to=yyyy-MM-dd  (ERP SFT_OP_EXCEPT defect)
     - ลิงก์ตรง : NG_Top5.aspx?from=2026-10-01&to=2026-10-19 · &tv=1 = โหมดจอทีวี (ซ่อนเมนู)
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<style>
    .ng5 { --bg:#eef2f7; --card:#fff; --ink:#0f172a; --ink2:#334155; --mute:#64748b; --line:#e2e8f0; --soft:#f8fafc; --acc:#6366f1;
           --bar:#e11d48; --bar2:#fda4af; --track:#f1f5f9;
           padding:16px; background:var(--bg); color:var(--ink); min-height:calc(100vh - 70px); box-sizing:border-box; font-variant-numeric:tabular-nums; }
    .ng5 * { box-sizing:border-box; }
    .ng5-bar { display:flex; align-items:center; gap:8px; flex-wrap:wrap; margin-bottom:14px; }
    .ng5-bar h2 { margin:0 8px 0 0; font-size:21px; font-weight:800; display:flex; align-items:center; gap:9px; }
    .ng5-bar h2::before { content:""; width:10px; height:10px; border-radius:50%; background:var(--bar); box-shadow:0 0 0 4px rgba(225,29,72,.15); }
    .ng5 .btn { font:inherit; font-size:13px; font-weight:700; color:var(--ink2); background:#fff; border:1px solid var(--line); border-radius:9px; padding:6px 12px; cursor:pointer; }
    .ng5 .btn.on { background:#eef2ff; border-color:#c7d2fe; color:var(--acc); }
    .ng5 .btn:hover { border-color:var(--acc); }
    .ng5 input[type=date] { font:inherit; font-size:13px; padding:5px 8px; border:1px solid var(--line); border-radius:9px; background:#fff; color:var(--ink); }
    .ng5 .lbl { font-size:12px; font-weight:700; color:var(--mute); }
    .ng5 .sp { flex:1; }
    .ng5 .msg { font-size:12.5px; color:var(--mute); }
    .ng5 .msg.err { color:#dc2626; font-weight:700; }

    .card { background:var(--card); border:1px solid var(--line); border-radius:16px; box-shadow:0 1px 2px rgba(15,23,42,.04), 0 6px 18px rgba(15,23,42,.05); padding:14px 16px; min-width:0; }
    .card h3 { margin:0 0 2px; font-size:15px; font-weight:800; }
    .card .sub { font-size:12px; color:var(--mute); }
    .kpis { display:grid; grid-template-columns:repeat(5, minmax(0,1fr)); gap:12px; margin-bottom:14px; }
    .kpi span { display:block; font-size:11.5px; font-weight:800; letter-spacing:.05em; text-transform:uppercase; color:var(--mute); }
    .kpi b { display:block; font-size:26px; font-weight:900; margin-top:2px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .kpi b.ng { color:var(--bar); }
    .kpi em { display:block; font-style:normal; font-size:12px; color:var(--mute); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }

    .ov { margin-bottom:14px; }
    .ov-row { display:grid; grid-template-columns:200px 1fr 140px; gap:10px; align-items:center; padding:5px 4px; border-radius:8px; cursor:pointer; }
    .ov-row:hover { background:var(--soft); }
    .ov-row .nm { font-size:13.5px; font-weight:700; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .ov-row .nm small { color:var(--mute); font-weight:700; margin-right:6px; }
    .trk { height:14px; background:var(--track); border-radius:99px; overflow:hidden; }
    .trk i { display:block; height:100%; background:var(--bar); border-radius:99px; }
    .ov-row .v { text-align:right; font-size:13px; } .ov-row .v b { font-size:14px; } .ov-row .v span { color:var(--mute); margin-left:6px; }

    .grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(420px, 1fr)); gap:14px; }
    .pc-h { display:flex; align-items:flex-start; gap:10px; margin-bottom:10px; }
    .pc-h .code { flex:0 0 auto; min-width:42px; height:42px; border-radius:12px; background:#fff1f2; color:var(--bar); font-weight:900; font-size:15px; display:flex; align-items:center; justify-content:center; padding:0 6px; }
    .pc-h .t { flex:1; min-width:0; } .pc-h .t h3 { font-size:16px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .pc-h .tot { text-align:right; } .pc-h .tot b { display:block; font-size:22px; font-weight:900; color:var(--bar); line-height:1.1; } .pc-h .tot span { font-size:12px; color:var(--mute); }
    .rate { display:inline-block; font-size:11.5px; font-weight:800; padding:1px 8px; border-radius:99px; background:#fff1f2; color:var(--bar); margin-left:6px; }
    .top { width:100%; border-collapse:collapse; }
    .top td { padding:6px 4px; border-top:1px solid var(--line); font-size:13.5px; vertical-align:middle; }
    .top tr.r { cursor:pointer; } .top tr.r:hover td { background:var(--soft); }
    .top .rk { width:26px; text-align:center; font-weight:900; color:var(--mute); }
    .top tr:nth-child(1) .rk { color:var(--bar); }
    .top .rs { max-width:0; width:44%; } .top .rs div { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; font-weight:700; } .top .rs small { display:block; color:var(--mute); font-size:11.5px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .top .bw { width:28%; } .top .bw .trk { height:10px; }
    .top .q { text-align:right; white-space:nowrap; } .top .q b { font-size:14px; } .top .q span { color:var(--mute); font-size:12px; margin-left:4px; }
    .top tr.oth td { color:var(--mute); } .top tr.oth .trk i { background:#cbd5e1; }
    .pc-f { margin-top:8px; font-size:12px; color:var(--mute); display:flex; gap:10px; flex-wrap:wrap; }
    .pc-f b { color:var(--ink2); }
    .nong { margin-top:14px; font-size:13px; color:var(--mute); }
    .nong span { display:inline-block; margin:4px 6px 0 0; padding:3px 10px; border-radius:99px; background:#ecfdf5; color:#047857; font-weight:700; font-size:12.5px; }
    .empty { padding:40px; text-align:center; color:var(--mute); }

    .md-back { position:fixed; inset:0; z-index:9999; background:rgba(15,23,42,.5); display:none; align-items:center; justify-content:center; padding:16px; }
    .md-back.open { display:flex; }
    .md { width:min(720px,100%); max-height:88vh; overflow:auto; background:#fff; border-radius:16px; box-shadow:0 30px 80px rgba(0,0,0,.35); padding:16px 18px; }
    .md-h { display:flex; align-items:flex-start; gap:10px; margin-bottom:10px; } .md-h h3 { margin:0; font-size:17px; flex:1; } .md-h small { display:block; color:var(--mute); font-weight:600; font-size:12.5px; }
    .md-x { border:0; background:#f1f5f9; width:32px; height:32px; border-radius:9px; font-size:18px; cursor:pointer; }
    .md table { width:100%; border-collapse:collapse; } .md th { text-align:left; font-size:11.5px; text-transform:uppercase; color:var(--mute); padding:6px; border-bottom:1px solid var(--line); }
    .md td { padding:6px; border-bottom:1px solid var(--line); font-size:13.5px; } .md .r { text-align:right; }
    .tip { position:fixed; z-index:10000; pointer-events:none; background:#0f172a; color:#f8fafc; font-size:12.5px; padding:7px 10px; border-radius:8px; display:none; max-width:360px; }
    body.ng5-tv .site-header { display:none !important; }
    @media (max-width:1100px) { .kpis { grid-template-columns:repeat(3, minmax(0,1fr)); } }
    @media (max-width:640px) { .kpis { grid-template-columns:repeat(2, minmax(0,1fr)); } .grid { grid-template-columns:1fr; } .ov-row { grid-template-columns:120px 1fr 96px; } }
</style>
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="ng5" id="ngRoot">
    <div class="ng5-bar">
        <h2>NG Top 5 by Process</h2>
        <button type="button" class="btn" data-q="today">Today</button>
        <button type="button" class="btn" data-q="yesterday">Yesterday</button>
        <button type="button" class="btn" data-q="7">Last 7 days</button>
        <button type="button" class="btn" data-q="month">This month</button>
        <span class="lbl">From</span><input type="date" id="dFrom" />
        <span class="lbl">To</span><input type="date" id="dTo" />
        <button type="button" class="btn" id="btnRefresh" title="Reload">⟳</button>
        <span class="msg" id="msg">Loading…</span>
        <span class="sp"></span>
        <span class="lbl">Sort</span>
        <button type="button" class="btn on" data-s="ng">Most NG</button>
        <button type="button" class="btn" data-s="op">Process order</button>
    </div>
    <div id="out"><div class="card empty">Loading…</div></div>

    <div class="md-back" id="mdBack"><div class="md" role="dialog" aria-modal="true">
        <div class="md-h"><h3 id="mdTitle">–</h3><button type="button" class="md-x" id="mdClose" title="Close (Esc)">×</button></div>
        <div id="mdBody"></div>
    </div></div>
    <div class="tip" id="tip"></div>
</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script>
// @ts-nocheck
(function () {
    var $ = function (id) { return document.getElementById(id); };
    var qs = new URLSearchParams(location.search);
    if (qs.get('tv') === '1') document.body.classList.add('ng5-tv');
    function pad(n) { return (n < 10 ? '0' : '') + n; }
    function ymd(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
    function prodToday() { var d = new Date(); if (d.getHours() < 8) d.setDate(d.getDate() - 1); return d; }
    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function fmt(n) { return n == null ? '–' : Math.round(n).toLocaleString('en-US'); }
    function pctUp(v) { return (Math.ceil(v * 100 - 1e-7) / 100).toFixed(2) + '%'; }   // NG % ปัดขึ้น: มี NG จะไม่โชว์ 0.00%
    function pct1(v) { return (Math.round(v * 10) / 10).toFixed(1) + '%'; }
    function dshort(s) { return s.slice(8) + '/' + s.slice(5, 7); }

    var st = { from: qs.get('from') || ymd(prodToday()), to: qs.get('to') || ymd(prodToday()), sort: qs.get('sort') || 'ng', data: null };
    $('dFrom').value = st.from; $('dTo').value = st.to;

    function preset(q) {
        var t = prodToday(), f = new Date(t);
        if (q === 'yesterday') { t.setDate(t.getDate() - 1); f = new Date(t); }
        else if (q === '7') f.setDate(f.getDate() - 6);
        else if (q === 'month') f = new Date(t.getFullYear(), t.getMonth(), 1);
        st.from = ymd(f); st.to = ymd(t); $('dFrom').value = st.from; $('dTo').value = st.to; load();
    }
    function markPreset() {
        var t = ymd(prodToday()), y = new Date(prodToday()); y.setDate(y.getDate() - 1);
        var s7 = new Date(prodToday()); s7.setDate(s7.getDate() - 6); var m1 = new Date(prodToday().getFullYear(), prodToday().getMonth(), 1);
        var map = { today: [t, t], yesterday: [ymd(y), ymd(y)], '7': [ymd(s7), t], month: [ymd(m1), t] };
        document.querySelectorAll('.ng5-bar [data-q]').forEach(function (b) { var r = map[b.getAttribute('data-q')]; b.classList.toggle('on', r[0] === st.from && r[1] === st.to); });
        document.querySelectorAll('.ng5-bar [data-s]').forEach(function (b) { b.classList.toggle('on', b.getAttribute('data-s') === st.sort); });
    }
    document.querySelectorAll('.ng5-bar [data-q]').forEach(function (b) { b.onclick = function () { preset(b.getAttribute('data-q')); }; });
    document.querySelectorAll('.ng5-bar [data-s]').forEach(function (b) { b.onclick = function () { st.sort = b.getAttribute('data-s'); sync(); markPreset(); if (st.data) render(); }; });
    $('dFrom').onchange = $('dTo').onchange = function () { if ($('dFrom').value && $('dTo').value) { st.from = $('dFrom').value; st.to = $('dTo').value; if (st.from > st.to) { var x = st.from; st.from = st.to; st.to = x; $('dFrom').value = st.from; $('dTo').value = st.to; } load(); } };
    $('btnRefresh').onclick = function () { load(); };
    function sync() {
        try { var p = new URLSearchParams(location.search); p.set('from', st.from); p.set('to', st.to); if (st.sort !== 'ng') p.set('sort', st.sort); else p.delete('sort'); history.replaceState(null, '', location.pathname + '?' + p); } catch (e) { }
    }

    var loading = false;
    function load() {
        if (loading) return; loading = true; sync(); markPreset();
        $('msg').className = 'msg'; $('msg').textContent = 'Loading…';
        fetch('NG_Top5.aspx?format=json&from=' + st.from + '&to=' + st.to + '&_=' + Date.now(), { cache: 'no-store' })
            .then(function (r) { return r.json().then(function (j) { if (!r.ok || j.error) throw new Error(j.error || ('HTTP ' + r.status)); return j; }); })
            .then(function (d) {
                st.data = d; st.from = d.from; st.to = d.to; $('dFrom').value = d.from; $('dTo').value = d.to; markPreset();
                $('msg').textContent = 'Production day ' + d.fromTime.slice(5).replace('-', '/') + ' → ' + d.toTime.slice(5).replace('-', '/') + ' · updated ' + d.now.slice(11, 16) + (d.to === ymd(prodToday()) ? ' · auto-refresh 5 min' : '');
                render();
            })
            .catch(function (e) { $('msg').className = 'msg err'; $('msg').textContent = 'Failed to load: ' + e.message; })
            .then(function () { loading = false; });
    }

    // ---------- รวมข้อมูล ----------
    function reasonKey(r) { return r.reason || r.grp || '(Unspecified)'; }
    function build(d) {
        var P = {};
        (d.processes || []).forEach(function (p) { P[p.op] = { op: p.op, code: p.code, name: p.name || p.op, good: p.good || 0, lots: p.lots || 0, ng: 0, ngLots: 0, reasons: {}, machines: {} }; });
        (d.rows || []).forEach(function (r) {
            var p = P[r.op] || (P[r.op] = { op: r.op, code: r.op, name: r.op, good: 0, lots: 0, ng: 0, reasons: {}, machines: {} });
            var k = reasonKey(r), x = p.reasons[k] || (p.reasons[k] = { reason: k, grp: r.grp, qty: 0, lots: 0, eq: {} });
            x.qty += r.qty; x.lots += r.lots; if (r.grp && !x.grp) x.grp = r.grp;
            var eq = r.eq || '(no machine)'; x.eq[eq] = (x.eq[eq] || 0) + r.qty;
            p.machines[eq] = (p.machines[eq] || 0) + r.qty; p.ng += r.qty;
        });
        var list = Object.keys(P).map(function (k) {
            var p = P[k];
            p.list = Object.keys(p.reasons).map(function (r) { return p.reasons[r]; }).sort(function (a, b) { return b.qty - a.qty; });
            p.rate = (p.good + p.ng) > 0 ? p.ng * 100 / (p.good + p.ng) : 0;
            p.topMc = Object.keys(p.machines).sort(function (a, b) { return p.machines[b] - p.machines[a]; })[0];
            return p;
        });
        return list;
    }

    function render() {
        var d = st.data, list = build(d);
        var withNg = list.filter(function (p) { return p.ng > 0; }), noNg = list.filter(function (p) { return p.ng <= 0; });
        var order = function (a, b) { return parseFloat(a.code) - parseFloat(b.code) || String(a.code).localeCompare(String(b.code)); };
        withNg.sort(st.sort === 'op' ? order : function (a, b) { return b.ng - a.ng; });
        noNg.sort(order);
        var tNg = 0, tGood = 0, tLots = 0, allR = {};
        list.forEach(function (p) { tNg += p.ng; tGood += p.good; tLots += p.lots; p.list.forEach(function (r) { var k = p.code + ' ' + p.name + ' · ' + r.reason; allR[k] = (allR[k] || 0) + r.qty; }); });
        var topAll = Object.keys(allR).sort(function (a, b) { return allR[b] - allR[a]; })[0];
        var worst = withNg.slice().sort(function (a, b) { return b.rate - a.rate; })[0];
        var range = d.from === d.to ? dshort(d.from) : dshort(d.from) + ' – ' + dshort(d.to);

        var h = '<div class="kpis">' +
            kpi('Total NG', fmt(tNg), 'pcs · ' + range, 'ng') +
            kpi('NG rate', (tGood + tNg) > 0 ? pctUp(tNg * 100 / (tGood + tNg)) : '–', 'of Good + NG (all processes)') +
            kpi('Batches checked out', fmt(tLots), list.length + ' processes') +
            kpi('Highest NG rate', worst ? esc(worst.code + ' ' + worst.name) : '–', worst ? pctUp(worst.rate) + ' · ' + fmt(worst.ng) + ' pcs' : 'no NG') +
            kpi('Top reason (all)', topAll ? esc(topAll.split(' · ').slice(1).join(' · ')) : '–', topAll ? fmt(allR[topAll]) + ' pcs · ' + esc(topAll.split(' · ')[0]) : '') +
            '</div>';

        if (!list.length) { $('out').innerHTML = h + '<div class="card empty">No batches checked out in this period</div>'; return; }

        // overview
        var mx = withNg.reduce(function (a, p) { return Math.max(a, p.ng); }, 1);
        if (withNg.length) {
            h += '<div class="card ov"><h3>NG by Process</h3><div class="sub" style="margin-bottom:6px">click a process to jump to its Top 5</div>' +
                withNg.slice().sort(function (a, b) { return b.ng - a.ng; }).map(function (p) {
                    return '<div class="ov-row" data-go="' + esc(p.op) + '"><div class="nm"><small>' + esc(p.code) + '</small>' + esc(p.name) + '</div>' +
                        '<div class="trk"><i style="width:' + (p.ng * 100 / mx) + '%"></i></div>' +
                        '<div class="v"><b>' + fmt(p.ng) + '</b><span>' + pctUp(p.rate) + '</span></div></div>';
                }).join('') + '</div>';
        }

        // cards
        h += '<div class="grid">' + withNg.map(card).join('') + '</div>';
        if (noNg.length) h += '<div class="nong">No NG recorded: ' + noNg.map(function (p) { return '<span>' + esc(p.code + ' ' + p.name) + ' · ' + fmt(p.lots) + ' batches</span>'; }).join('') + '</div>';
        $('out').innerHTML = h;

        document.querySelectorAll('.ov-row[data-go]').forEach(function (el) {
            el.onclick = function () { var c = document.getElementById('pc-' + el.getAttribute('data-go')); if (c) c.scrollIntoView({ behavior: 'smooth', block: 'start' }); };
        });
        document.querySelectorAll('.top tr.r').forEach(function (tr) {
            tr.onclick = function () { openReason(tr.getAttribute('data-op'), tr.getAttribute('data-k')); };
        });
        st.list = list;
    }
    function kpi(label, val, sub, cls) { return '<div class="card kpi"><span>' + label + '</span><b' + (cls ? ' class="' + cls + '"' : '') + ' title="' + String(val).replace(/<[^>]+>/g, '') + '">' + val + '</b><em>' + (sub || '&nbsp;') + '</em></div>'; }

    function card(p) {
        var top = p.list.slice(0, 5), rest = p.list.slice(5), restQ = rest.reduce(function (a, r) { return a + r.qty; }, 0), mx = top.length ? top[0].qty : 1, cum = 0;
        var rows = top.map(function (r, i) {
            cum += r.qty;
            return '<tr class="r" data-op="' + esc(p.op) + '" data-k="' + esc(r.reason) + '" title="Click for machines">' +
                '<td class="rk">' + (i + 1) + '</td>' +
                '<td class="rs"><div title="' + esc(r.reason) + '">' + esc(r.reason) + '</div><small>' + esc(r.grp && r.grp !== r.reason ? r.grp + ' · ' : '') + fmt(r.lots) + (r.lots === 1 ? ' batch' : ' batches') + '</small></td>' +
                '<td class="bw"><div class="trk"><i style="width:' + (r.qty * 100 / mx) + '%"></i></div></td>' +
                '<td class="q"><b>' + fmt(r.qty) + '</b><span>' + pct1(r.qty * 100 / p.ng) + '</span></td></tr>';
        }).join('');
        if (rest.length) rows += '<tr class="oth"><td class="rk">…</td><td class="rs"><div>Other ' + rest.length + (rest.length === 1 ? ' reason' : ' reasons') + '</div></td><td class="bw"><div class="trk"><i style="width:' + (restQ * 100 / mx) + '%"></i></div></td><td class="q"><b>' + fmt(restQ) + '</b><span>' + pct1(restQ * 100 / p.ng) + '</span></td></tr>';
        var top5share = p.ng ? cum * 100 / p.ng : 0;
        return '<div class="card pc" id="pc-' + esc(p.op) + '"><div class="pc-h"><div class="code">' + esc(p.code) + '</div>' +
            '<div class="t"><h3 title="' + esc(p.name) + '">' + esc(p.name) + '</h3><div class="sub">' + fmt(p.lots) + ' batches · Good ' + fmt(p.good) + '</div></div>' +
            '<div class="tot"><b>' + fmt(p.ng) + '</b><span>NG pcs</span><span class="rate">' + pctUp(p.rate) + '</span></div></div>' +
            '<table class="top"><tbody>' + rows + '</tbody></table>' +
            '<div class="pc-f"><span>Top ' + top.length + ' = <b>' + pct1(top5share) + '</b> of NG</span>' + (p.topMc ? '<span>Most NG machine: <b>' + esc(p.topMc) + '</b> (' + fmt(p.machines[p.topMc]) + ')</span>' : '') + '</div></div>';
    }

    // ---------- popup: สาเหตุนี้เกิดที่เครื่องไหน ----------
    function openReason(op, k) {
        var p = (st.list || []).filter(function (x) { return x.op === op; })[0]; if (!p) return;
        var r = p.reasons[k]; if (!r) return;
        var eqs = Object.keys(r.eq).sort(function (a, b) { return r.eq[b] - r.eq[a]; });
        $('mdTitle').innerHTML = esc(r.reason) + '<small>' + esc(p.code + ' ' + p.name) + ' · ' + fmt(r.qty) + ' pcs · ' + pct1(r.qty * 100 / p.ng) + ' of process NG · ' + (st.data.from === st.data.to ? dshort(st.data.from) : dshort(st.data.from) + ' – ' + dshort(st.data.to)) + '</small>';
        var mx = eqs.length ? r.eq[eqs[0]] : 1;
        $('mdBody').innerHTML = '<table><thead><tr><th>Machine</th><th class="r">NG pcs</th><th class="r">Share</th><th style="width:38%"></th></tr></thead><tbody>' +
            eqs.map(function (e) { return '<tr><td><b>' + esc(e) + '</b></td><td class="r">' + fmt(r.eq[e]) + '</td><td class="r">' + pct1(r.eq[e] * 100 / r.qty) + '</td><td><div class="trk" style="height:10px"><i style="width:' + (r.eq[e] * 100 / mx) + '%"></i></div></td></tr>'; }).join('') +
            '</tbody></table>';
        $('mdBack').classList.add('open');
    }
    function closeMd() { $('mdBack').classList.remove('open'); }
    $('mdClose').onclick = closeMd;
    $('mdBack').addEventListener('click', function (e) { if (e.target === $('mdBack')) closeMd(); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeMd(); });

    // ข้ามวันผลิต (08:00) : ถ้าช่วงที่ดูจบที่ "วันนี้" -> เลื่อนทั้งช่วงไปตามวันใหม่ (จำนวนวันเท่าเดิม)
    var lastToday = ymd(prodToday());
    setInterval(function () {
        var t = ymd(prodToday());
        if (t === lastToday) return;
        if (st.to === lastToday) {
            var n = Math.round((new Date(t + 'T00:00:00') - new Date(lastToday + 'T00:00:00')) / 864e5), f = new Date(st.from + 'T00:00:00');
            f.setDate(f.getDate() + n); st.from = ymd(f); st.to = t; $('dFrom').value = st.from; $('dTo').value = st.to; load();
        }
        lastToday = t;
    }, 30000);
    setInterval(function () { if (!document.hidden && st.to === ymd(prodToday())) load(); }, 300000);
    load();
})();
</script>
</asp:Content>
