<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Maintenance.aspx.cs" Inherits="Dashbord.Maintenance" Title="Maintenance · แจ้งซ่อม" %>

<%-- =====================================================================
     ระบบแจ้งซ่อม (แผนก Maintenance) : แจ้งซ่อม → รับงาน (ช่าง PIN) → ซ่อมเสร็จ → ปิดงาน (ผู้แจ้งยืนยัน)
     แท็บ : แจ้งซ่อม · งานซ่อม · Dashboard (MTTR / MTBF / Top เครื่องเสีย · โหมดทีวี ?tab=dash&tv=1) · QR Code ติดเครื่อง (?mc=MC13)
     โค้ดหน้าตาอยู่ที่ files/Maintenance.css / files/Maintenance.js (VS ชอบเซฟ .aspx เก่าทับ) · ค่าตั้งค่าอยู่บนสุดของ Maintenance.aspx.cs
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<link rel="stylesheet" href="files/Maintenance.css?v=<%= JsVer %>" />
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="mt" id="mt">
    <div class="mt-bar">
        <h2><i>🔧</i>Maintenance <small>แจ้งซ่อม · Repair Request</small></h2>
        <div class="mt-tabs" id="tabs">
            <button type="button" data-tab="report">＋ แจ้งซ่อม</button>
            <button type="button" data-tab="jobs">งานซ่อม <b class="badge" id="bOpen"></b></button>
            <button type="button" data-tab="dash">Dashboard</button>
            <button type="button" data-tab="qr">QR Code</button>
        </div>
        <span class="sp"></span>
        <span class="mt-upd" id="upd"></span>
        <button type="button" class="mt-btn ghost" id="tvBtn" title="โหมดทีวี (Dashboard + งานค้าง) · Esc = ออก">📺 TV</button>
    </div>

    <!-- ===================== แจ้งซ่อม ===================== -->
    <section class="pane" id="p-report">
        <div class="card form" id="fCard">
            <div class="mc-head" id="mcHead" hidden></div>
            <div class="row">
                <label>เครื่องจักร / อุปกรณ์ <em>*</em></label>
                <select id="fMc"></select>
                <input type="text" id="fMcName" placeholder="พิมพ์ชื่ออุปกรณ์ เช่น ปั๊มลม, แอร์ห้อง QC" hidden />
            </div>
            <div class="row two">
                <div><label>ตำแหน่ง / Location</label><input type="text" id="fLoc" placeholder="เช่น Line 2, ห้อง Mixing" /></div>
                <div><label>ผู้แจ้ง <em>*</em></label><input type="text" id="fRep" placeholder="ชื่อ - แผนก" /></div>
            </div>
            <div class="row">
                <label>ประเภทปัญหา</label>
                <div class="chips" id="fCat"></div>
            </div>
            <div class="row">
                <label>อาการเสีย <em>*</em></label>
                <textarea id="fProb" rows="3" placeholder="เช่น ฉีดไม่ออก, มีเสียงดัง, Alarm E-12, น้ำมันรั่ว"></textarea>
            </div>
            <div class="row two">
                <div>
                    <label>ความเร่งด่วน</label>
                    <div class="seg" id="fPri"><button type="button" data-v="normal" class="on">ปกติ</button><button type="button" data-v="urgent">🚨 ด่วน</button></div>
                </div>
                <div>
                    <label>&nbsp;</label>
                    <label class="chk"><input type="checkbox" id="fStop" /> <span>⛔ เครื่องหยุด / ผลิตไม่ได้</span></label>
                </div>
            </div>
            <div class="row">
                <label>รูปถ่าย (ไม่เกิน 3 รูป)</label>
                <div class="photos" id="fPhotos"></div>
            </div>
            <div class="row act">
                <span class="msg" id="fMsg"></span>
                <button type="button" class="mt-btn big" id="fSend">ส่งแจ้งซ่อม</button>
            </div>
        </div>
        <div class="card done-card" id="fDone" hidden></div>
    </section>

    <!-- ===================== งานซ่อม ===================== -->
    <section class="pane" id="p-jobs" hidden>
        <div class="filters">
            <div class="chips st" id="jSt"></div>
            <span class="sp"></span>
            <input type="search" id="jQ" placeholder="ค้นหา เครื่อง / อาการ / เลขที่ / ชื่อ" />
            <input type="date" id="jFrom" title="ประวัติตั้งแต่" />
            <input type="date" id="jTo" title="ถึง" />
        </div>
        <div class="jobs" id="jobs"><div class="empty">กำลังโหลด…</div></div>
    </section>

    <!-- ===================== Dashboard ===================== -->
    <section class="pane" id="p-dash" hidden>
        <div class="filters">
            <div class="seg" id="dRange"><button type="button" data-d="7">7 วัน</button><button type="button" data-d="30" class="on">30 วัน</button><button type="button" data-d="m">เดือนนี้</button><button type="button" data-d="90">90 วัน</button></div>
            <select id="dProc"></select>
            <span class="sp"></span>
            <span class="note">MTTR = แจ้ง → ซ่อมเสร็จ · MTBF = เวลาเฉลี่ยระหว่างเสียแต่ละครั้ง (ชม.)</span>
        </div>
        <div class="kpis" id="kpis"></div>
        <div class="dgrid">
            <div class="card"><h3>งานค้างตอนนี้ <small id="openCnt"></small></h3><div id="openList" class="openlist"></div></div>
            <div class="card"><h3>แนวโน้มรายเดือน <small>จำนวนงาน (แท่ง) · MTTR (เส้น)</small></h3><div id="cMonth" class="chart"></div></div>
            <div class="card wide"><h3>Top เครื่องเสีย <small id="dRangeTxt"></small></h3><div id="tMc"></div></div>
            <div class="card"><h3>ประเภทปัญหา</h3><div id="cCat"></div></div>
            <div class="card"><h3>ช่างซ่อม <small>งานที่ซ่อมเสร็จ · เวลาซ่อมเฉลี่ย</small></h3><div id="tTech"></div></div>
        </div>
    </section>

    <!-- ===================== QR Code ===================== -->
    <section class="pane" id="p-qr" hidden>
        <div class="filters">
            <label class="chk"><input type="checkbox" id="qAll" /> <span>เลือกทั้งหมด</span></label>
            <select id="qProc"></select>
            <input type="text" id="qCustom" placeholder="เพิ่มอุปกรณ์อื่น เช่น ปั๊มลม 1 (กด Enter)" />
            <span class="sp"></span>
            <select id="qSize"><option value="3">A4 · 3 ต่อแถว (ใหญ่)</option><option value="4" selected>A4 · 4 ต่อแถว</option><option value="5">A4 · 5 ต่อแถว (เล็ก)</option></select>
            <button type="button" class="mt-btn" id="qPrint">🖨 พิมพ์ QR</button>
        </div>
        <p class="note">ติด QR ที่เครื่อง → ใช้มือถือสแกน (ต่อ WiFi โรงงาน) → เปิดฟอร์มแจ้งซ่อมของเครื่องนั้นทันที</p>
        <div class="qgrid" id="qList"></div>
    </section>

    <!-- รายละเอียดงาน -->
    <div class="modal" id="dlg" hidden><div class="mbox" id="dlgBox"></div></div>
    <div class="modal" id="imgDlg" hidden><img id="imgBig" alt="" /></div>
</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script type="application/json" id="procJson"><%= ProcessJson %></script>
<script src="files/qrcode.js?v=1"></script>
<script src="files/Maintenance.js?v=<%= JsVer %>"></script>
</asp:Content>
