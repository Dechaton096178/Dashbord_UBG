using MySqlConnector;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace Dashbord
{
    public partial class connect : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            string connStr = ConfigurationManager
            .ConnectionStrings["MySQLConnectionString"]
            .ConnectionString;

            try
            {
                using (MySqlConnection conn = new MySqlConnection(connStr))
                {
                    conn.Open();

                    Response.Write("MySQL Connection OK<br>");
                    Response.Write("Database: " + conn.Database);
                }
            }
            catch (Exception ex)
            {
                Response.Write("MySQL Connection Error:<br>");
                Response.Write(ex.Message);
            }
        }
    }
}