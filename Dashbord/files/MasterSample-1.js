// @ts-nocheck
// MasterSample.aspx script
    // @ts-nocheck
    // =================== บาร์โค้ด (EAN-13 / UPC-A / Code 128) วาดเป็น SVG ไม่ต้องใช้ไลบรารีภายนอก ===================
    var BC = (function () {
        var EAN = { A: ["0001101","0011001","0010011","0111101","0100011","0110001","0101111","0111011","0110111","0001011"],
                    B: ["0100111","0110011","0011011","0100001","0011101","0111001","0000101","0010001","0001001","0010111"],
                    C: ["1110010","1100110","1101100","1000010","1011100","1001110","1010000","1000100","1001000","1110100"] };
        var PAR = ["AAAAAA","AABABB","AABBAB","AABBBA","ABAABB","ABBAAB","ABBBAA","ABABAB","ABABBA","ABBABA"];
        var C128 = ["11011001100", "11001101100", "11001100110", "10010011000", "10010001100", "10001001100", "10011001000", "10011000100", "10001100100", "11001001000", "11001000100", "11000100100", "10110011100", "10011011100", "10011001110", "10111001100", "10011101100", "10011100110", "11001110010", "11001011100", "11001001110", "11011100100", "11001110100", "11101101110", "11101001100", "11100101100", "11100100110", "11101100100", "11100110100", "11100110010", "11011011000", "11011000110", "11000110110", "10100011000", "10001011000", "10001000110", "10110001000", "10001101000", "10001100010", "11010001000", "11000101000", "11000100010", "10110111000", "10110001110", "10001101110", "10111011000", "10111000110", "10001110110", "11101110110", "11010001110", "11000101110", "11011101000", "11011100010", "11011101110", "11101011000", "11101000110", "11100010110", "11101101000", "11101100010", "11100011010", "11101111010", "11001000010", "11110001010", "10100110000", "10100001100", "10010110000", "10010000110", "10000101100", "10000100110", "10110010000", "10110000100", "10011010000", "10011000010", "10000110100", "10000110010", "11000010010", "11001010000", "11110111010", "11000010100", "10001111010", "10100111100", "10010111100", "10010011110", "10111100100", "10011110100", "10011110010", "11110100100", "11110010100", "11110010010", "11011011110", "11011110110", "11110110110", "10101111000", "10100011110", "10001011110", "10111101000", "10111100010", "11110101000", "11110100010", "10111011110", "10111101110", "11101011110", "11110101110", "11010000100", "11010010000", "11010011100", "11000111010"];
        function eanCheck(d12) { var s = 0; for (var i = 0; i < 12; i++) s += (+d12[i]) * (i % 2 ? 3 : 1); return (10 - s % 10) % 10; }
        function ean13(d) {   // d = 13 หลัก
            var p = PAR[+d[0]], bits = '101';
            for (var i = 1; i <= 6; i++) bits += EAN[p[i - 1]][+d[i]];
            bits += '01010';
            for (i = 7; i <= 12; i++) bits += EAN.C[+d[i]];
            return bits + '101';
        }
        function c128(text) {
            var vals = [], i;
            if (/^\d+$/.test(text) && text.length >= 4 && text.length % 2 === 0) { vals.push(105); for (i = 0; i < text.length; i += 2) vals.push(+text.substr(i, 2)); }
            else {
                vals.push(104);
                for (i = 0; i < text.length; i++) { var c = text.charCodeAt(i); if (c < 32 || c > 126) c = 63; vals.push(c - 32); }
            }
            var sum = vals[0]; for (i = 1; i < vals.length; i++) sum += vals[i] * i;
            vals.push(sum % 103);
            return vals.map(function (v) { return C128[v]; }).join('') + C128[106] + '11';
        }
        // คืน {bits, type, text}
        function encode(code) {
            code = String(code || '').trim();
            var d = code.replace(/\s/g, '');
            if (/^\d{12}$/.test(d) && eanCheck('0' + d.substr(0, 11)) === +d[11]) return { bits: ean13('0' + d), type: 'UPC-A', text: d };
            if (/^\d{13}$/.test(d) && eanCheck(d.substr(0, 12)) === +d[12]) return { bits: ean13(d), type: 'EAN-13', text: d };
            return { bits: c128(code), type: 'Code 128', text: code };
        }
        function svg(code, opt) {
            opt = opt || {};
            var e = encode(code), n = e.bits.length, h = opt.h || 60, quiet = 10, w = n + quiet * 2;
            var r = '', x = 0;
            while (x < n) { if (e.bits[x] === '1') { var s = x; while (x < n && e.bits[x] === '1') x++; r += '<rect x="' + (s + quiet) + '" y="0" width="' + (x - s) + '" height="' + h + '"/>'; } else x++; }
            var txt = opt.noText ? '' : '<text x="' + (w / 2) + '" y="' + (h + 11) + '" text-anchor="middle" font-family="Consolas,monospace" font-size="11" letter-spacing="1">' + e.text.replace(/&/g, '&amp;').replace(/</g, '&lt;') + '</text>';
            return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + w + ' ' + (h + (opt.noText ? 0 : 14)) + '" preserveAspectRatio="none" shape-rendering="crispEdges" class="bcsvg"><rect width="100%" height="100%" fill="#fff"/><g fill="#000">' + r + '</g>' + txt + '</svg>';
        }
        return { encode: encode, svg: svg };
    })();

    (function () {
        var API = location.pathname;
        var SLOT = {
            logo1: '1st Logo', logo2: '2nd Logo', side1: 'Side Mark 1', side2: 'Side Mark 2',
            sleeve_front: 'Front', sleeve_barcode: 'Barcode Side', box_lid: 'Lid Photo', box_base: 'Base Photo', box_barcode: 'Barcode Photo'
        };
        var $ = function (id) { return document.getElementById(id); };
        var root = $('ms'), scan = $('scan');
        var state = { rows: [], cur: null, edit: false, pin: '', pinRequired: null, cont: true, uploadSlot: null, all: null };

        function esc(s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
        function msg(t, cls) { var m = $('msg'); m.className = 'ms-msg' + (cls ? ' ' + cls : ''); m.textContent = t || ''; }
        function getJSON(url) { return fetch(url, { cache: 'no-store' }).then(function (r) { return r.json(); }); }
        function post(fmt, body) {
            body.pin = state.pin;
            return fetch(API + '?format=' + fmt, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
                .then(function (r) { return r.json(); })
                .then(function (d) { if (!d.ok) throw new Error(d.error || 'error'); return d; });
        }
        function readyNext() { if (state.cont && !anyModal()) { scan.focus(); scan.select(); } }
        var lastQ = '';
        function anyModal() { return document.querySelector('.ms-back.show, .ms-zoom.show') != null; }

        // ---------------- ค้นหา ----------------
        function find(q) {
            q = (q || '').trim(); if (!q) return;
            lastQ = q; scan.value = ''; if (typeof scan2 !== 'undefined' && scan2) scan2.value = '';   // ยิงแล้วเคลียร์ช่อง พร้อมยิงตัวต่อไป
            scan.placeholder = '① Unit barcode — scan next…';
            msg('Searching…');
            getJSON(API + '?format=find&q=' + encodeURIComponent(q)).then(function (d) {
                if (!d.ok) throw new Error(d.error);
                state.rows = d.rows;
                if (!d.rows.length) {
                    state.cur = null; renderChoices();
                    $('view').innerHTML = '<div class="ms-empty"><b>Not found</b>No item with "' + esc(q) + '".<br><br>' +
                        '<button type="button" class="ms-btn pri" id="addThis">+ Add new item with this barcode</button></div>';
                    $('addThis').onclick = function () { openForm(null, /^\d{6,}$/.test(q) ? { barcode: q } : { product_name: q }); };
                    msg('Not found: ' + q, 'err'); renderCheck(null);
                } else if (pendingCheck && !d.rows.some(checkOk)) {
                    // ยิง 2 ตัวแล้วไม่ตรงกัน → ห้ามแสดงรูป
                    blockMismatch(d.rows[0]);
                } else {
                    if (pendingCheck) state.rows = d.rows.filter(checkOk);   // เหลือเฉพาะ Supplier ที่ BarCode 2 ตรง
                    // หลายรายการ (บาร์โค้ดเดียวกันหลาย Supplier) → แสดงล่าสุดก่อน ให้เลือกได้
                    show(state.rows[0]);
                    msg(d.exact ? '' : d.rows.length + ' item(s) match the text');   // ผลการยิงแสดงในการ์ดสีน้ำเงิน
                    renderCheck(state.cur);
                }
                if (history.replaceState) history.replaceState(null, '', API + '?' + (document.body.classList.contains('ms-tv') ? 'tv=1&' : '') + 'q=' + encodeURIComponent(q));
                readyNext();
            }).catch(function (e) { msg('Search failed: ' + e.message, 'err'); readyNext(); });
        }

        function renderChoices() { }

        // ---------------- ตรวจ ① ② ----------------
        function dg(x) { return String(x || '').replace(/\D/g, '').replace(/^0+/, ''); }
        function norm2(x) { return String(x || '').toUpperCase().replace(/[^0-9A-Z]/g, ''); }
        function has2(r) { var n = norm2(r && r.barcode2); return n.length > 0 && n !== 'NA'; }
        function same2(scanned, stored) { var a = norm2(scanned), b = norm2(stored); return a === b || (dg(a).length > 0 && dg(a) === dg(b) && /^\d+$/.test(a) && /^\d+$/.test(b)); }
        function checkOk(r) {
            if (!pendingCheck) return true;
            var c = pendingCheck;
            if (has2(r)) return same2(c.b, r.barcode2);   // มี BarCode 2 บันทึกไว้ → ต้องตรงตัว (ยาวเท่าไรก็ได้)
            return core(c.a) === core(c.b);                // ยังไม่มี → เทียบเลข 11 หลักกลาง
        }
        function beep() {
            try {
                var A = window.AudioContext || window.webkitAudioContext; if (!A) return;
                var ctx = beep.ctx || (beep.ctx = new A()), t = ctx.currentTime;
                [0, 0.28, 0.56].forEach(function (d) {
                    var o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'square'; o.frequency.value = 880;
                    g.gain.setValueAtTime(0.25, t + d); g.gain.setValueAtTime(0, t + d + 0.18);
                    o.connect(g); g.connect(ctx.destination); o.start(t + d); o.stop(t + d + 0.2);
                });
            } catch (e) { }
        }
        function blockMismatch(r) {
            var c = pendingCheck;
            state.cur = null; state.rows = [];
            renderCheck(null);
            msg('BARCODE MISMATCH — photos are hidden', 'err');
            $('view').innerHTML =
                '<div class="ms-block"><div class="ic">✗</div><h2>BARCODE MISMATCH</h2><p>บาร์โค้ด ① กับ ② ไม่ตรงกัน — ห้ามใช้ / ตรวจฉลากกล่อง<br>Barcode ① and ② do not match — check the box label</p>' +
                '<table><tr><td>① Unit (scanned)</td><td>' + esc(c.a) + '</td></tr>' +
                '<tr><td>② Case (scanned)</td><td class="bad">' + esc(c.b) + '</td></tr>' +
                (r && r.barcode2 ? '<tr><td>② Expected for this item</td><td class="ok">' + esc(r.barcode2) + '</td></tr>' : '') +
                (r ? '<tr><td>Item of ①</td><td>' + esc(r.product_name) + (r.supplier ? ' · ' + esc(r.supplier) : '') + '</td></tr>' : '') +
                '</table><small>Scan again: ① then ②</small></div>';
            beep();
        }   // ปุ่มเลือก Supplier อยู่ในการ์ดข้อมูล (show)

        // ---------------- ใบ Master Sample Sheet ----------------
        var IMG_ICON = '<svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="8.5" cy="10" r="1.6"/><path d="M21 16l-5-5-8 8"/></svg>';
        function has(r, key) { return (',' + (r.photos || '') + ',').indexOf(',' + key + ',') >= 0; }
        function src(r, key) { return API + '?format=photo&id=' + r.id + '&slot=' + key + '&v=' + encodeURIComponent(r.updated_at || ''); }
        function tile(r, key) {
            var h = has(r, key);
            return '<div class="tile' + (h ? '' : ' empty') + '" data-slot="' + key + '">' +
                (h ? '<img src="' + src(r, key) + '" alt="' + SLOT[key] + '" data-zoom="' + key + '" />' : '<span class="none">' + IMG_ICON + 'No photo</span>') +
                '<span class="acts"><button type="button" data-up="' + key + '">' + (h ? 'Replace' : 'Upload') + '</button>' +
                (h ? '<button type="button" class="del" data-del="' + key + '">Delete</button>' : '') + '</span></div>';
        }
        function cell(r, key, label, cls) { return '<div class="c"><div class="h ' + (cls || '') + '">' + label + '</div>' + tile(r, key) + '</div>'; }
        // บาร์โค้ดจำลอง (ตกแต่ง) จากตัวเลข
        function bars(code) {
            var d = String(code || '').replace(/\D/g, ''); if (!d) return '';
            var h = ''; for (var i = 0; i < d.length && i < 14; i++) { var n = +d[i]; h += '<i style="width:' + (1 + n % 3) + 'px;margin-right:' + (1 + (n >> 2) % 2) + 'px"></i>'; }
            return '<span class="bars">' + h + '</span>';
        }
        function psHtml(r, key, cls) {
            return '<div class="ps ' + (cls || '') + '"><div class="lb">' + SLOT[key] + '</div><div class="im">' +
                (has(r, key) ? '<img src="' + src(r, key) + '" alt="" />' : '<span class="none">No photo</span>') + '</div></div>';
        }
        // ผลตรวจบาร์โค้ด ① ② กับรายการที่แสดง (เทียบกับ BarCode 2 ที่บันทึกไว้ ถ้ามี)
        // แสดงในการ์ดสีน้ำเงิน : เลขที่ยิงล่าสุด + ผลตรวจ ① ②
        function renderCheck(r) {
            var el = document.getElementById('scanLine');
            if (!el) return;
            if (!r || !lastQ) { el.innerHTML = ''; return; }
            if (!pendingCheck) { el.innerHTML = '<span class="sl-k">Last scan</span><span class="sl-v">' + esc(lastQ) + '</span>'; return; }
            var c = pendingCheck, ok = checkOk(r);
            el.innerHTML = '<span class="sl-k">Last scan</span><span class="sl-v">① ' + esc(c.a) + '</span><span class="sl-v">② ' + esc(c.b) + '</span>' +
                (ok ? '<span class="sl-ok">✓ Match</span>' : '<span class="sl-bad">✗ Mismatch</span>');
        }
        function show(r) {
            state.cur = r;
            setTimeout(function () { renderCheck(r); }, 0);
            var v = function (k) { return esc(r[k] || ''); };
            var n = r.photos ? r.photos.split(',').length : 0;
            var sup = state.rows.length > 1 ? '<div class="sup"><span>' + state.rows.length + ' suppliers for this code</span>' + state.rows.map(function (x, i) {
                    return '<button type="button" data-i="' + i + '" class="' + (x.id === r.id ? 'cur' : '') + '">' + esc(x.supplier || '-') + ' · ' + esc((x.prepared || '').substr(0, 7)) + '</button>';
                }).join('') + '</div>' : '';
            var kv = [['Product Number', v('product_number')], ['Supplier', '<span class="tagc">' + (v('supplier') || '-') + '</span>'], ['Sample Location', v('sample_location')],
                      ['SQE / SI', v('sqe')], ['Supplier Approver', v('supplier_approver')], ['Prepared', v('prepared')], ['Short Name', v('short_name')]];
            $('view').innerHTML =
                '<div class="scr">' +
                '<div class="info">' +
                  '<div class="hd"><small>Master Sample Sheet</small><h3>' + v('product_name') + '</h3>' +
                  '<div class="bcs">' +
                    '<div class="bc"><b>1</b><span class="bl">BarCode 1<small>Unit</small></span>' + bars(r.barcode) + '<span class="bn">' + (v('barcode') || 'No barcode') + '</span></div>' +
                    '<div class="bc bc2"><b>2</b><span class="bl">BarCode 2<small>Case</small></span>' + bars(r.barcode2) + '<span class="bn">' + (v('barcode2') || '–') + '</span></div>' +
                  '</div>' +
                  '<div class="scanline" id="scanLine"></div></div>' +
                  '<div class="bd" title="' + (state.edit ? 'Click to edit' : '') + '"><div class="edit-hint">Click here to edit the details</div>' + sup +
                  '<div class="kv">' + kv.map(function (p) { return '<div class="k">' + p[0] + '</div><div class="v">' + (p[1] || '–') + '</div>'; }).join('') + '</div>' +
                  (r.comment ? '<div class="note"><b>Comment</b>' + v('comment') + '</div>' : '') + '</div>' +
                  '<div class="ft"><span>Photos ' + n + ' / 9</span><span class="prog"><i style="width:' + (n / 9 * 100).toFixed(0) + '%"></i></span><span>ID ' + r.id + ' · ' + v('updated_at') + '</span></div>' +
                '</div>' +
                '<div class="pp">' +
                  '<div class="t">Product Photo</div>' +
                  '<div class="top">' + cell(r, 'logo1', '1st Logo') + cell(r, 'logo2', '2nd Logo') + cell(r, 'side1', 'Side Mark 1') + cell(r, 'side2', 'Side Mark 2') + '</div>' +
                  '<div class="bot">' +
                    '<div class="grp2"><div class="h g sl">Sleeve Photo</div><div class="two">' +
                      cell(r, 'sleeve_front', 'Front') + cell(r, 'sleeve_barcode', 'Barcode Side') + '</div></div>' +
                    '<div class="grp2"><div class="h g bx">Box Photo</div><div class="stack">' +
                      cell(r, 'box_lid', 'Lid Photo') + cell(r, 'box_base', 'Base Photo') + cell(r, 'box_barcode', 'Barcode Photo') + '</div></div>' +
                  '</div>' +
                '</div>' +
                '</div>';
            // ใบสำหรับพิมพ์ (รูปแบบเดิม)
            $('sheet').innerHTML =
                '<div class="ttl">Master Sample Sheet</div><table class="pinfo">' +
                '<tr><td class="k">Product Name</td><td class="big" colspan="6">' + v('product_name') + '</td></tr>' +
                '<tr><td class="k">BarCode 1</td><td class="bcx" colspan="2">' + (v('barcode') || '-') + '</td><td class="k">BarCode 2</td><td class="bcx" colspan="3">' + (v('barcode2') || '-') + '</td></tr>' +
                '<tr><td class="k">Product Number</td><td>' + v('product_number') + '</td><td class="k">Prepared</td><td>' + v('prepared') + '</td><td class="k">Sample Location</td><td>' + v('sample_location') + '</td><td class="sign" rowspan="2">Sign here:</td></tr>' +
                '<tr><td class="k">Supplier</td><td>' + v('supplier') + '</td><td class="k">Supplier Approver</td><td>' + v('supplier_approver') + '</td><td class="k">SQE/SI</td><td>' + v('sqe') + '</td></tr>' +
                '<tr><td class="k">Comment</td><td colspan="6">' + v('comment') + '</td></tr></table>' +
                '<div class="pt">Product Photo</div><div class="g4">' + psHtml(r, 'logo1') + psHtml(r, 'logo2') + psHtml(r, 'side1') + psHtml(r, 'side2') + '</div>' +
                '<div class="low"><div><div class="sub">Sleeve Photo</div><div class="g2">' + psHtml(r, 'sleeve_front', 'tall') + psHtml(r, 'sleeve_barcode', 'tall r') + '</div></div>' +
                '<div><div class="sub">Box Photo</div>' + psHtml(r, 'box_lid', 'mid r') + psHtml(r, 'box_base', 'mid r') + psHtml(r, 'box_barcode', 'mid r') + '</div></div>' +
                '<div class="foot"><span>Short name: ' + v('short_name') + '</span><span>Printed ' + new Date().toLocaleString('en-GB') + ' · ID ' + r.id + '</span></div>';

            var view = $('view');
            view.querySelectorAll('.sup button').forEach(function (b) { b.onclick = function (e) { e.stopPropagation(); show(state.rows[+b.getAttribute('data-i')]); readyNext(); }; });
            view.querySelectorAll('img[data-zoom]').forEach(function (im) {
                im.onclick = function () { $('zoomImg').src = im.src; $('zoomCap').textContent = SLOT[im.getAttribute('data-zoom')] + ' · ' + (r.product_name || ''); $('zoom').classList.add('show'); };
            });
            view.querySelectorAll('[data-up]').forEach(function (b) { b.onclick = function (e) { e.stopPropagation(); pickPhoto(b.getAttribute('data-up')); }; });
            view.querySelectorAll('[data-del]').forEach(function (b) { b.onclick = function (e) { e.stopPropagation(); delPhoto(b.getAttribute('data-del')); }; });
            view.querySelectorAll('.tile.empty').forEach(function (t) { t.onclick = function () { if (state.edit) pickPhoto(t.getAttribute('data-slot')); }; });
            view.querySelector('.info .bd').onclick = function (e) { if (state.edit && !e.target.closest('.sup')) openForm(state.cur); };
            view.querySelector('.info .hd').ondblclick = function () { openForm(state.cur); };
        }
        function refreshCur(row) {
            state.rows = state.rows.map(function (x) { return x.id === row.id ? row : x; });
            if (!state.rows.some(function (x) { return x.id === row.id; })) state.rows = [row];
            state.all = null; show(row);
        }

        // ---------------- โหมดแก้ไข ----------------
        function ensureEdit() {
            if (state.edit) return Promise.resolve(true);
            return (state.pinRequired === null ? getJSON(API + '?format=list').then(function (d) { state.pinRequired = !!d.pinRequired; state.all = d.rows; }) : Promise.resolve())
                .then(function () {
                    if (!state.pinRequired) { setEdit(true); return true; }
                    var p = prompt('Edit PIN / รหัสแก้ไข');
                    if (p === null) return false;
                    state.pin = p;
                    return post('checkpin', {}).then(function () { setEdit(true); return true; })
                        .catch(function (e) { state.pin = ''; alert(e.message); return false; });
                });
        }
        function setEdit(on) {
            state.edit = on; root.classList.toggle('edit', on);
            $('btnEdit').classList.toggle('edit-on', on); $('btnEdit').textContent = on ? 'Editing 🔓' : 'Edit';
            if (state.cur) show(state.cur);
        }

        // ---------------- อัปโหลดรูป (ย่อรูปก่อนส่ง) ----------------
        function pickPhoto(slot) { state.uploadSlot = slot; $('file').value = ''; $('file').click(); }
        $('file').addEventListener('change', function () {
            var f = this.files && this.files[0]; if (!f || !state.cur) return;
            msg('Uploading ' + SLOT[state.uploadSlot] + '…');
            resize(f, 1600, 0.85).then(function (dataUrl) {
                return post('upload', { id: state.cur.id, slot: state.uploadSlot, data: dataUrl });
            }).then(function (d) { refreshCur(d.row); msg('Photo saved: ' + SLOT[state.uploadSlot], 'ok'); })
              .catch(function (e) { msg('Upload failed: ' + e.message, 'err'); });
        });
        function resize(file, max, q) {
            return new Promise(function (res, rej) {
                var rd = new FileReader();
                rd.onerror = function () { rej(new Error('cannot read file')); };
                rd.onload = function () {
                    var img = new Image();
                    img.onerror = function () { rej(new Error('not an image')); };
                    img.onload = function () {
                        var s = Math.min(1, max / Math.max(img.width, img.height)), w = Math.round(img.width * s), h = Math.round(img.height * s);
                        var c = document.createElement('canvas'); c.width = w; c.height = h;
                        var g = c.getContext('2d'); g.fillStyle = '#fff'; g.fillRect(0, 0, w, h); g.drawImage(img, 0, 0, w, h);
                        res(c.toDataURL('image/jpeg', q));
                    };
                    img.src = rd.result;
                };
                rd.readAsDataURL(file);
            });
        }
        function delPhoto(slot) {
            if (!state.cur || !confirm('Delete photo "' + SLOT[slot] + '"?')) return;
            post('delphoto', { id: state.cur.id, slot: slot }).then(function (d) { refreshCur(d.row); msg('Photo deleted', 'ok'); })
                .catch(function (e) { msg('Delete failed: ' + e.message, 'err'); });
        }

        // ---------------- ฟอร์มเพิ่ม/แก้ไข ----------------
        var FIELDS = ['product_name', 'barcode', 'barcode2', 'product_number', 'supplier', 'sample_location', 'sqe', 'supplier_approver', 'prepared', 'short_name', 'comment'];
        var formId = 0;
        function fillLists() {
            var src = state.all || [], uniq = function (k) { var o = {}; src.forEach(function (r) { if (r[k]) o[r[k]] = 1; }); return Object.keys(o).sort(); };
            [['dlSupplier', 'supplier'], ['dlLocation', 'sample_location'], ['dlSqe', 'sqe'], ['dlAppr', 'supplier_approver']].forEach(function (p) {
                $(p[0]).innerHTML = uniq(p[1]).map(function (x) { return '<option value="' + esc(x) + '">'; }).join('');
            });
        }
        function openForm(row, preset) {
            ensureEdit().then(function (ok) {
                if (!ok) return;
                formId = row ? row.id : 0;
                var src = row || preset || {};
                FIELDS.forEach(function (k) { $('f_' + k).value = src[k] || ''; });
                if (!row && !$('f_prepared').value) { var d = new Date(); $('f_prepared').value = d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2); }
                $('formTitle').textContent = row ? 'Edit · ID ' + row.id : 'New item';
                $('fDelete').style.display = row ? '' : 'none';
                $('fMsg').textContent = '';
                if (!state.all) getJSON(API + '?format=list').then(function (d) { state.all = d.rows; fillLists(); }); else fillLists();
                $('formBack').classList.add('show');
                $('f_product_name').focus();
            });
        }
        function closeForm() { $('formBack').classList.remove('show'); readyNext(); }
        $('fCancel').onclick = closeForm;
        $('fSave').onclick = function () {
            var body = { id: formId }; FIELDS.forEach(function (k) { body[k] = $('f_' + k).value; });
            if (!body.product_name.trim()) { $('fMsg').textContent = 'Product Name is required'; return; }
            $('fMsg').textContent = 'Saving…';
            post('save', body).then(function (d) { closeForm(); refreshCur(d.row); msg('Saved', 'ok'); })
                .catch(function (e) { $('fMsg').textContent = e.message; });
        };
        $('fDelete').onclick = function () {
            if (!formId || !confirm('Delete this item and all its photos?')) return;
            post('delete', { id: formId }).then(function () {
                closeForm(); state.all = null; state.rows = state.rows.filter(function (x) { return x.id !== formId; });
                if (state.rows.length) show(state.rows[0]); else { state.cur = null; renderChoices(); $('view').innerHTML = '<div class="ms-empty"><b>Deleted</b></div>'; }
                msg('Deleted', 'ok');
            }).catch(function (e) { $('fMsg').textContent = e.message; });
        };

        // ---------------- รายการทั้งหมด ----------------
        function renderList() {
            var f = $('listFilter').value.trim().toUpperCase().split(/\s+/).filter(Boolean);
            var rows = (state.all || []).filter(function (r) {
                var h = [r.product_name, r.barcode, r.barcode2, r.product_number, r.supplier, r.sqe, r.short_name].join(' ').toUpperCase();
                return f.every(function (w) { return h.indexOf(w) >= 0; });
            });
            $('listCount').textContent = rows.length + ' / ' + (state.all || []).length;
            $('listBody').innerHTML = rows.map(function (r) {
                var n = r.photos ? r.photos.split(',').length : 0;
                return '<tr data-id="' + r.id + '"><td>' + esc(r.product_name) + '</td><td>' + esc(r.barcode) + '</td><td>' + esc(r.barcode2) + '</td><td>' + esc(r.product_number) + '</td><td>' + esc(r.supplier) +
                    '</td><td>' + esc(r.sqe) + '</td><td>' + esc(r.prepared) + '</td><td>' + esc(r.short_name) + '</td><td class="pc"><i><b style="width:' + (n / 9 * 100).toFixed(0) + '%"></b></i>' + n + '/9</td></tr>';
            }).join('');
            $('listBody').querySelectorAll('tr').forEach(function (tr) {
                tr.onclick = function () {
                    var r = state.all.filter(function (x) { return x.id === +tr.getAttribute('data-id'); })[0];
                    $('listBack').classList.remove('show'); state.rows = [r]; show(r); msg(''); readyNext();
                };
            });
            return rows;
        }
        $('btnList').onclick = function () {
            $('listBack').classList.add('show'); $('listFilter').value = ''; $('listFilter').focus();
            getJSON(API + '?format=list').then(function (d) { state.all = d.rows; state.pinRequired = !!d.pinRequired; renderList(); })
                .catch(function (e) { $('listCount').textContent = e.message; });
        };
        $('listFilter').oninput = renderList;
        $('listClose').onclick = function () { $('listBack').classList.remove('show'); readyNext(); };
        $('listCsv').onclick = function () {
            var rows = renderList(), cols = ['product_name', 'product_number', 'supplier', 'barcode', 'barcode2', 'sqe', 'prepared', 'supplier_approver', 'sample_location', 'short_name', 'comment'];
            var csv = '﻿' + cols.join(',') + '\n' + rows.map(function (r) { return cols.map(function (k) { return '"' + String(r[k] || '').replace(/"/g, '""') + '"'; }).join(','); }).join('\n');
            var a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' })); a.download = 'MasterSample.csv'; a.click();
        };

        // ---------------- ปุ่มต่างๆ ----------------
        // ---------------- ยิง 2 บาร์โค้ด (ฉลากกล่อง: ① Unit UPC + ② Case GTIN-14) ----------------
        var scan2 = $('scan2'), two = true, pendingCheck = null;
        function core(c) { var d = String(c || '').replace(/\D/g, '').replace(/^0+/, ''); return d.length >= 12 ? d.substr(d.length - 12, 11) : d; }
        function isCode(v) { return /^\d{8,14}$/.test(String(v || '').replace(/\s/g, '')); }
        function setTwo(on) {
            two = on; root.classList.toggle('one', !on); $('two').classList.toggle('on', on); $('two').textContent = on ? '2 barcodes' : '1 barcode';
            scan.classList.remove('next'); scan2.classList.remove('next'); scan2.value = '';
            try { localStorage.setItem('msTwo', on ? '1' : '0'); } catch (e) { }
            scan.focus();
        }
        function submit1() {
            var v = scan.value.trim(); if (!v) return;
            if (two && isCode(v)) { scan.classList.remove('next'); scan2.classList.add('next'); scan2.value = ''; scan2.focus(); msg('① ' + v + ' — now scan ② case barcode'); return; }
            pendingCheck = null; find(v);
        }
        function submit2() {
            var a = scan.value.trim(), b = scan2.value.trim();
            if (!a) { if (b) { scan.value = b; scan2.value = ''; submit1(); } return; }
            if (!b) return;
            scan2.classList.remove('next'); scan2.value = '';
            pendingCheck = { a: a, b: b };
            find(a);
        }
        scan.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); submit1(); } });
        scan2.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); submit2(); } else if (e.key === 'Escape') { scan2.value = ''; scan2.classList.remove('next'); scan.focus(); } });
        $('go').onclick = function () { if (two && scan2.value.trim()) submit2(); else { pendingCheck = null; find(scan.value); } };
        $('two').onclick = function () { setTwo(!two); };
        var two0 = true; try { two0 = localStorage.getItem('msTwo') !== '0'; } catch (e) { }
        setTwo(two0);
        $('cont').onclick = function () { state.cont = !state.cont; this.classList.toggle('on', state.cont); readyNext(); };
        $('btnEdit').onclick = function () { if (state.edit) setEdit(false); else ensureEdit(); };
        $('btnNew').onclick = function () { openForm(null, null); };
        $('btnPrint').onclick = function () { if (!state.cur) { msg('Scan an item first', 'err'); return; } window.print(); };
        $('zoom').onclick = function () { this.classList.remove('show'); readyNext(); };
        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape') { document.querySelectorAll('.ms-back.show, .ms-zoom.show').forEach(function (x) { x.classList.remove('show'); }); readyNext(); return; }
            // โหมดต่อเนื่อง : พิมพ์/ยิงตอนไม่ได้อยู่ในช่องกรอก → ส่งเข้าช่องสแกนเอง
            var t = e.target.tagName;
            if (state.cont && !anyModal() && t !== 'INPUT' && t !== 'TEXTAREA' && e.key.length === 1 && !e.ctrlKey && !e.metaKey && !e.altKey) { scan.value = ''; scan.focus(); }
        });

        // ---------------- พิมพ์บาร์โค้ด ----------------
        var LBL = { '50x30': [50, 30], '60x40': [60, 40], '100x50': [100, 50], 'a4': [70, 37] };
        function lblHtml(code, sizeKey, withName) {
            var sz = LBL[sizeKey], w = sz[0], h = sz[1], r = state.cur;
            var nameFs = Math.max(2.4, h * 0.085), subFs = Math.max(2.1, h * 0.065);
            return '<div class="lbl" style="width:' + w + 'mm;height:' + h + 'mm;padding:' + (h * 0.05) + 'mm ' + (w * 0.04) + 'mm">' +
                (withName ? '<div class="n" style="font-size:' + nameFs + 'mm">' + esc(r.product_name) + '</div>' : '') +
                '<div style="width:100%;height:' + (h * (withName ? 0.56 : 0.78)) + 'mm;display:flex;justify-content:center">' + BC.svg(code, { h: 50 }).replace('class="bcsvg"', 'class="bcsvg" style="height:100%"') + '</div>' +
                (withName ? '<div class="s" style="font-size:' + subFs + 'mm">' + esc([r.short_name, r.supplier].filter(Boolean).join(' · ')) + '</div>' : '') + '</div>';
        }
        function lblRefresh() {
            if (!state.cur) return;
            var code = $('lblCode').value, size = $('lblSize').value;
            $('lblPrev').innerHTML = lblHtml(code, size, $('lblName').checked);
            var pv = $('lblPrev').firstChild, sz = LBL[size], k = Math.min(2.4, 400 / (sz[0] * 3.78));
            pv.style.transform = 'scale(' + k + ')'; $('lblPrev').style.height = (sz[1] * 3.78 * k + 40) + 'px';
            $('lblType').textContent = BC.encode(code).type + ' · ' + code;
        }
        $('btnLabel').onclick = function () {
            if (!state.cur) { msg('Scan an item first', 'err'); return; }
            var r = state.cur, opts = [];
            if (r.barcode && /\d{6,}/.test(r.barcode)) opts.push(['BarCode 1', r.barcode]);
            if (r.barcode2 && /\d{6,}/.test(r.barcode2)) opts.push(['BarCode 2', r.barcode2]);
            if (r.product_number) opts.push(['Product Number', r.product_number]);
            if (!opts.length) { msg('This item has no barcode or product number', 'err'); return; }
            $('lblCode').innerHTML = opts.map(function (o) { return '<option value="' + esc(o[1]) + '">' + o[0] + ' · ' + esc(o[1]) + '</option>'; }).join('');
            $('lblBack').classList.add('show'); lblRefresh();
        };
        ['lblCode', 'lblSize', 'lblName'].forEach(function (id) { $(id).onchange = lblRefresh; });
        $('lblCancel').onclick = function () { $('lblBack').classList.remove('show'); readyNext(); };
        $('lblGo').onclick = function () {
            var code = $('lblCode').value, size = $('lblSize').value, n = Math.max(1, Math.min(200, +$('lblCopies').value || 1)), one = lblHtml(code, size, $('lblName').checked), html = '';
            for (var i = 0; i < n; i++) html += one;
            $('labelPrint').innerHTML = size === 'a4' ? '<div class="a4">' + html + '</div>' : html;
            var st = document.getElementById('lblPage') || document.head.appendChild(Object.assign(document.createElement('style'), { id: 'lblPage' }));
            st.textContent = size === 'a4' ? '@media print { @page { size:A4 portrait; margin:12mm 0 0 0; } #labelPrint .a4 { margin:0 auto; width:210mm; } }'
                                           : '@media print { @page { size:' + LBL[size][0] + 'mm ' + LBL[size][1] + 'mm; margin:0; } }';
            document.body.classList.add('lbl-printing');
            $('lblBack').classList.remove('show');
            setTimeout(function () { window.print(); }, 50);
        };
        window.addEventListener('afterprint', function () {
            if (!document.body.classList.contains('lbl-printing')) return;
            document.body.classList.remove('lbl-printing');
            var st = document.getElementById('lblPage'); if (st) st.textContent = '';
            $('labelPrint').innerHTML = ''; readyNext();
        });

        // ---------------- นำเข้า Excel / CSV ----------------
        var impData = null;
        function impShow(d) {
            $('impSum').innerHTML = '<span>' + d.total + ' rows</span><span class="n">' + d.added + ' new</span><span class="u">' + d.updated + ' update</span><span>' + d.same + ' no change</span>' +
                '<span class="u">' + d.photos + ' photo(s)</span>' + (d.errors ? '<span class="e">' + d.errors + ' error</span>' : '') +
                (d.photoColumns && d.photoColumns.length ? '' : '<span>no photo columns</span>');
            $('impBody').innerHTML = d.rows.map(function (x) {
                return '<tr><td>' + x.row + '</td><td><span class="act ' + x.action + '">' + x.action + '</span></td><td>' + esc(x.product_name) + '</td><td>' + esc(x.barcode) + '</td><td>' + esc(x.barcode2) +
                    '</td><td>' + esc(x.product_number) + '</td><td>' + esc(x.supplier) + '</td><td>' + (x.photos || '') + '</td><td style="white-space:normal">' + esc(x.note) + '</td></tr>';
            }).join('');
        }
        $('btnImport').onclick = function () {
            ensureEdit().then(function (ok) {
                if (!ok) return;
                impData = null; $('impFile').value = ''; $('impSum').innerHTML = ''; $('impBody').innerHTML = ''; $('impMsg').textContent = ''; $('impGo').disabled = true;
                $('impBack').classList.add('show');
            });
        };
        function upload(file) {   // ส่งไฟล์เป็นชิ้นละ ~1.5 MB
            var uid = Date.now().toString(36) + Math.random().toString(36).slice(2, 8), CH = 1536 * 1024, n = Math.ceil(file.size / CH) || 1, idx = 0;
            var bar = $('impProg'); bar.style.display = ''; bar.firstChild.style.width = '0';
            function next() {
                if (idx >= n) return Promise.resolve(uid);
                return new Promise(function (res, rej) {
                    var rd = new FileReader();
                    rd.onerror = function () { rej(new Error('cannot read file')); };
                    rd.onload = function () { res(String(rd.result).split(',')[1] || ''); };
                    rd.readAsDataURL(file.slice(idx * CH, (idx + 1) * CH));
                }).then(function (b64) { return post('chunk', { uid: uid, idx: idx, data: b64 }); })
                  .then(function () { idx++; bar.firstChild.style.width = (idx / n * 100).toFixed(0) + '%'; $('impMsg').textContent = 'Uploading… ' + Math.round(idx / n * 100) + '%'; return next(); });
            }
            return next();
        }
        $('impFile').onchange = function () {
            var f = this.files && this.files[0]; if (!f) return;
            if (f.size > 60 * 1024 * 1024) { $('impMsg').textContent = 'File too large (max 60 MB)'; return; }
            impData = null; $('impGo').disabled = true; $('impSum').innerHTML = ''; $('impBody').innerHTML = '';
            upload(f).then(function (uid) {
                impData = { name: f.name, uid: uid };
                $('impMsg').textContent = 'Checking…';
                return post('import', { name: f.name, uid: uid, commit: false });
            }).then(function (d) { impShow(d); $('impMsg').textContent = 'Preview only — press Import to save'; $('impGo').disabled = !(d.added + d.updated); })
              .catch(function (e) { $('impMsg').textContent = e.message; });
        };
        $('impGo').onclick = function () {
            if (!impData) return;
            $('impGo').disabled = true; $('impMsg').textContent = 'Importing… (photos take a little longer)';
            post('import', { name: impData.name, uid: impData.uid, commit: true })
                .then(function (d) {
                    impShow(d); state.all = null; impData = null;
                    $('impMsg').textContent = 'Done: ' + d.added + ' added, ' + d.updated + ' updated, ' + d.photos + ' photo(s)';
                    msg('Import done: ' + d.added + ' added, ' + d.updated + ' updated, ' + d.photos + ' photo(s)', 'ok');
                    if (state.cur && lastQ) find(lastQ);
                })
                .catch(function (e) { $('impMsg').textContent = e.message; $('impGo').disabled = false; });
        };
        $('impClose').onclick = function () { $('impBack').classList.remove('show'); readyNext(); };

        // ---------------- โหมด TV ----------------
        var qs0 = new URLSearchParams(location.search), tv = qs0.get('tv') === '1';
        function tvUrl(on) { var q = (state.cur ? lastQ : '') || qs0.get('q') || ''; return API + '?' + (on ? 'tv=1' : '') + (q ? (on ? '&' : '') + 'q=' + encodeURIComponent(q) : ''); }
        if (tv) { document.body.classList.add('ms-tv'); if (state.edit) setEdit(false); }
        $('btnTv').onclick = function () { location.href = tvUrl(true); };
        $('btnTvExit').onclick = function () { if (document.fullscreenElement) document.exitFullscreen(); location.href = tvUrl(false); };
        $('btnFull').onclick = function () { if (!document.fullscreenElement) document.documentElement.requestFullscreen && document.documentElement.requestFullscreen(); else document.exitFullscreen(); };

        // รูป : Fill (เต็มช่อง) / Fit (เห็นทั้งรูป) · จำค่าไว้ในเบราว์เซอร์
        function setFit(on) { root.classList.toggle('fit', on); $('btnFit').textContent = on ? 'Fit' : 'Fill'; try { localStorage.setItem('msFit', on ? '1' : '0'); } catch (e) { } }
        var fit0 = false; try { fit0 = localStorage.getItem('msFit') === '1'; } catch (e) { }
        setFit(fit0);
        $('btnFit').onclick = function () { setFit(!root.classList.contains('fit')); readyNext(); };

        var q0 = new URLSearchParams(location.search).get('q');
        if (q0) find(q0); else scan.focus();
    })();
