-- =====================================================================
-- ลบข้อมูลน้ำหนักที่ไม่เกิน 1.0 g ออกจากตาราง weight_log (หน้า WeightLog.aspx)
-- phpMyAdmin -> ฐานข้อมูล OEE -> แท็บ SQL -> วางทั้งไฟล์ -> Go
--   1) ดูก่อนว่าจะลบกี่แถว  2) ลบ  3) ตรวจซ้ำ (ต้องได้ 0)
-- หน่วย kg แปลงเป็นกรัมก่อนเทียบ (0.001 kg = 1 g)
-- ** ลบแล้วกู้คืนไม่ได้ **
-- =====================================================================
USE `OEE`;

-- 1) ดูก่อน: จำนวนแถวที่จะถูกลบ แยกตามเครื่อง
SELECT machine_code, COUNT(*) AS rows_to_delete, MIN(weight) AS min_w, MAX(weight) AS max_w
  FROM weight_log
 WHERE (CASE WHEN LOWER(unit) = 'kg' THEN weight * 1000 ELSE weight END) <= 1.0
 GROUP BY machine_code;

-- 2) ลบ
DELETE FROM weight_log
 WHERE (CASE WHEN LOWER(unit) = 'kg' THEN weight * 1000 ELSE weight END) <= 1.0;

-- 3) ตรวจซ้ำ (ต้องได้ 0)
SELECT COUNT(*) AS remaining_under_1g
  FROM weight_log
 WHERE (CASE WHEN LOWER(unit) = 'kg' THEN weight * 1000 ELSE weight END) <= 1.0;
