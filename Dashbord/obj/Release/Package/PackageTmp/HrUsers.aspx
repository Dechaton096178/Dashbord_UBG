<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="HrUsers.aspx.cs" Inherits="Dashbord.HrUsers" Title="HR Users" %>

<%-- =====================================================================
     HR Users (เฉพาะ admin) : ผู้ใช้ระบบ HR · role admin / hr / viewer · ประวัติการใช้งาน
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<link rel="stylesheet" href="files/Hardware.css" />
<link rel="stylesheet" href="files/Hr.css" />
<style>
    .role { display:inline-block; padding:3px 10px; border-radius:999px; font-size:11px; font-weight:800; text-transform:uppercase; letter-spacing:.05em; }
    .role.admin { background:#ede9fe; color:#6d28d9; } .role.hr { background:#dbeafe; color:#1d4ed8; } .role.viewer { background:#f1f5f9; color:#475569; }
    .role.manager { background:#dcfce7; color:#166534; } .role.supervisor { background:#fef3c7; color:#92400e; }
    .dept-box { display:flex; flex-wrap:wrap; gap:6px 12px; max-height:150px; overflow:auto; padding:8px; border:1px solid #cbd5e1; border-radius:9px; font-weight:600; color:#334155; }
    .dept-box label { display:flex; flex-direction:row; align-items:center; gap:4px; font-size:13px; }
    .roles-help { margin-top:12px; font-size:12.5px; color:#64748b; line-height:1.7; }
    .hw-form .chk { flex-direction:row; align-items:center; gap:8px; font-size:14px; }
</style>
</asp:Content>

<asp:Content ID="cRight" ContentPlaceHolderID="HeaderRight" runat="server">
<%= UserBadge() %>
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="hw editing" id="hw">
    <div class="hw-bar">
        <h2><i>&#128274;</i>HR Users</h2>
        <span class="hw-sp"></span>
        <button type="button" class="hw-btn" id="btnLog">Activity log</button>
        <button type="button" class="hw-btn pri" id="btnNew">+ New user</button>
    </div>
    <div class="hw-msg" id="msg"></div>
    <div class="hw-card">
        <div class="hw-table-wrap">
            <table class="hw-table">
                <thead><tr><th>Username</th><th>Display name</th><th>Role</th><th>Departments</th><th>Status</th><th>Last login</th><th></th></tr></thead>
                <tbody id="body"><tr><td colspan="7" class="hw-empty">Loading…</td></tr></tbody>
            </table>
        </div>
    </div>
    <div class="roles-help">
        <b>admin</b> = ทุกอย่าง + จัดการผู้ใช้ · <b>hr</b> = เพิ่ม / แก้ / ลบ / นำเข้า ข้อมูลพนักงาน + เห็นข้อมูลส่วนตัว ·
        <b>manager</b> = ผู้อนุมัติ (ช่อง "ผู้อนุมัติ / 核准" ในใบลา + ใบ OT) · <b>leader</b> = หัวหน้างาน / หัวหน้าแผนก เขียนและเซ็นขั้นแรกของใบลา + ใบ OT ของแผนกที่ดูแล ·
        <b>viewer</b> = ดูรายชื่ออย่างเดียว (ไม่เห็นเบอร์โทร เลขบัตร วันเกิด ที่อยู่) · ตั้งรหัสผ่านให้ผู้ใช้แล้ว ผู้ใช้ต้องเปลี่ยนรหัสเองตอนเข้าครั้งแรก
    </div>

    <div class="hw-back" id="formBack">
        <div class="hw-modal">
            <h3 id="formTitle">User</h3>
            <div class="hw-form">
                <label>Username<input id="f_username" maxlength="40" autocomplete="off" autocapitalize="off" spellcheck="false" placeholder="a-z 0-9 . _ -" /></label>
                <label>Display name<input id="f_display_name" maxlength="80" /></label>
                <label>Role<select id="f_role"><option value="viewer">viewer</option><option value="supervisor">leader</option><option value="manager">manager</option><option value="hr">hr</option><option value="admin">admin</option></select></label>
                <label class="chk"><input type="checkbox" id="f_active" /> Active</label>
                <label class="full" id="deptWrap">Departments — เห็นใบลา / ใบ OT ได้เฉพาะแผนกที่ติ๊ก (admin / hr เห็นทุกแผนก)<span class="dept-box" id="f_depts"></span></label>
                <label class="full"><span id="pwLabel">Password</span><input id="f_password" type="text" maxlength="100" autocomplete="off" /></label>
            </div>
            <div class="hw-mfoot">
                <button type="button" class="hw-btn red" id="fDelete">Delete</button>
                <span class="hw-sp"></span>
                <span class="hw-msg" id="fMsg"></span>
                <button type="button" class="hw-btn" id="fCancel">Cancel</button>
                <button type="button" class="hw-btn pri" id="fSave">Save</button>
            </div>
        </div>
    </div>

    <div class="hw-back" id="logBack">
        <div class="hw-modal wide">
            <h3>Activity log (latest 300)</h3>
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
    var API = 'HrUsers.aspx';
    var $ = function (id) { return document.getElementById(id); };
    var S = { rows: [], me: {}, edit: 0, depts: [] };
    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function msg(t, err) { var m = $('msg'); m.textContent = t || ''; m.className = 'hw-msg' + (err ? ' err' : ''); }
    function api(r) { return r.json().then(function (d) { if (d.login) { location.href = 'HrLogin.aspx'; throw new Error('login'); } if (!d.ok) throw new Error(d.error || 'error'); return d; }); }
    function post(fmt, body) { return fetch(API + '?format=' + fmt, { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'text/plain; charset=utf-8', 'X-HR': '1' }, body: JSON.stringify(body) }).then(api); }
    function load() {
        return fetch(API + '?format=list', { cache: 'no-store', credentials: 'same-origin' }).then(api)
            .then(function (d) { S.rows = d.rows; S.me = d.me; S.depts = d.departments || []; render(); }).catch(function (e) { msg(e.message, true); });
    }
    function render() {
        $('body').innerHTML = S.rows.map(function (u) {
            return '<tr><td class="emp-code">' + esc(u.username) + (u.id === S.me.id ? ' <small>(you)</small>' : '') + '</td><td>' + esc(u.display_name) + '</td>' +
                '<td><span class="role ' + esc(u.role) + '">' + (u.role === 'supervisor' ? 'leader' : esc(u.role)) + '</span></td>' +
                '<td><small>' + (u.role === 'admin' || u.role === 'hr' ? 'All' : u.depts ? esc(u.depts) : '<b class="bad-t" style="color:#dc2626">None — sees nothing</b>') + '</small></td>' +
                '<td><span class="st ' + (u.active ? 'ok' : 'res') + '"><i></i>' + (u.active ? 'Active' : 'Disabled') + '</span>' + (u.must_change ? ' <small class="mut">· must change password</small>' : '') + '</td>' +
                '<td>' + esc(u.last_login || '–') + '</td><td><button type="button" class="rowbtn" data-edit="' + u.id + '">Edit</button></td></tr>';
        }).join('') || '<tr><td colspan="7" class="hw-empty">No users</td></tr>';
    }
    function openForm(u) {
        S.edit = u ? u.id : 0;
        $('formTitle').textContent = u ? 'Edit · ' + u.username : 'New user';
        $('f_username').value = u ? u.username : ''; $('f_display_name').value = u ? u.display_name : '';
        $('f_role').value = u ? u.role : 'hr'; $('f_active').checked = u ? u.active : true; $('f_password').value = '';
        $('pwLabel').textContent = u ? 'Reset password (leave blank = no change)' : 'Initial password (min 6)';
        var cur = ((u && u.depts) || '').split(',').map(function (x) { return x.trim(); });
        var all = S.depts.slice(); cur.forEach(function (x) { if (x && all.indexOf(x) < 0) all.push(x); });
        $('f_depts').innerHTML = all.map(function (dp) { return '<label><input type="checkbox" value="' + esc(dp) + '"' + (cur.indexOf(dp) >= 0 ? ' checked' : '') + '>' + esc(dp) + '</label>'; }).join('') || '<small>No departments in Employee Directory yet</small>';
        showDepts();
        var self = u && u.id === S.me.id; $('f_role').disabled = self; $('f_active').disabled = self;
        $('fDelete').style.visibility = u && !self ? 'visible' : 'hidden'; $('fMsg').textContent = '';
        $('formBack').classList.add('show'); setTimeout(function () { $(u ? 'f_display_name' : 'f_username').focus(); }, 50);
    }
    function showDepts() { var r = $('f_role').value; $('deptWrap').style.display = r === 'admin' || r === 'hr' ? 'none' : ''; }
    $('f_role').onchange = showDepts;
    $('btnNew').onclick = function () { openForm(null); };
    $('fCancel').onclick = function () { $('formBack').classList.remove('show'); };
    $('fSave').onclick = function () {
        var b = { id: S.edit, username: $('f_username').value.trim(), display_name: $('f_display_name').value.trim(), role: $('f_role').value, active: $('f_active').checked, password: $('f_password').value,
                  depts: [].filter.call(document.querySelectorAll('#f_depts input'), function (x) { return x.checked; }).map(function (x) { return x.value; }).join(', ') };
        if (!S.edit && b.password.length < 6) { $('fMsg').textContent = 'Password must be at least 6 characters'; return; }
        $('fMsg').textContent = 'Saving…';
        post('save', b).then(function () { $('formBack').classList.remove('show'); return load(); })
            .then(function () { msg('Saved ✓ ' + b.username + (b.password ? ' — tell the user their password; they must change it at first login' : '')); })
            .catch(function (e) { $('fMsg').textContent = e.message; });
    };
    $('fDelete').onclick = function () {
        var u = S.rows.filter(function (x) { return x.id === S.edit; })[0];
        if (!u || !confirm('Delete user "' + u.username + '"?\n(Tip: untick Active to disable instead)')) return;
        post('delete', { id: u.id }).then(function () { $('formBack').classList.remove('show'); return load(); }).catch(function (e) { $('fMsg').textContent = e.message; });
    };
    $('btnLog').onclick = function () {
        $('logBody').innerHTML = 'Loading…'; $('logBack').classList.add('show');
        fetch(API + '?format=log', { cache: 'no-store', credentials: 'same-origin' }).then(api).then(function (d) {
            $('logBody').innerHTML = d.rows.map(function (x) { return '<div><time>' + esc(x.at) + '</time><b>' + esc(x.user) + '</b><span>' + esc(x.action) + (x.ref ? ' · ' + esc(x.ref) : '') + (x.detail ? ' · ' + esc(x.detail) : '') + '</span></div>'; }).join('') || 'No activity';
        }).catch(function (e) { $('logBody').textContent = e.message; });
    };
    $('logClose').onclick = function () { $('logBack').classList.remove('show'); };
    $('body').addEventListener('click', function (e) {
        var ed = e.target.closest('[data-edit]'); if (ed) { var id = +ed.getAttribute('data-edit'); openForm(S.rows.filter(function (x) { return x.id === id; })[0]); }
    });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') { $('formBack').classList.remove('show'); $('logBack').classList.remove('show'); } });
    var form1 = document.getElementById('form1'); if (form1) form1.addEventListener('submit', function (e) { e.preventDefault(); });
    load();
})();
</script>
</asp:Content>
