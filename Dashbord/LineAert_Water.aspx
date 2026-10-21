<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="LineAert_Water.aspx.cs" Inherits="Dashbord.LineAert_Water" %>

<!DOCTYPE html>
<html>
<head runat="server">
    <title>LINE Water Alert Test</title>
    <meta charset="utf-8" />
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 30px;
            background: #f4f6f9;
        }
        .panel {
            max-width: 650px;
            padding: 25px;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 8px #ddd;
        }
        .btn {
            padding: 10px 20px;
            background: #06C755;
            color: white;
            border: 0;
            border-radius: 5px;
            cursor: pointer;
        }
        .txt {
            width: 100%;
            padding: 10px;
            box-sizing: border-box;
            margin: 8px 0 15px;
        }
    </style>
</head>
<body>
<form id="form1" runat="server">
    <div class="panel">
        <h2>LINE Water Alert Test</h2>

        <label>Recipient ID (User ID / Group ID) · พิมพ์ <b>ALL</b> = ส่งถึงทุกคนที่แอด LINE OA เป็นเพื่อน</label>
        <asp:TextBox ID="txtRecipient" runat="server"
            CssClass="txt" />

        <label>ข้อความแจ้งเตือน</label>
        <asp:TextBox ID="txtMessage" runat="server"
            CssClass="txt" TextMode="MultiLine"
            Rows="4"
            Text="Water Alert: Test notification successful!" />

        <asp:Button ID="btnSend" runat="server"
            Text="ส่งข้อความทดสอบ LINE"
            CssClass="btn"
            OnClick="btnSend_Click" />

        <br /><br />

        <asp:Label ID="lblResult" runat="server" />
    </div>
</form>
</body>
</html>