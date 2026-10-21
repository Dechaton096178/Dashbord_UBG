<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="MasterSample.aspx.cs" Inherits="Dashbord.MasterSample" Title="Master Sample" %>

<%-- =====================================================================
     Master Sample : ยิงบาร์โค้ด → แสดง Master Sample Sheet (ข้อมูล + รูป 9 ช่อง)
     - เพิ่ม / แก้ไข / ลบ / อัปโหลดรูป ได้จากหน้านี้ (รหัสแก้ไข EDIT_PIN ใน MasterSample.aspx.cs)
     - ลิงก์ตรง : MasterSample.aspx?q=197193442479 · พิมพ์ใบ : ปุ่ม Print (A4)
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<%-- สไตล์ทั้งหมดอยู่ใน files/MasterSample.css (แก้ที่ไฟล์นั้น) --%>
<link rel="stylesheet" href="files/MasterSample.css?v=<%= MasterSampleVer %>" />
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="ms" id="ms">
    <div class="ms-bar">
        <h2><i>&#9638;</i>Master Sample5555555555</h2>
        <div class="ms-scan">
            <label class="fld f1" for="scan"><span class="fl"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2M7 8v8M10 8v8M13 8v8M16 8v8"/></svg>&#9312; Unit barcode <em>/ no. / name</em></span>
                <input type="text" id="scan" placeholder="Scan here…" autocomplete="off" autofocus /></label>
            <label class="fld f2" for="scan2"><span class="fl">&#9313; Case barcode</span>
                <input type="text" id="scan2" placeholder="Scan here…" autocomplete="off" /></label>
            <button type="button" id="go">Search</button>
        </div>
        <button type="button" class="ms-btn on" id="cont" title="After each scan the box is ready for the next scan">Continuous</button>
        <span class="ms-sp"></span>
        <button type="button" class="ms-btn" id="btnList" title="All items">List</button>
        <button type="button" class="ms-btn" id="btnNew">+ New</button>
        <button type="button" class="ms-btn" id="btnEdit" title="Edit mode (PIN)">Edit</button>
        <button type="button" class="ms-btn" id="btnImport">Import</button>
        <button type="button" class="ms-btn" id="btnLabel" title="Print barcode label">Label</button>
        <button type="button" class="ms-btn" id="btnFit" title="Fill = photo fills the box (may crop edges) · Fit = whole photo">Fill</button>
        <button type="button" class="ms-btn" id="btnPrint" title="Print Master Sample Sheet (A4)">Sheet</button>
        <button type="button" class="ms-btn" id="btnTv" title="TV mode">TV</button>
        <button type="button" class="ms-btn" id="btnFull">Full screen</button>
        <button type="button" class="ms-btn" id="btnTvExit">Exit TV</button>
    </div>
    <div class="ms-msg" id="msg"></div>
    <div id="view">
        <div class="ms-empty"><div class="ic"><svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2M7 8v8M10 8v8M13 8v8M16 8v8"/></svg></div>
        <b>Scan a barcode</b>Scan or type a barcode, product number or name — the Master Sample Sheet appears here.</div>
    </div>
    <div class="sheet" id="sheet"></div>

    <!-- เพิ่ม / แก้ไข -->
    <div class="ms-back" id="formBack">
        <div class="ms-modal">
            <h3 id="formTitle">Edit</h3>
            <div class="ms-form">
                <label class="full">Product Name *<input id="f_product_name" maxlength="120" /></label>
                <label>BarCode 1 <small style="font-weight:600;color:#94a3b8">(Unit / UPC)</small><input id="f_barcode" maxlength="40" /></label>
                <label>BarCode 2 <small style="font-weight:600;color:#94a3b8">(Case / GTIN-14)</small><input id="f_barcode2" maxlength="40" /></label>
                <label>Product Number<input id="f_product_number" maxlength="40" /></label>
                <label>Supplier<input id="f_supplier" maxlength="40" list="dlSupplier" /></label>
                <label>Sample Location<input id="f_sample_location" maxlength="60" list="dlLocation" /></label>
                <label>SQE / SI<input id="f_sqe" maxlength="40" list="dlSqe" /></label>
                <label>Supplier Approver<input id="f_supplier_approver" maxlength="60" list="dlAppr" /></label>
                <label>Prepared<input id="f_prepared" type="date" /></label>
                <label>Short Name<input id="f_short_name" maxlength="80" /></label>
                <label class="full">Comment<textarea id="f_comment" maxlength="500"></textarea></label>
            </div>
            <datalist id="dlSupplier"></datalist><datalist id="dlLocation"></datalist><datalist id="dlSqe"></datalist><datalist id="dlAppr"></datalist>
            <div class="ms-mfoot">
                <button type="button" class="ms-btn red" id="fDelete">Delete</button>
                <span class="ms-sp"></span>
                <span class="ms-msg" id="fMsg"></span>
                <button type="button" class="ms-btn" id="fCancel">Cancel</button>
                <button type="button" class="ms-btn pri" id="fSave">Save</button>
            </div>
        </div>
    </div>

    <!-- รายการทั้งหมด -->
    <div class="ms-back" id="listBack">
        <div class="ms-modal wide">
            <div style="display:flex;gap:8px;align-items:center">
                <h3 style="margin:0">All items <span class="ms-msg" id="listCount"></span></h3>
                <span class="ms-sp"></span>
                <input class="ms-filter" id="listFilter" placeholder="Filter…" style="width:260px" />
                <button type="button" class="ms-btn" id="listCsv">CSV</button>
                <button type="button" class="ms-btn" id="listClose">Close</button>
            </div>
            <div class="ms-list-wrap">
                <table class="ms-list">
                    <thead><tr><th>Product Name</th><th>BarCode 1</th><th>BarCode 2</th><th>Product #</th><th>Supplier</th><th>SQE/SI</th><th>Prepared</th><th>Short Name</th><th>Photos</th></tr></thead>
                    <tbody id="listBody"></tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- พิมพ์บาร์โค้ด -->
    <div class="ms-back" id="lblBack">
        <div class="ms-modal">
            <h3>Print barcode label</h3>
            <div class="lbl-opts">
                <label>Code<select id="lblCode"></select></label>
                <label>Label size<select id="lblSize">
                    <option value="50x30">50 × 30 mm (sticker)</option>
                    <option value="60x40">60 × 40 mm (sticker)</option>
                    <option value="100x50">100 × 50 mm (sticker)</option>
                    <option value="a4">A4 sheet · 3 × 8 (70 × 37 mm)</option>
                </select></label>
                <label>Copies<input id="lblCopies" type="number" min="1" max="200" value="1" style="width:90px" /></label>
                <label><span>&nbsp;</span><span style="display:flex;gap:6px;align-items:center;font-weight:700"><input type="checkbox" id="lblName" checked /> Show name</span></label>
            </div>
            <div class="lbl-prev" id="lblPrev"></div>
            <div class="lbl-type" id="lblType"></div>
            <div class="ms-mfoot">
                <span class="ms-sp"></span>
                <button type="button" class="ms-btn" id="lblCancel">Close</button>
                <button type="button" class="ms-btn pri" id="lblGo">Print</button>
            </div>
        </div>
    </div>

    <!-- นำเข้า Excel / CSV -->
    <div class="ms-back" id="impBack">
        <div class="ms-modal wide">
            <h3>Import from Excel / CSV</h3>
            <div class="imp-drop">
                <a class="ms-btn" href="files/MasterSample_Template.xlsx" download style="text-decoration:none;display:inline-block;margin-bottom:10px">&#11015; Download Excel template (with photo columns)</a><br />
                <input type="file" id="impFile" accept=".xlsx,.csv" /><br />
                <small>Columns: Product name · Product Number · Supplier · BarCode 1 · BarCode 2 · SQE/SI · Prepared · Supplier Approver · Sample Location · ShortName · Comment<br />
                Photo columns: 1st Logo · 2nd Logo · Side Mark 1 · Side Mark 2 · Sleeve Front · Sleeve Barcode Side · Box Lid · Box Base · Box Barcode — put each picture inside its cell (Insert › Pictures › Place in Cell)<br />
                Same BarCode 1 (or BarCode 2) + same supplier = update · otherwise = new item. Nothing is saved until you press Import.</small>
                <div class="prog" id="impProg" style="margin-top:10px;display:none"><i style="width:0"></i></div>
            </div>
            <div class="imp-sum" id="impSum"></div>
            <div class="ms-list-wrap" style="max-height:48vh">
                <table class="ms-list"><thead><tr><th>Row</th><th>Action</th><th>Product Name</th><th>BarCode 1</th><th>BarCode 2</th><th>Product #</th><th>Supplier</th><th>Photos</th><th>Note</th></tr></thead><tbody id="impBody"></tbody></table>
            </div>
            <div class="ms-mfoot">
                <span class="ms-msg" id="impMsg"></span>
                <span class="ms-sp"></span>
                <button type="button" class="ms-btn" id="impClose">Close</button>
                <button type="button" class="ms-btn pri" id="impGo" disabled>Import</button>
            </div>
        </div>
    </div>
    <div id="labelPrint"></div>

    <div class="ms-zoom" id="zoom"><img id="zoomImg" alt="" /><span id="zoomCap"></span></div>
    <input type="file" id="file" accept="image/*" style="display:none" />
</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<%-- โค้ดทั้งหมดอยู่ใน files/MasterSample.js (แก้ที่ไฟล์นั้น) --%>
<script src="files/MasterSample.js?v=<%= MasterSampleVer %>"></script>
</asp:Content>
