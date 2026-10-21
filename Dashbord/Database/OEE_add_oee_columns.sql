-- =====================================================================
-- OEE : เพิ่มคอลัมน์ A x P x Q = OEE ในตาราง mc_daily
-- รันครั้งเดียวใน phpMyAdmin (เลือกฐานข้อมูล OEE -> แท็บ SQL -> วาง -> Go)
-- หน้าเว็บตรวจเองอัตโนมัติ: ถ้ายังไม่รัน จะบันทึกแบบเดิม (ไม่มี P / Q / OEE)
-- =====================================================================
USE `OEE`;

ALTER TABLE `mc_daily`
  ADD COLUMN `performance`   DECIMAL(5,2) NULL COMMENT '% = shots_today x std_cycle_sec / operating_sec'   AFTER `availability`,
  ADD COLUMN `quality`       DECIMAL(5,2) NULL COMMENT '% = ok_today / (ok_today + ng_today)  (NULL = ยังไม่มีข้อมูล NG)' AFTER `performance`,
  ADD COLUMN `oee`           DECIMAL(5,2) NULL COMMENT '% = A x P x Q  (Q ว่าง -> คิด 100%)'             AFTER `quality`,
  ADD COLUMN `ok_today`      INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'ชิ้นดีวันนี้'                    AFTER `oee`,
  ADD COLUMN `ng_today`      INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'ชิ้นเสียวันนี้'                  AFTER `ok_today`,
  ADD COLUMN `std_cycle_sec` DECIMAL(6,2) NULL COMMENT 'Std CT ที่ใช้คิด Performance วันนั้น'          AFTER `ng_today`;

-- ให้ machine.std_cycle_sec เก็บทศนิยม 2 ตำแหน่ง (เช่น 1.25 วินาที)
ALTER TABLE `machine` MODIFY `std_cycle_sec` DECIMAL(6,2) NULL COMMENT 'Cycle time มาตรฐาน (วินาที/shot) ใช้คำนวณ Performance';

-- View สรุป OEE รายวัน
CREATE OR REPLACE VIEW `v_mc_oee` AS
SELECT
  d.`prod_day`, d.`machine_code`, m.`machine_no`, m.`process`,
  ROUND(d.`operating_sec` / 3600, 2) AS `operating_hours`,
  ROUND((d.`loss_sec` + d.`offline_sec`) / 3600, 2) AS `loss_hours`,
  d.`shots_today`, d.`ok_today`, d.`ng_today`, d.`std_cycle_sec`,
  d.`availability` AS `A`, d.`performance` AS `P`, d.`quality` AS `Q`, d.`oee` AS `OEE`,
  d.`updated_at`
FROM `mc_daily` d
JOIN `machine` m ON m.`machine_code` = d.`machine_code`;

-- ---------------------------------------------------------------------
-- ตั้ง Std CT (วินาที/shot) ของแต่ละเครื่อง -> ใช้คิด Performance
-- แก้ตัวเลขให้ตรงมาตรฐานจริง แล้วรันเฉพาะบรรทัดที่ต้องการ (มีผลภายใน 1 นาที)
-- ---------------------------------------------------------------------
-- UPDATE `machine` SET `std_cycle_sec` = 30.0 WHERE `machine_code` = 'MC27';
-- UPDATE `machine` SET `std_cycle_sec` = 30.0 WHERE `machine_code` = 'MC12';
-- UPDATE `machine` SET `std_cycle_sec` = 1.20 WHERE `machine_code` = 'SB01';
-- ดูรายการเครื่องทั้งหมด:  SELECT machine_code, machine_no, process, std_cycle_sec FROM machine ORDER BY process, machine_code;
