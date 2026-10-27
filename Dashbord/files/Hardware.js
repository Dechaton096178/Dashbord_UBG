// @ts-nocheck
// ===== Hardware List (Hardware.aspx) =====
(function () {
    var API = 'Hardware.aspx';
    var $ = function (id) { return document.getElementById(id); };
    var root = $('hw');
    var S = { rows: [], ping: {}, pingAt: '', pinging: false, q: '', type: '', loc: '', sort: 'item_no', desc: false, pin: '', edit: null, imp: null };
    var FIELDS = ['item_no', 'name', 'hw_type', 'ip', 'location', 'owner', 'serial_no', 'start_date', 'remark'];

    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function msg(t, err) { var m = $('msg'); m.textContent = t || ''; m.className = 'hw-msg' + (err ? ' err' : ''); }
    function getJSON(u) { return fetch(u, { cache: 'no-store' }).then(function (r) { return r.json(); }); }
    function post(fmt, body) {
        body = body || {}; body.pin = S.pin;
        return fetch(API + '?format=' + fmt, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
            .then(function (r) { return r.json(); })
            .then(function (d) { if (!d.ok) throw new Error(d.error || 'error'); return d; });
    }

    // ---------------- โหลดข้อมูล ----------------
    function load() {
        return getJSON(API + '?format=list').then(function (d) {
            if (!d.ok) throw new Error(d.error);
            S.rows = d.rows; render();
        }).catch(function (e) { msg('Load failed: ' + e.message, true); });
    }
    function ping(force) {
        if (S.pinging) return;
        S.pinging = true; $('btnPing').classList.add('busy'); render();
        getJSON(API + '?format=ping' + (force ? '&force=1' : '')).then(function (d) {
            if (!d.ok) throw new Error(d.error);
            S.ping = d.result || {}; S.pingAt = d.at;
        }).catch(function (e) { msg('Ping failed: ' + e.message, true); })
          .then(function () { S.pinging = false; $('btnPing').classList.remove('busy'); render(); });
    }

    // ---------------- แสดงผล ----------------
    var typeCls = {};
    function tcls(t) {
        if (!t) return '';
        if (!(t in typeCls)) typeCls[t] = 't' + (Object.keys(typeCls).length % 6);
        return typeCls[t];
    }
    function status(r) {
        if (!r.ip) return { k: 'none', html: '<span class="st"><i></i><span class="mut">no IP</span></span>' };
        var p = S.ping[r.ip];
        if (!p) return { k: 'wait', html: '<span class="st wait"><i></i>' + (S.pinging ? 'checking' : '–') + '</span>' };
        return p.ok ? { k: 'ok', html: '<span class="st ok"><i></i>Online <small class="mut">' + p.ms + ' ms</small></span>' }
                    : { k: 'bad', html: '<span class="st bad"><i></i>Offline</span>' };
    }
    function filtered() {
        var q = S.q.toLowerCase();
        return S.rows.filter(function (r) {
            if (S.type && r.hw_type !== S.type) return false;
            if (S.loc === '__online' && !(S.ping[r.ip] && S.ping[r.ip].ok)) return false;
            if (S.loc === '__offline' && !(r.ip && S.ping[r.ip] && !S.ping[r.ip].ok)) return false;
            if (!q) return true;
            return FIELDS.some(function (f) { return String(r[f] || '').toLowerCase().indexOf(q) >= 0; });
        });
    }
    function ipKey(ip) { return String(ip || '').split('.').map(function (x) { return ('000' + x).slice(-3); }).join('.'); }
    function sortRows(list) {
        var k = S.sort, dir = S.desc ? -1 : 1;
        return list.slice().sort(function (a, b) {
            var x, y;
            if (k === 'item_no') { x = a.item_no === '' ? 1e9 : +a.item_no; y = b.item_no === '' ? 1e9 : +b.item_no; }
            else if (k === 'ip') { x = ipKey(a.ip); y = ipKey(b.ip); }
            else if (k === 'status') { var o = { ok: 0, bad: 1, wait: 2, none: 3 }; x = o[status(a).k]; y = o[status(b).k]; }
            else { x = String(a[k] || '').toLowerCase(); y = String(b[k] || '').toLowerCase(); }
            return x < y ? -dir : x > y ? dir : 0;
        });
    }
    function render() {
        // KPI
        var total = S.rows.length, on = 0, off = 0, types = {};
        S.rows.forEach(function (r) {
            var p = r.ip && S.ping[r.ip]; if (p) { if (p.ok) on++; else off++; }
            var t = r.hw_type || '(none)'; types[t] = (types[t] || 0) + 1;
        });
        var checked = Object.keys(S.ping).length > 0;
        $('kpis').innerHTML =
            '<div class="hw-kpi acc"><span>Total devices</span><b>' + total + '</b><small>' + Object.keys(types).length + ' types</small></div>' +
            '<div class="hw-kpi ok"><span>Online</span><b>' + (checked ? on : '–') + '</b><small>' + (S.pingAt ? 'checked ' + S.pingAt : S.pinging ? 'checking…' : 'not checked') + '</small></div>' +
            '<div class="hw-kpi bad"><span>Offline</span><b>' + (checked ? off : '–') + '</b><small>no reply from server</small></div>' +
            Object.keys(types).sort().map(function (t) { return '<div class="hw-kpi"><span>' + esc(t) + '</span><b>' + types[t] + '</b></div>'; }).join('');

        // chips
        var ch = '<span class="hw-chip' + (!S.type ? ' on' : '') + '" data-type="">All<em>' + total + '</em></span>';
        Object.keys(types).sort().forEach(function (t) {
            if (t === '(none)') return;
            ch += '<span class="hw-chip' + (S.type === t ? ' on' : '') + '" data-type="' + esc(t) + '">' + esc(t) + '<em>' + types[t] + '</em></span>';
        });
        if (checked) ch += '<span class="hw-chip sep">|</span>' +
            '<span class="hw-chip' + (S.loc === '__online' ? ' on' : '') + '" data-loc="__online">Online<em>' + on + '</em></span>' +
            '<span class="hw-chip' + (S.loc === '__offline' ? ' on' : '') + '" data-loc="__offline">Offline<em>' + off + '</em></span>';
        $('chips').innerHTML = ch;

        // table
        document.querySelectorAll('.hw-table th[data-k]').forEach(function (th) {
            th.classList.toggle('sorted', th.getAttribute('data-k') === S.sort);
            th.classList.toggle('desc', th.getAttribute('data-k') === S.sort && S.desc);
        });
        var list = sortRows(filtered());
        if (!list.length) { $('body').innerHTML = '<tr><td colspan="11" class="hw-empty">' + (S.rows.length ? 'No match' : 'No hardware yet') + '</td></tr>'; return; }
        $('body').innerHTML = list.map(function (r) {
            return '<tr data-id="' + r.id + '">' +
                '<td class="c">' + esc(r.item_no) + '</td>' +
                '<td>' + status(r).html + '</td>' +
                '<td><b>' + esc(r.name) + '</b></td>' +
                '<td>' + (r.hw_type ? '<span class="type ' + tcls(r.hw_type) + '">' + esc(r.hw_type) + '</span>' : '') + '</td>' +
                '<td class="ip">' + (r.ip ? '<a href="#" class="cp" title="Click to copy">' + esc(r.ip) + '</a>' : '<span class="mut">–</span>') + '</td>' +
                '<td>' + esc(r.location) + '</td>' +
                '<td>' + esc(r.owner) + '</td>' +
                '<td>' + (r.serial_no ? esc(r.serial_no) : '<span class="mut">–</span>') + '</td>' +
                '<td>' + esc(r.start_date) + '</td>' +
                '<td class="rm">' + esc(r.remark) + '</td>' +
                '<td class="edit-only"><button type="button" class="rowbtn" data-edit="' + r.id + '">Edit</button></td>' +
                '</tr>';
        }).join('');
        if (S.q || S.type || S.loc) msg('Showing ' + list.length + ' of ' + S.rows.length);
        else if (!S.pinging) msg('');
    }

    // ---------------- Edit mode (PIN) ----------------
    function askPin() {
        if (S.pin) return Promise.resolve(true);
        var p = prompt('Edit PIN');
        if (!p) return Promise.resolve(false);
        S.pin = p;
        return post('checkpin').then(function () { return true; }).catch(function (e) { S.pin = ''; alert(e.message); return false; });
    }
    $('btnEdit').onclick = function () {
        if (root.classList.contains('editing')) { root.classList.remove('editing'); this.classList.remove('on'); this.textContent = 'Edit'; return; }
        var b = this;
        askPin().then(function (ok) { if (!ok) return; root.classList.add('editing'); b.classList.add('on'); b.textContent = 'Editing ✓'; render(); });
    };

    // ---------------- ฟอร์ม ----------------
    function fillLists() {
        var u = function (f) { var s = {}; S.rows.forEach(function (r) { if (r[f]) s[r[f]] = 1; }); return Object.keys(s).sort().map(function (v) { return '<option value="' + esc(v) + '">'; }).join(''); };
        $('dlType').innerHTML = u('hw_type'); $('dlLoc').innerHTML = u('location'); $('dlOwner').innerHTML = u('owner');
    }
    function openForm(r) {
        S.edit = r ? r.id : 0;
        $('formTitle').textContent = r ? 'Edit · ' + r.name : 'New hardware';
        var next = 0; S.rows.forEach(function (x) { if (+x.item_no > next) next = +x.item_no; });
        FIELDS.forEach(function (f) { $('f_' + f).value = r ? (r[f] || '') : ''; });
        if (!r) { $('f_item_no').value = next + 1; $('f_owner').value = 'IT'; $('f_start_date').value = new Date().toISOString().slice(0, 10); }
        $('fDelete').style.visibility = r ? 'visible' : 'hidden';
        $('fMsg').textContent = '';
        fillLists();
        $('formBack').classList.add('show');
        setTimeout(function () { $('f_name').focus(); }, 50);
    }
    function closeForm() { $('formBack').classList.remove('show'); }
    $('btnNew').onclick = function () { askPin().then(function (ok) { if (ok) openForm(null); }); };
    $('fCancel').onclick = closeForm;
    $('fSave').onclick = function () {
        var b = { id: S.edit };
        FIELDS.forEach(function (f) { b[f] = $('f_' + f).value.trim(); });
        if (!b.name) { $('fMsg').textContent = 'Name is required'; return; }
        if (b.ip && !/^\d{1,3}(\.\d{1,3}){3}$/.test(b.ip) && !confirm('IP "' + b.ip + '" does not look like an IPv4 address. Save anyway?')) return;
        $('fMsg').textContent = 'Saving…';
        post('save', b).then(function () { closeForm(); return load(); }).then(function () { msg('Saved ✓'); ping(true); })
            .catch(function (e) { $('fMsg').textContent = e.message; });
    };
    $('fDelete').onclick = function () {
        var r = S.rows.filter(function (x) { return x.id === S.edit; })[0];
        if (!r || !confirm('Delete "' + r.name + (r.ip ? ' (' + r.ip + ')' : '') + '"?')) return;
        post('delete', { id: r.id }).then(function () { closeForm(); return load(); }).then(function () { msg('Deleted'); })
            .catch(function (e) { $('fMsg').textContent = e.message; });
    };

    // ---------------- Import ----------------
    var impData = null, impName = '';
    $('btnImport').onclick = function () {
        askPin().then(function (ok) {
            if (!ok) return;
            impData = null; $('impFile').value = ''; $('impBody').innerHTML = ''; $('impSum').innerHTML = ''; $('impMsg').textContent = ''; $('impGo').disabled = true;
            $('impBack').classList.add('show');
        });
    };
    $('impClose').onclick = function () { $('impBack').classList.remove('show'); };
    function showImport(d) {
        $('impSum').innerHTML = '<span style="color:#166534">+ ' + d.add + ' new</span><span style="color:#1e40af">✎ ' + d.update + ' update</span>' +
            '<span style="color:#64748b">= ' + d.same + ' unchanged</span>' + (d.error ? '<span style="color:#991b1b">✕ ' + d.error + ' error</span>' : '');
        $('impBody').innerHTML = d.rows.map(function (r) {
            return '<tr><td>' + r.row + '</td><td><span class="act ' + r.action + '">' + r.action + '</span></td><td>' + esc(r.name) + '</td><td>' + esc(r.hw_type) +
                '</td><td class="ip">' + esc(r.ip) + '</td><td>' + esc(r.location) + '</td><td>' + esc(r.owner) + '</td><td>' + esc(r.note) + '</td></tr>';
        }).join('') || '<tr><td colspan="8" class="hw-empty">No rows found</td></tr>';
    }
    $('impFile').onchange = function () {
        var f = this.files[0]; if (!f) return;
        impName = f.name; $('impMsg').textContent = 'Reading…'; $('impGo').disabled = true;
        var rd = new FileReader();
        rd.onload = function () {
            impData = rd.result;
            post('import', { name: impName, data: impData, commit: false }).then(function (d) {
                showImport(d);
                $('impMsg').textContent = 'Preview only — press Import to save';
                $('impGo').disabled = (d.add + d.update) === 0;
            }).catch(function (e) { $('impMsg').textContent = e.message; });
        };
        rd.readAsDataURL(f);
    };
    $('impGo').onclick = function () {
        if (!impData) return;
        var b = this; b.disabled = true; $('impMsg').textContent = 'Importing…';
        post('import', { name: impName, data: impData, commit: true }).then(function (d) {
            showImport(d);
            $('impMsg').textContent = 'Imported ✓  (' + d.add + ' new, ' + d.update + ' updated)';
            return load().then(function () { ping(true); });
        }).catch(function (e) { $('impMsg').textContent = e.message; b.disabled = false; });
    };

    // ---------------- events ----------------
    $('q').addEventListener('input', function () { S.q = this.value.trim(); render(); });
    $('btnPing').onclick = function () { ping(true); };
    $('chips').addEventListener('click', function (e) {
        var c = e.target.closest('.hw-chip'); if (!c || c.classList.contains('sep')) return;
        if (c.hasAttribute('data-type')) S.type = c.getAttribute('data-type');
        if (c.hasAttribute('data-loc')) S.loc = S.loc === c.getAttribute('data-loc') ? '' : c.getAttribute('data-loc');
        render();
    });
    document.querySelector('.hw-table thead').addEventListener('click', function (e) {
        var th = e.target.closest('th[data-k]'); if (!th) return;
        var k = th.getAttribute('data-k');
        if (S.sort === k) S.desc = !S.desc; else { S.sort = k; S.desc = false; }
        render();
    });
    $('body').addEventListener('click', function (e) {
        var cp = e.target.closest('a.cp');
        if (cp) {
            e.preventDefault();
            var t = cp.textContent;
            (navigator.clipboard ? navigator.clipboard.writeText(t) : Promise.reject()).then(function () { msg('Copied ' + t); }, function () { msg(t); });
            return;
        }
        var ed = e.target.closest('[data-edit]');
        if (ed) { var id = +ed.getAttribute('data-edit'); openForm(S.rows.filter(function (x) { return x.id === id; })[0]); }
    });
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') { closeForm(); $('impBack').classList.remove('show'); }
    });

    load().then(function () { ping(false); });
    setInterval(function () { if (!document.hidden) ping(false); }, 60000);   // เช็ค Online ทุก 1 นาที
})();
