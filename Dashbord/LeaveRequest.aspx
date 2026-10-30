<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="LeaveRequest.aspx.cs" Inherits="Dashbord.LeaveRequest" Title="Leave Request" %>

<%-- =====================================================================
     Leave Request (แผนก HR) : ใบลาออนไลน์ ตามแบบ UBG-FM-HR-09-A
     เขียนใบลา -> หัวหน้างาน -> ผู้อนุมัติ -> ฝ่ายบุคคล · สิทธิ์วันลา · พิมพ์บัตรบันทึกการลา
     สคริปต์ : files/LeaveRequest.js · สไตล์ : files/Hardware.css + files/Hr.css
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
        <h2><i>&#127796;</i>Leave Request</h2>
        <div class="ta-tabs" id="tabs">
            <button type="button" data-tab="req" class="on">Requests</button>
            <button type="button" data-tab="bal">Leave balance</button>
            <button type="button" data-tab="set">Settings</button>
        </div>
        <span class="hw-sp"></span>
        <button type="button" class="hw-btn pri req-only" id="btnNew">+ New leave</button>
    </div>

    <!-- ===== Requests ===== -->
    <section id="tab-req">
        <div class="ta-tool">
            <label class="ta-lbl">From<input type="date" id="rFrom" class="hw-btn" /></label>
            <label class="ta-lbl">To<input type="date" id="rTo" class="hw-btn" /></label>
            <button type="button" class="hw-btn" id="rThis">This month</button>
            <input type="search" id="rQ" class="hw-search" placeholder="Search code / name / doc no…" autocomplete="off" />
            <select id="rDept" class="hw-btn"></select>
            <select id="rType" class="hw-btn"></select>
        </div>
        <div class="hw-chips" id="rChips"></div>
        <div class="hw-msg" id="rMsg"></div>
        <div class="hw-card"><div class="hw-table-wrap">
            <table class="hw-table">
                <thead><tr>
                    <th data-k="doc_no">No.</th><th data-k="emp_code">Employee</th><th data-k="dept">Department</th><th data-k="leave_type">Type</th>
                    <th data-k="date_from">Leave date</th><th data-k="days" class="c">Days</th><th data-k="reason">Reason</th>
                    <th>Signatures</th><th data-k="status">Status</th>
                </tr></thead>
                <tbody id="rBody"><tr><td colspan="9" class="hw-empty">Loading…</td></tr></tbody>
            </table>
        </div></div>
    </section>

    <!-- ===== Balance ===== -->
    <section id="tab-bal" style="display:none">
        <div class="ta-tool">
            <label class="ta-lbl">Year<select id="bYear" class="hw-btn"></select></label>
            <input type="search" id="bQ" class="hw-search" placeholder="Search code / name…" autocomplete="off" />
            <select id="bDept" class="hw-btn"></select>
            <span class="hw-sp"></span>
        </div>
        <div class="hw-msg" id="bMsg"></div>
        <div class="hw-card"><div class="hw-table-wrap">
            <table class="hw-table lv-bal">
                <thead><tr>
                    <th data-k="code">Code</th><th data-k="name">Name</th><th data-k="dept">Department</th><th data-k="start">Start date</th>
                    <th class="c" data-k="V">Vacation V<small>used / quota</small></th><th class="c" data-k="S">Sick S<small>used / quota</small></th>
                    <th class="c" data-k="P">Personal P<small>used / quota</small></th><th class="c" data-k="O">Other O<small>days</small></th>
                    <th class="c" data-k="A">Absence A<small>days</small></th><th class="c" data-k="L">Late L<small>times</small></th><th></th>
                </tr></thead>
                <tbody id="bBody"></tbody>
            </table>
        </div></div>
    </section>

    <!-- ===== Settings ===== -->
    <section id="tab-set" style="display:none">
        <div class="hw-card ta-pad">
            <div class="hw-form ta-set">
                <h4>Leave entitlement per year (default for everyone · change per person in Leave balance)</h4>
                <label>Vacation days (V)<input type="number" id="l_VacationDays" min="0" step="0.5" /><small>ลาพักร้อน วัน/ปี</small></label>
                <label>Vacation after (months of service)<input type="number" id="l_VacationAfterMonths" min="0" /><small>ทำงานครบกี่เดือนถึงได้พักร้อน</small></label>
                <label>Sick days (S)<input type="number" id="l_SickDays" min="0" step="0.5" /><small>ลาป่วย วัน/ปี</small></label>
                <label>Personal days (P)<input type="number" id="l_PersonalDays" min="0" step="0.5" /><small>ลากิจ วัน/ปี</small></label>
                <h4>Rules (from the leave form)</h4>
                <label>Advance notice for V / P (days)<input type="number" id="l_AdvanceDays" min="0" /><small>ลาพักร้อน / ลากิจ ต้องลาล่วงหน้า</small></label>
                <label>Sick leave needs medical certificate from (days)<input type="number" id="l_SickCertDays" min="0" /><small>1 = ทุกครั้ง (ตามใบลา)</small></label>
                <label>Hours per day<input type="number" id="l_HoursPerDay" min="1" max="24" step="0.5" /><small>ลาเป็นชั่วโมง : กี่ ชม. = 1 วัน</small></label>
            </div>
            <p class="mut" style="font-size:12.5px">Work days and company holidays come from Time Attendance → Settings (leave days count only work days).</p>
            <div class="hw-mfoot"><span class="hw-msg" id="lMsg"></span><span class="hw-sp"></span><button type="button" class="hw-btn pri hr-only" id="lSave">Save settings</button></div>
        </div>
    </section>

    <!-- ===== เขียนใบลา ===== -->
    <div class="hw-back" id="fBack">
        <div class="hw-modal">
            <h3 id="fTitle">New leave</h3>
            <div class="hw-form">
                <label class="full"><span class="req">Employee</span><input id="f_emp" list="dlEmp" placeholder="Type code or name…" autocomplete="off" /></label>
                <div class="full lv-empinfo" id="fEmpInfo"></div>
                <label><span class="req">Type</span><select id="f_type"></select></label>
                <label>Written date · วันที่เขียน<input type="date" id="f_written" /></label>
                <label class="full">Portion<span class="lv-portion" id="fPortion">
                    <label><input type="radio" name="portion" value="full" checked /> Full day(s)</label>
                    <label><input type="radio" name="portion" value="am" /> Morning ½</label>
                    <label><input type="radio" name="portion" value="pm" /> Afternoon ½</label>
                    <label><input type="radio" name="portion" value="hours" /> Hours</label>
                </span></label>
                <label><span class="req">From · วันที่ลา</span><input type="date" id="f_from" /></label>
                <label id="fToWrap">To<input type="date" id="f_to" /></label>
                <label id="fHoursWrap" style="display:none">Hours<input type="number" id="f_hours" min="0.5" max="24" step="0.5" /></label>
                <label class="full">Reason · เหตุผลที่ลา<textarea id="f_reason" maxlength="300"></textarea></label>
                <label>Substitute · ผู้ทำการแทน<input id="f_sub" list="dlEmp" placeholder="Code (optional)" autocomplete="off" /></label>
                <label id="fCertWrap" class="chk" style="flex-direction:row;align-items:center;gap:8px;display:none"><input type="checkbox" id="f_cert" /> Has medical certificate · มีใบรับรองแพทย์</label>
                <label class="full chk hr-only" style="flex-direction:row;align-items:center;gap:8px"><input type="checkbox" id="f_paper" /> Already signed on the paper form — record as approved (HR)</label>
            </div>
            <datalist id="dlEmp"></datalist>
            <div class="lv-calc" id="fCalc"></div>
            <div class="hw-mfoot">
                <span class="hw-msg" id="fMsg"></span><span class="hw-sp"></span>
                <button type="button" class="hw-btn" id="fCancel">Cancel</button>
                <button type="button" class="hw-btn pri" id="fSave">Submit</button>
            </div>
        </div>
    </div>

    <!-- ===== รายละเอียดใบลา ===== -->
    <div class="hw-back" id="vBack">
        <div class="hw-modal">
            <h3 id="vTitle">Leave</h3>
            <div id="vBody"></div>
            <div class="lv-signs" id="vSigns"></div>
            <div class="hw-mfoot">
                <button type="button" class="hw-btn red" id="vReject">Not approve</button>
                <button type="button" class="hw-btn" id="vCancelDoc">Cancel leave</button>
                <button type="button" class="hw-btn" id="vEdit">Edit</button>
                <button type="button" class="hw-btn" id="vPrint">Print</button>
                <span class="hw-sp"></span><span class="hw-msg" id="vMsg"></span>
                <button type="button" class="hw-btn" id="vClose">Close</button>
            </div>
        </div>
    </div>
</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script src="files/HrPrint.js?v=<%= JsVer %>"></script>
<script src="files/LeaveRequest.js?v=<%= JsVer %>"></script>
</asp:Content>
