// @ts-nocheck
// Maintenance.aspx — ระบบแจ้งซ่อม (แจ้ง → รับงาน → ซ่อมเสร็จ → ปิดงาน)
(function () {
    var API = location.pathname;
    var $ = function (id) { return document.getElementById(id); };
    var root = $('mt');
    var PROCS = JSON.parse(($('procJson') || {}).textContent || '[]');
    var ST = {
        open:   { th: 'รอรับงาน',   en: 'Open' },
        doing:  { th: 'กำลังซ่อม',  en: 'In progress' },
        done:   { th: 'ซ่อมเสร็จ รอปิด', en: 'Fixed' },
        closed: { th: 'ปิดงานแล้ว', en: 'Closed' },
        cancel: { th: 'ยกเลิก',     en: 'Cancelled' }
    };
    var CATS = [['Mechanical', 'เครื่องกล'], ['Electrical', 'ไฟฟ้า'], ['Pneumatic/Hydraulic', 'ลม / ไฮดรอลิก'], ['Mold', 'แม่พิมพ์'], ['Utility', 'สาธารณูปโภค'], ['Other', 'อื่นๆ']];
    var LATE_MIN = { open: 15, doing: 120, done: 240 };       // เกินกี่นาทีแสดงตัวแดง
    var qs = new URLSearchParams(location.search);
    var S = { tab: 'report', rows: [], machines: [], fStatus: 'active', q: '', pin: '', photos: [], cat: '', pri: 'normal', dash: null, range: '30', proc: 'All', qSel: {}, qCustom: [] };

    // ---------- ตัวช่วย ----------
    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function ls(k, v) { try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) { return null; } }
    function ss(k, v) { try { if (v === undefined) return sessionStorage.getItem(k); sessionStorage.setItem(k, v); } catch (e) { return null; } }
    function pt(s) { return s ? new Date(String(s).replace(' ', 'T')) : null; }
    function ymd(d) { return d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2); }
    function dm(s) { var d = pt(s); return d ? ('0' + d.getDate()).slice(-2) + '/' + ('0' + (d.getMonth() + 1)).slice(-2) + ' ' + ('0' + d.getHours()).slice(-2) + ':' + ('0' + d.getMinutes()).slice(-2) : '–'; }
    function dur(min) {
        if (min == null || isNaN(min)) return '–';
        min = Math.max(0, Math.round(min));
        if (min < 60) return min + ' นาที';
        var h = Math.floor(min / 60), m = min % 60;
        if (h < 24) return h + ' ชม.' + (m ? ' ' + m + ' นาที' : '');
        var d = Math.floor(h / 24); h = h % 24;
        return d + ' วัน' + (h ? ' ' + h + ' ชม.' : '');
    }
    function minsSince(s, now) { var d = pt(s); return d ? ((now || Date.now()) - d.getTime()) / 60000 : null; }
    function fmtN(v) { return v == null ? '–' : Math.round(v).toLocaleString('en-US'); }
    function api(fmt, body, qsx) {
        var opt = body ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) } : { cache: 'no-store' };
        return fetch(API + '?format=' + fmt + (qsx || '') + '&_=' + Date.now(), opt).then(function (r) {
            return r.json().catch(function () { throw new Error('HTTP ' + r.status); }).then(function (j) { if (!r.ok || j.ok === false) throw new Error(j.error || ('HTTP ' + r.status)); return j; });
        });
    }
    function stPill(s) { return '<span class="pill st-' + s + '"><i></i>' + (ST[s] ? ST[s].th : s) + '</span>'; }
    function catTh(c) { for (var i = 0; i < CATS.length; i++) if (CATS[i][0] === c) return CATS[i][1]; return c || ''; }
    function mcLabel(r) { return r.machineName || r.machine || '–'; }

    // ---------- แท็บ ----------
    function setTab(t) {
        S.tab = t;
        Array.prototype.forEach.call(document.querySelectorAll('#tabs button'), function (b) { b.classList.toggle('on', b.getAttribute('data-tab') === t); });
        ['report', 'jobs', 'dash', 'qr'].forEach(function (k) { $('p-' + k).hidden = k !== t; });
        var u = new URL(location.href); u.searchParams.set('tab', t); if (t !== 'report') { u.searchParams.delete('mc'); u.searchParams.delete('eq'); } history.replaceState(null, '', u);
        if (t === 'jobs') loadJobs();
        if (t === 'dash') { loadDash(); loadJobs(true); }
        if (t === 'qr') renderQr();
    }
    Array.prototype.forEach.call(document.querySelectorAll('#tabs button'), function (b) { b.onclick = function () { setTab(b.getAttribute('data-tab')); }; });

    // ================================================================ แจ้งซ่อม
    function loadMachines() {
        return api('machines').then(function (d) { S.machines = d.machines || []; fillMc(); renderQr(); }).catch(function (e) { S.machines = []; fillMc(); $('fMsg').textContent = 'โหลดรายชื่อเครื่องไม่ได้: ' + e.message; });
    }
    function mcGroups() {
        var g = {}, order = [];
        S.machines.forEach(function (m) { var p = m.process || 'Other'; if (!g[p]) { g[p] = []; order.push(p); } g[p].push(m); });
        order.sort(function (a, b) { var x = PROCS.indexOf(a), y = PROCS.indexOf(b); return (x < 0 ? 99 : x) - (y < 0 ? 99 : y) || a.localeCompare(b); });
        return order.map(function (p) { return { p: p, list: g[p].sort(function (a, b) { return String(a.name).localeCompare(String(b.name), undefined, { numeric: true }); }) }; });
    }
    function fillMc() {
        var sel = $('fMc'), cur = sel.value || qs.get('mc') || '';
        var h = '<option value="">— เลือกเครื่อง —</option>';
        mcGroups().forEach(function (g) { h += '<optgroup label="' + esc(g.p) + '">' + g.list.map(function (m) { return '<option value="' + esc(m.code) + '" data-p="' + esc(m.process) + '">' + esc(m.name) + (m.name !== m.code ? ' (' + esc(m.code) + ')' : '') + '</option>'; }).join('') + '</optgroup>'; });
        h += '<option value="__other">อื่นๆ / อุปกรณ์ที่ไม่มีในรายการ (พิมพ์เอง)</option>';
        sel.innerHTML = h;
        if (qs.get('eq')) { sel.value = '__other'; $('fMcName').value = qs.get('eq'); }
        else if (cur) { sel.value = cur; if (sel.value !== cur && cur !== '__other') { sel.value = '__other'; $('fMcName').value = cur; } }
        if (qs.get('loc')) $('fLoc').value = qs.get('loc');
        mcChanged();
    }
    function mcChanged() {
        var sel = $('fMc'), other = sel.value === '__other';
        $('fMcName').hidden = !other;
        var head = $('mcHead'), fromQr = qs.get('mc') || qs.get('eq');
        if (fromQr && (sel.value && sel.value !== '__other' || other && $('fMcName').value)) {
            var o = sel.options[sel.selectedIndex];
            head.innerHTML = '<span>แจ้งซ่อมเครื่อง (จาก QR)</span><b>' + esc(other ? $('fMcName').value : o.text) + '</b>' + (o && o.getAttribute('data-p') ? '<span>Process: ' + esc(o.getAttribute('data-p')) + '</span>' : '');
            head.hidden = false;
        } else head.hidden = true;
    }
    $('fMc').onchange = mcChanged;
    $('fCat').innerHTML = CATS.map(function (c) { return '<button type="button" data-v="' + c[0] + '">' + c[1] + '</button>'; }).join('');
    $('fCat').onclick = function (e) { var b = e.target.closest('button'); if (!b) return; S.cat = S.cat === b.getAttribute('data-v') ? '' : b.getAttribute('data-v'); Array.prototype.forEach.call(this.children, function (x) { x.classList.toggle('on', x.getAttribute('data-v') === S.cat); }); };
    $('fPri').onclick = function (e) { var b = e.target.closest('button'); if (!b) return; S.pri = b.getAttribute('data-v'); Array.prototype.forEach.call(this.children, function (x) { x.classList.toggle('on', x === b); }); };
    $('fRep').value = ls('mt.reporter') || '';

    // รูปถ่าย : ย่อเหลือด้านยาว 1280px JPEG ก่อนส่ง
    function shrink(file) {
        return new Promise(function (res, rej) {
            var fr = new FileReader();
            fr.onload = function () {
                var img = new Image();
                img.onload = function () {
                    var M = 1280, w = img.width, h = img.height, k = Math.min(1, M / Math.max(w, h));
                    var c = document.createElement('canvas'); c.width = Math.round(w * k); c.height = Math.round(h * k);
                    c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
                    res(c.toDataURL('image/jpeg', 0.8));
                };
                img.onerror = function () { rej(new Error('อ่านรูปไม่ได้')); };
                img.src = fr.result;
            };
            fr.onerror = function () { rej(new Error('อ่านไฟล์ไม่ได้')); };
            fr.readAsDataURL(file);
        });
    }
    function photoWidget(box, list, max) {
        function draw() {
            box.innerHTML = list.map(function (p, i) { return '<div class="ph"><img src="' + p + '" data-i="' + i + '" alt="" /><button type="button" data-del="' + i + '" title="ลบ">×</button></div>'; }).join('') +
                (list.length < max ? '<label class="add"><span>📷</span>ถ่าย / เลือกรูป<input type="file" accept="image/*" capture="environment" multiple hidden /></label>' : '');
            var inp = box.querySelector('input[type=file]');
            if (inp) inp.onchange = function () {
                var files = Array.prototype.slice.call(this.files, 0, max - list.length);
                Promise.all(files.map(shrink)).then(function (arr) { arr.forEach(function (x) { list.push(x); }); draw(); }).catch(function (e) { alert(e.message); });
            };
        }
        box.onclick = function (e) {
            var d = e.target.getAttribute('data-del'); if (d != null) { list.splice(+d, 1); draw(); return; }
            if (e.target.tagName === 'IMG') showImg(e.target.src);
        };
        draw();
        return draw;
    }
    var drawFPhotos = photoWidget($('fPhotos'), S.photos, 3);

    $('fSend').onclick = function () {
        var sel = $('fMc'), other = sel.value === '__other', o = sel.options[sel.selectedIndex];
        var body = {
            machine: other ? '' : sel.value, machineName: other ? $('fMcName').value.trim() : '', process: !other && o ? (o.getAttribute('data-p') || '') : '',
            location: $('fLoc').value.trim(), category: S.cat, problem: $('fProb').value.trim(), priority: S.pri, stop: $('fStop').checked,
            reporter: $('fRep').value.trim(), photos: S.photos
        };
        var m = $('fMsg'); m.className = 'msg err';
        if (!body.machine && !body.machineName) { m.textContent = 'กรุณาเลือกเครื่อง / พิมพ์ชื่ออุปกรณ์'; return; }
        if (!body.problem) { m.textContent = 'กรุณาใส่อาการเสีย'; $('fProb').focus(); return; }
        if (!body.reporter) { m.textContent = 'กรุณาใส่ชื่อผู้แจ้ง'; $('fRep').focus(); return; }
        ls('mt.reporter', body.reporter);
        var btn = this; btn.disabled = true; m.className = 'msg'; m.textContent = 'กำลังส่ง…';
        api('create', body).then(function (d) {
            $('fCard').hidden = true;
            $('fDone').hidden = false;
            $('fDone').innerHTML = '<div class="big">✅</div><h3>ส่งแจ้งซ่อมแล้ว · ' + esc(d.no) + '</h3><p>' + esc(body.machineName || (o ? o.text : '')) + '<br>งานเข้าคิวช่างซ่อมแล้ว' + (body.priority === 'urgent' ? ' (งานด่วน)' : '') + ' · ติดตามสถานะได้ที่แท็บ "งานซ่อม"</p>' +
                '<p><button type="button" class="mt-btn ghost" id="fAgain">แจ้งเครื่องอื่น</button> <button type="button" class="mt-btn" id="fView">ดูสถานะงานนี้</button></p>';
            $('fAgain').onclick = resetForm;
            $('fView').onclick = function () { resetForm(); setTab('jobs'); openJob(d.id); };
            loadJobs(true);
        }).catch(function (e) { m.className = 'msg err'; m.textContent = 'ส่งไม่สำเร็จ: ' + e.message; })
          .then(function () { btn.disabled = false; });
    };
    function resetForm() {
        $('fProb').value = ''; $('fStop').checked = false; S.photos.length = 0; drawFPhotos(); S.cat = ''; S.pri = 'normal';
        Array.prototype.forEach.call($('fCat').children, function (x) { x.classList.remove('on'); });
        Array.prototype.forEach.call($('fPri').children, function (x) { x.classList.toggle('on', x.getAttribute('data-v') === 'normal'); });
        $('fMsg').textContent = ''; $('fCard').hidden = false; $('fDone').hidden = true;
    }

    // ================================================================ งานซ่อม
    var FST = [['active', 'งานค้าง'], ['open', 'รอรับงาน'], ['doing', 'กำลังซ่อม'], ['done', 'รอปิดงาน'], ['closed', 'ปิดแล้ว'], ['cancel', 'ยกเลิก'], ['all', 'ทั้งหมด']];
    var today = new Date(), d30 = new Date(); d30.setDate(d30.getDate() - 30);
    $('jFrom').value = ymd(d30); $('jTo').value = ymd(today);
    var jobsBusy = false;
    function loadJobs(silent) {
        if (jobsBusy) return; jobsBusy = true;
        if (!silent && !S.rows.length) $('jobs').innerHTML = '<div class="empty">กำลังโหลด…</div>';
        api('list', null, '&from=' + $('jFrom').value + '&to=' + $('jTo').value).then(function (d) {
            S.rows = d.rows || []; S.now = pt(d.now) ? pt(d.now).getTime() : Date.now(); S.nowAt = Date.now();
            renderJobs(); renderOpenList();
            $('upd').textContent = 'อัปเดต ' + String(d.now).slice(11, 16);
        }).catch(function (e) { if (!silent) $('jobs').innerHTML = '<div class="empty">โหลดไม่ได้: ' + esc(e.message) + '</div>'; })
          .then(function () { jobsBusy = false; });
    }
    function nowMs() { return S.now ? S.now + (Date.now() - S.nowAt) : Date.now(); }
    function elapsed(r) {
        var now = nowMs();
        if (r.status === 'open') { var m = minsSince(r.created, now); return { t: 'รอ ' + dur(m), late: m > LATE_MIN.open }; }
        if (r.status === 'doing') { var m2 = minsSince(r.accepted || r.created, now); return { t: 'ซ่อมมา ' + dur(m2), late: m2 > LATE_MIN.doing }; }
        if (r.status === 'done') { var m3 = minsSince(r.done, now); return { t: 'รอปิด ' + dur(m3), late: m3 > LATE_MIN.done }; }
        if (r.status === 'closed') return { t: 'ใช้เวลา ' + dur(r.totalMin) };
        return { t: dm(r.closed) };
    }
    function matchQ(r) {
        if (!S.q) return true;
        var t = [r.no, r.machine, r.machineName, r.process, r.location, r.problem, r.reporter, r.technician, r.category].join(' ').toLowerCase();
        return S.q.toLowerCase().split(/\s+/).every(function (w) { return t.indexOf(w) >= 0; });
    }
    function renderJobs() {
        var cnt = { active: 0, all: 0 };
        S.rows.forEach(function (r) { cnt[r.status] = (cnt[r.status] || 0) + 1; cnt.all++; if (r.status === 'open' || r.status === 'doing' || r.status === 'done') cnt.active++; });
        $('bOpen').textContent = cnt.open ? cnt.open : '';
        $('jSt').innerHTML = FST.map(function (f) { return '<button type="button" data-v="' + f[0] + '"' + (S.fStatus === f[0] ? ' class="on"' : '') + '>' + f[1] + '<b>' + (cnt[f[0]] || 0) + '</b></button>'; }).join('');
        var list = S.rows.filter(function (r) { return (S.fStatus === 'all' || (S.fStatus === 'active' ? /^(open|doing|done)$/.test(r.status) : r.status === S.fStatus)) && matchQ(r); });
        var rank = { open: 0, doing: 1, done: 2, closed: 3, cancel: 4 };
        list.sort(function (a, b) { return (rank[a.status] - rank[b.status]) || ((b.priority === 'urgent') - (a.priority === 'urgent')) || (S.fStatus === 'active' ? a.id - b.id : b.id - a.id); });
        $('jobs').innerHTML = list.length ? list.map(jobCard).join('') : '<div class="empty">ไม่มีงานในสถานะนี้</div>';
    }
    function jobCard(r) {
        var el = elapsed(r);
        return '<div class="job st-' + r.status + (r.priority === 'urgent' ? ' urgent' : '') + '" data-id="' + r.id + '">' +
            '<div class="top"><span class="no">' + esc(r.no) + '</span>' + stPill(r.status) + (r.priority === 'urgent' ? '<span class="tag urg">ด่วน</span>' : '') + (r.stop ? '<span class="tag stop">เครื่องหยุด</span>' : '') + '<span style="margin-left:auto">' + dm(r.created) + '</span></div>' +
            '<div class="mc">' + esc(mcLabel(r)) + ' <small>' + esc(r.process || r.location || '') + '</small></div>' +
            '<div class="pb">' + esc(r.problem) + '</div>' +
            '<div class="bot">' + (r.category ? '<span class="tag cat">' + esc(catTh(r.category)) + '</span>' : '') + '<span>👤 ' + esc(r.reporter || '') + '</span>' + (r.technician ? '<span>🔧 ' + esc(r.technician) + '</span>' : '') +
            (r.photoBefore + r.photoAfter ? '<span>📷 ' + (r.photoBefore + r.photoAfter) + '</span>' : '') + '<span class="el' + (el.late ? ' late' : '') + '">' + esc(el.t) + '</span></div></div>';
    }
    $('jSt').onclick = function (e) { var b = e.target.closest('button'); if (!b) return; S.fStatus = b.getAttribute('data-v'); renderJobs(); };
    $('jQ').oninput = function () { S.q = this.value.trim(); renderJobs(); };
    $('jFrom').onchange = $('jTo').onchange = function () { loadJobs(); };
    $('jobs').onclick = function (e) { var c = e.target.closest('.job'); if (c) openJob(+c.getAttribute('data-id')); };

    // ---------- รายละเอียดงาน ----------
    function closeDlg() { $('dlg').hidden = true; var u = new URL(location.href); u.searchParams.delete('id'); history.replaceState(null, '', u); }
    $('dlg').onclick = function (e) { if (e.target === this) closeDlg(); };
    function showImg(src) { $('imgBig').src = src; $('imgDlg').hidden = false; }
    $('imgDlg').onclick = function () { this.hidden = true; };
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') { if (!$('imgDlg').hidden) $('imgDlg').hidden = true; else if (!$('dlg').hidden) closeDlg(); else if (S.tv) setTv(false); } });

    function openJob(id) {
        var u = new URL(location.href); u.searchParams.set('id', id); history.replaceState(null, '', u);
        $('dlg').hidden = false; $('dlgBox').innerHTML = '<div class="empty">กำลังโหลด…</div>';
        api('get', null, '&id=' + id).then(function (d) { renderJob(d.row, d.photos || []); })
            .catch(function (e) { $('dlgBox').innerHTML = '<button type="button" class="x">×</button><div class="empty">' + esc(e.message) + '</div>'; $('dlgBox').querySelector('.x').onclick = closeDlg; });
    }
    function step(label, at, on, extra, st) {
        return '<div class="' + (on ? 'on ' : '') + 'st-' + st + '"><b>' + label + '</b>' + (at ? dm(at) : '–') + (extra ? '<em>' + extra + '</em>' : '') + '</div>';
    }
    function renderJob(r, photos) {
        var before = photos.filter(function (p) { return p.kind === 'before'; }), after = photos.filter(function (p) { return p.kind === 'after'; });
        var ph = function (list) { return '<div class="photos">' + list.map(function (p) { return '<div class="ph"><img src="' + API + '?format=photo&id=' + p.id + '" alt="" loading="lazy" /></div>'; }).join('') + '</div>'; };
        var h = '<button type="button" class="x" title="ปิด">×</button>' +
            '<h3>' + esc(mcLabel(r)) + '</h3>' +
            '<div class="sub"><b>' + esc(r.no) + '</b>' + stPill(r.status) + (r.priority === 'urgent' ? '<span class="tag urg">ด่วน</span>' : '') + (r.stop ? '<span class="tag stop">เครื่องหยุด</span>' : '') + (r.category ? '<span class="tag cat">' + esc(catTh(r.category)) + '</span>' : '') + '</div>' +
            '<div class="tl">' +
                step('แจ้งซ่อม', r.created, true, esc(r.reporter || ''), 'open') +
                step('รับงาน', r.accepted, !!r.accepted, r.waitMin != null ? 'รอ ' + dur(r.waitMin) : (r.status === 'open' ? 'รอ ' + dur(minsSince(r.created, nowMs())) : ''), 'doing') +
                step('ซ่อมเสร็จ', r.done, !!r.done, r.repairMin != null ? 'ซ่อม ' + dur(r.repairMin) : (r.status === 'doing' ? 'ซ่อมมา ' + dur(minsSince(r.accepted, nowMs())) : ''), 'done') +
                step(r.status === 'cancel' ? 'ยกเลิก' : 'ปิดงาน', r.closed, !!r.closed, r.closedBy ? esc(r.closedBy) : (r.totalMin != null ? 'รวม ' + dur(r.totalMin) : ''), r.status === 'cancel' ? 'cancel' : 'closed') +
            '</div>' +
            '<dl class="info">' +
                '<dt>เครื่อง</dt><dd>' + esc(mcLabel(r)) + (r.machine && r.machine !== r.machineName ? ' (' + esc(r.machine) + ')' : '') + (r.process ? ' · ' + esc(r.process) : '') + '</dd>' +
                (r.location ? '<dt>ตำแหน่ง</dt><dd>' + esc(r.location) + '</dd>' : '') +
                '<dt>อาการเสีย</dt><dd>' + esc(r.problem) + '</dd>' +
                '<dt>ผู้แจ้ง</dt><dd>' + esc(r.reporter) + ' · ' + dm(r.created) + '</dd>' +
                (r.technician ? '<dt>ช่าง</dt><dd>' + esc(r.technician) + '</dd>' : '') +
                (r.cause ? '<dt>สาเหตุ</dt><dd>' + esc(r.cause) + '</dd>' : '') +
                (r.action ? '<dt>วิธีแก้ไข</dt><dd>' + esc(r.action) + '</dd>' : '') +
                (r.closeNote ? '<dt>หมายเหตุ</dt><dd>' + esc(r.closeNote) + '</dd>' : '') +
            '</dl>' +
            (before.length ? '<h4>📷 รูปตอนแจ้ง</h4>' + ph(before) : '') +
            (after.length ? '<h4>📷 รูปหลังซ่อม</h4>' + ph(after) : '') +
            actionBox(r);
        $('dlgBox').innerHTML = h;
        $('dlgBox').querySelector('.x').onclick = closeDlg;
        Array.prototype.forEach.call($('dlgBox').querySelectorAll('.photos img'), function (im) { im.onclick = function () { showImg(im.src); }; });
        wireActions(r);
    }
    function pinRow() { return S.pin ? '' : '<div><label>รหัสช่าง (PIN)</label><input type="password" id="aPin" autocomplete="off" /></div>'; }
    function actionBox(r) {
        var tech = ls('mt.tech') || '', me = ls('mt.reporter') || '';
        if (r.status === 'open') return '<div class="actbox"><div class="two"><div><label>ชื่อช่างที่รับงาน</label><input type="text" id="aTech" value="' + esc(tech) + '" placeholder="ชื่อช่าง (หลายคนคั่นด้วย ,)" /></div>' + pinRow() + '</div>' +
            '<div class="btns"><span class="msg" id="aMsg"></span><button type="button" class="mt-btn red" id="aCancel">ยกเลิกใบแจ้ง</button><button type="button" class="mt-btn amber big" id="aAccept">🔧 รับงาน</button></div></div>';
        if (r.status === 'doing') return '<div class="actbox"><div class="row"><label>สาเหตุ</label><textarea id="aCause" rows="2" placeholder="เช่น ลูกปืนแตก, สายไฟหลวม"></textarea></div>' +
            '<div class="row"><label>วิธีแก้ไข / สิ่งที่ทำ *</label><textarea id="aAct" rows="2" placeholder="เช่น เปลี่ยนลูกปืน 6204, ขันสายใหม่"></textarea></div>' +
            '<div class="row"><label>รูปหลังซ่อม (ไม่เกิน 3 รูป)</label><div class="photos" id="aPhotos"></div></div>' +
            '<div class="two"><div><label>ชื่อช่าง</label><input type="text" id="aTech" value="' + esc(r.technician || tech) + '" /></div>' + pinRow() + '</div>' +
            '<div class="btns"><span class="msg" id="aMsg"></span><button type="button" class="mt-btn red" id="aCancel">ยกเลิก</button><button type="button" class="mt-btn big" id="aDone">✅ ซ่อมเสร็จ</button></div></div>';
        if (r.status === 'done') return '<div class="actbox"><p class="note" style="margin-top:0">ผู้แจ้ง / หัวหน้างาน ตรวจเครื่องแล้วกดยืนยันปิดงาน · ถ้ายังไม่หาย กดส่งกลับให้ช่างซ่อมต่อ</p>' +
            '<div class="two"><div><label>ชื่อผู้ตรวจรับ</label><input type="text" id="aBy" value="' + esc(me) + '" /></div><div><label>หมายเหตุ (ถ้ามี)</label><input type="text" id="aNote" placeholder="ถ้ายังไม่หาย บอกอาการที่นี่" /></div></div>' +
            '<div class="btns"><span class="msg" id="aMsg"></span><button type="button" class="mt-btn red" id="aReopen">↩ ยังไม่หาย ส่งกลับ</button><button type="button" class="mt-btn green big" id="aClose">✔ ยืนยันปิดงาน</button></div></div>';
        return '';
    }
    var afterPhotos = [];
    function wireActions(r) {
        var msg = function (t, ok) { var m = $('aMsg'); if (m) { m.className = 'msg ' + (ok ? 'ok' : 'err'); m.textContent = t; } };
        var pin = function () { return S.pin || ($('aPin') ? $('aPin').value : ''); };
        var run = function (btn, fmt, body, after) {
            btn.disabled = true; msg('กำลังบันทึก…', true);
            api(fmt, body).then(function () {
                if (body.pin && !S.pin) { S.pin = body.pin; ss('mt.pin', body.pin); }
                closeDlg(); loadJobs(true); if (S.tab === 'dash') loadDash(); if (after) after();
            }).catch(function (e) { btn.disabled = false; msg(e.message); if (/PIN/.test(e.message)) { S.pin = ''; ss('mt.pin', ''); } });
        };
        if ($('aPhotos')) { afterPhotos = []; photoWidget($('aPhotos'), afterPhotos, 3); }
        if ($('aAccept')) $('aAccept').onclick = function () {
            var t = $('aTech').value.trim(); if (!t) return msg('กรุณาใส่ชื่อช่าง'); ls('mt.tech', t);
            run(this, 'accept', { id: r.id, tech: t, pin: pin() });
        };
        if ($('aDone')) $('aDone').onclick = function () {
            var a = $('aAct').value.trim(); if (!a) return msg('กรุณาใส่วิธีแก้ไข');
            var t = $('aTech').value.trim(); if (t) ls('mt.tech', t);
            run(this, 'done', { id: r.id, cause: $('aCause').value.trim(), action: a, tech: t, pin: pin(), photos: afterPhotos });
        };
        if ($('aCancel')) $('aCancel').onclick = function () {
            var why = prompt('เหตุผลที่ยกเลิก', 'แจ้งซ้ำ / เครื่องใช้ได้แล้ว'); if (why == null) return;
            run(this, 'cancel', { id: r.id, by: ($('aTech') && $('aTech').value.trim()) || ls('mt.tech') || '', note: why, pin: pin() });
        };
        if ($('aClose')) $('aClose').onclick = function () {
            var by = $('aBy').value.trim(); if (!by) return msg('กรุณาใส่ชื่อผู้ตรวจรับ'); ls('mt.reporter', by);
            run(this, 'close', { id: r.id, by: by, note: $('aNote').value.trim() });
        };
        if ($('aReopen')) $('aReopen').onclick = function () {
            var by = $('aBy').value.trim(), note = $('aNote').value.trim();
            if (!by) return msg('กรุณาใส่ชื่อ'); if (!note) { $('aNote').focus(); return msg('บอกอาการที่ยังเสียในช่องหมายเหตุ'); }
            run(this, 'reopen', { id: r.id, by: by, note: note });
        };
    }

    // ================================================================ Dashboard
    $('dProc').innerHTML = '<option value="All">ทุก Process</option>' + PROCS.map(function (p) { return '<option>' + esc(p) + '</option>'; }).join('');
    $('dRange').onclick = function (e) { var b = e.target.closest('button'); if (!b) return; S.range = b.getAttribute('data-d'); Array.prototype.forEach.call(this.children, function (x) { x.classList.toggle('on', x === b); }); loadDash(); };
    $('dProc').onchange = function () { S.proc = this.value; loadDash(); renderOpenList(); };
    function dashRange() {
        var t = new Date(), f = new Date();
        if (S.range === 'm') f = new Date(t.getFullYear(), t.getMonth(), 1); else f.setDate(f.getDate() - (+S.range - 1));
        return { from: ymd(f), to: ymd(t) };
    }
    function loadDash() {
        var r = dashRange();
        api('dash', null, '&from=' + r.from + '&to=' + r.to + '&proc=' + encodeURIComponent(S.proc)).then(function (d) { S.dash = d; renderDash(); })
            .catch(function (e) { $('kpis').innerHTML = '<div class="empty">โหลด Dashboard ไม่ได้: ' + esc(e.message) + '</div>'; });
    }
    function hrs(min) { return min == null ? '–' : (min >= 120 ? (min / 60).toFixed(1) + ' ชม.' : Math.round(min) + ' นาที'); }
    function renderDash() {
        var d = S.dash, t = d.total;
        $('dRangeTxt').textContent = d.from.split('-').reverse().join('/') + ' – ' + d.to.split('-').reverse().join('/') + (d.process !== 'All' ? ' · ' + d.process : '');
        var k = function (cls, label, val, sub) { return '<div class="kpi ' + cls + '"><span>' + label + '</span><b>' + val + '</b><em>' + (sub || '') + '</em></div>'; };
        $('kpis').innerHTML =
            k('blue', 'แจ้งซ่อม', fmtN(t.count), 'ด่วน ' + t.urgent + ' · เครื่องหยุด ' + t.stop) +
            k(t.open + t.doing ? 'red' : 'green', 'งานค้าง', fmtN(t.open + t.doing), 'รอรับ ' + t.open + ' · กำลังซ่อม ' + t.doing + ' · รอปิด ' + t.done) +
            k('amber', 'MTTR', hrs(t.mttr), 'แจ้ง → ซ่อมเสร็จ (เฉลี่ย)') +
            k('', 'รอช่าง', hrs(t.wait), 'แจ้ง → รับงาน (เฉลี่ย)') +
            k('', 'เวลาซ่อม', hrs(t.repair), 'รับงาน → เสร็จ (เฉลี่ย)') +
            k('green', 'MTBF', t.mtbf == null ? '–' : fmtN(t.mtbf) + ' ชม.', 'เฉลี่ยต่อเครื่องที่เสีย') +
            k('red', 'Downtime', hrs(t.downMin), 'เวลาเครื่องหยุดรวม');
        // Top เครื่องเสีย
        var mx = Math.max.apply(null, d.machines.map(function (m) { return m.count; }).concat([1]));
        $('tMc').innerHTML = d.machines.length ? '<table class="tbl"><thead><tr><th>#</th><th>เครื่อง</th><th>Process</th><th style="width:30%">จำนวนครั้ง</th><th class="r">Downtime</th><th class="r">MTTR</th><th class="r">MTBF</th><th class="r">ค้าง</th></tr></thead><tbody>' +
            d.machines.map(function (m, i) {
                return '<tr><td>' + (i + 1) + '</td><td><b>' + esc(m.name || m.machine) + '</b></td><td>' + esc(m.process || '') + '</td><td><div class="bar"><i style="width:' + (m.count * 100 / mx) + '%"></i><b>' + m.count + '</b></div></td>' +
                       '<td class="r">' + hrs(m.downMin) + '</td><td class="r">' + hrs(m.mttr) + '</td><td class="r">' + fmtN(m.mtbf) + ' ชม.</td><td class="r">' + (m.open || '') + '</td></tr>';
            }).join('') + '</tbody></table>' : '<div class="empty">ไม่มีงานซ่อมในช่วงนี้</div>';
        var cx = Math.max.apply(null, d.categories.map(function (c) { return c.count; }).concat([1]));
        $('cCat').innerHTML = d.categories.length ? '<table class="tbl"><tbody>' + d.categories.map(function (c) { return '<tr><td style="width:34%">' + esc(catTh(c.category)) + '</td><td><div class="bar"><i style="width:' + (c.count * 100 / cx) + '%"></i><b>' + c.count + '</b></div></td><td class="r">' + hrs(c.downMin) + '</td></tr>'; }).join('') + '</tbody></table>' : '<div class="empty">–</div>';
        $('tTech').innerHTML = d.techs.length ? '<table class="tbl"><thead><tr><th>ช่าง</th><th class="r">งาน</th><th class="r">เวลาซ่อมเฉลี่ย</th></tr></thead><tbody>' + d.techs.map(function (x) { return '<tr><td>' + esc(x.tech) + '</td><td class="r">' + x.count + '</td><td class="r">' + hrs(x.repair) + '</td></tr>'; }).join('') + '</tbody></table>' : '<div class="empty">ยังไม่มีงานที่ซ่อมเสร็จ</div>';
        drawMonths(d.months);
    }
    function drawMonths(ms) {
        var box = $('cMonth'), W = box.clientWidth || 500, H = box.clientHeight || 240, L = 34, R = 40, T = 16, B = 24;
        var mc = Math.max.apply(null, ms.map(function (m) { return m.count; }).concat([1])), mt = Math.max.apply(null, ms.map(function (m) { return m.mttr || 0; }).concat([1]));
        var slot = (W - L - R) / ms.length, bw = Math.max(6, slot * 0.55), Y = function (v) { return H - B - (H - B - T) * v / mc; }, Y2 = function (v) { return H - B - (H - B - T) * v / mt; };
        var s = '<svg viewBox="0 0 ' + W + ' ' + H + '"><line x1="' + L + '" x2="' + (W - R) + '" y1="' + (H - B) + '" y2="' + (H - B) + '" stroke="#cbd5e1"/>';
        var pts = [];
        ms.forEach(function (m, i) {
            var x = L + slot * i + (slot - bw) / 2;
            if (m.count) s += '<rect x="' + x + '" y="' + Y(m.count) + '" width="' + bw + '" height="' + (H - B - Y(m.count)) + '" rx="3" fill="#818cf8"><title>' + m.month + ' · ' + m.count + ' งาน (ด่วน ' + m.urgent + ')</title></rect><text class="vl" x="' + (x + bw / 2) + '" y="' + (Y(m.count) - 4) + '" text-anchor="middle">' + m.count + '</text>';
            if (m.urgent) s += '<rect x="' + x + '" y="' + Y(m.urgent) + '" width="' + bw + '" height="' + (H - B - Y(m.urgent)) + '" rx="3" fill="#ef4444" opacity=".75"/>';
            s += '<text class="ax" x="' + (L + slot * i + slot / 2) + '" y="' + (H - 7) + '" text-anchor="middle">' + m.month.slice(5) + '/' + m.month.slice(2, 4) + '</text>';
            if (m.mttr != null) pts.push([L + slot * i + slot / 2, Y2(m.mttr), m.mttr]);
        });
        if (pts.length) s += '<polyline fill="none" stroke="#f59e0b" stroke-width="2.2" points="' + pts.map(function (p) { return p[0].toFixed(1) + ',' + p[1].toFixed(1); }).join(' ') + '"/>' +
            pts.map(function (p) { return '<circle cx="' + p[0] + '" cy="' + p[1] + '" r="3.5" fill="#f59e0b"><title>MTTR ' + hrs(p[2]) + '</title></circle>'; }).join('');
        s += '<text class="ax" x="' + (W - R + 4) + '" y="' + (T + 4) + '">' + hrs(mt) + '</text><text class="ax" x="2" y="' + (T + 4) + '">' + mc + '</text></svg>';
        box.innerHTML = s;
    }
    function renderOpenList() {
        if (!$('openList')) return;
        var list = S.rows.filter(function (r) { return /^(open|doing|done)$/.test(r.status) && (S.proc === 'All' || r.process === S.proc); });
        var rank = { open: 0, doing: 1, done: 2 };
        list.sort(function (a, b) { return ((b.priority === 'urgent') - (a.priority === 'urgent')) || (rank[a.status] - rank[b.status]) || a.id - b.id; });
        $('openCnt').textContent = list.length + ' งาน';
        $('openList').innerHTML = list.length ? list.map(function (r) {
            var el = elapsed(r);
            return '<div class="o st-' + r.status + '" data-id="' + r.id + '">' + (r.priority === 'urgent' ? '<span class="tag urg">ด่วน</span>' : '') + stPill(r.status) + '<b>' + esc(mcLabel(r)) + ' · ' + esc(r.problem) + '</b><span class="el' + (el.late ? ' late' : '') + '">' + esc(el.t) + '</span></div>';
        }).join('') : '<div class="empty">✅ ไม่มีงานค้าง</div>';
    }
    $('openList').onclick = function (e) { var o = e.target.closest('.o'); if (o) openJob(+o.getAttribute('data-id')); };

    // ================================================================ QR Code
    $('qProc').innerHTML = '<option value="All">ทุก Process</option>' + PROCS.map(function (p) { return '<option>' + esc(p) + '</option>'; }).join('');
    $('qProc').onchange = renderQr;
    function qrItems() {
        var p = $('qProc').value, out = [];
        mcGroups().forEach(function (g) { if (p === 'All' || g.p === p) g.list.forEach(function (m) { out.push({ key: 'mc:' + m.code, group: g.p, name: m.name, code: m.code, url: 'mc=' + encodeURIComponent(m.code) }); }); });
        S.qCustom.forEach(function (n) { out.push({ key: 'eq:' + n, group: 'อุปกรณ์อื่น', name: n, code: '', url: 'eq=' + encodeURIComponent(n) }); });
        return out;
    }
    function renderQr() {
        if (S.tab !== 'qr') return;
        var items = qrItems(), h = '', last = null;
        items.forEach(function (it) {
            if (it.group !== last) { h += '<h4>' + esc(it.group) + '</h4>'; last = it.group; }
            h += '<label><input type="checkbox" data-k="' + esc(it.key) + '"' + (S.qSel[it.key] ? ' checked' : '') + ' /> <span>' + esc(it.name) + (it.code && it.code !== it.name ? ' <small>' + esc(it.code) + '</small>' : '') + '</span></label>';
        });
        $('qList').innerHTML = h || '<div class="empty">ยังไม่มีรายชื่อเครื่อง (ตาราง machine ว่าง) · เพิ่มอุปกรณ์เองได้ในช่องด้านบน</div>';
    }
    $('qList').onchange = function (e) { var k = e.target.getAttribute('data-k'); if (k) S.qSel[k] = e.target.checked; };
    $('qAll').onchange = function () { var on = this.checked; qrItems().forEach(function (it) { S.qSel[it.key] = on; }); renderQr(); };
    $('qCustom').onkeydown = function (e) {
        if (e.key !== 'Enter') return; e.preventDefault();
        var n = this.value.trim(); if (!n) return;
        if (S.qCustom.indexOf(n) < 0) S.qCustom.push(n);
        S.qSel['eq:' + n] = true; this.value = ''; renderQr();
    };
    function qrSvg(text) {
        if (!window.qrcode) return '<div style="color:red">ไม่พบ files/qrcode.js</div>';
        var q = qrcode(0, 'M'); q.addData(text); q.make();
        return q.createSvgTag({ cellSize: 4, margin: 2, scalable: true });
    }
    $('qPrint').onclick = function () {
        var items = qrItems().filter(function (it) { return S.qSel[it.key]; });
        if (!items.length) { alert('เลือกเครื่องที่จะพิมพ์ QR ก่อน'); return; }
        var base = location.origin + location.pathname, cols = +$('qSize').value;
        var w = window.open('', '_blank'); if (!w) return;
        var cells = items.map(function (it) {
            return '<div class="c"><div class="t">🔧 แจ้งซ่อม / Repair</div>' + qrSvg(base + '?' + it.url) + '<b>' + esc(it.name) + '</b>' + (it.code && it.code !== it.name ? '<span>' + esc(it.code) + '</span>' : '') + '<i>สแกนเพื่อแจ้งซ่อม</i></div>';
        }).join('');
        w.document.write('<!doctype html><html><head><meta charset="utf-8"><title>QR แจ้งซ่อม</title><style>' +
            '@page{size:A4;margin:8mm} body{margin:0;font-family:Sarabun,Tahoma,sans-serif} .g{display:grid;grid-template-columns:repeat(' + cols + ',1fr);gap:4mm}' +
            '.c{border:1.5px dashed #94a3b8;border-radius:3mm;padding:3mm;text-align:center;page-break-inside:avoid;display:flex;flex-direction:column;align-items:center}' +
            '.c svg{width:100%;max-width:' + (cols <= 3 ? 55 : cols === 4 ? 42 : 33) + 'mm;height:auto;display:block}' +
            '.t{font-weight:800;font-size:' + (cols <= 3 ? 13 : 11) + 'pt;margin-bottom:1mm} b{font-size:' + (cols <= 3 ? 13 : 10.5) + 'pt;margin-top:1mm;word-break:break-word} span{font-size:8.5pt;color:#475569} i{font-size:8pt;color:#64748b}' +
            '</style></head><body><div class="g">' + cells + '</div><script>setTimeout(function(){print()},400)<\/script></body></html>');
        w.document.close();
    };

    // ================================================================ โหมดทีวี (Dashboard + งานค้าง)
    function setTv(on) {
        S.tv = on; ls('mt.tv', on ? '1' : '0');
        document.body.classList.toggle('mt-tv', on); root.classList.toggle('tv', on);
        $('tvBtn').textContent = on ? '✕ Exit TV' : '📺 TV';
        if (on && S.tab !== 'dash') setTab('dash'); else if (S.dash) renderDash();
    }
    $('tvBtn').onclick = function () { setTv(!S.tv); };

    // ================================================================ เริ่มต้น
    S.pin = ss('mt.pin') || '';
    var startTab = qs.get('tab') || (qs.get('mc') || qs.get('eq') ? 'report' : qs.get('id') ? 'jobs' : 'report');
    if (!/^(report|jobs|dash|qr)$/.test(startTab)) startTab = 'report';
    loadMachines();
    setTab(startTab);
    if (startTab !== 'jobs') loadJobs(true);
    if (qs.get('id')) openJob(+qs.get('id'));
    if (qs.get('tv') === '1' || (qs.get('tv') !== '0' && startTab === 'dash' && ls('mt.tv') === '1')) setTv(true);
    setInterval(function () { if (document.hidden) return; loadJobs(true); if (S.tab === 'dash') loadDash(); }, 30000);
    setInterval(function () { if (S.tab === 'jobs' && $('dlg').hidden) renderJobs(); if (S.tab === 'dash') renderOpenList(); }, 20000);   // อัปเดตเวลาที่ผ่านไป
    var rt; window.addEventListener('resize', function () { clearTimeout(rt); rt = setTimeout(function () { if (S.dash && S.tab === 'dash') drawMonths(S.dash.months); }, 200); });
})();
