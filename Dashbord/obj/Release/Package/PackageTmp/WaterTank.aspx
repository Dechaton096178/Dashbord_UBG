<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="WaterTank.aspx.cs" Inherits="Dashbord.WaterTank" Title="Water Tank" %>

<%-- =====================================================================
     Water Tank : ถังน้ำ 4 ระดับ (Full / Normal / Low / Empty) จาก Relay ระดับน้ำ 3 ตัว (DI1 EMPTY, DI2 MID, DI3 FULL) ผ่าน Node-RED + แจ้งเตือน LINE
     - API  : POST WaterTank.aspx {"tank":"Water1","level":"full|normal|low|empty|fault","di1":1,"di2":1,"di3":0}
     - Data : WaterTank.aspx?format=json&tank=Water1&day=yyyy-MM-dd
     - ปุ่มจำลอง : WaterTank.aspx?test=1
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<style>
    .wt { --bg:#eef2f8; --card:#fff; --bd:#e2e8f0; --ink:#0f172a; --ink2:#334155; --mute:#64748b; --line:#e5e9f0;
          --full:#0ea5e9; --normal:#16a34a; --low:#f59e0b; --empty:#ef4444; --fault:#8b5cf6; --none:#94a3b8; --ok:#16a34a;
          padding:14px; background:var(--bg); color:var(--ink); min-height:calc(100vh - 70px); box-sizing:border-box; font-variant-numeric:tabular-nums; }
    .wt * { box-sizing:border-box; }
    .wt-bar { display:flex; align-items:center; gap:8px; flex-wrap:wrap; margin-bottom:12px; }
    .wt-bar h2 { margin:0 6px 0 0; font-size:20px; font-weight:800; }
    .wt-bar .sp { flex:1; }
    .wt-btn, .wt-in { font:inherit; font-size:13px; font-weight:700; color:var(--ink2); background:#f8fafc; border:1px solid var(--bd); border-radius:9px; padding:6px 11px; cursor:pointer; }
    .wt-btn:hover { border-color:#6366f1; color:#4f46e5; }
    .wt-in { cursor:text; padding:5px 9px; }
    .wt-badge { display:inline-flex; align-items:center; gap:6px; font-size:12.5px; font-weight:800; padding:4px 10px; border-radius:999px; background:#e2e8f0; color:#475569; }
    .wt-badge::before { content:""; width:8px; height:8px; border-radius:50%; background:currentColor; }
    .wt-badge.on { background:#dcfce7; color:#15803d; } .wt-badge.off { background:#fee2e2; color:#b91c1c; }
    .wt-msg { font-size:12.5px; color:var(--mute); } .wt-msg.err { color:#dc2626; font-weight:700; }

    .wt-grid { display:grid; grid-template-columns:minmax(300px, 420px) 1fr; gap:12px; align-items:start; }
    .wt-card { background:var(--card); border:1px solid var(--bd); border-radius:14px; padding:14px 16px; box-shadow:0 1px 2px rgba(15,23,42,.04), 0 6px 20px rgba(15,23,42,.06); }
    .wt-card h3 { margin:0 0 10px; font-size:14px; font-weight:800; color:var(--ink2); }
    .wt-right { display:grid; gap:12px; }

    /* ---------- ถัง ---------- */
    .tank-wrap { display:flex; flex-direction:column; align-items:center; gap:10px; }
    .tank-svg { width:100%; max-width:300px; height:auto; }
    .tank-svg .water { transition:transform 1.2s cubic-bezier(.4,0,.2,1), fill .6s; }
    .tank-svg .wave { animation:wv 3.2s linear infinite; }
    .tank-svg .wave2 { animation:wv 5s linear infinite reverse; opacity:.45; }
    @keyframes wv { from { transform:translateX(0); } to { transform:translateX(-120px); } }
    .tank-svg .mk text { font:700 13px system-ui, "Segoe UI", sans-serif; fill:#94a3b8; }
    .tank-svg .mk line { stroke:#cbd5e1; stroke-width:2; stroke-dasharray:4 4; }
    .tank-svg .mk.cur text { fill:var(--c); font-size:14px; }
    .tank-svg .mk.cur line { stroke:var(--c); stroke-dasharray:none; }
    .tank-svg .fl circle { stroke:#fff; stroke-width:2; }
    .wt-state { text-align:center; }
    .wt-state .big { font-size:40px; font-weight:900; line-height:1.1; color:var(--c); }
    .wt-state .sub { margin-top:4px; font-size:14px; color:var(--mute); }
    .wt.blink .wt-state .big { animation:bl 1s steps(2) infinite; }
    @keyframes bl { 50% { opacity:.35; } }
    .wt-sensors { display:flex; gap:10px; flex-wrap:wrap; justify-content:center; font-size:12.5px; color:var(--ink2); }
    .wt-sensors span { display:inline-flex; align-items:center; gap:6px; padding:4px 10px; border-radius:8px; background:#f1f5f9; }
    .wt-sensors i { width:10px; height:10px; border-radius:50%; background:#cbd5e1; display:inline-block; }
    .wt-sensors i.on { background:var(--ok); box-shadow:0 0 0 3px rgba(22,163,74,.18); }

    /* ---------- LINE ---------- */
    .q-row { display:flex; justify-content:space-between; align-items:baseline; gap:8px; font-size:13px; color:var(--ink2); }
    .q-row b { font-size:22px; color:var(--ink); }
    .q-bar { height:10px; border-radius:6px; background:#e2e8f0; overflow:hidden; margin:8px 0 6px; }
    .q-bar div { height:100%; background:#06c755; border-radius:6px; transition:width .6s; }
    .q-bar.hi div { background:#f59e0b; } .q-bar.full div { background:#ef4444; }
    .rules { margin:10px 0 0; padding:0; list-style:none; display:grid; gap:5px; font-size:12.5px; color:var(--ink2); }
    .rules li::before { content:"•"; color:#06c755; font-weight:900; margin-right:6px; }

    /* ---------- แถบเวลา ---------- */
    .tl { position:relative; height:34px; border-radius:8px; overflow:hidden; background:#f1f5f9; display:flex; }
    .tl div { height:100%; }
    .tl-ax { display:flex; justify-content:space-between; font-size:11px; color:var(--mute); margin-top:4px; }
    .tl-lg { display:flex; gap:12px; flex-wrap:wrap; font-size:12px; color:var(--ink2); margin-top:8px; }
    .tl-lg span::before { content:""; display:inline-block; width:10px; height:10px; border-radius:3px; margin-right:5px; vertical-align:-1px; background:var(--c); }
    .tl-now { position:absolute; top:0; bottom:0; width:2px; background:#0f172a; opacity:.6; }

    /* ---------- ประวัติ ---------- */
    .ev { width:100%; border-collapse:collapse; font-size:13.5px; }
    .ev th { text-align:left; font-size:12px; color:var(--mute); font-weight:700; padding:6px 8px; border-bottom:1px solid var(--line); }
    .ev td { padding:7px 8px; border-bottom:1px solid var(--line); vertical-align:top; }
    .ev tr:last-child td { border-bottom:0; }
    .ev .t { white-space:nowrap; color:var(--ink2); font-weight:700; }
    .pill { display:inline-block; padding:2px 9px; border-radius:999px; font-size:12px; font-weight:800; color:#fff; background:var(--c); }
    .ev .ln { color:var(--mute); font-size:12.5px; white-space:pre-line; }
    .ev .ln.bad { color:#dc2626; }
    .ev-wrap { max-height:420px; overflow:auto; }
    .empty-note { color:var(--mute); font-size:13px; padding:10px 0; }

    .wt-test { display:none; gap:6px; align-items:center; flex-wrap:wrap; padding:8px 10px; border:1px dashed #a5b4fc; border-radius:10px; background:#eef2ff; font-size:12.5px; margin-bottom:12px; }
    .wt-test.show { display:flex; }

    @media (max-width: 820px) { .wt-grid { grid-template-columns:1fr; } .wt-state .big { font-size:32px; } }
</style>
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="wt" id="wt">
    <div class="wt-bar">
        <h2>💧 Water Tank</h2>
        <span class="wt-badge" id="online">-</span>
        <span class="wt-msg" id="seen"></span>
        <span class="sp"></span>
        <label class="wt-msg" for="day">History</label>
        <input type="date" class="wt-in" id="day" />
        <button type="button" class="wt-btn" id="today">Today</button>
        <span class="wt-msg" id="msg"></span>
    </div>

    <div class="wt-test" id="testBar">
        <b>Simulate:</b>
        <button type="button" class="wt-btn" data-sim="full">Full</button>
        <button type="button" class="wt-btn" data-sim="normal">Normal</button>
        <button type="button" class="wt-btn" data-sim="low">Low</button>
        <button type="button" class="wt-btn" data-sim="empty">Empty</button>
        <button type="button" class="wt-btn" data-sim="fault">Relay fault</button>
        <label><input type="checkbox" id="simLine" /> also send LINE</label>
        <span class="wt-msg">(test mode: LINE is not sent unless ticked)</span>
    </div>

    <div class="wt-grid">
        <div class="wt-card tank-wrap">
            <svg class="tank-svg" viewBox="0 0 300 380" aria-label="Water tank level">
                <defs>
                    <clipPath id="tankClip"><rect x="40" y="40" width="160" height="300" rx="22" /></clipPath>
                    <linearGradient id="glass" x1="0" x2="1">
                        <stop offset="0" stop-color="#fff" stop-opacity=".55" /><stop offset=".25" stop-color="#fff" stop-opacity="0" />
                        <stop offset=".85" stop-color="#000" stop-opacity="0" /><stop offset="1" stop-color="#000" stop-opacity=".08" />
                    </linearGradient>
                </defs>
                <!-- ฝา / ท่อ -->
                <rect x="95" y="22" width="50" height="20" rx="5" fill="#cbd5e1" />
                <rect x="40" y="40" width="160" height="300" rx="22" fill="#f1f5f9" />
                <!-- น้ำ -->
                <g clip-path="url(#tankClip)">
                    <g class="water" id="water" style="transform:translateY(300px)">
                        <g class="wave2"><path id="wv2" d="" /></g>
                        <g class="wave"><path id="wv1" d="" /></g>
                    </g>
                </g>
                <rect x="40" y="40" width="160" height="300" rx="22" fill="url(#glass)" />
                <rect x="40" y="40" width="160" height="300" rx="22" fill="none" stroke="#94a3b8" stroke-width="4" />
                <!-- ขีดระดับ -->
                <!-- Relay ระดับน้ำ : Relay3 FULL (DI3) / Relay2 MID (DI2) / Relay1 EMPTY (DI1) -->
                <g class="mk" id="mk-3"><line x1="40" y1="80" x2="214" y2="80" /><text x="220" y="85">FULL</text></g>
                <g class="mk" id="mk-2"><line x1="40" y1="190" x2="214" y2="190" /><text x="220" y="195">MID</text></g>
                <g class="mk" id="mk-1"><line x1="40" y1="300" x2="214" y2="300" /><text x="220" y="305">EMPTY</text></g>
                <!-- สถานะ Relay -->
                <g class="fl"><circle id="f3" cx="24" cy="80" r="9" fill="#cbd5e1" /><circle id="f2" cx="24" cy="190" r="9" fill="#cbd5e1" /><circle id="f1" cx="24" cy="300" r="9" fill="#cbd5e1" /></g>
                <g font-size="10" fill="#94a3b8" font-family="system-ui" text-anchor="middle"><text x="24" y="104">R3</text><text x="24" y="214">R2</text><text x="24" y="324">R1</text></g>
                <!-- ฐาน -->
                <rect x="55" y="340" width="20" height="26" fill="#94a3b8" /><rect x="165" y="340" width="20" height="26" fill="#94a3b8" />
                <rect x="40" y="362" width="160" height="8" rx="3" fill="#64748b" />
            </svg>
            <div class="wt-state">
                <div class="big" id="lvTxt">-</div>
                <div class="sub" id="lvSub">Waiting for data…</div>
            </div>
            <div class="wt-sensors">
                <span><i id="s1"></i> Relay1 EMPTY (DI1)</span>
                <span><i id="s2"></i> Relay2 MID (DI2)</span>
                <span><i id="s3"></i> Relay3 FULL (DI3)</span>
            </div>
        </div>

        <div class="wt-right">
            <div class="wt-card">
                <h3>Timeline · <span id="tlDay"></span></h3>
                <div class="tl" id="tl"></div>
                <div class="tl-ax"><span>00</span><span>04</span><span>08</span><span>12</span><span>16</span><span>20</span><span>24</span></div>
                <div class="tl-lg">
                    <span style="--c:var(--full)">Full</span><span style="--c:var(--normal)">Normal</span><span style="--c:var(--low)">Low</span>
                    <span style="--c:var(--empty)">Empty</span><span style="--c:var(--fault)">Relay fault</span><span style="--c:#e2e8f0">No data</span>
                </div>
            </div>

            <div class="wt-card">
                <h3>LINE alerts</h3>
                <div class="q-row"><span>Messages used this month (all of the OA)</span><span><b id="qUsed">-</b> / <span id="qLimit">-</span></span></div>
                <div class="q-bar" id="qBar"><div style="width:0"></div></div>
                <div class="q-row"><span id="qNote" class="wt-msg"></span><span class="wt-msg" id="qMine"></span></div>
                <ul class="rules" id="rules"></ul>
            </div>

            <div class="wt-card">
                <h3>History</h3>
                <div class="ev-wrap">
                    <table class="ev">
                        <thead><tr><th>Time</th><th>Event</th><th>Detail</th></tr></thead>
                        <tbody id="evBody"></tbody>
                    </table>
                    <div class="empty-note" id="evNone">No events on this day.</div>
                </div>
            </div>
        </div>
    </div>
</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script>
    // @ts-nocheck
    (function () {
        var qs = new URLSearchParams(location.search);
        var TANK = qs.get('tank') || 'Water1';
        var API = location.pathname;
        var LV = {
            full:   { th: 'Full', en: 'Full', hex: '#0ea5e9', h: 0.92, di: [1, 1, 1] },
            normal: { th: 'Normal', en: 'Normal', hex: '#16a34a', h: 0.62, di: [1, 1, 0] },
            low:    { th: 'Low · Near empty', en: 'Low', hex: '#f59e0b', h: 0.28, di: [1, 0, 0] },
            empty:  { th: 'Empty!', en: 'Empty', hex: '#ef4444', h: 0.03, di: [0, 0, 0] },
            fault:  { th: 'Relay fault', en: 'Fault', hex: '#8b5cf6', h: 0.50, di: [0, 1, 0] }
        };
        var $ = function (id) { return document.getElementById(id); };
        var dayIn = $('day'), root = $('wt');
        var timer = null, lastData = null;

        function pad(n) { return (n < 10 ? '0' : '') + n; }
        function ymd(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
        function parse(s) { return s ? new Date(s.replace(' ', 'T')) : null; }
        function hm(s) { return s ? s.substr(11, 5) : '-'; }
        function esc(s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
        function dur(sec) {
            if (sec == null || sec < 0) return '';
            var h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60);
            return (h ? h + ' h ' : '') + m + ' min';
        }

        // คลื่นน้ำ (กว้างกว่าถัง เลื่อนวนไปเรื่อยๆ)
        function wavePath(amp, off) {
            var d = 'M0 ' + off, x;
            for (x = 0; x < 480; x += 60) d += ' Q' + (x + 15) + ' ' + (off - amp) + ' ' + (x + 30) + ' ' + off + ' T' + (x + 60) + ' ' + off;
            return d + ' L480 400 L0 400 Z';
        }
        $('wv1').setAttribute('d', wavePath(6, 6)); $('wv2').setAttribute('d', wavePath(7, 4));

        function paintTank(d) {
            var lv = LV[d.level], hex = lv ? lv.hex : '#cbd5e1';
            var h = lv ? lv.h : 0, top = 40 + 300 * (1 - h) - 6;   // y ของผิวน้ำ
            $('water').style.transform = 'translateY(' + top + 'px)';
            $('wv1').setAttribute('fill', '#38bdf8'); $('wv2').setAttribute('fill', '#7dd3fc');   // น้ำสีฟ้าเสมอ (สีสถานะอยู่ที่ตัวหนังสือ/ขีดระดับ)
            [1, 2, 3].forEach(function (n) {   // Relay ติด = ขีดทึบสีเขียว
                var v = d['di' + n], on = v === 1;
                $('mk-' + n).classList.toggle('cur', on);
                $('mk-' + n).style.setProperty('--c', '#16a34a');
                $('f' + n).setAttribute('fill', on ? '#16a34a' : '#cbd5e1');
                $('s' + n).className = on ? 'on' : '';
                $('s' + n).parentNode.title = v == null ? 'no data' : (on ? 'ON' : 'OFF');
            });

            var st = document.querySelector('.wt-state');
            st.style.setProperty('--c', lv ? hex : '#94a3b8');
            $('lvTxt').textContent = lv ? lv.th : 'No data';
            var since = parse(d.since), now = parse(d.now);
            $('lvSub').textContent = lv ? ('Since ' + hm(d.since) + (since && now ? ' · ' + dur((now - since) / 1000) : '')) : 'Waiting for data from Node-RED';
            root.classList.toggle('blink', d.level === 'empty');
        }

        function paintOnline(d) {
            var b = $('online');
            if (!d.lastSeen) { b.className = 'wt-badge'; b.textContent = 'No data yet'; $('seen').textContent = ''; return; }
            b.className = 'wt-badge ' + (d.online ? 'on' : 'off');
            b.textContent = d.online ? 'Online' : 'Offline';
            $('seen').textContent = 'Last update ' + d.lastSeen.substr(5, 11) + (d.online ? '' : ' (' + dur(d.ageSec) + ' ago — check IoT box / Node-RED)');
        }

        function paintTimeline(d) {
            var tl = $('tl'), day = parse(d.day + ' 00:00:00'), end = new Date(day.getTime() + 864e5), now = parse(d.now);
            var stop = now < end ? now : end, segs = [], cur = d.levelBefore, t0 = day;
            $('tlDay').textContent = d.day;
            d.events.forEach(function (e) {
                if (e.kind !== 'level') return;
                var t = parse(e.at);
                segs.push([t0, t, cur]); t0 = t; cur = e.level;
            });
            segs.push([t0, stop, cur]);
            var html = '', total = 864e5;
            segs.forEach(function (s) {
                var w = (s[1] - s[0]) / total * 100; if (w <= 0) return;
                var lv = LV[s[2]];
                html += '<div style="width:' + w.toFixed(3) + '%;background:' + (lv ? lv.hex : '#e2e8f0') + '" title="' +
                        (lv ? lv.en : 'No data') + ' ' + pad(s[0].getHours()) + ':' + pad(s[0].getMinutes()) + '–' + pad(s[1].getHours()) + ':' + pad(s[1].getMinutes()) + '"></div>';
            });
            if (now < end && now > day) html += '<span class="tl-now" style="left:' + ((now - day) / total * 100).toFixed(2) + '%"></span>';
            tl.innerHTML = html;
        }

        function paintLine(d) {
            var q = d.quota, bar = $('qBar');
            if (q && q.limit != null) {
                var lim = q.type === 'none' ? null : +q.limit, used = +q.used || 0;
                $('qUsed').textContent = used.toLocaleString();
                $('qLimit').textContent = lim ? lim.toLocaleString() : 'unlimited';
                var p = lim ? Math.min(100, used / lim * 100) : 0;
                bar.firstChild.style.width = p + '%';
                bar.className = 'q-bar' + (p >= 100 ? ' full' : p >= 80 ? ' hi' : '');
                $('qNote').textContent = lim ? 'Left ' + Math.max(0, lim - used).toLocaleString() + ' · counted per recipient' : '';
            } else {
                $('qUsed').textContent = '-'; $('qLimit').textContent = '-';
                $('qNote').textContent = q && q.error ? 'Cannot read quota: ' + q.error : 'Quota not available';
            }
            $('qMine').textContent = 'Sent by this tank this month: ' + d.lineMonth;
            var c = d.cfg, r = [];
            r.push('<b>Empty</b> → alert once (no repeat until refilled)');
            if (c.alertLow) r.push('<b>Normal/Full → Low</b> → near-empty warning');
            if (c.alertRefill) r.push('<b>Water back</b> (Normal/Full) after an empty alert');
            r.push('<b>Relay fault</b> (relay pattern out of order)');
            if (c.dailyHour >= 0) r.push('<b>Daily summary</b> at ' + pad(c.dailyHour) + ':00');
            r.push('Same alert not repeated within ' + c.repeatMin + ' min · to: ' + esc(c.to === 'ALL' ? 'all friends of the LINE OA' : c.to));
            $('rules').innerHTML = r.map(function (x) { return '<li>' + x + '</li>'; }).join('');
        }

        var KIND = { full: 'Full', normal: 'Normal', low: 'Low', empty: 'Empty', fault: 'Relay fault', mid: 'Mid' };
        var LTYPE = { empty: '🚨 Empty alert', low: '⚠️ Near-empty alert', mid: '⚠️ Mid alert', refill: '✅ Refill alert', fault: '⚠️ Fault alert', daily: '💧 Daily summary' };
        function paintEvents(d) {
            var rows = d.events.slice().reverse();
            $('evNone').style.display = rows.length ? 'none' : '';
            $('evBody').innerHTML = rows.map(function (e) {
                if (e.kind === 'level') {
                    var lv = LV[e.level];
                    return '<tr><td class="t">' + e.at.substr(11, 8) + '</td><td><span class="pill" style="--c:' + (lv ? lv.hex : '#94a3b8') + '">' +
                           esc(KIND[e.level] || e.level) + '</span></td><td class="ln">' + (e.prev ? 'from ' + esc(KIND[e.prev] || e.prev) : 'first reading') +
                           (e.note === 'test' ? ' · <i>test</i>' : '') + '</td></tr>';
                }
                return '<tr><td class="t">' + e.at.substr(11, 8) + '</td><td>LINE ' + (e.ok ? '✔' : '✖') + '</td><td class="ln' + (e.ok ? '' : ' bad') + '">' +
                       esc(LTYPE[e.prev] || e.prev) + (e.ok ? '' : '\n' + esc((e.note || '').split(' · ')[0])) + '</td></tr>';
            }).join('');
        }

        function load() {
            var day = dayIn.value || ymd(new Date());
            fetch(API + '?format=json&tank=' + encodeURIComponent(TANK) + '&day=' + day, { cache: 'no-store' })
                .then(function (r) { return r.json(); })
                .then(function (d) {
                    if (!d.ok) throw new Error(d.error || 'error');
                    lastData = d;
                    $('msg').className = 'wt-msg'; $('msg').textContent = '';
                    paintTank(d); paintOnline(d); paintTimeline(d); paintLine(d); paintEvents(d);
                })
                .catch(function (e) { $('msg').className = 'wt-msg err'; $('msg').textContent = 'Load failed: ' + e.message; });
        }

        dayIn.value = qs.get('day') || ymd(new Date());
        dayIn.addEventListener('change', load);
        $('today').addEventListener('click', function () { dayIn.value = ymd(new Date()); load(); });

        // ปุ่มจำลอง (?test=1)
        if (qs.get('test') === '1') {
            $('testBar').classList.add('show');
            document.querySelectorAll('[data-sim]').forEach(function (b) {
                b.addEventListener('click', function () {
                    var lv = b.getAttribute('data-sim');
                    var di = LV[lv].di;
                    fetch(API, { method: 'POST', headers: { 'Content-Type': 'application/json' },
                                 body: JSON.stringify({ tank: TANK, level: lv, di1: di[0], di2: di[1], di3: di[2], test: true, notify: $('simLine').checked }) })
                        .then(function (r) { return r.json(); })
                        .then(function (r) { $('msg').className = 'wt-msg'; $('msg').textContent = 'Sim ' + lv + (r.alerts && r.alerts.length ? ' · alert: ' + r.alerts.join(', ') + (r.notify ? ' (LINE sent)' : ' (LINE skipped)') : ''); setTimeout(load, 600); })
                        .catch(function (e) { $('msg').className = 'wt-msg err'; $('msg').textContent = e.message; });
                });
            });
        }

        load();
        timer = setInterval(load, 5000);
    })();
</script>
</asp:Content>
