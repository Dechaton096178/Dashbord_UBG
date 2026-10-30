// @ts-nocheck
// ===== Time Attendance (TimeAttendance.aspx) =====
(function () {
    var API = 'TimeAttendance.aspx';
    var $ = function (id) { return document.getElementById(id); };
    var root = $('hw');
    var S = {
        me: {}, cfg: null, today: '', tab: 'day',
        day: { date: '', rows: [], q: '', dept: '', st: '', sort: 'code', desc: false },
        sum: { rows: [], q: '', dept: '', sort: 'code', desc: false },
        plan: { rows: [], q: '', dept: '', group: '', shift: null, sort: 'code', desc: false, sel: {} },
        person: null, imp: null
    };
    var DOW = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
    var ST = {
        ok: ['ok', 'On time'], late: ['late', 'Late'], early: ['early', 'Early out'], noout: ['noout', 'No OUT scan'],
        working: ['work', 'No OUT yet'], noscan: ['nos', 'No scan'], off: ['off', 'Day off'], pending: ['off', 'No scan yet'], unseen: ['off', 'Not in scanner 30d'], leave: ['leave', 'Leave']
    };

    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
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
    function hm(min) { min = +min || 0; return min ? Math.floor(min / 60) + ':' + ('0' + (min % 60)).slice(-2) : ''; }
    function hrs(min) { min = +min || 0; return min ? (min / 60).toFixed(1).replace(/\.0$/, '') : ''; }
    function iso(d) { return d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2); }
    function pd(s) { var p = s.split('-'); return new Date(+p[0], +p[1] - 1, +p[2]); }
    function addDays(s, n) { var d = pd(s); d.setDate(d.getDate() + n); return iso(d); }
    function fd(s) { if (!s) return ''; var p = s.split('-'); return p[2] + '/' + p[1] + '/' + p[0]; }
    var LVN = { S: 'Sick', P: 'Personal', V: 'Vacation', O: 'Other leave', A: 'Absence', L: 'Late (recorded)' };
    function leaveBadge(r) {
        if (!r.leave) return '';
        return ' <span class="ta-st ' + (r.leave === 'A' ? 'nos' : 'leave') + '" title="' + esc(r.leaveDoc) + (r.leaveSt !== 'approved' ? ' · waiting approval' : '') + '">' +
            r.leave + ' · ' + LVN[r.leave] + (r.leavePortion === 'am' ? ' ½AM' : r.leavePortion === 'pm' ? ' ½PM' : '') + (r.leaveSt !== 'approved' ? ' ?' : '') + '</span>';
    }
    function otCell(r, f) {
        var h = (r.ot ? '<b class="ta-c-ot">' + f(r.ot) + '</b>' : '');
        if (r.otReq) h += '<small class="ta-otreq' + (r.otReqSt !== 'approved' ? ' pend' : '') + '" title="OT request ' + esc(r.otReq) + (r.otReqSt !== 'approved' ? ' (waiting approval)' : '') + '">req ' + esc(r.otReq) + (r.otReqSt === 'approved' ? ' · pay ' + (f(r.otPay) || '0') : ' ?') + '</small>';
        else if (r.otNoReq) h += '<small class="ta-otreq no" title="OT by scan time but no OT request">no request</small>';
        return h;
    }
    function stBadge(st, unknown) {
        var x = ST[st] || ['', st];
        return (unknown ? '<span class="ta-st unk">Unknown ID</span> ' : '') + (st ? '<span class="ta-st ' + x[0] + '">' + x[1] + '</span>' : '');
    }
    // กะดึก = เริ่มบ่าย / ข้ามเที่ยงคืน
    function isNight(code) {
        var sh = S.cfg && S.cfg.Shifts.filter(function (x) { return x.Code === code; })[0]; if (!sh) return false;
        var a = +sh.Start.slice(0, 2), b = +sh.End.slice(0, 2); return a >= 14 || b < a;
    }
    function shBadge(r) {
        if (!r.shift) return '';
        var t = r.planned ? 'Shift plan · ' + r.shiftTime : 'No shift plan — guessed from scan time · ' + r.shiftTime;
        return '<span class="ta-sh' + (isNight(r.shift) ? ' ta-sh-N' : '') + (r.planned ? '' : ' ta-guess') + '" title="' + esc(t) + '">' + esc(r.shiftName) + '</span>' +
            (r.mismatch ? '<span class="ta-mis" title="Shift plan says ' + esc(r.planShift) + ' but scan time does not fit — check the plan">≠ plan ' + esc(r.planShift) + '</span>' : '');
    }
    function nameCell(r) {
        return '<td class="emp-name"><b>' + esc(r.name || '(no name)') + (r.nick ? ' <span class="nick">(' + esc(r.nick) + ')</span>' : '') + '</b>' +
            (r.code ? '' : '<small>Scanner ID ' + esc(r.scan) + '</small>') + '</td>';
    }
    function sortRows(rows, k, desc) {
        var dir = desc ? -1 : 1;
        return rows.sort(function (a, b) {
            var x = a[k], y = b[k];
            if (typeof x === 'number' || typeof y === 'number') { x = +x || 0; y = +y || 0; }
            else { x = String(x || '').toLowerCase(); y = String(y || '').toLowerCase(); if (!x) x = '￿'; if (!y) y = '￿'; }
            return x < y ? -dir : x > y ? dir : 0;
        });
    }
    function deptOptions(sel, rows, cur) {
        var o = {}; rows.forEach(function (r) { var d = r.dept || '(none)'; o[d] = (o[d] || 0) + 1; });
        $(sel).innerHTML = '<option value="">All departments</option>' + Object.keys(o).sort().map(function (d) {
            return '<option value="' + esc(d) + '"' + (cur === d ? ' selected' : '') + '>' + esc(d) + ' (' + o[d] + ')</option>';
        }).join('');
    }
    function match(r, q, dept) {
        if (dept && (r.dept || '(none)') !== dept) return false;
        if (!q) return true; q = q.toLowerCase();
        return [r.code, r.scan, r.name, r.nick].some(function (v) { return String(v || '').toLowerCase().indexOf(q) >= 0; });
    }
    function markSort(tbl, k, desc) {
        document.querySelectorAll('#' + tbl + ' th[data-k]').forEach(function (th) {
            var on = th.getAttribute('data-k') === k; th.classList.toggle('sorted', on); th.classList.toggle('desc', on && desc);
        });
    }

    // ================= Tabs =================
    function showTab(t) {
        S.tab = t;
        document.querySelectorAll('#tabs button').forEach(function (b) { b.classList.toggle('on', b.getAttribute('data-tab') === t); });
        ['day', 'sum', 'plan', 'imp', 'set'].forEach(function (x) { $('tab-' + x).style.display = x === t ? '' : 'none'; });
        if (t === 'sum' && !S.sum.loaded) loadSum();
        if (t === 'plan' && !S.plan.loaded) loadPlan();
        if (t === 'set') renderSettings();
        try { localStorage.setItem('ta.tab', t); } catch (e) { }
    }
    $('tabs').addEventListener('click', function (e) { var b = e.target.closest('button[data-tab]'); if (b) showTab(b.getAttribute('data-tab')); });
    $('btnHelp').onclick = function () { var h = $('help'); h.style.display = h.style.display === 'none' ? '' : 'none'; };

    // ================= Daily =================
    function loadDay(date) {
        S.day.date = date; $('dDate').value = date;
        $('dDow').textContent = DOW[pd(date).getDay()] + (S.cfg && S.cfg.Holidays.indexOf(date) >= 0 ? ' · วันหยุด' : '');
        $('dCsv').href = API + '?format=csvday&date=' + date;
        $('dBody').innerHTML = '<tr><td colspan="11" class="hw-empty">Loading…</td></tr>';
        return get('format=day&date=' + date).then(function (d) { S.day.rows = d.rows; renderDay(); })
            .catch(function (e) { msg('dMsg', 'Load failed: ' + e.message, true); });
    }
    function renderDay() {
        var all = S.day.rows, D = S.day;
        var cnt = function (f) { return all.filter(f).length; };
        var people = {}; all.forEach(function (r) { if (r.status !== 'off' && r.status !== 'unseen') people[r.scan] = 1; });
        var present = {}; all.forEach(function (r) { if (r['in']) present[r.scan] = 1; });
        var ot = all.reduce(function (s, r) { return s + (r.ot || 0); }, 0);
        $('dKpis').innerHTML =
            '<div class="hw-kpi acc"><span>Present</span><b>' + Object.keys(present).length + '</b><small>of ' + Object.keys(people).length + ' expected</small></div>' +
            '<div class="hw-kpi bad"><span>No scan</span><b>' + cnt(function (r) { return r.status === 'noscan'; }) + '</b><small>no leave form</small></div>' +
            '<div class="hw-kpi"><span>Leave</span><b>' + cnt(function (r) { return r.leave && r.leave !== 'L'; }) + '</b><small>from leave forms</small></div>' +
            '<div class="hw-kpi"><span>Late</span><b class="ta-c-late">' + cnt(function (r) { return r.late > 0; }) + '</b></div>' +
            '<div class="hw-kpi"><span>No OUT scan</span><b class="ta-c-noout">' + cnt(function (r) { return r.status === 'noout'; }) + '</b></div>' +
            '<div class="hw-kpi"><span>Night shift</span><b>' + cnt(function (r) { return r.shift && isNight(r.shift); }) + '</b></div>' +
            '<div class="hw-kpi ok"><span>OT (from scans)</span><b>' + hrs(ot) + '</b><small>hours</small></div>' +
            (cnt(function (r) { return r.status === 'unseen'; }) ? '<div class="hw-kpi" title="In Employee Directory as Active, but no scans in the last 30 days — probably resigned. Fix in Employee Directory → filter &quot;Not in scanner&quot;."><span>Not in scanner 30d</span><b class="mut">' + cnt(function (r) { return r.status === 'unseen'; }) + '</b><small>not counted · resigned?</small></div>' : '') +
            (cnt(function (r) { return r.unknown; }) ? '<div class="hw-kpi"><span>Unknown IDs</span><b>' + cnt(function (r) { return r.unknown; }) + '</b><small>not in Employee Directory</small></div>' : '');

        var chips = [['', 'All'], ['ok', 'On time'], ['late', 'Late'], ['early', 'Early out'], ['noout', 'No OUT scan'], ['working', 'No OUT yet'], ['noscan', 'No scan'], ['pending', 'No scan yet'], ['leave', 'Leave'], ['night', 'Night shift'], ['ot', 'Has OT'], ['otnoreq', 'OT without request'], ['unknown', 'Unknown ID'], ['unseen', 'Not in scanner 30d']];
        $('dChips').innerHTML = chips.map(function (c) {
            var n = c[0] ? all.filter(function (r) { return dayFilter(r, c[0]); }).length : all.filter(function (r) { return r.status !== 'unseen'; }).length;
            return n || !c[0] || D.st === c[0] ? '<span class="hw-chip' + (D.st === c[0] ? ' on' : '') + '" data-st="' + c[0] + '">' + c[1] + '<em>' + n + '</em></span>' : '';
        }).join('');
        deptOptions('dDept', all, D.dept);

        markSort('tab-day', D.sort, D.desc);
        var list = sortRows(all.filter(function (r) { return match(r, D.q, D.dept) && (D.st ? dayFilter(r, D.st) : r.status !== 'unseen'); }), D.sort, D.desc);
        $('dBody').innerHTML = list.map(function (r) {
            return '<tr data-scan="' + esc(r.scan) + '" class="' + (r.status === 'off' || r.status === 'unseen' ? 'ta-off' : '') + '"><td class="emp-code">' + esc(r.code || '–') + '</td>' + nameCell(r) +
                '<td>' + esc(r.dept) + '</td><td>' + shBadge(r) + '</td>' +
                '<td class="c ta-t">' + esc(r['in'] || '') + '</td><td class="c ta-t">' + esc(r.out || '') + '</td>' +
                '<td class="c">' + (r.late ? '<b class="ta-c-late">' + r.late + "'</b>" : '') + '</td>' +
                '<td class="c">' + (r.early ? '<b class="ta-c-early">' + r.early + "'</b>" : '') + '</td>' +
                '<td class="c">' + hm(r.work) + '</td><td class="c">' + otCell(r, hm) + '</td>' +
                '<td>' + (r.status === 'leave' ? '' : stBadge(r.status, r.unknown)) + leaveBadge(r) + '</td></tr>';
        }).join('') || '<tr><td colspan="11" class="hw-empty">' + (all.length ? 'No match' : 'No scanner data for this date — import the scanner file first (Import tab)') + '</td></tr>';
        msg('dMsg', (D.q || D.dept || D.st) ? 'Showing ' + list.length + ' of ' + all.length : '');
    }
    function dayFilter(r, st) {
        if (st === 'night') return r.shift && isNight(r.shift);
        if (st === 'ot') return r.ot > 0;
        if (st === 'otnoreq') return !!r.otNoReq;
        if (st === 'leave') return !!r.leave;
        if (st === 'unknown') return !!r.unknown;
        if (st === 'late') return r.late > 0;
        return r.status === st;
    }
    $('dDate').onchange = function () { if (this.value) loadDay(this.value); };
    $('dPrev').onclick = function () { loadDay(addDays(S.day.date, -1)); };
    $('dNext').onclick = function () { loadDay(addDays(S.day.date, 1)); };
    $('dQ').oninput = function () { S.day.q = this.value.trim(); renderDay(); };
    $('dDept').onchange = function () { S.day.dept = this.value; renderDay(); };
    $('dChips').onclick = function (e) { var c = e.target.closest('[data-st]'); if (c) { S.day.st = c.getAttribute('data-st'); renderDay(); } };
    document.querySelector('#tab-day thead').onclick = function (e) {
        var th = e.target.closest('th[data-k]'); if (!th) return; var k = th.getAttribute('data-k');
        if (S.day.sort === k) S.day.desc = !S.day.desc; else { S.day.sort = k; S.day.desc = false; } renderDay();
    };
    $('dBody').onclick = function (e) {
        var tr = e.target.closest('tr[data-scan]'); if (!tr) return;
        var d = pd(S.day.date); openPerson(tr.getAttribute('data-scan'), iso(new Date(d.getFullYear(), d.getMonth(), 1)), S.day.date);
    };

    // ================= Summary =================
    function monthRange(offset) {
        var t = pd(S.today), a = new Date(t.getFullYear(), t.getMonth() + offset, 1), b = new Date(t.getFullYear(), t.getMonth() + offset + 1, 0);
        return [iso(a), iso(b > t ? t : b)];
    }
    function loadSum() {
        var a = $('sFrom').value, b = $('sTo').value;
        if (!a || !b) return;
        S.sum.loaded = true;
        $('sCsv').href = API + '?format=csv&from=' + a + '&to=' + b;
        $('sBody').innerHTML = '<tr><td colspan="14" class="hw-empty">Loading…</td></tr>';
        return get('format=month&from=' + a + '&to=' + b).then(function (d) { S.sum.rows = d.rows; renderSum(); })
            .catch(function (e) { msg('sMsg', e.message, true); $('sBody').innerHTML = ''; });
    }
    function renderSum() {
        var all = S.sum.rows, U = S.sum;
        var sum = function (k) { return all.reduce(function (s, r) { return s + (r[k] || 0); }, 0); };
        $('sKpis').innerHTML =
            '<div class="hw-kpi acc"><span>Employees scanning</span><b>' + all.filter(function (r) { return !r.unknown && !r.unseen; }).length + '</b></div>' +
            '<div class="hw-kpi bad"><span>No-scan days</span><b>' + sum('noScan') + '</b></div>' +
            '<div class="hw-kpi"><span>Late (times)</span><b class="ta-c-late">' + sum('lateCount') + '</b><small>' + hm(sum('lateMin')) + ' h total</small></div>' +
            '<div class="hw-kpi"><span>No OUT scan</span><b class="ta-c-noout">' + sum('noOut') + '</b></div>' +
            '<div class="hw-kpi"><span>Leave days</span><b>' + hrs(sum('leaveDays') * 60) + '</b><small>approved</small></div>' +
            '<div class="hw-kpi"><span>OT (from scans)</span><b>' + hrs(sum('ot')) + '</b><small>hours</small></div>' +
            '<div class="hw-kpi ok"><span>OT payable</span><b>' + hrs(sum('otPay')) + '</b><small>approved request ∩ scan</small></div>' +
            '<div class="hw-kpi"><span>OT without request</span><b class="ta-c-late">' + hrs(sum('otNoReq')) + '</b><small>hours</small></div>';
        deptOptions('sDept', all, U.dept);
        markSort('tab-sum', U.sort, U.desc);
        var unseen = all.filter(function (r) { return r.unseen; }).length;
        var list = sortRows(all.filter(function (r) { return match(r, U.q, U.dept) && (U.showUnseen || !r.unseen); }), U.sort, U.desc);
        var z = function (v, cls) { return v ? (cls ? '<b class="' + cls + '">' + v + '</b>' : v) : '<span class="mut">·</span>'; };
        $('sBody').innerHTML = list.map(function (r) {
            return '<tr data-scan="' + esc(r.scan) + '"><td class="emp-code">' + esc(r.code || '–') + '</td>' + nameCell(r) + '<td>' + esc(r.dept) + (r.unknown ? ' <span class="ta-st unk">Unknown ID</span>' : '') + (r.unseen ? ' <span class="ta-st off">Not in scanner 30d</span>' : '') + '</td>' +
                '<td class="c">' + r.days + (r.workDays ? '<small class="mut"> / ' + r.workDays + '</small>' : '') + '</td>' +
                '<td class="c">' + z(r.noScan, 'ta-c-nos') + '</td><td class="c">' + z(r.lateCount, 'ta-c-late') + '</td><td class="c">' + z(r.lateMin) + '</td>' +
                '<td class="c">' + z(r.earlyCount, 'ta-c-early') + '</td><td class="c">' + z(r.noOut, 'ta-c-noout') + '</td><td class="c">' + z(r.night) + '</td>' +
                '<td class="c" title="' + ['S', 'P', 'V', 'O', 'A', 'L'].filter(function (t) { return r['lv' + t]; }).map(function (t) { return t + ' ' + r['lv' + t]; }).join(' · ') + '">' +
                    z(r.leaveDays ? Math.round(r.leaveDays * 10) / 10 : 0) + (r.lvA ? ' <b class="ta-c-nos" title="Absence">A' + r.lvA + '</b>' : '') + '</td>' +
                '<td class="c">' + hrs(r.work) + '</td><td class="c">' + (r.ot ? '<b class="ta-c-ot">' + hrs(r.ot) + '</b>' : '') + '</td>' +
                '<td class="c">' + (r.otPay ? '<b class="ta-c-ot">' + hrs(r.otPay) + '</b>' : '') + (r.otNoReq ? '<small class="ta-otreq no">' + hrs(r.otNoReq) + ' no req</small>' : '') + '</td></tr>';
        }).join('') || '<tr><td colspan="14" class="hw-empty">No data</td></tr>';
        msg('sMsg', (U.q || U.dept ? 'Showing ' + list.length + ' of ' + all.length + ' · ' : '') + 'Days worked = days with scans / work days that have scanner data · hours in decimal (7.5 = 7 h 30 m)');
        $('sUnseen').style.display = unseen ? '' : 'none';
        $('sUnseen').textContent = (U.showUnseen ? 'Hide' : 'Show') + ' ' + unseen + ' not in scanner';
    }
    $('sFrom').onchange = $('sTo').onchange = loadSum;
    $('sThis').onclick = function () { var r = monthRange(0); $('sFrom').value = r[0]; $('sTo').value = r[1]; loadSum(); };
    $('sLast').onclick = function () { var r = monthRange(-1); $('sFrom').value = r[0]; $('sTo').value = r[1]; loadSum(); };
    $('sUnseen').onclick = function () { S.sum.showUnseen = !S.sum.showUnseen; renderSum(); };
    $('sQ').oninput = function () { S.sum.q = this.value.trim(); renderSum(); };
    $('sDept').onchange = function () { S.sum.dept = this.value; renderSum(); };
    document.querySelector('#tab-sum thead').onclick = function (e) {
        var th = e.target.closest('th[data-k]'); if (!th) return; var k = th.getAttribute('data-k');
        if (S.sum.sort === k) S.sum.desc = !S.sum.desc; else { S.sum.sort = k; S.sum.desc = k !== 'code' && k !== 'name' && k !== 'dept'; } renderSum();
    };
    $('sBody').onclick = function (e) { var tr = e.target.closest('tr[data-scan]'); if (tr) openPerson(tr.getAttribute('data-scan'), $('sFrom').value, $('sTo').value); };

    // ================= รายคน =================
    function openPerson(scan, from, to) {
        S.person = { scan: scan }; $('pFrom').value = from; $('pTo').value = to;
        $('pTitle').textContent = 'Scanner ID ' + scan; $('pSess').innerHTML = ''; $('pPunch').innerHTML = 'Loading…'; $('pNo').innerHTML = '';
        $('aAt').value = to + 'T' + (S.cfg ? S.cfg.Shifts[0].End : '17:00'); $('aNote').value = ''; msg('pMsg', '');
        $('pBack').classList.add('show'); loadPerson();
    }
    function loadPerson() {
        var p = S.person; if (!p) return;
        return get('format=person&scan=' + encodeURIComponent(p.scan) + '&from=' + $('pFrom').value + '&to=' + $('pTo').value).then(function (d) {
            var e = d.emp;
            $('pTitle').innerHTML = e ? esc(e.code) + ' · ' + esc(e.name) + (e.nick ? ' (' + esc(e.nick) + ')' : '') + ' <small class="mut">' + esc(e.dept) + ' · scanner ID ' + esc(d.scan) + '</small>'
                                      : 'Scanner ID ' + esc(d.scan) + ' <span class="ta-st unk">not in Employee Directory</span>';
            $('pSess').innerHTML = d.sessions.map(function (s) {
                return '<tr><td>' + fd(s.date) + ' <small class="mut">' + ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'][pd(s.date).getDay()] + '</small></td><td>' + shBadge(s) + '</td>' +
                    '<td class="c ta-t">' + esc(s['in']) + '</td><td class="c ta-t">' + esc(s.out) + '</td>' +
                    '<td class="c">' + (s.late ? '<b class="ta-c-late">' + s.late + "'</b>" : '') + '</td><td class="c">' + (s.early ? '<b class="ta-c-early">' + s.early + "'</b>" : '') + '</td>' +
                    '<td class="c">' + hm(s.work) + '</td><td class="c">' + (s.ot ? '<b class="ta-c-ot">' + hm(s.ot) + '</b>' : '') + '</td><td>' + stBadge(s.status) + '</td></tr>';
            }).join('') || '<tr><td colspan="9" class="hw-empty">No scans in this range</td></tr>';
            $('pNo').innerHTML = d.noScan.length ? '<b>No scan (' + d.noScan.length + ' days):</b> ' + d.noScan.map(fd).join(', ') : '';
            $('pPunch').innerHTML = d.punches.map(function (x) {
                return '<div class="' + (x.isVoid ? 'void' : '') + '"><span class="ta-t">' + fd(x.at.slice(0, 10)) + ' <b>' + x.at.slice(11) + '</b></span>' +
                    '<span class="ta-src ' + x.source + '">' + (x.source === 'manual' ? 'manual · ' + esc(x.by) : 'scanner') + '</span>' +
                    '<span class="ta-note">' + esc(x.note) + '</span>' +
                    (S.me.canEdit ? '<button type="button" class="rowbtn" data-void="' + x.id + '" data-v="' + (x.isVoid ? 0 : 1) + '">' + (x.isVoid ? 'Restore' : x.source === 'manual' ? 'Delete' : 'Ignore') + '</button>' : '') + '</div>';
            }).join('') || '<div class="mut">No scans</div>';
        }).catch(function (e) { msg('pMsg', e.message, true); });
    }
    $('pFrom').onchange = $('pTo').onchange = loadPerson;
    $('pClose').onclick = function () { $('pBack').classList.remove('show'); S.person = null; };
    function afterEdit() { return Promise.all([loadPerson(), S.day.date ? loadDay(S.day.date) : null, S.sum.loaded ? loadSum() : null]); }
    $('pPunch').onclick = function (e) {
        var b = e.target.closest('[data-void]'); if (!b) return;
        var v = b.getAttribute('data-v') === '1', note = '';
        if (v) { note = prompt('Reason for ignoring this scan (e.g. scanned twice / wrong person)'); if (note === null) return; }
        post('punchvoid', { id: +b.getAttribute('data-void'), 'void': v, note: note }).then(afterEdit).catch(function (er) { msg('pMsg', er.message, true); });
    };
    $('aGo').onclick = function () {
        var at = $('aAt').value, note = $('aNote').value.trim();
        if (!at) { msg('pMsg', 'Choose date & time', true); return; }
        if (!note) { msg('pMsg', 'Reason is required', true); $('aNote').focus(); return; }
        post('punchadd', { scan: S.person.scan, at: at.replace('T', ' ').slice(0, 16), note: note })
            .then(function () { $('aNote').value = ''; msg('pMsg', 'Added ✓'); return afterEdit(); }).catch(function (er) { msg('pMsg', er.message, true); });
    };

    // ================= Shift plan (เปลี่ยนกะ) =================
    function loadPlan() {
        var d = $('kDate').value || S.today; $('kDate').value = d; S.plan.loaded = true;
        $('kBody').innerHTML = '<tr><td colspan="10" class="hw-empty">Loading…</td></tr>';
        return get('format=plan&date=' + d).then(function (x) { S.plan.rows = x.rows; renderPlan(); }).catch(function (e) { msg('kMsg', e.message, true); });
    }
    function planShown() {
        var K = S.plan;
        return sortRows(K.rows.filter(function (r) {
            if (K.group && (r.group || '(none)') !== K.group) return false;
            if (K.shift !== null && (r.shift || '') !== K.shift) return false;
            return match(r, K.q, K.dept);
        }), K.sort, K.desc);
    }
    function renderPlan() {
        var K = S.plan, all = K.rows;
        var by = {}; all.forEach(function (r) { var k = r.shift || ''; by[k] = (by[k] || 0) + 1; });
        var chips = '<span class="hw-chip' + (K.shift === null ? ' on' : '') + '" data-sh="*">All<em>' + all.length + '</em></span>';
        (S.cfg ? S.cfg.Shifts : []).forEach(function (sh) {
            chips += '<span class="hw-chip' + (K.shift === sh.Code ? ' on' : '') + '" data-sh="' + esc(sh.Code) + '" title="' + esc(sh.Start + '-' + sh.End) + '">' + esc(sh.Name) + '<em>' + (by[sh.Code] || 0) + '</em></span>';
        });
        chips += '<span class="hw-chip' + (K.shift === '' ? ' on' : '') + '" data-sh="" title="No shift plan — system guesses the shift from scan time">No plan<em>' + (by[''] || 0) + '</em></span>';
        $('kChips').innerHTML = chips;
        deptOptions('kDept', all, K.dept);
        var g = {}; all.forEach(function (r) { var k = r.group || '(none)'; g[k] = (g[k] || 0) + 1; });
        $('kGroup').innerHTML = '<option value="">All groups</option>' + Object.keys(g).sort().map(function (k) { return '<option value="' + esc(k) + '"' + (K.group === k ? ' selected' : '') + '>' + esc(k) + ' (' + g[k] + ')</option>'; }).join('');
        markSort('tab-plan', K.sort, K.desc);
        var list = planShown();
        $('kBody').innerHTML = list.map(function (r) {
            var on = !!K.sel[r.code];
            return '<tr data-code="' + esc(r.code) + '"' + (on ? ' class="ta-selrow"' : '') + '><td class="c edit-only"><input type="checkbox" data-sel="' + esc(r.code) + '"' + (on ? ' checked' : '') + '></td>' +
                '<td class="emp-code">' + esc(r.code) + '</td>' + nameCell(r) + '<td>' + esc(r.dept) + '</td><td>' + esc(r.group) + '</td>' +
                '<td>' + (r.shift ? '<span class="ta-sh' + (isNight(r.shift) ? ' ta-sh-N' : '') + '">' + esc(r.shiftName) + '</span> <small class="mut">' + esc(r.shiftTime) + '</small>'
                                  : '<span class="ta-noplan">' + (r.shiftName || 'No plan (auto)') + '</span>') + '</td>' +
                '<td>' + fd(r.from) + '</td><td>' + (r.to ? fd(r.to) + '<span class="ta-tmp">temporary</span>' : '') + '</td>' +
                '<td>' + (r.next ? fd(r.next) + ' → <b>' + esc(r.nextName) + '</b>' : '') + '</td>' +
                '<td><button type="button" class="rowbtn" data-hist="' + esc(r.code) + '">History' + (r.changes ? ' (' + r.changes + ')' : '') + '</button></td></tr>';
        }).join('') || '<tr><td colspan="10" class="hw-empty">No employees</td></tr>';
        var n = Object.keys(K.sel).length;
        $('kSel').textContent = n + ' selected';
        $('kChkAll').checked = list.length > 0 && list.every(function (r) { return K.sel[r.code]; });
        msg('kMsg', 'Showing ' + list.length + ' of ' + all.length + ' · shift as of ' + fd($('kDate').value) + ' · tick people, choose shift + From date, then Change shift');
    }
    function fillShiftSelect() {
        $('kShift').innerHTML = (S.cfg ? S.cfg.Shifts : []).map(function (sh) { return '<option value="' + esc(sh.Code) + '">' + esc(sh.Name + ' (' + sh.Start + '-' + sh.End + ')') + '</option>'; }).join('');
        if (!$('kFrom').value) $('kFrom').value = S.today;
    }
    $('kDate').onchange = loadPlan;
    $('kQ').oninput = function () { S.plan.q = this.value.trim(); renderPlan(); };
    $('kDept').onchange = function () { S.plan.dept = this.value; renderPlan(); };
    $('kGroup').onchange = function () { S.plan.group = this.value; renderPlan(); };
    $('kChips').onclick = function (e) { var c = e.target.closest('[data-sh]'); if (!c) return; var v = c.getAttribute('data-sh'); S.plan.shift = v === '*' ? null : v; renderPlan(); };
    document.querySelector('#tab-plan thead').onclick = function (e) {
        var th = e.target.closest('th[data-k]'); if (!th) return; var k = th.getAttribute('data-k');
        if (S.plan.sort === k) S.plan.desc = !S.plan.desc; else { S.plan.sort = k; S.plan.desc = false; } renderPlan();
    };
    $('kChkAll').onchange = function () { var on = this.checked; planShown().forEach(function (r) { if (on) S.plan.sel[r.code] = 1; else delete S.plan.sel[r.code]; }); renderPlan(); };
    $('kAll').onclick = function () { planShown().forEach(function (r) { S.plan.sel[r.code] = 1; }); renderPlan(); };
    $('kNone').onclick = function () { S.plan.sel = {}; renderPlan(); };
    $('kBody').onclick = function (e) {
        var h = e.target.closest('[data-hist]'); if (h) { openHist(h.getAttribute('data-hist')); return; }
        if (!S.me.canEdit) return;
        var tr = e.target.closest('tr[data-code]'); if (!tr) return;
        var code = tr.getAttribute('data-code');
        if (S.plan.sel[code]) delete S.plan.sel[code]; else S.plan.sel[code] = 1;
        renderPlan();
    };
    $('kGo').onclick = function () {
        var codes = Object.keys(S.plan.sel), sh = $('kShift').value, from = $('kFrom').value, to = $('kTo').value;
        if (!codes.length) { msg('kMsg', 'Tick the employees first', true); return; }
        if (!from) { msg('kMsg', 'Choose the From date', true); return; }
        if (to && to < from) { msg('kMsg', 'Until must be on or after From', true); return; }
        var name = $('kShift').options[$('kShift').selectedIndex].text;
        if (!confirm('Change ' + codes.length + ' employees to ' + name + '\nfrom ' + fd(from) + (to ? ' until ' + fd(to) + ' (temporary, then back to their previous shift)' : ' onward (permanent)') + '?')) return;
        msg('kMsg', 'Saving…');
        post('planadd', { codes: codes, shift: sh, from: from, to: to, note: $('kNote').value.trim() }).then(function (d) {
            S.plan.sel = {}; $('kNote').value = ''; $('kTo').value = '';
            S.sum.loaded = false;
            return Promise.all([loadPlan(), S.day.date ? loadDay(S.day.date) : null]).then(function () { msg('kMsg', 'Changed shift for ' + d.added + ' employees ✓ — attendance is recalculated'); });
        }).catch(function (e) { msg('kMsg', e.message, true); });
    };
    function openHist(code) {
        S.hist = code; $('hTitle').textContent = 'Shift history · ' + code; $('hBody').innerHTML = '<tr><td colspan="6">Loading…</td></tr>'; msg('hMsg', '');
        $('hBack').classList.add('show');
        get('format=planhist&code=' + encodeURIComponent(code)).then(function (d) {
            $('hBody').innerHTML = d.rows.map(function (x) {
                return '<tr><td><b>' + esc(x.shiftName) + '</b></td><td>' + fd(x.from) + '</td><td>' + (x.to ? fd(x.to) + '<span class="ta-tmp">temporary</span>' : '<span class="mut">until changed</span>') + '</td>' +
                    '<td class="rm">' + esc(x.note) + '</td><td><small>' + esc(x.by) + '<br>' + esc(x.at) + '</small></td>' +
                    '<td class="edit-only"><button type="button" class="rowbtn" data-pdel="' + x.id + '">Delete</button></td></tr>';
            }).join('') || '<tr><td colspan="6" class="hw-empty">No shift plan — system guesses the shift from scan time</td></tr>';
        }).catch(function (e) { msg('hMsg', e.message, true); });
    }
    $('hBody').onclick = function (e) {
        var b = e.target.closest('[data-pdel]'); if (!b || !confirm('Delete this shift plan entry?')) return;
        post('plandelete', { id: +b.getAttribute('data-pdel') }).then(function () { S.sum.loaded = false; openHist(S.hist); loadPlan(); if (S.day.date) loadDay(S.day.date); })
            .catch(function (er) { msg('hMsg', er.message, true); });
    };
    $('hClose').onclick = function () { $('hBack').classList.remove('show'); };

    // ================= Import =================
    $('iFile').onchange = function () {
        var f = this.files[0]; if (!f) return;
        if (f.size > 2 * 1024 * 1024) { msg('iMsg', 'File too large (max 2 MB) — export a shorter date range', true); return; }
        var rd = new FileReader();
        rd.onload = function () { S.imp = { name: f.name, data: rd.result }; runImport(false); };
        rd.readAsDataURL(f);
    };
    function runImport(commit) {
        msg('iMsg', commit ? 'Importing…' : 'Checking file…'); $('iGo').disabled = true;
        post('import', { name: S.imp.name, data: S.imp.data, commit: commit }).then(function (d) {
            $('iSum').innerHTML = (commit ? '✓ Imported <span class="act add">' + d.added + ' new scans</span>' :
                'File : ' + fd(d.from) + ' – ' + fd(d.to) + ' · ' + d.people + ' people · ' + d.total + ' scans → <span class="act add">new ' + d.fresh + '</span> <span class="act same">already in system ' + d.existing + '</span>') +
                (d.warnings.length ? '<div class="ta-warn">' + d.warnings.map(esc).join('<br>') + '</div>' : '');
            $('iDays').innerHTML = d.perDay.map(function (x) { return '<tr><td>' + fd(x.date) + ' <small class="mut">' + DOW[pd(x.date).getDay()] + '</small></td><td class="c">' + x.people + '</td><td class="c">' + x.punches + '</td><td class="c">' + (x.fresh || '·') + '</td></tr>'; }).join('');
            $('iUnkN').textContent = '(' + d.unknown.length + ')';
            $('iUnk').innerHTML = d.unknown.length ? d.unknown.map(function (u) { return '<span><b>' + esc(u.scan) + '</b> ' + esc(u.name) + ' <small>' + esc(u.dept) + '</small></span>'; }).join('') +
                '<p class="mut">These scans are still saved. Add the person in Employee Directory with the matching code (e.g. ID 104 → U-0104) and they appear automatically.</p>' : '<span class="ok">All IDs match the Employee Directory ✓</span>';
            $('iGrid').style.display = '';
            $('iGo').disabled = commit || !d.fresh;
            msg('iMsg', commit ? 'Done — see the Daily tab' : d.fresh ? 'Check, then Confirm import' : 'Nothing new to import');
            if (commit) { var last = d.to; boot(last); }
        }).catch(function (e) { msg('iMsg', e.message, true); });
    }
    $('iGo').onclick = function () { if (S.imp) runImport(true); };

    // ================= Settings =================
    var DAYN = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    function renderSettings() {
        var c = S.cfg; if (!c) return;
        var ro = !S.me.canEdit;
        $('cShifts').innerHTML = c.Shifts.map(function (s, i) {
            return '<tr data-i="' + i + '"><td><input data-f="Code" value="' + esc(s.Code) + '" maxlength="4" size="3"></td><td><input data-f="Name" value="' + esc(s.Name) + '" maxlength="20"></td>' +
                '<td><input data-f="Start" type="time" value="' + esc(s.Start) + '"></td><td><input data-f="End" type="time" value="' + esc(s.End) + '"></td>' +
                '<td><input data-f="BreakMin" type="number" min="0" max="240" value="' + s.BreakMin + '" style="width:80px"></td>' +
                '<td><input data-f="OtBreakMin" type="number" min="0" max="240" value="' + (s.OtBreakMin == null ? 60 : s.OtBreakMin) + '" style="width:80px"></td>' +
                '<td class="mut" data-otfrom>' + otFrom(s) + '</td>' +
                '<td>' + (c.Shifts.length > 1 ? '<button type="button" class="rowbtn edit-only" data-del="' + i + '">Remove</button>' : '') + '</td></tr>';
        }).join('');
        ['GraceMin', 'OtRoundMin', 'OtMinMin', 'EarlyOtMin', 'SessionMaxHours', 'DupMin'].forEach(function (k) { $('c_' + k).value = c[k]; });
        var wd = (c.WorkDays || '').split(',');
        $('cDays').innerHTML = DAYN.map(function (n, i) { return '<label><input type="checkbox" value="' + i + '"' + (wd.indexOf(String(i)) >= 0 ? ' checked' : '') + '>' + n + '</label>'; }).join('');
        $('c_Holidays').value = (c.Holidays || []).join('\n');
        document.querySelectorAll('#tab-set input, #tab-set textarea').forEach(function (x) { x.disabled = ro; });
        msg('cMsg', ro ? 'View only' : 'ค่าเริ่มต้นเป็นค่าที่เดาจากไฟล์ตัวอย่าง (กะเช้า 08:00-17:00 · กะดึก 20:00-05:00) — แก้ให้ตรงกับบริษัทแล้วกด Save');
    }
    function readSettings() {
        var c = JSON.parse(JSON.stringify(S.cfg));
        c.Shifts = [].map.call(document.querySelectorAll('#cShifts tr'), function (tr) {
            var o = {}; tr.querySelectorAll('[data-f]').forEach(function (x) { o[x.getAttribute('data-f')] = x.type === 'number' ? +x.value : x.value.trim(); }); return o;
        });
        ['GraceMin', 'OtRoundMin', 'OtMinMin', 'EarlyOtMin', 'SessionMaxHours', 'DupMin'].forEach(function (k) { c[k] = +$('c_' + k).value || 0; });
        c.WorkDays = [].filter.call(document.querySelectorAll('#cDays input'), function (x) { return x.checked; }).map(function (x) { return x.value; }).join(',');
        c.Holidays = $('c_Holidays').value.split(/[\s,]+/).filter(Boolean);
        return c;
    }
    $('cAddShift').onclick = function () { S.cfg = readSettings(); S.cfg.Shifts.push({ Code: 'S' + (S.cfg.Shifts.length + 1), Name: 'Shift ' + (S.cfg.Shifts.length + 1), Start: '08:00', End: '17:00', BreakMin: 60, OtBreakMin: 60 }); renderSettings(); };
    // OT เริ่ม = เลิกกะ + พักก่อน OT · ตัวอย่าง 2 ชม.
    function otFrom(s) {
        var m = /^(\d{1,2}):(\d{2})$/.exec(s.End || ''); if (!m) return '';
        var a = +m[1] * 60 + +m[2] + (s.OtBreakMin == null ? 60 : +s.OtBreakMin || 0);
        function t(x) { x = ((x % 1440) + 1440) % 1440; return ('0' + Math.floor(x / 60)).slice(-2) + ':' + ('0' + x % 60).slice(-2); }
        return t(a) + ' – ' + t(a + 120) + ' (2 h)';
    }
    $('cShifts').oninput = function (e) {
        var tr = e.target.closest('tr[data-i]'); if (!tr) return;
        var o = {}; tr.querySelectorAll('[data-f]').forEach(function (x) { o[x.getAttribute('data-f')] = x.type === 'number' ? +x.value : x.value; });
        tr.querySelector('[data-otfrom]').textContent = otFrom(o);
    };
    $('cShifts').onclick = function (e) { var b = e.target.closest('[data-del]'); if (!b) return; S.cfg = readSettings(); S.cfg.Shifts.splice(+b.getAttribute('data-del'), 1); renderSettings(); };
    $('cSave').onclick = function () {
        var c = readSettings();
        var bad = c.Holidays.filter(function (h) { return !/^\d{4}-\d{2}-\d{2}$/.test(h); });
        if (bad.length) { msg('cMsg', 'Holiday format must be yyyy-mm-dd: ' + bad.join(', '), true); return; }
        msg('cMsg', 'Saving…');
        post('settings', { config: c }).then(function (d) { S.cfg = d.config; renderSettings(); fillShiftSelect(); S.plan.loaded = false; msg('cMsg', 'Saved ✓ — all days are recalculated with the new settings'); S.sum.loaded = false; if (S.day.date) loadDay(S.day.date); })
            .catch(function (e) { msg('cMsg', e.message, true); });
    };

    // ================= เริ่ม =================
    function boot(gotoDate) {
        return get('format=init').then(function (d) {
            S.me = d.me; S.cfg = d.config; S.today = d.today;
            root.classList.toggle('editing', !!S.me.canEdit);
            var date = gotoDate || (d.last && d.last < d.today ? d.last : d.today);
            if (!$('sFrom').value) { var p = pd(date); $('sFrom').value = iso(new Date(p.getFullYear(), p.getMonth(), 1)); $('sTo').value = date; }
            S.sum.loaded = false;
            if (S.tab === 'set') renderSettings();
            fillShiftSelect();
            if (S.tab === 'plan') loadPlan();
            if (!d.last && S.me.canEdit && !gotoDate) { showTab('imp'); $('help').style.display = ''; msg('iMsg', 'No scanner data yet — start by importing the scanner Excel file'); }
            else if (S.tab === 'sum') loadSum();
            return loadDay(date);
        }).catch(function (e) { msg('dMsg', 'Load failed: ' + e.message, true); });
    }
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') { $('pClose').onclick(); $('hClose').onclick(); } });
    var form1 = document.getElementById('form1'); if (form1) form1.addEventListener('submit', function (e) { e.preventDefault(); });
    var saved = null; try { saved = localStorage.getItem('ta.tab'); } catch (e) { }
    if (saved && saved !== 'imp') showTab(saved);
    boot();
})();
