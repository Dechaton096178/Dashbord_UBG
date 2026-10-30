<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="HrEmployee.aspx.cs" Inherits="Dashbord.HrEmployee" Title="Employee Directory" %>

<%-- =====================================================================
     Employee Directory (แผนก HR) : ทะเบียนพนักงาน · ต้องล็อกอินก่อน (HrLogin.aspx)
     admin / hr = เพิ่ม แก้ ลบ นำเข้า Excel · viewer = ดูอย่างเดียว (ไม่เห็นข้อมูลส่วนตัว)
     สไตล์ : files/Hardware.css + files/Hr.css
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
        <h2><i>&#128101;</i>Employee Directory</h2>
        <input type="search" id="q" class="hw-search" placeholder="Search code / name / nickname / position…" autocomplete="off" />
        <select id="fDept" class="hw-btn" title="Department"></select>
        <span class="hw-sp"></span>
        <span class="ro-badge" id="roBadge" style="display:none">View only</span>
        <button type="button" class="hw-btn red edit-only" id="btnResign" style="display:none"></button>
        <button type="button" class="hw-btn pri edit-only" id="btnNew">+ New</button>
        <button type="button" class="hw-btn edit-only" id="btnImport">Import Excel</button>
        <a class="hw-btn" href="HrEmployee.aspx?format=csv">Export</a>
    </div>

    <div class="hw-kpis" id="kpis"></div>
    <div class="hw-chips" id="chips"></div>
    <div class="hw-msg" id="msg"></div>

    <div class="hw-card">
        <div class="hw-table-wrap">
            <table class="hw-table">
                <thead><tr>
                    <th data-k="emp_code">Code</th>
                    <th data-k="name_th">Name</th>
                    <th data-k="emp_group">Group</th>
                    <th data-k="position">Position</th>
                    <th data-k="gender" class="c">Sex</th>
                    <th data-k="nationality">Nationality</th>
                    <th data-k="start_date">Start date</th>
                    <th data-k="start_date" data-tenure="1">Service</th>
                    <th data-k="locker_no" class="c">Locker</th>
                    <th data-k="passport_exp">Passport expiry</th>
                    <th data-k="visa_exp">Visa expiry</th>
                    <th data-k="wp_exp">Work permit expiry</th>
                    <th data-k="pink_exp">Pink card expiry</th>
                    <th data-k="status">Status</th>
                    <th></th>
                </tr></thead>
                <tbody id="body"><tr><td colspan="16" class="hw-empty">Loading…</td></tr></tbody>
            </table>
        </div>
    </div>

    <!-- ===== ฟอร์มเพิ่ม / แก้ไข ===== -->
    <div class="hw-back" id="formBack">
        <div class="hw-modal">
            <h3 id="formTitle">Employee</h3>
            <div class="hw-form" id="form">
                <h4>Basic</h4>
                <label><span class="req">Employee code</span><input id="f_emp_code" maxlength="20" placeholder="U-0001" /></label>
                <label>Group<input id="f_emp_group" maxlength="40" list="dlGroup" placeholder="UBG / DMM / นักศึกษา" /></label>
                <label>Prefix<input id="f_prefix" maxlength="20" list="dlPrefix" /></label>
                <label>Nickname<input id="f_nickname" maxlength="40" /></label>
                <label><span class="req">Name (TH)</span><input id="f_name_th" maxlength="120" placeholder="ชื่อ นามสกุล" /></label>
                <label>Name (EN)<input id="f_name_en" maxlength="120" placeholder="First Last" /></label>
                <label>Gender<select id="f_gender"><option value="">–</option><option value="M">Male · ชาย</option><option value="F">Female · หญิง</option></select></label>
                <label>Nationality<input id="f_nationality" maxlength="40" list="dlNat" /></label>

                <h4>Work</h4>
                <label>Department<input id="f_department" maxlength="60" list="dlDept" /></label>
                <label>Position<input id="f_position" maxlength="120" list="dlPos" /></label>
                <label>Type<select id="f_emp_type"><option value="">–</option><option>Regular</option><option>Temporary</option><option>Student</option><option>Contract</option></select></label>
                <label>Locker no.<input id="f_locker_no" maxlength="20" /></label>
                <label>Start date<input id="f_start_date" type="date" /></label>
                <label>Contract end<input id="f_contract_end" type="date" /></label>

                <h4 class="sens">Personal (HR only)</h4>
                <label class="sens">Phone<input id="f_phone" maxlength="40" /></label>
                <label class="sens">ID card / Passport<input id="f_id_card" maxlength="30" /></label>
                <label class="sens">Birth date<input id="f_birth_date" type="date" /></label>
                <label class="sens full">Address<textarea id="f_address" maxlength="300"></textarea></label>

                <h4>Passport / Visa / Work permit (foreign workers)</h4>
                <label class="sens">Passport no.<input id="f_passport_no" maxlength="30" /></label>
                <label>Passport expiry<input id="f_passport_exp" type="date" /></label>
                <label>Visa expiry<input id="f_visa_exp" type="date" /></label>
                <label>Permit type · ประเภทใบอนุญาต<input id="f_permit_type" maxlength="60" list="dlPermit" /></label>
                <label class="sens">Work permit no.<input id="f_wp_no" maxlength="30" /></label>
                <label>Work permit expiry<input id="f_wp_exp" type="date" /></label>
                <label class="sens">Pink card no. · บัตรชมพู<input id="f_pink_no" maxlength="30" /></label>
                <label>Pink card expiry<input id="f_pink_exp" type="date" /></label>
                <h4>Status</h4>
                <label>Status<select id="f_status"><option>Active</option><option>Resigned</option></select></label>
                <label>Resign date<input id="f_resign_date" type="date" /></label>
                <label class="full">Remark<textarea id="f_remark" maxlength="500"></textarea></label>
            </div>
            <datalist id="dlGroup"></datalist><datalist id="dlPermit"></datalist><datalist id="dlDept"></datalist><datalist id="dlPos"></datalist><datalist id="dlNat"></datalist>
            <datalist id="dlPrefix"><option value="นาย"></option><option value="นาง"></option><option value="นางสาว"></option><option value="Mr."></option><option value="Ms."></option></datalist>
            <div class="hw-mfoot">
                <button type="button" class="hw-btn red edit-only" id="fDelete">Delete</button>
                <button type="button" class="hw-btn" id="fLog">History</button>
                <span class="hw-sp"></span>
                <span class="hw-msg" id="fMsg"></span>
                <button type="button" class="hw-btn" id="fCancel">Close</button>
                <button type="button" class="hw-btn pri edit-only" id="fSave">Save</button>
            </div>
        </div>
    </div>

    <!-- ===== นำเข้า Excel ===== -->
    <div class="hw-back" id="impBack">
        <div class="hw-modal wide">
            <h3>Import employees from Excel</h3>
            <div class="imp-drop">
                <input type="file" id="impFile" accept=".xlsx,.csv" />
                <small>
                    รองรับไฟล์ <b>ทะเบียนลูกจ้าง</b> เดิม (อ่านทุกแผ่นงาน · ชื่อแผ่น = Group เช่น UBG / DMM / นักศึกษา) และไฟล์ที่ Export จากหน้านี้ ·
                    จับคู่ด้วย <b>รหัสพนักงาน</b> : มีแล้ว = อัปเดต · ยังไม่มี = เพิ่มใหม่ · คอลัมน์ที่ไม่มีในไฟล์จะไม่ถูกแก้ ·
                    <a href="HrEmployee.aspx?format=template">ดาวน์โหลดแบบฟอร์มเปล่า</a>
                </small>
            </div>
            <div class="imp-sheets" id="impSheets"></div>
            <div class="imp-sum" id="impSum"></div>
            <div class="hw-table-wrap imp-wrap" id="impWrap" style="display:none">
                <table class="hw-table">
                    <thead><tr><th>Row</th><th>Action</th><th>Code</th><th>Name</th><th>Group</th><th>Department</th><th>Position</th><th>Start</th><th>Note</th></tr></thead>
                    <tbody id="impBody"></tbody>
                </table>
            </div>
            <div class="hw-mfoot">
                <span class="hw-msg" id="impMsg"></span>
                <span class="hw-sp"></span>
                <button type="button" class="hw-btn" id="impClose">Close</button>
                <button type="button" class="hw-btn pri" id="impGo" disabled>Confirm import</button>
            </div>
        </div>
    </div>

    <!-- ===== ประวัติการแก้ไข ===== -->
    <div class="hw-back" id="logBack">
        <div class="hw-modal">
            <h3 id="logTitle">History</h3>
            <div class="log-list" id="logBody"></div>
            <div class="hw-mfoot"><span class="hw-sp"></span><button type="button" class="hw-btn" id="logClose">Close</button></div>
        </div>
    </div>
</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script>
// @ts-nocheck
(function () {
    var API = 'HrEmployee.aspx';
    var $ = function (id) { return document.getElementById(id); };
    var root = $('hw');
    var S = { rows: [], me: {}, procs: [], q: '', group: '', status: 'Active', dept: '', sort: 'emp_code', desc: false, edit: 0, imp: null, scanData: false, unseen: false };
    var UNSEEN = 30;
    // Active แต่ไม่มีสแกนเลย 30 วัน (และเริ่มงานเกิน 14 วัน) -> น่าจะลาออกแล้ว
    function unseen(r) {
        if (!S.scanData || (r.status || 'Active') !== 'Active') return false;
        var cut = new Date(TODAY); cut.setDate(cut.getDate() - UNSEEN); var c = cut.toISOString().slice(0, 10);
        var hire = new Date(TODAY); hire.setDate(hire.getDate() - 14);
        if (r.start_date && pd(r.start_date) > hire) return false;
        return !r.last_scan || r.last_scan < c;
    }
    var FIELDS = ['emp_code', 'emp_group', 'prefix', 'name_th', 'name_en', 'nickname', 'gender', 'nationality', 'department', 'position',
                  'emp_type', 'start_date', 'contract_end', 'locker_no', 'phone', 'id_card', 'birth_date', 'address', 'status', 'resign_date', 'remark',
                  'passport_no', 'passport_exp', 'visa_exp', 'permit_type', 'wp_no', 'wp_exp', 'pink_no', 'pink_exp'];
    var DOCS = [['passport_exp', 'Passport'], ['visa_exp', 'Visa'], ['wp_exp', 'Work permit'], ['pink_exp', 'Pink card']];
    var DOC_WARN = 90;
    // เอกสารที่หมดอายุเร็วที่สุด
    function docNext(r) {
        var best = null;
        DOCS.forEach(function (d) { if (r[d[0]] && (!best || r[d[0]] < best.date)) best = { date: r[d[0]], label: d[1] }; });
        return best;
    }
    function docAlert(r) { if ((r.status || 'Active') !== 'Active') return false; var n = docNext(r); if (!n) return false; var x = daysTo(n.date); return x !== null && x <= DOC_WARN; }
    var SEARCH = ['emp_code', 'name_th', 'name_en', 'nickname', 'position', 'department', 'emp_group', 'locker_no', 'phone', 'remark', 'passport_no', 'wp_no', 'pink_no'];
    var TODAY = new Date(); TODAY.setHours(0, 0, 0, 0);

    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function msg(t, err) { var m = $('msg'); m.textContent = t || ''; m.className = 'hw-msg' + (err ? ' err' : ''); }
    function api(r) {
        return r.json().then(function (d) {
            if (d.login) { location.href = 'HrLogin.aspx?ReturnUrl=' + encodeURIComponent(location.pathname + location.search); throw new Error('Session expired'); }
            if (!d.ok) throw new Error(d.error || 'error'); return d;
        });
    }
    function post(fmt, body) {
        return fetch(API + '?format=' + fmt, { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'text/plain; charset=utf-8', 'X-HR': '1' }, body: JSON.stringify(body || {}) }).then(api);
    }
    function load() {
        return fetch(API + '?format=list', { cache: 'no-store', credentials: 'same-origin' }).then(api)
            .then(function (d) { S.rows = d.rows; S.me = d.me; S.procs = d.processes || []; S.scanData = !!d.scanData; setup(); render(); })
            .catch(function (e) { msg('Load failed: ' + e.message, true); });
    }
    function setup() {
        root.classList.toggle('editing', !!S.me.canEdit);
        $('roBadge').style.display = S.me.canEdit ? 'none' : '';
        document.querySelectorAll('.sens').forEach(function (x) { x.style.display = S.me.sensitive ? '' : 'none'; });
    }

    // ---------- วันที่ / อายุงาน ----------
    function pd(s) { if (!s) return null; var p = s.split('-'); return new Date(+p[0], +p[1] - 1, +p[2]); }
    function fd(s) { if (!s) return ''; var p = s.split('-'); return p[2] + '/' + p[1] + '/' + p[0]; }
    function tenure(r) {
        var a = pd(r.start_date); if (!a) return '';
        var b = r.status === 'Resigned' && r.resign_date ? pd(r.resign_date) : TODAY;
        if (b < a) return '';
        var y = b.getFullYear() - a.getFullYear(), m = b.getMonth() - a.getMonth(), d = b.getDate() - a.getDate();
        if (d < 0) { m--; d += new Date(b.getFullYear(), b.getMonth(), 0).getDate(); }
        if (m < 0) { y--; m += 12; }
        return (y ? y + 'y ' : '') + (y || m ? m + 'm ' : '') + d + 'd';
    }
    function daysTo(s) { var d = pd(s); return d ? Math.round((d - TODAY) / 864e5) : null; }

    // ---------- กรอง / เรียง ----------
    function sortVal(r, k) { if (k === 'doc_next') { var n = docNext(r); return n ? n.date : ''; } return r[k]; }
    function filtered() {
        var q = S.q.toLowerCase();
        return S.rows.filter(function (r) {
            if (S.group && (r.emp_group || '(none)') !== S.group) return false;
            if (S.status && (r.status || 'Active') !== S.status) return false;
            if (S.dept && (r.department || '(none)') !== S.dept) return false;
            if (S.unseen && !unseen(r)) return false;
            if (S.docs && !docAlert(r)) return false;
            return !q || SEARCH.some(function (f) { return String(r[f] || '').toLowerCase().indexOf(q) >= 0; });
        }).sort(function (a, b) {
            var k = S.sort, x = String(sortVal(a, k) || ''), y = String(sortVal(b, k) || ''), dir = S.desc ? -1 : 1;
            if (k === 'locker_no') { x = +x || 1e9; y = +y || 1e9; } else { x = x.toLowerCase(); y = y.toLowerCase(); if (!x) x = '￿'; if (!y) y = '￿'; }
            return x < y ? -dir : x > y ? dir : 0;
        });
    }
    function count(list, f) { var o = {}; list.forEach(function (r) { var v = r[f] || '(none)'; o[v] = (o[v] || 0) + 1; }); return o; }

    function render() {
        var act = S.rows.filter(function (r) { return (r.status || 'Active') === 'Active'; });
        var groups = count(act, 'emp_group');
        $('kpis').innerHTML =
            '<div class="hw-kpi acc"><span>Active employees</span><b>' + act.length + '</b><small>' + (S.rows.length - act.length) + ' resigned</small></div>' +
            Object.keys(groups).sort().map(function (g) { return '<div class="hw-kpi"><span>' + esc(g) + '</span><b>' + groups[g] + '</b></div>'; }).join('') +
            (function () {
                var al = act.filter(docAlert), exp = al.filter(function (r) { return daysTo(docNext(r).date) < 0; }).length;
                return '<div class="hw-kpi' + (al.length ? ' bad' : '') + '"><span>Documents expire ≤ ' + DOC_WARN + ' days</span><b>' + al.length + '</b><small>' + (exp ? exp + ' already expired' : 'passport / visa / WP / pink card') + '</small></div>';
            })();

        var allG = count(S.rows, 'emp_group');
        var ch = '<span class="hw-chip' + (!S.group ? ' on' : '') + '" data-group="">All groups</span>';
        Object.keys(allG).sort().forEach(function (g) { ch += '<span class="hw-chip' + (S.group === g ? ' on' : '') + '" data-group="' + esc(g) + '">' + esc(g) + '<em>' + allG[g] + '</em></span>'; });
        ch += '<span class="hw-chip sep">|</span>' + ['Active', 'Resigned', ''].map(function (s) { return '<span class="hw-chip' + (S.status === s ? ' on' : '') + '" data-status="' + s + '">' + (s || 'All status') + '</span>'; }).join('');
        var nUn = S.rows.filter(unseen).length;
        if (nUn || S.unseen) ch += '<span class="hw-chip sep">|</span><span class="hw-chip' + (S.unseen ? ' on' : '') + '" data-unseen="1" title="Active in this list but no fingerprint scans in the last ' + UNSEEN + ' days">Not in scanner ' + UNSEEN + 'd<em>' + nUn + '</em></span>';
        var nDoc = S.rows.filter(docAlert).length;
        if (nDoc || S.docs) ch += '<span class="hw-chip sep">|</span><span class="hw-chip' + (S.docs ? ' on' : '') + '" data-docs="1" title="Passport / visa / work permit / pink card expires within ' + DOC_WARN + ' days (or expired)">Documents expiring<em>' + nDoc + '</em></span>';
        $('chips').innerHTML = ch;

        var depts = count(S.rows, 'department');
        $('fDept').innerHTML = '<option value="">All departments</option>' + Object.keys(depts).sort().map(function (d) {
            return '<option value="' + esc(d) + '"' + (S.dept === d ? ' selected' : '') + '>' + esc(d) + ' (' + depts[d] + ')</option>';
        }).join('');

        document.querySelectorAll('.hw-table th[data-k]').forEach(function (th) {
            var on = th.getAttribute('data-k') === S.sort && !th.hasAttribute('data-tenure');
            th.classList.toggle('sorted', on); th.classList.toggle('desc', on && S.desc);
        });
        var list = filtered();
        $('body').innerHTML = list.map(function (r) {
            var res = r.status === 'Resigned';
            function expTd(k) {   // หมดแล้ว / ใกล้หมด ≤ DOC_WARN (90) วัน = ตัวแดง
                if (!r[k]) return '<td></td>';
                return '<td class="' + (!res && daysTo(r[k]) <= DOC_WARN ? 'past-end' : '') + '">' + fd(r[k]) + '</td>';
            }
            return '<tr' + (res ? ' class="emp-resigned"' : '') + ' data-id="' + r.id + '">' +
                '<td class="emp-code">' + esc(r.emp_code) + '</td>' +
                '<td class="emp-name"><b>' + esc((r.prefix || '') + (r.name_th || r.name_en)) + (r.nickname ? ' <span class="nick">(' + esc(r.nickname) + ')</span>' : '') + '</b>' +
                    (r.name_th && r.name_en ? '<small>' + esc(r.name_en) + '</small>' : '') + '</td>' +
                '<td>' + (r.emp_group ? '<span class="type t4">' + esc(r.emp_group) + '</span>' : '') + (r.emp_type && r.emp_type !== 'Regular' ? ' <span class="type t2">' + esc(r.emp_type) + '</span>' : '') + '</td>' +
                '<td>' + esc(r.position) + '</td>' +
                '<td class="c">' + (r.gender === 'M' ? '<span class="g-m">M</span>' : r.gender === 'F' ? '<span class="g-f">F</span>' : '') + '</td>' +
                '<td>' + esc(r.nationality) + '</td><td>' + fd(r.start_date) + '</td><td>' + tenure(r) + '</td>' +
                '<td class="c">' + esc(r.locker_no) + '</td>' +
                expTd('passport_exp') + expTd('visa_exp') + expTd('wp_exp') + expTd('pink_exp') +
                '<td><span class="st ' + (res ? 'res' : 'ok') + '"><i></i>' + esc(r.status || 'Active') + '</span></td>' +
                '<td><button type="button" class="rowbtn" data-edit="' + r.id + '">' + (S.me.canEdit ? 'Edit' : 'View') + '</button></td></tr>';
        }).join('') || '<tr><td colspan="16" class="hw-empty">' + (S.rows.length ? 'No match' : 'No employees yet — use Import Excel or + New') + '</td></tr>';
        msg((S.q || S.group || S.dept || S.status || S.unseen) ? 'Showing ' + list.length + ' of ' + S.rows.length : '');
        var rb = $('btnResign'), cand = S.unseen ? list.filter(unseen) : [];
        rb.style.display = cand.length ? '' : 'none'; rb.textContent = 'Mark ' + cand.length + ' as Resigned';
    }

    // ---------- ฟอร์ม ----------
    function fillList(id, f, extra) {
        var o = {}; (extra || []).forEach(function (v) { o[v] = 1; }); S.rows.forEach(function (x) { if (x[f]) o[x[f]] = 1; });
        $(id).innerHTML = Object.keys(o).sort().map(function (v) { return '<option value="' + esc(v) + '">'; }).join('');
    }
    function openForm(r) {
        S.edit = r ? r.id : 0;
        $('formTitle').textContent = r ? r.emp_code + ' · ' + ((r.prefix || '') + (r.name_th || r.name_en)) : 'New employee';
        FIELDS.forEach(function (f) { $('f_' + f).value = r ? (r[f] || '') : ''; });
        if (!r) { $('f_status').value = 'Active'; $('f_emp_type').value = 'Regular'; $('f_start_date').value = TODAY.toISOString().slice(0, 10); }
        fillList('dlGroup', 'emp_group', ['UBG', 'DMM', 'นักศึกษา']); fillList('dlDept', 'department', S.procs);
        fillList('dlPos', 'position'); fillList('dlPermit', 'permit_type'); fillList('dlNat', 'nationality', ['ไทย', 'เมียนมา', 'กัมพูชา', 'ลาว']);
        var ro = !S.me.canEdit;
        document.querySelectorAll('#form input, #form select, #form textarea').forEach(function (x) { x.disabled = ro; });
        $('fDelete').style.visibility = r ? 'visible' : 'hidden'; $('fLog').style.display = r ? '' : 'none'; $('fMsg').textContent = '';
        $('formBack').classList.add('show'); if (!ro) setTimeout(function () { $(r ? 'f_name_th' : 'f_emp_code').focus(); }, 50);
    }
    function closeAll() { ['formBack', 'impBack', 'logBack'].forEach(function (id) { $(id).classList.remove('show'); }); }
    $('btnNew').onclick = function () { openForm(null); };
    $('btnResign').onclick = function () {
        var cand = filtered().filter(unseen);
        if (!cand.length) return;
        if (!confirm('Mark ' + cand.length + ' employees as Resigned?\n\nThey are Active here but have no fingerprint scans in the last ' + UNSEEN + ' days.\n' +
                     'Make sure scanner files from ALL scanners are imported in Time Attendance first.\n\nResign date = last scan date (blank if never scanned). You can change any of them back later.')) return;
        post('bulkresign', { items: cand.map(function (r) { return { id: r.id, date: r.last_scan || '' }; }) })
            .then(function (d) { S.unseen = false; return load().then(function () { msg('Marked ' + d.updated + ' as Resigned ✓'); }); })
            .catch(function (e) { msg(e.message, true); });
    };
    $('fCancel').onclick = function () { $('formBack').classList.remove('show'); };
    $('f_status').onchange = function () { if (this.value === 'Resigned' && !$('f_resign_date').value) $('f_resign_date').value = TODAY.toISOString().slice(0, 10); };
    $('fSave').onclick = function () {
        var b = { id: S.edit }; FIELDS.forEach(function (f) { b[f] = $('f_' + f).value.trim(); });
        if (!S.me.sensitive) ['phone', 'id_card', 'birth_date', 'address', 'passport_no', 'wp_no', 'pink_no'].forEach(function (f) { delete b[f]; });
        if (!b.emp_code) { $('fMsg').textContent = 'Employee code is required'; $('f_emp_code').focus(); return; }
        if (!b.name_th && !b.name_en) { $('fMsg').textContent = 'Name is required'; $('f_name_th').focus(); return; }
        $('fMsg').textContent = 'Saving…';
        post('save', b).then(function () { $('formBack').classList.remove('show'); return load(); })
            .then(function () { msg('Saved ✓ ' + b.emp_code); }).catch(function (e) { $('fMsg').textContent = e.message; });
    };
    $('fDelete').onclick = function () {
        var r = S.rows.filter(function (x) { return x.id === S.edit; })[0];
        if (!r || !confirm('Delete ' + r.emp_code + ' ' + (r.name_th || r.name_en) + ' permanently?\n\nTip: set Status = Resigned instead to keep the record.')) return;
        post('delete', { id: r.id }).then(function () { $('formBack').classList.remove('show'); return load(); })
            .then(function () { msg('Deleted ' + r.emp_code); }).catch(function (e) { $('fMsg').textContent = e.message; });
    };
    $('fLog').onclick = function () {
        var code = $('f_emp_code').value;
        $('logTitle').textContent = 'History · ' + code; $('logBody').innerHTML = 'Loading…'; $('logBack').classList.add('show');
        fetch(API + '?format=log&code=' + encodeURIComponent(code), { cache: 'no-store', credentials: 'same-origin' }).then(api).then(function (d) {
            $('logBody').innerHTML = d.rows.map(function (x) { return '<div><time>' + esc(x.at) + '</time><b>' + esc(x.user) + '</b><span>' + esc(x.action) + (x.detail ? ' · ' + esc(x.detail) : '') + '</span></div>'; }).join('') || 'No history';
        }).catch(function (e) { $('logBody').textContent = e.message; });
    };
    $('logClose').onclick = function () { $('logBack').classList.remove('show'); };

    // ---------- Import ----------
    $('btnImport').onclick = function () {
        S.imp = null; $('impFile').value = ''; $('impSum').innerHTML = ''; $('impSheets').innerHTML = ''; $('impBody').innerHTML = '';
        $('impWrap').style.display = 'none'; $('impGo').disabled = true; $('impMsg').textContent = ''; $('impBack').classList.add('show');
    };
    $('impClose').onclick = function () { $('impBack').classList.remove('show'); };
    function impRun(commit) {
        $('impMsg').textContent = commit ? 'Importing…' : 'Checking file…'; $('impGo').disabled = true;
        return post('import', { name: S.imp.name, data: S.imp.data, commit: commit, resignMissing: commit && $('impResign') && $('impResign').checked }).then(function (d) {
            $('impSheets').innerHTML = (d.sheets || []).map(function (s) { return '<span>' + esc(s.name) + ' · ' + s.rows + ' rows' + (s.note ? ' · ' + esc(s.note) : '') + '</span>'; }).join('');
            $('impSum').innerHTML = (commit ? '✓ Imported : ' : 'Preview : ') +
                '<span class="act add">add ' + d.add + '</span> <span class="act update">update ' + d.update + '</span> <span class="act same">no change ' + d.same + '</span>' +
                (d.skip ? ' <span class="act skip">' + (d.docMode ? 'skip ' : 'duplicate ') + d.skip + '</span>' : '') + (d.error ? ' <span class="act error">error ' + d.error + '</span>' : '') +
                (d.docMode ? '<div class="mut" style="font-weight:600;margin-top:6px">Passport / visa / work permit file — only document columns are updated (name, department, status are not touched).</div>' : '') +
                (commit && d.resigned ? '<div style="margin-top:6px">✓ Marked ' + d.resigned + ' employees as Resigned</div>' : '') +
                (!commit && d.missing && d.missing.length ? '<div class="imp-missing"><label><input type="checkbox" id="impResign" checked> Mark <b>' + d.missing.length + '</b> Active employees that are <b>not in this file</b> as Resigned ' +
                    '<small>(groups ' + esc(Object.keys(d.missing.reduce(function (o, m) { o[m.group] = 1; return o; }, {})).join(', ')) + ' · can be changed back one by one)</small></label>' +
                    '<div class="imp-missing-list">' + d.missing.map(function (m) { return '<span>' + esc(m.emp_code) + ' ' + esc(m.name) + '</span>'; }).join('') + '</div></div>' : '');
            var rows = d.rows.slice().sort(function (a, b) { var o = { error: 0, skip: 1, add: 2, update: 3, same: 4 }; return o[a.action] - o[b.action]; });
            $('impBody').innerHTML = rows.map(function (r) {
                return '<tr><td>' + esc(r.where) + '</td><td><span class="act ' + r.action + '">' + r.action + '</span></td><td class="emp-code">' + esc(r.emp_code) + '</td><td>' + esc(r.name) +
                    '</td><td>' + esc(r.group) + '</td><td>' + esc(r.department) + '</td><td>' + esc(r.position) + '</td><td>' + fd(r.start_date) + '</td><td class="rm">' + esc(r.note) + '</td></tr>';
            }).join('') || '<tr><td colspan="9" class="hw-empty">No employee rows found</td></tr>';
            $('impWrap').style.display = '';
            $('impGo').disabled = commit || !(d.add + d.update + (d.missing ? d.missing.length : 0));
            $('impMsg').textContent = commit ? 'Done' : (d.add + d.update || (d.missing && d.missing.length) ? 'Check the preview, then Confirm import' : 'Nothing to import');
            if (commit) return load();
        }).catch(function (e) { $('impMsg').textContent = e.message; });
    }
    $('impFile').onchange = function () {
        var f = this.files[0]; if (!f) return;
        if (f.size > 2 * 1024 * 1024) { $('impMsg').textContent = 'File too large (max 2 MB)'; return; }   // base64 ต้องไม่เกิน maxRequestLength 4 MB ของ IIS
        var rd = new FileReader();
        rd.onload = function () { S.imp = { name: f.name, data: rd.result }; impRun(false); };
        rd.readAsDataURL(f);
    };
    $('impGo').onclick = function () { if (S.imp) impRun(true); };

    // ---------- events ----------
    $('q').addEventListener('input', function () { S.q = this.value.trim(); render(); });
    $('fDept').onchange = function () { S.dept = this.value; render(); };
    $('chips').addEventListener('click', function (e) {
        var c = e.target.closest('.hw-chip'); if (!c || c.classList.contains('sep')) return;
        if (c.hasAttribute('data-group')) S.group = c.getAttribute('data-group');
        if (c.hasAttribute('data-status')) S.status = c.getAttribute('data-status');
        if (c.hasAttribute('data-docs')) { S.docs = !S.docs; if (S.docs) { S.status = 'Active'; S.sort = 'wp_exp'; S.desc = false; } }
        if (c.hasAttribute('data-unseen')) { S.unseen = !S.unseen; if (S.unseen) S.status = 'Active'; }
        render();
    });
    document.querySelector('.hw-table thead').addEventListener('click', function (e) {
        var th = e.target.closest('th[data-k]'); if (!th) return;
        var k = th.getAttribute('data-k'); if (S.sort === k) S.desc = !S.desc; else { S.sort = k; S.desc = false; } render();
    });
    $('body').addEventListener('click', function (e) {
        var tr = e.target.closest('tr[data-id]'); if (!tr) return;
        var id = +tr.getAttribute('data-id'); openForm(S.rows.filter(function (x) { return x.id === id; })[0]);
    });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeAll(); });
    var form1 = document.getElementById('form1'); if (form1) form1.addEventListener('submit', function (e) { e.preventDefault(); });   // กด Enter ในช่องกรอก ไม่ให้ postback
    load();
})();
</script>
</asp:Content>
