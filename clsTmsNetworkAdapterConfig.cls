VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "clsTmsNetworkAdapterConfig"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit
Private Declare Function timeGetTime Lib "winmm.dll" () As Long
Private Declare Function SetAdapterIPAddress Lib "Iphlpapi.dll" Alias "#135" (ByVal szAdapterGUID As String, ByVal dwDHCP As Long, ByVal dwIP As Long, ByVal dwMask As Long, ByVal dwGateway As Long) As Long
'Private Declare Function DhcpNotifyConfigChange Lib "dhcpcsvc.dll" Alias "DHCPNotifyConfigChange" (ByVal ServerName As String, ByVal AdapterName As String, ByVal bNewIPAddress As Boolean, ByVal dwIPIndex As Long, ByVal dwIPAddress As Long, ByVal dwSubNetMask As Long, ByVal nDHCPAction As Long) As Long
Private Declare Function inet_addr Lib "wsock32.dll" (ByVal Num As String) As Long
Private Declare Function DhcpNotifyConfigChange Lib "dhcpcsvc.dll" (ByVal ServerName As String, ByVal AdapterName As Long, ByVal bNewIPAddress As Long, ByVal dwIPIndex As Long, ByVal dwIPAddress As Long, ByVal dwSubNetMask As Long, ByVal nDHCPAction As Long) As Long
'Private ws_ As New WshShell
Private ra_ As New clsRegistryAccess
Private tec_ As New clsTmsExecuteCommand
Private csl_ As Object, csl_type_ As String

'���캯��
Private Sub Class_Initialize()

End Sub
'��������
Private Sub Class_Terminate()
    
End Sub

Public Function BindConsole(csl As Object, csl_type As String)
    Set csl_ = csl
    csl_type_ = LCase(csl_type)
End Function

Public Sub ConsolePrint(ByVal str As String)
    Select Case csl_type_
    Case "form": csl_.Print str
    Case "textbox": csl_.Text = csl_.Text & str: csl_.SelStart = Len(csl_.Text)
    Case "picturebox": csl_.Print str
    Case Else: Debug.Print str
    End Select
End Sub

Public Sub ConsolePrintln(ByVal str As String)
    ConsolePrint str & vbCrLf
End Sub

Public Sub ConsoleCls()
    Select Case csl_type_
    Case "form": csl_.Cls
    Case "textbox": csl_.Text = ""
    Case "picturebox": csl_.Cls
    End Select
End Sub

Public Function GetAdapterList(Optional sInterfaceFilter As String = "") As Variant
    ' ��ȡע�����ȡMAC����Ϣ
    Dim aAdapters() As String
    ' 0ע������,1�豸����,2GUID,3MAC��ַ,4IP��ַ,5��������,6Ĭ������,7DNS������,8DHCP�Ƿ���,9DHCPIP��ַ,10DHCP��������,11DHCPĬ������,12DHCPDNS������,13DHCP������,14NetshInterfaceName
    Dim sRegAdapterIndex() As String, i As Integer, iAdaptersCount As Integer, sRegAdapterPath As String
    sRegAdapterPath = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}\"
    iAdaptersCount = 0
    
    ra_.EnumKeys sRegAdapterPath, sRegAdapterIndex
    For i = LBound(sRegAdapterIndex) To UBound(sRegAdapterIndex)
        If IsNumeric(sRegAdapterIndex(i)) Then
            If sInterfaceFilter <> "" Then
                If Not InStr(ra_.ReadString("HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\" & sRegAdapterIndex(i) & "\Ndi\Interfaces", "LowerRange", ""), sInterfaceFilter) > 0 Then
                    GoTo skipThis
                End If
            End If
            Dim sRegIpConfigPath As String
            ReDim Preserve aAdapters(15, iAdaptersCount)
            aAdapters(0, iAdaptersCount) = sRegAdapterIndex(i)
            aAdapters(1, iAdaptersCount) = ra_.ReadString(sRegAdapterPath & sRegAdapterIndex(i), "DriverDesc", "")
            aAdapters(2, iAdaptersCount) = ra_.ReadString(sRegAdapterPath & sRegAdapterIndex(i), "NetCfgInstanceId", "")
            aAdapters(3, iAdaptersCount) = ra_.ReadString(sRegAdapterPath & sRegAdapterIndex(i), "NetworkAddress", "")
            sRegIpConfigPath = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\Tcpip\Parameters\Interfaces\" & aAdapters(2, iAdaptersCount)
            aAdapters(4, iAdaptersCount) = ra_.ReadString(sRegIpConfigPath, "IPAddress", "")
            aAdapters(5, iAdaptersCount) = ra_.ReadString(sRegIpConfigPath, "SubnetMask", "")
            aAdapters(6, iAdaptersCount) = ra_.ReadString(sRegIpConfigPath, "DefaultGateway", "")
            aAdapters(7, iAdaptersCount) = ra_.ReadString(sRegIpConfigPath, "NameServer", "")
            aAdapters(8, iAdaptersCount) = ra_.ReadDWORD(sRegIpConfigPath, "EnableDHCP", 1)
            aAdapters(9, iAdaptersCount) = ra_.ReadString(sRegIpConfigPath, "DhcpIPAddress", "")
            aAdapters(10, iAdaptersCount) = ra_.ReadString(sRegIpConfigPath, "DhcpSubnetMask", "")
            aAdapters(11, iAdaptersCount) = ra_.ReadString(sRegIpConfigPath, "DhcpDefaultGateway", "")
            aAdapters(12, iAdaptersCount) = ra_.ReadString(sRegIpConfigPath, "DhcpNameServer", "")
            aAdapters(13, iAdaptersCount) = ra_.ReadString(sRegIpConfigPath, "DhcpServer", "")
            aAdapters(14, iAdaptersCount) = Replace(ra_.ReadString("HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Network\{4D36E972-E325-11CE-BFC1-08002BE10318}\" _
                                                          & aAdapters(2, iAdaptersCount) & "\Connection", "Name", ""), Chr(0), "")
            iAdaptersCount = iAdaptersCount + 1
skipThis:
        End If
    Next
    
    GetAdapterList = aAdapters
End Function

Function SetAdapterIpViaNetsh(ByVal sInterfaceName As String, ByVal sIP As String, ByVal sMask As String, ByVal sGateway As String) As Integer
    ConsolePrintln "--------------------------------------------------------"
    ConsolePrintln "�������á�" & sInterfaceName & "��IP..."
    DoEvents
    If sIP = "" Then
        ConsolePrintln "��Ϊ�Զ���ȡ...": DoEvents
        'netsh interface IP set address name="��������" source=dhcp
        ConsolePrintln ">> " & TmsTrim(tec_.ExeCMD("netsh interface ip set address name=""" & sInterfaceName & """ source=dhcp"))
    Else
        ConsolePrintln sIP & "/" & sMask & " " & sGateway: DoEvents
        'netsh interface ip set address name="��������" source = static addr = 172.10.38.90  mask=255.255.0.0 gateway = 172.10.38.1 gwmetric =0
        ConsolePrintln ">> " & TmsTrim(tec_.ExeCMD("netsh interface ip set address name=""" & sInterfaceName & """ source=static addr=" & sIP & " mask=" & sMask & " gateway=" & sGateway & " gwmetric=0"))
    End If
    ConsolePrintln "���á�" & sInterfaceName & "��IP���ˡ�"
    DoEvents
End Function

Function SetAdapterDnsViaNetsh(ByVal sInterfaceName As String, ByVal sDNSs As String) As Integer
    ConsolePrintln "--------------------------------------------------------"
    ConsolePrintln "�������á�" & sInterfaceName & "��DNS..."
    DoEvents
    If sDNSs = "" Then
        ConsolePrintln "��Ϊ�Զ���ȡ...": DoEvents
        'netsh interface ip set dns  name="��������" source=dhcp
        ConsolePrintln ">> " & TmsTrim(tec_.ExeCMD("netsh interface ip set dns name=""" & sInterfaceName & """ source=dhcp"))
    Else
        'netsh interface ip set dns name="��������" source = static  addr = 219.150.150.150 register=PRIMARY
        'netsh interface ip add dns name="��������" addr = 222.88.88.88 index=2
        Dim aDNSs() As String, i As Integer
        aDNSs = Split(sDNSs, ",")
        For i = LBound(aDNSs) To UBound(aDNSs)
            If i = 0 Then
                ConsolePrintln "��DNS: " & aDNSs(i): DoEvents
                ConsolePrintln ">> " & TmsTrim(tec_.ExeCMD("netsh interface ip set dns name=""" & sInterfaceName & """ source=static addr=" & aDNSs(i) & " register=PRIMARY"))
            Else
                ConsolePrintln "DNS" & CStr(i) & ": " & aDNSs(i): DoEvents
                ConsolePrintln ">> " & TmsTrim(tec_.ExeCMD("netsh interface ip add dns name=""" & sInterfaceName & """ addr=" & aDNSs(i) & " index=" & CStr(i + 1)))
            End If
            DoEvents
        Next
    End If
    ConsolePrintln "���á�" & sInterfaceName & "��DNS���ˡ�"
    DoEvents
End Function

Function SetAdapterIpViaReg(ByVal sGUID As String, ByVal sIPs As String, ByVal sMasks As String, ByVal sGateways As String, ByVal sGatewayCostMetrics As String, ByVal sDNSs As String) As Integer
    Dim sRegConfigPath As String
    sRegConfigPath = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\Tcpip\Parameters\Interfaces\" & sGUID
    Dim aIPs() As String, aMasks() As String, aGateways() As String, aGatewayCostMetrics() As String
    
    aIPs = MultiStringFormat(sIPs)
    aMasks = MultiStringFormat(sMasks)
    aGateways = MultiStringFormat(sGateways)
    aGatewayCostMetrics = MultiStringFormat(sGatewayCostMetrics)
    
    If Not sDNSs = "" Then ra_.WriteString sRegConfigPath, "NameServer", sDNSs
    If Not aIPs(0) = "" Then ra_.WriteMultiString sRegConfigPath, "IPAddress", aIPs
    If Not aMasks(0) = "" Then ra_.WriteMultiString sRegConfigPath, "SubnetMask", aMasks
    If Not aGateways(0) = "" Then ra_.WriteMultiString sRegConfigPath, "DefaultGateway", aGateways
    If Not aGatewayCostMetrics(0) = "" Then ra_.WriteMultiString sRegConfigPath, "DefaultGatewayMetric", aGatewayCostMetrics
    
    Dim iIP As Long, iMask As Long, iGW As Long
    iIP = inet_addr(aIPs(0))
    iMask = inet_addr(aMasks(0))
    iGW = inet_addr(aGateways(0))
    
    Debug.Print DhcpNotifyConfigChange(vbNullString, StrPtr(sGUID), 1, 0, iIP, iMask, 1)
    'Debug.Print SetAdapterIPAddress(sGuid, 2, iIP, iMask, iGW)
    
End Function

' ��������MAC��ַ
' ������sAdapterIndex ע������������
'       sMac          ��MAC��ַ
Public Function SetAdapterMac(ByVal sAdapterIndex As String, ByVal sMac As String) As Boolean
    ConsolePrintln "--------------------------------------------------------"
    ConsolePrintln "�������á�" & sAdapterIndex & "��������MAC��ַ..."
    DoEvents
    If sMac = "" Then
        SetAdapterMac = ra_.WriteString("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}\" & sAdapterIndex, "NetworkAddress", "")
        SetAdapterMac = ra_.KillValue("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}\" & sAdapterIndex, "NetworkAddress")
    Else
        SetAdapterMac = ra_.WriteString("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}\" & sAdapterIndex, "NetworkAddress", sMac)
    End If
    ConsolePrintln "���á�" & sAdapterIndex & "��������MAC��ַ���ˣ���������������������Ч��"
    DoEvents
End Function

' "IP1,IP2" -> Array(IP1,IP2)
Private Function MultiStringFormat(ByVal sValues As String) As Variant
    Dim aValues() As String, i As Integer
    sValues = Trim(sValues)
    sValues = Replace(sValues, Chr(0), "")
    sValues = Replace(sValues, Chr(32), "")
    aValues = Split(sValues, Chr(44))
    
    For i = LBound(aValues) To UBound(aValues)
        aValues(i) = Trim(aValues(i))
    Next
    
    MultiStringFormat = aValues
End Function

Public Function CheckIpAddressFormat(ByVal sIpAddrs As String) As String
    sIpAddrs = TmsTrim(sIpAddrs, " " & vbCrLf & ",")
    Dim aIpAddrs() As String, aIpAddr() As String, i As Integer, J As Integer
    CheckIpAddressFormat = ""
    aIpAddrs = Split(sIpAddrs, ",")
    For i = LBound(aIpAddrs) To UBound(aIpAddrs)
        aIpAddr = Split(aIpAddrs(i), ".")
        If (UBound(aIpAddr) - LBound(aIpAddr)) <> 3 Then CheckIpAddressFormat = vbNullString: Exit Function
        For J = LBound(aIpAddr) To UBound(aIpAddr)
            If Not IsNumeric(aIpAddr(J)) Then CheckIpAddressFormat = vbNullString: Exit Function
            If CInt(aIpAddr(J)) > 255 Or CInt(aIpAddr(J)) < 0 Then CheckIpAddressFormat = vbNullString: Exit Function
            CheckIpAddressFormat = CheckIpAddressFormat & IIf(J = LBound(aIpAddr), "", ".") & CStr(CInt(aIpAddr(J)))
        Next
        CheckIpAddressFormat = CheckIpAddressFormat & IIf(i = UBound(aIpAddrs), "", ",")
    Next
End Function

Public Function CheckMacAddressFormat(ByVal sMacAddr As String) As String
    sMacAddr = Replace(UCase(sMacAddr), vbCrLf, "")
    
    Dim sTmp As String, aReplace() As String, i As Integer
    sTmp = sMacAddr
    aReplace = Split("0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F", ",")
     
    If Len(sMacAddr) <> 12 Then CheckMacAddressFormat = vbNullString: Exit Function
    For i = LBound(aReplace) To UBound(aReplace)
        sTmp = Replace(sTmp, aReplace(i), "")
    Next
    If Len(sTmp) <> 0 Then CheckMacAddressFormat = vbNullString: Exit Function
    CheckMacAddressFormat = sMacAddr
End Function

Public Function Mask2Int(ByVal sMask As String) As Integer
    Mask2Int = -1
    Dim aMask() As String, i As Integer
    aMask = Split("0.0.0.0,128.0.0.0,192.0.0.0,224.0.0.0,240.0.0.0,248.0.0.0,252.0.0.0,254.0.0.0,255.0.0.0," & _
    "255.128.0.0,255.192.0.0,255.224.0.0,255.240.0.0,255.248.0.0,255.252.0.0,255.254.0.0,255.255.0.0," & _
    "255.255.128.0,255.255.192.0,255.255.224.0,255.255.240.0,255.255.248.0,255.255.252.0,255.255.254.0,255.255.255.0," & _
    "255.255.255.128,255.255.255.192,255.255.255.224,255.255.255.240,255.255.255.248,255.255.255.252,255.255.255.254,255.255.255.255", ",")
    For i = 0 To 32
        If sMask = aMask(i) Then Mask2Int = i
    Next
End Function

Public Function Int2Mask(ByVal iMask As Integer) As String
    If iMask < 0 Or iMask > 32 Then Int2Mask = vbNullString: Exit Function
    Dim aMask() As String
    aMask = Split("0.0.0.0,128.0.0.0,192.0.0.0,224.0.0.0,240.0.0.0,248.0.0.0,252.0.0.0,254.0.0.0,255.0.0.0," & _
    "255.128.0.0,255.192.0.0,255.224.0.0,255.240.0.0,255.248.0.0,255.252.0.0,255.254.0.0,255.255.0.0," & _
    "255.255.128.0,255.255.192.0,255.255.224.0,255.255.240.0,255.255.248.0,255.255.252.0,255.255.254.0,255.255.255.0," & _
    "0,255.255.255.128,255.255.255.192,255.255.255.224,255.255.255.240,255.255.255.248,255.255.255.252,255.255.255.254,255.255.255.255", ",")
    Int2Mask = aMask(iMask)
End Function

Private Function TmsTrim(ByVal str As String, Optional sReplace As String = "") As String
    If sReplace = "" Then sReplace = " ��" & vbCr & vbLf & vbCrLf & Chr(0)
    Dim i As Integer
    For i = 1 To Len(str) Step 1
        If InStr(sReplace, Mid(str, 1, 1)) > 0 Then
            str = Mid(str, 2)
        Else
            Exit For
        End If
    Next
    For i = 1 To Len(str) Step 1
        If InStr(sReplace, Mid(str, Len(str), 1)) > 0 Then
            str = Mid(str, 1, Len(str) - 1)
        Else
            Exit For
        End If
    Next
    TmsTrim = str
End Function

'VB���úͽ�����������
Public Function RestartPCI(ByVal sInterfaceName As String) As Integer   '������������
    If 1 = 0 Then
errGUID:
        MsgBox "Error When Reboot Device!"
        Exit Function
    End If
    
    On Error GoTo errGUID
    
    RestartPCI = 0
    '�� �������ӻ�����Ҫ���Ƶı������ӵ�����
    If ExcNetLinkMenu(sInterfaceName, "ͣ��(&B)") Then 'xp
        ConsolePrintln "ͣ�óɹ�,������������..."
    ElseIf ExcNetLinkMenu(sInterfaceName, "����(&B)") Then 'Win7
        ConsolePrintln "ͣ�óɹ�,������������..."
    Else
        ConsolePrintln "ͣ��ʧ��,���ڳ�������..."
        RestartPCI = 1
    End If
    
    ThreadSleep 4000
    If ExcNetLinkMenu(sInterfaceName, "����(&A)") Then
        ConsolePrintln "�������óɹ�"
        RestartPCI = 0
    Else
        If RestartPCI = 1 Then Exit Function
        ConsolePrintln "����ʧ�� ���ֶ���������"
        RestartPCI = 2
        Exit Function
    End If
End Function

'��������Microsoft Shell Controls And Automation
Private Function ExcNetLinkMenu(ByVal AdapterName As String, ByVal MenuName As String) As Boolean
    On Error Resume Next
    Dim mShell As New Shell32.Shell
    Dim NetConnection As Shell32.Folder
    Dim FolderItem As Shell32.FolderItem
    Dim NetConnectionItem As ShellFolderItem
    Dim verb As Shell32.FolderItemVerb
    Set NetConnection = mShell.NameSpace(49) '���49�����ҳ����ģ��������Ϳ��Ա�������������
    If ObjPtr(NetConnection) = 0 Then
        ExcNetLinkMenu = False
        GoTo exitfunction
    End If
    Dim flag As Boolean
    flag = False
    For Each FolderItem In NetConnection.Items
        If FolderItem.Name = AdapterName Then
            Set NetConnectionItem = FolderItem
            flag = True
            Exit For
        End If
    Next
    If flag = False Then
        ExcNetLinkMenu = False
        GoTo exitfunction
    End If
    For Each verb In NetConnectionItem.Verbs
        If verb.Name = MenuName Then
            flag = True
            verb.DoIt
            ExcNetLinkMenu = True
            GoTo exitfunction
        End If
    Next
    If flag = False Then
        ExcNetLinkMenu = False
        GoTo exitfunction
    End If
exitfunction:
    Set mShell = Nothing
    Set NetConnection = Nothing
    Set FolderItem = Nothing
    Set NetConnectionItem = Nothing
    Set verb = Nothing
End Function

'��������
Public Sub ThreadSleep(t As Double)
    Dim Savetime As Double
    Savetime = timeGetTime '���¿�ʼʱ��
    While timeGetTime < Savetime + t 'ѭ���ȴ�
        DoEvents 'ת�ÿ���Ȩ
    Wend
End Sub