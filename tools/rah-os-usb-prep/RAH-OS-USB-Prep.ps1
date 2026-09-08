Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ExpectedName = 'RAH-OS-Raven-v0.1-amd64.iso'
$ExpectedHash = 'c19b6c72be2068ba0fe800a5375c0c9b3b63496d9bf9b48d5704d355e2c1e7c5'
$BuildUrl     = 'https://github.com/NilsRa73/rah-platform/actions/runs/34187411973'
$RufusUrl     = 'https://rufus.ie/'

$form = New-Object System.Windows.Forms.Form
$form.Text = 'RAH OS USB Prep v0.1'
$form.Size = New-Object System.Drawing.Size(760,520)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::FromArgb(12,12,12)
$form.ForeColor = [System.Drawing.Color]::FromArgb(212,175,55)
$form.Font = New-Object System.Drawing.Font('Segoe UI',10)
$form.MaximizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = 'RAH OS  •  USB PREP'
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold',24)
$title.ForeColor = [System.Drawing.Color]::FromArgb(212,175,55)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(28,22)
$form.Controls.Add($title)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = 'Raven v0.1  |  Windows verification before Rufus'
$sub.AutoSize = $true
$sub.ForeColor = [System.Drawing.Color]::Gainsboro
$sub.Location = New-Object System.Drawing.Point(31,70)
$form.Controls.Add($sub)

$info = New-Object System.Windows.Forms.Label
$info.Text = "1. Download artifact: RAH-OS-Raven-v0.1-amd64`r`n2. Unzip it and choose $ExpectedName`r`n3. Verify SHA-256 here`r`n4. Only after VERIFIED: open Rufus and choose the USB key manually"
$info.Size = New-Object System.Drawing.Size(690,90)
$info.Location = New-Object System.Drawing.Point(32,108)
$info.ForeColor = [System.Drawing.Color]::WhiteSmoke
$form.Controls.Add($info)

$btnBuild = New-Object System.Windows.Forms.Button
$btnBuild.Text = '1  OPEN GREEN GITHUB BUILD'
$btnBuild.Size = New-Object System.Drawing.Size(320,42)
$btnBuild.Location = New-Object System.Drawing.Point(32,205)
$btnBuild.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
$btnBuild.ForeColor = [System.Drawing.Color]::FromArgb(212,175,55)
$btnBuild.FlatStyle = 'Flat'
$btnBuild.Add_Click({ Start-Process $BuildUrl })
$form.Controls.Add($btnBuild)

$btnSelect = New-Object System.Windows.Forms.Button
$btnSelect.Text = '2  SELECT ISO'
$btnSelect.Size = New-Object System.Drawing.Size(320,42)
$btnSelect.Location = New-Object System.Drawing.Point(382,205)
$btnSelect.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
$btnSelect.ForeColor = [System.Drawing.Color]::FromArgb(212,175,55)
$btnSelect.FlatStyle = 'Flat'
$form.Controls.Add($btnSelect)

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.ReadOnly = $true
$pathBox.Size = New-Object System.Drawing.Size(670,28)
$pathBox.Location = New-Object System.Drawing.Point(32,265)
$pathBox.BackColor = [System.Drawing.Color]::FromArgb(24,24,24)
$pathBox.ForeColor = [System.Drawing.Color]::WhiteSmoke
$form.Controls.Add($pathBox)

$hashLabel = New-Object System.Windows.Forms.Label
$hashLabel.Text = 'Expected SHA-256:'
$hashLabel.AutoSize = $true
$hashLabel.Location = New-Object System.Drawing.Point(32,310)
$form.Controls.Add($hashLabel)

$hashBox = New-Object System.Windows.Forms.TextBox
$hashBox.ReadOnly = $true
$hashBox.Text = $ExpectedHash
$hashBox.Size = New-Object System.Drawing.Size(670,28)
$hashBox.Location = New-Object System.Drawing.Point(32,334)
$hashBox.BackColor = [System.Drawing.Color]::FromArgb(24,24,24)
$hashBox.ForeColor = [System.Drawing.Color]::Gainsboro
$form.Controls.Add($hashBox)

$status = New-Object System.Windows.Forms.Label
$status.Text = 'STATUS: WAITING FOR ISO'
$status.Font = New-Object System.Drawing.Font('Segoe UI Semibold',12)
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(32,382)
$status.ForeColor = [System.Drawing.Color]::Khaki
$form.Controls.Add($status)

$btnVerify = New-Object System.Windows.Forms.Button
$btnVerify.Text = '3  VERIFY SHA-256'
$btnVerify.Enabled = $false
$btnVerify.Size = New-Object System.Drawing.Size(320,42)
$btnVerify.Location = New-Object System.Drawing.Point(32,420)
$btnVerify.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
$btnVerify.ForeColor = [System.Drawing.Color]::FromArgb(212,175,55)
$btnVerify.FlatStyle = 'Flat'
$form.Controls.Add($btnVerify)

$btnRufus = New-Object System.Windows.Forms.Button
$btnRufus.Text = '4  OPEN RUFUS'
$btnRufus.Enabled = $false
$btnRufus.Size = New-Object System.Drawing.Size(320,42)
$btnRufus.Location = New-Object System.Drawing.Point(382,420)
$btnRufus.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
$btnRufus.ForeColor = [System.Drawing.Color]::FromArgb(212,175,55)
$btnRufus.FlatStyle = 'Flat'
$form.Controls.Add($btnRufus)

$btnSelect.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = 'ISO images (*.iso)|*.iso|All files (*.*)|*.*'
    $dlg.Title = 'Select RAH OS Raven v0.1 ISO'
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $pathBox.Text = $dlg.FileName
        $btnVerify.Enabled = $true
        $btnRufus.Enabled = $false
        $status.Text = 'STATUS: ISO SELECTED - NOT YET VERIFIED'
        $status.ForeColor = [System.Drawing.Color]::Khaki
    }
})

$btnVerify.Add_Click({
    try {
        $btnVerify.Enabled = $false
        $status.Text = 'STATUS: CALCULATING SHA-256...'
        $status.ForeColor = [System.Drawing.Color]::Khaki
        $form.Refresh()

        $file = Get-Item -LiteralPath $pathBox.Text -ErrorAction Stop
        $actual = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        $nameOk = ($file.Name -eq $ExpectedName)
        $hashOk = ($actual -eq $ExpectedHash)

        if ($hashOk) {
            $status.Text = if ($nameOk) { 'STATUS: VERIFIED  •  RAH OS v0.1 USB-READY' } else { 'STATUS: VERIFIED HASH  •  FILENAME DIFFERS' }
            $status.ForeColor = [System.Drawing.Color]::LightGreen
            $btnRufus.Enabled = $true
        } else {
            $status.Text = 'STATUS: FAILED  •  HASH DOES NOT MATCH - DO NOT FLASH'
            $status.ForeColor = [System.Drawing.Color]::Tomato
            $btnRufus.Enabled = $false
            [System.Windows.Forms.MessageBox]::Show("Actual SHA-256:`r`n$actual`r`n`r`nExpected:`r`n$ExpectedHash", 'RAH OS verification failed', 'OK', 'Error') | Out-Null
        }
    } catch {
        $status.Text = 'STATUS: ERROR READING ISO'
        $status.ForeColor = [System.Drawing.Color]::Tomato
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'RAH OS USB Prep', 'OK', 'Error') | Out-Null
    } finally {
        $btnVerify.Enabled = $true
    }
})

$btnRufus.Add_Click({
    $msg = "Rufus will be opened in your browser.`r`n`r`nRAH OS USB Prep NEVER selects, formats, or writes a disk itself.`r`nIn Rufus, verify the USB device by brand/capacity before pressing START.`r`nDo not select the internal SSD."
    [System.Windows.Forms.MessageBox]::Show($msg, 'RAH OS - Safe USB step', 'OK', 'Information') | Out-Null
    Start-Process $RufusUrl
})

[void]$form.ShowDialog()
