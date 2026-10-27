<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Hardware.aspx.cs" Inherits="Dashbord.Hardware" Title="Hardware List" %>

<%-- =====================================================================
     Hardware List (แผนก IT) : รายการอุปกรณ์ Raspberry pi / IOT BOX / ... พร้อมสถานะ Online (Ping จาก Server)
     - เพิ่ม / แก้ไข / ลบ / นำเข้า Excel ได้จากหน้านี้ (รหัสแก้ไข EDIT_PIN ใน Hardware.aspx.cs)
     - สไตล์อยู่ใน files/Hardware.css · โค้ดอยู่ใน files/Hardware.js
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<link rel="stylesheet" href="files/Hardware.css?v=<%= HardwareVer %>" />
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="hw" id="hw">
    <div class="hw-bar">
        <h2><i>&#128421;</i>Hardware List</h2>
        <input type="search" id="q" class="hw-search" placeholder="Search name / IP / location / serial…" autocomplete="off" />
        <span class="hw-sp"></span>
        <button type="button" class="hw-btn" id="btnPing" title="Ping every IP from the server">&#8635; Check online</button>
        <button type="button" class="hw-btn" id="btnEdit" title="Edit mode (PIN)">Edit</button>
        <button type="button" class="hw-btn pri edit-only" id="btnNew">+ New</button>
        <button type="button" class="hw-btn" id="btnImport">Import Excel</button>
        <a class="hw-btn" id="btnCsv" href="Hardware.aspx?format=csv">Export</a>
    </div>

    <div class="hw-kpis" id="kpis"></div>
    <div class="hw-chips" id="chips"></div>
    <div class="hw-msg" id="msg"></div>

    <div class="hw-card">
        <div class="hw-table-wrap">
            <table class="hw-table">
                <thead><tr>
                    <th data-k="item_no" class="c">No.</th>
                    <th data-k="status" class="c">Status</th>
                    <th data-k="name">Name</th>
                    <th data-k="hw_type">Type</th>
                    <th data-k="ip">IP Address</th>
                    <th data-k="location">Location</th>
                    <th data-k="owner">Owner</th>
                    <th data-k="serial_no">Serial number</th>
                    <th data-k="start_date">Start date</th>
                    <th data-k="remark">Remark</th>
                    <th class="edit-only"></th>
                </tr></thead>
                <tbody id="body"><tr><td colspan="11" class="hw-empty">Loading…</td></tr></tbody>
            </table>
        </div>
    </div>

    <!-- เพิ่ม / แก้ไข -->
    <div class="hw-back" id="formBack">
        <div class="hw-modal">
            <h3 id="formTitle">Edit</h3>
            <div class="hw-form">
                <label>No.<input id="f_item_no" type="number" min="0" /></label>
                <label>Name *<input id="f_name" maxlength="80" /></label>
                <label>Type<input id="f_hw_type" maxlength="40" list="dlType" /></label>
                <label>IP Address<input id="f_ip" maxlength="45" placeholder="192.168.x.x" /></label>
                <label>Location<input id="f_location" maxlength="80" list="dlLoc" /></label>
                <label>Owner<input id="f_owner" maxlength="40" list="dlOwner" /></label>
                <label>Serial number<input id="f_serial_no" maxlength="60" /></label>
                <label>Start date<input id="f_start_date" type="date" /></label>
                <label class="full">Remark<textarea id="f_remark" maxlength="300"></textarea></label>
            </div>
            <datalist id="dlType"></datalist><datalist id="dlLoc"></datalist><datalist id="dlOwner"></datalist>
            <div class="hw-mfoot">
                <button type="button" class="hw-btn red" id="fDelete">Delete</button>
                <span class="hw-sp"></span>
                <span class="hw-msg" id="fMsg"></span>
                <button type="button" class="hw-btn" id="fCancel">Cancel</button>
                <button type="button" class="hw-btn pri" id="fSave">Save</button>
            </div>
        </div>
    </div>

    <!-- นำเข้า Excel -->
    <div class="hw-back" id="impBack">
        <div class="hw-modal wide">
            <h3>Import from Excel / CSV</h3>
            <div class="imp-drop">
                <a class="hw-btn" href="files/Hardware_Template.xlsx" download>&#11015; Download Excel template</a>
                <input type="file" id="impFile" accept=".xlsx,.csv" />
                <small>Columns: No · Name · Type · IP Address · Location · Owner · Serial number · Start date · Remark (header row must contain <b>Name</b>)<br />
                Same <b>IP Address</b> = update · no IP → same <b>Name + Location</b> = update · otherwise = new. Nothing is saved until you press Import.</small>
            </div>
            <div class="imp-sum" id="impSum"></div>
            <div class="hw-table-wrap imp-wrap">
                <table class="hw-table"><thead><tr><th>Row</th><th>Action</th><th>Name</th><th>Type</th><th>IP</th><th>Location</th><th>Owner</th><th>Note</th></tr></thead><tbody id="impBody"></tbody></table>
            </div>
            <div class="hw-mfoot">
                <span class="hw-msg" id="impMsg"></span>
                <span class="hw-sp"></span>
                <button type="button" class="hw-btn" id="impClose">Close</button>
                <button type="button" class="hw-btn pri" id="impGo" disabled>Import</button>
            </div>
        </div>
    </div>
</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script src="files/Hardware.js?v=<%= HardwareVer %>"></script>
</asp:Content>
