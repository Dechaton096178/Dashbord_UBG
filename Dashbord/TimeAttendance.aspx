<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="TimeAttendance.aspx.cs" Inherits="Dashbord.TimeAttendance" Title="Time Attendance" %>

<%-- =====================================================================
     Time Attendance (แผนก HR) : เวลาเข้า-ออกงานจากเครื่องสแกน
     Import ไฟล์ Excel จากเครื่องสแกน -> ระบบจับคู่ เข้า/ออก (กะดึกข้ามวันได้) -> สาย / OT / ไม่มีสแกน
     สคริปต์ : files/TimeAttendance.js · สไตล์ : files/Hardware.css + files/Hr.css
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<link rel="stylesheet" href="files/Hardware.css" />
<link rel="stylesheet" href="files/Hr.css" />
</asp:Content>

<asp:Content ID="cRight" ContentPlaceHolderID="HeaderRight" runat="server">
<%= UserBadge() %>
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="hw ta" id="hw">
    <div class="hw-bar">
        <h2><i>&#9200;</i>Time Attendance</h2>
        <div class="ta-tabs" id="tabs">
            <button type="button" data-tab="day" class="on">Daily</button>
            <button type="button" data-tab="sum">Summary</button>
            <button type="button" data-tab="plan">Shift plan</button>
            <button type="button" data-tab="imp" class="edit-only">Import</button>
            <button type="button" data-tab="set">Settings</button>
        </div>
        <span class="hw-sp"></span>
        <button type="button" class="hw-btn" id="btnHelp">How it works</button>
    </div>

    <div class="ta-help" id="help" style="display:none">
        <ol>
            <li><b>ดึงไฟล์จากเครื่องสแกน</b> (Excel แบบที่ใช้อยู่ : แผนก · รหัสพนักงาน · ชื่อ · วันที่ · บันทึกเวลา1-3) แล้วไปแท็บ <b>Import</b> เลือกไฟล์ → ตรวจ → กด Confirm · นำเข้าไฟล์ที่ช่วงวันซ้ำกันได้ ระบบไม่บันทึกซ้ำ</li>
            <li><b>จับคู่คน</b> : รหัสในเครื่องสแกน = เลขในรหัสพนักงาน (104 = U-0104, 8104 = U-8104) · รหัสที่ไม่มีในทะเบียนพนักงานจะขึ้นเป็น <span class="ta-st unk">Unknown ID</span></li>
            <li><b>จับคู่ เข้า-ออก</b> : สแกนแรก = เข้างาน · สแกนสุดท้ายภายใน 18 ชม. = ออกงาน (กะดึก 19:30 → 07:30 วันถัดไป นับเป็นวันเดียว) · ระบบเลือกกะที่เวลาเข้าใกล้ที่สุด (ตั้งเวลากะที่แท็บ <b>Settings</b>)</li>
            <li><b>กะของแต่ละคน</b> : ตั้งที่แท็บ <b>Shift plan</b> (เลือกคน → เลือกกะ → ตั้งแต่วันที่ → กด Change shift) · เปลี่ยนชั่วคราวได้ (ใส่วันสิ้นสุด แล้วกลับเป็นกะเดิมเอง) · คนที่ยังไม่มีแผน ระบบเดากะจากเวลาเข้างาน (<i>ตัวเอียง</i>)</li>
            <li><b>สาย</b> = เข้าหลังเวลาเริ่มกะ · <b>ออกก่อน</b> = ออกก่อนเวลาเลิกกะ · <b>OT</b> = เวลาหลังเลิกกะ (+ มาก่อนกะมาก ๆ) ปัดลงทีละ 30 นาที — เป็น OT จากเวลาสแกน ยังไม่ใช่ OT ที่อนุมัติ</li>
            <li><b>ใบลา / ใบขอ OT</b> : ถ้ามีใบลา (หน้า Leave Request) วันนั้นจะขึ้น <span class="ta-st leave">Leave</span> แทน "ไม่มีสแกน" · ใบขอ OT (หน้า Overtime) จะแสดง "req" ในช่อง OT · <b>OT payable</b> = เวลาที่ขอ OT และอนุมัติแล้ว ∩ เวลาที่สแกนจริง</li>
            <li><b>Not in scanner 30d</b> = เป็น Active ในทะเบียนพนักงาน แต่ไม่มีสแกนเลย 30 วัน (น่าจะลาออกแล้ว) → ไม่นับเป็นขาด · ไปปรับเป็น Resigned ที่ Employee Directory (ตัวกรอง "Not in scanner")</li>
            <li><b>ไม่มีสแกน</b> = วันทำงานที่ไม่พบการสแกนเลย (ขาด / ลา / ลืมสแกน) · <b>ไม่มีสแกนออก</b> = สแกนเข้าแล้วไม่สแกนออก → กดที่ชื่อคน เพื่อ <b>เพิ่มเวลาเอง</b> (ต้องใส่เหตุผล) หรือ <b>ยกเลิก</b> เวลาที่สแกนผิด</li>
        </ol>
    </div>

    <!-- ===== Daily ===== -->
    <section id="tab-day">
        <div class="ta-tool">
            <button type="button" class="hw-btn" id="dPrev">&#9664;</button>
            <input type="date" id="dDate" class="hw-btn" />
            <button type="button" class="hw-btn" id="dNext">&#9654;</button>
            <span class="ta-dow" id="dDow"></span>
            <input type="search" id="dQ" class="hw-search" placeholder="Search code / name…" autocomplete="off" />
            <select id="dDept" class="hw-btn"></select>
            <span class="hw-sp"></span>
            <a class="hw-btn" id="dCsv" href="#">Export</a>
        </div>
        <div class="hw-kpis" id="dKpis"></div>
        <div class="hw-chips" id="dChips"></div>
        <div class="hw-msg" id="dMsg"></div>
        <div class="hw-card"><div class="hw-table-wrap">
            <table class="hw-table">
                <thead><tr>
                    <th data-k="code">Code</th><th data-k="name">Name</th><th data-k="dept">Department</th><th data-k="shift">Shift</th>
                    <th data-k="in" class="c">In</th><th data-k="out" class="c">Out</th><th data-k="late" class="c">Late</th><th data-k="early" class="c">Early out</th>
                    <th data-k="work" class="c">Work</th><th data-k="ot" class="c">OT</th><th data-k="status">Status</th>
                </tr></thead>
                <tbody id="dBody"><tr><td colspan="11" class="hw-empty">Loading…</td></tr></tbody>
            </table>
        </div></div>
    </section>

    <!-- ===== Summary ===== -->
    <section id="tab-sum" style="display:none">
        <div class="ta-tool">
            <label class="ta-lbl">From<input type="date" id="sFrom" class="hw-btn" /></label>
            <label class="ta-lbl">To<input type="date" id="sTo" class="hw-btn" /></label>
            <button type="button" class="hw-btn" id="sThis">This month</button>
            <button type="button" class="hw-btn" id="sLast">Last month</button>
            <input type="search" id="sQ" class="hw-search" placeholder="Search code / name…" autocomplete="off" />
            <select id="sDept" class="hw-btn"></select>
            <button type="button" class="hw-btn" id="sUnseen" style="display:none"></button>
            <span class="hw-sp"></span>
            <a class="hw-btn" id="sCsv" href="#">Export</a>
        </div>
        <div class="hw-kpis" id="sKpis"></div>
        <div class="hw-msg" id="sMsg"></div>
        <div class="hw-card"><div class="hw-table-wrap">
            <table class="hw-table">
                <thead><tr>
                    <th data-k="code">Code</th><th data-k="name">Name</th><th data-k="dept">Department</th>
                    <th data-k="days" class="c">Days worked</th><th data-k="noScan" class="c">No scan</th><th data-k="lateCount" class="c">Late</th>
                    <th data-k="lateMin" class="c">Late (min)</th><th data-k="earlyCount" class="c">Early out</th><th data-k="noOut" class="c">No OUT</th>
                    <th data-k="night" class="c">Night</th><th data-k="leaveDays" class="c">Leave</th><th data-k="work" class="c">Work hrs</th><th data-k="ot" class="c">OT scan</th><th data-k="otPay" class="c">OT payable</th>
                </tr></thead>
                <tbody id="sBody"></tbody>
            </table>
        </div></div>
    </section>

    <!-- ===== Shift plan (เปลี่ยนกะ) ===== -->
    <section id="tab-plan" style="display:none">
        <div class="ta-tool">
            <label class="ta-lbl">As of<input type="date" id="kDate" class="hw-btn" /></label>
            <input type="search" id="kQ" class="hw-search" placeholder="Search code / name…" autocomplete="off" />
            <select id="kDept" class="hw-btn"></select>
            <select id="kGroup" class="hw-btn"></select>
            <span class="hw-sp"></span>
        </div>
        <div class="hw-chips" id="kChips"></div>
        <div class="ta-assign edit-only" id="kAssign">
            <b id="kSel">0 selected</b>
            <button type="button" class="hw-btn" id="kAll">Select all shown</button>
            <button type="button" class="hw-btn" id="kNone">Clear</button>
            <span class="ta-arrow">→</span>
            <label class="ta-lbl">Shift<select id="kShift" class="hw-btn"></select></label>
            <label class="ta-lbl">From<input type="date" id="kFrom" class="hw-btn" /></label>
            <label class="ta-lbl" title="Leave blank = permanent change. Set a date = temporary, goes back to the previous shift after this date.">Until<input type="date" id="kTo" class="hw-btn" /></label>
            <input id="kNote" class="hw-btn" maxlength="200" placeholder="Note (optional)" />
            <button type="button" class="hw-btn pri" id="kGo">Change shift</button>
        </div>
        <div class="hw-msg" id="kMsg"></div>
        <div class="hw-card"><div class="hw-table-wrap">
            <table class="hw-table">
                <thead><tr>
                    <th class="c edit-only"><input type="checkbox" id="kChkAll" title="Select all shown" /></th>
                    <th data-k="code">Code</th><th data-k="name">Name</th><th data-k="dept">Department</th><th data-k="group">Group</th>
                    <th data-k="shiftName">Shift</th><th data-k="from">Since</th><th data-k="to">Until</th><th data-k="next">Next change</th><th></th>
                </tr></thead>
                <tbody id="kBody"></tbody>
            </table>
        </div></div>
    </section>

    <!-- ===== Import ===== -->
    <section id="tab-imp" style="display:none">
        <div class="hw-card ta-pad">
            <div class="imp-drop">
                <input type="file" id="iFile" accept=".xlsx,.csv" />
                <small>ไฟล์รายงานจากเครื่องสแกน (.xlsx) · อ่านทุกแผ่นงาน · เวลาที่มีอยู่แล้วจะไม่บันทึกซ้ำ · ไฟล์ .xls แบบเก่าให้ Save As เป็น .xlsx ก่อน</small>
            </div>
            <div class="imp-sum" id="iSum"></div>
            <div class="ta-imp-grid" id="iGrid" style="display:none">
                <div>
                    <h4>By date</h4>
                    <table class="hw-table"><thead><tr><th>Date</th><th class="c">People</th><th class="c">Scans</th><th class="c">New</th></tr></thead><tbody id="iDays"></tbody></table>
                </div>
                <div>
                    <h4>Scanner IDs not in Employee Directory <span id="iUnkN"></span></h4>
                    <div class="ta-unk" id="iUnk"></div>
                </div>
            </div>
            <div class="hw-mfoot">
                <span class="hw-msg" id="iMsg"></span>
                <span class="hw-sp"></span>
                <button type="button" class="hw-btn pri" id="iGo" disabled>Confirm import</button>
            </div>
        </div>
    </section>

    <!-- ===== Settings ===== -->
    <section id="tab-set" style="display:none">
        <div class="hw-card ta-pad">
            <h4 class="ta-h">Shifts</h4>
            <table class="hw-table ta-shifts">
                <thead><tr><th>Code</th><th>Name</th><th>Start</th><th>End</th><th>Break (min)</th><th title="พักหลังเลิกกะ ก่อนเริ่มนับ OT">Break before OT (min)</th><th>OT from</th><th></th></tr></thead>
                <tbody id="cShifts"></tbody>
            </table>
            <button type="button" class="hw-btn edit-only" id="cAddShift" style="margin-top:8px">+ Add shift</button>
            <small class="mut" style="margin-left:8px">กำหนดว่าใครทำกะไหนที่แท็บ Shift plan · ถ้าลบ / เปลี่ยนรหัสกะ คนที่ใช้รหัสนั้นจะกลับไปให้ระบบเดากะเอง</small>
            <div class="hw-form ta-set">
                <h4>Rules</h4>
                <label>Late grace (min)<input type="number" id="c_GraceMin" min="0" max="120" /><small>เข้าหลังเวลาเริ่มกะเกินกี่นาทีถึงนับสาย (0 = 1 นาทีก็สาย)</small></label>
                <label>OT round down (min)<input type="number" id="c_OtRoundMin" min="1" max="60" /><small>ปัดเศษ OT ลงทีละกี่นาที</small></label>
                <label>OT minimum (min)<input type="number" id="c_OtMinMin" min="0" max="240" /><small>OT ต่ำกว่านี้ไม่นับ</small></label>
                <label>Early-arrival OT from (min)<input type="number" id="c_EarlyOtMin" min="0" max="600" /><small>มาก่อนกะตั้งแต่กี่นาทีถึงนับ OT ก่อนเข้างาน (0 = ไม่นับ)</small></label>
                <label>Max hours IN → OUT<input type="number" id="c_SessionMaxHours" min="8" max="24" /><small>สแกนถัดไปภายในกี่ ชม. = สแกนออกของรอบเดียวกัน</small></label>
                <label>Double-scan window (min)<input type="number" id="c_DupMin" min="0" max="30" /><small>สแกนซ้ำภายในกี่นาทีนับครั้งเดียว</small></label>
                <label>Work days<span class="ta-days" id="cDays"></span><small>ไม่มาสแกนในวันทำงาน = ไม่มีสแกน</small></label>
                <label class="full">Company holidays (one date per line, yyyy-mm-dd)<textarea id="c_Holidays" rows="4" placeholder="2026-12-05&#10;2026-12-31"></textarea></label>
            </div>
            <div class="hw-mfoot">
                <span class="hw-msg" id="cMsg"></span>
                <span class="hw-sp"></span>
                <button type="button" class="hw-btn pri edit-only" id="cSave">Save settings</button>
            </div>
        </div>
    </section>

    <!-- ===== ประวัติแผนกะ 1 คน ===== -->
    <div class="hw-back" id="hBack">
        <div class="hw-modal">
            <h3 id="hTitle">Shift history</h3>
            <div class="hw-table-wrap"><table class="hw-table">
                <thead><tr><th>Shift</th><th>From</th><th>Until</th><th>Note</th><th>By</th><th class="edit-only"></th></tr></thead>
                <tbody id="hBody"></tbody>
            </table></div>
            <div class="hw-mfoot"><span class="hw-msg" id="hMsg"></span><span class="hw-sp"></span><button type="button" class="hw-btn" id="hClose">Close</button></div>
        </div>
    </div>

    <!-- ===== รายละเอียดรายคน ===== -->
    <div class="hw-back" id="pBack">
        <div class="hw-modal wide">
            <h3 id="pTitle">Employee</h3>
            <div class="ta-tool">
                <label class="ta-lbl">From<input type="date" id="pFrom" class="hw-btn" /></label>
                <label class="ta-lbl">To<input type="date" id="pTo" class="hw-btn" /></label>
                <span class="hw-sp"></span>
                <span class="hw-msg" id="pMsg"></span>
            </div>
            <div class="ta-person">
                <div>
                    <h4>Work days</h4>
                    <div class="hw-table-wrap ta-pwrap"><table class="hw-table">
                        <thead><tr><th>Date</th><th>Shift</th><th class="c">In</th><th class="c">Out</th><th class="c">Late</th><th class="c">Early</th><th class="c">Work</th><th class="c">OT</th><th>Status</th></tr></thead>
                        <tbody id="pSess"></tbody>
                    </table></div>
                    <div class="ta-noscan" id="pNo"></div>
                </div>
                <div>
                    <h4>All scans</h4>
                    <div class="ta-punches" id="pPunch"></div>
                    <div class="ta-add edit-only">
                        <h4>Add time manually</h4>
                        <input type="datetime-local" id="aAt" class="hw-btn" />
                        <input id="aNote" class="hw-btn" maxlength="200" placeholder="Reason (e.g. forgot to scan out)" />
                        <button type="button" class="hw-btn pri" id="aGo">Add</button>
                    </div>
                </div>
            </div>
            <div class="hw-mfoot"><span class="hw-sp"></span><button type="button" class="hw-btn" id="pClose">Close</button></div>
        </div>
    </div>
</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script src="files/TimeAttendance.js?v=<%= JsVer %>"></script>
</asp:Content>
