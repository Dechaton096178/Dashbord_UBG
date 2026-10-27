<%@ Page Title="Injection Layout" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="InjectionLayout.aspx.cs" Inherits="Dashbord.InjectionLayout" %>

<%-- =====================================================================
     Injection Layout — ผังแผนก Injection PVC + สถานะ / OEE สดของแต่ละเครื่อง (ออกแบบสำหรับจอทีวี : ปุ่ม TV หรือ ?tv=1)
     ข้อมูลสดชุดเดียวกับ MC Monitor (?format=live ใน InjectionLayout.aspx.cs) รีเฟรชทุก 5 วินาที
     ตำแหน่งเครื่องจับจาก EQID : UB-MC-PV-1-x = แถวบน · PV-2-x = แถวสอง · PV-3-x / PV-4-x = โซนล่างซ้าย (ยังไม่ติด IoT = OFF)
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<style>
    .ij { --u:min(1vw, 1.75vh); --ink:#e6edf7; --mute:#8b9bb4; --line:#1c2a44; --bg:#060a14; --card:#0d1526; --card2:#101b31;
          --run:#10b981; --idle:#f59e0b; --down:#ef4444; --off:#55657e; --cA:#38bdf8; --cP:#a78bfa; --cQ:#34d399;
          background:radial-gradient(1200px 600px at 50% -10%, #12204a 0%, var(--bg) 60%); color:var(--ink);
          height:calc(100vh - 64px); min-height:620px; padding:calc(var(--u) * 1) calc(var(--u) * 1.2); font-size:calc(var(--u) * .95);
          display:flex; flex-direction:column; gap:calc(var(--u) * .8); overflow:hidden; font-variant-numeric:tabular-nums; }
    .ij, .ij * { box-sizing:border-box; }

    /* ---------- หัว ---------- */
    .ij-top { display:flex; align-items:stretch; gap:calc(var(--u) * .8); flex:none; }
    .ij-brand { display:flex; flex-direction:column; justify-content:center; padding-right:calc(var(--u) * .4); min-width:0; flex:none; max-width:14%; }
    .ij-brand small { overflow:hidden; text-overflow:ellipsis; }
    .ij-brand h1 { margin:0; font-size:1.75em; font-weight:900; letter-spacing:.02em; line-height:1; white-space:nowrap; }
    .ij-brand h1 span { color:#818cf8; }
    .ij-brand small { color:var(--mute); font-size:.92em; margin-top:.35em; white-space:nowrap; }
    .kp { background:var(--card); border:1px solid var(--line); border-radius:1em; padding:.5em .8em; display:flex; align-items:center; gap:.6em; min-width:0; flex:1 1 0; overflow:hidden; }
    .kp .t { min-width:0; }
    .kp.cn { flex:0 0 auto; } .kp.out { flex:.8 1 0; }
    .kp .ring { --v:0; width:4em; height:4em; border-radius:50%; flex:none; display:grid; place-items:center; background:conic-gradient(var(--c) calc(var(--v) * 1%), #1a2742 0); }
    .kp .ring::after { content:""; width:76%; height:76%; border-radius:50%; background:var(--card); grid-area:1/1; }
    .kp .ring b { grid-area:1/1; z-index:1; font-size:1.05em; font-weight:900; color:var(--c); }
    .kp .t span { display:block; font-size:.74em; font-weight:800; letter-spacing:.12em; color:var(--mute); text-transform:uppercase; }
    .kp .t strong { display:block; font-size:1em; color:var(--c); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .kp .t em { display:block; font-style:normal; font-size:.8em; color:var(--mute); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .kp.o { --c:#fff; background:linear-gradient(135deg,#1e1b4b,#3730a3); border:0; }
    .kp.o { flex:1.35 1 0; }
    .kp.o .ring { width:5em; height:5em; background:conic-gradient(var(--oc,#a5b4fc) calc(var(--v) * 1%), rgba(255,255,255,.14) 0); }
    .kp.o .ring::after { background:#25226a; }
    .kp.o .ring b { font-size:1.35em; }
    .kp.o .t span { color:#a5b4fc; } .kp.o .t strong { font-size:1.5em; }
    .kp.apq3 { flex:2 1 0; flex-direction:column; align-items:stretch; justify-content:center; gap:.35em; padding:.55em 1em; }
    .hb { display:grid; grid-template-columns:7.2em 1fr 4.4em; align-items:center; gap:.6em; }
    .hb span { font-size:.8em; font-weight:800; letter-spacing:.06em; text-transform:uppercase; color:var(--mute); }
    .hb i { display:block; height:.65em; border-radius:99px; background:#1a2742; overflow:hidden; }
    .hb i b { display:block; height:100%; border-radius:99px; }
    .hb strong { text-align:right; font-size:1.15em; font-weight:900; }
    .kp.a { --c:var(--cA); } .kp.p { --c:var(--cP); } .kp.q { --c:var(--cQ); }
    .kp.a .t span, .kp.p .t span, .kp.q .t span { color:var(--c); font-size:.78em; letter-spacing:.06em; }
    .kp.a .t em, .kp.p .t em, .kp.q .t em { font-size:.78em; margin-top:.2em; }
    .cnt { display:grid; grid-template-columns:repeat(4, 3.2em); gap:.35em; }
    .cnt div { text-align:center; border-radius:.7em; background:var(--card2); border:1px solid var(--line); padding:.25em 0; }
    .cnt b { display:block; font-size:1.7em; font-weight:900; line-height:1.1; }
    .cnt i { font-style:normal; font-size:.68em; font-weight:800; letter-spacing:.08em; color:var(--mute); }
    .cnt .run b { color:var(--run); } .cnt .idle b { color:var(--idle); } .cnt .down b { color:var(--down); } .cnt .off b { color:var(--off); }
    .cnt .down.hot { background:rgba(239,68,68,.18); border-color:rgba(239,68,68,.6); animation:pulse 1.4s infinite; }
    .out b { display:block; font-size:1.55em; font-weight:900; line-height:1.1; }
    .out em { font-style:normal; font-size:.8em; color:var(--mute); }
    .out .ng { color:var(--down); }
    .ij-sp { flex:1; }
    .ij-clock { display:flex; flex-direction:column; justify-content:center; align-items:flex-end; }
    .ij-clock b { font-size:2.5em; font-weight:900; line-height:1; letter-spacing:.02em; }
    .ij-clock span { font-size:.85em; color:var(--mute); margin-top:.3em; white-space:nowrap; }
    .ij-clock .btns { display:flex; gap:.4em; margin-top:.4em; }
    .ij-clock button { font:inherit; font-size:.78em; font-weight:800; color:var(--mute); background:var(--card2); border:1px solid var(--line); border-radius:.6em; padding:.25em .7em; cursor:pointer; }
    .ij-clock button:hover { color:var(--ink); }

    /* ---------- ผังโรงงาน ---------- */
    .floor { flex:1; min-height:0; position:relative; border:1px solid #22345a; border-radius:1.1em; padding:calc(var(--u) * .8);
             background:#081022 linear-gradient(rgba(99,130,190,.07) 1px, transparent 1px) 0 0 / calc(var(--u) * 2) calc(var(--u) * 2),
                        linear-gradient(90deg, rgba(99,130,190,.07) 1px, transparent 1px) 0 0 / calc(var(--u) * 2) calc(var(--u) * 2);
             display:grid; gap:calc(var(--u) * .8);
             grid-template-columns:4.5% 1fr 19%; grid-template-rows:minmax(0,1.45fr) minmax(0,1fr);
             grid-template-areas:"mold inj seam" "low low util"; }
    .zone { position:relative; border:1.5px dashed #2b416d; border-radius:.9em; background:rgba(13,21,38,.55); min-width:0; min-height:0; }
    .zone > .zl { position:absolute; top:.45em; left:.7em; font-size:.82em; font-weight:800; letter-spacing:.1em; text-transform:uppercase; color:#6f86ad; }
    .z-mold { grid-area:mold; display:grid; place-items:center; }
    .z-mold b { writing-mode:vertical-rl; transform:rotate(180deg); font-size:1.3em; letter-spacing:.3em; color:#5d7399; }
    .z-seam { grid-area:seam; display:flex; flex-direction:column; gap:calc(var(--u) * .5); padding:2em calc(var(--u) * .6) calc(var(--u) * .6); border-color:#3a55a0; background:rgba(30,45,90,.22); }
    .z-seam > .zl { color:#a5b4fc; }
    .z-seam .zs { position:absolute; top:.35em; right:.7em; font-size:.9em; font-weight:900; color:var(--mute); }
    .sgrid { flex:1; min-height:0; display:grid; grid-template-columns:1fr 1fr; grid-template-rows:1fr 1fr; gap:calc(var(--u) * .5); }
    .mc.sm { font-size:.82em; padding:.45em .5em .4em; }
    .mc.sm .oee { font-size:2.1em; }
    .mc.sm .id { font-size:1.25em; white-space:nowrap; }
    .mc.sm .apq { font-size:.74em; }
    .z-util { grid-area:util; display:grid; grid-template-rows:1fr 1fr; gap:.6em; padding:.6em; border-style:solid; }
    .z-util div { border:1.5px dashed #2b416d; border-radius:.7em; display:grid; place-items:center; text-align:center; color:#7d93ba; font-weight:800; font-size:1em; padding:.4em; }
    .z-util div small { display:block; font-size:.75em; color:#56698e; font-weight:600; margin-top:.2em; }

    .z-inj { grid-area:inj; display:grid; grid-template-rows:auto 1fr 1fr; gap:calc(var(--u) * .6); padding:2em calc(var(--u) * .8) calc(var(--u) * .8); border-color:#3a55a0; background:rgba(30,45,90,.22); }
    .z-inj > .zl { color:#a5b4fc; }
    .mrow { display:grid; grid-template-columns:repeat(8, minmax(0,1fr)); gap:calc(var(--u) * .6); min-height:0; }
    .z-low { grid-area:low; display:grid; grid-template-columns:52% 1fr; gap:calc(var(--u) * .8); padding:2em calc(var(--u) * .8) calc(var(--u) * .8); }
    .z-low .grid4 { display:grid; grid-template-columns:repeat(4, minmax(0,1fr)); grid-template-rows:1fr 1fr; gap:calc(var(--u) * .6); min-height:0; }
    .aisle { display:flex; flex-direction:column; align-items:center; justify-content:center; gap:.5em; color:#4c6290; text-align:center; }
    .aisle b { font-size:2.6em; font-weight:900; letter-spacing:.06em; color:#33497a; line-height:1; }
    .aisle span { font-size:.95em; }
    .aisle .lg { display:flex; gap:1em; font-size:.85em; color:var(--mute); font-weight:700; margin-top:.6em; flex-wrap:wrap; justify-content:center; }
    .aisle .lg i { display:inline-block; width:.8em; height:.8em; border-radius:.2em; margin-right:.35em; vertical-align:-.05em; }

    /* ---------- การ์ดเครื่อง ---------- */
    .mc { --sc:var(--off); position:relative; border-radius:.8em; background:linear-gradient(180deg, var(--card2), var(--card)); border:1px solid var(--line);
          box-shadow:inset 0 .28em 0 var(--sc); padding:.55em .6em .45em; display:flex; flex-direction:column; min-width:0; min-height:0; overflow:hidden; cursor:pointer; transition:transform .15s; }
    .mc:hover { transform:translateY(-2px); }
    .mc.run { --sc:var(--run); } .mc.idle { --sc:var(--idle); } .mc.down { --sc:var(--down); }
    .mc.down { border-color:rgba(239,68,68,.75); animation:pulse 1.4s infinite; }
    .mc.idle { border-color:rgba(245,158,11,.45); }
    @keyframes pulse { 0%,100% { box-shadow:inset 0 .28em 0 var(--sc), 0 0 0 0 rgba(239,68,68,.0); } 50% { box-shadow:inset 0 .28em 0 var(--sc), 0 0 1.1em .1em rgba(239,68,68,.55); } }
    .mc .hd { display:flex; align-items:center; gap:.4em; }
    .mc .id { font-size:1.45em; font-weight:900; letter-spacing:.02em; line-height:1; }
    .mc .pill { margin-left:auto; font-size:.72em; font-weight:900; letter-spacing:.08em; padding:.18em .55em; border-radius:99px; color:var(--sc); background:color-mix(in srgb, var(--sc) 16%, transparent); white-space:nowrap; }
    .mc .st { font-size:.74em; color:var(--mute); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; margin-top:.15em; min-height:1.1em; }
    .mc.down .st { color:#fca5a5; font-weight:700; } .mc.idle .st { color:#fcd34d; }
    .mc .oee { font-size:2.35em; font-weight:900; line-height:1; margin-top:.15em; }
    .mc .oee small { font-size:.36em; color:var(--mute); font-weight:800; letter-spacing:.1em; margin-left:.25em; }
    .mc .ob { height:.32em; border-radius:99px; background:#1a2742; overflow:hidden; margin:.3em 0 .35em; }
    .mc .ob i { display:block; height:100%; border-radius:99px; }
    .mc .cn { display:flex; justify-content:space-between; gap:.25em; font-size:.68em; color:var(--mute); white-space:nowrap; margin:.1em 0 .1em; }
    .mc .cn b { color:#e2e8f0; font-weight:800; }
    .mc .apq { display:grid; grid-template-columns:repeat(3, 1fr); gap:.2em; font-size:.78em; font-weight:800; }
    .mc .apq span em { font-style:normal; color:var(--mute); margin-right:.15em; font-size:.85em; }
    .mc .ft { display:flex; justify-content:space-between; gap:.3em; font-size:.72em; color:var(--mute); margin-top:.25em; white-space:nowrap; }
    .mc .ft b { color:var(--ink); }
    .mc .sp { flex:1; min-height:.4em; display:flex; align-items:flex-end; gap:1px; margin-top:.3em; }
    .mc .sp i { flex:1; background:rgba(129,140,248,.55); border-radius:1px 1px 0 0; min-height:1px; }
    .mc .sp i.cur { background:#a5b4fc; }
    .g { color:var(--run); } .w { color:var(--idle); } .b { color:var(--down); } .na { color:var(--mute); }

    .mc.noiot { --sc:#334155; background:repeating-linear-gradient(135deg, rgba(51,65,85,.18) 0 .6em, transparent .6em 1.2em), var(--card); border-style:dashed; border-color:#2b3a55; cursor:default; justify-content:center; align-items:center; text-align:center; gap:.2em; }
    .mc.noiot:hover { transform:none; }
    .mc.noiot .id { color:#64748b; font-size:1.3em; }
    .mc.noiot .pill { margin:0; color:#94a3b8; background:rgba(100,116,139,.18); }
    .mc.noiot small { font-size:.72em; color:#56698e; }

    .ij-msg { position:absolute; left:50%; top:.4em; transform:translateX(-50%); font-size:.85em; padding:.3em .9em; border-radius:99px; background:rgba(239,68,68,.15); color:#fca5a5; border:1px solid rgba(239,68,68,.4); display:none; z-index:3; }

    /* ---------- โหมดทีวี ---------- */
    body.ij-tv .site-header, body.ij-tv .pv-badge, body.ij-tv header, body.ij-tv nav, body.ij-tv footer { display:none !important; }
    body.ij-tv { overflow:hidden; }
    body.ij-tv .ij { position:fixed; inset:0; z-index:50; height:100vh; --u:min(1vw, 1.78vh); }
    body.ij-tv #btnTv { display:none; }
    body:not(.ij-tv) #btnExit { display:none; }
</style>
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="ij" id="ij">
    <div class="ij-top">
        <div class="ij-brand"><h1>INJECTION <span>PVC</span></h1><small id="sub">Live OEE · production day 08:00 – 08:00</small></div>
        <div class="kp o" id="kO"></div>
        <div class="kp apq3" id="kAPQ"></div>
        <div class="kp cn"><div class="cnt" id="cnt"></div></div>
        <div class="kp out" id="kOut"></div>
        <span class="ij-sp"></span>
        <div class="ij-clock"><b id="clk">--:--</b><span id="upd">connecting…</span>
            <div class="btns"><button type="button" id="btnTv">&#128250; TV</button><button type="button" id="btnFull">&#x26F6; Full</button><button type="button" id="btnExit">Exit TV</button></div></div>
    </div>

    <div class="floor" id="floor">
        <div class="ij-msg" id="msg"></div>
        <div class="zone z-mold"><b>MOLD</b></div>
        <div class="zone z-inj"><span class="zl">Injection PVC · Line 1 – 2</span>
            <span></span>
            <div class="mrow" id="r1"></div>
            <div class="mrow" id="r2"></div>
        </div>
        <div class="zone z-seam"><span class="zl">Seam buffing</span><span class="zs" id="seamOee"></span><div class="sgrid" id="rs"></div></div>
        <div class="zone z-low"><span class="zl">Injection PVC · Line 3 – 4 · Setting up (not in OEE)</span>
            <div class="grid4" id="r34"></div>
            <div class="aisle"><b>INJECTION PVC</b><span id="aisleTxt"></span>
                <div class="lg"><span><i style="background:var(--run)"></i>Run</span><span><i style="background:var(--idle)"></i>Idle</span><span><i style="background:var(--down)"></i>Breakdown</span><span><i style="background:var(--off)"></i>Offline</span><span><i style="background:#334155"></i>No IoT</span></div>
            </div>
        </div>
        <div class="zone z-util"><div>Plastic crusher<small>บดพลาสติก</small></div><div>Raw materials<br />Mixing PVC<small>ผสมวัตถุดิบ</small></div></div>
    </div>
</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script>
// @ts-nocheck
(function () {
    var $ = function (id) { return document.getElementById(id); };
    var CAT = { run: 'RUN', idle: 'IDLE', down: 'DOWN', off: 'OFF' };

    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function fmt(v) { return v == null ? '–' : Math.round(v).toLocaleString('en-US'); }
    function pct(v, d) { return v == null ? '–' : v.toFixed(d == null ? 1 : d) + '%'; }
    function cls(v) { return v == null ? 'na' : v >= 85 ? 'g' : v >= 60 ? 'w' : 'b'; }
    function col(v) { return v == null ? '#475569' : v >= 85 ? '#10b981' : v >= 60 ? '#f59e0b' : '#ef4444'; }
    // สถานะแบบเดียวกับ MC Monitor (stOf ใน CounterMachine.aspx)
    function stOf(m) {
        if (!m.online || m.mode === 'offline') return 'off';
        if (m.status >= 17) return 'down';                   // 17-20 = Error
        return m.mode === 'operating' ? 'run' : 'idle';
    }
    function pos(eq) { var m = /PV-(\d+)-(\d+)/i.exec(eq || ''); return m ? m[1] + '-' + m[2] : null; }

    // ---------- TV ----------
    if (new URLSearchParams(location.search).get('tv') === '1') document.body.classList.add('ij-tv');
    function full() { try { if (!document.fullscreenElement && document.documentElement.requestFullscreen) document.documentElement.requestFullscreen(); } catch (e) { } }
    $('btnTv').onclick = function () { document.body.classList.add('ij-tv'); history.replaceState(null, '', location.pathname + '?tv=1'); full(); };
    $('btnExit').onclick = function () { document.body.classList.remove('ij-tv'); history.replaceState(null, '', location.pathname); if (document.fullscreenElement) document.exitFullscreen(); };
    $('btnFull').onclick = function () { if (document.fullscreenElement) document.exitFullscreen(); else full(); };

    function tick() { var n = new Date(); $('clk').textContent = ('0' + n.getHours()).slice(-2) + ':' + ('0' + n.getMinutes()).slice(-2) + ':' + ('0' + n.getSeconds()).slice(-2); }
    tick(); setInterval(tick, 1000);

    // ---------- การ์ดเครื่อง ----------
    function tile(code, m, hourIdx, extra) {
        extra = extra ? ' ' + extra : '';
        if (!m) return '<div class="mc noiot' + extra + '"><div class="id">' + code + '</div><span class="pill">OFF</span><small>IoT not installed</small></div>';
        var c = m.cat || 'off', st = c === 'off' ? (m.lastOnline ? 'last seen ' + String(m.lastOnline).slice(11, 16) : 'no signal') : (m.statusText || '');
        if (c === 'run' && m.operator) st = '👤 ' + m.operator;
        var hrs = m.hours || [], mx = 1;
        for (var i = 0; i <= hourIdx && i < hrs.length; i++) mx = Math.max(mx, hrs[i]);
        var sp = '';
        for (var j = 0; j <= hourIdx && j < hrs.length; j++) sp += '<i' + (j === hourIdx ? ' class="cur"' : '') + ' style="height:' + Math.max(2, hrs[j] * 100 / mx) + '%" title="' + ('0' + ((8 + j) % 24)).slice(-2) + ':00 · ' + hrs[j] + ' shots"></i>';
        var ct = m.cycleTime != null ? (+m.cycleTime).toFixed(1) : '–', sct = m.idealCycleTime != null ? '/' + (+m.idealCycleTime).toFixed(0) + 's' : 's';
        return '<div class="mc ' + c + extra + '" data-mc="' + esc(m.machine) + '" title="' + esc(m.eqid || m.machine) + '">' +
            '<div class="hd"><span class="id">' + code + '</span><span class="pill">' + CAT[c] + '</span></div>' +
            '<div class="st">' + esc(st || ' ') + '</div>' +
            '<div class="oee ' + cls(m.oee) + '">' + (m.oee == null ? '–' : Math.round(m.oee) + '%') + '<small>OEE</small></div>' +
            '<div class="cn"><span title="Counter today (pieces)">Today <b>' + fmt(m.piecesToday) + '</b></span><span title="Shot counter now (HMI)">Shot <b>' + fmt(m.shotCount) + '</b></span></div>' +
            '<div class="ob"><i style="width:' + Math.min(100, m.oee || 0) + '%;background:' + col(m.oee) + '"></i></div>' +
            '<div class="apq"><span style="color:var(--cA)"><em>A</em>' + (m.availability == null ? '–' : Math.round(m.availability)) + '</span><span style="color:var(--cP)"><em>P</em>' + (m.performance == null ? '–' : Math.round(m.performance)) + '</span><span style="color:var(--cQ)"><em>Q</em>' + (m.quality == null ? '–' : Math.round(m.quality)) + '</span></div>' +
            '<div class="ft"><span>NG <b' + (m.erpNg ? ' style="color:#f87171"' : '') + '>' + fmt(m.erpNg) + '</b></span><span title="Cycle time actual / standard">CT <b>' + ct + '</b>' + sct + '</span></div>' +
            '<div class="sp">' + sp + '</div></div>';
    }

    // ---------- รวมทั้งแผนก ----------
    function totals(list) {
        var op = 0, all = 0, std = 0, out = 0, ng = 0, pcs = 0, hasErp = false, c = { run: 0, idle: 0, down: 0, off: 0 };
        list.forEach(function (m) {
            var o = (m.operatingHours || 0) * 3600, t = o + ((m.lossHours || 0) + (m.offlineHours || 0)) * 3600;
            op += o; all += t; pcs += m.piecesToday || 0;
            if (m.idealCycleTime) std += (m.shotsToday || 0) * m.idealCycleTime;
            if (m.erpOut != null) { hasErp = true; out += m.erpOut || 0; ng += m.erpNg || 0; }
            c[m.cat] = (c[m.cat] || 0) + 1;
            void hasErp; void std;
        });
        // สูตรเดียวกับ MC Monitor : เฉลี่ยค่าของแต่ละเครื่อง (OEE AVG = เฉลี่ยเฉพาะเครื่องที่คิด OEE ได้)
        function avg(k) { var s = 0, n = 0; list.forEach(function (m) { if (m[k] != null) { s += m[k]; n++; } }); return n ? s / n : null; }
        var A = avg('availability'), P = avg('performance'), Q = avg('quality'), O = avg('oee');
        return { A: A, P: P, Q: Q, O: O, op: op, all: all, pcs: pcs, out: out, ng: ng, c: c };
    }
    function ring(v, txt) { return '<div class="ring" style="--v:' + (v == null ? 0 : Math.max(0, Math.min(100, v))) + '"><b>' + txt + '</b></div>'; }

    // ---------- แสดงผล ----------
    function render(d) {
        var list = d.machines || [], by = {};
        var seam = [];
        list.forEach(function (m) { m.cat = stOf(m); });
        list.forEach(function (m) {
            if (/-SF-/i.test(m.eqid || '') || /seam/i.test(m.process || '')) { seam.push(m); return; }
            var p = pos(m.eqid); if (p) by[p] = m;
        });
        seam.sort(function (a, b) { return String(a.eqid || a.machine).localeCompare(String(b.eqid || b.machine), undefined, { numeric: true }); });
        var now = new Date(String(d.now).replace(' ', 'T')), ds = new Date(String(d.dayStart).replace(' ', 'T'));
        var hourIdx = Math.max(0, Math.min(23, Math.floor((now - ds) / 3600e3)));
        function rowHtml(r, n) { var h = ''; for (var i = 1; i <= n; i++) h += tile(r + '-' + i, by[r + '-' + i], hourIdx); return h; }
        $('r1').innerHTML = rowHtml(1, 8);
        $('r2').innerHTML = rowHtml(2, 8);
        $('r34').innerHTML = rowHtml(3, 4) + rowHtml(4, 4);
        // Seam buffing : 4 ช่อง เรียงตาม EQID (UB-MC-SF-001 ...) · ยังไม่มีข้อมูล = OFF
        var sh = '';
        for (var k = 0; k < Math.max(4, seam.length) && k < 6; k++) {
            var sm = seam[k], lbl = sm ? ((/SF-?(\w+)/i.exec(sm.eqid || '') || [])[0] || sm.machine) : 'SF-' + (k + 1);
            sh += tile(esc(lbl), sm, hourIdx, 'sm');
        }
        $('rs').innerHTML = sh;
        var ts = totals(seam);
        $('seamOee').innerHTML = seam.length ? 'OEE <span class="' + cls(ts.O) + '">' + pct(ts.O) + '</span>' : '';

        // OEE / ตัวนับด้านบน : คิดเฉพาะ Line 1–2 · Line 3–4 (มุมล่างซ้าย) กำลังตั้งเครื่อง ยังไม่นำมาคิด
        var onFloor = []; Object.keys(by).forEach(function (k) { if (/^[12]-/.test(k)) onFloor.push(by[k]); });
        var t = totals(onFloor);
        var grade = t.O == null ? '' : t.O >= 85 ? 'World-class' : t.O >= 60 ? 'Typical' : t.O >= 40 ? 'Needs improvement' : 'Low';
        $('kO').style.setProperty('--oc', col(t.O));
        $('kO').innerHTML = ring(t.O, pct(t.O)) + '<div class="t"><span>OEE AVG</span><strong>OEE</strong><em>' + grade + '</em></div>';
        function hbar(lbl, v, c, sub, d) { return '<div class="hb" title="' + esc(sub) + '"><span>' + lbl + '</span><i><b style="width:' + Math.min(100, v || 0) + '%;background:' + c + '"></b></i><strong style="color:' + c + '">' + (v == null ? '–' : v.toFixed(d || 1) + '%') + '</strong></div>'; }
        $('kAPQ').innerHTML = hbar('Availability', t.A, 'var(--cA)', 'Run ' + (t.op / 3600).toFixed(1) + ' / ' + (t.all / 3600).toFixed(1) + ' h') +
            hbar('Performance', t.P, 'var(--cP)', 'shots × std CT / run time') + hbar('Quality', t.Q, 'var(--cQ)', 'Good ' + fmt(t.out) + ' · NG ' + fmt(t.ng), 2);
        $('cnt').innerHTML = '<div class="run"><b>' + t.c.run + '</b><i>RUN</i></div><div class="idle"><b>' + t.c.idle + '</b><i>IDLE</i></div>' +
            '<div class="down' + (t.c.down ? ' hot' : '') + '"><b>' + t.c.down + '</b><i>DOWN</i></div><div class="off"><b>' + t.c.off + '</b><i>OFF</i></div>';
        $('kOut').innerHTML = '<div class="t"><span style="display:block;font-size:.74em;font-weight:800;letter-spacing:.12em;color:var(--mute)">OUTPUT TODAY</span><b>' + fmt(t.pcs) + ' <small style="font-size:.5em;color:var(--mute)">pcs</small></b><em>NG <b class="ng" style="display:inline;font-size:1em">' + fmt(t.ng) + '</b></em></div>';
        $('aisleTxt').textContent = 'Line 1–2 : ' + onFloor.length + ' machines in OEE · Line 3–4 : setting up (not counted)';
        $('sub').textContent = 'Live OEE · ' + String(d.dayStart).slice(0, 10);
        $('upd').textContent = 'updated ' + String(d.now).slice(11, 19) + ' · every 5 s';
        $('msg').style.display = 'none';
    }

    function load() {
        fetch('InjectionLayout.aspx?format=live', { cache: 'no-store' })
            .then(function (r) { return r.json(); })
            .then(function (d) { if (d.ok === false) throw new Error(d.error || 'error'); render(d); })
            .catch(function (e) { $('msg').textContent = 'Connection problem: ' + e.message + ' — retrying'; $('msg').style.display = 'block'; });
    }
    $('floor').addEventListener('click', function (e) {
        var t = e.target.closest('.mc[data-mc]'); if (!t) return;
        window.open('OEE_Dashboard.aspx?proc=Injection&machine=' + encodeURIComponent(t.getAttribute('data-mc')), '_blank');
    });
    load();
    setInterval(function () { if (!document.hidden) load(); }, 5000);
})();
</script>
</asp:Content>
