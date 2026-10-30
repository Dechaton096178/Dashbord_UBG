// @ts-nocheck
// ===== Leave Request (LeaveRequest.aspx) : ใบลา UBG-FM-HR-09 =====
(function () {
    var API = 'LeaveRequest.aspx';
    var $ = function (id) { return document.getElementById(id); };
    var esc = HrPrint.esc;
    var S = {
        me: {}, cfg: null, types: {}, steps: [], stepNames: {}, emps: {}, empList: [], users: {}, today: '',
        req: { rows: [], q: '', dept: '', type: '', st: 'mine', sort: 'date_from', desc: true },
        bal: { rows: [], q: '', dept: '', sort: 'code', desc: false, year: 0 },
        edit: 0, view: null
    };
    var STATUS = { pending: ['work', 'Pending'], approved: ['ok', 'Approved'], rejected: ['nos', 'Not approved'], cancelled: ['off', 'Cancelled'] };
    var TCLS = { S: 't3', P: 't2', V: 't1', O: 't4', A: 'tA', L: 't5' };

    function msg(id, t, err) { var m = $(id); m.textContent = t || ''; m.className = 'hw-msg' + (err ? ' err' : ''); }
    function api(r) {
        return r.json().then(function (d) {
            if (d.login) { location.href = 'HrLogin.aspx?ReturnUrl=' + encodeURIComponent(location.pathname + location.search); throw new Error('Session expired'); }
            if (!d.ok) throw new Error(d.error || 'error'); return d;
        });
    }
    function get(q) { return fetch(API + '?' + q, { cache: 'no-store', credentials: 'same-origin' }).then(api); }
    function post(fmt, body) {
        return fetch(API + '?format=' + fmt, { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'text/plain; charset=utf-8', 'X-HR': '1' }, body: JSON.stringify(body || {}) }).then(api);
    }
    function pd(s) { var p = s.split('-'); return new Date(+p[0], +p[1] - 1, +p[2]); }
    function iso(d) { return d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2); }
    function fd(s) { if (!s) return ''; var p = s.slice(0, 10).split('-'); return p[2] + '/' + p[1] + '/' + p[0]; }
    function num(v) { v = +v || 0; return String(Math.round(v * 100) / 100); }
    function uname(u) { return S.users[u] || u; }
    function empName(code) { var e = S.emps[code]; return e ? e.name + (e.nick ? ' (' + e.nick + ')' : '') : code; }
    function typeBadge(t) { return '<span class="type ' + (TCLS[t] || '') + '" title="' + esc(S.types[t]) + '">' + t + ' · ' + esc((S.types[t] || '').split(' · ')[0]) + '</span>'; }
    function dates(r) {
        var s = r.date_from === r.date_to ? fd(r.date_from) : fd(r.date_from) + ' – ' + fd(r.date_to);
        if (r.portion === 'am') s += ' <small>morning</small>'; else if (r.portion === 'pm') s += ' <small>afternoon</small>'; else if (r.portion === 'hours') s += ' <small>' + num(r.hours) + ' h</small>';
        return s;
    }
    function sortRows(rows, k, desc) {
        var dir = desc ? -1 : 1;
        return rows.sort(function (a, b) { var x = a[k], y = b[k]; if (typeof x === 'number') { x = +x; y = +y; } else { x = String(x || '').toLowerCase(); y = String(y || '').toLowerCase(); } return x < y ? -dir : x > y ? dir : 0; });
    }
    function markSort(sec, k, desc) {
        document.querySelectorAll('#' + sec + ' th[data-k]').forEach(function (th) { var on = th.getAttribute('data-k') === k; th.classList.toggle('sorted', on); th.classList.toggle('desc', on && desc); });
    }
    function deptOptions(sel, cur) {
        var o = {}; S.empList.forEach(function (e) { if (e.dept) o[e.dept] = 1; });
        $(sel).innerHTML = '<option value="">All departments</option>' + Object.keys(o).sort().map(function (d) { return '<option' + (cur === d ? ' selected' : '') + '>' + esc(d) + '</option>'; }).join('');
    }
    function signDots(r) {
        return '<span class="lv-dots">' + S.steps.map(function (s) {
            var by = r[s + '_by'];
            return '<i class="' + (by ? 'on' : '') + (r.canSign && r.canSign.indexOf(s) >= 0 ? ' me' : '') + '" title="' + esc(S.stepNames[s]) + (by ? ' · ' + esc(uname(by)) + ' ' + esc(r[s + '_at']) : '') + '">' + (by ? '✓' : '') + '</i>';
        }).join('') + '</span>' + (r.paper ? ' <small class="mut">paper</small>' : '');
    }

    // ================= Tabs =================
    function showTab(t) {
        document.querySelectorAll('#tabs button').forEach(function (b) { b.classList.toggle('on', b.getAttribute('data-tab') === t); });
        ['req', 'bal', 'set'].forEach(function (x) { $('tab-' + x).style.display = x === t ? '' : 'none'; });
        if (t === 'bal' && !S.bal.loaded) loadBal();
        if (t === 'set') renderSettings();
    }
    $('tabs').onclick = function (e) { var b = e.target.closest('button[data-tab]'); if (b) showTab(b.getAttribute('data-tab')); };

    // ================= Requests =================
    function loadReq() {
        var a = $('rFrom').value, b = $('rTo').value;
        $('rBody').innerHTML = '<tr><td colspan="9" class="hw-empty">Loading…</td></tr>';
        return get('format=list&from=' + a + '&to=' + b).then(function (d) { S.req.rows = d.rows; renderReq(); })
            .catch(function (e) { msg('rMsg', e.message, true); });
    }
    function reqFilter(r, st) {
        if (st === 'mine') return r.canSign && r.canSign.length > 0;
        if (st === 'closed') return r.status === 'rejected' || r.status === 'cancelled';
        return !st || r.status === st;
    }
    function renderReq() {
        var R = S.req, all = R.rows;
        var chips = [['mine', 'Waiting for my signature'], ['pending', 'Pending'], ['approved', 'Approved'], ['closed', 'Not approved / cancelled'], ['', 'All']];
        $('rChips').innerHTML = chips.map(function (c) {
            var n = all.filter(function (r) { return reqFilter(r, c[0]); }).length;
            return '<span class="hw-chip' + (R.st === c[0] ? ' on' : '') + (c[0] === 'mine' && n ? ' lv-hot' : '') + '" data-st="' + c[0] + '">' + c[1] + '<em>' + n + '</em></span>';
        }).join('');
        markSort('tab-req', R.sort, R.desc);
        var q = R.q.toLowerCase();
        var list = sortRows(all.filter(function (r) {
            if (!reqFilter(r, R.st)) return false;
            if (R.dept && r.dept !== R.dept) return false;
            if (R.type && r.leave_type !== R.type) return false;
            return !q || [r.doc_no, r.emp_code, empName(r.emp_code), r.reason].some(function (v) { return String(v || '').toLowerCase().indexOf(q) >= 0; });
        }), R.sort, R.desc);
        $('rBody').innerHTML = list.map(function (r) {
            var st = STATUS[r.status] || ['', r.status];
            return '<tr data-id="' + r.id + '"><td class="emp-code">' + esc(r.doc_no) + '<small class="mut" style="display:block">' + fd(r.written_date) + '</small></td>' +
                '<td class="emp-name"><b>' + esc(empName(r.emp_code)) + '</b><small>' + esc(r.emp_code) + '</small></td><td>' + esc(r.dept) + '</td>' +
                '<td>' + typeBadge(r.leave_type) + '</td><td>' + dates(r) + '</td><td class="c"><b>' + num(r.days) + '</b></td>' +
                '<td class="rm">' + esc(r.reason) + (r.leave_type === 'S' ? (r.med_cert ? ' <span class="ta-tmp" style="background:#dcfce7;color:#166534">cert ✓</span>' : ' <span class="ta-mis">no cert</span>') : '') + '</td>' +
                '<td>' + signDots(r) + '</td><td><span class="ta-st ' + st[0] + '">' + st[1] + '</span></td></tr>';
        }).join('') || '<tr><td colspan="9" class="hw-empty">' + (R.st === 'mine' ? 'Nothing waiting for your signature 👍' : 'No leave in this range') + '</td></tr>';
        msg('rMsg', 'Showing ' + list.length + ' of ' + all.length + ' (leave dates ' + fd($('rFrom').value) + ' – ' + fd($('rTo').value) + ') · click a row to view / sign');
    }
    function thisMonth() { var t = pd(S.today); $('rFrom').value = iso(new Date(t.getFullYear(), t.getMonth(), 1)); $('rTo').value = iso(new Date(t.getFullYear(), t.getMonth() + 1, 0)); }
    $('rFrom').onchange = $('rTo').onchange = loadReq;
    $('rThis').onclick = function () { thisMonth(); loadReq(); };
    $('rQ').oninput = function () { S.req.q = this.value.trim(); renderReq(); };
    $('rDept').onchange = function () { S.req.dept = this.value; renderReq(); };
    $('rType').onchange = function () { S.req.type = this.value; renderReq(); };
    $('rChips').onclick = function (e) { var c = e.target.closest('[data-st]'); if (c) { S.req.st = c.getAttribute('data-st'); renderReq(); } };
    document.querySelector('#tab-req thead').onclick = function (e) {
        var th = e.target.closest('th[data-k]'); if (!th) return; var k = th.getAttribute('data-k');
        if (S.req.sort === k) S.req.desc = !S.req.desc; else { S.req.sort = k; S.req.desc = false; } renderReq();
    };
    $('rBody').onclick = function (e) { var tr = e.target.closest('tr[data-id]'); if (tr) openView(+tr.getAttribute('data-id')); };

    // ================= ดูใบลา / เซ็น =================
    function openView(id) {
        var r = S.req.rows.filter(function (x) { return x.id === id; })[0]; if (!r) return;
        S.view = r; var st = STATUS[r.status] || ['', r.status];
        $('vTitle').innerHTML = esc(r.doc_no) + ' · ' + typeBadge(r.leave_type) + ' <span class="ta-st ' + st[0] + '">' + st[1] + '</span>';
        var e = S.emps[r.emp_code] || {};
        $('vBody').innerHTML = '<div class="lv-grid">' +
            '<div><span>Employee</span><b>' + esc(r.emp_code) + ' · ' + esc(empName(r.emp_code)) + '</b><small>' + esc(e.dept || '') + (e.pos ? ' · ' + esc(e.pos) : '') + '</small></div>' +
            '<div><span>Leave date</span><b>' + dates(r) + '</b><small>' + num(r.days) + ' day(s)</small></div>' +
            '<div><span>Reason</span><b>' + (esc(r.reason) || '–') + '</b></div>' +
            '<div><span>Substitute</span><b>' + (r.substitute ? esc(r.substitute) + ' · ' + esc(empName(r.substitute)) : '–') + '</b></div>' +
            '<div><span>Written</span><b>' + fd(r.written_date) + '</b><small>by ' + esc(uname(r.created_by)) + ' · ' + esc(r.created_at) + '</small></div>' +
            (r.leave_type === 'S' ? '<div><span>Medical certificate</span><b>' + (r.med_cert ? 'Yes ✓' : '<span class="ta-mis">No</span>') + '</b></div>' : '') +
            (r.reject_by ? '<div class="full"><span>' + (r.status === 'rejected' ? 'Not approved' : 'Cancelled') + ' by ' + esc(uname(r.reject_by)) + ' · ' + esc(r.reject_at) + '</span><b>' + esc(r.reject_note) + '</b></div>' : '') +
            '</div>';
        $('vSigns').innerHTML = S.steps.map(function (s) {
            var by = r[s + '_by'], can = r.canSign.indexOf(s) >= 0;
            return '<div class="lv-sign' + (by ? ' done' : '') + '"><span>' + esc(S.stepNames[s]) + '</span>' +
                (by ? '<b>' + esc(uname(by)) + '</b><small>' + esc(r[s + '_at']) + '</small>' : can ? '<button type="button" class="hw-btn pri" data-sign="' + s + '">Sign ✓</button>' : '<em>waiting</em>') + '</div>';
        }).join('') + (r.canSign.length > 1 ? '<button type="button" class="hw-btn" id="vSignAll">Sign all my steps</button>' : '');
        $('vReject').style.display = r.canSign.length ? '' : 'none';
        $('vCancelDoc').style.display = r.canCancel ? '' : 'none';
        $('vEdit').style.display = r.canEdit ? '' : 'none';
        msg('vMsg', ''); $('vBack').classList.add('show');
    }
    function afterChange(t) { S.bal.loaded = false; return loadReq().then(function () { if (S.view) openView(S.view.id); msg('vMsg', t); }); }
    $('vSigns').onclick = function (e) {
        var b = e.target.closest('[data-sign]'), all = e.target.closest('#vSignAll'); if (!b && !all) return;
        post('sign', { id: S.view.id, steps: all ? S.view.canSign : [b.getAttribute('data-sign')] }).then(function (d) { return afterChange(d.status === 'approved' ? 'Approved ✓' : 'Signed ✓'); })
            .catch(function (er) { msg('vMsg', er.message, true); });
    };
    $('vReject').onclick = function () {
        var n = prompt('Reason for not approving'); if (n === null) return;
        post('reject', { id: S.view.id, note: n }).then(function () { return afterChange('Not approved'); }).catch(function (er) { msg('vMsg', er.message, true); });
    };
    $('vCancelDoc').onclick = function () {
        var n = prompt('Cancel this leave? Reason (optional)'); if (n === null) return;
        post('cancel', { id: S.view.id, note: n }).then(function () { return afterChange('Cancelled'); }).catch(function (er) { msg('vMsg', er.message, true); });
    };
    $('vEdit').onclick = function () { $('vBack').classList.remove('show'); openForm(S.view); };
    $('vPrint').onclick = function () {
        var r = S.view, y = r.date_from.slice(0, 4);
        get('format=card&code=' + encodeURIComponent(r.emp_code) + '&year=' + y).then(function (d) {
            if (r.status !== 'approved') d.leaves = [r];   // ใบที่ยังไม่อนุมัติ : พิมพ์เฉพาะใบนี้ไปให้เซ็นบนกระดาษ
            HrPrint.leaveCard(d, S.users);
        }).catch(function (er) { msg('vMsg', er.message, true); });
    };
    $('vClose').onclick = function () { $('vBack').classList.remove('show'); S.view = null; };

    // ================= เขียนใบลา =================
    function codeOf(v) { v = (v || '').trim(); var m = /^(\S+)\s+[-–·]/.exec(v); var c = m ? m[1] : v; return S.emps[c] ? c : (S.empList.filter(function (e) { return e.code.toLowerCase() === c.toLowerCase(); })[0] || {}).code || c; }
    function portion() { var r = document.querySelector('input[name=portion]:checked'); return r ? r.value : 'full'; }
    function openForm(r) {
        S.edit = r ? r.id : 0;
        $('fTitle').textContent = r ? 'Edit ' + r.doc_no : 'New leave · ใบลา';
        $('f_emp').value = r ? r.emp_code + ' - ' + empName(r.emp_code) : '';
        $('f_emp').disabled = !!r && !S.me.hr;
        $('f_type').innerHTML = Object.keys(S.types).filter(function (t) { return S.me.hr || (t !== 'A' && t !== 'L'); })
            .map(function (t) { return '<option value="' + t + '">' + t + ' · ' + esc(S.types[t]) + '</option>'; }).join('');
        $('f_type').value = r ? r.leave_type : 'P';
        $('f_written').value = r ? (r.written_date || S.today) : S.today;
        document.querySelector('input[name=portion][value="' + (r ? r.portion : 'full') + '"]').checked = true;
        $('f_from').value = r ? r.date_from : S.today; $('f_to').value = r ? r.date_to : S.today; $('f_hours').value = r && r.hours ? r.hours : '';
        $('f_reason').value = r ? r.reason : ''; $('f_sub').value = r && r.substitute ? r.substitute : ''; $('f_cert').checked = r ? !!r.med_cert : false;
        $('f_paper').checked = false;
        msg('fMsg', ''); formUi(); $('fBack').classList.add('show'); setTimeout(function () { $(r ? 'f_from' : 'f_emp').focus(); }, 50);
    }
    function formUi() {
        var p = portion(), t = $('f_type').value;
        $('fToWrap').style.display = p === 'full' ? '' : 'none';
        $('fHoursWrap').style.display = p === 'hours' ? '' : 'none';
        $('fCertWrap').style.display = t === 'S' ? 'flex' : 'none';
        if ($('f_to').value < $('f_from').value) $('f_to').value = $('f_from').value;
        var code = codeOf($('f_emp').value), e = S.emps[code];
        if (!e) { $('fEmpInfo').innerHTML = $('f_emp').value ? '<span class="ta-mis">Employee not found</span>' : ''; $('fCalc').innerHTML = ''; return; }
        $('fEmpInfo').innerHTML = '<b>' + esc(e.code) + '</b> ' + esc(e.name) + ' · ' + esc(e.dept || '') + (e.pos ? ' · ' + esc(e.pos) : '') + ' · start ' + fd(e.start);
        // สิทธิ์คงเหลือของปีที่ลา
        var y = +($('f_from').value || S.today).slice(0, 4);
        ensureBal(y).then(function () {
            var b = S.balByYear[y] && S.balByYear[y][code]; if (!b) { $('fCalc').innerHTML = ''; return; }
            $('fCalc').innerHTML = 'Balance ' + y + ' : ' + ['V', 'S', 'P'].map(function (t) {
                var x = b[t]; var left = x.quota - x.used - x.pending;
                return '<span class="lv-bal-chip' + (t === $('f_type').value ? ' on' : '') + '">' + t + ' left <b>' + num(left) + '</b> / ' + num(x.quota) + (x.pending ? ' <small>(' + num(x.pending) + ' pending)</small>' : '') + '</span>';
            }).join(' ');
        });
    }
    S.balByYear = {};
    function ensureBal(y) {
        if (S.balByYear[y]) return Promise.resolve();
        return get('format=balance&year=' + y).then(function (d) {
            var m = {}; d.rows.forEach(function (r) { var o = {}; r.types.forEach(function (t) { o[t.type] = t; }); m[r.code] = o; }); S.balByYear[y] = m;
        }).catch(function () { });
    }
    ['f_emp', 'f_type', 'f_from', 'f_to'].forEach(function (id) { $(id).addEventListener('change', formUi); });
    $('fPortion').onchange = formUi;
    $('btnNew').onclick = function () { openForm(null); };
    $('fCancel').onclick = function () { $('fBack').classList.remove('show'); };
    $('fSave').onclick = function () {
        var code = codeOf($('f_emp').value);
        if (!S.emps[code]) { msg('fMsg', 'Choose an employee from the list', true); $('f_emp').focus(); return; }
        var b = {
            id: S.edit, emp: code, type: $('f_type').value, portion: portion(), from: $('f_from').value, to: portion() === 'full' ? $('f_to').value : $('f_from').value,
            hours: $('f_hours').value, reason: $('f_reason').value.trim(), substitute: codeOf($('f_sub').value), written: $('f_written').value,
            medCert: $('f_cert').checked, paper: $('f_paper').checked
        };
        if (!b.from) { msg('fMsg', 'Choose the leave date', true); return; }
        if (b.portion === 'hours' && !(+b.hours > 0)) { msg('fMsg', 'Enter hours', true); return; }
        if (!b.reason && b.type !== 'A' && b.type !== 'L') { msg('fMsg', 'Enter the reason · เหตุผลที่ลา', true); $('f_reason').focus(); return; }
        b.check = true; msg('fMsg', 'Checking…');
        post('save', b).then(function (c) {
            if (c.warnings.length && !confirm('⚠ ' + c.warnings.join('\n⚠ ') + '\n\nSubmit anyway?')) { msg('fMsg', 'Not submitted'); return; }
            b.check = false;
            return post('save', b).then(function (d) {
                $('fBack').classList.remove('show'); S.bal.loaded = false; S.balByYear = {};
                if ($('rFrom').value > b.from) $('rFrom').value = b.from;
                if ($('rTo').value < b.to) $('rTo').value = b.to;
                return loadReq().then(function () { msg('rMsg', 'Saved ✓ ' + num(d.days) + ' day(s)' + (b.paper ? ' — recorded as approved' : ' — waiting for signatures')); });
            });
        }).catch(function (er) { msg('fMsg', er.message, true); });
    };

    // ================= Balance =================
    function loadBal() {
        var y = +$('bYear').value; S.bal.loaded = true; S.bal.year = y;
        $('bBody').innerHTML = '<tr><td colspan="11" class="hw-empty">Loading…</td></tr>';
        return get('format=balance&year=' + y).then(function (d) {
            S.bal.rows = d.rows.map(function (r) {
                var e = S.emps[r.code] || {}, o = { code: r.code, name: e.name || '', nick: e.nick, dept: e.dept || '', start: e.start || '', t: {} };
                r.types.forEach(function (t) { o.t[t.type] = t; o[t.type] = t.used; }); return o;
            });
            renderBal();
        }).catch(function (e) { msg('bMsg', e.message, true); });
    }
    function renderBal() {
        var B = S.bal, q = B.q.toLowerCase();
        markSort('tab-bal', B.sort, B.desc);
        var list = sortRows(B.rows.filter(function (r) {
            if (B.dept && r.dept !== B.dept) return false;
            return !q || [r.code, r.name, r.nick].some(function (v) { return String(v || '').toLowerCase().indexOf(q) >= 0; });
        }), B.sort, B.desc);
        function cell(r, t) {
            var x = r.t[t]; if (!x) return '<td></td>';
            var left = x.quota - x.used, over = left < 0;
            return '<td class="c lv-q' + (S.me.hr ? ' ed' : '') + '" data-q="' + esc(r.code) + '|' + t + '" title="' + (x.custom ? 'Custom quota for this person' : 'Default quota') + (S.me.hr ? ' · click to change' : '') + '">' +
                '<b class="' + (over ? 'ta-c-nos' : '') + '">' + num(x.used) + '</b> / ' + num(x.quota) + (x.custom ? '<sup>*</sup>' : '') +
                (x.pending ? '<small class="mut" style="display:block">+' + num(x.pending) + ' pending</small>' : '') + '</td>';
        }
        $('bBody').innerHTML = list.map(function (r) {
            var z = function (t, times) { var x = r.t[t]; var v = x ? (times ? x.times : x.used) : 0; return '<td class="c">' + (v ? '<b>' + num(v) + '</b>' : '<span class="mut">·</span>') + '</td>'; };
            return '<tr><td class="emp-code">' + esc(r.code) + '</td><td class="emp-name"><b>' + esc(r.name) + (r.nick ? ' <span class="nick">(' + esc(r.nick) + ')</span>' : '') + '</b></td>' +
                '<td>' + esc(r.dept) + '</td><td>' + fd(r.start) + '</td>' + cell(r, 'V') + cell(r, 'S') + cell(r, 'P') + z('O') + z('A') + z('L', true) +
                '<td><button type="button" class="rowbtn" data-card="' + esc(r.code) + '">Leave card</button></td></tr>';
        }).join('') || '<tr><td colspan="11" class="hw-empty">No employees</td></tr>';
        msg('bMsg', 'Approved leave in ' + B.year + ' (by leave start date) · used / quota · * = custom quota for this person' + (S.me.hr ? ' — click a V / S / P cell to change the quota' : ''));
    }
    $('bYear').onchange = loadBal;
    $('bQ').oninput = function () { S.bal.q = this.value.trim(); renderBal(); };
    $('bDept').onchange = function () { S.bal.dept = this.value; renderBal(); };
    document.querySelector('#tab-bal thead').onclick = function (e) {
        var th = e.target.closest('th[data-k]'); if (!th) return; var k = th.getAttribute('data-k');
        if (S.bal.sort === k) S.bal.desc = !S.bal.desc; else { S.bal.sort = k; S.bal.desc = k.length === 1; } renderBal();
    };
    $('bBody').onclick = function (e) {
        var c = e.target.closest('[data-card]');
        if (c) { get('format=card&code=' + encodeURIComponent(c.getAttribute('data-card')) + '&year=' + S.bal.year).then(function (d) { HrPrint.leaveCard(d, S.users); }).catch(function (er) { msg('bMsg', er.message, true); }); return; }
        var q = e.target.closest('[data-q]'); if (!q || !S.me.hr) return;
        var p = q.getAttribute('data-q').split('|'), x = S.bal.rows.filter(function (r) { return r.code === p[0]; })[0].t[p[1]];
        var v = prompt(p[0] + ' · ' + S.types[p[1]] + ' quota for ' + S.bal.year + ' (days)\nLeave blank = default', x.custom ? x.quota : '');
        if (v === null) return;
        post('quota', { emp: p[0], year: S.bal.year, type: p[1], days: v.trim() }).then(function () { S.balByYear = {}; return loadBal(); }).catch(function (er) { msg('bMsg', er.message, true); });
    };

    // ================= Settings =================
    var LF = ['VacationDays', 'VacationAfterMonths', 'SickDays', 'PersonalDays', 'AdvanceDays', 'SickCertDays', 'HoursPerDay'];
    function renderSettings() {
        if (!S.cfg) return;
        LF.forEach(function (k) { $('l_' + k).value = S.cfg[k]; $('l_' + k).disabled = !S.me.hr; });
        msg('lMsg', S.me.hr ? '' : 'View only');
    }
    $('lSave').onclick = function () {
        var c = {}; LF.forEach(function (k) { c[k] = +$('l_' + k).value || 0; });
        post('settings', { config: c }).then(function (d) { S.cfg = d.config; renderSettings(); S.bal.loaded = false; S.balByYear = {}; msg('lMsg', 'Saved ✓'); })
            .catch(function (e) { msg('lMsg', e.message, true); });
    };

    // ================= เริ่ม =================
    get('format=init').then(function (d) {
        S.me = d.me; S.cfg = d.config; S.types = d.types; S.steps = d.steps; S.stepNames = d.stepNames; S.users = d.users || {}; S.today = d.today;
        if (!S.me.hr && !(S.me.depts && S.me.depts.length)) {   // ไม่ได้ผูกแผนก = มองไม่เห็นใบไหน / เซ็นไม่ได้
            var w = document.createElement('div'); w.className = 'hw-msg err'; w.style.margin = '0 0 10px';
            w.textContent = 'บัญชีนี้ยังไม่ได้เลือกแผนก จึงมองไม่เห็นและเซ็นใบไม่ได้ — ให้ admin เข้า HR Users แล้วติ๊กแผนกที่ดูแล';
            var bar = document.querySelector('.hw-bar'); bar.parentNode.insertBefore(w, bar.nextSibling);
        }
        S.empList = d.emps.map(function (e) { return { code: e.code, name: e.name, nick: e.nick, dept: e.dept, pos: e.pos, start: e.start, status: e.status }; });
        S.empList.forEach(function (e) { S.emps[e.code] = e; });
        $('dlEmp').innerHTML = S.empList.filter(function (e) { return e.status !== 'Resigned'; }).map(function (e) { return '<option value="' + esc(e.code + ' - ' + e.name) + '">'; }).join('');
        document.querySelectorAll('.req-only').forEach(function (x) { x.style.display = S.me.canRequest ? '' : 'none'; });
        document.querySelectorAll('.hr-only').forEach(function (x) { x.style.display = S.me.hr ? '' : 'none'; });
        $('rType').innerHTML = '<option value="">All types</option>' + Object.keys(S.types).map(function (t) { return '<option value="' + t + '">' + t + ' · ' + esc(S.types[t]) + '</option>'; }).join('');
        deptOptions('rDept', ''); deptOptions('bDept', '');
        var y = +S.today.slice(0, 4); $('bYear').innerHTML = [y + 1, y, y - 1, y - 2].map(function (v) { return '<option' + (v === y ? ' selected' : '') + '>' + v + '</option>'; }).join('');
        thisMonth();
        return loadReq().then(function () { if (!S.req.rows.some(function (r) { return reqFilter(r, 'mine'); })) { S.req.st = 'pending'; renderReq(); } });
    }).catch(function (e) { msg('rMsg', 'Load failed: ' + e.message, true); });

    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') { $('fBack').classList.remove('show'); $('vBack').classList.remove('show'); } });
    var form1 = document.getElementById('form1'); if (form1) form1.addEventListener('submit', function (e) { e.preventDefault(); });
})();
