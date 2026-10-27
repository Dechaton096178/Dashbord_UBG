<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="EmailList.aspx.cs" Inherits="Dashbord.EmailList" Title="Email List" %>

<%-- =====================================================================
     Email List (แผนก IT) : รายชื่ออีเมลบริษัท · เพิ่ม / แก้ไข / ลบ (รหัสแก้ไข EDIT_PIN ใน EmailList.aspx.cs)
     ไม่เก็บรหัสผ่านในระบบ · สไตล์ใช้ร่วมกับหน้า Hardware (files/Hardware.css)
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<link rel="stylesheet" href="files/Hardware.css" />
<style>
    .em-mail { font-family:ui-monospace,Consolas,monospace; font-weight:700; color:#1e293b; }
    .em-mail a { color:inherit; text-decoration:none; border-bottom:1px dashed #94a3b8; }
    .em-cancel td { color:#94a3b8 !important; text-decoration:line-through; text-decoration-color:#cbd5e1; }
    .em-cancel td:last-child, .em-cancel td .st { text-decoration:none; }
    .st.act { color:#047857; } .st.act i { background:#10b981; }
    .st.can { color:#b91c1c; } .st.can i { background:#ef4444; }
    .warn-dom { display:inline-block; margin-left:6px; padding:1px 7px; border-radius:99px; font-size:10.5px; font-weight:800; background:#fef3c7; color:#92400e; }
    .hw-form select { font:inherit; font-size:14px; padding:8px 10px; border:1px solid #cbd5e1; border-radius:9px; outline:none; background:#fff; }
</style>
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="hw" id="hw">
    <div class="hw-bar">
        <h2><i>&#9993;</i>Email List</h2>
        <input type="search" id="q" class="hw-search" placeholder="Search email / name / position…" autocomplete="off" />
        <span class="hw-sp"></span>
        <button type="button" class="hw-btn" id="btnCopy" title="Copy all emails shown (separated by ; ) for Outlook">Copy emails</button>
        <button type="button" class="hw-btn" id="btnEdit" title="Edit mode (PIN)">Edit</button>
        <button type="button" class="hw-btn pri edit-only" id="btnNew">+ New</button>
        <a class="hw-btn" href="EmailList.aspx?format=csv">Export</a>
    </div>

    <div class="hw-kpis" id="kpis"></div>
    <div class="hw-chips" id="chips"></div>
    <div class="hw-msg" id="msg"></div>

    <div class="hw-card">
        <div class="hw-table-wrap">
            <table class="hw-table">
                <thead><tr>
                    <th data-k="item_no" class="c">No.</th>
                    <th data-k="email">Email</th>
                    <th data-k="mail_type">Type</th>
                    <th data-k="position">Position / Dept.</th>
                    <th data-k="name_th">Name (TH)</th>
                    <th data-k="name_en">Name (EN)</th>
                    <th data-k="emp_code">Code</th>
                    <th data-k="status">Status</th>
                    <th data-k="remark">Remark</th>
                    <th class="edit-only"></th>
                </tr></thead>
                <tbody id="body"><tr><td colspan="10" class="hw-empty">Loading…</td></tr></tbody>
            </table>
        </div>
    </div>

    <div class="hw-back" id="formBack">
        <div class="hw-modal">
            <h3 id="formTitle">Edit</h3>
            <div class="hw-form">
                <label>No.<input id="f_item_no" type="number" min="0" /></label>
                <label>Type<input id="f_mail_type" maxlength="30" list="dlType" placeholder="Microsoft 365 / Gmail" /></label>
                <label class="full">Email<input id="f_email" maxlength="120" placeholder="name@universalbasegolfball.com" /></label>
                <label>Position / Dept.<input id="f_position" maxlength="80" list="dlPos" /></label>
                <label>Code<input id="f_emp_code" maxlength="30" /></label>
                <label>Name (TH)<input id="f_name_th" maxlength="80" /></label>
                <label>Name (EN)<input id="f_name_en" maxlength="80" /></label>
                <label>Status<select id="f_status"><option>Active</option><option>Cancelled</option></select></label>
                <label class="full">Remark<textarea id="f_remark" maxlength="300" placeholder="Do not put passwords here"></textarea></label>
            </div>
            <datalist id="dlType"><option value="Microsoft 365"></option><option value="Gmail"></option></datalist><datalist id="dlPos"></datalist>
            <div class="hw-mfoot">
                <button type="button" class="hw-btn red" id="fDelete">Delete</button>
                <span class="hw-sp"></span>
                <span class="hw-msg" id="fMsg"></span>
                <button type="button" class="hw-btn" id="fCancel">Cancel</button>
                <button type="button" class="hw-btn pri" id="fSave">Save</button>
            </div>
        </div>
    </div>
</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script>
// @ts-nocheck
(function () {
    var API = 'EmailList.aspx', DOMAIN = 'universalbasegolfball.com';
    var $ = function (id) { return document.getElementById(id); };
    var root = $('hw');
    var S = { rows: [], q: '', type: '', status: 'Active', sort: 'item_no', desc: false, pin: '', edit: 0 };
    var FIELDS = ['item_no', 'email', 'mail_type', 'position', 'name_th', 'name_en', 'emp_code', 'remark', 'status'];

    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function msg(t, err) { var m = $('msg'); m.textContent = t || ''; m.className = 'hw-msg' + (err ? ' err' : ''); }
    function post(fmt, body) {
        body = body || {}; body.pin = S.pin;
        return fetch(API + '?format=' + fmt, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
            .then(function (r) { return r.json(); }).then(function (d) { if (!d.ok) throw new Error(d.error || 'error'); return d; });
    }
    function load() {
        return fetch(API + '?format=list', { cache: 'no-store' }).then(function (r) { return r.json(); })
            .then(function (d) { if (!d.ok) throw new Error(d.error); S.rows = d.rows; render(); })
            .catch(function (e) { msg('Load failed: ' + e.message, true); });
    }
    // โดเมนสะกดผิด (เช่น uuniversal...) -> แสดงป้ายเตือน
    function badDomain(e) { var m = /@(.+)$/.exec(e || ''); if (!m) return false; var d = m[1].toLowerCase(); return d !== DOMAIN && d.indexOf('universal') >= 0 && d.indexOf('onmicrosoft') < 0; }

    function filtered() {
        var q = S.q.toLowerCase();
        return S.rows.filter(function (r) {
            if (S.type && (r.mail_type || '(none)') !== S.type) return false;
            if (S.status && (r.status || 'Active') !== S.status) return false;
            return !q || FIELDS.some(function (f) { return String(r[f] || '').toLowerCase().indexOf(q) >= 0; });
        }).sort(function (a, b) {
            var k = S.sort, x = a[k], y = b[k], dir = S.desc ? -1 : 1;
            if (k === 'item_no') { x = x === '' ? 1e9 : +x; y = y === '' ? 1e9 : +y; } else { x = String(x || '').toLowerCase(); y = String(y || '').toLowerCase(); }
            return x < y ? -dir : x > y ? dir : 0;
        });
    }
    function render() {
        var act = S.rows.filter(function (r) { return (r.status || 'Active') === 'Active'; });
        var types = {}; S.rows.forEach(function (r) { var t = r.mail_type || '(none)'; types[t] = (types[t] || 0) + 1; });
        var noMail = act.filter(function (r) { return !r.email; }).length;
        $('kpis').innerHTML = '<div class="hw-kpi acc"><span>Active accounts</span><b>' + act.length + '</b><small>' + S.rows.length + ' total</small></div>' +
            Object.keys(types).sort().map(function (t) { return '<div class="hw-kpi"><span>' + esc(t) + '</span><b>' + types[t] + '</b></div>'; }).join('') +
            '<div class="hw-kpi bad"><span>Cancelled</span><b>' + (S.rows.length - act.length) + '</b></div>' +
            (noMail ? '<div class="hw-kpi"><span>No email yet</span><b>' + noMail + '</b><small>position only</small></div>' : '');
        var ch = '<span class="hw-chip' + (!S.type ? ' on' : '') + '" data-type="">All types</span>';
        Object.keys(types).sort().forEach(function (t) { ch += '<span class="hw-chip' + (S.type === t ? ' on' : '') + '" data-type="' + esc(t) + '">' + esc(t) + '<em>' + types[t] + '</em></span>'; });
        ch += '<span class="hw-chip sep">|</span>' + ['Active', 'Cancelled', ''].map(function (s) { return '<span class="hw-chip' + (S.status === s ? ' on' : '') + '" data-status="' + s + '">' + (s || 'All status') + '</span>'; }).join('');
        $('chips').innerHTML = ch;
        document.querySelectorAll('.hw-table th[data-k]').forEach(function (th) {
            th.classList.toggle('sorted', th.getAttribute('data-k') === S.sort); th.classList.toggle('desc', th.getAttribute('data-k') === S.sort && S.desc);
        });
        var list = filtered();
        $('body').innerHTML = list.map(function (r) {
            var can = (r.status || 'Active') !== 'Active';
            return '<tr' + (can ? ' class="em-cancel"' : '') + '><td class="c">' + esc(r.item_no) + '</td>' +
                '<td class="em-mail">' + (r.email ? '<a href="#" class="cp" title="Click to copy">' + esc(r.email) + '</a>' + (badDomain(r.email) ? '<span class="warn-dom" title="Domain looks misspelled">check domain</span>' : '') : '<span class="mut">–</span>') + '</td>' +
                '<td>' + (r.mail_type ? '<span class="type ' + (r.mail_type === 'Gmail' ? 't3' : 't4') + '">' + esc(r.mail_type) + '</span>' : '') + '</td>' +
                '<td><b>' + esc(r.position) + '</b></td><td>' + esc(r.name_th) + '</td><td>' + esc(r.name_en) + '</td><td>' + esc(r.emp_code) + '</td>' +
                '<td><span class="st ' + (can ? 'can' : 'act') + '"><i></i>' + esc(r.status || 'Active') + '</span></td>' +
                '<td class="rm">' + esc(r.remark) + '</td>' +
                '<td class="edit-only"><button type="button" class="rowbtn" data-edit="' + r.id + '">Edit</button></td></tr>';
        }).join('') || '<tr><td colspan="10" class="hw-empty">No match</td></tr>';
        msg((S.q || S.type || S.status) ? 'Showing ' + list.length + ' of ' + S.rows.length : '');
    }

    // ---------- Edit (PIN) ----------
    function askPin() {
        if (S.pin) return Promise.resolve(true);
        var p = prompt('Edit PIN'); if (!p) return Promise.resolve(false);
        S.pin = p;
        return post('checkpin').then(function () { return true; }).catch(function (e) { S.pin = ''; alert(e.message); return false; });
    }
    $('btnEdit').onclick = function () {
        var b = this;
        if (root.classList.contains('editing')) { root.classList.remove('editing'); b.classList.remove('on'); b.textContent = 'Edit'; return; }
        askPin().then(function (ok) { if (ok) { root.classList.add('editing'); b.classList.add('on'); b.textContent = 'Editing ✓'; render(); } });
    };
    function openForm(r) {
        S.edit = r ? r.id : 0;
        $('formTitle').textContent = r ? 'Edit · ' + (r.email || r.position) : 'New email';
        var next = 0; S.rows.forEach(function (x) { if (+x.item_no > next) next = +x.item_no; });
        FIELDS.forEach(function (f) { $('f_' + f).value = r ? (r[f] || '') : ''; });
        if (!r) { $('f_item_no').value = next + 1; $('f_mail_type').value = 'Microsoft 365'; $('f_status').value = 'Active'; }
        else if (!r.status) $('f_status').value = 'Active';
        var pos = {}; S.rows.forEach(function (x) { if (x.position) pos[x.position] = 1; });
        $('dlPos').innerHTML = Object.keys(pos).sort().map(function (v) { return '<option value="' + esc(v) + '">'; }).join('');
        $('fDelete').style.visibility = r ? 'visible' : 'hidden'; $('fMsg').textContent = '';
        $('formBack').classList.add('show'); setTimeout(function () { $('f_email').focus(); }, 50);
    }
    function closeForm() { $('formBack').classList.remove('show'); }
    $('btnNew').onclick = function () { askPin().then(function (ok) { if (ok) openForm(null); }); };
    $('fCancel').onclick = closeForm;
    $('fSave').onclick = function () {
        var b = { id: S.edit }; FIELDS.forEach(function (f) { b[f] = $('f_' + f).value.trim(); });
        if (b.email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(b.email)) { $('fMsg').textContent = 'Email format is not valid'; return; }
        if (b.email && S.rows.some(function (x) { return x.id !== S.edit && (x.email || '').toLowerCase() === b.email.toLowerCase(); }) && !confirm(b.email + ' already exists. Save anyway?')) return;
        $('fMsg').textContent = 'Saving…';
        post('save', b).then(function () { closeForm(); return load(); }).then(function () { msg('Saved ✓'); }).catch(function (e) { $('fMsg').textContent = e.message; });
    };
    $('fDelete').onclick = function () {
        var r = S.rows.filter(function (x) { return x.id === S.edit; })[0];
        if (!r || !confirm('Delete "' + (r.email || r.position) + '"?\n(Tip: set Status = Cancelled to keep history instead)')) return;
        post('delete', { id: r.id }).then(function () { closeForm(); return load(); }).then(function () { msg('Deleted'); }).catch(function (e) { $('fMsg').textContent = e.message; });
    };

    // ---------- events ----------
    $('q').addEventListener('input', function () { S.q = this.value.trim(); render(); });
    $('chips').addEventListener('click', function (e) {
        var c = e.target.closest('.hw-chip'); if (!c || c.classList.contains('sep')) return;
        if (c.hasAttribute('data-type')) S.type = c.getAttribute('data-type');
        if (c.hasAttribute('data-status')) S.status = c.getAttribute('data-status');
        render();
    });
    document.querySelector('.hw-table thead').addEventListener('click', function (e) {
        var th = e.target.closest('th[data-k]'); if (!th) return;
        var k = th.getAttribute('data-k'); if (S.sort === k) S.desc = !S.desc; else { S.sort = k; S.desc = false; } render();
    });
    function copy(t, okMsg) { (navigator.clipboard ? navigator.clipboard.writeText(t) : Promise.reject()).then(function () { msg(okMsg); }, function () { window.prompt('Copy:', t); }); }
    $('body').addEventListener('click', function (e) {
        var cp = e.target.closest('a.cp'); if (cp) { e.preventDefault(); copy(cp.textContent, 'Copied ' + cp.textContent); return; }
        var ed = e.target.closest('[data-edit]'); if (ed) { var id = +ed.getAttribute('data-edit'); openForm(S.rows.filter(function (x) { return x.id === id; })[0]); }
    });
    $('btnCopy').onclick = function () {
        var list = filtered().map(function (r) { return r.email; }).filter(Boolean);
        if (!list.length) { msg('No email to copy', true); return; }
        copy(list.join('; '), 'Copied ' + list.length + ' emails (paste into Outlook To / Bcc)');
    };
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeForm(); });
    load();
})();
</script>
</asp:Content>
