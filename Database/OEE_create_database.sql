-- =====================================================================
--  OEE Database : เก็บข้อมูลเครื่องจักรจาก HMI (Node-RED -> CounterMachine.aspx)
--  สำหรับ MySQL 5.7+ / MariaDB 10.3+  (phpMyAdmin : แท็บ Import หรือ SQL)
-- =====================================================================

CREATE DATABASE IF NOT EXISTS `OEE`
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `OEE`;

-- ---------------------------------------------------------------------
-- 1) machine : ข้อมูลหลักของเครื่อง (ชื่อ Node-RED -> รหัสเครื่อง / Process)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `machine` (
  `machine_code`  VARCHAR(20)  NOT NULL COMMENT 'ชื่อที่ Node-RED ส่งมา เช่น MC13',
  `machine_no`    VARCHAR(40)  NOT NULL COMMENT 'รหัสเครื่อง เช่น UB-MC-PV-1-3',
  `process`       VARCHAR(40)  NOT NULL DEFAULT 'Injection',
  `cavities`      TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `std_cycle_sec` DECIMAL(6,1) NULL COMMENT 'Cycle time มาตรฐาน (ไว้คำนวณ Performance)',
  `hmi_ip`        VARCHAR(45)  NULL,
  `is_active`     TINYINT(1)   NOT NULL DEFAULT 1,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`machine_code`),
  UNIQUE KEY `uk_machine_no` (`machine_no`),
  KEY `ix_process` (`process`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='ข้อมูลหลักเครื่องจักร';

-- ---------------------------------------------------------------------
-- 2) status_code : ความหมายรหัสสถานะจาก HMI (register 32884)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `status_code` (
  `code`      TINYINT UNSIGNED NOT NULL,
  `text`      VARCHAR(40) NOT NULL,
  `category`  ENUM('run','idle','down','off') NOT NULL COMMENT 'run=Operating, idle/down=Loss',
  PRIMARY KEY (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='รหัสสถานะเครื่อง';

-- ---------------------------------------------------------------------
-- 3) mc_daily : สรุปรายวันต่อเครื่อง (1 แถว / เครื่อง / วันผลิต 08:00-08:00)
--    อัปเดตทุก 1 นาที และใช้โหลดยอดกลับเมื่อ IIS restart
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mc_daily` (
  `prod_day`        DATE         NOT NULL COMMENT 'วันผลิต (เริ่ม 08:00)',
  `machine_code`    VARCHAR(20)  NOT NULL,
  `count_start`     DATETIME     NOT NULL COMMENT 'เวลาเริ่มนับของวัน',
  `operating_sec`   INT UNSIGNED NOT NULL DEFAULT 0,
  `loss_sec`        INT UNSIGNED NOT NULL DEFAULT 0,
  `offline_sec`     INT UNSIGNED NOT NULL DEFAULT 0,
  `shots_today`     INT UNSIGNED NOT NULL DEFAULT 0,
  `pieces_today`    INT UNSIGNED NOT NULL DEFAULT 0,
  `last_counter`    INT UNSIGNED NULL COMMENT 'Counter ล่าสุดจาก HMI',
  `last_cycle_sec`  DECIMAL(6,1) NULL,
  `last_status`     TINYINT UNSIGNED NULL,
  `last_operator`   VARCHAR(40)  NULL,
  `availability`    DECIMAL(5,2) NULL COMMENT '% = operating / (operating+loss+offline)',
  `updated_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`prod_day`, `machine_code`),
  KEY `ix_machine_day` (`machine_code`, `prod_day`),
  CONSTRAINT `fk_daily_machine` FOREIGN KEY (`machine_code`) REFERENCES `machine` (`machine_code`)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='สรุปรายวัน (Operating/Loss/Shots)';

-- ---------------------------------------------------------------------
-- 4) mc_hourly : ยอดรายชั่วโมง (กราฟ Shots/hour, ย้อนหลังได้)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mc_hourly` (
  `machine_code`   VARCHAR(20)  NOT NULL,
  `hour_start`     DATETIME     NOT NULL COMMENT 'ต้นชั่วโมง เช่น 2026-10-06 09:00:00',
  `prod_day`       DATE         NOT NULL,
  `shots`          INT UNSIGNED NOT NULL DEFAULT 0,
  `operating_sec`  INT UNSIGNED NOT NULL DEFAULT 0,
  `loss_sec`       INT UNSIGNED NOT NULL DEFAULT 0,
  `offline_sec`    INT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`machine_code`, `hour_start`),
  KEY `ix_prod_day` (`prod_day`),
  CONSTRAINT `fk_hourly_machine` FOREIGN KEY (`machine_code`) REFERENCES `machine` (`machine_code`)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='ยอดรายชั่วโมง';

-- ---------------------------------------------------------------------
-- 5) mc_status_log : ประวัติการเปลี่ยนสถานะ (Downtime Analysis)
--    end_time = NULL คือสถานะที่ยังเป็นอยู่ตอนนี้
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mc_status_log` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `machine_code`  VARCHAR(20)  NOT NULL,
  `prod_day`      DATE         NOT NULL,
  `status_code`   TINYINT UNSIGNED NULL COMMENT 'NULL = Offline',
  `category`      ENUM('run','idle','down','off') NOT NULL,
  `start_time`    DATETIME     NOT NULL,
  `end_time`      DATETIME     NULL,
  `duration_sec`  INT UNSIGNED NULL,
  `counter_start` INT UNSIGNED NULL,
  `counter_end`   INT UNSIGNED NULL,
  `operator`      VARCHAR(40)  NULL,
  `reason`        VARCHAR(100) NULL COMMENT 'สาเหตุการหยุด (กรอกภายหลังได้)',
  PRIMARY KEY (`id`),
  KEY `ix_machine_start` (`machine_code`, `start_time`),
  KEY `ix_day_category` (`prod_day`, `category`),
  KEY `ix_open` (`machine_code`, `end_time`),
  CONSTRAINT `fk_log_machine` FOREIGN KEY (`machine_code`) REFERENCES `machine` (`machine_code`)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='ประวัติสถานะเครื่อง';

-- ---------------------------------------------------------------------
-- 6) mc_snapshot : ค่าทุกเครื่องทุก 1 นาที (ย้อนดูละเอียด / ตรวจสอบ)
--    ~20,000 แถว/วัน สำหรับ 14 เครื่อง
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mc_snapshot` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ts`            DATETIME     NOT NULL,
  `machine_code`  VARCHAR(20)  NOT NULL,
  `online`        TINYINT(1)   NOT NULL DEFAULT 1,
  `status_code`   TINYINT UNSIGNED NULL,
  `category`      ENUM('run','idle','down','off') NOT NULL,
  `counter`       INT UNSIGNED NULL COMMENT 'Counter (Shot) จาก HMI',
  `shots_today`   INT UNSIGNED NULL,
  `target_shots`  INT UNSIGNED NULL,
  `cycle_sec`     DECIMAL(6,1) NULL,
  `operator`      VARCHAR(40)  NULL,
  `job_start`     DATETIME     NULL,
  `job_finish`    DATETIME     NULL,
  PRIMARY KEY (`id`),
  KEY `ix_machine_ts` (`machine_code`, `ts`),
  KEY `ix_ts` (`ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Snapshot ทุก 1 นาที';

-- ---------------------------------------------------------------------
-- ข้อมูลเริ่มต้น
-- ---------------------------------------------------------------------
INSERT INTO `status_code` (`code`, `text`, `category`) VALUES
  (0,  'Idle',             'idle'),
  (1,  'Manual',           'idle'),
  (2,  'Semi-Auto',        'run'),
  (4,  'Auto',             'run'),
  (8,  'Adj. Mould',       'idle'),
  (17, 'Manual Error',     'down'),
  (18, 'Semi-Auto Error',  'down'),
  (19, 'Adj. Mould Error', 'down'),
  (20, 'Auto Error',       'down')
ON DUPLICATE KEY UPDATE `text` = VALUES(`text`), `category` = VALUES(`category`);

INSERT INTO `machine` (`machine_code`, `machine_no`, `process`) VALUES
  ('MC13', 'UB-MC-PV-1-3', 'Injection'),
  ('MC14', 'UB-MC-PV-1-4', 'Injection'),
  ('MC15', 'UB-MC-PV-1-5', 'Injection'),
  ('MC16', 'UB-MC-PV-1-6', 'Injection'),
  ('MC17', 'UB-MC-PV-1-7', 'Injection'),
  ('MC18', 'UB-MC-PV-1-8', 'Injection'),
  ('MC21', 'UB-MC-PV-2-1', 'Injection'),
  ('MC22', 'UB-MC-PV-2-2', 'Injection'),
  ('MC23', 'UB-MC-PV-2-3', 'Injection'),
  ('MC24', 'UB-MC-PV-2-4', 'Injection'),
  ('MC25', 'UB-MC-PV-2-5', 'Injection'),
  ('MC26', 'UB-MC-PV-2-6', 'Injection'),
  ('MC27', 'UB-MC-PV-1-1', 'Injection'),
  ('MC28', 'UB-MC-PV-2-8', 'Injection'),
  ('MC7',  'UB-MC-PV-2-7', 'Injection'),
  ('MC12', 'UB-MC-PV-1-2', 'Injection')
ON DUPLICATE KEY UPDATE `machine_no` = VALUES(`machine_no`), `process` = VALUES(`process`);

-- ---------------------------------------------------------------------
-- View : สรุปรายวัน แสดงเป็นชั่วโมง (เหมือนหน้าจอ)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW `v_mc_daily` AS
SELECT
  d.`prod_day`,
  d.`machine_code`,
  m.`machine_no`,
  m.`process`,
  d.`count_start`,
  ROUND(d.`operating_sec` / 3600, 4) AS `operating_hours`,
  ROUND(d.`loss_sec` / 3600, 4)      AS `loss_hours`,
  ROUND(d.`offline_sec` / 3600, 4)   AS `offline_hours`,
  d.`shots_today`,
  d.`pieces_today`,
  d.`availability`,
  d.`last_counter`,
  d.`updated_at`
FROM `mc_daily` d
JOIN `machine` m ON m.`machine_code` = d.`machine_code`;

-- View : Downtime (Idle / Breakdown) พร้อมระยะเวลาเป็นนาที
CREATE OR REPLACE VIEW `v_mc_downtime` AS
SELECT
  l.`id`, l.`prod_day`, l.`machine_code`, m.`machine_no`, m.`process`,
  l.`category`, l.`status_code`, s.`text` AS `status_text`,
  l.`start_time`, l.`end_time`,
  ROUND(COALESCE(l.`duration_sec`, TIMESTAMPDIFF(SECOND, l.`start_time`, NOW())) / 60, 1) AS `duration_min`,
  l.`reason`
FROM `mc_status_log` l
JOIN `machine` m ON m.`machine_code` = l.`machine_code`
LEFT JOIN `status_code` s ON s.`code` = l.`status_code`
WHERE l.`category` IN ('idle', 'down');

-- =====================================================================
-- (แนะนำ) user สำหรับหน้าเว็บ แทนการใช้ root
--   1) เปลี่ยน 'ตั้งรหัสผ่านใหม่ที่นี่' เป็นรหัสที่ต้องการ
--   2) '192.168.100.20' = เครื่อง IIS ที่จะเชื่อมต่อเข้ามา
--   ถ้ายังไม่ต้องการ ให้ลบ 3 บรรทัดด้านล่างออกก่อนรัน
-- =====================================================================
CREATE USER IF NOT EXISTS 'oee_app'@'192.168.100.20' IDENTIFIED BY 'ตั้งรหัสผ่านใหม่ที่นี่';
GRANT SELECT, INSERT, UPDATE, DELETE ON `OEE`.* TO 'oee_app'@'192.168.100.20';
FLUSH PRIVILEGES;
