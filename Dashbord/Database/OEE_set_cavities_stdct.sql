-- =====================================================================
-- ตั้งค่า Cavities (ชิ้น/shot) และ Std CT (วินาที/shot) ของแต่ละเครื่อง
-- ใช้ทั้ง MC Monitor และ OEE Dashboard  (มีผลภายใน 1 นาที ไม่ต้อง restart)
-- phpMyAdmin -> ฐานข้อมูล OEE -> แท็บ SQL -> แก้ตัวเลข ?? ให้ถูก -> Go
--   cavities      = 1 shot ได้กี่ลูก (ดูจากแม่พิมพ์ เช่น "8 cav")
--   std_cycle_sec = เวลามาตรฐานต่อ 1 shot (วินาที)
-- =====================================================================
USE `OEE`;

-- ดูค่าปัจจุบัน
SELECT machine_code, machine_no, process, cavities, std_cycle_sec FROM machine ORDER BY process, machine_code;

-- ---------- Injection (แก้ ?? เป็นค่าจริง แล้วเอา -- หน้าบรรทัดออก) ----------
-- UPDATE machine SET machine_no='UB-MC-PV-1-1', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC27';
-- UPDATE machine SET machine_no='UB-MC-PV-1-2', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC12';
-- UPDATE machine SET machine_no='UB-MC-PV-1-3', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC13';
-- UPDATE machine SET machine_no='UB-MC-PV-1-4', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC14';
-- UPDATE machine SET machine_no='UB-MC-PV-1-5', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC15';
-- UPDATE machine SET machine_no='UB-MC-PV-1-6', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC16';
-- UPDATE machine SET machine_no='UB-MC-PV-1-7', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC17';
-- UPDATE machine SET machine_no='UB-MC-PV-1-8', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC18';
-- UPDATE machine SET machine_no='UB-MC-PV-2-1', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC21';
-- UPDATE machine SET machine_no='UB-MC-PV-2-2', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC22';
-- UPDATE machine SET machine_no='UB-MC-PV-2-3', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC23';
-- UPDATE machine SET machine_no='UB-MC-PV-2-4', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC24';
-- UPDATE machine SET machine_no='UB-MC-PV-2-5', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC25';
-- UPDATE machine SET machine_no='UB-MC-PV-2-6', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC26';
-- UPDATE machine SET machine_no='UB-MC-PV-2-7', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC7';
-- UPDATE machine SET machine_no='UB-MC-PV-2-8', cavities=??, std_cycle_sec=45.0 WHERE machine_code='MC28';

-- ---------- Seambuffing (นับเป็นลูกอยู่แล้ว -> cavities = 1) ----------
-- UPDATE machine SET machine_no='UB-MC-SF-004', process='Seambuffing', cavities=1, std_cycle_sec=1.20 WHERE machine_code='SB04';   -- Seambuffing 4 (เดิม SB01)
-- UPDATE machine SET machine_no='UB-MC-SF-002', process='Seambuffing', cavities=1, std_cycle_sec=1.20 WHERE machine_code='SB02';
-- UPDATE machine SET machine_no='UB-MC-SF-003', process='Seambuffing', cavities=1, std_cycle_sec=1.20 WHERE machine_code='SB03';
