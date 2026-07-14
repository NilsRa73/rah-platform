Option Explicit

Dim shell, fso, baseDir, htmlFile, appUrl, browserPath, candidates, item
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
htmlFile = fso.BuildPath(baseDir, "RAH Raven Command Center.html")

If Not fso.FileExists(htmlFile) Then
  MsgBox "RAH Raven Command Center.html is missing. Extract the complete ZIP first.", 16, "RAH Raven"
  WScript.Quit 1
End If

appUrl = "file:///" & Replace(htmlFile, "\", "/")
browserPath = ""

candidates = Array( _
  shell.ExpandEnvironmentStrings("%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"), _
  shell.ExpandEnvironmentStrings("%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"), _
  shell.ExpandEnvironmentStrings("%LocalAppData%\Microsoft\Edge\Application\msedge.exe"), _
  shell.ExpandEnvironmentStrings("%ProgramFiles%\Google\Chrome\Application\chrome.exe"), _
  shell.ExpandEnvironmentStrings("%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"), _
  shell.ExpandEnvironmentStrings("%LocalAppData%\Google\Chrome\Application\chrome.exe") _
)

For Each item In candidates
  If fso.FileExists(item) Then
    browserPath = item
    Exit For
  End If
Next

On Error Resume Next
If browserPath <> "" Then
  shell.Run Chr(34) & browserPath & Chr(34) & " --app=" & Chr(34) & appUrl & Chr(34) & " --start-maximized", 1, False
Else
  shell.Run Chr(34) & htmlFile & Chr(34), 1, False
End If

If Err.Number <> 0 Then
  MsgBox "RAH could not open. Double-click 'RAH Raven Command Center.html' instead." & vbCrLf & vbCrLf & Err.Description, 16, "RAH Raven"
  WScript.Quit 1
End If
