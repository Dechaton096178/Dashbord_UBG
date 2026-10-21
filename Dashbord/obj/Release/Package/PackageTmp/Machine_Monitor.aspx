<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Machine_Monitor.aspx.cs" Inherits="Dashbord.Machine_Monitor" %>

<%-- =====================================================================
     Machine Monitor
     - เครื่องที่มีข้อมูลจริง (LIVE) : ดึงจาก CounterMachine.aspx?format=json
       (HMI -> Node-RED IoT Box -> CounterMachine.aspx) ดู LIVE_MAP ด้านล่าง
     - เครื่องอื่น ยังเป็นข้อมูลตัวอย่างใน MACHINES (JavaScript ด้านล่าง)
     - ไม่มีไฟล์ .cs (เป็นหน้าแสดงผลอย่างเดียว)
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/flatpickr/4.6.13/flatpickr.min.css" />
<script src="https://cdnjs.cloudflare.com/ajax/libs/flatpickr/4.6.13/flatpickr.min.js"></script>
<style>

    :root {
        --ink:#0f172a;
        --mute:#64748b;
        --line:#e2e8f0;
        --shadow:0 1px 2px rgba(15,23,42,.06), 0 10px 28px rgba(15,23,42,.08);

        --run:#10b981;   --run-bg:#ecfdf5;
        --idle:#f59e0b;  --idle-bg:#fffbeb;
        --down:#ef4444;  --down-bg:#fef2f2;
        --off:#94a3b8;   --off-bg:#f1f5f9;

        --cA:#0284c7; --cP:#7c3aed; --cQ:#059669;
    }

    /* Layout แบบเดียวกับ OEE Dashboard : ซ้าย = ตัวกรอง , ขวา = การ์ดเครื่อง */
    .mon {
        display:grid;
        grid-template-columns:280px minmax(0, 1fr);
        gap:16px;
        padding:16px;
        height:calc(100vh - var(--header-h, 64px));
        min-height:640px;
    }
    .right { min-width:0; min-height:0; overflow:auto; padding-right:2px; }

    /* ================= LEFT : FILTER ================= */
    .side { display:flex; flex-direction:column; gap:14px; min-height:0; overflow:auto; }
    .side > * { flex-shrink:0; }
    .fcard {
        padding:16px;
        background:#fff; border:1px solid var(--line); border-radius:18px;
        box-shadow:var(--shadow);
    }
    .fcard h3 {
        margin:0 0 10px; font-size:15px; font-weight:700;
        display:flex; align-items:center; gap:8px;
    }
    .fcard h3::before {
        content:""; width:9px; height:9px; border-radius:50%;
        background:linear-gradient(135deg,#6366f1,#ec4899);
    }
    .fcard label {
        display:block; margin:12px 0 5px;
        font-size:12px; font-weight:700; letter-spacing:.06em;
        text-transform:uppercase; color:var(--mute);
    }
    .fcard input[type=text], .fcard select {
        width:100%; height:38px; padding:0 12px;
        border:1px solid #cbd5e1; border-radius:10px; background:#f8fafc;
        font:inherit; font-size:14px; color:var(--ink); outline:none;
    }
    .fcard input[type=text]:focus, .fcard select:focus {
        border-color:#6366f1; background:#fff; box-shadow:0 0 0 3px rgba(99,102,241,.18);
    }
    .two { display:grid; grid-template-columns:1fr 1fr; gap:8px; }
    .quick { display:grid; grid-template-columns:1fr 1fr; gap:6px; margin-top:10px; }
    .quick button {
        height:30px; border:1px solid var(--line); border-radius:9px;
        background:#fff; color:var(--mute);
        font:inherit; font-size:12px; font-weight:700; cursor:pointer;
    }
    .quick button:hover, .quick button.on { background:#eef2ff; border-color:#c7d2fe; color:#4338ca; }
    .btn {
        width:100%; height:40px; margin-top:16px;
        border:0; border-radius:10px;
        background:linear-gradient(135deg,#6366f1,#8b5cf6); color:#fff;
        font:inherit; font-size:14px; font-weight:700; cursor:pointer;
        box-shadow:0 6px 16px rgba(99,102,241,.35);
    }

    /* สถานะ (แนวตั้งในแถบซ้าย) */
    .st-list { display:grid; gap:6px; }
    .st-list button {
        display:flex; align-items:center; gap:10px;
        height:38px; padding:0 12px;
        border:1px solid var(--line); border-radius:10px;
        background:#fff; color:var(--ink);
        font:inherit; font-size:13.5px; font-weight:600; cursor:pointer; text-align:left;
    }
    .st-list button i { width:10px; height:10px; border-radius:50%; }
    .st-list button b { margin-left:auto; font-size:13px; color:var(--mute); font-variant-numeric:tabular-nums; }
    .st-list button.on { background:#eef2ff; border-color:#c7d2fe; color:#4338ca; }
    .st-list button.on b { color:#4338ca; }

    .clock { font-size:12.5px; color:var(--mute); margin-top:12px; }
    .clock b { color:var(--ink); font-variant-numeric:tabular-nums; }

    /* ================= TOP BAR ================= */
    .top {
        display:grid;
        grid-template-columns:repeat(4, 1fr) 1.5fr;
        gap:12px;
        margin-bottom:14px;
    }
    .stat {
        position:relative; overflow:hidden;
        padding:10px 14px;
        background:#fff; border:1px solid var(--line); border-radius:14px;
        box-shadow:var(--shadow);
        display:flex; align-items:center; gap:14px;
    }
    .stat .ic {
        width:36px; height:36px; border-radius:10px;
        display:grid; place-items:center; color:#fff; flex-shrink:0;
    }
    .stat b { display:block; font-size:22px; font-weight:800; line-height:1; font-variant-numeric:tabular-nums; }
    .stat span { font-size:12px; font-weight:700; letter-spacing:.08em; color:var(--mute); text-transform:uppercase; }
    .s-run  .ic { background:var(--run); }  .s-run b  { color:var(--run); }
    .s-idle .ic { background:var(--idle); } .s-idle b { color:var(--idle); }
    .s-down .ic { background:var(--down); } .s-down b { color:var(--down); }
    .s-off  .ic { background:var(--off); }  .s-off b  { color:var(--off); }

    .s-oee {
        background:linear-gradient(135deg,#1e1b4b,#312e81 60%,#4338ca);
        color:#fff; border:0;
    }
    .s-oee span { color:#a5b4fc; }
    .s-oee b { color:#fff; font-size:26px; }
    .s-oee em { display:block; font-style:normal; font-size:12px; color:#c7d2fe; margin-top:4px; }
    .s-oee .spark { margin-left:auto; }

    /* ================= TOOLBAR ================= */
    .bar {
        display:flex; align-items:center; gap:10px; flex-wrap:wrap;
        margin-bottom:14px;
    }
    .chips { display:flex; gap:6px; padding:4px; background:#fff; border:1px solid var(--line); border-radius:12px; }
    .chips button {
        display:flex; align-items:center; gap:7px;
        padding:7px 14px; border:0; border-radius:9px;
        background:transparent; color:var(--mute);
        font:inherit; font-size:13px; font-weight:700; cursor:pointer;
    }
    .chips button i { width:8px; height:8px; border-radius:50%; }
    .chips button.on { background:#eef2ff; color:#4338ca; }
    .bar select, .bar input {
        height:38px; padding:0 12px;
        border:1px solid var(--line); border-radius:10px; background:#fff;
        font:inherit; font-size:14px; color:var(--ink); outline:none;
    }
    .bar input { width:220px; }
    .bar .clock { margin-left:auto; font-size:13px; color:var(--mute); }
    .bar .clock b { color:var(--ink); font-variant-numeric:tabular-nums; }

    /* ================= MACHINE GRID ================= */
    .grid {
        display:grid;
        grid-template-columns:repeat(auto-fill, minmax(255px, 1fr));
        gap:12px;
    }

    .mc {
        --st:var(--run); --st-bg:var(--run-bg);
        position:relative;
        background:#fff;
        border:1px solid var(--line);
        border-radius:16px;
        box-shadow:var(--shadow);
        overflow:hidden;
        transition:transform .15s, box-shadow .15s;
    }
    .mc:hover { transform:translateY(-3px); box-shadow:0 18px 40px rgba(15,23,42,.14); }
    .mc::before {
        content:""; position:absolute; left:0; right:0; top:0; height:4px;
        background:var(--st);
    }
    .mc.idle { --st:var(--idle); --st-bg:var(--idle-bg); }
    .mc.down { --st:var(--down); --st-bg:var(--down-bg); }
    .mc.off  { --st:var(--off);  --st-bg:var(--off-bg); }

    .mc-head {
        display:flex; align-items:flex-start; gap:10px;
        padding:12px 14px 4px;
    }
    .mc-head h4 { margin:0; font-size:14px; font-weight:800; letter-spacing:-.01em; }
    .mc-head small { display:block; color:var(--mute); font-size:11.5px; margin-top:1px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:150px; }
    /* ป้าย LIVE = การ์ดที่ใช้ข้อมูลจริงจาก HMI */
    .mc-head h4 .live {
        font-style:normal; font-size:9px; font-weight:800; letter-spacing:.08em;
        color:#fff; background:var(--run); padding:1px 5px; border-radius:4px;
        margin-left:4px; vertical-align:2px;
    }
    .mc.off .mc-head h4 .live { background:var(--off); }
    .pill {
        margin-left:auto; flex-shrink:0;
        display:inline-flex; align-items:center; gap:7px;
        padding:3px 9px; border-radius:999px;
        background:var(--st-bg); color:var(--st);
        font-size:10.5px; font-weight:800; letter-spacing:.04em;
    }
    .pill i { width:8px; height:8px; border-radius:50%; background:var(--st); }
    .mc.run .pill i { animation:blink 1.4s infinite; }
    @keyframes blink {
        0%   { box-shadow:0 0 0 0 rgba(16,185,129,.55); }
        100% { box-shadow:0 0 0 8px rgba(16,185,129,0); }
    }

    /* ---------- หัวข้อ Process ---------- */
    .sec {
        grid-column:1/-1;
        display:flex; align-items:baseline; gap:12px;
        margin-top:6px; padding:4px 2px 0;
        border-bottom:2px solid var(--line);
    }
    .sec:first-child { margin-top:0; }
    .sec h3 { margin:0 0 6px; font-size:16px; font-weight:800; }
    .sec span { font-size:12.5px; color:var(--mute); }
    .sec b { margin-left:auto; font-size:13px; }

    /* ---------- รูปเครื่อง + OEE ---------- */
    .mc-body {
        display:grid; grid-template-columns:1fr 80px; gap:6px; align-items:center;
        padding:2px 12px 4px 8px;
    }
    .art {
        position:relative; height:78px;
        border-radius:12px;
        background:
            radial-gradient(120% 90% at 30% 100%, var(--st-bg) 0%, transparent 70%),
            linear-gradient(180deg,#f8fafc,#fff);
    }
    .art svg { width:100%; height:100%; }

    .oee {
        --v:0;
        position:relative; width:78px; height:78px; border-radius:50%;
        display:grid; place-items:center;
        background:conic-gradient(var(--oc, #6366f1) calc(var(--v) * 1%), #eef2f7 0);
    }
    .oee::after { content:""; position:absolute; inset:8px; border-radius:50%; background:#fff; }
    .oee div { position:relative; z-index:1; text-align:center; }
    .oee b { display:block; font-size:16px; font-weight:800; line-height:1; font-variant-numeric:tabular-nums; color:var(--ink); }
    .oee span { font-size:9px; font-weight:800; letter-spacing:.12em; color:var(--mute); }

    /* ---------- A P Q ---------- */
    .apq { padding:4px 14px 2px; display:grid; gap:5px; }
    .apq .r { display:grid; grid-template-columns:78px 1fr 42px; align-items:center; gap:8px; font-size:11.5px; }
    .apq .r span { color:var(--mute); font-weight:700; }
    .apq .r b { text-align:right; font-variant-numeric:tabular-nums; }
    .apq .t { height:6px; border-radius:99px; background:#f1f5f9; overflow:hidden; }
    .apq .t i { display:block; height:100%; border-radius:99px; }
    .apq .rA i { background:var(--cA); }
    .apq .rP i { background:var(--cP); }
    .apq .rQ i { background:var(--cQ); }

    /* ---------- ข้อมูลเวลา / จำนวน ---------- */
    .mc-foot {
        margin:8px 12px 10px;
        display:grid; grid-template-columns:1fr 1fr; gap:6px;
    }
    .kv {
        padding:6px 9px; border-radius:10px;
        background:#f8fafc; border:1px solid #eef2f7;
    }
    .kv span {
        display:flex; align-items:center; gap:6px;
        font-size:9.5px; font-weight:800; letter-spacing:.02em;
        text-transform:uppercase; color:var(--mute); white-space:nowrap;
    }
    .kv b { display:block; margin-top:2px; font-size:13.5px; font-variant-numeric:tabular-nums; color:var(--ink); }
    .kv.loss b { color:#e11d48; }
    .kv.count b { color:#4338ca; }

    .mc-job {
        display:flex; align-items:center; gap:8px;
        padding:7px 14px; border-top:1px dashed var(--line);
        font-size:11.5px; color:var(--mute);
    }
    .mc-job b { color:var(--ink); font-weight:700; max-width:120px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .mc-job .prog { flex:1; height:6px; border-radius:99px; background:#eef2f7; overflow:hidden; }
    .mc-job .prog i { display:block; height:100%; background:linear-gradient(90deg,#6366f1,#8b5cf6); }

    /* ---------- Animation ของเครื่อง ---------- */
    .mc.run .gear { animation:spin 3s linear infinite; transform-origin:center; transform-box:fill-box; }
    .mc.run .flow { animation:flow 1.2s linear infinite; }
    .mc.run .ram  { animation:ram 2.4s ease-in-out infinite; }
    @keyframes spin { to { transform:rotate(360deg); } }
    @keyframes flow { to { stroke-dashoffset:-16; } }
    @keyframes ram  { 0%,100% { transform:translateX(0); } 50% { transform:translateX(10px); } }
    .lamp { transition:opacity .2s; }

    @media (max-width:1300px) { .top { grid-template-columns:repeat(2, 1fr); } }
    @media (max-width:1000px) {
        .mon { display:block; height:auto; }
        .side { margin-bottom:16px; }
        .top { grid-template-columns:1fr 1fr; }
    }

</style>
</asp:Content>


<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="mon">

    <!-- ================= LEFT : FILTER (แบบเดียวกับ OEE Dashboard) ================= -->
    <div class="side">

        <div class="fcard">
            <h3>Filter</h3>

            <div class="two">
                <div>
                    <label>From</label>
                    <input type="text" id="dFrom" autocomplete="off" />
                </div>
                <div>
                    <label>To</label>
                    <input type="text" id="dTo" autocomplete="off" />
                </div>
            </div>

            <div class="quick" id="quick">
                <button type="button" data-q="today" class="on">Today</button>
                <button type="button" data-q="yesterday">Yesterday</button>
                <button type="button" data-q="7">Last 7 days</button>
                <button type="button" data-q="month">This month</button>
            </div>

            <label>Process</label>
            <select id="proc"><option value="">All processes</option></select>

            <label>Machine</label>
            <input type="text" id="q" placeholder="Search machine..." autocomplete="off" />

            <button type="button" class="btn" id="btnApply">Show Machines</button>

            <div class="clock">Shift day <b id="shift"></b> · <b id="now"></b></div>
        </div>

        <div class="fcard">
            <h3>Status</h3>
            <div class="st-list" id="chips">
                <button type="button" class="on" data-f="all"><i style="background:#6366f1"></i>All machines<b id="nAll">0</b></button>
                <button type="button" data-f="run"><i style="background:var(--run)"></i>Running<b id="nRun">0</b></button>
                <button type="button" data-f="idle"><i style="background:var(--idle)"></i>Idle<b id="nIdle">0</b></button>
                <button type="button" data-f="down"><i style="background:var(--down)"></i>Breakdown<b id="nDown">0</b></button>
                <button type="button" data-f="off"><i style="background:var(--off)"></i>Offline<b id="nOff">0</b></button>
            </div>
        </div>

    </div>


    <!-- ================= RIGHT : สรุป + การ์ดเครื่อง ================= -->
    <div class="right">

        <div class="top">
            <div class="stat s-run">
                <div class="ic"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4l14 8-14 8z"/></svg></div>
                <div><b id="cRun">0</b><span>Running</span></div>
            </div>
            <div class="stat s-idle">
                <div class="ic"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M8 5v14 M16 5v14"/></svg></div>
                <div><b id="cIdle">0</b><span>Idle</span></div>
            </div>
            <div class="stat s-down">
                <div class="ic"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l10 18H2z M12 10v4 M12 17.5v.5"/></svg></div>
                <div><b id="cDown">0</b><span>Breakdown</span></div>
            </div>
            <div class="stat s-off">
                <div class="ic"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M12 3v8 M6.3 7.3a8 8 0 1 0 11.4 0"/></svg></div>
                <div><b id="cOff">0</b><span>Offline</span></div>
            </div>
            <div class="stat s-oee">
                <div>
                    <span>Plant OEE</span>
                    <b id="cOee">0%</b>
                    <em id="cApq">A 0% · P 0% · Q 0%</em>
                </div>
                <svg class="spark" width="130" height="40" viewBox="0 0 150 46" id="spark"></svg>
            </div>
        </div>

        <div class="grid" id="grid"></div>

    </div>

</div>
</asp:Content>


<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script>
    // @ts-nocheck
    (function () {

        // =========================================================
        // ข้อมูลตัวอย่าง (MOCK) — ภายหลังเปลี่ยนเป็นข้อมูลจริงจาก C# / .ashx
        //   status : run | idle | down | off
        //   opMin / lossMin : นาที , start : เวลาเริ่มกะ/งาน
        // =========================================================
        // ---------- สร้างเครื่องตัวอย่างตาม Process (MOCK) ----------
        //   ต่อข้อมูลจริงภายหลัง : แทนที่ MACHINES ด้วยข้อมูลจาก SFT_OP_REALRUN (EQID)
        var PROCESS_MACHINES = [
            { proc: 'Mixing',        prefix: 'MX-',              n: 3,  target: 6000 },
            { proc: 'Extruder',      prefix: 'EX-',              n: 6,  target: 11000 },
            { proc: 'Core Molding',  prefix: 'CM-',              n: 10, target: 17000 },
            { proc: 'Glebar',        prefix: 'GB-',              n: 6,  target: 3000 },
            { proc: 'Mixing Surlyn', prefix: 'MS-',              n: 2,  target: 5000 },
            { proc: 'Injection',     prefix: '1.UB-MC-PV-',      n: 24, target: 20000 },
            { proc: 'Seambuffing',   prefix: 'SB-',              n: 8,  target: 26000 },
            { proc: 'Vanmark',       prefix: 'VM-',              n: 6,  target: 8000 },
            { proc: 'QC Vanmark',    prefix: 'QV-',              n: 3,  target: 8000 },
            { proc: 'Coating',       prefix: 'CT-',              n: 6,  target: 10000 },
            { proc: 'Stamping',      prefix: 'ST-',              n: 6,  target: 6000 },
            { proc: 'QC Coating',    prefix: 'QC-',              n: 3,  target: 10000 },
            { proc: 'Packing',       prefix: 'PK-',              n: 4,  target: 60000 }
        ];
        var BALLS = ['Core Blue PVC White', 'Core Pink PVC White', 'Core Yellow PVC White', 'Core Teal PVC White', 'Core Pink PVC White Stamping'];
        var IDLE_REASON = ['Waiting material', 'Changeover', 'No operator', 'Quality check'];
        var DOWN_REASON = ['Mold repair', 'Heater alarm', 'Hydraulic leak', 'Sensor error'];

        // สุ่มแบบคงที่ (ได้ค่าเดิมทุกครั้งที่เปิดหน้า)
        var seed = 7;
        function rnd() { seed = (seed * 9301 + 49297) % 233280; return seed / 233280; }
        function pick(a) { return a[Math.floor(rnd() * a.length)]; }
        function between(a, b) { return a + rnd() * (b - a); }

        var MACHINES = [];
        PROCESS_MACHINES.forEach(function (pm) {
            for (var i = 1; i <= pm.n; i++) {
                var id = pm.proc === 'Injection'
                    ? pm.prefix + (i <= 12 ? '1-' + i : '2-' + (i - 12))
                    : pm.prefix + ('0' + i).slice(-2);

                var r = rnd();
                var status = r < 0.70 ? 'run' : r < 0.84 ? 'idle' : r < 0.93 ? 'down' : 'off';

                var a = status === 'run' ? between(82, 98) : status === 'idle' ? between(55, 80) : status === 'down' ? between(30, 60) : 0;
                var pf = status === 'off' ? 0 : between(80, 99);
                var q = status === 'off' ? 0 : between(96, 99.9);
                var shiftMin = 554;                                        // 08:00 → ตอนนี้ (ตัวอย่าง)
                var opMin = status === 'off' ? 0 : shiftMin * a / 100;
                var count = Math.round(pm.target * (opMin / 600) * pf / 100);

                MACHINES.push({
                    id: id, proc: pm.proc, status: status,
                    a: a, p: pf, q: q,
                    opMin: opMin, lossMin: status === 'off' ? 0 : shiftMin - opMin,
                    count: count, target: pm.target,
                    start: status === 'off' ? '—' : '08:' + ('0' + Math.floor(rnd() * 20)).slice(-2),
                    job: status === 'run' ? '5101-202609' + ('0' + (10 + Math.floor(rnd() * 20))).slice(-2) + '0' + Math.ceil(rnd() * 5) + '_' + ('00' + Math.floor(rnd() * 200)).slice(-3)
                       : status === 'idle' ? pick(IDLE_REASON)
                       : status === 'down' ? pick(DOWN_REASON) : 'Not scheduled',
                    ball: status === 'run' ? pick(BALLS) : '—'
                });
            }
        });

        var LABEL = { run: 'RUNNING', idle: 'IDLE', down: 'BREAKDOWN', off: 'OFFLINE' };
        var LAMP  = { run: '#10b981', idle: '#f59e0b', down: '#ef4444', off: '#cbd5e1' };

        function fmt(n) { return Number(n || 0).toLocaleString('en-US'); }
        function f1(n) { return Number(n || 0).toFixed(1); }
        function qf(n) { return (Math.floor(Number(n || 0) * 100 + 1e-7) / 100).toFixed(2); }   // Quality: 2 ตำแหน่ง ปัดลง (มี NG จะไม่โชว์ 100%)
        function hm(min) { min = Math.round(min || 0); return Math.floor(min / 60) + 'h ' + ('0' + (min % 60)).slice(-2) + 'm'; }
        function esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;'); }
        // OEE = null เมื่อยังไม่มีค่า A/P/Q ครบ (เครื่อง LIVE ยังไม่มี Performance/Quality)
        function oeeOf(m) { return (m.a == null || m.p == null || m.q == null) ? null : m.a * m.p * m.q / 10000; }
        function oeeColor(v) { return v >= 85 ? '#10b981' : v >= 60 ? '#0ea5e9' : v >= 40 ? '#f59e0b' : '#ef4444'; }


        // =========================================================
        // รูปเครื่องฉีด (SVG) : ไฟสถานะบนเสาเปลี่ยนสีตามสถานะ
        // =========================================================
        function machineSvg(st) {
            var lamp = LAMP[st];
            var dim = function (c) { return c === lamp ? 1 : .18; };
            return '' +
            '<svg viewBox="0 0 260 120" xmlns="http://www.w3.org/2000/svg">' +
              '<defs>' +
                '<linearGradient id="bd" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e2e8f0"/><stop offset="1" stop-color="#cbd5e1"/></linearGradient>' +
                '<linearGradient id="bl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#818cf8"/><stop offset="1" stop-color="#4f46e5"/></linearGradient>' +
              '</defs>' +
              // พื้น + ฐานเครื่อง
              '<ellipse cx="130" cy="110" rx="118" ry="6" fill="#0f172a" opacity=".07"/>' +
              '<rect x="18" y="74" width="224" height="30" rx="6" fill="url(#bd)"/>' +
              '<rect x="18" y="98" width="224" height="6" rx="3" fill="#94a3b8"/>' +
              // หน่วยปิดแม่พิมพ์ (ซ้าย)
              '<rect x="26" y="36" width="70" height="40" rx="6" fill="url(#bl)"/>' +
              '<rect x="34" y="44" width="54" height="24" rx="4" fill="#c7d2fe" opacity=".55"/>' +
              '<g class="ram"><rect x="44" y="50" width="22" height="12" rx="2" fill="#e0e7ff"/></g>' +
              '<line x1="26" y1="42" x2="96" y2="42" stroke="#312e81" stroke-width="2" opacity=".35"/>' +
              '<line x1="26" y1="70" x2="96" y2="70" stroke="#312e81" stroke-width="2" opacity=".35"/>' +
              // แม่พิมพ์
              '<rect x="96" y="40" width="14" height="34" rx="2" fill="#64748b"/>' +
              // กระบอกฉีด (ขวา)
              '<rect x="110" y="50" width="96" height="14" rx="7" fill="#94a3b8"/>' +
              '<line class="flow" x1="116" y1="57" x2="200" y2="57" stroke="#f97316" stroke-width="3" stroke-dasharray="6 10" stroke-linecap="round" opacity=".85"/>' +
              '<rect x="196" y="40" width="34" height="36" rx="5" fill="url(#bl)"/>' +
              '<g class="gear"><circle cx="213" cy="58" r="8" fill="none" stroke="#e0e7ff" stroke-width="3" stroke-dasharray="4 3"/></g>' +
              // Hopper
              '<path d="M142 18 h26 l-7 20 h-12 z" fill="#a5b4fc"/>' +
              '<rect x="150" y="38" width="10" height="12" fill="#818cf8"/>' +
              // หน้าจอควบคุม
              '<rect x="112" y="78" width="40" height="18" rx="3" fill="#1e293b"/>' +
              '<rect x="116" y="82" width="20" height="10" rx="1.5" fill="' + lamp + '" opacity=".75"/>' +
              '<circle cx="144" cy="87" r="3" fill="#475569"/>' +
              // เสาไฟสถานะ
              '<rect x="236" y="20" width="4" height="56" fill="#64748b"/>' +
              '<rect class="lamp" x="232" y="6"  width="12" height="9" rx="2" fill="#ef4444" opacity="' + dim('#ef4444') + '"/>' +
              '<rect class="lamp" x="232" y="15" width="12" height="9" rx="2" fill="#f59e0b" opacity="' + dim('#f59e0b') + '"/>' +
              '<rect class="lamp" x="232" y="24" width="12" height="9" rx="2" fill="#10b981" opacity="' + dim('#10b981') + '"/>' +
            '</svg>';
        }


        // =========================================================
        // การ์ดเครื่องจักร
        // =========================================================
        function card(m) {
            var o = oeeOf(m);
            // เครื่อง LIVE ใช้ % ความคืบหน้าของ Job จาก HMI (Shot Count / Total cycle)
            var pct = m.pct != null ? Math.min(100, m.pct)
                    : (m.target ? Math.min(100, m.count * 100 / m.target) : 0);
            var dimmed = m.status === 'off' || o == null;
            var progTitle = m.live ? m.job : fmt(m.count) + ' / ' + fmt(m.target) + ' pcs';

            return '' +
            '<div class="mc ' + m.status + '" data-id="' + esc(m.id) + '">' +
              '<div class="mc-head">' +
                '<div><h4>' + esc(m.id) + (m.live ? '<em class="live" title="ข้อมูลจริงจาก HMI · อัปเดต ' + esc(m.lastUpdate) + '">LIVE</em>' : '') + '</h4>' +
                '<small title="' + esc(m.ball) + '">' + esc(m.proc) + ' · ' + esc(m.ball) + '</small></div>' +
                '<span class="pill"><i></i>' + LABEL[m.status] + '</span>' +
              '</div>' +

              '<div class="mc-body">' +
                '<div class="art">' + machineSvg(m.status) + '</div>' +
                '<div class="oee" style="--v:' + (dimmed ? 0 : o) + ';--oc:' + oeeColor(o || 0) + '">' +
                  '<div><b>' + (dimmed ? '–' : f1(o) + '%') + '</b><span>OEE</span></div>' +
                '</div>' +
              '</div>' +

              '<div class="apq">' +
                bar('rA', 'Availability', m.a) +
                bar('rP', 'Performance', m.p) +
                bar('rQ', 'Quality', m.q) +
              '</div>' +

              '<div class="mc-foot">' +
                kv('', ico('clock'), 'Operating time', hm(m.opMin)) +
                kv('loss', ico('pause'), 'Loss time', hm(m.lossMin)) +
                kv('count', ico('hash'), 'Count', fmt(m.count) + ' <small style="color:#94a3b8;font-size:12px">pcs</small>') +
                (m.live ? kv('', ico('play'), 'Count Start', esc(shortTime(m.countStart)))
                        : kv('', ico('play'), 'Start', esc(m.start))) +
              '</div>' +

              '<div class="mc-job">' +
                '<span>Job</span><b>' + esc(m.job) + '</b>' +
                '<div class="prog" title="' + esc(progTitle) + '"><i style="width:' + pct + '%"></i></div>' +
                '<span>' + Math.round(pct) + '%</span>' +
              '</div>' +
            '</div>';
        }

        function bar(cls, name, v) {
            return '<div class="r ' + cls + '"><span>' + name + '</span>' +
                   '<div class="t"><i style="width:' + Math.min(100, v || 0) + '%"></i></div>' +
                   '<b>' + (v == null ? '–' : (cls === 'rQ' ? qf(v) : f1(v)) + '%') + '</b></div>';
        }

        function kv(cls, icon, label, value) {
            return '<div class="kv ' + cls + '"><span>' + icon + label + '</span><b>' + value + '</b></div>';
        }

        function ico(n) {
            var p = {
                clock: 'M12 7v5l3 2 M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z',
                pause: 'M9 6v12 M15 6v12',
                hash:  'M5 9h14 M5 15h14 M10 4L8 20 M16 4l-2 16',
                play:  'M7 5l12 7-12 7z'
            }[n];
            return '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="' + p + '"/></svg>';
        }


        // =========================================================
        // สรุปด้านบน + กราฟเส้นเล็ก
        // =========================================================
        function summary() {
            var c = { run: 0, idle: 0, down: 0, off: 0 }, sa = 0, sp = 0, sq = 0, n = 0;
            MACHINES.forEach(function (m) {
                c[m.status]++;
                if (m.status !== 'off' && oeeOf(m) != null) { sa += m.a; sp += m.p; sq += m.q; n++; }
            });
            document.getElementById('nAll').textContent = MACHINES.length;
            document.getElementById('nRun').textContent = c.run;
            document.getElementById('nIdle').textContent = c.idle;
            document.getElementById('nDown').textContent = c.down;
            document.getElementById('nOff').textContent = c.off;
            document.getElementById('cRun').textContent = c.run;
            document.getElementById('cIdle').textContent = c.idle;
            document.getElementById('cDown').textContent = c.down;
            document.getElementById('cOff').textContent = c.off;

            var A = n ? sa / n : 0, P = n ? sp / n : 0, Q = n ? sq / n : 0;
            document.getElementById('cOee').textContent = f1(A * P * Q / 10000) + '%';
            document.getElementById('cApq').textContent = 'A ' + f1(A) + '% · P ' + f1(P) + '% · Q ' + qf(Q) + '%';
        }

        (function spark() {
            var pts = [58, 62, 60, 67, 71, 69, 74, 72, 76, 74];   // OEE รายชั่วโมง (ตัวอย่าง)
            var w = 150, h = 46, max = 100, min = 40;
            var d = pts.map(function (v, i) {
                return (i ? 'L' : 'M') + (i * w / (pts.length - 1)).toFixed(1) + ' ' + (h - (v - min) / (max - min) * h).toFixed(1);
            }).join(' ');
            document.getElementById('spark').innerHTML =
                '<path d="' + d + ' L' + w + ' ' + h + ' L0 ' + h + ' Z" fill="rgba(165,180,252,.22)"/>' +
                '<path d="' + d + '" fill="none" stroke="#a5b4fc" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>';
        })();


        // =========================================================
        // ตัวกรอง + แสดงผล
        // =========================================================
        var filter = 'all';
        var procSel = document.getElementById('proc');

        Array.from(new Set(MACHINES.map(function (m) { return m.proc; }))).forEach(function (p) {
            var o = document.createElement('option'); o.value = p; o.textContent = p; procSel.appendChild(o);
        });

        function render() {
            var q = document.getElementById('q').value.trim().toLowerCase();
            var list = MACHINES.filter(function (m) {
                return (filter === 'all' || m.status === filter) &&
                       (!procSel.value || m.proc === procSel.value) &&
                       (!q || m.id.toLowerCase().indexOf(q) >= 0);
            });
            if (!list.length) {
                document.getElementById('grid').innerHTML =
                    '<div style="grid-column:1/-1;text-align:center;padding:60px;color:#94a3b8">No machines</div>';
                return;
            }

            // แยกหัวข้อตาม Process
            var html = '', lastProc = null;
            list.forEach(function (m) {
                if (m.proc !== lastProc) {
                    var grp = list.filter(function (x) { return x.proc === m.proc; });
                    var on = grp.filter(function (x) { return x.status !== 'off' && oeeOf(x) != null; });
                    var avg = on.length ? on.reduce(function (s, x) { return s + oeeOf(x); }, 0) / on.length : 0;
                    var nr = grp.filter(function (x) { return x.status === 'run'; }).length;
                    html += '<div class="sec"><h3>' + esc(m.proc) + '</h3>' +
                            '<span>' + grp.length + ' machines · ' + nr + ' running</span>' +
                            '<b style="color:' + oeeColor(avg) + '">OEE ' + f1(avg) + '%</b></div>';
                    lastProc = m.proc;
                }
                html += card(m);
            });
            document.getElementById('grid').innerHTML = html;
        }

        document.getElementById('chips').addEventListener('click', function (e) {
            var b = e.target.closest('button'); if (!b) return;
            document.querySelectorAll('#chips button').forEach(function (x) { x.classList.remove('on'); });
            b.classList.add('on');
            filter = b.getAttribute('data-f');
            render();
        });
        procSel.addEventListener('change', render);
        document.getElementById('q').addEventListener('input', render);


        // =========================================================
        // นาฬิกา + จำลองตัวนับเดินทุก 3 วินาที (เฉพาะเครื่องที่ Running)
        // =========================================================
        function tick() {
            var now = new Date(), sd = new Date(now.getTime() - 8 * 3600 * 1000);
            var p = function (n) { return ('0' + n).slice(-2); };
            document.getElementById('shift').textContent = p(sd.getDate()) + '/' + p(sd.getMonth() + 1) + '/' + sd.getFullYear();
            document.getElementById('now').textContent = now.toLocaleTimeString('en-GB');
        }

        setInterval(tick, 1000);
        setInterval(function () {
            MACHINES.forEach(function (m) {
                if (m.status !== 'run' || m.live) return;      // เครื่อง LIVE ไม่จำลอง ใช้ค่าจริง
                m.count += Math.round(5 + Math.random() * 25);
                m.opMin += 0.05;

                // อัปเดตเฉพาะตัวเลข (ไม่วาดการ์ดใหม่ animation จะได้ไม่สะดุด)
                var el = document.querySelector('.mc[data-id="' + m.id + '"]');
                if (!el) return;
                el.querySelector('.kv.count b').innerHTML = fmt(m.count) + ' <small style="color:#94a3b8;font-size:12px">pcs</small>';
                var pct = m.target ? Math.min(100, m.count * 100 / m.target) : 0;
                el.querySelector('.mc-job .prog i').style.width = pct + '%';
                el.querySelector('.mc-job > span:last-child').textContent = Math.round(pct) + '%';
            });
        }, 3000);


        // =========================================================
        // LIVE DATA : ดึงค่าจริงจาก CounterMachine.aspx
        //   HMI -> Node-RED (IoT Box) -> POST CounterMachine.aspx -> หน้านี้
        // =========================================================
        var LIVE_URL = 'CounterMachine.aspx?format=json';
        var LIVE_INTERVAL = 5000;                  // ms
        var LIVE_PROC = 'Injection';               // Process ของเครื่องที่ไม่มีใน LIVE_MAP
        // ชื่อเครื่องที่ Node-RED ส่งมา  ->  รหัสเครื่องในหน้านี้
        var LIVE_MAP = {
            'MC26': '1.UB-MC-PV-2-6',              // PVC 2-6
            'MC17': '1.UB-MC-PV-1-7',              // PVC 1-7
            'MC27': '1.UB-MC-PV-1-1',              // PVC 1-1
            'MC13': '1.UB-MC-PV-1-3',              // PVC 1-3
            'MC14': '1.UB-MC-PV-1-4',              // PVC 1-4
            'MC15': '1.UB-MC-PV-1-5',              // PVC 1-5
            'MC16': '1.UB-MC-PV-1-6',              // PVC 1-6
            'MC18': '1.UB-MC-PV-1-8',              // PVC 1-8
            'MC21': '1.UB-MC-PV-2-1',              // PVC 2-1
            'MC22': '1.UB-MC-PV-2-2',              // PVC 2-2
            'MC23': '1.UB-MC-PV-2-3',              // PVC 2-3
            'MC24': '1.UB-MC-PV-2-4',              // PVC 2-4
            'MC25': '1.UB-MC-PV-2-5',              // PVC 2-5
            'MC28': '1.UB-MC-PV-2-8',              // PVC 2-8
            'MC7':  '1.UB-MC-PV-2-7',              // PVC 2-7
            'MC12': '1.UB-MC-PV-1-2',              // PVC 1-2
            'SB04': 'SB-04',                       // Seambuffing 4
            'SB01': 'SB-01',                       // Seambuffing 4 (รหัสเดิม)
            'SB02': 'SB-02',                       // Seambuffing 2
            'SB03': 'SB-03'                        // Seambuffing 3
        };

        function liveStatus(x) {
            if (!x.online || x.mode === 'offline') return 'off';
            if (x.status >= 17) return 'down';                    // 17-20 = Error
            return x.mode === 'operating' ? 'run' : 'idle';       // 2,4 = run | 0,1,8 = idle
        }

        function shortTime(s) {                                   // "2026-10-06 08:15:30" -> "06/10 08:15"
            var t = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})/.exec(s || '');
            return t ? t[3] + '/' + t[2] + ' ' + t[4] + ':' + t[5] : '—';
        }

        // นำค่าจาก JSON ไปใส่ใน MACHINES  (คืนค่า true = ต้องวาดหน้าใหม่)
        function applyLive(x) {
            var id = LIVE_MAP[x.machine] || x.machine;
            var m = MACHINES.filter(function (k) { return k.id === id; })[0];
            var isNew = !m;
            if (isNew) {
                m = { id: id, proc: LIVE_PROC };
                var last = -1;
                MACHINES.forEach(function (k, i) { if (k.proc === LIVE_PROC) last = i; });
                MACHINES.splice(last >= 0 ? last + 1 : MACHINES.length, 0, m);
            }
            var prev = m.status;
            var st = liveStatus(x);

            m.live = true;
            m.status = st;
            m.a = x.availability;                  // จากเวลาเดินเครื่อง / เวลาทั้งหมดของวัน
            m.p = null;                            // ยังไม่มีข้อมูล Performance
            m.q = x.quality != null ? x.quality : null;   // Quality จาก OK/NG (ถ้าเครื่องส่งมา)
            m.opMin = (x.operatingHours || 0) * 60;
            m.lossMin = ((x.lossHours || 0) + (x.offlineHours || 0)) * 60;
            // Count = Counter Shot บนจอ HMI x Cavity (ให้ตรงกับเลขบนเครื่อง)
            m.count = x.piecesCounter != null ? x.piecesCounter
                    : (x.shotCount || 0) * (x.cavities > 0 ? x.cavities : 1);
            m.target = x.targetShots || 0;
            m.pct = x.jobProgress != null ? x.jobProgress : 0;
            m.start = shortTime(x.jobStart);
            m.countStart = x.countStart;           // เวลาเริ่มนับยอดของวันนี้
            m.job = st === 'off' ? 'No signal'
                  : 'Shot ' + fmt(x.shotCount) + (x.targetShots ? ' / ' + fmt(x.targetShots) : '');
            m.ball = x.machine + ' · Op ' + (x.operator || '–') + ' · CT ' + (x.cycleTime != null ? Number(x.cycleTime).toFixed(1) + 's' : '–') +
                     (x.jobFinish ? ' · Finish ' + shortTime(x.jobFinish) : '');
            m.lastUpdate = x.lastUpdate;

            return isNew || prev !== st;
        }

        // อัปเดตการ์ดเดิม โดยไม่แตะรูปเครื่อง (animation ไม่สะดุด)
        function patchCard(m) {
            var el = document.querySelector('.mc[data-id="' + m.id + '"]');
            if (!el) return;
            var t = document.createElement('div');
            t.innerHTML = card(m);
            var n = t.firstChild;
            ['.mc-head', '.oee', '.apq', '.mc-foot', '.mc-job'].forEach(function (s) {
                var a = el.querySelector(s), b = n.querySelector(s);
                if (a && b) a.parentNode.replaceChild(b, a);
            });
        }

        function pollLive() {
            if (!window.fetch) return;
            fetch(LIVE_URL, { cache: 'no-store' })
                .then(function (r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
                .then(function (d) {
                    var redraw = false;
                    (d.machines || []).forEach(function (x) { if (applyLive(x)) redraw = true; });
                    summary();
                    if (redraw) render();
                    else MACHINES.forEach(function (m) { if (m.live) patchCard(m); });
                })
                .catch(function (e) {
                    // ติดต่อ CounterMachine.aspx ไม่ได้ -> เครื่อง LIVE แสดง Offline
                    var redraw = false;
                    MACHINES.forEach(function (m) {
                        if (m.live && m.status !== 'off') { m.status = 'off'; m.job = 'No live data'; redraw = true; }
                    });
                    if (redraw) { summary(); render(); }
                    if (window.console) console.warn('Live data:', e);
                });
        }

        // =========================================================
        // วันที่ From / To (dd/mm/yyyy) + ปุ่มลัด  — ดีไซน์ (ยังไม่กรองข้อมูลจริง)
        // =========================================================
        function shiftToday() { var d = new Date(); d.setHours(d.getHours() - 8); d.setHours(0, 0, 0, 0); return d; }
        var fpF = null, fpT = null;
        if (window.flatpickr) {
            fpF = flatpickr('#dFrom', { dateFormat: 'd/m/Y', defaultDate: shiftToday() });
            fpT = flatpickr('#dTo',   { dateFormat: 'd/m/Y', defaultDate: shiftToday() });
        }
        document.getElementById('quick').addEventListener('click', function (e) {
            var b = e.target.closest('button'); if (!b) return;
            document.querySelectorAll('#quick button').forEach(function (x) { x.classList.remove('on'); });
            b.classList.add('on');
            var q = b.getAttribute('data-q'), t = shiftToday(), f = new Date(t);
            if (q === 'yesterday') { t.setDate(t.getDate() - 1); f = new Date(t); }
            else if (q === '7') { f.setDate(f.getDate() - 6); }
            else if (q === 'month') { f = new Date(t.getFullYear(), t.getMonth(), 1); }
            if (fpF) { fpF.setDate(f); fpT.setDate(t); }
        });
        document.getElementById('btnApply').addEventListener('click', render);

        tick(); summary(); render();
        pollLive();
        setInterval(pollLive, LIVE_INTERVAL);

    })();
</script>
</asp:Content>
