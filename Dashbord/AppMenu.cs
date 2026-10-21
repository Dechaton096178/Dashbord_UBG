using System;
using System.Collections.Generic;

namespace Dashbord
{
    // =========================================================
    // AppMenu : เมนูของทั้งระบบ (ใช้ร่วมกัน Site.Master + Default.aspx)
    //   แยกเป็นไฟล์ของตัวเอง ไม่ผูกกับ class SiteMaster
    // =========================================================
    public static class AppMenu
    {
        // =========================================================
        // โครงสร้างเมนู (แก้ที่นี่ที่เดียว)
        //   Url = null  -> ยังไม่มีหน้า แสดงเป็น "Soon"
        //   เพิ่มหน้าใหม่ : ใส่ชื่อไฟล์ .aspx ใน Url ของเมนูนั้น
        // =========================================================
        public class MenuItem
        {
            public string Title;
            public string Url;
            public List<MenuItem> Children;      // เมนูย่อย (กดแล้วกางออก)
            public MenuItem(string title, string url) { Title = title; Url = url; }
            public MenuItem(string title, string url, List<MenuItem> children) : this(title, url) { Children = children; }
            public bool HasChildren { get { return Children != null && Children.Count > 0; } }
        }

        // =========================================================
        // Process ของหน้า MC Monitor (CounterMachine.aspx?proc=...)
        // ต้องตรงกับ PROCESSES ใน CounterMachine.aspx
        // =========================================================
        public static readonly string[] Processes = {
            "Mixing", "Extruder", "Core Molding", "Glebar", "Mixing Surlyn", "Injection",
            "Seambuffing", "Vanmark", "Coating", "Stamping", "Packing", "QC Vanmark", "QC Coating"
        };

        static List<MenuItem> McMonitorPages()
        {
            var list = new List<MenuItem> { new MenuItem("All machines", "CounterMachine.aspx?proc=All") };
            foreach (string p in Processes)
                list.Add(new MenuItem(p, "CounterMachine.aspx?proc=" + Uri.EscapeDataString(p)));
            return list;
        }

        // =========================================================
        // Production Dashboard แยกตามแผนก (ProductionDashboard.aspx?op=...)
        //   รหัสตาม OPERATION.ERP_OPID ใน EMES
        // =========================================================
        static readonly string[,] ProdOps = {
            { "01", "Mixing" }, { "02", "Extruder" }, { "03", "Core Molding" }, { "04", "Glebar" },
            { "05", "Mixing Surlyn" }, { "06", "Injection" }, { "07", "Seambuffing" }, { "08", "Vanmark" },
            { "12", "QC Vanmark" }, { "09", "Coating" }, { "10", "Stamping" }, { "13", "QC Coating" }, { "11", "Packing" }
        };

        static List<MenuItem> ProductionPages()
        {
            var list = new List<MenuItem>();
            for (int i = 0; i < ProdOps.GetLength(0); i++)
                list.Add(new MenuItem(ProdOps[i, 1], "ProductionDashboard.aspx?op=" + ProdOps[i, 0]));
            return list;
        }

        public class Dept
        {
            public string Name;
            public string Icon;   // SVG path
            public List<MenuItem> Items;
        }

        public static readonly List<Dept> MenuData = new List<Dept>
        {
            new Dept {
                Name = "Production",
                Icon = "M3 21V10l6-4v4l6-4v4l6-4v15H3z M7 17h2 M11 17h2 M15 17h2",
                Items = new List<MenuItem> {
                    new MenuItem("Production Dashboard", "ProductionDashboard.aspx", ProductionPages()),   // กดแล้วกางเมนูย่อยตามแผนก
                    new MenuItem("PO Tracking", "PO_Tracking.aspx"),          // PO นี้ผลิตถึง Process ไหนแล้ว
                    new MenuItem("Weight Log", "WeightLog.aspx"),             // น้ำหนักจากเครื่องชั่ง (Extruder03 ...)
                    new MenuItem("Daily Production Report", null),
                    new MenuItem("Line / Machine Status", null),
                }
            },
            new Dept {
                Name = "Quality",
                Icon = "M12 3l7 3v6c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6l7-3z M9 12l2 2 4-4",
                Items = new List<MenuItem> {
                    new MenuItem("NG Dashboard", "IOT_NGDashcord.aspx"),
                    new MenuItem("NG Top 5 by Process", "NG_Top5.aspx"),     // ปัญหางานเสีย 5 อันดับแรกของแต่ละ Process
                    new MenuItem("Master Sample", "MasterSample.aspx"),      // ยิงบาร์โค้ด → Master Sample Sheet
                    new MenuItem("PO Search", "PO_Search.aspx"),
                    new MenuItem("ERP Daily Report", "ERP_Daily_Report.aspx"),
                    new MenuItem("Inspection Record", null),
                    new MenuItem("NCR / CAPA", null),
                }
            },
            new Dept {
                Name = "OEE",
                Icon = "M4 19a8 8 0 1 1 16 0 M12 19l4-6 M4 19h16",
                Items = new List<MenuItem> {
                    new MenuItem("OEE Dashboard", "OEE_Dashboard.aspx"),
                    new MenuItem("MC Monitor", "CounterMachine.aspx", McMonitorPages()),   // กดแล้วกางเมนูย่อยตาม Process
                    new MenuItem("Availability / Performance / Quality", null),
                    new MenuItem("Downtime Analysis", null),
                    new MenuItem("Machine Utilization", null),
                }
            },
            new Dept {
                Name = "Maintenance",
                Icon = "M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.5 2.5-2.5-.5-.5-2.5 2.5-2.5z",
                Items = new List<MenuItem> {
                    new MenuItem("Water Tank", "WaterTank.aspx"),             // ถังน้ำ 3 ระดับ (ลูกลอย) + แจ้ง LINE
                    new MenuItem("PM Schedule", null),
                    new MenuItem("Breakdown Log", null),
                    new MenuItem("Spare Parts", null),
                }
            },
            new Dept {
                Name = "Warehouse",
                Icon = "M3 9l9-5 9 5v11H3V9z M7 20v-7h10v7 M7 16h10",
                Items = new List<MenuItem> {
                    new MenuItem("Stock On-hand", null),
                    new MenuItem("Material Receiving", null),
                    new MenuItem("Finished Goods", null),
                    new MenuItem("Stock Movement", null),
                }
            },
            new Dept {
                Name = "Planning",
                Icon = "M4 5h16v15H4z M4 9h16 M8 3v4 M16 3v4 M8 13h3 M8 16h6",
                Items = new List<MenuItem> {
                    new MenuItem("Sales Order", null),
                    new MenuItem("Production Plan", null),
                    new MenuItem("MRP", null),
                    new MenuItem("Delivery Schedule", null),
                }
            },
            new Dept {
                Name = "Purchasing",
                Icon = "M3 4h2l2.4 11h11.2L21 8H6.2 M9 20a1 1 0 1 0 0-2 1 1 0 0 0 0 2z M18 20a1 1 0 1 0 0-2 1 1 0 0 0 0 2z",
                Items = new List<MenuItem> {
                    new MenuItem("Purchase Requisition (PR)", null),
                    new MenuItem("Purchase Order (PO)", null),
                    new MenuItem("Supplier / Vendor", null),
                    new MenuItem("Goods Receipt Status", null),
                    new MenuItem("Purchase Price History", null),
                }
            },
            new Dept {
                Name = "Accounting",
                Icon = "M5 3h14v18H5z M8 7h8 M8 11h2 M14 11h2 M8 15h2 M14 15h2 M8 18h2 M14 18h2",
                Items = new List<MenuItem> {
                    new MenuItem("Accounts Payable (AP)", null),
                    new MenuItem("Accounts Receivable (AR)", null),
                    new MenuItem("Invoice / Billing", null),
                    new MenuItem("Production Cost", null),
                    new MenuItem("Financial Report", null),
                }
            },
            new Dept {
                Name = "HR",
                Icon = "M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M2 21v-1a6 6 0 0 1 6-6h2a6 6 0 0 1 6 6v1 M17 11a3 3 0 1 0 0-6 M22 21v-1a5 5 0 0 0-4-4.9",
                Items = new List<MenuItem> {
                    new MenuItem("Employee Directory", null),
                    new MenuItem("Time Attendance", null),
                    new MenuItem("Leave Request", null),
                    new MenuItem("Overtime (OT)", null),
                    new MenuItem("Training Record", null),
                    new MenuItem("Manpower by Line", null),
                }
            },
            new Dept {
                Name = "Engineering",
                Icon = "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8z M12 2v3 M12 19v3 M2 12h3 M19 12h3 M4.9 4.9l2.1 2.1 M17 17l2.1 2.1 M4.9 19.1L7 17 M17 7l2.1-2.1",
                Items = new List<MenuItem> {
                    new MenuItem("BOM", null),
                    new MenuItem("Routing", null),
                    new MenuItem("Process Parameters", null),
                }
            },
        };


    }
}
