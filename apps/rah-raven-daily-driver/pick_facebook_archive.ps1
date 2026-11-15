Add-Type -AssemblyName System.Windows.Forms

$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = "Velg Facebook / Meta-arkiv ZIP"
$dialog.Filter = "ZIP archive (*.zip)|*.zip|All files (*.*)|*.*"
$dialog.Multiselect = $false

$result = $dialog.ShowDialog()
if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Ingen fil valgt."
    exit 2
}

Write-Output $dialog.FileName
