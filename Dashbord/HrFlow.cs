using System;
using System.Collections.Generic;
using System.Linq;

namespace Dashbord
{
    // =========================================================
    // ใบลา (UBG-FM-HR-09) / ใบขอ OT (UBG-FM-HR-07) : ค่าตั้ง + ขั้นตอนอนุมัติ
    // =========================================================
    public class LeaveConfig
    {
        public double SickDays = 30;          // ลาป่วย (ได้ค่าจ้าง) วัน/ปี
        public double PersonalDays = 3;       // ลากิจ วัน/ปี
        public double VacationDays = 6;       // ลาพักร้อน วัน/ปี (เมื่อทำงานครบตามเดือนด้านล่าง)
        public int VacationAfterMonths = 12;  // ทำงานครบกี่เดือนถึงได้พักร้อน
        public double HoursPerDay = 8;        // ลาเป็นชั่วโมง : กี่ชั่วโมง = 1 วัน
        public int AdvanceDays = 3;           // ลาพักร้อน / ลากิจ ต้องลาล่วงหน้ากี่วัน
        public int SickCertDays = 1;          // ลาป่วยตั้งแต่กี่วัน ต้องมีใบรับรองแพทย์ (ตามใบลา = ทุกครั้ง)

        public static LeaveConfig Fix(LeaveConfig c)
        {
            c = c ?? new LeaveConfig();
            c.SickDays = Clamp(c.SickDays, 0, 365); c.PersonalDays = Clamp(c.PersonalDays, 0, 365); c.VacationDays = Clamp(c.VacationDays, 0, 365);
            c.VacationAfterMonths = (int)Clamp(c.VacationAfterMonths, 0, 120); c.HoursPerDay = Clamp(c.HoursPerDay, 1, 24);
            c.AdvanceDays = (int)Clamp(c.AdvanceDays, 0, 60); c.SickCertDays = (int)Clamp(c.SickCertDays, 0, 60);
            return c;
        }
        static double Clamp(double v, double a, double b) { return v < a ? a : v > b ? b : v; }

        /// <summary>สิทธิ์ตั้งต้นของปีนั้น (ยังไม่ได้แก้รายคน)</summary>
        public double DefaultQuota(string type, DateTime? startDate, int year)
        {
            if (type == "S") return SickDays;
            if (type == "P") return PersonalDays;
            if (type == "V")
            {
                if (!startDate.HasValue) return VacationDays;
                DateTime eligible = startDate.Value.AddMonths(VacationAfterMonths);
                return eligible <= new DateTime(year, 12, 31) ? VacationDays : 0;   // ครบกำหนดภายในปีนั้น = ได้สิทธิ์
            }
            return 0;
        }
    }

    public static class HrFlow
    {
        // ประเภทลา ตามใบลา : S ลาป่วย · P ลากิจ · V ลาพักร้อน · O อื่น ๆ · A ขาดงาน · L สาย
        public static readonly string[] LEAVE_TYPES = { "S", "P", "V", "O", "A", "L" };
        public static readonly Dictionary<string, string> LEAVE_NAMES = new Dictionary<string, string> {
            { "S", "Sick · ลาป่วย" }, { "P", "Personal · ลากิจ" }, { "V", "Vacation · ลาพักร้อน" },
            { "O", "Other · อื่น ๆ" }, { "A", "Absence · ขาดงาน" }, { "L", "Late · สาย" } };
        /// <summary>A / L = HR บันทึก ไม่ใช่การขอลา</summary>
        public static bool HrOnlyType(string t) { return t == "A" || t == "L"; }

        // ขั้นตอนเซ็น ตามช่องในใบ : ใบลา = หัวหน้างาน → ผู้อนุมัติ → ฝ่ายบุคคล · ใบ OT = หัวหน้าแผนก → ฝ่ายบุคคล → ผู้อนุมัติ
        public static readonly string[] LEAVE_STEPS = { "sup", "appr", "hr" };
        public static readonly string[] OT_STEPS = { "sup", "hr", "appr" };
        public static readonly Dictionary<string, string> STEP_NAMES = new Dictionary<string, string> {
            { "sup", "Leader · หัวหน้า" }, { "appr", "Approver · ผู้อนุมัติ" }, { "hr", "HR · ฝ่ายบุคคล" } };

        /// <summary>ใครเซ็นช่องไหนได้ (admin เซ็นได้ทุกช่อง)</summary>
        public static bool CanSign(HrSessionUser u, string step, string dept)
        {
            if (u == null) return false;
            if (u.IsAdmin) return true;
            switch (step)
            {
                case "sup": return u.Role == "hr" || ((u.Role == "supervisor" || u.Role == "manager") && u.InScope(dept));
                case "appr": return u.Role == "manager" && u.InScope(dept);
                case "hr": return u.Role == "hr";
            }
            return false;
        }

        /// <summary>จำนวนวันลา : นับเฉพาะวันทำงาน (ตาม Settings ของ Time Attendance) · ครึ่งวัน = 0.5 · ชั่วโมง = ชม. / ชม.ต่อวัน</summary>
        public static double LeaveDays(DateTime from, DateTime to, string portion, double hours, TaConfig ta, LeaveConfig lc)
        {
            if (to < from) throw new Exception("วันสิ้นสุดต้องไม่ก่อนวันเริ่ม");
            if (portion == "am" || portion == "pm")
            {
                if (from != to) throw new Exception("ลาครึ่งวัน เลือกได้วันเดียว");
                return 0.5;
            }
            if (portion == "hours")
            {
                if (from != to) throw new Exception("ลาเป็นชั่วโมง เลือกได้วันเดียว");
                if (hours <= 0 || hours > 24) throw new Exception("ใส่จำนวนชั่วโมง");
                return Math.Round(hours / lc.HoursPerDay, 2);
            }
            if ((to - from).TotalDays > 366) throw new Exception("ช่วงวันลายาวเกินไป");
            int n = 0;
            for (DateTime d = from; d <= to; d = d.AddDays(1)) if (ta.IsWorkDay(d)) n++;
            return n;
        }

        public static int Minutes(string hm)
        {
            var p = (hm ?? "").Split(':');
            int h, m;
            if (p.Length != 2 || !int.TryParse(p[0], out h) || !int.TryParse(p[1], out m) || h > 23 || m > 59 || h < 0 || m < 0) return -1;
            return h * 60 + m;
        }

        /// <summary>ช่วงเวลา OT (ข้ามเที่ยงคืนได้) เป็น DateTime ของวันนั้น</summary>
        public static bool OtWindow(DateTime day, string from, string to, out DateTime a, out DateTime b)
        {
            int x = Minutes(from), y = Minutes(to);
            a = day.AddMinutes(Math.Max(0, x)); b = day.AddMinutes(Math.Max(0, y));
            if (x < 0 || y < 0) return false;
            if (y <= x) b = b.AddDays(1);
            return true;
        }
    }
}
