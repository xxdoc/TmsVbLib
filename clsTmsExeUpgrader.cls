VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "clsTmsExeUpgrader"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit
'*************************************************************************
'**ģ �� ����clsTmsExeUpgrader
'**˵    ����EXE�汾������
'**�� �� �ˣ���һ�� tinymins
'**��    վ��ZhaiYiMing.CoM
'**��    �ڣ�2013��5��17��
'**��    ע: Ҫ��clsMD5��
'*************************************************************************
Private Declare Function URLDownloadToFile Lib "urlmon" Alias "URLDownloadToFileA" (ByVal pCaller As Long, ByVal szURL As String, ByVal szFileName As String, ByVal dwReserved As Long, ByVal lpfnCB As Long) As Long
'*********************************************
Private Declare Function ShellExecute Lib "shell32.dll" Alias "ShellExecuteA" (ByVal hwnd As Long, ByVal lpOperation As String, ByVal lpFile As String, ByVal lpParameters As String, ByVal lpDirectory As String, ByVal nShowCmd As Long) As Long
Private Const SW_HIDE = 0            '{����}
Private Const SW_SHOWNORMAL = 1      '{������Ĵ�С��λ����ʾ, ����}
Private Const SW_NORMAL = 1          '{ͬ SW_SHOWNORMAL}
Private Const SW_SHOWMINIMIZED = 2   '{��С��, ����}
Private Const SW_SHOWMAXIMIZED = 3   '{���, ����}
Private Const SW_MAXIMIZE = 3        '{ͬ SW_SHOWMAXIMIZED}
Private Const SW_SHOWNOACTIVATE = 4  '{������Ĵ�С��λ����ʾ, ������}
Private Const SW_SHOW = 5            '{ͬ SW_SHOWNORMAL}
Private Const SW_MINIMIZE = 6        '{��С��, ������}
Private Const SW_SHOWMINNOACTIVE = 7 '{ͬ SW_MINIMIZE}
Private Const SW_SHOWNA = 8          '{ͬ SW_SHOWNOACTIVATE}
Private Const SW_RESTORE = 9         '{ͬ SW_SHOWNORMAL}
Private Const SW_SHOWDEFAULT = 10    '{ͬ SW_SHOWNORMAL}
Private Const SW_MAX = 10            '{ͬ SW_SHOWNORMAL}
'*********************************************
' �����°汾�����¿�ʼ��
Public Event OnUpgradeStart(ByRef bUpgradeContinue As Boolean)
' û���°汾��������ֹ
Public Event OnUpgradeAbort()
' ������������׼������
Public Event OnUpgradeReady()
' ���¹��̳���
Public Event OnUpgradeError(ByVal iErrCode As Integer, ByVal sErrString As String)
'iErrCode    0.��������ʧ��
'            1.����VER�ļ���ʽ����
'            2.����EXE�ļ�����ʧ��
'           11.������VER�ļ�����
'           12.������EXE�ļ����ش���
'*********************************************
Public LatestInfo, LatestVersion, LatestExeUrl, LatestExeMd5, OnErrorUrl, UpgraderFilePath As String, LatestMajor, LatestMinor, LatestRevision As Integer
Private m_iUpgradeState

'���캯��
Private Sub Class_Initialize()
    LatestInfo = ""
    LatestVersion = ""
    LatestExeMd5 = ""
    LatestExeUrl = ""
    OnErrorUrl = ""
    m_iUpgradeState = 0
End Sub

'��������
Private Sub Class_Terminate()
    
End Sub

'˵������ʼ������
'������
'   sVerUrl: ���°汾��Ϣ��ȡ��ַ
'   sOnErrorUrl: �����������������������ʱ������ҳ��
'   sUpgraderVerUrl: �������汾��Ϣ��ַ
Public Sub Start(ByVal sVerUrl As String, ByVal sOnErrorUrl As String, Optional sUpgraderVerUrl As String = "http://www.zhaiyiming.com/soft/upgrader/version.html")
    'On Error Resume Next
    m_iUpgradeState = 1
    OnErrorUrl = sOnErrorUrl
    
    Dim i As Integer, arrVer() As String
    
    Me.LatestInfo = Me.GetHttpResponse(sVerUrl & IIf(InStr(sVerUrl, "?") = 0, "?", "&") & "rnd=" + CStr(Now), "GBK")
    Me.LatestVersion = Me.Trim(Me.TmsExeVersionDecode(Me.LatestInfo, "ver"))
    Me.LatestExeMd5 = Me.Trim(Me.TmsExeVersionDecode(Me.LatestInfo, "md5"))
    Me.LatestExeUrl = Me.Trim(Me.TmsExeVersionDecode(Me.LatestInfo, "url"))
    
    If Me.LatestInfo = "" Then RaiseEvent OnUpgradeError(0, "��ȡ���°汾��ʧ�ܣ��������Ӵ���"): Exit Sub
    If InStr(LCase(Me.LatestExeUrl), "http://") = 0 And InStr(LCase(Me.LatestExeUrl), "https://") = 0 Then Me.LatestExeUrl = Mid(sVerUrl, 1, InStrRev(sVerUrl, "/")) & Me.LatestExeUrl
    
    arrVer = Split(Me.LatestVersion, ".")
    If UBound(arrVer) - LBound(arrVer) + 1 < 3 Then
        RaiseEvent OnUpgradeError(1, "��ȡ���°汾��ʧ�ܣ�Version�ļ���ʽ����")
        Exit Sub
    Else
        Me.LatestMajor = CInt(arrVer(0))
        Me.LatestMinor = CInt(arrVer(1))
        Me.LatestRevision = CInt(arrVer(3))
    End If
    
    If Me.LatestMajor > App.Major Then GoTo startUpgrader
    If Me.LatestMajor = App.Major And Me.LatestMinor > App.Minor Then GoTo startUpgrader
    If Me.LatestMajor = App.Major And Me.LatestMinor = App.Minor And Me.LatestRevision > App.Revision Then GoTo startUpgrader
    GoTo abortUpgrader
    
startUpgrader:
    Dim bUpgradeContinue As Boolean
    bUpgradeContinue = True
    RaiseEvent OnUpgradeStart(bUpgradeContinue)
    If Not bUpgradeContinue Then Exit Sub
    ' ��������������·�� Me.UpgraderFilePath
    Me.UpgraderFilePath = Me.AddStrToStrEnd(App.Path, "\") & "upgrader.exe"
    ' ��֤upgrader�Ѵ���
    Dim fso As New FileSystemObject
    If fso.FileExists(Me.UpgraderFilePath) Then
        Dim sUpgraderInfo, sUpgraderMd5 As String
        sUpgraderInfo = Me.GetHttpResponse(sUpgraderVerUrl & IIf(InStr(sUpgraderVerUrl, "?") = 0, "?", "&") & "rnd=" + CStr(Now), "GBK")
        sUpgraderMd5 = Me.Trim(Me.TmsExeVersionDecode(sUpgraderInfo, "md5"))
        
        If Len(sUpgraderMd5) <> 32 Then GoTo shellUpgrader
        
        Dim md5 As New clsMD5
        If sUpgraderMd5 = md5.Md5_File_Calc(Me.UpgraderFilePath) Then
            GoTo shellUpgrader
        Else
            fso.DeleteFile Me.UpgraderFilePath
        End If
    End If
    ' ������������
    If Not GetInternetFile(Mid(sUpgraderVerUrl, 1, InStrRev(sUpgraderVerUrl, "/")) & "/upgrader.exe?rand=" & Now, Me.UpgraderFilePath) Then
        ShellExecute 0, "open", sOnErrorUrl, vbNullString, vbNullString, SW_SHOWNORMAL
        End
    End If
shellUpgrader:
    RaiseEvent OnUpgradeReady
    Exit Sub
abortUpgrader:
    RaiseEvent OnUpgradeAbort
End Sub

Public Function ShellEx(ByVal sPath As String, ByVal sParam As String)
    ShellEx = ShellExecute(0, "open", sPath, sParam, vbNullString, SW_SHOWNORMAL)
End Function

Public Function AddStrToStrEnd(ByVal Str1 As String, ByVal Str2 As String) As String
    '�Զ������ַ�����Ŀ���ַ�����β
    If LCase(Right(Str1, Len(Str2))) = LCase(Str2) Then
        AddStrToStrEnd = Str1
    Else
        AddStrToStrEnd = Str1 & Str2
    End If
End Function

Public Function RemoveStrFromStrStart(ByVal Str1 As String, ByVal Str2 As String) As String
    '��Ŀ���ַ����ײ�ɾ���ַ���
    While LCase(Left(Str1, Len(Str2))) = LCase(Str2)
        Str1 = Mid(Str1, Len(Str2) + 1)
    Wend
    RemoveStrFromStrStart = Str1
End Function

'˵������ȡ��ҳԴ����
'������
'   url: ���ӵ�ַ
'   encoding: ҳ�����,gb2312��utf-8��
Public Function GetHttpResponse(ByVal url As String, ByVal encoding As String) As String
    Dim xmlHTTP As Object
    Dim content As Variant
    On Error Resume Next
    Set xmlHTTP = CreateObject("Microsoft.XMLHTTP")
    xmlHTTP.Open "GET", url, True
    xmlHTTP.send
    While xmlHTTP.readyState <> 4
        DoEvents
    Wend
    content = xmlHTTP.responseBody
    If CStr(content) <> "" Then GetHttpResponse = EncodingConvertor(content, encoding)
    Set xmlHTTP = Nothing
    If Err.Number <> 0 Then
        GetHttpResponse = ""
    End If
    On Error GoTo 0
End Function

'˵�����ַ�������ת��
'������
'   content: �ı�
'   encoding:����
Public Function EncodingConvertor(ByVal content As Variant, ByVal encoding As String) As String
    Dim objStream As Object
    On Error Resume Next
    Set objStream = CreateObject("Adodb.Stream")
    With objStream
        .Type = 1
        .Mode = 3
        .Open
        .Write content
        .Position = 0
        .Type = 2
        .Charset = encoding
        EncodingConvertor = .ReadText
        .Close
    End With
    Set objStream = Nothing
    If Err.Number <> 0 Then
        EncodingConvertor = ""
    End If
    On Error GoTo 0
End Function

'˵�������������ļ�
'������
'   SourceURL: �ļ����ӵ�ַ
'   DestFilePath: �ļ�����·��
Public Function GetInternetFile(SourceURL As String, DestFilePath As String) As Boolean
    GetInternetFile = IIf(0 = URLDownloadToFile(0, SourceURL, DestFilePath, 0, 0), True, False)
    Exit Function
End Function

'˵������Version.html�л�ȡ��Ϣ
'������
'   s_info: Version�ļ����� �ַ�����Ϣ
'   s_seek: Ѱ�ҵ��ֶ�
Public Function TmsExeVersionDecode(ByVal s_info As String, ByVal s_seek As String) As String
If 1 = 0 Then
notFound:
    TmsExeVersionDecode = ""
    Exit Function
End If
    Dim s_rtn As String
    If InStr(s_info, "|" + s_seek + "=") = 0 Then GoTo notFound
    s_rtn = Mid(s_info, InStr(s_info, "|" + s_seek + "=") + Len("|" + s_seek + "="))
    If InStr(s_rtn, "|") <> 0 Then s_rtn = Mid(s_rtn, 1, InStr(s_rtn, "|") - 1)
    TmsExeVersionDecode = s_rtn
End Function

'˵����ȥ���ַ������ҵĻ��з��ո��Ʊ��Լ�\0
'������
'   str: �ַ���
Public Function Trim(ByVal str As String) As String
    Dim i As Integer
    For i = 1 To Len(str) Step 1
        Select Case Mid(str, 1, 1)
        Case vbCr
        Case vbLf
        Case vbCrLf
        Case Chr(0)
        Case " "
        Case "  "
        Case Else
            Exit For
        End Select
        str = Mid(str, 2)
    Next
    For i = 1 To Len(str) Step 1
        Select Case Mid(str, Len(str), 1)
        Case vbCr
        Case vbLf
        Case vbCrLf
        Case Chr(0)
        Case " "
        Case "  "
        Case Else
            Exit For
        End Select
        str = Mid(str, 1, Len(str) - 1)
    Next
    Trim = str
End Function