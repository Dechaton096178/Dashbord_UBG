// @ts-nocheck
// ===== Overtime (OtRequest.aspx) : ใบขอ OT UBG-FM-HR-07 =====
(function () {
    var API = 'OtRequest.aspx';
    var $ = function (id) { return document.getElementById(id); };
    var esc = HrPrint.esc;
    var S = {
        me: {}, steps: [], stepNames: {}, emps: {}, empList: [], users: {}, today: '', shifts: [],
        req: { rows: [], q: '', dept: '', st: 'mine', sort: 'ot_date', desc: true },
        cmp: { rows: [], no: [], q: '', dept: '', flag: '' },
        edit: 0, lines: [], view: null
    };
    var STATUS = { pending: ['work', 'Pending'], approved: ['ok', 'Approved'], rejected: ['nos', 'Not approved'], cancelled: ['off', 'Cancelled'] };
    var FLAG = { '': ['ok', 'OK'], short: ['early', 'Less than requested'], noscan: ['nos', 'No scan'], noout: ['noout', 'No OUT scan'], working: ['work', 'Not finished yet'] };

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
    function fdt(s) { return s ? fd(s) + ' ' + s.slice(11, 16) : ''; }   // 2026-10-27 19:45 -> 27/10/2026 19:45
    function hrs(min) { min = +min || 0; return min ? (Math.round(min / 6) / 10).toString() : ''; }
    function mins(hm) { var m = /^(\d{1,2}):(\d{2})$/.exec(hm || ''); return m ? +m[1] * 60 + +m[2] : -1; }
    function span(a, b) { var x = mins(a), y = mins(b); if (x < 0 || y < 0 || x === y) return 0; return y > x ? y - x : y + 1440 - x; }
    function hm(m) { m = ((m % 1440) + 1440) % 1440; return ('0' + Math.floor(m / 60)).slice(-2) + ':' + ('0' + (m % 60)).slice(-2); }
    function uname(u) { return S.users[u] || u; }
    function empName(c) { var e = S.emps[c]; return e ? e.name + (e.nick ? ' (' + e.nick + ')' : '') : ''; }
    function deptOptions(sel, cur, first) {
        var o = {}; S.empList.forEach(function (e) { if (e.dept) o[e.dept] = 1; });
        $(sel).innerHTML = (first ? '<option value="">' + first + '</option>' : '') + Object.keys(o).sort().map(function (d) { return '<option' + (cur === d ? ' selected' : '') + '>' + esc(d) + '</option>'; }).join('');
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
        ['req', 'cmp'].forEach(function (x) { $('tab-' + x).style.display = x === t ? '' : 'none'; });
        if (t === 'cmp' && !S.cmp.loaded) loadCmp();
    }
    $('tabs').onclick = function (e) { var b = e.target.closest('button[data-tab]'); if (b) showTab(b.getAttribute('data-tab')); };

    // ================= Requests =================
    function loadReq() {
        $('rBody').innerHTML = '<tr><td colspan="8" class="hw-empty">Loading…</td></tr>';
        return get('format=list&from=' + $('rFrom').value + '&to=' + $('rTo').value).then(function (d) {
            d.rows.forEach(function (r) { r.people = r.lines.length; }); S.req.rows = d.rows; renderReq();
        }).catch(function (e) { msg('rMsg', e.message, true); });
    }
    function reqFilter(r, st) {
        if (st === 'mine') return r.canSign && r.canSign.length > 0;
        if (st === 'closed') return r.status === 'rejected' || r.status === 'cancelled';
        return !st || r.status === st;
    }
    function renderReq() {
        var R = S.req, all = R.rows;
        $('rChips').innerHTML = [['mine', 'Waiting for my signature'], ['pending', 'Pending'], ['approved', 'Approved'], ['closed', 'Not approved / cancelled'], ['', 'All']].map(function (c) {
            var n = all.filter(function (r) { return reqFilter(r, c[0]); }).length;
            return '<span class="hw-chip' + (R.st === c[0] ? ' on' : '') + (c[0] === 'mine' && n ? ' lv-hot' : '') + '" data-st="' + c[0] + '">' + c[1] + '<em>' + n + '</em></span>';
        }).join('');
        document.querySelectorAll('#tab-req th[data-k]').forEach(function (th) { var on = th.getAttribute('data-k') === R.sort; th.classList.toggle('sorted', on); th.classList.toggle('desc', on && R.desc); });
        var q = R.q.toLowerCase(), dir = R.desc ? -1 : 1;
        var list = all.filter(function (r) {
            if (!reqFilter(r, R.st)) return false;
            if (R.dept && r.department !== R.dept) return false;
            return !q || r.doc_no.toLowerCase().indexOf(q) >= 0 || r.lines.some(function (l) { return (l.emp_code + ' ' + empName(l.emp_code)).toLowerCase().indexOf(q) >= 0; });
        }).sort(function (a, b) { var x = a[R.sort], y = b[R.sort]; if (typeof x !== 'number') { x = String(x || ''); y = String(y || ''); } return x < y ? -dir : x > y ? dir : 0; });
        $('rBody').innerHTML = list.map(function (r) {
            var st = STATUS[r.status] || ['', r.status];
            return '<tr data-id="' + r.id + '"><td class="emp-code">' + esc(r.doc_no) + '</td><td>' + fd(r.ot_date) + '</td><td><b>' + esc(r.department) + '</b>' + (r.note ? '<small class="mut" style="display:block">' + esc(r.note) + '</small>' : '') + '</td>' +
                '<td class="c">' + r.people + '</td><td class="c"><b class="ta-c-ot">' + hrs(r.minutes) + '</b></td><td>' + esc(uname(r.created_by)) + '</td>' +
                '<td>' + signDots(r) + '</td><td><span class="ta-st ' + st[0] + '">' + st[1] + '</span></td></tr>';
        }).join('') || '<tr><td colspan="8" class="hw-empty">' + (R.st === 'mine' ? 'Nothing waiting for your signature 👍' : 'No OT requests in this range') + '</td></tr>';
        msg('rMsg', 'Showing ' + list.length + ' of ' + all.length + ' · click a row to view / sign / print');
    }
    function thisMonth() { var t = pd(S.today); $('rFrom').value = iso(new Date(t.getFullYear(), t.getMonth(), 1)); $('rTo').value = iso(new Date(t.getFullYear(), t.getMonth() + 1, 0)); }
    $('rFrom').onchange = $('rTo').onchange = loadReq;
    $('rThis').onclick = function () { thisMonth(); loadReq(); };
    $('rQ').oninput = function () { S.req.q = this.value.trim(); renderReq(); };
    $('rDept').onchange = function () { S.req.dept = this.value; renderReq(); };
    $('rChips').onclick = function (e) { var c = e.target.closest('[data-st]'); if (c) { S.req.st = c.getAttribute('data-st'); renderReq(); } };
    document.querySelector('#tab-req thead').onclick = function (e) {
        var th = e.target.closest('th[data-k]'); if (!th) return; var k = th.getAttribute('data-k');
        if (S.req.sort === k) S.req.desc = !S.req.desc; else { S.req.sort = k; S.req.desc = false; } renderReq();
    };
    $('rBody').onclick = function (e) { var tr = e.target.closest('tr[data-id]'); if (tr) openView(+tr.getAttribute('data-id')); };

    // ================= ดูใบ / เซ็น =================
    function openView(id) {
        var r = S.req.rows.filter(function (x) { return x.id === id; })[0]; if (!r) return;
        S.view = r; var st = STATUS[r.status] || ['', r.status];
        $('vTitle').innerHTML = esc(r.doc_no) + ' · ' + esc(r.department) + ' · ' + fd(r.ot_date) + ' <span class="ta-st ' + st[0] + '">' + st[1] + '</span>';
        $('vBody').innerHTML = (r.note ? '<p><b>Note:</b> ' + esc(r.note) + '</p>' : '') +
            '<div class="hw-table-wrap" style="max-height:42vh;border:1px solid #e2e8f0;border-radius:12px"><table class="hw-table"><thead><tr><th>#</th><th>Code</th><th>Name</th><th>From</th><th>To</th><th class="c">Hrs</th><th>Job detail</th><th>Remark</th></tr></thead><tbody>' +
            r.lines.map(function (l, i) {
                return '<tr><td>' + (i + 1) + '</td><td class="emp-code">' + esc(l.emp_code) + '</td><td>' + esc(empName(l.emp_code)) + '</td><td class="ta-t">' + esc(l.time_from) + '</td><td class="ta-t">' + esc(l.time_to) + '</td>' +
                    '<td class="c"><b>' + hrs(span(l.time_from, l.time_to)) + '</b></td><td class="rm">' + esc(l.job) + '</td><td class="rm">' + esc(l.remark) + '</td></tr>';
            }).join('') + '</tbody></table></div>' +
            '<p class="mut" style="font-size:12.5px">Requested by ' + esc(uname(r.created_by)) + ' · ' + esc(r.created_at) + ' · total ' + hrs(r.minutes) + ' h' +
            (r.reject_by ? ' · <b>' + (r.status === 'rejected' ? 'Not approved' : 'Cancelled') + '</b> by ' + esc(uname(r.reject_by)) + ': ' + esc(r.reject_note) : '') + '</p>';
        $('vSigns').innerHTML = '<div class="lv-sign done"><span>Requester · ผู้ขอเปิดโอที</span><b>' + esc(uname(r.created_by)) + '</b><small>' + esc(r.created_at) + '</small></div>' +
            S.steps.map(function (s) {
                var by = r[s + '_by'], can = r.canSign.indexOf(s) >= 0;
                return '<div class="lv-sign' + (by ? ' done' : '') + '"><span>' + esc(S.stepNames[s]) + '</span>' +
                    (by ? '<b>' + esc(uname(by)) + '</b><small>' + esc(r[s + '_at']) + '</small>' : can ? '<button type="button" class="hw-btn pri" data-sign="' + s + '">Sign ✓</button>' : '<em>waiting</em>') + '</div>';
            }).join('') + (r.canSign.length > 1 ? '<button type="button" class="hw-btn" id="vSignAll">Sign all my steps</button>' : '');
        $('vReject').style.display = r.canSign.length ? '' : 'none';
        $('vCancelDoc').style.display = r.canCancel ? '' : 'none';
        $('vEdit').style.display = r.canEdit ? '' : 'none';
        msg('vMsg', ''); $('vBack').classList.add('show');
    }
    function afterChange(t) { S.cmp.loaded = false; return loadReq().then(function () { if (S.view) openView(S.view.id); msg('vMsg', t); }); }
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
        var n = prompt('Cancel this OT request? Reason (optional)'); if (n === null) return;
        post('cancel', { id: S.view.id, note: n }).then(function () { return afterChange('Cancelled'); }).catch(function (er) { msg('vMsg', er.message, true); });
    };
    $('vEdit').onclick = function () { $('vBack').classList.remove('show'); openForm(S.view); };
    $('vPrint').onclick = function () {
        var em = {}; S.empList.forEach(function (e) { em[e.code] = e; });
        HrPrint.otForm(S.view, em, S.users);
    };
    $('vClose').onclick = function () { $('vBack').classList.remove('show'); S.view = null; };

    // ================= เขียนใบขอ OT =================
    function codeOf(v) { v = (v || '').trim(); var m = /^(\S+)\s+[-–·]/.exec(v); var c = m ? m[1] : v; var e = S.empList.filter(function (x) { return x.code.toLowerCase() === c.toLowerCase(); })[0]; return e ? e.code : ''; }
    function openForm(r) {
        S.edit = r ? r.id : 0;
        $('fTitle').textContent = r ? 'Edit ' + r.doc_no : 'New OT request · ใบขออนุมัติทำงานล่วงเวลา';
        deptOptions('f_dept', r ? r.department : (S.me.depts && S.me.depts.length ? S.me.depts[0] : ''), '');
        $('f_date').value = r ? r.ot_date : S.today; $('f_note').value = r ? r.note : '';
        S.lines = r ? r.lines.map(function (l) { return { emp: l.emp_code, from: l.time_from, to: l.time_to, job: l.job, remark: l.remark }; }) : [];
        $('f_shift').innerHTML = '<option value="">Start after shift…</option>' + S.shifts.map(function (s) { return '<option value="' + esc(s.code) + '">' + esc(s.name) + ' ends ' + esc(s.end) + '</option>'; }).join('');
        if (!r) { $('f_from').value = ''; $('f_to').value = ''; $('f_job').value = ''; }
        $('f_paper').checked = false; $('f_add').value = '';
        renderLines(); msg('fMsg', ''); $('fBack').classList.add('show');
    }
    function renderLines() {
        var tot = 0;
        $('fLines').innerHTML = S.lines.map(function (l, i) {
            var h = span(l.from, l.to); tot += h;
            return '<tr data-i="' + i + '"><td>' + (i + 1) + '</td><td class="emp-code">' + esc(l.emp) + '</td><td>' + esc(empName(l.emp)) + '</td>' +
                '<td><input type="time" data-f="from" value="' + esc(l.from) + '"></td><td><input type="time" data-f="to" value="' + esc(l.to) + '"></td>' +
                '<td class="c"><b>' + hrs(h) + '</b></td><td><input data-f="job" maxlength="200" value="' + esc(l.job) + '"></td><td><input data-f="remark" maxlength="200" value="' + esc(l.remark) + '"></td>' +
                '<td><button type="button" class="rowbtn" data-del="' + i + '">✕</button></td></tr>';
        }).join('') || '<tr><td colspan="9" class="hw-empty">Add employees above</td></tr>';
        $('fCount').textContent = S.lines.length + ' people · ' + hrs(tot) + ' h' + (S.lines.length > 15 ? ' · prints on ' + Math.ceil(S.lines.length / 15) + ' forms (15 per form)' : '');
    }
    function addEmp(code) {
        if (!code) return false;
        if (S.lines.some(function (l) { return l.emp === code; })) return false;
        S.lines.push({ emp: code, from: $('f_from').value, to: $('f_to').value, job: $('f_job').value.trim(), remark: '' });
        return true;
    }
    $('fLines').oninput = function (e) {
        var x = e.target.closest('[data-f]'); if (!x) return; var i = +x.closest('tr').getAttribute('data-i');
        S.lines[i][x.getAttribute('data-f')] = x.value;
        if (x.type === 'time') { var tr = x.closest('tr'); tr.children[5].innerHTML = '<b>' + hrs(span(S.lines[i].from, S.lines[i].to)) + '</b>'; renderCount(); }
    };
    function renderCount() { var t = 0; S.lines.forEach(function (l) { t += span(l.from, l.to); }); $('fCount').textContent = S.lines.length + ' people · ' + hrs(t) + ' h'; }
    $('fLines').onclick = function (e) { var b = e.target.closest('[data-del]'); if (b) { S.lines.splice(+b.getAttribute('data-del'), 1); renderLines(); } };
    $('f_shift').onchange = function () {
        var s = S.shifts.filter(function (x) { return x.code === $('f_shift').value; })[0]; if (!s) return;
        var a = mins(s.end) + (s.otBreak == null ? 60 : s.otBreak); $('f_from').value = hm(a); $('f_to').value = hm(a + 120);   // เลิกกะ + พัก → OT 2 ชม.
    };
    $('fApply').onclick = function () {
        S.lines.forEach(function (l) { if ($('f_from').value) l.from = $('f_from').value; if ($('f_to').value) l.to = $('f_to').value; if ($('f_job').value.trim()) l.job = $('f_job').value.trim(); });
        renderLines();
    };
    function addTyped() {
        var c = codeOf($('f_add').value);
        if (!c) { msg('fMsg', 'Employee not found', true); return; }
        if (!addEmp(c)) msg('fMsg', c + ' is already in the list', true); else msg('fMsg', '');
        $('f_add').value = ''; renderLines(); $('f_add').focus();
    }
    $('fAdd').onclick = addTyped;
    $('f_add').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); addTyped(); } });
    $('f_add').addEventListener('change', function () { if (codeOf(this.value)) addTyped(); });
    $('fAddDept').onclick = function () {
        var d = $('f_dept').value, n = 0;
        S.empList.filter(function (e) { return e.dept === d && e.status !== 'Resigned'; }).forEach(function (e) { if (addEmp(e.code)) n++; });
        renderLines(); msg('fMsg', 'Added ' + n + ' from ' + d);
    };
    $('btnNew').onclick = function () { openForm(null); };
    $('fCancel').onclick = function () { $('fBack').classList.remove('show'); };
    $('fSave').onclick = function () {
        if (!S.lines.length) { msg('fMsg', 'Add at least one employee', true); return; }
        var bad = S.lines.filter(function (l) { return mins(l.from) < 0 || mins(l.to) < 0 || l.from === l.to; });
        if (bad.length) { msg('fMsg', 'Set From / To time for: ' + bad.map(function (l) { return l.emp; }).join(', '), true); return; }
        msg('fMsg', 'Saving…');
        post('save', { id: S.edit, dept: $('f_dept').value, date: $('f_date').value, note: $('f_note').value.trim(), paper: $('f_paper').checked,
                       lines: S.lines.map(function (l) { return { emp: l.emp, from: l.from, to: l.to, job: l.job, remark: l.remark }; }) })
            .then(function () {
                $('fBack').classList.remove('show'); S.cmp.loaded = false;
                var dt = $('f_date').value; if ($('rFrom').value > dt) $('rFrom').value = dt; if ($('rTo').value < dt) $('rTo').value = dt;
                return loadReq().then(function () { msg('rMsg', 'Saved ✓' + ($('f_paper').checked ? ' — recorded as approved' : ' — waiting for signatures')); });
            }).catch(function (er) { msg('fMsg', er.message, true); });
    };

    // ================= OT vs scan =================
    function loadCmp() {
        S.cmp.loaded = true;
        $('cBody').innerHTML = '<tr><td colspan="10" class="hw-empty">Loading…</td></tr>';
        return get('format=compare&from=' + $('cFrom').value + '&to=' + $('cTo').value).then(function (d) { S.cmp.rows = d.rows; S.cmp.no = d.noRequest; renderCmp(); })
            .catch(function (e) { msg('cMsg', e.message, true); $('cBody').innerHTML = ''; });
    }
    function cmpMatch(r) {
        var C = S.cmp, q = C.q.toLowerCase();
        if (C.dept && r.dept !== C.dept) return false;
        return !q || (r.emp + ' ' + r.name).toLowerCase().indexOf(q) >= 0;
    }
    function renderCmp() {
        var C = S.cmp, all = C.rows.filter(cmpMatch), sum = function (k, f) { return all.filter(f || function () { return true; }).reduce(function (s, r) { return s + (r[k] || 0); }, 0); };
        $('cKpis').innerHTML =
            '<div class="hw-kpi acc"><span>Requested</span><b>' + hrs(sum('appr')) + '</b><small>' + all.length + ' lines</small></div>' +
            '<div class="hw-kpi ok"><span>Payable (approved)</span><b>' + hrs(sum('pay', function (r) { return r.status === 'approved'; })) + '</b><small>requested ∩ scan</small></div>' +
            '<div class="hw-kpi"><span>Waiting approval</span><b>' + hrs(sum('appr', function (r) { return r.status === 'pending'; })) + '</b><small>hours</small></div>' +
            '<div class="hw-kpi bad"><span>No scan</span><b>' + all.filter(function (r) { return r.flag === 'noscan'; }).length + '</b></div>' +
            '<div class="hw-kpi"><span>OT without request</span><b class="ta-c-late">' + C.no.filter(cmpMatch).length + '</b></div>';
        $('cChips').innerHTML = [['', 'All'], ['short', 'Less than requested'], ['noscan', 'No scan'], ['noout', 'No OUT scan'], ['pending', 'Waiting approval']].map(function (c) {
            return '<span class="hw-chip' + (C.flag === c[0] ? ' on' : '') + '" data-f="' + c[0] + '">' + c[1] + '</span>';
        }).join('');
        var list = all.filter(function (r) { return !C.flag || (C.flag === 'pending' ? r.status === 'pending' : r.flag === C.flag); });
        $('cBody').innerHTML = list.map(function (r) {
            var f = FLAG[r.flag] || ['', r.flag];
            return '<tr><td>' + fd(r.date) + '</td><td class="emp-code">' + esc(r.doc) + (r.status !== 'approved' ? ' <span class="ta-st work">pending</span>' : '') + '</td>' +
                '<td class="emp-name"><b>' + esc(r.name) + '</b><small>' + esc(r.emp) + '</small></td><td>' + esc(r.dept) + '</td>' +
                '<td class="c ta-t">' + esc(r.from) + '–' + esc(r.to) + '</td><td class="c">' + hrs(r.appr) + '</td><td class="c ta-t">' + esc(r['in']) + '</td><td class="c ta-t">' + esc(r.out) + '</td>' +
                '<td class="c"><b class="ta-c-ot">' + hrs(r.pay) + '</b></td><td><span class="ta-st ' + f[0] + '">' + f[1] + '</span></td></tr>';
        }).join('') || '<tr><td colspan="10" class="hw-empty">No OT requests in this range</td></tr>';
        var no = C.no.filter(cmpMatch);
        $('cNoN').textContent = '(' + no.length + ')';
        $('cNo').innerHTML = no.map(function (r) {
            return '<tr><td>' + fd(r.date) + '</td><td class="emp-name"><b>' + esc(r.name) + '</b><small>' + esc(r.emp) + '</small></td><td>' + esc(r.dept) + '</td><td>' + esc(r.shift) + '</td>' +
                '<td class="c ta-t">' + fdt(r['in']) + '</td><td class="c ta-t">' + fdt(r.out) + '</td><td class="c"><b class="ta-c-late">' + hrs(r.ot) + '</b></td></tr>';
        }).join('') || '<tr><td colspan="7" class="hw-empty">None 👍</td></tr>';
        msg('cMsg', 'Payable = overlap of requested time and actual scan in/out, rounded down (Time Attendance → Settings). Only approved requests are payable.');
    }
    $('cFrom').onchange = $('cTo').onchange = loadCmp;
    $('cQ').oninput = function () { S.cmp.q = this.value.trim(); renderCmp(); };
    $('cDept').onchange = function () { S.cmp.dept = this.value; renderCmp(); };
    $('cChips').onclick = function (e) { var c = e.target.closest('[data-f]'); if (c) { S.cmp.flag = c.getAttribute('data-f'); renderCmp(); } };
    $('cCsv').onclick = function () {
        var rows = [['Date', 'Doc', 'Status', 'Code', 'Name', 'Department', 'From', 'To', 'Requested hrs', 'Scan in', 'Scan out', 'Payable hrs', 'Check']];
        S.cmp.rows.filter(cmpMatch).forEach(function (r) { rows.push([r.date, r.doc, r.status, r.emp, r.name, r.dept, r.from, r.to, hrs(r.appr), r['in'], r.out, hrs(r.pay), (FLAG[r.flag] || ['', r.flag])[1]]); });
        var csv = '﻿' + rows.map(function (r) { return r.map(function (v) { v = String(v == null ? '' : v); return /[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; }).join(','); }).join('\r\n');
        var a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
        a.download = 'OT_vs_scan_' + $('cFrom').value + '_' + $('cTo').value + '.csv'; document.body.appendChild(a); a.click(); a.remove();
    };

    // ================= เริ่ม =================
    get('format=init').then(function (d) {
        S.me = d.me; S.steps = d.steps; S.stepNames = d.stepNames; S.users = d.users || {}; S.today = d.today; S.shifts = d.shifts || [];
        if (!S.me.hr && !(S.me.depts && S.me.depts.length)) {   // ไม่ได้ผูกแผนก = มองไม่เห็นใบไหน / เซ็นไม่ได้
            var w = document.createElement('div'); w.className = 'hw-msg err'; w.style.margin = '0 0 10px';
            w.textContent = 'บัญชีนี้ยังไม่ได้เลือกแผนก จึงมองไม่เห็นและเซ็นใบไม่ได้ — ให้ admin เข้า HR Users แล้วติ๊กแผนกที่ดูแล';
            var bar = document.querySelector('.hw-bar'); bar.parentNode.insertBefore(w, bar.nextSibling);
        }
        S.empList = d.emps.map(function (e) { return { code: e.code, name: e.name, nick: e.nick, dept: e.dept, status: e.status }; });
        S.empList.forEach(function (e) { S.emps[e.code] = e; });
        $('dlEmp').innerHTML = S.empList.filter(function (e) { return e.status !== 'Resigned'; }).map(function (e) { return '<option value="' + esc(e.code + ' - ' + e.name) + '">'; }).join('');
        document.querySelectorAll('.req-only').forEach(function (x) { x.style.display = S.me.canRequest ? '' : 'none'; });
        document.querySelectorAll('.hr-only').forEach(function (x) { x.style.display = S.me.hr ? '' : 'none'; });
        deptOptions('rDept', '', 'All departments'); deptOptions('cDept', '', 'All departments');
        thisMonth();
        var t = pd(S.today); $('cFrom').value = iso(new Date(t.getFullYear(), t.getMonth(), 1)); $('cTo').value = S.today;
        return loadReq().then(function () { if (!S.req.rows.some(function (r) { return reqFilter(r, 'mine'); })) { S.req.st = 'pending'; renderReq(); } });
    }).catch(function (e) { msg('rMsg', 'Load failed: ' + e.message, true); });

    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') { $('fBack').classList.remove('show'); $('vBack').classList.remove('show'); } });
    var form1 = document.getElementById('form1'); if (form1) form1.addEventListener('submit', function (e) { e.preventDefault(); });
})();
