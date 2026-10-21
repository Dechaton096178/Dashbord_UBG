<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="CounterMachine.aspx.cs" Inherits="Dashbord.CounterMachine" Title="Injection Machine Dashboard" %>

<%-- =====================================================================
     Injection Machine Dashboard
     - รับข้อมูลจาก Node-RED (POST) / ส่ง JSON (?format=json) : ดู CounterMachine.aspx.cs
     - Logic การนับอยู่ใน CounterStore.cs
     - การ์ดดีไซน์เดียวกับ Machine_Monitor.aspx (ข้อมูลจริงทั้งหมด) รีเฟรชทุก 3 วินาที
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<style>
    .imd {
        --ink:#0f172a; --mute:#64748b; --line:#e2e8f0;
        --shadow:0 1px 2px rgba(15,23,42,.06), 0 10px 28px rgba(15,23,42,.08);
        --run:#10b981;  --run-bg:#ecfdf5;
        --idle:#f59e0b; --idle-bg:#fffbeb;
        --down:#ef4444; --down-bg:#fef2f2;
        --off:#94a3b8;  --off-bg:#f1f5f9;
        --cA:#0284c7; --cL:#e11d48; --cJ:#7c3aed;
        /* โทนสี (ธีมสว่าง) */
        --bg:#f4f6fb; --card:#fff; --card2:#f8fafc; --line2:#eef2f7; --track:#eef2f7; --art1:#f8fafc;
        --idle-glow:#fffbeb; --down-glow:#fef2f2;
        --cnt-bg1:#eef2ff; --cnt-bg2:#f5f3ff; --cnt-bd:#e0e7ff; --cnt-lbl:#6366f1; --cnt-num:#312e81; --cnt-unit:#818cf8;
        --cnt-i-bg1:#fffbeb; --cnt-i-bg2:#fef3c7; --cnt-i-bd:#fde68a; --cnt-i-lbl:#b45309; --cnt-i-num:#78350f;
        --cnt-d-bg1:#fef2f2; --cnt-d-bg2:#fee2e2; --cnt-d-bd:#fecaca; --cnt-d-lbl:#b91c1c; --cnt-d-num:#7f1d1d;
        --btn-on-bg:#eef2ff; --btn-on-bd:#c7d2fe; --btn-on-ink:#4338ca; --link:#4338ca;
        padding:16px; color:var(--ink); background:var(--bg);
    }

    /* ธีมมืด (ค่าเริ่มต้น) */
    .imd.dark {
        --ink:#e5e7eb; --mute:#94a3b8; --line:#1e293b;
        --shadow:0 1px 2px rgba(0,0,0,.5), 0 10px 28px rgba(0,0,0,.45);
        --run-bg:rgba(16,185,129,.16); --idle-bg:rgba(245,158,11,.16); --down-bg:rgba(239,68,68,.18); --off-bg:rgba(148,163,184,.14);
        --bg:#070b16; --card:#0f172a; --card2:#111c33; --line2:#1e293b; --track:#1e293b; --art1:#131d36;
        --idle-glow:#2a1d06; --down-glow:#2b0d10;
        --cnt-bg1:#1e1b4b; --cnt-bg2:#16153a; --cnt-bd:#312e81; --cnt-lbl:#a5b4fc; --cnt-num:#eef2ff; --cnt-unit:#a5b4fc;
        --cnt-i-bg1:#3a2a07; --cnt-i-bg2:#2a1d06; --cnt-i-bd:#92400e; --cnt-i-lbl:#fbbf24; --cnt-i-num:#fde68a;
        --cnt-d-bg1:#3b0f13; --cnt-d-bg2:#2b0d10; --cnt-d-bd:#991b1b; --cnt-d-lbl:#f87171; --cnt-d-num:#fecaca;
        --btn-on-bg:#1e1b4b; --btn-on-bd:#4338ca; --btn-on-ink:#c7d2fe; --link:#a5b4fc;
    }

    /* ---------- หัวเพจ ---------- */
    .imd-head { display:flex; align-items:center; gap:12px; flex-wrap:wrap; margin-bottom:14px; }
    .imd-head h2 { margin:0; font-size:20px; font-weight:800; letter-spacing:-.01em; }
    .imd-head span { font-size:13px; color:var(--mute); }
    .imd-head span b { color:var(--ink); font-variant-numeric:tabular-nums; }
    .imd-db { font-size:11.5px !important; font-weight:700; padding:2px 8px; border-radius:99px; border:1px solid var(--line); }
    .imd-db.ok  { color:#10b981 !important; border-color:rgba(16,185,129,.4); }
    .imd-db.err { color:#ef4444 !important; border-color:rgba(239,68,68,.45); }
    .imd-db.off { color:var(--mute) !important; }
    .imd-head a { margin-left:auto; font-size:13px; font-weight:700; color:var(--link); text-decoration:none; }

    /* ---------- แท็บแยกตาม Process ---------- */
    .imd-tabs {
        display:flex; gap:6px; overflow-x:auto; padding:4px; margin-bottom:14px;
        background:var(--card); border:1px solid var(--line); border-radius:12px; scrollbar-width:none;
    }
    .imd-tabs button {
        flex-shrink:0; display:inline-flex; align-items:center; gap:7px;
        padding:7px 13px; border:0; border-radius:9px; background:transparent; color:var(--mute);
        font:inherit; font-size:13px; font-weight:700; cursor:pointer; white-space:nowrap;
    }
    .imd-tabs button:hover { color:var(--ink); }
    .imd-tabs button.on { background:var(--btn-on-bg); color:var(--btn-on-ink); box-shadow:inset 0 0 0 1px var(--btn-on-bd); }
    .imd-tabs button b {
        min-width:20px; padding:1px 6px; border-radius:99px; background:var(--card2); color:var(--mute);
        font-size:11px; font-weight:800; text-align:center; font-variant-numeric:tabular-nums;
    }
    .imd-tabs button.on b { background:var(--btn-on-bd); color:#fff; }
    .imd-tabs button.empty { opacity:.55; }
    .imd-tabs button i { width:7px; height:7px; border-radius:50%; background:var(--down); display:none; }
    .imd-tabs button.alert i { display:inline-block; animation:blink 1.4s infinite; }

    /* ---------- สรุปด้านบน ---------- */
    .imd-top { display:grid; grid-template-columns:repeat(4, 1fr) 1.5fr; gap:12px; margin-bottom:14px; }
    .imd-stat {
        padding:10px 14px; background:var(--card); border:1px solid var(--line); border-radius:14px;
        box-shadow:var(--shadow); display:flex; align-items:center; gap:14px;
    }
    .imd-stat .ic { width:36px; height:36px; border-radius:10px; display:grid; place-items:center; color:#fff; flex-shrink:0; }
    .imd-stat b { display:block; font-size:22px; font-weight:800; line-height:1; font-variant-numeric:tabular-nums; }
    .imd-stat span { font-size:12px; font-weight:700; letter-spacing:.08em; color:var(--mute); text-transform:uppercase; }
    .s-run  .ic { background:var(--run); }  .s-run b  { color:var(--run); }
    .s-idle .ic { background:var(--idle); } .s-idle b { color:var(--idle); }
    .s-down .ic { background:var(--down); } .s-down b { color:var(--down); }
    .s-off  .ic { background:var(--off); }  .s-off b  { color:var(--off); }
    .s-sum { background:linear-gradient(135deg,#1e1b4b,#312e81 60%,#4338ca); color:#fff; border:0; }
    .s-sum span { color:#a5b4fc; }
    .s-sum b { color:#fff; font-size:26px; }
    .s-sum em { display:block; font-style:normal; font-size:12px; color:#c7d2fe; margin-top:4px; }

    /* ---------- การ์ดเครื่อง (เหมือน Machine Monitor) ---------- */
    .imd-grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(270px, 1fr)); gap:12px; }
    .imd-empty { grid-column:1/-1; text-align:center; padding:60px; color:#94a3b8; }

    .mc {
        --st:var(--run); --st-bg:var(--run-bg);
        position:relative; background:var(--card); border:1px solid var(--line); border-radius:16px;
        box-shadow:var(--shadow); overflow:hidden; transition:transform .15s, box-shadow .15s;
    }
    .mc:hover { transform:translateY(-3px); box-shadow:0 18px 40px rgba(15,23,42,.14); }
    .mc::before { content:""; position:absolute; left:0; right:0; top:0; height:4px; background:var(--st); }
    .mc.idle { --st:var(--idle); --st-bg:var(--idle-bg); }
    .mc.down { --st:var(--down); --st-bg:var(--down-bg); }
    .mc.off  { --st:var(--off);  --st-bg:var(--off-bg); }

    .mc-head { display:flex; align-items:flex-start; gap:10px; padding:12px 14px 4px; }
    .mc-head h4 { margin:0; font-size:15px; font-weight:800; letter-spacing:-.01em; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .mc-head h4 em { font-style:normal; font-size:11.5px; font-weight:700; color:var(--mute); margin-left:3px; }
    .mc-head > div { min-width:0; flex:1; }
    .mc-head small { display:block; color:var(--mute); font-size:11.5px; margin-top:1px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .pill {
        margin-left:auto; flex-shrink:0; display:inline-flex; align-items:center; gap:7px;
        padding:3px 9px; border-radius:999px; background:var(--st-bg); color:var(--st);
        font-size:10.5px; font-weight:800; letter-spacing:.04em;
    }
    .pill i { width:8px; height:8px; border-radius:50%; background:var(--st); }
    .mc.run .pill i { animation:blink 1.4s infinite; }
    @keyframes blink { 0% { box-shadow:0 0 0 0 rgba(16,185,129,.55); } 100% { box-shadow:0 0 0 8px rgba(16,185,129,0); } }

    /* ตัวเลข Counter ตัวใหญ่ */
    .cnt {
        margin:2px 12px 4px; padding:6px 12px 7px; border-radius:12px;
        background:linear-gradient(135deg,var(--cnt-bg1),var(--cnt-bg2)); border:1px solid var(--cnt-bd);
        display:flex; align-items:baseline; gap:8px;
    }
    .cnt span { font-size:10px; font-weight:800; letter-spacing:.08em; color:var(--cnt-lbl); text-transform:uppercase; }
    .cnt b { margin-left:auto; font-size:38px; font-weight:900; line-height:1; letter-spacing:-.02em; color:var(--cnt-num); font-variant-numeric:tabular-nums; }
    .cnt em { font-style:normal; font-size:12px; font-weight:700; color:var(--cnt-unit); }
    .cnt { align-items:stretch; gap:10px; }
    .cnt .cday { flex:1; min-width:0; display:flex; flex-direction:column; justify-content:center; }
    .cnt .cday > div { display:flex; align-items:baseline; justify-content:flex-end; gap:5px; }
    .cnt .cday b { margin-left:0; }
    .cnt .cnow { flex-shrink:0; display:flex; flex-direction:column; justify-content:center; align-items:flex-end;
                 padding-left:10px; border-left:1px solid var(--cnt-bd); }
    .cnt .cnow span { font-size:9px; white-space:nowrap; }
    .cnt .cnow b { margin:0; font-size:17px; font-weight:800; opacity:.85; }
    .mc.idle .cnt { background:linear-gradient(135deg,var(--cnt-i-bg1),var(--cnt-i-bg2)); border-color:var(--cnt-i-bd); }
    .mc.idle .cnt span, .mc.idle .cnt em { color:var(--cnt-i-lbl); } .mc.idle .cnt b { color:var(--cnt-i-num); }
    .mc.down .cnt { background:linear-gradient(135deg,var(--cnt-d-bg1),var(--cnt-d-bg2)); border-color:var(--cnt-d-bd); }
    .mc.down .cnt span, .mc.down .cnt em { color:var(--cnt-d-lbl); } .mc.down .cnt b { color:var(--cnt-d-num); }
    .mc.off .cnt { background:var(--card2); border-color:var(--line); }
    .mc.off .cnt span, .mc.off .cnt em, .mc.off .cnt b { color:#94a3b8; }

    /* Idle / Breakdown : การ์ดกะพริบช้าๆ */
    .mc.idle { animation:pulseIdle 2.6s ease-in-out infinite; }
    .mc.down { animation:pulseDown 2.6s ease-in-out infinite; }
    @keyframes pulseIdle {
        0%,100% { border-color:var(--line); box-shadow:var(--shadow); background:var(--card); }
        50%     { border-color:#f59e0b; box-shadow:0 0 0 3px rgba(245,158,11,.35), 0 10px 28px rgba(245,158,11,.25); background:var(--idle-glow); }
    }
    @keyframes pulseDown {
        0%,100% { border-color:var(--line); box-shadow:var(--shadow); background:var(--card); }
        50%     { border-color:#ef4444; box-shadow:0 0 0 3px rgba(239,68,68,.40), 0 10px 28px rgba(239,68,68,.28); background:var(--down-glow); }
    }
    .imd.dark .art svg { filter:brightness(.92) saturate(1.05); }
    .imd.dark .kv.count b { color:#a5b4fc; }
    .imd.dark .kv.loss b { color:#fb7185; }
    .imd.dark .mc:hover { box-shadow:0 18px 40px rgba(0,0,0,.6); }
    .imd.dark .s-sum { background:linear-gradient(135deg,#1e1b4b,#312e81 60%,#4338ca); }

    @media (prefers-reduced-motion: reduce) { .mc.idle, .mc.down { animation:none; } }

    .mc-body { display:grid; grid-template-columns:1fr 80px; gap:6px; align-items:center; padding:2px 12px 4px 8px; }
    .art {
        position:relative; height:78px; border-radius:12px;
        background:radial-gradient(120% 90% at 30% 100%, var(--st-bg) 0%, transparent 70%), linear-gradient(180deg,var(--art1),var(--card));
    }
    .art svg { width:100%; height:100%; }
    .ring {
        --v:0; position:relative; width:78px; height:78px; border-radius:50%; display:grid; place-items:center;
        background:conic-gradient(var(--oc, #6366f1) calc(var(--v) * 1%), var(--track) 0);
    }
    .ring::after { content:""; position:absolute; inset:8px; border-radius:50%; background:var(--card); }
    .ring div { position:relative; z-index:1; text-align:center; }
    .ring b { display:block; font-size:16px; font-weight:800; line-height:1; font-variant-numeric:tabular-nums; color:var(--ink); }
    .ring span { font-size:9px; font-weight:800; letter-spacing:.12em; color:var(--mute); }

    .apq { padding:4px 14px 2px; display:grid; gap:5px; }
    .apq .r { display:grid; grid-template-columns:78px 1fr 42px; align-items:center; gap:8px; font-size:11.5px; }
    .apq .r span { color:var(--mute); font-weight:700; }
    .apq .r b { text-align:right; font-variant-numeric:tabular-nums; }
    .apq .t { height:6px; border-radius:99px; background:var(--track); overflow:hidden; }
    .apq .t i { display:block; height:100%; border-radius:99px; }
    .apq .rA i { background:var(--cA); }
    .apq .rL i { background:var(--cL); }
    .apq .rJ i { background:var(--cJ); }
    .apq .rQ i { background:#059669; }
    .apq .rP i { background:#8b5cf6; }
    .apq .r span em { font-style:normal; font-weight:900; color:var(--ink); margin-right:4px; }
    /* OK / NG (เครื่องที่ส่ง OK/NG มา) */
    .okng { display:grid; grid-template-columns:1fr 1fr; gap:6px; margin:6px 14px 0; }
    .okng div { border-radius:10px; padding:5px 10px; display:flex; align-items:baseline; gap:6px; border:1px solid; }
    .okng span { font-size:10px; font-weight:800; letter-spacing:.08em; }
    .okng b { margin-left:auto; font-size:20px; font-weight:900; font-variant-numeric:tabular-nums; line-height:1.1; }
    .okng .ok { background:rgba(16,185,129,.10); border-color:rgba(16,185,129,.35); color:#10b981; }
    .okng .ng { background:rgba(244,63,94,.10); border-color:rgba(244,63,94,.40); color:#fb7185; }
    .ring.oee span { color:var(--ink); }

    .mc-foot { margin:6px 12px 8px; display:grid; grid-template-columns:repeat(3, 1fr); gap:6px; }

    /* Operating / Loss / Count Start (รูปแบบเดียวกับหน้าจอเก่า) */
    .rt {
        margin:8px 12px 0; padding:7px 11px; border-radius:10px;
        background:var(--card2); border:1px solid var(--line2);
        display:grid; grid-template-columns:auto 1fr; gap:3px 10px; align-items:baseline;
    }
    .rt span { font-size:12px; font-weight:700; color:var(--mute); white-space:nowrap; }
    .rt b { text-align:right; font-size:15px; font-weight:800; color:var(--ink); font-variant-numeric:tabular-nums; white-space:nowrap; }
    .rt b small { font-size:11px; font-weight:700; color:var(--mute); margin-left:3px; }
    .rt b.loss { color:#e11d48; }
    .imd.dark .rt b.loss { color:#fb7185; }
    .rt b.cs { font-size:13px; }
    .kv { padding:6px 9px; border-radius:10px; background:var(--card2); border:1px solid var(--line2); }
    .kv span {
        display:flex; align-items:center; gap:6px; font-size:9.5px; font-weight:800; letter-spacing:.02em;
        text-transform:uppercase; color:var(--mute); white-space:nowrap;
    }
    .kv b { display:block; margin-top:2px; font-size:13.5px; font-variant-numeric:tabular-nums; color:var(--ink); }
    .kv.loss b { color:#e11d48; }
    .kv.count b { color:#4338ca; }

    .hrs { padding:0 14px 6px; }
    .hrs .lbl { font-size:9.5px; font-weight:800; letter-spacing:.02em; text-transform:uppercase; color:var(--mute); }
    .hrs .bars { display:flex; align-items:flex-end; gap:2px; height:30px; margin-top:3px; }
    .hrs .bars i { flex:1; min-height:1px; border-radius:2px 2px 0 0; background:#a5b4fc; }
    .hrs .bars i.now { background:#6366f1; }

    .mc-job { display:flex; align-items:center; gap:8px; padding:7px 14px; border-top:1px dashed var(--line); font-size:11.5px; color:var(--mute); }
    .mc-job b { color:var(--ink); font-weight:700; max-width:130px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .mc-job .prog { flex:1; height:6px; border-radius:99px; background:var(--track); overflow:hidden; }
    .mc-job .prog i { display:block; height:100%; background:linear-gradient(90deg,#6366f1,#8b5cf6); }

    .mc.run .gear { animation:spin 3s linear infinite; transform-origin:center; transform-box:fill-box; }
    .mc.run .flow { animation:flow 1.2s linear infinite; }
    .mc.run .ram  { animation:ram 2.4s ease-in-out infinite; }
    @keyframes spin { to { transform:rotate(360deg); } }
    @keyframes flow { to { stroke-dashoffset:-16; } }
    @keyframes ram  { 0%,100% { transform:translateX(0); } 50% { transform:translateX(10px); } }

    /* ---------- โหมดพอดีจอ (สำหรับจอ TV / Dashboard) ---------- */
    .imd-btn {
        height:30px; padding:0 12px; border:1px solid var(--line); border-radius:9px; background:var(--card);
        color:var(--mute); font:inherit; font-size:12px; font-weight:700; cursor:pointer;
    }
    .imd-btn.on { background:var(--btn-on-bg); border-color:var(--btn-on-bd); color:var(--btn-on-ink); }
    .imd-grid.fit { grid-template-columns:repeat(var(--cols, 4), minmax(0, 1fr)); }
    .imd-grid.fit .mc:hover { transform:none; }
    .imd-grid.compact .hrs { display:none; }          /* จอเล็ก/เครื่องเยอะ: ซ่อนกราฟรายชั่วโมง */
    .imd-grid.compact .mc-foot { margin-bottom:6px; }

    .imd-tabs::-webkit-scrollbar { display:none; }
    .s-sum > div { display:flex; align-items:baseline; gap:10px; flex-wrap:wrap; }
    .s-sum > div em { flex-basis:100%; margin-top:0; }

    /* จอแคบ (เช่น TV ที่ตั้ง scale สูง): ยังเรียงแถวเดียว แค่ย่อขนาด */
    @media (max-width:1300px) {
        .imd-top { grid-template-columns:repeat(4, minmax(0,1fr)) minmax(0,1.6fr); gap:8px; }
        .imd-stat { padding:7px 10px; gap:9px; border-radius:11px; }
        .imd-stat .ic { width:28px; height:28px; border-radius:8px; }
        .imd-stat .ic svg { width:14px; height:14px; }
        .imd-stat b { font-size:18px; }
        .imd-stat span { font-size:10px; letter-spacing:.05em; }
        .s-sum b { font-size:20px; }
        .s-sum em { font-size:10.5px; }
    }
    @media (max-width:640px) {   /* มือถือ */
        .imd-top { grid-template-columns:repeat(2, 1fr); }
        .imd-top .s-sum { grid-column:1 / -1; }
    }


    /* ---------- Popup ประวัติเครื่อง (คลิกการ์ด) ---------- */
    .mc { cursor:pointer; }
    .dt-back { position:fixed; inset:0; z-index:9999; background:rgba(2,6,23,.62); display:none; align-items:center; justify-content:center; padding:16px; }
    .dt-back.open { display:flex; }
    .dt { width:min(960px, 100%); max-height:min(88vh, 900px); display:flex; flex-direction:column;
          background:var(--card); color:var(--ink); border:1px solid var(--line); border-radius:16px; box-shadow:0 30px 80px rgba(0,0,0,.5); overflow:hidden; }
    .dt-h { display:flex; align-items:center; gap:10px; padding:14px 18px; border-bottom:1px solid var(--line); }
    .dt-h h3 { margin:0; font-size:18px; font-weight:800; }
    .dt-h small { color:var(--mute); font-size:12.5px; }
    .dt-h .pill { margin-left:6px; }
    .dt-h input[type=date] { margin-left:auto; font:inherit; font-size:12.5px; padding:5px 8px; border-radius:8px;
          border:1px solid var(--line); background:var(--card2); color:var(--ink); color-scheme:dark light; }
    .dt-h button { border:0; background:var(--card2); color:var(--ink); width:32px; height:32px; border-radius:9px; font-size:18px; cursor:pointer; }
    .dt-tabs { display:flex; gap:6px; padding:10px 18px 0; }
    .dt-tabs button { border:0; background:transparent; color:var(--mute); font:inherit; font-size:13px; font-weight:800;
          padding:8px 14px; border-radius:9px 9px 0 0; cursor:pointer; border-bottom:2px solid transparent; }
    .dt-tabs button.on { color:var(--ink); border-bottom-color:#6366f1; background:var(--card2); }
    .dt-tabs button b { margin-left:6px; padding:1px 7px; border-radius:99px; background:var(--card2); font-size:11px; }
    .dt-body { padding:14px 18px 18px; overflow:auto; }
    .dt-pane { display:none; } .dt-pane.on { display:block; }
    .dt-msg { padding:30px; text-align:center; color:var(--mute); }
    .dt table { width:100%; border-collapse:collapse; font-size:13px; font-variant-numeric:tabular-nums; }
    .dt th { text-align:left; font-size:11px; letter-spacing:.06em; text-transform:uppercase; color:var(--mute); padding:7px 8px;
             border-bottom:1px solid var(--line); position:sticky; top:-14px; background:var(--card); }
    .dt td { padding:7px 8px; border-bottom:1px solid var(--line2); }
    .dt td.r, .dt th.r { text-align:right; }
    .dt .cat { display:inline-flex; align-items:center; gap:6px; font-weight:800; font-size:12px; }
    .dt .cat i { width:9px; height:9px; border-radius:3px; display:inline-block; }
    .dt .c-run i { background:var(--run); } .dt .c-idle i { background:var(--idle); } .dt .c-down i { background:var(--down); } .dt .c-off i { background:var(--off); }
    .dt .c-run { color:var(--run); } .dt .c-idle { color:var(--idle); } .dt .c-down { color:var(--down); } .dt .c-off { color:var(--off); }
    .dt tr.open td { background:rgba(99,102,241,.08); }
    .dt-sum { display:grid; grid-template-columns:repeat(4, minmax(0,1fr)); gap:10px; margin-bottom:14px; }
    .dt-sum div { border:1px solid var(--line); border-radius:12px; padding:10px 12px; background:var(--card2); }
    .dt-sum span { display:block; font-size:11px; font-weight:800; letter-spacing:.06em; text-transform:uppercase; color:var(--mute); }
    .dt-sum b { display:block; font-size:22px; font-weight:900; margin-top:2px; }
    .dt-sum em { font-style:normal; font-size:12px; color:var(--mute); }
    .dt-tl { position:relative; height:26px; border-radius:8px; overflow:hidden; background:var(--track); display:flex; margin:4px 0 4px; }
    .dt-tl i { display:block; height:100%; }
    .dt-tl i.run { background:var(--run); } .dt-tl i.idle { background:var(--idle); } .dt-tl i.down { background:var(--down); } .dt-tl i.off { background:var(--off); } .dt-tl i.none { background:transparent; }
    .dt-ax { display:flex; justify-content:space-between; font-size:10.5px; color:var(--mute); margin-bottom:14px; }
    .dt h4 { margin:14px 0 8px; font-size:13px; font-weight:800; }
    .dt-bar { height:8px; border-radius:99px; background:var(--track); overflow:hidden; min-width:60px; }
    .dt-bar i { display:block; height:100%; border-radius:99px; }
    @media (max-width:640px) { .dt-sum { grid-template-columns:repeat(2, 1fr); } }
    /* ---------- แท็บ OEE ย้อนหลัง ---------- */
    .oe-bar { display:flex; align-items:center; gap:6px; margin-bottom:12px; flex-wrap:wrap; }
    .oe-bar button { border:1px solid var(--line); background:var(--card2); color:var(--mute); font:inherit; font-size:12px; font-weight:800; padding:5px 11px; border-radius:8px; cursor:pointer; }
    .oe-bar button.on { color:var(--ink); border-color:#6366f1; }
    .oe-bar span { font-size:12px; color:var(--mute); margin-left:6px; }
    .oe-bar label { display:inline-flex; align-items:center; gap:5px; font-size:12px; font-weight:800; color:var(--mute); margin-left:6px; }
    .oe-bar input[type=date] { font:inherit; font-size:12.5px; padding:4px 7px; border-radius:8px; border:1px solid var(--line); background:var(--card2); color:var(--ink); color-scheme:dark light; }
    .oe-bar input.on { border-color:#6366f1; }
    .oe-bar .oe-info { flex-basis:100%; margin-left:0; }
    .oe-sum b small { font-size:13px; color:var(--mute); margin-left:2px; font-weight:800; }
    .oe-plot { height:210px; position:relative; }
    .oe-plot svg { display:block; width:100%; height:100%; overflow:visible; }
    .oe-plot .gl { stroke:var(--line); stroke-width:1; } .oe-plot .ax { fill:var(--mute); font-size:10.5px; } .oe-plot .vl { fill:var(--ink); font-size:10.5px; font-weight:800; }
    .oe-tip { position:fixed; z-index:10001; pointer-events:none; background:#0f172a; color:#f8fafc; border:1px solid #334155; font-size:12px; padding:7px 10px; border-radius:8px; display:none; line-height:1.5; }
    .dt td.oe-v { font-weight:900; }
    .oe-g { color:var(--run); } .oe-w { color:var(--idle); } .oe-b { color:var(--down); }
    .dt tr.oe-row { cursor:pointer; } .dt tr.oe-row:hover td { background:rgba(99,102,241,.08); }
    .dt tr.oe-none td { color:var(--mute); }
    .dt tfoot td { font-weight:900; border-top:2px solid var(--line); position:sticky; bottom:-18px; background:var(--card); }

    /* ---------- โหมด TV : ซ่อนแถบเมนูบน + ส่วนหัวกะทัดรัด ---------- */
    body.imd-tv .site-header { display:none !important; }
    body.imd-tv { padding:0 !important; margin:0 !important; overflow:hidden; }
    body.imd-tv form { margin:0 !important; padding:0 !important; max-width:none !important; }
    .imd.tv { padding:10px 12px 8px; min-height:100vh; box-sizing:border-box; }
    .imd.tv .imd-head { margin-bottom:8px; gap:10px; }
    .imd.tv .imd-head h2 { font-size:18px; }
    .imd.tv .imd-head a, .imd.tv #imdTheme, .imd.tv #imdFit { display:none; }
    .imd.tv .imd-tabs { margin-bottom:8px; padding:3px; }
    .imd.tv .imd-tabs button { padding:5px 11px; font-size:12px; }
    .imd.tv .imd-top { margin-bottom:8px; }
    #imdTv { margin-left:0; }
    .imd.tv #imdTv { margin-left:auto; opacity:.35; }
    .imd.tv #imdTv:hover { opacity:1; }
</style>
</asp:Content>


<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="imd dark" id="imdRoot">
    <div class="imd-head">
        <h2 id="imdTitle">Injection Machine Dashboard</h2>
        <span>Shift day <b id="imdDay">–</b> · <b id="imdNow">–</b></span>
        <span class="imd-db" id="imdDb" title=""></span>
        <a href="Machine_Monitor.aspx">Machine Monitor →</a>
        <button type="button" class="imd-btn" id="imdTheme" title="Toggle dark / light theme">☾ Dark</button>
        <button type="button" class="imd-btn" id="imdFit" title="Fit all machines on one screen">⤢ Fit screen</button>
        <button type="button" class="imd-btn" id="imdTv" title="TV mode: hide top menu + fullscreen (Esc or this button to exit) · direct link: ?tv=1">📺 TV</button>
    </div>

    <div class="imd-tabs" id="imdTabs"></div>

    <div class="imd-top">
        <div class="imd-stat s-run">
            <div class="ic"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4l14 8-14 8z"/></svg></div>
            <div><b id="cRun">0</b><span>Running</span></div>
        </div>
        <div class="imd-stat s-idle">
            <div class="ic"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M8 5v14 M16 5v14"/></svg></div>
            <div><b id="cIdle">0</b><span>Idle</span></div>
        </div>
        <div class="imd-stat s-down">
            <div class="ic"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l10 18H2z M12 10v4 M12 17.5v.5"/></svg></div>
            <div><b id="cDown">0</b><span>Breakdown</span></div>
        </div>
        <div class="imd-stat s-off">
            <div class="ic"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M12 3v8 M6.3 7.3a8 8 0 1 0 11.4 0"/></svg></div>
            <div><b id="cOff">0</b><span>Offline</span></div>
        </div>
        <div class="imd-stat s-sum">
            <div>
                <span>OEE AVG</span>
                <b id="cShots">–</b>
                <em id="cAvail">A – · P – · Q –</em>
            </div>
        </div>
    </div>

    <!-- Popup ประวัติเครื่อง: คลิกที่การ์ด -->
    <div class="dt-back" id="dtBack">
        <div class="dt" role="dialog" aria-modal="true">
            <div class="dt-h">
                <div><h3 id="dtTitle">–</h3><small id="dtSub">–</small></div>
                <span class="pill" id="dtPill"></span>
                <input type="date" id="dtDay" title="Production day (starts 08:00)" />
                <button type="button" id="dtClose" title="Close (Esc)">×</button>
            </div>
            <div class="dt-tabs">
                <button type="button" class="on" data-t="log">Downtime Log<b id="dtNLog">0</b></button>
                <button type="button" data-t="stop">Machine Stops<b id="dtNStop">0</b></button>
                <button type="button" data-t="ng">NG / Defects<b id="dtNNg">0</b></button>
                <button type="button" data-t="oee">OEE History<b id="dtNOee">–</b></button>
            </div>
            <div class="dt-body">
                <div class="dt-pane on" id="dtLog"></div>
                <div class="dt-pane" id="dtStop"></div>
                <div class="dt-pane" id="dtNg"></div>
                <div class="dt-pane" id="dtOee"></div>
            </div>
        </div>
    </div>
    <div class="imd-grid" id="imdGrid">
        <div class="imd-empty">No machine data yet (waiting for Node-RED)</div>
    </div>
</div>
</asp:Content>


<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script>
    // @ts-nocheck
    (function () {
        var REFRESH_MS = 3000;
        // ชื่อเครื่องจาก Node-RED -> รหัสเครื่อง (ตามตาราง 机台号)
        var MACHINE_CODE = {
            'MC13': 'UB-MC-PV-1-3', 'MC14': 'UB-MC-PV-1-4', 'MC15': 'UB-MC-PV-1-5', 'MC16': 'UB-MC-PV-1-6',
            'MC17': 'UB-MC-PV-1-7', 'MC18': 'UB-MC-PV-1-8',
            'MC21': 'UB-MC-PV-2-1', 'MC22': 'UB-MC-PV-2-2', 'MC23': 'UB-MC-PV-2-3', 'MC24': 'UB-MC-PV-2-4',
            'MC25': 'UB-MC-PV-2-5', 'MC26': 'UB-MC-PV-2-6', 'MC27': 'UB-MC-PV-1-1', 'MC28': 'UB-MC-PV-2-8',
            'MC7': 'UB-MC-PV-2-7', 'MC12': 'UB-MC-PV-1-2',
            // เครื่อง Process อื่น
            'SB04': 'Seambuffing 4', 'SB01': 'Seambuffing 4 (old)', 'SB02': 'Seambuffing 2', 'SB03': 'Seambuffing 3'
        };
        function nameOf(m) { return codeOf(m.machine) || m.machine; }     // แสดงรหัสเครื่องแทนชื่อ MCxx
        function codeOf(name) {
            if (/^UB-/i.test(name || '')) return String(name).toUpperCase();   // Node-RED ส่งรหัสเครื่องมาเองแล้ว
            // รองรับชื่อหลายแบบ: "MC7", "MC-7", "MC07", "mc 7" -> "MC7"
            var key = String(name || '').toUpperCase().replace(/[^A-Z0-9]/g, '').replace(/^MC0+(?=\d)/, 'MC');
            if (MACHINE_CODE[key]) return MACHINE_CODE[key];
            if (MACHINE_CODE[name]) return MACHINE_CODE[name];
            var t = /^MC(\d)(\d)$/i.exec(name || '');             // เครื่องใหม่ที่ไม่มีในตาราง: MCxy -> UB-MC-PV-x-y
            return t ? 'UB-MC-PV-' + t[1] + '-' + t[2] : '';
        }
        // ---------- Process (แท็บ) ----------
        var PROCESSES = ['Mixing', 'Extruder', 'Core Molding', 'Glebar', 'Mixing Surlyn', 'Injection',
                         'Seambuffing', 'Vanmark', 'Coating', 'Stamping', 'Packing', 'QC Vanmark', 'QC Coating'];
        // เครื่องที่ไม่ใช่เครื่องฉีด ใส่ Process ที่นี่ (หรือให้ Node-RED ส่ง "process" มาใน JSON)
        var MACHINE_PROC = {
            // 'MX01': 'Mixing',
        };
        function procOf(m) { return m.process || MACHINE_PROC[m.machine] || 'Injection'; }

        var curProc = 'All';
        try {
            var qp = new URLSearchParams(location.search).get('proc');
            var sp = localStorage.getItem('imd.proc');
            if (qp && (qp === 'All' || PROCESSES.indexOf(qp) >= 0)) curProc = qp;
            else if (sp && (sp === 'All' || PROCESSES.indexOf(sp) >= 0)) curProc = sp;
        } catch (e) { }
        var LABEL = { run: 'RUNNING', idle: 'IDLE', down: 'BREAKDOWN', off: 'OFFLINE' };
        var LAMP  = { run: '#10b981', idle: '#f59e0b', down: '#ef4444', off: '#cbd5e1' };

        function esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;'); }
        function fmt(n) { return n == null ? '–' : Number(n).toLocaleString('en-US'); }
        function f1(n) { return Number(n || 0).toFixed(1); }
        function qf(n) { return (Math.floor(Number(n || 0) * 100 + 1e-7) / 100).toFixed(2); }   // Quality: 2 ตำแหน่ง ปัดลง (มี NG จะไม่โชว์ 100%)
        function hm(min) { min = Math.round(min || 0); return Math.floor(min / 60) + 'h ' + ('0' + (min % 60)).slice(-2) + 'm'; }
        function shortTime(s) {                                  // "2026-10-06 08:15:30" -> "06/10 08:15"
            var t = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})/.exec(s || '');
            return t ? t[3] + '/' + t[2] + ' ' + t[4] + ':' + t[5] : '–';
        }
        function hr4(h) { return h == null ? '–' : Number(h).toFixed(4); }      // ชั่วโมง ทศนิยม 4 ตำแหน่ง (เหมือนหน้าจอเก่า)
        function fullTime(s) {                                                  // "2026-10-06 12:54:24" -> "06/10/2026, 12:54:24"
            var t = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}:\d{2}:\d{2})/.exec(s || '');
            return t ? t[3] + '/' + t[2] + '/' + t[1] + ', ' + t[4] : '–';
        }
        function ringColor(v) { return v >= 85 ? '#10b981' : v >= 60 ? '#0ea5e9' : v >= 40 ? '#f59e0b' : '#ef4444'; }
        function stOf(m) {
            if (!m.online || m.mode === 'offline') return 'off';
            if (m.status >= 17) return 'down';                   // 17-20 = Error
            return m.mode === 'operating' ? 'run' : 'idle';      // 2,4 = run | 0,1,8 = idle
        }

        // ---------- รูปเครื่องฉีด (เหมือน Machine Monitor) ----------
        function machineSvg(st) {
            var lamp = LAMP[st];
            var dim = function (c) { return c === lamp ? 1 : .18; };
            return '' +
            '<svg viewBox="0 0 260 120" xmlns="http://www.w3.org/2000/svg">' +
              '<defs>' +
                '<linearGradient id="bd" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e2e8f0"/><stop offset="1" stop-color="#cbd5e1"/></linearGradient>' +
                '<linearGradient id="bl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#818cf8"/><stop offset="1" stop-color="#4f46e5"/></linearGradient>' +
              '</defs>' +
              '<ellipse cx="130" cy="110" rx="118" ry="6" fill="#0f172a" opacity=".07"/>' +
              '<rect x="18" y="74" width="224" height="30" rx="6" fill="url(#bd)"/>' +
              '<rect x="18" y="98" width="224" height="6" rx="3" fill="#94a3b8"/>' +
              '<rect x="26" y="36" width="70" height="40" rx="6" fill="url(#bl)"/>' +
              '<rect x="34" y="44" width="54" height="24" rx="4" fill="#c7d2fe" opacity=".55"/>' +
              '<g class="ram"><rect x="44" y="50" width="22" height="12" rx="2" fill="#e0e7ff"/></g>' +
              '<line x1="26" y1="42" x2="96" y2="42" stroke="#312e81" stroke-width="2" opacity=".35"/>' +
              '<line x1="26" y1="70" x2="96" y2="70" stroke="#312e81" stroke-width="2" opacity=".35"/>' +
              '<rect x="96" y="40" width="14" height="34" rx="2" fill="#64748b"/>' +
              '<rect x="110" y="50" width="96" height="14" rx="7" fill="#94a3b8"/>' +
              '<line class="flow" x1="116" y1="57" x2="200" y2="57" stroke="#f97316" stroke-width="3" stroke-dasharray="6 10" stroke-linecap="round" opacity=".85"/>' +
              '<rect x="196" y="40" width="34" height="36" rx="5" fill="url(#bl)"/>' +
              '<g class="gear"><circle cx="213" cy="58" r="8" fill="none" stroke="#e0e7ff" stroke-width="3" stroke-dasharray="4 3"/></g>' +
              '<path d="M142 18 h26 l-7 20 h-12 z" fill="#a5b4fc"/>' +
              '<rect x="150" y="38" width="10" height="12" fill="#818cf8"/>' +
              '<rect x="112" y="78" width="40" height="18" rx="3" fill="#1e293b"/>' +
              '<rect x="116" y="82" width="20" height="10" rx="1.5" fill="' + lamp + '" opacity=".75"/>' +
              '<circle cx="144" cy="87" r="3" fill="#475569"/>' +
              '<rect x="236" y="20" width="4" height="56" fill="#64748b"/>' +
              '<rect x="232" y="6"  width="12" height="9" rx="2" fill="#ef4444" opacity="' + dim('#ef4444') + '"/>' +
              '<rect x="232" y="15" width="12" height="9" rx="2" fill="#f59e0b" opacity="' + dim('#f59e0b') + '"/>' +
              '<rect x="232" y="24" width="12" height="9" rx="2" fill="#10b981" opacity="' + dim('#10b981') + '"/>' +
            '</svg>';
        }

        function bar(cls, name, v) {
            return '<div class="r ' + cls + '"><span>' + name + '</span>' +
                   '<div class="t"><i style="width:' + Math.min(100, v || 0) + '%"></i></div>' +
                   '<b>' + (v == null ? '–' : (cls === 'rQ' ? qf(v) : f1(v)) + '%') + '</b></div>';
        }
        // ป้าย Q บอกที่มา: Quality = OK/NG จาก PLC | ERP = NG รายเครื่องจาก ERP | Process = Q ทั้ง Process จาก ERP | (100%) = ยังไม่มีข้อมูล NG
        function qLabel(m) {
            return m.qualitySource === 'ERP' ? '<em>Q</em>ERP' : m.qualitySource === 'ERP-P' ? '<em>Q</em>Process'
                 : m.qualitySource === '100%' ? '<em>Q</em>(100%)' : '<em>Q</em>Quality';
        }
        function kv(cls, icon, label, value) {
            return '<div class="kv ' + cls + '"><span>' + icon + label + '</span><b>' + value + '</b></div>';
        }
        function ico(n) {
            var p = {
                clock: 'M12 7v5l3 2 M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z',
                pause: 'M9 6v12 M15 6v12',
                hash:  'M5 9h14 M5 15h14 M10 4L8 20 M16 4l-2 16',
                play:  'M7 5l12 7-12 7z',
                cycle: 'M4 12a8 8 0 0 1 14-5.3 M20 4v4h-4 M20 12a8 8 0 0 1-14 5.3 M4 20v-4h4',
                shot:  'M4 20h16 M7 16V9 M12 16V5 M17 16v-4'
            }[n];
            return '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="' + p + '"/></svg>';
        }

        // ---------- การ์ด ----------
        function card(m, nowIdx) {
            var st = stOf(m);
            var a = m.availability;
            var tot = m.operatingHours + m.lossHours + m.offlineHours;
            var lossPct = tot > 0 ? (m.lossHours + m.offlineHours) * 100 / tot : null;
            var prog = m.jobProgress != null ? Math.min(100, m.jobProgress) : 0;
            var dim = st === 'off' || a == null;
            var max = Math.max.apply(null, m.hourly.map(function (h) { return h.shots; }).concat([1]));
            // Injection นับเป็น Shot | แผนกอื่น (Seambuffing ฯลฯ) นับจาก Counter ที่เพิ่มขึ้น = ชิ้น
            var isInj = !m.process || m.process === 'Injection';
            var unit = isInj ? 'shots' : 'pcs';
            var bars = m.hourly.map(function (h, i) {
                return '<i' + (i === nowIdx ? ' class="now"' : '') + ' title="' + h.hour + ' : ' + fmt(h.shots) + ' ' + unit + '" style="height:' + (h.shots / max * 100) + '%"></i>';
            }).join('');
            var hNow = (m.hourly[nowIdx] || {}).shots, hPrev = nowIdx > 0 ? (m.hourly[nowIdx - 1] || {}).shots : null;
            var sub = st === 'off'
                ? procOf(m) + ' · ' + (m.lastOnline ? 'Last data ' + String(m.lastOnline).slice(11, 19) : 'No PLC data yet') +
                  (m.lastUpdate && !m.stale ? ' · IoT reports offline' : ' · IoT not sending')
                : m.speedPerMin != null
                ? procOf(m) + ' · ' + Number(m.speedPerMin).toFixed(1) + ' pcs/min'
                : procOf(m) + ' · Op ' + (m.operator || '–') + ' · CT ' + (m.cycleTime != null ? Number(m.cycleTime).toFixed(1) + 's' : '–') +
                  ' / Std ' + (m.idealCycleTime != null ? Number(m.idealCycleTime).toFixed(1) + 's' : '–');
            // เครื่องที่มี OK/NG (เช่น Seambuffing) -> แสดงกล่อง OK/NG | เครื่องฉีด -> แสดง Target / Job
            var erpQ = (m.qualitySource === 'ERP' || m.qualitySource === 'ERP-P') && (m.process && m.process !== 'Injection');   // NG มาจาก ERP
            var hasQ = m.okCount != null || (m.okToday || 0) + (m.ngToday || 0) > 0 || (!!m.process && m.process !== 'Injection');   // เครื่องที่ส่ง OK/NG มา -> แสดง A x P x Q = OEE
            // วงกลมแสดง OEE ทุกเครื่อง (ยังไม่ได้ตั้ง Std CT -> คิด P ไม่ได้ -> แสดง "–" และบอกให้ตั้ง Std CT)
            var ringV = m.oee, ringL = (m.oee == null && m.idealCycleTime == null && st !== 'off') ? 'SET STD CT' : 'OEE';
            var dimR = st === 'off' || ringV == null;

            return '' +
            '<div class="mc ' + st + '" data-id="' + esc(m.machine) + '">' +
              '<div class="mc-head">' +
                '<div><h4 title="' + esc(nameOf(m)) + '">' + esc(nameOf(m)) + '</h4>' +
                '<small title="' + esc(sub) + '">' + esc(sub) + '</small></div>' +
                '<span class="pill"><i></i>' + LABEL[st] + '</span>' +
              '</div>' +

              '<div class="mc-body">' +
                '<div class="art">' + machineSvg(st) + '</div>' +
                '<div class="ring' + (hasQ ? ' oee' : '') + '" style="--v:' + (dimR ? 0 : ringV) + ';--oc:' + ringColor(ringV || 0) + '">' +
                  '<div><b>' + (dimR ? '–' : f1(ringV) + '%') + '</b><span>' + ringL + '</span></div>' +
                '</div>' +
              '</div>' +

              // ตัวใหญ่ = ยอดรวมทั้งวัน (2 กะ ตั้งแต่ 08:00 ไม่หายแม้หน้าเครื่องรีเซ็ต) | ขวา = Counter ปัจจุบันบนหน้าเครื่อง
              '<div class="cnt"><div class="cday"><span>Total today</span><div><b>' + fmt(m.piecesToday) + '</b><em>pcs</em></div></div>' +
                '<div class="cnow"><span>Counter now</span><b>' + fmt(m.piecesCounter) + '</b></div></div>' +

              (hasQ
                ? (erpQ
                    ? '<div class="okng" title="ยอดจาก ERP (พนักงานคีย์) วันนี้ตั้งแต่ 08:00 · อัปเดตทุก 5 นาที">' +
                      '<div class="ok"><span>OK · ERP</span><b>' + fmt(m.erpOut) + '</b></div>' +
                      '<div class="ng"><span>NG · ERP</span><b>' + fmt(m.erpNg) + '</b></div></div>'
                    : '<div class="okng"><div class="ok"><span>OK</span><b>' + fmt(m.okCount) + '</b></div>' +
                      '<div class="ng"><span>NG</span><b>' + fmt(m.ngCount) + '</b></div></div>')
                : '') +

              '<div class="apq">' +
              (hasQ
                ? bar('rA', '<em>A</em>Avail.', a) +
                  bar('rP', '<em>P</em>Perf.', m.performance) +
                  bar('rQ', qLabel(m), m.quality)
                : bar('rA', '<em>A</em>Avail.', a) +
                  bar('rP', '<em>P</em>Perf.', m.performance) +
                  bar('rQ', qLabel(m), m.quality)) +
              '</div>' +

              '<div class="rt">' +
                '<span>Operating time:</span><b>' + hr4(m.operatingHours) + '<small>Hour</small></b>' +
                '<span>Loss time:</span><b class="loss">' + hr4(m.lossHours) + '<small>Hour</small></b>' +
                '<span>Count Start:</span><b class="cs">' + esc(fullTime(m.countStart)) + '</b>' +
              '</div>' +

              '<div class="mc-foot">' +
                (hasQ ? (erpQ ? kv('count', ico('hash'), 'NG % (ERP)', (m.quality != null ? (Math.ceil((100 - m.quality) * 100 - 1e-7) / 100).toFixed(2) + '%' : '–'))
                      : kv('count', ico('hash'), 'OK / NG today', fmt(m.okToday) + ' <small style="color:#fb7185">/ ' + fmt(m.ngToday) + '</small>'))
                      : kv('count', ico('hash'), 'Target', m.targetShots ? fmt(m.targetShots) : '–')) +
                kv('', ico('cycle'), 'Cycle time', m.cycleTime != null ? Number(m.cycleTime).toFixed(1) + ' s' : '–') +
                (isInj ? kv('', ico('shot'), 'Shots today', fmt(m.shotsToday))
                       : kv('', ico('shot'), 'This hour', fmt(hNow) + ' <small title="Last hour">/ ' + fmt(hPrev) + '</small>')) +
              '</div>' +

              '<div class="hrs"><div class="lbl">' + (isInj ? 'Shots / hour' : 'Counter / hour (pcs)') + '</div><div class="bars">' + bars + '</div></div>' +

              (hasQ
              ? '<div class="mc-job">' +
                  '<span>Std CT</span><b>' + (m.idealCycleTime != null ? Number(m.idealCycleTime).toFixed(2) + ' s' : '–') + '</b>' +
                  '<div class="prog" title="OEE = A × P × Q"><i style="width:' + Math.min(100, m.oee || 0) + '%"></i></div>' +
                  '<span>OEE ' + (m.oee != null ? f1(m.oee) + '%' : '–') + '</span>' +
                '</div>'
              : '<div class="mc-job">' +
                '<span>Job</span><b>Shot ' + fmt(m.shotCount) + (m.targetShots ? ' / ' + fmt(m.targetShots) : '') + '</b>' +
                '<div class="prog" title="' + (m.targetShots ? 'Target ' + fmt(m.targetShots) : 'No target set on HMI') + '"><i style="width:' + prog + '%"></i></div>' +
                '<span>' + (m.jobProgress != null ? Math.round(prog) + '%' : '–') + '</span>' +
              '</div>') +
            '</div>';
        }

        // ---------- สรุปด้านบน ----------
        function summary(list) {
            var c = { run: 0, idle: 0, down: 0, off: 0 }, pcs = 0, allPcs = true, shots = 0, sa = 0, n = 0, so = 0, no = 0, sp = 0, np = 0, sq = 0, nq = 0;
            list.forEach(function (m) {
                c[stOf(m)]++;
                shots += m.shotsToday || 0;
                pcs += m.piecesToday || 0;
                if (!m.process || m.process === 'Injection') allPcs = false;
                if (m.availability != null) { sa += m.availability; n++; }
                if (m.oee != null) { so += m.oee; no++; }
                if (m.performance != null) { sp += m.performance; np++; }
                if (m.quality != null) { sq += m.quality; nq++; }
            });
            document.getElementById('cRun').textContent = c.run;
            document.getElementById('cIdle').textContent = c.idle;
            document.getElementById('cDown').textContent = c.down;
            document.getElementById('cOff').textContent = c.off;
            // OEE AVG = เฉลี่ยเฉพาะเครื่องที่คิด OEE ได้ (มี OK/NG + Std CT)
            var pct = function (s, k) { return k ? f1(s / k) + '%' : '–'; };
            document.getElementById('cShots').textContent = no ? pct(so, no) : '–';
            document.getElementById('cAvail').textContent =
                'A ' + pct(sa, n) + ' · P ' + pct(sp, np) + ' · Q ' + (nq ? qf(sq / nq) + '%' : '–') +
                (allPcs ? ' · Pcs ' + fmt(pcs) : ' · Shots ' + fmt(shots)) + ' · ' + list.length + ' machines';
        }

        // ---------- พอดีจอ: คำนวณจำนวนคอลัมน์ + ขนาดการ์ดให้เห็นทุกเครื่องโดยไม่ต้องเลื่อน ----------
        var CARD_W = 270, GAP = 12, Z_MIN = 0.45, Z_MAX = 1.35, COMPACT_BELOW = 0.75;
        var fitOn = true;
        try { var saved = localStorage.getItem('imd.fit'); if (saved !== null) fitOn = saved === '1'; } catch (e) { }

        function measure(grid, cards) {                // ความสูงการ์ดจริงที่ความกว้าง CARD_W (ไม่ย่อ)
            grid.style.gridTemplateColumns = 'repeat(' + cards.length + ', ' + CARD_W + 'px)';
            var h = 0;
            for (var i = 0; i < cards.length; i++) h = Math.max(h, cards[i].offsetHeight);
            grid.style.gridTemplateColumns = '';
            return h;
        }
        function bestLayout(n, aw, ah, h) {
            var best = { c: 1, z: 0 };
            for (var c = 1; c <= n; c++) {
                var rows = Math.ceil(n / c);
                var z = Math.min(aw / (c * CARD_W + (c - 1) * GAP), ah / (rows * h + (rows - 1) * GAP));
                if (z > best.z) best = { c: c, z: z };
            }
            best.z = Math.max(Z_MIN, Math.min(Z_MAX, best.z));
            return best;
        }
        function fit() {
            var grid = document.getElementById('imdGrid');
            var cards = grid.querySelectorAll('.mc');
            var btn = document.getElementById('imdFit');
            btn.classList.toggle('on', fitOn);
            grid.style.zoom = '';
            grid.classList.remove('compact');
            if (!fitOn || !cards.length) { grid.classList.remove('fit'); return; }

            grid.classList.add('fit');
            var aw = grid.getBoundingClientRect().width;
            var ah = Math.max(240, window.innerHeight - grid.getBoundingClientRect().top - 24);
            var best = bestLayout(cards.length, aw, ah, measure(grid, cards));
            if (best.z < COMPACT_BELOW) {               // เครื่องเยอะ/จอเล็ก -> ลองแบบกะทัดรัด
                grid.classList.add('compact');
                var b2 = bestLayout(cards.length, aw, ah, measure(grid, cards));
                if (b2.z > best.z) best = b2; else grid.classList.remove('compact');
            }
            grid.style.setProperty('--cols', best.c);
            grid.style.zoom = best.z;
        }
        // ---------- ธีมมืด / สว่าง (ค่าเริ่มต้น = มืด) ----------
        var dark = true;
        try { var th = localStorage.getItem('imd.theme'); if (th) dark = th !== 'light'; } catch (e) { }
        function applyTheme() {
            var root = document.getElementById('imdRoot'), b = document.getElementById('imdTheme');
            root.classList.toggle('dark', dark);
            b.classList.toggle('on', dark);
            b.textContent = dark ? '☾ Dark' : '☀ Light';
            document.body.style.background = dark ? '#070b16' : '';     // พื้นหลังรอบนอก (Site.Master) ให้กลืนกัน
        }
        document.getElementById('imdTheme').addEventListener('click', function () {
            dark = !dark;
            try { localStorage.setItem('imd.theme', dark ? 'dark' : 'light'); } catch (e) { }
            applyTheme();
        });
        applyTheme();

        // ---------- โหมด TV (?tv=1 หรือกดปุ่ม 📺 TV) ----------
        var tvOn = /[?&]tv=1\b/.test(location.search);
        if (!tvOn) { try { tvOn = localStorage.getItem('imd.tv') === '1'; } catch (e) { } }
        if (/[?&]tv=0\b/.test(location.search)) tvOn = false;
        function applyTv() {
            document.body.classList.toggle('imd-tv', tvOn);
            document.getElementById('imdRoot').classList.toggle('tv', tvOn);
            var b = document.getElementById('imdTv');
            b.classList.toggle('on', tvOn);
            b.textContent = tvOn ? '✕ Exit TV' : '📺 TV';
            setTimeout(fit, 60);
        }
        document.getElementById('imdTv').addEventListener('click', function () {
            tvOn = !tvOn;
            try { localStorage.setItem('imd.tv', tvOn ? '1' : '0'); } catch (e) { }
            try {
                if (tvOn && document.documentElement.requestFullscreen && !document.fullscreenElement) document.documentElement.requestFullscreen();
                if (!tvOn && document.fullscreenElement) document.exitFullscreen();
            } catch (e) { }
            applyTv();
        });
        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape' && tvOn && !document.fullscreenElement) { tvOn = false; try { localStorage.setItem('imd.tv', '0'); } catch (x) { } applyTv(); }
        });
        applyTv();

        var fitTimer = null;
        window.addEventListener('resize', function () { clearTimeout(fitTimer); fitTimer = setTimeout(fit, 150); });
        document.getElementById('imdFit').addEventListener('click', function () {
            fitOn = !fitOn;
            try { localStorage.setItem('imd.fit', fitOn ? '1' : '0'); } catch (e) { }
            fit();
        });

        // ---------- วาด / อัปเดต (ไม่วาดรูปเครื่องใหม่ถ้าสถานะไม่เปลี่ยน animation จะไม่สะดุด) ----------
        var lastSig = '', lastData = null;

        function renderTabs(all) {
            var cnt = { All: all.length }, alert = {};
            all.forEach(function (m) {
                var p = procOf(m), st = stOf(m);
                cnt[p] = (cnt[p] || 0) + 1;
                if (st === 'down') { alert[p] = true; alert.All = true; }
            });
            document.getElementById('imdTabs').innerHTML = ['All'].concat(PROCESSES).map(function (p) {
                var n = cnt[p] || 0;
                return '<button type="button" data-p="' + esc(p) + '" class="' + (p === curProc ? 'on ' : '') + (n ? '' : 'empty ') + (alert[p] ? 'alert' : '') + '"' +
                       ' title="' + (alert[p] ? 'Machine in breakdown' : '') + '"><i></i>' + esc(p) + '<b>' + n + '</b></button>';
            }).join('');
            document.getElementById('imdTitle').textContent = curProc === 'All' ? 'Machine Dashboard' : curProc + ' Machine Dashboard';
            document.title = document.getElementById('imdTitle').textContent;
        }
        document.getElementById('imdTabs').addEventListener('click', function (e) {
            var b = e.target.closest('button'); if (!b) return;
            curProc = b.getAttribute('data-p');
            try {
                localStorage.setItem('imd.proc', curProc);
                var u = new URL(location.href); u.searchParams.set('proc', curProc); history.replaceState(null, '', u);
            } catch (er) { }
            lastSig = '';
            if (lastData) render(lastData);
        });

        // ค่าจาก HMI ที่ไม่ได้ตั้ง / อ่านผิดรูปแบบ -> ไม่แสดง
        function validTime(s) {
            var x = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/.exec(s || '');
            return !!x && +x[2] >= 1 && +x[2] <= 12 && +x[3] >= 1 && +x[3] <= 31 && +x[4] < 24 && +x[5] < 60 && +x[6] < 60;
        }
        function clean(m) {
            if (m.targetShots != null && m.targetShots >= 999999) { m.targetShots = null; m.jobProgress = null; }  // 999999 / 99999999 = ไม่ได้ตั้งเป้า
            if (!validTime(m.jobStart)) m.jobStart = '';
            if (!validTime(m.jobFinish)) m.jobFinish = '';
            return m;
        }

        function render(d) {
            lastData = d;
            var all = (d.machines || []).map(clean);
            renderTabs(all);
            var list = curProc === 'All' ? all : all.filter(function (m) { return procOf(m) === curProc; });
            list = list.slice().sort(function (a, b) {                      // เรียงตามรหัสเครื่อง UB-MC-PV-1-1, 1-3, ...
                return nameOf(a).localeCompare(nameOf(b), undefined, { numeric: true });
            });
            var day = /^(\d{4})-(\d{2})-(\d{2})/.exec(d.dayStart || '');
            document.getElementById('imdDay').textContent = day ? day[3] + '/' + day[2] + '/' + day[1] : '–';
            document.getElementById('imdNow').textContent = (d.serverTime || '').slice(11);
            summary(list);
            var dbEl = document.getElementById('imdDb'), db = d.db || {};
            if (!db.enabled)      { dbEl.className = 'imd-db off'; dbEl.textContent = 'DB: not saving'; }
            else if (db.lastError){ dbEl.className = 'imd-db err'; dbEl.textContent = 'DB ✕ error'; }
            else                  { dbEl.className = 'imd-db ok';  dbEl.textContent = 'DB ✓ ' + (db.lastWrite ? db.lastWrite.slice(11, 16) : 'pending'); }
            dbEl.title = db.lastError || (db.lastWrite ? 'Last saved ' + db.lastWrite : '');
            var grid0 = document.getElementById('imdGrid');
            if (!list.length) {
                if (lastSig !== 'empty:' + curProc) {
                    grid0.innerHTML = '<div class="imd-empty">No machines reporting in ' + esc(curProc) + ' yet</div>';
                    grid0.classList.remove('fit', 'compact'); grid0.style.zoom = '';
                    lastSig = 'empty:' + curProc;
                }
                return;
            }

            var nowIdx = Math.floor((new Date() - new Date((d.dayStart || '').replace(' ', 'T'))) / 3600000);
            var sig = curProc + '#' + list.map(function (m) { return m.machine + ':' + stOf(m); }).join('|');
            var grid = document.getElementById('imdGrid');

            if (sig !== lastSig) {
                grid.innerHTML = list.map(function (m) { return card(m, nowIdx); }).join('');
                lastSig = sig;
                fit();
                return;
            }
            list.forEach(function (m) {
                var el = grid.querySelector('.mc[data-id="' + esc(m.machine) + '"]');
                if (!el) return;
                var t = document.createElement('div');
                t.innerHTML = card(m, nowIdx);
                var n = t.firstChild;
                ['.mc-head', '.ring', '.cnt', '.okng', '.apq', '.rt', '.mc-foot', '.hrs', '.mc-job'].forEach(function (s) {
                    var a = el.querySelector(s), b = n.querySelector(s);
                    if (a && b) a.parentNode.replaceChild(b, a);
                });
            });
        }

        function load() {
            fetch('?format=json', { cache: 'no-store' })
                .then(function (r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
                .then(render)
                .catch(function (e) { document.getElementById('imdNow').textContent = 'Failed to load: ' + e.message; });
        }
        // ---------- Popup ประวัติเครื่อง (Downtime Log / เครื่องหยุด) ----------
        var dtMc = null, dtTab = 'log', dtData = null;
        var CAT = { run: 'Running', idle: 'Idle', down: 'Breakdown', off: 'Offline' };
        function dur(sec) {
            sec = Math.round(sec || 0);
            var h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s2 = sec % 60;
            return h ? h + 'h ' + m + 'm' : m ? m + 'm ' + s2 + 's' : s2 + 's';
        }
        function hm(t) { return t ? String(t).slice(11, 16) : ''; }
        function catHtml(c) { return '<span class="cat c-' + c + '"><i></i>' + (CAT[c] || c) + '</span>'; }
        function dayStr(d) { return d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2); }
        function prodDay() { var d = new Date(); if (d.getHours() < 8) d.setDate(d.getDate() - 1); return dayStr(d); }

        function openDt(id) {
            var m = (lastData && lastData.machines || []).filter(function (x) { return x.machine === id; })[0];
            dtMc = id;
            document.getElementById('dtTitle').textContent = m ? nameOf(m) : id;
            var st = m ? stOf(m) : 'off';
            var pill = document.getElementById('dtPill');
            var col = { run: ['--run', '--run-bg'], idle: ['--idle', '--idle-bg'], down: ['--down', '--down-bg'], off: ['--off', '--off-bg'] }[st];
            pill.style.setProperty('--st', 'var(' + col[0] + ')'); pill.style.setProperty('--st-bg', 'var(' + col[1] + ')');
            pill.innerHTML = '<i></i>' + LABEL[st];
            document.getElementById('dtSub').textContent = (m ? procOf(m) : '') + ' · ' + id;
            document.getElementById('dtDay').value = prodDay();
            document.getElementById('dtBack').classList.add('open');
            document.getElementById('dtNNg').textContent = '…';
            document.getElementById('dtNOee').textContent = '–'; oeeKey = '';
            loadDt(); loadNg(); if (dtTab === 'oee') loadOee();
        }
        function closeDt() { dtMc = null; document.getElementById('dtBack').classList.remove('open'); }
        function setDtTab(t) {
            dtTab = t;
            [].forEach.call(document.querySelectorAll('.dt-tabs button'), function (b) { b.classList.toggle('on', b.getAttribute('data-t') === t); });
            document.getElementById('dtLog').classList.toggle('on', t === 'log');
            document.getElementById('dtStop').classList.toggle('on', t === 'stop');
            document.getElementById('dtNg').classList.toggle('on', t === 'ng');
            document.getElementById('dtOee').classList.toggle('on', t === 'oee');
            if (t === 'oee') loadOee();
        }
        function loadDt() {
            if (!dtMc) return;
            var msg = '<div class="dt-msg">Loading…</div>';
            if (!dtData || dtData.machine !== dtMc) { document.getElementById('dtLog').innerHTML = msg; document.getElementById('dtStop').innerHTML = msg; }
            var id = dtMc;
            fetch('?format=log&machine=' + encodeURIComponent(id) + '&day=' + document.getElementById('dtDay').value, { cache: 'no-store' })
                .then(function (r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
                .then(function (d) { if (dtMc === id) { dtData = d; renderDt(d); } })
                .catch(function (e) {
                    var err = '<div class="dt-msg">Failed to load: ' + esc(e.message) + '</div>';
                    document.getElementById('dtLog').innerHTML = err; document.getElementById('dtStop').innerHTML = err;
                });
        }
        // ----- แท็บ 3 : NG / Defects (จาก ERP รายเครื่อง ราย Lot + สาเหตุ) -----
        function loadNg() {
            var id = dtMc; if (!id) return;
            var el = document.getElementById('dtNg');
            if (!el.getAttribute('data-mc') || el.getAttribute('data-mc') !== id) el.innerHTML = '<div class="dt-msg">Loading…</div>';
            fetch('?format=log&kind=ng&machine=' + encodeURIComponent(id) + '&day=' + document.getElementById('dtDay').value, { cache: 'no-store' })
                .then(function (r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
                .then(function (d) { if (dtMc === id) { el.setAttribute('data-mc', id); renderNg(d); } })
                .catch(function (e) { el.innerHTML = '<div class="dt-msg">Failed to load: ' + esc(e.message) + '</div>'; });
        }
        function renderNg(d) {
            var el = document.getElementById('dtNg');
            var lots = d.lots || [], rs = d.reasons || [];
            document.getElementById('dtNNg').textContent = fmt(d.ng || 0);
            if (d.error) { el.innerHTML = '<div class="dt-msg">ERP: ' + esc(d.error) + '</div>'; return; }
            if (!lots.length) { el.innerHTML = '<div class="dt-msg">No ERP records for ' + esc(d.eqid || d.machine) + ' on this day</div>'; return; }
            var rate = (d.out + d.ng) > 0 ? d.ng * 100 / (d.out + d.ng) : 0;
            var withNg = lots.filter(function (l) { return l.ng > 0; }).length;
            var sum = '<div class="dt-sum">' +
                '<div><span class="c-down">Total NG</span><b>' + fmt(d.ng) + '</b><em>pcs</em></div>' +
                '<div><span>NG Rate</span><b>' + rate.toFixed(2) + '%</b><em>Quality ' + (d.quality != null ? d.quality.toFixed(2) + '%' : '–') + '</em></div>' +
                '<div><span>Output (ERP)</span><b>' + fmt(d.out) + '</b><em>pcs</em></div>' +
                '<div><span>Lots</span><b>' + lots.length + '</b><em>' + withNg + ' with NG</em></div>' +
                '</div>';
            var maxR = rs.reduce(function (a, r) { return Math.max(a, r.qty); }, 1);
            var top = rs.length ? '<h4>NG by Reason</h4><table><tbody>' + rs.map(function (r) {
                return '<tr><td>' + esc(r.reason) + '</td><td class="r" style="width:90px"><b>' + fmt(r.qty) + '</b></td>' +
                       '<td class="r" style="width:70px">' + (d.ng ? (r.qty * 100 / d.ng).toFixed(1) + '%' : '') + '</td>' +
                       '<td style="width:38%"><div class="dt-bar"><i style="width:' + (r.qty * 100 / maxR) + '%;background:var(--down)"></i></div></td></tr>';
            }).join('') + '</tbody></table>' : '<h4>NG by Reason</h4><div class="dt-msg">No NG recorded</div>';
            var rows = lots.map(function (l) {
                return '<tr><td>' + hm(l.time) + '</td><td>' + esc(l.lot) + '</td><td>' + esc(l.ball || '–') + '</td>' +
                    '<td class="r">' + fmt(l.out) + '</td>' +
                    '<td class="r">' + (l.ng ? '<b class="c-down">' + fmt(l.ng) + '</b>' : '0') + '</td>' +
                    '<td>' + esc((l.reasons || []).map(function (r) { return r.reason + ' (' + fmt(r.qty) + ')'; }).join(', ')) + '</td></tr>';
            }).join('');
            el.innerHTML = sum + top + '<h4>Lots (from ERP)</h4><table><thead><tr><th>Time</th><th>Lot / MO</th><th>Ball Model</th>' +
                '<th class="r">Output</th><th class="r">NG</th><th>Reasons</th></tr></thead><tbody>' + rows + '</tbody></table>';
        }

        // ----- แท็บ 4 : OEE History (รายวัน ย้อนหลัง N วัน จนถึงวันที่เลือก) -----
        var oeeDays = 14, oeeKey = '', oeeData = null, oeeFrom = '', oeeTo = '';   // oeeFrom/To = ช่วงที่เลือกเอง ('' = ใช้ปุ่ม N วัน)
        function oeCls(v) { return v == null ? '' : v >= 85 ? 'oe-g' : v >= 60 ? 'oe-w' : 'oe-b'; }
        function pctTxt(v) { return v == null ? '–' : v.toFixed(1) + '%'; }
        function qTxt(v) { return v == null ? '–' : v.toFixed(2) + '%'; }   // Quality 2 ตำแหน่ง (NG น้อยๆ จะไม่โชว์ 100%)
        function addDays(s, n) { var d = new Date(s + 'T00:00:00'); d.setDate(d.getDate() + n); return dayStr(d); }
        function loadOee(force) {
            var id = dtMc; if (!id) return;
            var to = oeeTo || document.getElementById('dtDay').value || prodDay(), from = oeeFrom || addDays(to, -(oeeDays - 1));
            var key = id + '|' + from + '|' + to;
            if (!force && key === oeeKey && oeeData) return;
            oeeKey = key;
            var el = document.getElementById('dtOee');
            el.innerHTML = oeeBar() + '<div class="dt-msg">Loading…</div>'; bindOeeBar();
            fetch('?format=oeedaily&machine=' + encodeURIComponent(id) + '&from=' + from + '&to=' + to, { cache: 'no-store' })
                .then(function (r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
                .then(function (d) { if (dtMc === id && oeeKey === key) { oeeData = d; renderOee(d); } })
                .catch(function (e) { if (oeeKey === key) { el.innerHTML = oeeBar() + '<div class="dt-msg">Failed to load: ' + esc(e.message) + '</div>'; bindOeeBar(); } });
        }
        function oeeBar(d) {
            var custom = !!oeeFrom, k = oeeKey.split('|');
            var f = oeeFrom || k[1] || '', t = oeeTo || k[2] || '';
            var nd = f && t ? Math.round((new Date(t + 'T00:00:00') - new Date(f + 'T00:00:00')) / 864e5) + 1 : 0;
            return '<div class="oe-bar">' + [7, 14, 30].map(function (n) { return '<button type="button" data-n="' + n + '"' + (!custom && n === oeeDays ? ' class="on"' : '') + '>' + n + ' days</button>'; }).join('') +
                '<label>From <input type="date" id="oeFrom" value="' + f + '"' + (custom ? ' class="on"' : '') + ' /></label>' +
                '<label>To <input type="date" id="oeTo" value="' + t + '"' + (custom ? ' class="on"' : '') + ' /></label>' +
                '<span class="oe-info">' + (d ? nd + ' days · production day 08:00–08:00 · click a day to open it in the other tabs' : '') + '</span></div>';
        }
        function bindOeeBar() {
            [].forEach.call(document.querySelectorAll('#dtOee .oe-bar button'), function (b) {
                b.onclick = function () { oeeDays = +b.getAttribute('data-n'); oeeFrom = oeeTo = ''; loadOee(true); };
            });
            var fi = document.getElementById('oeFrom'), ti = document.getElementById('oeTo');
            function apply() {
                var f = fi.value, t = ti.value;
                if (!f || !t) return;
                if (f > t) { var x = f; f = t; t = x; }
                var nd = Math.round((new Date(t + 'T00:00:00') - new Date(f + 'T00:00:00')) / 864e5) + 1;
                if (nd > 92) { f = addDays(t, -91); }                   // สูงสุด 92 วัน
                oeeFrom = f; oeeTo = t; loadOee(true);
            }
            if (fi) fi.onchange = apply;
            if (ti) ti.onchange = apply;
        }
        function renderOee(d) {
            var el = document.getElementById('dtOee'), t = d.total || {}, rows = d.rows || [];
            document.getElementById('dtNOee').textContent = t.oee != null ? Math.round(t.oee) + '%' : '–';
            var warn = (d.dbError ? '<div class="dt-msg">DB: ' + esc(d.dbError) + '</div>' : '') + (d.erpError ? '<div class="dt-msg" style="padding:6px">ERP: ' + esc(d.erpError) + ' (Quality assumed 100%)</div>' : '');
            var sum = '<div class="dt-sum oe-sum">' +
                '<div><span>OEE</span><b class="' + oeCls(t.oee) + '">' + pctTxt(t.oee) + '</b><em>' + (t.days || 0) + ' days with data</em></div>' +
                '<div><span>Availability</span><b>' + pctTxt(t.availability) + '</b><em>Run ' + fmt(t.runHours) + ' h / ' + fmt(t.plannedHours) + ' h</em></div>' +
                '<div><span>Performance</span><b>' + pctTxt(t.performance) + '</b><em>' + fmt(t.shots) + ' shots · ' + fmt(t.pieces) + ' pcs</em></div>' +
                '<div><span>Quality</span><b>' + qTxt(t.quality) + '</b><em>Good ' + fmt(t.erpGood) + ' · NG ' + fmt(t.erpNg) + '</em></div>' +
                '</div>';
            var body = rows.slice().reverse().map(function (r) {
                if (r.noData) return '<tr class="oe-none oe-row" data-d="' + r.day + '"><td>' + r.day.slice(5).replace('-', '/') + '</td><td colspan="10">No data</td></tr>';
                return '<tr class="oe-row" data-d="' + r.day + '"><td>' + r.day.slice(5).replace('-', '/') + '</td>' +
                    '<td class="r">' + r.runHours.toFixed(1) + '</td><td class="r">' + (r.lossHours + r.offlineHours).toFixed(1) + '</td>' +
                    '<td class="r">' + fmt(r.shots) + '</td><td class="r">' + fmt(r.pieces) + '</td>' +
                    '<td class="r">' + fmt(r.erpGood) + '</td><td class="r">' + (r.erpNg ? '<b class="c-down">' + fmt(r.erpNg) + '</b>' : r.erpNg == null ? '–' : '0') + '</td>' +
                    '<td class="r">' + pctTxt(r.availability) + '</td><td class="r">' + pctTxt(r.performance) + '</td>' +
                    '<td class="r">' + qTxt(r.quality) + (r.qualityAssumed ? '*' : '') + '</td>' +
                    '<td class="r oe-v ' + oeCls(r.oee) + '">' + pctTxt(r.oee) + '</td></tr>';
            }).join('');
            var foot = '<tfoot><tr><td>Total</td><td class="r">' + (t.runHours || 0).toFixed(1) + '</td><td class="r">' + ((t.lossHours || 0) + (t.offlineHours || 0)).toFixed(1) + '</td>' +
                '<td class="r">' + fmt(t.shots) + '</td><td class="r">' + fmt(t.pieces) + '</td><td class="r">' + fmt(t.erpGood) + '</td><td class="r">' + fmt(t.erpNg) + '</td>' +
                '<td class="r">' + pctTxt(t.availability) + '</td><td class="r">' + pctTxt(t.performance) + '</td><td class="r">' + qTxt(t.quality) + '</td>' +
                '<td class="r oe-v ' + oeCls(t.oee) + '">' + pctTxt(t.oee) + '</td></tr></tfoot>';
            el.innerHTML = oeeBar(d) + warn + sum + '<h4>Daily OEE</h4><div class="oe-plot" id="oePlot"></div>' +
                '<h4>Daily Breakdown <small style="color:var(--mute);font-weight:600">* no ERP output → Quality assumed 100%</small></h4>' +
                '<table><thead><tr><th>Day</th><th class="r">Run h</th><th class="r">Stop h</th><th class="r">Shots</th><th class="r">Pieces</th>' +
                '<th class="r">Good</th><th class="r">NG</th><th class="r">A</th><th class="r">P</th><th class="r">Q</th><th class="r">OEE</th></tr></thead><tbody>' + body + '</tbody>' + foot + '</table>';
            bindOeeBar();
            drawOee(rows);
            [].forEach.call(el.querySelectorAll('tr.oe-row'), function (tr) {
                tr.onclick = function () { document.getElementById('dtDay').value = tr.getAttribute('data-d'); loadDt(); loadNg(); setDtTab('log'); };
            });
        }
        var oeTip = null;
        function drawOee(rows) {
            var box = document.getElementById('oePlot'); if (!box) return;
            if (!oeTip) { oeTip = document.createElement('div'); oeTip.className = 'oe-tip'; document.body.appendChild(oeTip); }
            var W = box.clientWidth, H = box.clientHeight, L = 34, R = 6, T = 16, B = 22, n = rows.length;
            if (!rows.some(function (r) { return r.oee != null; })) { box.innerHTML = '<div class="dt-msg">No OEE data in this range</div>'; return; }
            var slot = (W - L - R) / n, bw = Math.max(4, Math.min(34, slot * 0.62)), Y = function (v) { return H - B - (H - B - T) * v / 100; };
            var s = '<svg viewBox="0 0 ' + W + ' ' + H + '">';
            [0, 25, 50, 75, 100].forEach(function (v) { s += '<line class="gl" x1="' + L + '" x2="' + (W - R) + '" y1="' + Y(v) + '" y2="' + Y(v) + '"/><text class="ax" x="' + (L - 5) + '" y="' + (Y(v) + 4) + '" text-anchor="end">' + v + '%</text>'; });
            var every = Math.ceil(n / Math.max(1, Math.floor((W - L - R) / 44)));
            rows.forEach(function (r, i) {
                var cx = L + slot * i + slot / 2, x = cx - bw / 2;
                if (r.oee != null && r.oee > 0) {
                    var y = Y(r.oee), h = H - B - y, rr = Math.min(4, bw / 2, h);
                    s += '<path d="M' + x + ',' + (H - B) + 'V' + (y + rr) + 'Q' + x + ',' + y + ' ' + (x + rr) + ',' + y + 'H' + (x + bw - rr) + 'Q' + (x + bw) + ',' + y + ' ' + (x + bw) + ',' + (y + rr) + 'V' + (H - B) + 'Z" fill="#6366f1"/>';
                    if (slot > 30) s += '<text class="vl" x="' + cx + '" y="' + (y - 4) + '" text-anchor="middle">' + Math.round(r.oee) + '</text>';
                } else if (!r.noData && r.oee != null) s += '<text class="ax" x="' + cx + '" y="' + (H - B - 4) + '" text-anchor="middle">0</text>';
                if (i % every === 0 || i === n - 1) s += '<text class="ax" x="' + cx + '" y="' + (H - 6) + '" text-anchor="middle">' + r.day.slice(8) + '/' + r.day.slice(5, 7) + '</text>';
                s += '<rect class="oe-hit" data-i="' + i + '" x="' + (L + slot * i) + '" y="' + T + '" width="' + slot + '" height="' + (H - B - T) + '" fill="transparent"/>';
            });
            box.innerHTML = s + '</svg>';
            [].forEach.call(box.querySelectorAll('.oe-hit'), function (el) {
                var r = rows[+el.getAttribute('data-i')];
                el.onmousemove = function (ev) {
                    oeTip.innerHTML = '<b>' + r.day + '</b>' + (r.noData ? '<br>No data' :
                        '<br>OEE <b>' + pctTxt(r.oee) + '</b><br>A ' + pctTxt(r.availability) + ' · P ' + pctTxt(r.performance) + ' · Q ' + qTxt(r.quality) + (r.qualityAssumed ? '*' : '') +
                        '<br>Run ' + r.runHours.toFixed(1) + ' h · ' + fmt(r.pieces) + ' pcs');
                    oeTip.style.display = 'block';
                    var x = ev.clientX + 14, y = ev.clientY + 14;
                    if (x + oeTip.offsetWidth > innerWidth - 8) x = ev.clientX - oeTip.offsetWidth - 14;
                    oeTip.style.left = x + 'px'; oeTip.style.top = y + 'px';
                };
                el.onmouseleave = function () { oeTip.style.display = 'none'; };
            });
        }

        function renderDt(d) {
            var ev = d.events || [];
            var stops = ev.filter(function (e) { return e.cat !== 'run'; });
            document.getElementById('dtNLog').textContent = ev.length;
            document.getElementById('dtNStop').textContent = stops.length;
            if (d.error) {
                var er = '<div class="dt-msg">' + esc(d.error) + '</div>';
                document.getElementById('dtLog').innerHTML = er; document.getElementById('dtStop').innerHTML = er; return;
            }

            // ----- แท็บ 1 : Downtime Log (ทุกการเปลี่ยนสถานะ ล่าสุดอยู่บน) -----
            var rows = ev.slice().reverse().map(function (e) {
                return '<tr' + (e.end ? '' : ' class="open"') + '>' +
                    '<td>' + hm(e.start) + ' – ' + (e.end ? hm(e.end) : '<b>Now</b>') + '</td>' +
                    '<td>' + catHtml(e.cat) + '</td>' +
                    '<td>' + esc(e.text || (e.code != null ? 'Code ' + e.code : '–')) + '</td>' +
                    '<td class="r">' + dur(e.sec) + '</td>' +
                    '<td class="r">' + (e.cntStart != null ? fmt(e.cntStart) : '–') + (e.cntEnd != null ? ' → ' + fmt(e.cntEnd) : '') + '</td>' +
                    '<td>' + esc(e.reason || '') + '</td></tr>';
            }).join('');
            document.getElementById('dtLog').innerHTML = ev.length
                ? '<table><thead><tr><th>Time</th><th>Status</th><th>Code / Message</th><th class="r">Duration</th><th class="r">Counter</th><th>Reason</th></tr></thead><tbody>' + rows + '</tbody></table>'
                : '<div class="dt-msg">No history for this day yet (saved to DB every minute)</div>';

            // ----- แท็บ 2 : เครื่องหยุด (สรุป + Timeline + จัดอันดับ) -----
            var t0 = new Date(String(d.dayStart).replace(' ', 'T')).getTime(), span = 24 * 3600e3;
            var nowT = Math.min(new Date(String(d.now).replace(' ', 'T')).getTime(), t0 + span);
            var tot = { run: 0, idle: 0, down: 0, off: 0 }, cnt = { idle: 0, down: 0, off: 0 };
            ev.forEach(function (e) { tot[e.cat] = (tot[e.cat] || 0) + e.sec; if (cnt[e.cat] != null) cnt[e.cat]++; });
            var all = tot.run + tot.idle + tot.down + tot.off || 1;
            var stopSec = tot.idle + tot.down + tot.off;
            var longest = stops.reduce(function (a, e) { return !a || e.sec > a.sec ? e : a; }, null);
            var sum = '<div class="dt-sum">' +
                '<div><span>Total Stop Time</span><b>' + dur(stopSec) + '</b><em>' + Math.round(stopSec * 100 / all) + '% of recorded time</em></div>' +
                '<div><span class="c-down">Breakdown</span><b>' + cnt.down + (cnt.down === 1 ? ' time' : ' times') + '</b><em>' + dur(tot.down) + '</em></div>' +
                '<div><span class="c-idle">Idle</span><b>' + cnt.idle + (cnt.idle === 1 ? ' time' : ' times') + '</b><em>' + dur(tot.idle) + '</em></div>' +
                '<div><span>Longest Stop</span><b>' + (longest ? dur(longest.sec) : '–') + '</b><em>' +
                    (longest ? (CAT[longest.cat] || '') + ' ' + hm(longest.start) + '–' + (longest.end ? hm(longest.end) : 'Now') : '') + '</em></div>' +
                '</div>';
            // timeline 08:00 -> 08:00
            var segs = [], pos = t0;
            ev.forEach(function (e) {
                var a = Math.max(t0, new Date(String(e.start).replace(' ', 'T')).getTime());
                var b = Math.min(nowT, a + e.sec * 1000);
                if (a > pos) segs.push('<i class="none" style="width:' + ((a - pos) * 100 / span) + '%"></i>');
                if (b > a) segs.push('<i class="' + e.cat + '" title="' + (CAT[e.cat] || e.cat) + ' ' + hm(e.start) + ' · ' + dur(e.sec) + '" style="width:' + ((b - a) * 100 / span) + '%"></i>');
                pos = Math.max(pos, b);
            });
            var ax = [0, 4, 8, 12, 16, 20, 24].map(function (h) { return '<span>' + ('0' + ((8 + h) % 24)).slice(-2) + ':00</span>'; }).join('');
            var tl = '<h4>Production Day Timeline (08:00 – 08:00)</h4><div class="dt-tl">' + segs.join('') + '</div><div class="dt-ax">' + ax + '</div>';
            // ตารางเครื่องหยุด เรียงตามนานสุด
            var maxS = stops.reduce(function (a, e) { return Math.max(a, e.sec); }, 1);
            var srows = stops.slice().sort(function (a, b) { return b.sec - a.sec; }).map(function (e) {
                var col = e.cat === 'down' ? 'var(--down)' : e.cat === 'idle' ? 'var(--idle)' : 'var(--off)';
                return '<tr' + (e.end ? '' : ' class="open"') + '><td>' + catHtml(e.cat) + '</td>' +
                    '<td>' + hm(e.start) + ' – ' + (e.end ? hm(e.end) : '<b>Now</b>') + '</td>' +
                    '<td>' + esc(e.text || (e.code != null ? 'Code ' + e.code : '–')) + '</td>' +
                    '<td class="r">' + dur(e.sec) + '</td>' +
                    '<td style="width:28%"><div class="dt-bar"><i style="width:' + (e.sec * 100 / maxS) + '%;background:' + col + '"></i></div></td></tr>';
            }).join('');
            document.getElementById('dtStop').innerHTML = sum + tl + '<h4>Stop List (longest first)</h4>' +
                (stops.length ? '<table><thead><tr><th>Type</th><th>Time</th><th>Code / Message</th><th class="r">Duration</th><th></th></tr></thead><tbody>' + srows + '</tbody></table>'
                              : '<div class="dt-msg">No stops on this day</div>');
        }
        document.getElementById('imdGrid').addEventListener('click', function (e) {
            var c = e.target.closest ? e.target.closest('.mc') : null;
            if (c) openDt(c.getAttribute('data-id'));
        });
        document.getElementById('dtClose').addEventListener('click', closeDt);
        document.getElementById('dtBack').addEventListener('click', function (e) { if (e.target === this) closeDt(); });
        document.getElementById('dtDay').addEventListener('change', function () { loadDt(); loadNg(); if (dtTab === 'oee') loadOee(); else oeeKey = ''; });
        [].forEach.call(document.querySelectorAll('.dt-tabs button'), function (b) { b.addEventListener('click', function () { setDtTab(b.getAttribute('data-t')); }); });
        document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && dtMc) { e.stopImmediatePropagation(); closeDt(); } }, true);
        setInterval(function () { if (dtMc && document.getElementById('dtDay').value === prodDay()) loadDt(); }, 30000);
        setInterval(function () { if (dtMc && document.getElementById('dtDay').value === prodDay()) loadNg(); }, 300000);

        load();
        setInterval(load, REFRESH_MS);
    })();
</script>
</asp:Content>
