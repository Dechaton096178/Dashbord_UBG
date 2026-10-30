<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="OtRequest.aspx.cs" Inherits="Dashbord.OtRequest" Title="Overtime (OT)" %>

<%-- =====================================================================
     Overtime (แผนก HR) : ใบขออนุมัติทำงานล่วงเวลา ตามแบบ UBG-FM-HR-07-A
     ผู้ขอเปิดโอที -> หัวหน้าแผนก -> ฝ่ายบุคคล -> ผู้อนุมัติ · เทียบ OT ที่ขอ กับเวลาสแกนจริง
     สคริปต์ : files/OtRequest.js · สไตล์ : files/Hardware.css + files/Hr.css
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<link rel="stylesheet" href="files/Hardware.css" />
<link rel="stylesheet" href="files/Hr.css" />
</asp:Content>

<asp:Content ID="cRight" ContentPlaceHolderID="HeaderRight" runat="server">
<%= UserBadge() %>
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="hw" id="hw">
    <div class="hw-bar">
        <h2><i>&#9203;</i>Overtime (OT)</h2>
        <div class="ta-tabs" id="tabs">
            <button type="button" data-tab="req" class="on">OT requests</button>
            <button type="button" data-tab="cmp">OT vs scan</button>
        </div>
        <span class="hw-sp"></span>
        <button type="button" class="hw-btn pri req-only" id="btnNew">+ New OT request</button>
    </div>

    <!-- ===== Requests ===== -->
    <section id="tab-req">
        <div class="ta-tool">
            <label class="ta-lbl">From<input type="date" id="rFrom" class="hw-btn" /></label>
            <label class="ta-lbl">To<input type="date" id="rTo" class="hw-btn" /></label>
            <button type="button" class="hw-btn" id="rThis">This month</button>
            <input type="search" id="rQ" class="hw-search" placeholder="Search doc no / code / name…" autocomplete="off" />
            <select id="rDept" class="hw-btn"></select>
        </div>
        <div class="hw-chips" id="rChips"></div>
        <div class="hw-msg" id="rMsg"></div>
        <div class="hw-card"><div class="hw-table-wrap">
            <table class="hw-table">
                <thead><tr>
                    <th data-k="doc_no">No.</th><th data-k="ot_date">OT date</th><th data-k="department">Department</th><th data-k="people" class="c">People</th>
                    <th data-k="minutes" class="c">Hours</th><th data-k="created_by">Requested by</th><th>Signatures</th><th data-k="status">Status</th>
                </tr></thead>
                <tbody id="rBody"><tr><td colspan="8" class="hw-empty">Loading…</td></tr></tbody>
            </table>
        </div></div>
    </section>

    <!-- ===== OT vs scan ===== -->
    <section id="tab-cmp" style="display:none">
        <div class="ta-tool">
            <label class="ta-lbl">From<input type="date" id="cFrom" class="hw-btn" /></label>
            <label class="ta-lbl">To<input type="date" id="cTo" class="hw-btn" /></label>
            <input type="search" id="cQ" class="hw-search" placeholder="Search code / name…" autocomplete="off" />
            <select id="cDept" class="hw-btn"></select>
            <span class="hw-sp"></span>
            <button type="button" class="hw-btn" id="cCsv">Export</button>
        </div>
        <div class="hw-kpis" id="cKpis"></div>
        <div class="hw-chips" id="cChips"></div>
        <div class="hw-msg" id="cMsg"></div>
        <div class="hw-card"><div class="hw-table-wrap">
            <table class="hw-table">
                <thead><tr>
                    <th>Date</th><th>Doc</th><th>Employee</th><th>Department</th><th class="c">Requested</th><th class="c">Req. hrs</th>
                    <th class="c">Scan in</th><th class="c">Scan out</th><th class="c">Payable hrs</th><th>Check</th>
                </tr></thead>
                <tbody id="cBody"></tbody>
            </table>
        </div></div>
        <h4 class="ta-h" style="margin-top:18px">Worked OT by scan time but no OT request <span id="cNoN"></span></h4>
        <div class="hw-card"><div class="hw-table-wrap" style="max-height:40vh">
            <table class="hw-table">
                <thead><tr><th>Date</th><th>Employee</th><th>Department</th><th>Shift</th><th class="c">Scan in</th><th class="c">Scan out</th><th class="c">OT by scan</th></tr></thead>
                <tbody id="cNo"></tbody>
            </table>
        </div></div>
    </section>

    <!-- ===== เขียน / แก้ใบขอ OT ===== -->
    <div class="hw-back" id="fBack">
        <div class="hw-modal wide">
            <h3 id="fTitle">New OT request</h3>
            <div class="hw-form ot-head">
                <label><span class="req">Department · แผนกขอทำโอที</span><select id="f_dept"></select></label>
                <label><span class="req">OT date</span><input type="date" id="f_date" /></label>
                <label class="full">Note<input id="f_note" maxlength="300" placeholder="Reason / order no. (optional)" /></label>
            </div>
            <div class="ot-defaults">
                <b>Default time</b>
                <select id="f_shift" class="hw-btn" title="Fill the start time from a shift end"></select>
                <input type="time" id="f_from" class="hw-btn" /> → <input type="time" id="f_to" class="hw-btn" />
                <input id="f_job" class="hw-btn" maxlength="200" placeholder="Job detail · รายละเอียดของงาน" />
                <button type="button" class="hw-btn" id="fApply" title="Apply time + job to everyone below">Apply to all</button>
            </div>
            <div class="ot-add">
                <input id="f_add" class="hw-btn" list="dlEmp" placeholder="Add employee: type code or name…" autocomplete="off" />
                <button type="button" class="hw-btn" id="fAdd">+ Add</button>
                <button type="button" class="hw-btn" id="fAddDept">+ Whole department</button>
                <span class="hw-sp"></span><span class="mut" id="fCount"></span>
            </div>
            <datalist id="dlEmp"></datalist>
            <div class="hw-table-wrap ot-lines">
                <table class="hw-table">
                    <thead><tr><th>#</th><th>Code</th><th>Name</th><th>From</th><th>To</th><th class="c">Hrs</th><th>Job detail</th><th>Remark</th><th></th></tr></thead>
                    <tbody id="fLines"></tbody>
                </table>
            </div>
            <label class="chk hr-only ot-paper"><input type="checkbox" id="f_paper" /> Already signed on the paper form — record as approved (HR)</label>
            <div class="hw-mfoot">
                <span class="hw-msg" id="fMsg"></span><span class="hw-sp"></span>
                <button type="button" class="hw-btn" id="fCancel">Cancel</button>
                <button type="button" class="hw-btn pri" id="fSave">Submit</button>
            </div>
        </div>
    </div>

    <!-- ===== รายละเอียดใบขอ OT ===== -->
    <div class="hw-back" id="vBack">
        <div class="hw-modal wide">
            <h3 id="vTitle">OT</h3>
            <div id="vBody"></div>
            <div class="lv-signs" id="vSigns"></div>
            <div class="hw-mfoot">
                <button type="button" class="hw-btn red" id="vReject">Not approve</button>
                <button type="button" class="hw-btn" id="vCancelDoc">Cancel request</button>
                <button type="button" class="hw-btn" id="vEdit">Edit</button>
                <button type="button" class="hw-btn" id="vPrint">Print form</button>
                <span class="hw-sp"></span><span class="hw-msg" id="vMsg"></span>
                <button type="button" class="hw-btn" id="vClose">Close</button>
            </div>
        </div>
    </div>
</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script src="files/HrPrint.js?v=<%= JsVer %>"></script>
<script src="files/OtRequest.js?v=<%= JsVer %>"></script>
</asp:Content>
