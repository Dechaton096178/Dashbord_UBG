using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace Dashbord
{
    /// <summary>
    /// เชื่อมใบขอ OT + ใบลา กับเวลาสแกน (Time Attendance)
    ///   OT ที่จ่ายได้ = ช่วงเวลา OT ที่ขอ ∩ เวลาที่อยู่จริง (สแกนเข้า-ออก) ปัดลงตาม Settings
    /// </summary>
    public static class OtCalc
    {
        public class LineInfo
        {
            public long DocId, LineId; public string Doc, Status, Dept, Emp, Scan, From, To, Job, Remark;
            public DateTime Date, WinStart, WinEnd;
            public int ApprMin, PayMin;
            public DateTime? In, Out;
            public string Flag;   // "" ok · noscan ไม่ได้มา · noout ไม่มีสแกนออก · short ทำไม่ครบ
        }

        /// <summary>ทุกบรรทัดในใบขอ OT ช่วงวันที่ (ไม่รวมใบที่ไม่อนุมัติ / ยกเลิก) + เทียบกับเวลาสแกน</summary>
        public static List<LineInfo> Lines(DateTime from, DateTime to, List<TaSession> sessions, TaConfig cfg)
        {
            var bySc = sessions.GroupBy(s => s.ScanId).ToDictionary(g => g.Key, g => g.ToList());
            var result = new List<LineInfo>();
            foreach (var doc in OeeDb.OtList(from, to, null))
            {
                string st = Convert.ToString(doc["status"]);
                if (st == "rejected" || st == "cancelled") continue;
                DateTime day = DateTime.ParseExact(Convert.ToString(doc["ot_date"]), "yyyy-MM-dd", CultureInfo.InvariantCulture);
                foreach (var l in (List<Dictionary<string, object>>)doc["lines"])
                {
                    var x = new LineInfo
                    {
                        DocId = (long)doc["id"], LineId = (long)l["id"], Doc = Convert.ToString(doc["doc_no"]), Status = st, Dept = Convert.ToString(doc["department"]),
                        Emp = Convert.ToString(l["emp_code"]), From = Convert.ToString(l["time_from"]), To = Convert.ToString(l["time_to"]),
                        Job = Convert.ToString(l["job"]), Remark = Convert.ToString(l["remark"]), Date = day,
                    };
                    x.Scan = TaCalc.ScanKey(x.Emp);
                    DateTime a, b;
                    if (!HrFlow.OtWindow(day, x.From, x.To, out a, out b)) continue;
                    x.WinStart = a; x.WinEnd = b; x.ApprMin = (int)(b - a).TotalMinutes;
                    // รอบทำงานที่ทับช่วง OT มากที่สุด
                    List<TaSession> ss; TaSession best = null; double bestOv = -1;
                    if (x.Scan != null && bySc.TryGetValue(x.Scan, out ss))
                        foreach (var s in ss)
                        {
                            DateTime end = s.Out ?? s.In;
                            double ov = Overlap(a, b, s.In, end);
                            bool near = s.WorkDate == day || (s.In <= b && end >= a);
                            if (near && ov > bestOv) { bestOv = ov; best = s; }
                        }
                    if (best == null) x.Flag = "noscan";
                    else
                    {
                        x.In = best.In; x.Out = best.Out;
                        if (best.Out == null) x.Flag = best.Working ? "working" : "noout";
                        else
                        {
                            int ov = (int)Overlap(a, b, best.In, best.Out.Value);
                            x.PayMin = ov / cfg.OtRoundMin * cfg.OtRoundMin;
                            x.Flag = x.PayMin < x.ApprMin ? "short" : "";
                        }
                    }
                    result.Add(x);
                }
            }
            return result;
        }

        static double Overlap(DateTime a, DateTime b, DateTime c, DateTime d)
        {
            DateTime s = a > c ? a : c, e = b < d ? b : d;
            return e > s ? (e - s).TotalMinutes : 0;
        }

        // ------------------------------------------------------------ ใบลา : วันไหนใครลา
        public class LeaveDay { public string Type, Portion, Status, Doc; public double Days; }

        /// <summary>key = emp|yyyy-MM-dd · เฉพาะวันทำงาน · ไม่รวมใบไม่อนุมัติ / ยกเลิก</summary>
        public static Dictionary<string, LeaveDay> LeaveDays(DateTime from, DateTime to, TaConfig cfg)
        {
            var map = new Dictionary<string, LeaveDay>(StringComparer.OrdinalIgnoreCase);
            foreach (var l in OeeDb.LeaveList(from, to, null))
            {
                string st = Convert.ToString(l["status"]);
                if (st == "rejected" || st == "cancelled") continue;
                DateTime a = DateTime.ParseExact(Convert.ToString(l["date_from"]), "yyyy-MM-dd", CultureInfo.InvariantCulture);
                DateTime b = DateTime.ParseExact(Convert.ToString(l["date_to"]), "yyyy-MM-dd", CultureInfo.InvariantCulture);
                string portion = Convert.ToString(l["portion"]);
                double per = portion == "full" ? 1 : portion == "hours" ? Convert.ToDouble(l["days"]) : 0.5;
                for (DateTime d = a > from ? a : from; d <= b && d <= to; d = d.AddDays(1))
                {
                    if (portion == "full" && !cfg.IsWorkDay(d)) continue;
                    string k = Convert.ToString(l["emp_code"]) + "|" + d.ToString("yyyy-MM-dd");
                    LeaveDay old;
                    if (map.TryGetValue(k, out old) && old.Status == "approved" && st != "approved") continue;   // ใบที่อนุมัติแล้วชนะ
                    map[k] = new LeaveDay { Type = Convert.ToString(l["leave_type"]), Portion = portion, Status = st, Doc = Convert.ToString(l["doc_no"]), Days = per };
                }
            }
            return map;
        }
    }
}
