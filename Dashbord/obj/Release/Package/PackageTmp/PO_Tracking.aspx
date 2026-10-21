<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="PO_Tracking.aspx.cs" Inherits="Dashbord.PO_Tracking" Title="PO Tracking" %>

<%-- =====================================================================
     PO Tracking : which process has this PO reached
     - สรุป PO / ขั้นตอนการผลิต (stepper) / Yield / NG ตามสาเหตุ / Batch × Process / รายละเอียด
     - ข้อมูล : PO_Tracking.aspx?format=json&po=...  (EMES_UNIVERSAL : SFT_OP_REALRUN, SFT_OP_EXCEPT)
     - ลิงก์ตรง : PO_Tracking.aspx?po=4500762127
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<style>
    .pt { --bg:#eef2f7; --card:#fff; --ink:#0f172a; --ink2:#334155; --mute:#64748b; --line:#e2e8f0; --soft:#f8fafc;
          --acc:#4f46e5; --acc2:#0ea5e9; --done:#10b981; --wip:#3b82f6; --part:#f59e0b; --ng:#e11d48; --wait:#94a3b8;
          --shadow:0 1px 2px rgba(15,23,42,.05), 0 8px 24px rgba(15,23,42,.06);
          padding:16px; background:var(--bg); color:var(--ink); font-variant-numeric:tabular-nums; min-height:calc(100vh - 64px); }
    .pt * { box-sizing:border-box; }
    .card { background:var(--card); border:1px solid var(--line); border-radius:16px; box-shadow:var(--shadow); padding:16px 18px; margin-bottom:14px; }
    .card h3 { margin:0 0 12px; font-size:15px; font-weight:800; display:flex; align-items:center; gap:8px; }
    .card h3::before { content:""; width:4px; height:16px; border-radius:4px; background:linear-gradient(180deg,var(--acc2),var(--acc)); }
    .card h3 small { margin-left:auto; font-size:12px; font-weight:600; color:var(--mute); }

    /* ---------- ค้นหา ---------- */
    .search { display:flex; flex-wrap:wrap; gap:10px; align-items:flex-end; }
    .search h2 { margin:0 16px 0 0; font-size:21px; font-weight:800; align-self:center; }
    .fld label { display:block; font-size:11.5px; font-weight:700; color:var(--mute); text-transform:uppercase; letter-spacing:.05em; margin-bottom:4px; }
    .fld input { height:38px; border:1px solid #cbd5e1; border-radius:10px; padding:0 12px; font:inherit; font-size:14px; background:var(--soft); min-width:240px; outline:none; }
    .fld input:focus { border-color:var(--acc); background:#fff; box-shadow:0 0 0 3px rgba(79,70,229,.15); }
    .btn { height:38px; border:0; border-radius:10px; padding:0 20px; font:inherit; font-size:14px; font-weight:700; color:#fff; cursor:pointer;
           background:linear-gradient(135deg,#6366f1,#8b5cf6); box-shadow:0 6px 16px rgba(99,102,241,.3); }
    .btn.ghost { background:#fff; color:var(--ink2); border:1px solid var(--line); box-shadow:none; }
    .recent { display:flex; flex-wrap:wrap; gap:6px; margin-top:12px; align-items:center; font-size:12px; color:var(--mute); }
    .chip { border:1px solid var(--line); background:var(--soft); border-radius:99px; padding:3px 10px; font-size:12.5px; font-weight:600; color:var(--ink2); cursor:pointer; }
    .chip:hover { border-color:var(--acc); color:var(--acc); }
    .msg { padding:40px; text-align:center; color:var(--mute); font-size:15px; }
    .msg.err { color:var(--ng); }

    /* ---------- สรุป PO ---------- */
    .hero { display:grid; grid-template-columns:minmax(260px, 1.2fr) 3fr; gap:18px; align-items:center;
            background:linear-gradient(135deg,#1e1b4b,#312e81 60%,#4338ca); color:#fff; border:0; }
    .hero .po { font-size:13px; color:#c7d2fe; font-weight:700; letter-spacing:.04em; }
    .hero .po b { display:block; font-size:28px; color:#fff; letter-spacing:-.01em; margin:2px 0 6px; word-break:break-all; }
    .hero .ball { font-size:13px; color:#e0e7ff; }
    .pill { display:inline-flex; align-items:center; gap:6px; border-radius:99px; padding:4px 12px; font-size:13px; font-weight:800; margin-top:10px; }
    .pill.fin { background:#d1fae5; color:#065f46; } .pill.run { background:#dbeafe; color:#1e40af; }
    .pill i { width:8px; height:8px; border-radius:50%; background:currentColor; }
    .pill.run i { animation:ptPulse 1.6s infinite; }
    @keyframes ptPulse { 50% { opacity:.3; } }
    .kpis { display:grid; grid-template-columns:repeat(6, minmax(0,1fr)); gap:10px; }
    .kpi { background:rgba(255,255,255,.08); border:1px solid rgba(255,255,255,.16); border-radius:12px; padding:10px 12px; min-width:0; }
    .kpi span { display:block; font-size:11px; font-weight:700; color:#c7d2fe; text-transform:uppercase; letter-spacing:.04em; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .kpi b { display:block; font-size:20px; font-weight:800; margin-top:3px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .kpi em { display:block; font-style:normal; font-size:11.5px; color:#c7d2fe; margin-top:1px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }

    /* ---------- Stepper ---------- */
    .steps { display:flex; gap:0; overflow-x:auto; padding:4px 2px 8px; }
    .step { flex:1 0 190px; position:relative; padding:0 6px; cursor:pointer; }
    .step::before { content:""; position:absolute; top:22px; left:-50%; width:100%; height:3px; background:var(--line); z-index:0; }
    .step:first-child::before { display:none; }
    .step.done::before, .step.partial::before, .step.wip::before { background:var(--done); }
    .dot { position:relative; z-index:1; width:44px; height:44px; border-radius:50%; margin:0 auto; display:grid; place-items:center;
           font-weight:800; font-size:13px; color:#fff; background:var(--wait); border:4px solid #fff; box-shadow:0 0 0 2px var(--line); }
    .step.done .dot { background:var(--done); } .step.partial .dot { background:var(--part); } .step.wip .dot { background:var(--wip); animation:ptRing 1.8s infinite; }
    @keyframes ptRing { 0%,100% { box-shadow:0 0 0 2px rgba(59,130,246,.35); } 50% { box-shadow:0 0 0 8px rgba(59,130,246,.08); } }
    .sbox { margin-top:8px; border:1px solid var(--line); border-radius:12px; padding:10px 10px 8px; background:var(--soft); text-align:center; transition:.15s; }
    .step.sel .sbox { border-color:var(--acc); box-shadow:0 0 0 3px rgba(79,70,229,.15); background:#fff; }
    .sbox h4 { margin:0; font-size:14px; font-weight:800; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .sbox .st { font-size:11.5px; font-weight:800; margin:2px 0 6px; }
    .st.done { color:var(--done); } .st.partial { color:#b45309; } .st.wip { color:var(--wip); }
    .sbox .nums { display:grid; grid-template-columns:1fr 1fr; gap:2px 8px; font-size:12px; text-align:left; }
    .sbox .nums span { color:var(--mute); } .sbox .nums b { text-align:right; }
    .sbox .nums b.ng { color:var(--ng); }
    .sbox .tm { font-size:11px; color:var(--mute); margin-top:6px; line-height:1.45; border-top:1px dashed var(--line); padding-top:5px; }

    .legend { display:flex; gap:14px; flex-wrap:wrap; font-size:12px; color:var(--ink2); margin-top:8px; }

    .two { display:grid; grid-template-columns:1fr 1fr; gap:14px; }
    .yrow { display:grid; grid-template-columns:150px 1fr 90px; gap:10px; align-items:center; font-size:12.5px; margin:6px 0; }
    .yrow .nm { font-weight:700; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .ytrack { position:relative; height:20px; background:#f1f5f9; border-radius:6px; overflow:hidden; }
    .ytrack i { position:absolute; left:0; top:0; bottom:0; border-radius:6px; }
    .ytrack i.in { background:#c7d2fe; } .ytrack i.ok { background:#6366f1; }
    .yrow .v { text-align:right; color:var(--ink2); font-weight:700; }
    .step b.loss { color:#d97706; }
    .step b.diff { color:#7c3aed; cursor:help; }
    .step b.na { color:#0284c7; cursor:help; }
    .step b.wipn { cursor:help; }
    td.diffc { color:#7c3aed; font-weight:700; cursor:help; }
    .parts { display:inline-block; font-size:10.5px; font-weight:800; color:#1e40af; background:#dbeafe; border-radius:6px; padding:0 5px; cursor:help; }
    .ngp { margin:0 0 12px; } .ngp h5 { margin:0 0 4px; font-size:13px; display:flex; justify-content:space-between; }
    .ngp h5 span { color:var(--ng); }
    .ngr { display:grid; grid-template-columns:1fr 120px 54px; gap:8px; align-items:center; font-size:12px; margin:3px 0; }
    .ngr .t { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; color:var(--ink2); }
    .ngr .b { height:8px; background:#ffe4e6; border-radius:4px; overflow:hidden; } .ngr .b i { display:block; height:100%; background:var(--ng); border-radius:4px; }
    .ngr .q { text-align:right; font-weight:700; }

    /* ---------- ตาราง ---------- */
    .tbl { overflow:auto; max-height:520px; border:1px solid var(--line); border-radius:12px; }
    table.t { border-collapse:separate; border-spacing:0; width:100%; font-size:12.5px; }
    table.t th { position:sticky; top:0; background:#f1f5f9; z-index:1; text-align:left; padding:8px 10px; font-size:11.5px; font-weight:700; color:var(--mute);
                 text-transform:uppercase; letter-spacing:.03em; border-bottom:1px solid var(--line); white-space:nowrap; }
    table.t td { padding:7px 10px; border-bottom:1px solid #f1f5f9; white-space:nowrap; }
    table.t td.r, table.t th.r { text-align:right; }
    table.t tr:hover td { background:#f8fafc; }
    table.t tfoot td { position:sticky; bottom:0; z-index:1; background:#eef2ff; font-weight:800; color:var(--ink, #0f172a); border-top:2px solid #6366f1; border-bottom:0; }
    table.t .sub2, table.t tfoot td .sub2 { display:block; font-size:10.5px; font-weight:600; color:var(--mute); }
    .mx td.c { text-align:center; font-size:11.5px; font-weight:700; }
    .cell { display:inline-block; min-width:74px; padding:3px 6px; border-radius:7px; }
    .cell.done { background:#d1fae5; color:#065f46; } .cell.wip { background:#dbeafe; color:#1e40af; } .cell.none { color:#cbd5e1; }
    .cell.wait { background:#f1f5f9; color:#475569; border:1px dashed #94a3b8; padding:2px 5px; cursor:help; }
    .mxf { display:flex; align-items:center; gap:6px; flex-wrap:wrap; margin-bottom:8px; font-size:12.5px; color:var(--ink2); }
    .mxf button { border:1px solid var(--line); background:#fff; border-radius:99px; padding:3px 11px; font:inherit; font-size:12px; font-weight:700; color:var(--ink2); cursor:pointer; }
    .mxf button.on { background:#eef2ff; border-color:#c7d2fe; color:var(--acc); }
    .mxf .lg { margin-left:auto; display:flex; gap:8px; align-items:center; color:#64748b; }
    .mxf .lg .cell { min-width:0; font-size:11px; }
    .tag { font-size:11px; font-weight:800; padding:2px 8px; border-radius:99px; }
    .tag.finished { background:#d1fae5; color:#065f46; } .tag.wip { background:#dbeafe; color:#1e40af; } .tag.waiting { background:#fef3c7; color:#92400e; }
    .procsel { display:inline-flex; align-items:center; gap:6px; margin-left:10px; font-size:12.5px; font-weight:700; color:#475569; }
    .procsel select { font:inherit; font-size:13px; font-weight:600; padding:5px 8px; border:1px solid #c7d2fe; border-radius:8px; background:#fff; color:#1e1b4b; max-width:240px; }
    .tabs { display:flex; gap:6px; margin-bottom:10px; }
    .tabs button { border:1px solid var(--line); background:#fff; border-radius:9px; padding:6px 14px; font:inherit; font-size:13px; font-weight:700; color:var(--ink2); cursor:pointer; }
    .tabs button.on { background:#eef2ff; border-color:#c7d2fe; color:var(--acc); }
    .tabs .sp { flex:1; }

    .tip { position:fixed; z-index:60; pointer-events:none; background:#0f172a; color:#f8fafc; border-radius:10px; padding:8px 11px; font-size:12.5px; line-height:1.55;
           box-shadow:0 10px 30px rgba(0,0,0,.3); display:none; max-width:320px; }
    .tip .mu { color:#94a3b8; }

    @media (max-width:1100px) { .hero { grid-template-columns:1fr; } .kpis { grid-template-columns:repeat(3,minmax(0,1fr)); } .two { grid-template-columns:1fr; } }
    @media (max-width:600px)  { .kpis { grid-template-columns:repeat(2,minmax(0,1fr)); } .fld input { min-width:0; width:100%; } .fld { flex:1 1 100%; } }
    /* ---------- คู่มือ (popup) ---------- */
    .gd-back { position:fixed; inset:0; z-index:9999; background:rgba(15,23,42,.55); display:none; align-items:center; justify-content:center; padding:16px; }
    .gd-back.open { display:flex; }
    .gd { width:min(1000px, 100%); max-height:min(92vh, 1100px); display:flex; flex-direction:column; background:#fff; color:var(--ink); border-radius:16px; box-shadow:0 30px 80px rgba(0,0,0,.35); overflow:hidden; }
    .gd-h { display:flex; align-items:center; gap:12px; padding:14px 18px; border-bottom:1px solid var(--line); }
    .gd-h h3 { margin:0; font-size:18px; font-weight:800; flex:1; }
    .gd-lang { display:flex; border:1px solid var(--line); border-radius:9px; overflow:hidden; }
    .gd-lang button { border:0; background:#fff; font:inherit; font-size:13px; font-weight:700; padding:6px 12px; color:var(--ink2); cursor:pointer; }
    .gd-lang button.on { background:#eef2ff; color:var(--acc); }
    .gd-x { border:0; background:#f1f5f9; width:34px; height:34px; border-radius:9px; font-size:20px; cursor:pointer; color:var(--ink2); }
    .gd-nav { display:flex; gap:6px; flex-wrap:wrap; padding:10px 18px; border-bottom:1px solid var(--line); background:#f8fafc; }
    .gd-nav a { font-size:12.5px; font-weight:700; color:var(--ink2); text-decoration:none; padding:4px 10px; border-radius:99px; border:1px solid var(--line); background:#fff; }
    .gd-nav a:hover { border-color:var(--acc); color:var(--acc); }
    .gd-body { padding:16px 22px 24px; overflow:auto; font-size:14px; line-height:1.6; }
    .gd-body h4 { font-size:16px; font-weight:800; margin:22px 0 8px; padding-top:4px; scroll-margin-top:8px; }
    .gd-body img { display:block; max-width:100%; border:1px solid var(--line); border-radius:10px; margin:8px 0 10px; }
    .gd-body img.gd-narrow { max-width:620px; }
    .gd-body table { width:100%; border-collapse:collapse; margin:8px 0 10px; font-size:13.5px; }
    .gd-body th, .gd-body td { border-bottom:1px solid var(--line); padding:6px 8px; text-align:left; vertical-align:top; }
    .gd-body th { font-size:12px; color:var(--mute); text-transform:uppercase; background:#f8fafc; }
    .gd-body code { background:#f1f5f9; border-radius:5px; padding:1px 5px; font-size:12.5px; }
    .gd-body ol { padding-left:22px; margin:6px 0 10px; }
    .gd-body dt { font-weight:800; margin-top:8px; } .gd-body dd { margin:2px 0 6px 16px; color:var(--ink2); }
    .gd-lead { background:#eef2ff; border-radius:10px; padding:10px 14px; margin:0 0 4px; }
    .gd-tip { background:#fffbeb; border:1px solid #fde68a; border-radius:10px; padding:8px 12px; margin:8px 0; }
    .gd-foot { color:var(--mute); font-size:12px; margin-top:18px; }
    .gd-cell { display:inline-block; min-width:70px; padding:2px 6px; border-radius:7px; font-size:12.5px; font-weight:700; text-align:center; }
    .gd-cell.done { background:#d1fae5; color:#065f46; } .gd-cell.wip { background:#dbeafe; color:#1e40af; } .gd-cell.wait { background:#f1f5f9; color:#475569; border:1px dashed #94a3b8; } .gd-cell.none { color:#94a3b8; }
    .gd[data-l="th"] [data-lang="en"], .gd[data-l="en"] [data-lang="th"] { display:none; }
    @media (max-width:640px) { .gd-h h3 { font-size:15px; } .gd-body { padding:12px 14px 20px; } }
</style>
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="pt" id="ptRoot">
    <div class="card">
        <div class="search">
            <h2>PO Tracking</h2>
            <div class="fld"><label>PO Number</label><input id="inPo" list="poList" placeholder="e.g. 4500762127" autocomplete="off" /></div>
            <div class="fld"><label>or Batch / MO</label><input id="inBatch" placeholder="(optional)" autocomplete="off" style="min-width:180px" /></div>
            <button type="button" class="btn" id="btnGo">Search</button>
            <button type="button" class="btn ghost" id="btnRefresh" title="Reload latest data">⟳</button>
            <button type="button" class="btn ghost" id="btnGuide" title="คู่มือการใช้งาน / User Guide">📖 User Guide</button>
            <datalist id="poList"></datalist>
        </div>
        <div class="recent" id="recent"></div>
    </div>

    <div id="out"><div class="card msg">Enter a PO number and press Search, or pick a recent PO above</div></div>
    <div class="tip" id="tip"></div>
    <!-- ===== คู่มือการใช้งาน (popup) ===== -->
    <div class="gd-back" id="gdBack" aria-hidden="true">
        <div class="gd" role="dialog" aria-modal="true" aria-labelledby="gdTitle">
            <div class="gd-h">
                <h3 id="gdTitle">📖 PO Tracking — <span data-lang="th">คู่มือการใช้งาน</span><span data-lang="en">User Guide</span></h3>
                <div class="gd-lang"><button type="button" data-l="th" class="on">ไทย</button><button type="button" data-l="en">English</button></div>
                <button type="button" class="gd-x" id="gdClose" title="Close (Esc)">×</button>
            </div>
            <div class="gd-nav" id="gdNav">
                <a href="#gd1">1 <span data-lang="th">ค้นหา</span><span data-lang="en">Search</span></a>
                <a href="#gd2">2 <span data-lang="th">สรุป PO</span><span data-lang="en">Summary</span></a>
                <a href="#gd3">3 <span data-lang="th">การ์ดขั้นตอน</span><span data-lang="en">Stages</span></a>
                <a href="#gd4">4 <span data-lang="th">กราฟ</span><span data-lang="en">Charts</span></a>
                <a href="#gd5">5 <span data-lang="th">ตาราง</span><span data-lang="en">Tables</span></a>
                <a href="#gd6">6 <span data-lang="th">คำศัพท์</span><span data-lang="en">Glossary</span></a>
                <a href="#gd7">7 FAQ</a>
            </div>
            <div class="gd-body" id="gdBody">
                <p class="gd-lead" data-lang="th">PO Tracking แสดงว่า PO ผลิตไปถึงขั้นไหนแล้ว ทุก Batch อยู่ที่ไหน ได้ของดี เสีย และหายเท่าไหร่ในแต่ละขั้น ข้อมูลดึงสดจาก ERP (บันทึก Check-In / Check-Out ของแต่ละ Batch) · วันผลิต 08:00 → 08:00</p>
                <p class="gd-lead" data-lang="en">PO Tracking shows how far a PO has progressed, where every batch is, and the good, NG and lost quantities at each stage. Data comes live from the ERP (each batch's check-in / check-out) · production day 08:00 → 08:00.</p>

                <h4 id="gd1">1. <span data-lang="th">การค้นหา</span><span data-lang="en">How to search</span></h4>
                <img src="images/guide/po_search.png" alt="Search" loading="lazy" />
                <ol data-lang="th">
                    <li>พิมพ์เลข PO ในช่อง <b>PO Number</b> เช่น <code>4500774321</code> แล้วกด <b>Search</b> หรือ Enter · พิมพ์บางส่วนจะมีรายการให้เลือก (PO หนึ่งอาจแยกเป็นชุด เช่น <code>PO # 4500774321 (1)</code>)</li>
                    <li>หรือกดปุ่ม PO ล่าสุดใต้ช่องค้นหา</li>
                    <li>รู้แค่เลข Batch ให้ใส่ช่อง <b>or Batch / MO</b> เช่น <code>5101-2026101001_011</code></li>
                    <li>ปุ่ม <b>⟳</b> = โหลดข้อมูลล่าสุดจาก ERP · คัดลอกลิงก์ส่งต่อได้เลย (ลิงก์มีเลข PO อยู่แล้ว)</li>
                </ol>
                <ol data-lang="en">
                    <li>Type a PO in <b>PO Number</b>, e.g. <code>4500774321</code>, then press <b>Search</b> or Enter. Typing part of it shows a list (one PO may be split into sets such as <code>PO # 4500774321 (1)</code>).</li>
                    <li>Or click a recent PO chip under the search bar.</li>
                    <li>If you only know the batch, enter it in <b>or Batch / MO</b>, e.g. <code>5101-2026101001_011</code>.</li>
                    <li><b>⟳</b> reloads the latest ERP data. The link already contains the PO, so you can share it.</li>
                </ol>

                <h4 id="gd2">2. <span data-lang="th">การ์ดสรุป PO</span><span data-lang="en">PO summary</span></h4>
                <img src="images/guide/po_summary.png" alt="Summary" loading="lazy" />
                <table>
                    <tr><th></th><th data-lang="th">ความหมาย</th><th data-lang="en">Meaning</th></tr>
                    <tr><td><b>Batch</b></td><td data-lang="th">Batch ที่ Packing แล้ว / ทั้งหมด และจำนวนที่อยู่บนเครื่อง</td><td data-lang="en">Packed batches / all batches, and how many are on machines</td></tr>
                    <tr><td><b>Current stage</b></td><td data-lang="th">ขั้นที่ไกลที่สุดที่มี Batch ไปถึง</td><td data-lang="en">Furthest stage any batch has reached</td></tr>
                    <tr><td><b>Started / Lead time</b></td><td data-lang="th">เริ่มเมื่อไหร่ และใช้เวลามาแล้วกี่วัน</td><td data-lang="en">When it started and how long so far</td></tr>
                    <tr><td><b>Good at latest stage</b></td><td data-lang="th">ยอดดีขั้นล่าสุด เทียบยอดเข้าขั้นแรก</td><td data-lang="en">Good at the latest stage vs. first-stage input</td></tr>
                    <tr><td><b>Total NG</b></td><td data-lang="th">NG รวมทุกขั้น และ Loss รวม</td><td data-lang="en">NG of all stages, plus total Loss</td></tr>
                </table>

                <h4 id="gd3">3. <span data-lang="th">การ์ดขั้นตอนการผลิต</span><span data-lang="en">Production Stages</span></h4>
                <img src="images/guide/po_stages.png" alt="Stages" loading="lazy" />
                <p data-lang="th">1 การ์ด = 1 ขั้นตอน เรียงตามลำดับการผลิต · วงกลมสีเขียว = <b>✓ Done</b> (ทุก Batch มาถึงและ Check-Out ครบ) · สีส้ม = ยังไม่ครบ · <b>คลิกการ์ด</b>เพื่อกรองตารางด้านล่างเฉพาะขั้นนั้น คลิกซ้ำเพื่อยกเลิก</p>
                <p data-lang="en">One card per stage, in production order. Green circle = <b>✓ Done</b> (every batch arrived and checked out); orange = not complete. <b>Click a card</b> to filter the tables to that stage; click again to clear.</p>
                <img src="images/guide/po_card.png" alt="Card" loading="lazy" class="gd-narrow" />
                <ol data-lang="th">
                    <li><b>สถานะ</b> — ◐ Done 106/140 = เสร็จ 106 จาก 140 Batch</li>
                    <li><b>In / Good / NG / Loss</b> — รับเข้า / ได้ดี / เสีย (% ของ Good+NG) / หาย (% ของ In) · <b>Other ⓘ</b> = ยอดที่ยังรอ Check-Out หรือส่งคืน</li>
                    <li><b>In progress ⏳</b> — Batch ที่ Check-In ที่ขั้นนี้แล้ว กำลังผลิต</li>
                    <li><b>Not arrived ⓘ</b> — Batch ที่ยังค้างอยู่ขั้นก่อนหน้า ยังไม่ Check-In ที่ขั้นนี้</li>
                    <li><b>Batch</b> — เสร็จ / ทั้งหมด (106 + 8 + 26 = 140)</li>
                    <li><b>เวลาและเครื่อง</b> — Check-In แรก → Check-Out สุดท้าย และเครื่องที่ใช้</li>
                </ol>
                <ol data-lang="en">
                    <li><b>Status</b> — ◐ Done 106/140 = 106 of 140 batches done</li>
                    <li><b>In / Good / NG / Loss</b> — received / good / NG (% of Good+NG) / loss (% of In). <b>Other ⓘ</b> = pending check-out or returned</li>
                    <li><b>In progress ⏳</b> — batches checked in here and still running</li>
                    <li><b>Not arrived ⓘ</b> — batches still at an earlier stage, not checked in here yet</li>
                    <li><b>Batch</b> — done / all (106 + 8 + 26 = 140)</li>
                    <li><b>Time and machines</b> — first check-in → last check-out, machines used</li>
                </ol>
                <div class="gd-tip" data-lang="th">💡 <b>เอาเมาส์ชี้ ⓘ</b> จะเห็นเลข Batch แต่ละตัว อยู่ขั้นไหน และค้างตั้งแต่เมื่อไหร่ · ถ้า Good ของขั้นก่อนมากกว่า In ของขั้นถัดไปประมาณ 1 Batch (~1,600 ชิ้น) ให้ดู Not arrived ของขั้นถัดไป</div>
                <div class="gd-tip" data-lang="en">💡 <b>Hover ⓘ</b> to see each batch, where it is and since when. If one stage's Good exceeds the next stage's In by about one batch (~1,600 pcs), check Not arrived on the next stage.</div>

                <h4 id="gd4">4. <span data-lang="th">กราฟ</span><span data-lang="en">Charts</span></h4>
                <img src="images/guide/po_charts.png" alt="Charts" loading="lazy" />
                <p data-lang="th"><b>Output by Stage</b>: แท่งอ่อน = In, แท่งเข้ม = Good ของแต่ละขั้น · ยอดลดลงทีละขั้นเพราะ PO ยังผลิตไม่ครบ ไม่ใช่ของหาย (ของหายจริงดูที่ NG / Loss / Other บนการ์ด) · <b>NG by Reason</b>: สาเหตุ NG จาก ERP แยกตามขั้น 6 อันดับแรก</p>
                <p data-lang="en"><b>Output by Stage</b>: light bar = In, dark bar = Good per stage. Later stages are lower because the PO is still running, not because pieces were lost (for real losses read NG / Loss / Other on the cards). <b>NG by Reason</b>: NG reasons from ERP per stage, top 6.</p>

                <h4 id="gd5">5. <span data-lang="th">ตาราง</span><span data-lang="en">Tables</span></h4>
                <img src="images/guide/po_table.png" alt="Batch x Process" loading="lazy" />
                <table>
                    <tr><th data-lang="th">ช่องในตาราง Batch × Process</th><th data-lang="en">Cell in Batch × Process</th><th data-lang="th">ความหมาย</th><th data-lang="en">Meaning</th></tr>
                    <tr><td><span class="gd-cell done">✓ 1,570</span></td><td data-lang="th">Check-Out แล้ว ได้ Good เท่านี้ (ตัวแดง = NG)</td><td data-lang="en">Checked out, good quantity (red = NG)</td></tr>
                    <tr><td><span class="gd-cell wip">⏳ 1,590</span></td><td data-lang="th">กำลังผลิตอยู่ที่ขั้นนี้</td><td data-lang="en">In progress at this stage</td></tr>
                    <tr><td><span class="gd-cell wait">Not arrived</span></td><td data-lang="th">ขั้นถัดไปที่ Batch นี้ยังไม่ Check-In (ชี้ดูเวลาที่ออกจากขั้นก่อน)</td><td data-lang="en">Next stage not checked in yet (hover for when it left the previous stage)</td></tr>
                    <tr><td><span class="gd-cell none">–</span></td><td data-lang="th">ยังไม่ถึงขั้นนี้</td><td data-lang="en">Not reached yet</td></tr>
                </table>
                <p data-lang="th"><b>ตัวอย่าง:</b> คลิกการ์ด <b>04 Glebar</b> → กดปุ่ม <b>Not arrived 26</b> เหนือตาราง → ตารางเหลือ 26 Batch · <code>Not arrived · at 03</code> = เสร็จจาก Core Molding แล้ว รอส่งเข้า Glebar (งานที่ควรตาม) · <code>Not arrived · ⏳ at 03</code> = ยังผลิตอยู่ที่ Core Molding</p>
                <p data-lang="en"><b>Example:</b> click card <b>04 Glebar</b> → press <b>Not arrived 26</b> above the table → 26 batches remain. <code>Not arrived · at 03</code> = finished Core Molding, waiting to enter Glebar (follow these up). <code>Not arrived · ⏳ at 03</code> = still running at Core Molding.</p>
                <img src="images/guide/po_table_na.png" alt="Glebar Not arrived" loading="lazy" />
                <p data-lang="th"><b>All Step Details</b>: 1 แถวต่อ 1 Batch ต่อ 1 ขั้น มีเวลา Check-In/Out เครื่อง ชั่วโมง In Good NG Loss Other · ป้าย ×N parts = Check-Out แยกหลายครั้ง · ทั้งสองตารางมีแถว <b>Total</b> และกด <b>⬇ Export CSV</b> เปิดด้วย Excel ได้</p>
                <p data-lang="en"><b>All Step Details</b>: one row per batch per stage with check-in/out, machine, hours, In, Good, NG, Loss, Other. A ×N parts badge = checked out in several parts. Both tables have a <b>Total</b> row; <b>⬇ Export CSV</b> opens in Excel.</p>
                <img src="images/guide/po_details.png" alt="All Step Details" loading="lazy" />

                <h4 id="gd6">6. <span data-lang="th">คำศัพท์และสูตร</span><span data-lang="en">Glossary and formulas</span></h4>
                <table>
                    <tr><th></th><th>Formula</th><th data-lang="th">ความหมาย</th><th data-lang="en">Meaning</th></tr>
                    <tr><td><b>NG %</b></td><td>NG ÷ (Good + NG)</td><td data-lang="th">ปัดขึ้น 2 ตำแหน่ง มี NG จะไม่โชว์ 0.00%</td><td data-lang="en">Rounded up, any NG never shows 0.00%</td></tr>
                    <tr><td><b>Loss</b></td><td>UNKNOWQTY</td><td data-lang="th">ยอดหายที่บันทึกไว้ (Loss % = Loss ÷ In)</td><td data-lang="en">Recorded loss (Loss % = Loss ÷ In)</td></tr>
                    <tr><td><b>Other</b></td><td>In − Good − NG − Loss</td><td data-lang="th">ยังรอ Check-Out หรือส่งคืน (ไม่ใช่ Loss)</td><td data-lang="en">Pending check-out or returned (not Loss)</td></tr>
                    <tr><td><b>Yield</b></td><td>Good ÷ In</td><td data-lang="th">ปัดลง ไม่โชว์ 100% ถ้ายังมีส่วนต่าง</td><td data-lang="en">Rounded down, never 100% if anything is missing</td></tr>
                    <tr><td><b>In progress</b></td><td>Check-In, no Check-Out</td><td data-lang="th">กำลังผลิตที่ขั้นนั้น</td><td data-lang="en">Running at that stage</td></tr>
                    <tr><td><b>Not arrived</b></td><td>—</td><td data-lang="th">ยังค้างขั้นก่อนหน้า (Batch ที่ข้ามขั้นไปแล้วไม่นับ)</td><td data-lang="en">Still at an earlier stage (batches that skipped past are not counted)</td></tr>
                    <tr><td><b>Finished</b></td><td>Packing checked out</td><td data-lang="th">Batch เสร็จสมบูรณ์</td><td data-lang="en">Batch completed</td></tr>
                </table>

                <h4 id="gd7">7. FAQ</h4>
                <dl data-lang="th">
                    <dt>In − Good − NG ไม่เท่ากับ 0 งานหายไปไหน?</dt><dd>ดู Loss (หายที่บันทึกไว้) และ Other (ยังรอ Check-Out หรือส่งคืน) เอาเมาส์ชี้ Other ดูช่องอื่นใน ERP</dd>
                    <dt>ขั้นก่อนมี 205 Batch ขั้นถัดไปมี 204?</dt><dd>มี 1 Batch ยังไม่ Check-In ที่ขั้นถัดไป ดู Not arrived ⓘ บนการ์ดขั้นนั้น ขั้นนั้นจะยังไม่ขึ้น ✓ Done</dd>
                    <dt>Not arrived เยอะ ผิดปกติไหม?</dt><dd>ปกติสำหรับ PO ที่ยังผลิตอยู่ ให้ตามเฉพาะแถว <code>Not arrived · at xx</code> (ไม่มี ⏳) ที่ Last move เก่าหลายวัน</dd>
                    <dt>ค้น PO ไม่เจอ</dt><dd>พิมพ์บางส่วนแล้วเลือกจากรายการ หรือค้นด้วยเลข Batch · เลข PO มาจาก Description ของ MO ใน ERP</dd>
                    <dt>ตัวเลขไม่ตรงกับที่เพิ่งบันทึก</dt><dd>กด ⟳ ถ้ายังไม่ตรงให้เช็ค Check-In / Check-Out ใน ERP · หน้าเว็บแสดงแบบเก่า กด Ctrl+F5</dd>
                </dl>
                <dl data-lang="en">
                    <dt>In − Good − NG is not 0 — where did the pieces go?</dt><dd>Check Loss (recorded loss) and Other (pending check-out or returned); hover Other for the remaining ERP fields.</dd>
                    <dt>Earlier stage has 205 batches, next has 204?</dt><dd>One batch has not checked in at the next stage; see Not arrived ⓘ on that card. That stage will not show ✓ Done.</dd>
                    <dt>Many Not arrived — is that a problem?</dt><dd>Normal for a PO still in production. Follow up only rows marked <code>Not arrived · at xx</code> (no ⏳) whose Last move is several days old.</dd>
                    <dt>PO not found</dt><dd>Type part of it and pick from the list, or search by batch. The PO comes from the MO description in ERP.</dd>
                    <dt>Numbers don't match what was just entered</dt><dd>Press ⟳; if still different, check the check-in / check-out in ERP. Page looks outdated: press Ctrl+F5.</dd>
                </dl>
                <p class="gd-foot" data-lang="th">ภาพในคู่มือใช้ข้อมูลตัวอย่าง ตัวเลขจริงจะต่างจากในภาพ</p>
                <p class="gd-foot" data-lang="en">Screenshots use sample data; real numbers will differ.</p>
            </div>
        </div>
    </div>
</div>

<script>
// @ts-nocheck
(function () {
    var $ = function (id) { return document.getElementById(id); };
    var D = null, selOp = null, tab = 'mx', mxShow = 'all';
    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function fmt(n) { return n == null ? '–' : Math.round(n).toLocaleString('en-US'); }
    // อธิบายยอดที่ไม่อยู่ใน Good / NG / Loss (ช่องอื่นใน ERP)
    function diffTip(x) {
        var t = (x.diff > 0 ? 'Other (pending check-out / returned): ' : 'Over by ') + Math.abs(x.diff).toLocaleString('en-US') + ' pcs = In − Good − NG − Loss' +
            (x.diff > 0 ? '\n(not checked out yet, or returned — not recorded as Good / NG / Loss)' : '') + '\nOther ERP fields at this step:' +
            '\n  DEFECTQTY ' + (x.defect || 0).toLocaleString('en-US') + '\n  SURPLUSQTY ' + (x.surplus || 0).toLocaleString('en-US') +
            '\n  OR034 ' + (x.or034 || 0).toLocaleString('en-US') + '\n  OR038 ' + (x.or038 || 0).toLocaleString('en-US');
        if (x.multiOut) t += '\n  ' + x.multiOut + ' batch(es) checked out in several parts (sum of outputs ' + (x.outSum || 0).toLocaleString('en-US') + ')';
        if (x.outRows > 1) t += '\n  Checked out in ' + x.outRows + ' parts · sum of outputs ' + (x.outSum || 0).toLocaleString('en-US');
        return t;
    }
    function pdate(s) { return s ? new Date(s.replace(' ', 'T')) : null; }
    function dtx(s) { if (!s) return '–'; var d = pdate(s); return pad(d.getDate()) + '/' + pad(d.getMonth() + 1) + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes()); }
    function pad(n) { return (n < 10 ? '0' : '') + n; }
    function dur(h) {
        if (h == null) return '–';
        if (h < 1) return Math.round(h * 60) + ' min';
        if (h < 48) return h.toFixed(1) + ' h';
        return (h / 24).toFixed(1) + ' days';
    }
    var tip = $('tip');
    function showTip(html, ev) {
        tip.innerHTML = html; tip.style.display = 'block';
        var w = tip.offsetWidth, h = tip.offsetHeight, x = ev.clientX + 14, y = ev.clientY + 14;
        if (x + w > innerWidth - 8) x = ev.clientX - w - 14;
        if (y + h > innerHeight - 8) y = ev.clientY - h - 14;
        tip.style.left = x + 'px'; tip.style.top = y + 'px';
    }
    function hideTip() { tip.style.display = 'none'; }

    // ---------- รายการ PO ล่าสุด ----------
    fetch('PO_Tracking.aspx?format=list').then(function (r) { return r.json(); }).then(function (list) {
        if (!list || !list.length) return;
        $('poList').innerHTML = list.map(function (p) { return '<option value="' + esc(p.po.replace(/^PO:/, '')) + '">' + esc(p.po + ' · ' + p.batches + ' batch · ' + (p.ball || '')) + '</option>'; }).join('');
        $('recent').innerHTML = 'Recent POs: ' + list.slice(0, 8).map(function (p) {
            return '<span class="chip" data-po="' + esc(p.po.replace(/^PO:/, '')) + '" title="' + esc((p.ball || '') + ' · last ' + dtx(p.last)) + '">' + esc(p.po.replace(/^PO:/, '')) + '</span>';
        }).join('');
        $('recent').onclick = function (e) { var c = e.target.closest('.chip'); if (c) { $('inPo').value = c.getAttribute('data-po'); $('inBatch').value = ''; go(); } };
    }).catch(function () { });

    // ---------- ค้นหา ----------
    function go() {
        var po = $('inPo').value.trim().replace(/^PO:\s*/i, ''), b = $('inBatch').value.trim();
        if (!po && !b) { $('inPo').focus(); return; }
        try { var p = new URLSearchParams(); if (po) p.set('po', po); if (b) p.set('batch', b); history.replaceState(null, '', location.pathname + '?' + p); } catch (e) { }
        $('out').innerHTML = '<div class="card msg">Loading...</div>';
        fetch('PO_Tracking.aspx?format=json&po=' + encodeURIComponent(po) + '&batch=' + encodeURIComponent(b) + '&_=' + Date.now())
            .then(function (r) { return r.json(); })
            .then(function (d) {
                if (d.error) throw new Error(d.error);
                if (!d.found) { $('out').innerHTML = '<div class="card msg">No data found for ' + esc(po || b) + '</div>'; return; }
                D = d; selOp = null; render();
            })
            .catch(function (e) { $('out').innerHTML = '<div class="card msg err">Failed to load: ' + esc(e.message) + '</div>'; });
    }
    $('btnGo').onclick = go;
    $('btnRefresh').onclick = go;
    [$('inPo'), $('inBatch')].forEach(function (el) { el.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); go(); } }); });
    var q0 = new URLSearchParams(location.search);
    if (q0.get('po') || q0.get('batch')) { $('inPo').value = q0.get('po') || ''; $('inBatch').value = q0.get('batch') || ''; go(); }

    // ---------- วาดทั้งหน้า ----------
    function render() {
        var S = D.summary, P = D.processes;
        var fin = S.status === 'finished';
        var yieldPct = S.startQty > 0 ? (S.lastGood * 100 / S.startQty) : null;
        var h = '';
        h += '<div class="card hero"><div>' +
             '<div class="po">PURCHASE ORDER<b>' + esc((S.pos && S.pos.length ? S.pos.join(', ') : D.po || D.batch)) + '</b></div>' +
             '<div class="ball">Ball model: ' + esc((S.balls || []).join(', ') || '–') + '</div>' +
             '<span class="pill ' + (fin ? 'fin' : 'run') + '"><i></i>' + (fin ? 'Completed (packed)' : 'In progress · at ' + esc(S.furthestName)) + '</span>' +
             '</div><div class="kpis">' +
             kpi('Batch', S.finished + ' / ' + S.batchCount, (S.wipBatches ? S.wipBatches + ' in progress' : 'none on machines')) +
             kpi('Current stage', esc(S.furthestName), 'Process ' + esc(code(S.furthestOp))) +
             kpi('Started', dtx(S.start), 'Last move ' + dtx(S.lastMove)) +
             kpi('Lead time', dur(S.leadHours), fin ? 'start → finish' : 'start → now') +
             kpi('Good at latest stage', fmt(S.lastGood), 'from input ' + fmt(S.startQty) + (yieldPct != null ? ' · ' + (Math.floor(yieldPct * 100 + 1e-7) / 100).toFixed(2) + '%' : '')) +
             kpi('Total NG', fmt(S.totalNg), 'Loss ' + fmt(S.totalLoss)) +
             '</div></div>';

        // stepper
        h += '<div class="card"><h3>Production Stages<small>Click a stage to filter the table</small></h3><div class="steps" id="steps">';
        P.forEach(function (p) {
            var na = p.notArrived || 0, tot = p.batches + na;
            var stTxt = p.status === 'done' ? '✓ Done' : p.status === 'wip' ? '● In progress ' + p.wip + ' batch' : '◐ Done ' + p.done + '/' + tot + ' batch';
            var wipList = []; (D.batches || []).forEach(function (b) { b.steps.forEach(function (s) { if (s.op === p.op && s.wip) wipList.push(b.batch + ' — checked in ' + dtx(s.in) + ' · ' + fmt(s.inQty) + ' pcs' + (s.eqid ? ' · ' + s.eqid : '')); }); });
            var wipTip = p.wip ? 'In progress at this stage: ' + p.wip + ' batch (checked in, not checked out yet)\n' + wipList.slice(0, 30).join('\n') + (wipList.length > 30 ? '\n…' : '') : '';
            var naTip = na ? 'Not arrived yet: ' + na + ' batch · ' + fmt(p.notArrivedQty) + ' pcs (still at an earlier stage)\n' +
                (p.notArrivedList || []).map(function (b) { return b.batch + ' — at ' + b.op + ' ' + b.proc + (b.wip ? ' (in progress)' : ' (checked out ' + dtx(b.since) + ', waiting)') + ' · ' + fmt(b.qty) + ' pcs'; }).join('\n') +
                (na > (p.notArrivedList || []).length ? '\n…' : '') : '';
            h += '<div class="step ' + p.status + (selOp === p.op ? ' sel' : '') + '" data-op="' + esc(p.op) + '">' +
                 '<div class="dot">' + esc(p.code) + '</div><div class="sbox"><h4 title="' + esc(p.name) + '">' + esc(p.name) + '</h4>' +
                 '<div class="st ' + p.status + '">' + stTxt + '</div><div class="nums">' +
                 '<span>In</span><b>' + fmt(p.inQty) + '</b><span>Good</span><b>' + fmt(p.outQty) + '</b>' +
                 '<span>NG</span><b class="ng">' + fmt(p.ng) + (p.ngPct != null ? ' <small>(' + p.ngPct.toFixed(2) + '%)</small>' : '') + '</b>' +
                 '<span>Loss</span><b class="loss">' + fmt(p.loss) + (p.inQty > 0 && p.loss ? ' <small>(' + (Math.ceil((p.loss * 100 / p.inQty) * 100 - 1e-7) / 100).toFixed(2) + '%)</small>' : '') + '</b>' +
                 (p.diff ? '<span title="Other = In − Good − NG − Loss (pending check-out or returned)">Other</span><b class="diff" title="' + esc(diffTip(p)) + '">' + (p.diff > 0 ? '' : '+') + fmt(Math.abs(p.diff)) + ' ⓘ</b>' : '') +
                 (p.wip ? '<span title="Batches checked in at this stage, not checked out yet">In progress</span><b class="wipn" title="' + esc(wipTip) + '">⏳ ' + p.wip + ' batch ⓘ</b>' : '') +
                 (na ? '<span title="' + esc(naTip) + '">Not arrived</span><b class="na" title="' + esc(naTip) + '">' + na + ' batch ⓘ</b>' : '') +
                 '<span>Batch</span><b>' + p.done + '/' + tot + '</b></div>' +
                 '<div class="tm">Start ' + dtx(p.start) + '<br>' + (p.end ? 'End ' + dtx(p.end) : 'Not finished') + ' · ' + dur(p.spanHours) +
                 (p.machines && p.machines.length ? '<br>' + esc(p.machines.slice(0, 3).join(', ') + (p.machines.length > 3 ? ' +' + (p.machines.length - 3) : '')) : '') + '</div></div></div>';
        });
        h += '</div></div>';

        // yield + NG
        h += '<div class="two"><div class="card"><h3>Output by Stage<small>In (light) / Good (dark)</small></h3><div id="yld"></div></div>' +
             '<div class="card"><h3>NG by Reason<small>as recorded in ERP</small></h3><div id="ngb"></div></div></div>';

        // tables
        h += '<div class="card"><div class="tabs"><button type="button" data-t="mx">Batch × Process</button><button type="button" data-t="dt">All Step Details</button>' +
             '<label class="procsel">Process <select id="selProc"><option value="">All processes</option>' +
             D.processes.map(function (p) { return '<option value="' + esc(p.op) + '">' + esc(p.code + ' ' + p.name) + '</option>'; }).join('') + '</select></label>' +
             '<span class="sp"></span><button type="button" id="btnCsv">⬇ Export CSV</button></div><div class="tbl" id="tblBox"></div></div>';

        $('out').innerHTML = h;
        $('steps').onclick = function (e) {
            var s = e.target.closest('.step'); if (!s) return;
            var op = s.getAttribute('data-op'); setOp(selOp === op ? null : op);
        };
        // เลือก Process (การ์ดขั้นด้านบน หรือ dropdown ในตาราง ทำงานเหมือนกัน)
        function setOp(op) {
            selOp = op || null; mxShow = 'all';
            document.querySelectorAll('.step').forEach(function (x) { x.classList.toggle('sel', x.getAttribute('data-op') === selOp); });
            $('selProc').value = selOp || '';
            drawTable();
        }
        $('selProc').value = selOp || '';
        $('selProc').onchange = function () { setOp(this.value); };
        document.querySelectorAll('.tabs button[data-t]').forEach(function (b) {
            b.classList.toggle('on', b.getAttribute('data-t') === tab);
            b.onclick = function () { tab = b.getAttribute('data-t'); document.querySelectorAll('.tabs button[data-t]').forEach(function (x) { x.classList.toggle('on', x === b); }); drawTable(); };
        });
        $('btnCsv').onclick = exportCsv;
        drawYield(); drawNg(); drawTable();
    }
    function kpi(l, v, s) { return '<div class="kpi"><span>' + l + '</span><b title="' + String(v).replace(/<[^>]+>/g, '') + '">' + v + '</b><em>' + (s || '&nbsp;') + '</em></div>'; }
    function code(op) { var p = (D.processes || []).filter(function (x) { return x.op === op; })[0]; return p ? p.code : op; }
    function procName(op) { var p = D.processes.filter(function (x) { return x.op === op; })[0]; return p ? p.name : op; }

    // ---------- Yield ----------
    function drawYield() {
        var P = D.processes, max = Math.max.apply(null, P.map(function (p) { return Math.max(p.inQty, p.outQty); }).concat([1]));
        $('yld').innerHTML = P.map(function (p) {
            return '<div class="yrow"><span class="nm" title="' + esc(p.name) + '">' + esc(p.code + ' ' + p.name) + '</span>' +
                '<div class="ytrack" title="In ' + fmt(p.inQty) + ' / Good ' + fmt(p.outQty) + '"><i class="in" style="width:' + (p.inQty / max * 100) + '%"></i><i class="ok" style="width:' + (p.outQty / max * 100) + '%"></i></div>' +
                '<span class="v">' + fmt(p.outQty) + (p.yield != null ? ' <small style="color:#64748b">' + (Math.floor(p.yield * 10 + 1e-7) / 10).toFixed(1) + '%</small>' : '') + '</span></div>';
        }).join('');
    }

    // ---------- NG ----------
    function drawNg() {
        var R = D.reasons || [];
        if (!R.length) { $('ngb').innerHTML = '<div class="msg" style="padding:20px">No NG recorded</div>'; return; }
        var by = {};
        R.forEach(function (r) { (by[r.op] = by[r.op] || []).push(r); });
        var h = '';
        D.processes.forEach(function (p) {
            var list = (by[p.op] || []).sort(function (a, b) { return b.qty - a.qty; });
            if (!list.length) return;
            var tot = list.reduce(function (s, r) { return s + r.qty; }, 0), mx = list[0].qty;
            h += '<div class="ngp"><h5>' + esc(p.code + ' ' + p.name) + '<span>' + fmt(tot) + ' pcs</span></h5>' +
                list.slice(0, 6).map(function (r) {
                    return '<div class="ngr"><span class="t" title="' + esc(r.reason) + '">' + esc(r.reason || r.group || '(unspecified)') + '</span>' +
                        '<div class="b"><i style="width:' + (r.qty / mx * 100) + '%"></i></div><span class="q">' + fmt(r.qty) + '</span></div>';
                }).join('') + (list.length > 6 ? '<div class="ngr"><span class="t" style="color:#94a3b8">+ ' + (list.length - 6) + ' more reasons</span></div>' : '') + '</div>';
        });
        $('ngb').innerHTML = h;
    }

    // ---------- ตาราง ----------
    var lastRows = [];
    function drawTable() {
        var box = $('tblBox'), P = D.processes, h = '';
        if (tab === 'mx') {
            var cols = P.filter(function (p) { return !selOp || p.op === selOp; });
            var pIdx = {}; P.forEach(function (p, i) { pIdx[p.op] = i; });
            var selP = selOp ? P[pIdx[selOp]] : null;
            // สถานะของแต่ละ Batch: ขั้นล่าสุด, ขั้นถัดไปที่ยังไม่รับ (ยังไม่ Check-In)
            var rows = D.batches.map(function (b) {
                var map = {}, last = -1; b.steps.forEach(function (s) { map[s.op] = s; if (pIdx[s.op] > last) last = pIdx[s.op]; });
                var ls = last >= 0 ? map[P[last].op] : null;
                var nextOp = b.state !== 'finished' && ls && !ls.wip && last + 1 < P.length ? P[last + 1].op : null;
                // เทียบกับขั้นที่เลือก: done / wip / na (ยังไม่มาถึง) / skip
                var st = !selOp ? b.state : map[selOp] ? (map[selOp].wip ? 'wip' : 'done') : (b.state !== 'finished' && last < pIdx[selOp] ? 'na' : 'skip');
                return { b: b, map: map, last: last, ls: ls, nextOp: nextOp, st: st };
            }).filter(function (r) { return !selOp || r.st !== 'skip'; });
            var cnt = {}; rows.forEach(function (r) { cnt[r.st] = (cnt[r.st] || 0) + 1; });
            var opts = selOp ? [['all', 'All'], ['wip', '⏳ In progress'], ['na', 'Not arrived'], ['done', '✓ Done']]
                             : [['all', 'All'], ['wip', 'In progress'], ['waiting', 'Waiting next stage'], ['finished', 'Finished']];
            if (!opts.some(function (o) { return o[0] === mxShow; })) mxShow = 'all';
            h = '<div class="mxf"><b>' + (selP ? esc(selP.code + ' ' + selP.name) + ':' : 'Show:') + '</b>' + opts.map(function (o) {
                    var n = o[0] === 'all' ? rows.length : (cnt[o[0]] || 0);
                    return '<button type="button" data-f="' + o[0] + '"' + (mxShow === o[0] ? ' class="on"' : '') + '>' + o[1] + ' ' + n + '</button>';
                }).join('') +
                '<span class="lg"><span class="cell done">✓ Good</span><span class="cell wip">⏳ In progress</span><span class="cell wait">Not arrived</span><span class="cell none">– not reached</span></span></div>';
            h += '<table class="t mx"><thead><tr><th>Batch / MO</th><th>Ball</th><th>Status</th><th>Current stage</th><th>Last move</th>' +
                cols.map(function (p) { return '<th class="r" title="' + esc(p.name) + '">' + esc(p.code + ' ' + p.name) + '</th>'; }).join('') + '</tr></thead><tbody>';
            lastRows = [];
            var shown = rows.filter(function (r) { return mxShow === 'all' || r.st === mxShow; });
            var tot = cols.map(function () { return { good: 0, wip: 0, ng: 0, n: 0, na: 0 }; });
            shown.forEach(function (r) {
                var b = r.b, map = r.map;
                var stTxt = b.state === 'finished' ? 'Finished' : b.state === 'wip' ? 'In progress' : 'Waiting next stage';
                h += '<tr><td><b>' + esc(b.batch) + '</b></td><td>' + esc(b.ball) + '</td><td><span class="tag ' + b.state + '">' + stTxt + '</span></td>' +
                     '<td>' + esc(b.curProc) + '</td><td>' + dtx(b.lastMove) + '</td>' +
                     cols.map(function (p, i) {
                         var s = map[p.op];
                         if (s) {
                             tot[i].n++; tot[i].ng += s.ng || 0; if (s.wip) tot[i].wip += s.inQty || 0; else tot[i].good += s.outQty || 0;
                             return '<td class="c"><span class="cell ' + (s.wip ? 'wip' : 'done') + '" title="In ' + fmt(s.inQty) + ' · Good ' + fmt(s.outQty) + ' · NG ' + fmt(s.ng) + '\n' + dtx(s.in) + ' → ' + (s.wip ? 'In progress' : dtx(s.out)) + '">' +
                                    (s.wip ? '⏳ ' + fmt(s.inQty) : '✓ ' + fmt(s.outQty)) + (s.ng ? ' <span style="color:#e11d48">·' + fmt(s.ng) + '</span>' : '') + '</span></td>';
                         }
                         var notYet = b.state !== 'finished' && r.last < pIdx[p.op];
                         if (notYet) tot[i].na++;
                         if (notYet && (p.op === r.nextOp || selOp)) {
                             var where = r.ls ? (r.ls.wip ? 'still in progress at ' + code(r.ls.op) + ' ' + r.ls.proc : 'checked out from ' + code(r.ls.op) + ' ' + r.ls.proc + ' ' + dtx(r.ls.out) + ' — not received here yet') : '';
                             return '<td class="c"><span class="cell wait" title="Not arrived · ' + esc(where) + '">Not arrived' + (selOp && r.ls ? ' · ' + (r.ls.wip ? '⏳ ' : '') + 'at ' + esc(code(r.ls.op)) : '') + '</span></td>';
                         }
                         return '<td class="c"><span class="cell none">–</span></td>';
                     }).join('') + '</tr>';
                lastRows.push([b.batch, b.ball, stTxt, b.curProc, b.lastMove].concat(cols.map(function (p) {
                    var s = map[p.op]; if (s) return s.wip ? 'WIP ' + s.inQty : s.outQty;
                    return b.state !== 'finished' && r.last < pIdx[p.op] ? (p.op === r.nextOp ? 'Not arrived' : '') : '';
                })));
            });
            if (!shown.length) h += '<tr><td colspan="' + (5 + cols.length) + '" style="color:#94a3b8;text-align:center;padding:18px">No batches</td></tr>';
            lastRows.unshift(['Batch', 'Ball', 'Status', 'Current process', 'Last move'].concat(cols.map(function (p) { return p.code + ' ' + p.name; })));
            var nb = shown.length;
            h += '</tbody><tfoot><tr><td colspan="5">Total · ' + fmt(nb) + ' batches</td>' + tot.map(function (t) {
                return '<td class="r">' + (t.n ? '✓ ' + fmt(t.good) + (t.ng ? ' <span style="color:#e11d48">·' + fmt(t.ng) + '</span>' : '') + (t.wip ? '<span class="sub2">⏳ ' + fmt(t.wip) + ' WIP</span>' : '') + '<span class="sub2">' + fmt(t.n) + ' batches</span>' : '–') +
                       (t.na ? '<span class="sub2" style="color:#0284c7">' + fmt(t.na) + ' not arrived</span>' : '') + '</td>';
            }).join('') + '</tr></tfoot>';
            lastRows.push(['TOTAL', '', '', '', ''].concat(tot.map(function (t) { return t.good; })));
        } else {
            h = '<table class="t"><thead><tr><th>Batch / MO</th><th>Process</th><th>Machine</th><th>Line</th><th>Check-In</th><th>Check-Out</th><th class="r">Duration</th>' +
                '<th class="r">In</th><th class="r">Good</th><th class="r">NG</th><th class="r">Loss</th><th class="r" title="In − Good − NG − Loss">Other<span class="sub2" style="text-transform:none">pending check-out / returned</span></th><th class="r">NG %</th></tr></thead><tbody>';
            lastRows = [['Batch', 'Process', 'Machine', 'Line', 'Check-In', 'Check-Out', 'Hours', 'In', 'Good', 'NG', 'Loss', 'Other - pending check-out / returned (In-Good-NG-Loss)', 'DEFECTQTY', 'SURPLUSQTY', 'OR034', 'OR038']];
            var now = pdate(D.now), list = [], T = { n: 0, diff: 0, inQ: 0, good: 0, ng: 0, loss: 0, hrs: 0, nh: 0, batches: {}, procs: {} };
            D.batches.forEach(function (b) { b.steps.forEach(function (s) { if (!selOp || s.op === selOp) list.push({ b: b, s: s }); }); });
            list.sort(function (x, y) { return (x.s.in || '').localeCompare(y.s.in || ''); });
            list.forEach(function (x) {
                var s = x.s, a = pdate(s.in), z = s.wip ? now : pdate(s.out), hrs = a && z ? (z - a) / 3600e3 : null;
                var ngp = (s.outQty + s.ng) > 0 ? (Math.ceil((s.ng * 100 / (s.outQty + s.ng)) * 100 - 1e-7) / 100).toFixed(2) + '%' : '–';
                h += '<tr><td>' + esc(x.b.batch) + '</td><td>' + esc(code(s.op) + ' ' + s.proc) + '</td><td>' + esc(s.eqid || '–') + '</td><td>' + esc(s.line || '') + '</td>' +
                     '<td>' + dtx(s.in) + '</td><td>' + (s.wip ? '<span class="tag wip">In progress</span>' : dtx(s.out) + (s.outRows > 1 ? ' <span class="parts" title="Checked out in ' + s.outRows + ' parts · first ' + dtx(s.firstOut) + '">×' + s.outRows + '</span>' : '')) + '</td><td class="r">' + dur(hrs) + '</td>' +
                     '<td class="r">' + fmt(s.inQty) + '</td><td class="r">' + fmt(s.outQty) + '</td><td class="r" style="color:#e11d48">' + (s.ng ? fmt(s.ng) : '–') + '</td>' +
                     '<td class="r">' + (s.loss ? fmt(s.loss) : '–') + '</td>' +
                     (s.diff ? '<td class="r diffc" title="' + esc(diffTip(s)) + '">' + (s.diff > 0 ? '' : '+') + fmt(Math.abs(s.diff)) + '</td>' : '<td class="r">–</td>') +
                     '<td class="r">' + ngp + '</td></tr>';
                lastRows.push([x.b.batch, s.proc, s.eqid, s.line, s.in, s.wip ? 'WIP' : s.out, hrs != null ? hrs.toFixed(2) : '', s.inQty, s.outQty, s.ng, s.loss, s.diff, s.defect, s.surplus, s.or034, s.or038]);
                T.n++; T.diff += s.diff || 0; T.inQ += s.inQty || 0; T.good += s.outQty || 0; T.ng += s.ng || 0; T.loss += s.loss || 0; if (hrs != null) { T.hrs += hrs; T.nh++; }
                T.batches[x.b.batch] = 1; T.procs[s.op] = 1;
            });
            // ---- รวมด้านล่าง ----
            var nP = Object.keys(T.procs).length, tngp = (T.good + T.ng) > 0 ? (Math.ceil((T.ng * 100 / (T.good + T.ng)) * 100 - 1e-7) / 100).toFixed(2) + '%' : '–';
            h += '</tbody><tfoot><tr><td colspan="6">Total · ' + fmt(T.n) + ' steps · ' + fmt(Object.keys(T.batches).length) + ' batches' +
                 (nP > 1 ? '<span class="sub2">sum across ' + nP + ' processes — click a stage above to total one process</span>' : '') + '</td>' +
                 '<td class="r">' + (T.nh ? dur(T.hrs / T.nh) + '<span class="sub2">avg</span>' : '–') + '</td>' +
                 '<td class="r">' + fmt(T.inQ) + '</td><td class="r">' + fmt(T.good) + '</td><td class="r" style="color:#e11d48">' + fmt(T.ng) + '</td>' +
                 '<td class="r">' + fmt(T.loss) + '</td><td class="r" style="color:#7c3aed">' + (T.diff ? fmt(T.diff) : '–') + '</td><td class="r">' + tngp + '</td></tr></tfoot>';
            lastRows.push(['TOTAL', '', '', '', '', '', T.nh ? (T.hrs / T.nh).toFixed(2) : '', T.inQ, T.good, T.ng, T.loss, T.diff]);
        }
        box.innerHTML = h + (h.indexOf('<tfoot>') < 0 ? '</tbody>' : '') + '</table>';
        box.querySelectorAll('.mxf button[data-f]').forEach(function (b) { b.onclick = function () { mxShow = b.getAttribute('data-f'); drawTable(); }; });
    }
    function exportCsv() {
        var csv = lastRows.map(function (r) { return r.map(function (v) { return '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"'; }).join(','); }).join('\r\n');
        var a = document.createElement('a');
        a.href = URL.createObjectURL(new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' }));
        a.download = 'PO_' + ((D.summary.pos || [])[0] || D.po || D.batch || 'tracking').replace(/[^\w-]/g, '') + '_' + (tab === 'mx' ? 'batches' : 'steps') + '.csv';
        document.body.appendChild(a); a.click(); a.remove();
    }
    // ---------- คู่มือ (popup) ----------
    (function () {
        var back = $('gdBack'), box = back.querySelector('.gd');
        function setLang(l) { box.setAttribute('data-l', l); back.querySelectorAll('.gd-lang button').forEach(function (b) { b.classList.toggle('on', b.getAttribute('data-l') === l); }); try { localStorage.setItem('poGuideLang', l); } catch (e) { } }
        var l0 = 'th'; try { l0 = localStorage.getItem('poGuideLang') || 'th'; } catch (e) { }
        setLang(l0);
        function open() { back.classList.add('open'); back.setAttribute('aria-hidden', 'false'); $('gdBody').scrollTop = 0; }
        function close() { back.classList.remove('open'); back.setAttribute('aria-hidden', 'true'); }
        $('btnGuide').onclick = open;
        $('gdClose').onclick = close;
        back.addEventListener('click', function (e) { if (e.target === back) close(); });
        document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && back.classList.contains('open')) close(); });
        back.querySelectorAll('.gd-lang button').forEach(function (b) { b.onclick = function () { setLang(b.getAttribute('data-l')); }; });
        $('gdNav').addEventListener('click', function (e) {
            var a = e.target.closest('a'); if (!a) return; e.preventDefault();
            var t = document.getElementById(a.getAttribute('href').slice(1)); if (t) $('gdBody').scrollTo({ top: t.offsetTop - 8, behavior: 'smooth' });
        });
        if (new URLSearchParams(location.search).get('guide') === '1') open();
    })();
})();
</script>
</asp:Content>
