<%@ Page Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="HrLogin.aspx.cs" Inherits="Dashbord.HrLogin" Title="HR Login" %>

<%-- =====================================================================
     HR Login : เข้าสู่ระบบก่อนใช้หน้า HR · เปลี่ยนรหัสผ่าน (ครั้งแรก / ?change=1)
     ===================================================================== --%>

<asp:Content ID="cHead" ContentPlaceHolderID="HeadContent" runat="server">
<link rel="stylesheet" href="files/Hardware.css" />
<link rel="stylesheet" href="files/Hr.css" />
</asp:Content>

<asp:Content ID="cMain" ContentPlaceHolderID="MainContent" runat="server">
<div class="hr-login">
    <!-- ===== Login ===== -->
    <div class="hr-card" id="cardLogin" style="display:none">
        <div class="ic"><svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M2 21v-1a6 6 0 0 1 6-6h2a6 6 0 0 1 6 6v1 M17 11a3 3 0 1 0 0-6 M22 21v-1a5 5 0 0 0-4-4.9"/></svg></div>
        <h2>HR System</h2>
        <p class="sub">เข้าสู่ระบบเพื่อใช้งานข้อมูลพนักงาน · Sign in to continue</p>
        <label>Username<input id="lUser" autocomplete="username" autocapitalize="off" spellcheck="false" /></label>
        <label>Password<span class="hr-pw"><input id="lPw" type="password" autocomplete="current-password" /><button type="button" data-eye="lPw">Show</button></span></label>
        <div class="err" id="lErr"></div>
        <button type="button" class="hw-btn pri go" id="lGo">Sign in</button>
        <div class="hint">ลืมรหัสผ่าน ติดต่อผู้ดูแลระบบ HR / IT</div>
    </div>

    <!-- ===== เปลี่ยนรหัสผ่าน ===== -->
    <div class="hr-card" id="cardChange" style="display:none">
        <div class="ic"><svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 11h14v10H5z M8 11V7a4 4 0 0 1 8 0v4"/></svg></div>
        <h2>Change password</h2>
        <p class="sub" id="cSub"></p>
        <label>Current password<span class="hr-pw"><input id="cOld" type="password" autocomplete="current-password" /><button type="button" data-eye="cOld">Show</button></span></label>
        <label>New password<span class="hr-pw"><input id="cNew" type="password" autocomplete="new-password" /><button type="button" data-eye="cNew">Show</button></span></label>
        <label>Confirm new password<input id="cNew2" type="password" autocomplete="new-password" /></label>
        <div class="err" id="cErr"></div>
        <button type="button" class="hw-btn pri go" id="cGo">Save new password</button>
        <div class="hint"><a href="HrLogin.aspx?logout=1">Logout</a></div>
    </div>
</div>
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="ScriptContent" runat="server">
<script>
// @ts-nocheck
(function () {
    var MODE = <%= JsStr(Mode) %>, NEXT = <%= JsStr(NextUrl) %>, WHO = <%= JsStr(WhoName) %>, DBERR = <%= JsStr(DbError) %>;
    var $ = function (id) { return document.getElementById(id); };
    function post(fmt, body) {
        return fetch('HrLogin.aspx?format=' + fmt, { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'text/plain; charset=utf-8', 'X-HR': '1' }, body: JSON.stringify(body) })
            .then(function (r) { return r.json(); }).then(function (d) { if (!d.ok) throw new Error(d.error || 'error'); return d; });
    }
    function show(mode) {
        $('cardLogin').style.display = mode === 'login' ? '' : 'none';
        $('cardChange').style.display = mode === 'change' ? '' : 'none';
        setTimeout(function () { $(mode === 'login' ? 'lUser' : 'cOld').focus(); }, 30);
    }

    function login() {
        var u = $('lUser').value.trim(), p = $('lPw').value;
        if (!u || !p) { $('lErr').textContent = 'กรุณาใส่ Username และ Password'; return; }
        $('lErr').textContent = ''; $('lGo').classList.add('busy'); $('lGo').textContent = 'Signing in…';
        post('login', { username: u, password: p }).then(function (d) {
            if (d.mustChange) {
                $('cSub').textContent = 'สวัสดี ' + d.name + ' · ต้องตั้งรหัสผ่านใหม่ก่อนใช้งาน (ครั้งแรก / ถูกรีเซ็ต)';
                $('cOld').value = p; show('change');
            } else location.href = NEXT;
        }).catch(function (e) { $('lErr').textContent = e.message; $('lPw').select(); })
          .then(function () { $('lGo').classList.remove('busy'); $('lGo').textContent = 'Sign in'; });
    }
    function change() {
        var o = $('cOld').value, n = $('cNew').value, n2 = $('cNew2').value;
        if (n.length < 6) { $('cErr').textContent = 'รหัสผ่านใหม่ต้องยาวอย่างน้อย 6 ตัวอักษร'; return; }
        if (n !== n2) { $('cErr').textContent = 'ยืนยันรหัสผ่านไม่ตรงกัน'; return; }
        $('cErr').textContent = ''; $('cGo').classList.add('busy');
        post('changepw', { old: o, 'new': n }).then(function () {
            $('cErr').className = 'err ok'; $('cErr').textContent = 'เปลี่ยนรหัสผ่านแล้ว ✓'; setTimeout(function () { location.href = NEXT; }, 600);
        }).catch(function (e) { $('cErr').className = 'err'; $('cErr').textContent = e.message; })
          .then(function () { $('cGo').classList.remove('busy'); });
    }

    $('lGo').onclick = login; $('cGo').onclick = change;
    ['lUser', 'lPw'].forEach(function (id) { $(id).addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); login(); } }); });
    ['cOld', 'cNew', 'cNew2'].forEach(function (id) { $(id).addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); change(); } }); });
    document.querySelectorAll('[data-eye]').forEach(function (b) {
        b.onclick = function () { var i = $(b.getAttribute('data-eye')); i.type = i.type === 'password' ? 'text' : 'password'; b.textContent = i.type === 'password' ? 'Show' : 'Hide'; };
    });
    var form1 = document.getElementById('form1'); if (form1) form1.addEventListener('submit', function (e) { e.preventDefault(); });

    if (MODE === 'change') $('cSub').textContent = (WHO ? WHO + ' · ' : '') + 'ตั้งรหัสผ่านใหม่อย่างน้อย 6 ตัวอักษร';
    if (DBERR) { $('lErr').textContent = DBERR; }
    show(MODE);
})();
</script>
</asp:Content>
