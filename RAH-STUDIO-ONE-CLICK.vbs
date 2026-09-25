Option Explicit

Dim shell, fso, baseDir, studio, prepare, command, rc, logDir, statusFile, statusText, studioUrl
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
studio = fso.BuildPath(baseDir, "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html")
prepare = fso.BuildPath(fso.BuildPath(baseDir, "desktop-bridge"), "start-studio-bridge-silent.cmd")
logDir = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\RAH-Raven\Studio"
statusFile = logDir & "\boot-last.txt"

If Not fso.FolderExists(logDir) Then
  On Error Resume Next
  fso.CreateFolder shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\RAH-Raven"
  fso.CreateFolder logDir
  On Error GoTo 0
End If

If Not fso.FileExists(studio) Then
  MsgBox "RAH Raven Studio Candidate mangler: " & studio, 16, "RAH AI Studios"
  WScript.Quit 2
End If

If Not fso.FileExists(prepare) Then
  MsgBox "Raven Bridge bootstrap mangler: " & prepare, 16, "RAH AI Studios"
  WScript.Quit 3
End If

command = shell.ExpandEnvironmentStrings("%ComSpec%") & " /d /c " & Chr(34) & Chr(34) & prepare & Chr(34) & Chr(34)
rc = shell.Run(command, 0, True)

If rc = 0 Then
  statusText = "PASS - Raven Bridge ready on 127.0.0.1:18765"
ElseIf rc = 6 Then
  statusText = "FAIL - port 18765 belongs to an unverified service; nothing was killed"
Else
  statusText = "FAIL - hidden Bridge bootstrap exit=" & CStr(rc)
End If

On Error Resume Next
Dim outFile
Set outFile = fso.CreateTextFile(statusFile, True, True)
outFile.WriteLine Now & " " & statusText
outFile.Close
On Error GoTo 0

studioUrl = "file:///" & Replace(studio, "\", "/")
studioUrl = Replace(studioUrl, " ", "%20") & "?boot=" & CStr(rc)
shell.Run Chr(34) & studioUrl & Chr(34), 1, False
