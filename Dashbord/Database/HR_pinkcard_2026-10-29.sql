-- UBG HR · Pink card (บัตรชมพู) number + expiry from PassWork.xlsx · 2026-10-29
-- Safe to run more than once. Only touches pink_no / pink_exp.
SET NAMES utf8mb4;
SET @s = (SELECT IF(COUNT(*) = 0, 'ALTER TABLE hr_employee ADD COLUMN pink_no VARCHAR(30) NULL', 'DO 0') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hr_employee' AND COLUMN_NAME = 'pink_no');
PREPARE x FROM @s; EXECUTE x; DEALLOCATE PREPARE x;
SET @s = (SELECT IF(COUNT(*) = 0, 'ALTER TABLE hr_employee ADD COLUMN pink_exp DATE NULL', 'DO 0') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hr_employee' AND COLUMN_NAME = 'pink_exp');
PREPARE x FROM @s; EXECUTE x; DEALLOCATE PREPARE x;

UPDATE hr_employee SET pink_no = '0020021482993', pink_exp = '2035-11-10', updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0099';
UPDATE hr_employee SET pink_no = '0020021489441', pink_exp = '2036-03-29', updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0108';
UPDATE hr_employee SET pink_no = '0020021489459', pink_exp = '2036-03-29', updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0209';
UPDATE hr_employee SET pink_no = '0020021489441', pink_exp = '2036-03-29', updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0210';
UPDATE hr_employee SET pink_no = '0020021489475', pink_exp = '2036-03-29', updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0211';
UPDATE hr_employee SET pink_no = '0020021489491', pink_exp = '2036-03-29', updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0212';
UPDATE hr_employee SET pink_no = '0020021489505', pink_exp = '2036-03-29', updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0213';
UPDATE hr_employee SET pink_no = '0020021489513', pink_exp = '2036-03-29', updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0218';
UPDATE hr_employee SET pink_no = '0020021489521', pink_exp = '2036-03-29', updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0219';
UPDATE hr_employee SET pink_no = '0020021489530', pink_exp = '2036-03-29', updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0220';
UPDATE hr_employee SET pink_no = '0020021489572', pink_exp = '2036-03-29', updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0222';
UPDATE hr_employee SET pink_no = '0020021489581', pink_exp = '2036-03-29', updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0223';
UPDATE hr_employee SET pink_no = '0020021489483', pink_exp = '2036-03-29', updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0229';
UPDATE hr_employee SET pink_no = '0020871008394', pink_exp = '2032-12-27', updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0255';
UPDATE hr_employee SET pink_no = '0020021519056', pink_exp = pink_exp, updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0348';
UPDATE hr_employee SET pink_no = '0074016060931', pink_exp = pink_exp, updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0353';
UPDATE hr_employee SET pink_no = '0021081316691', pink_exp = pink_exp, updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0357';
UPDATE hr_employee SET pink_no = '0050701014580', pink_exp = pink_exp, updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0363';
UPDATE hr_employee SET pink_no = '0020821049364', pink_exp = pink_exp, updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0369';
UPDATE hr_employee SET pink_no = '0020801446121', pink_exp = pink_exp, updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0375';
UPDATE hr_employee SET pink_no = '0010491732007', pink_exp = pink_exp, updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0376';
UPDATE hr_employee SET pink_no = '0020021518513', pink_exp = pink_exp, updated_at = NOW(), updated_by = 'import' WHERE emp_code = 'U-0377';

SELECT COUNT(*) AS with_pink_no, SUM(pink_exp IS NOT NULL) AS with_pink_exp FROM hr_employee WHERE pink_no IS NOT NULL;
