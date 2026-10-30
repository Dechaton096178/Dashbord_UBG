// @ts-nocheck
// ===== พิมพ์แบบฟอร์ม HR ตามกระดาษเดิม : ใบลา UBG-FM-HR-09-A · ใบขอ OT UBG-FM-HR-07-A =====
window.HrPrint = (function () {
    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function md(s) { if (!s) return ''; var p = s.split('-'); return +p[2] + '/' + +p[1]; }                 // วัน/เดือน
    function dmy(s) { if (!s) return ''; var p = s.slice(0, 10).split('-'); return +p[2] + '/' + +p[1] + '/' + p[0]; }
    function num(v) { v = +v || 0; return v ? String(Math.round(v * 100) / 100) : ''; }
    function sign(by, at, users) { return by ? '<div class="sg"><b>' + esc((users && users[by]) || by) + '</b><small>' + dmy(at) + '</small></div>' : ''; }

    var CSS =
        '@page{size:A4 landscape;margin:10mm}' +
        'body{font-family:Sarabun,Tahoma,sans-serif;color:#000;margin:0;font-size:12px}' +
        '.sheet{page-break-after:always}.sheet:last-child{page-break-after:auto}' +
        'h1{font-size:16px;text-align:center;margin:0}h2{font-size:15px;text-align:center;margin:2px 0 8px}' +
        '.hd{display:flex;justify-content:space-between;gap:12px;margin:4px 0}.hd span{white-space:nowrap}.hd b{border-bottom:1px dotted #000;padding:0 6px;font-weight:600}' +
        'table{width:100%;border-collapse:collapse;table-layout:fixed}th,td{border:1px solid #000;padding:3px 4px;text-align:center;vertical-align:middle;word-wrap:break-word}' +
        'th{font-weight:600;font-size:11px}td{height:26px}td.l{text-align:left}.zh{display:block;font-weight:400;font-size:10px}' +
        '.sg b{display:block;font-size:11px}.sg small{font-size:9px}' +
        '.ft{display:flex;justify-content:space-between;margin-top:4px;font-size:10.5px}.note{font-size:10.5px;margin-top:4px;line-height:1.5}' +
        '.no{float:right;font-weight:600}.cut{border-top:1px dashed #666;margin:10px 0}' +
        '.bar{position:fixed;top:8px;right:8px}@media print{.bar{display:none}}';

    function open(title, body, landscape, extraCss) {
        var w = window.open('', '_blank');
        if (!w) { alert('Please allow pop-ups to print'); return; }
        w.document.write('<!doctype html><html><head><meta charset="utf-8"><title>' + esc(title) + '</title>' +
            '<link href="https://fonts.googleapis.com/css2?family=Sarabun:wght@400;600&display=swap" rel="stylesheet">' +
            '<style>' + (landscape ? CSS : CSS.replace('A4 landscape', 'A4 portrait')) + (extraCss || '') + '</style></head><body>' +
            '<div class="bar"><button onclick="window.print()">Print</button></div>' + body + '</body></html>');
        w.document.close();
        setTimeout(function () { try { w.focus(); w.print(); } catch (e) { } }, 600);
    }

    // ---------- ใบลา (บัตรบันทึกการลา) : 1 คน 1 ปี · 12 บรรทัด/แผ่น ----------
    function leaveCard(d, users) {
        var e = d.emp, bal = {}; (d.balance || []).forEach(function (b) { bal[b.type] = b; });
        var name = ((e.prefix || '') + (e.name_th || '')).trim() || e.name_en;
        var rows = d.leaves || [], pages = [];
        for (var i = 0; i < Math.max(1, rows.length); i += 12) pages.push(rows.slice(i, i + 12));
        var body = pages.map(function (pg, pi) {
            var tr = pg.map(function (l) {
                var c = { S: '', P: '', V: '', O: '', A: '', L: '' };
                c[l.leave_type] = l.leave_type === 'L' ? (l.hours ? num(l.hours) + ' ชม.' : '1') : num(l.days);
                var dt = l.date_from === l.date_to ? md(l.date_from) : md(l.date_from) + '-' + md(l.date_to);
                if (l.portion === 'am') dt += ' (เช้า)'; else if (l.portion === 'pm') dt += ' (บ่าย)'; else if (l.portion === 'hours') dt += ' (' + num(l.hours) + ' ชม.)';
                return '<tr><td>' + md(l.written_date || l.created_at) + '</td><td>' + dt + '</td><td class="l">' + esc(l.reason) + (l.med_cert ? ' <small>(มีใบรับรองแพทย์)</small>' : '') + '</td>' +
                    '<td>' + esc(name) + '</td><td>' + esc(l.substitute) + '</td>' +
                    ['S', 'P', 'V', 'O', 'A', 'L'].map(function (t) { return '<td>' + c[t] + '</td>'; }).join('') +
                    '<td>' + sign(l.sup_by, l.sup_at, users) + '</td><td>' + sign(l.appr_by, l.appr_at, users) + '</td><td>' + sign(l.hr_by, l.hr_at, users) + '</td></tr>';
            }).join('');
            for (var k = pg.length; k < 12; k++) tr += '<tr>' + new Array(15).join('<td></td>') + '</tr>';
            return '<div class="sheet"><h1>UNIVERSAL BASE GOLF BALL CO., LTD.</h1><h2>ใบลา 請假單 <span class="no">' + (pages.length > 1 ? 'แผ่นที่ ' + (pi + 1) + '/' + pages.length : '') + '</span></h2>' +
                '<div class="hd"><span>ปี 年份: <b>' + d.year + '</b></span><span>ชื่อ-สกุล 姓名 : <b>' + esc(name) + (e.nickname ? ' (' + esc(e.nickname) + ')' : '') + '</b></span><span>รหัส 編號: <b>' + esc(e.emp_code) + '</b></span></div>' +
                '<div class="hd"><span>VACATION จำนวนวันพักร้อน : <b>' + num(bal.V && bal.V.quota) + '</b></span><span>แผนก 部門: <b>' + esc(e.department) + (e.position ? ' / ' + esc(e.position) : '') + '</b></span><span>วันเริ่มงาน 入廠日期: <b>' + dmy(e.start_date) + '</b></span></div>' +
                '<table><colgroup><col style="width:6%"><col style="width:9%"><col style="width:17%"><col style="width:11%"><col style="width:7%">' +
                '<col style="width:3.5%"><col style="width:3.5%"><col style="width:3.5%"><col style="width:3.5%"><col style="width:3.5%"><col style="width:4%"><col style="width:9.5%"><col style="width:9.5%"><col style="width:9.5%"></colgroup>' +
                '<tr><th>วันที่เขียน<span class="zh">月/日</span></th><th>วันที่ลา<span class="zh">月/日</span></th><th>เหตุผลที่ลา<span class="zh">請假理由</span></th><th>ผู้ยื่นใบลา<span class="zh">請假人</span></th><th>ผู้ทำการแทน<span class="zh">代理人</span></th>' +
                '<th>S<span class="zh">病假</span></th><th>P<span class="zh">事假</span></th><th>V<span class="zh">年假</span></th><th>O<span class="zh">其他</span></th><th>A<span class="zh">曠工</span></th><th>L<span class="zh">遲</span></th>' +
                '<th>หัวหน้างาน<span class="zh">課長</span></th><th>ผู้อนุมัติ<span class="zh">核準者</span></th><th>ฝ่ายบุคคล<span class="zh">人事</span></th></tr>' + tr + '</table>' +
                '<div class="note">หมายเหตุ 備考: S: Sick ลาป่วย 病假 &nbsp; P: Personal ลากิจ 事假 &nbsp; V: Vacation ลาพักร้อน 年休假 &nbsp; O: Other อื่นๆ 其他 &nbsp; A: Absence ขาดงาน 曠工 &nbsp; L: Late สาย 慢<br>' +
                '1. ลาพักร้อน ต้องลาล่วงหน้า 3วัน &nbsp; 2.ลากิจ ต้องลาล่วงหน้า 3วัน &nbsp; 3.ลาป่วย ต้องมีใบรับรองแพทย์แผนปัจจุบันชั้นหนึ่งหรือของสถานพยาบาลทางราชการเท่านั้น</div>' +
                '<div class="ft"><span>พิมพ์จากระบบ HR ' + dmy(new Date().toISOString()) + '</span><span>UBG-FM-HR-09-A</span></div></div>';
        }).join('');
        open('Leave card ' + e.emp_code + ' ' + d.year, body, true);
    }

    // ---------- ใบขอ OT : 15 คน/ใบ · พิมพ์ 2 ส่วน (ใบที่ 1 ฝ่ายบุคคล / ใบที่ 2 แผนก) ----------
    function otForm(doc, emps, users) {
        var lines = doc.lines || [], chunks = [];
        for (var i = 0; i < Math.max(1, lines.length); i += 15) chunks.push(lines.slice(i, i + 15));
        var p = (doc.ot_date || '').split('-');
        function copy(ch, ci, part) {
            var tr = ch.map(function (l, k) {
                var e = emps[l.emp_code] || {};
                return '<tr><td>' + (ci * 15 + k + 1) + '</td><td>' + esc(l.emp_code) + '</td><td class="l">' + esc(e.name || '') + '</td><td>' + esc(l.time_from) + '</td><td>' + esc(l.time_to) + '</td><td class="l">' + esc(l.job) + '</td><td class="l">' + esc(l.remark) + '</td></tr>';
            }).join('');
            for (var k = ch.length; k < 15; k++) tr += '<tr><td>' + (ci * 15 + k + 1) + '</td><td></td><td></td><td></td><td></td><td></td><td></td></tr>';
            return '<h1>UNIVERSAL BASE GOLF BALL CO., LTD.</h1><h2>ใบขออนุมัติทำงานล่วงเวลา 加班申報單 <span class="no">' + esc(doc.doc_no) + (chunks.length > 1 ? ' (' + (ci + 1) + '/' + chunks.length + ')' : '') + '</span></h2>' +
                '<div class="hd"><span>แผนกขอทำโอที 加班單位: <b>' + esc(doc.department || '') + '</b></span><span>ปี 年 <b>' + (p[0] || '') + '</b> เดือน 月 <b>' + (+p[1] || '') + '</b> วันที่ 日 <b>' + (+p[2] || '') + '</b></span></div>' +
                '<table><colgroup><col style="width:6%"><col style="width:11%"><col style="width:23%"><col style="width:10%"><col style="width:10%"><col style="width:25%"><col style="width:15%"></colgroup>' +
                '<tr><th>ลำดับ<span class="zh">序號</span></th><th>รหัสพนักงาน<span class="zh">工號</span></th><th>ชื่อ - สกุลผู้ทำงาน<span class="zh">姓名</span></th><th>เวลาเข้างาน<span class="zh">加班時間</span></th><th>เวลาเลิกงาน<span class="zh">下班時間</span></th><th>รายละเอียดของงาน<span class="zh">工作明細</span></th><th>หมายเหตุ<span class="zh">備註</span></th></tr>' + tr + '</table>' +
                '<table style="margin-top:4px"><tr><th>ผู้ขอเปิดโอที<span class="zh">申 請 人</span></th><th>หัวหน้าแผนก<span class="zh">組 長</span></th><th>ฝ่ายบุคคล<span class="zh">人事</span></th><th>ผู้อนุมัติ<span class="zh">核 准</span></th></tr>' +
                '<tr><td style="height:40px">' + sign(doc.created_by, doc.created_at, users) + '</td><td>' + sign(doc.sup_by, doc.sup_at, users) + '</td><td>' + sign(doc.hr_by, doc.hr_at, users) + '</td><td>' + sign(doc.appr_by, doc.appr_at, users) + '</td></tr></table>' +
                '<div class="ft"><span>' + part + '</span><span>UBG-FM-HR-07-A</span></div>';
        }
        var body = chunks.map(function (ch, ci) {
            return '<div class="sheet">' + copy(ch, ci, 'ใบที่ 1 ฝ่ายบุคคล 第一連 人事') + '<div class="cut"></div>' + copy(ch, ci, 'ใบที่ 2 แผนกเปิดโอที 第二連 加班單位存根') + '</div>';
        }).join('');
        open('OT ' + doc.doc_no, body, false, 'td{height:19px;padding:1px 4px}h1{font-size:14px}h2{font-size:13px;margin:0 0 4px}@page{margin:8mm}');
    }

    return { leaveCard: leaveCard, otForm: otForm, esc: esc };
})();
