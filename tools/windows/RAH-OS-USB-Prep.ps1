Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$ExpectedFileName = 'RAH-OS-Raven-v0.1-amd64.iso'

$form = New-Object System.Windows.Forms.Form
$form.Text = 'RAH OS Raven v0.1 - USB Prep'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(760, 560)
$form.MinimumSize = New-Object System.Drawing.Size(760, 560)
$form.BackColor = [System.Drawing.Color]::FromArgb(14,14,14)
$form.ForeColor = [System.Drawing.Color]::FromArgb(218,181,92)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'RAH OS  |  RAVEN v0.1'
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 22)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(28, 22)
$form.Controls.Add($title)

$safety = New-Object System.Windows.Forms.Label
$safety.Text = "SAFE MODE: Dette verktøyet skriver IKKE til USB, SSD eller NVMe. Det verifiserer bare ISO-filen."
$safety.ForeColor = [System.Drawing.Color]::White
$safety.AutoSize = $true
$safety.Location = New-Object System.Drawing.Point(31, 72)
$form.Controls.Add($safety)

$fileBox = New-Object System.Windows.Forms.TextBox
$fileBox.Location = New-Object System.Drawing.Point(32, 118)
$fileBox.Size = New-Object System.Drawing.Size(555, 28)
$fileBox.ReadOnly = $true
$fileBox.BackColor = [System.Drawing.Color]::FromArgb(28,28,28)
$fileBox.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($fileBox)

$browse = New-Object System.Windows.Forms.Button
$browse.Text = 'Velg ISO...'
$browse.Location = New-Object System.Drawing.Point(600, 115)
$browse.Size = New-Object System.Drawing.Size(120, 34)
$form.Controls.Add($browse)

$verify = New-Object System.Windows.Forms.Button
$verify.Text = 'Verifiser SHA-256'
$verify.Location = New-Object System.Drawing.Point(32, 168)
$verify.Size = New-Object System.Drawing.Size(180, 38)
$verify.Enabled = $false
$form.Controls.Add($verify)

$status = New-Object System.Windows.Forms.Label
$status.Text = 'STATUS: Velg RAH OS ISO-filen.'
$status.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 12)
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(32, 226)
$form.Controls.Add($status)

$details = New-Object System.Windows.Forms.TextBox
$details.Location = New-Object System.Drawing.Point(32, 264)
$details.Size = New-Object System.Drawing.Size(688, 124)
$details.Multiline = $true
$details.ReadOnly = $true
$details.ScrollBars = 'Vertical'
$details.BackColor = [System.Drawing.Color]::FromArgb(24,24,24)
$details.ForeColor = [System.Drawing.Color]::White
$details.Text = "Forventet ISO: $ExpectedFileName`r`nForventet checksum-fil: $ExpectedFileName.sha256`r`n`r`nChecksum-filen skal ligge i samme mappe som ISO-en."
$form.Controls.Add($details)

$rufus = New-Object System.Windows.Forms.Button
$rufus.Text = 'Åpne Rufus'
$rufus.Location = New-Object System.Drawing.Point(32, 414)
$rufus.Size = New-Object System.Drawing.Size(150, 40)
$rufus.Enabled = $false
$form.Controls.Add($rufus)

$warning = New-Object System.Windows.Forms.Label
$warning.Text = "I Rufus: velg KUN USB-minnepinnen. Ikke velg intern SSD/NVMe. SSD-installasjon er IKKE godkjent i v0.1-testen."
$warning.ForeColor = [System.Drawing.Color]::White
$warning.Location = New-Object System.Drawing.Point(205, 407)
$warning.Size = New-Object System.Drawing.Size(515, 62)
$form.Controls.Add($warning)

$browse.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Velg RAH OS Raven v0.1 ISO'
    $dialog.Filter = 'ISO image (*.iso)|*.iso'
    $dialog.Multiselect = $false
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $fileBox.Text = $dialog.FileName
        $verify.Enabled = $true
        $rufus.Enabled = $false
        $status.Text = 'STATUS: Klar for SHA-256-verifisering.'
        $status.ForeColor = [System.Drawing.Color]::FromArgb(218,181,92)
    }
})

$verify.Add_Click({
    try {
        $isoPath = $fileBox.Text
        if (-not (Test-Path -LiteralPath $isoPath -PathType Leaf)) {
            throw 'ISO-filen finnes ikke.'
        }

        $actualName = [System.IO.Path]::GetFileName($isoPath)
        if ($actualName -ne $ExpectedFileName) {
            throw "Feil filnavn. Forventet: $ExpectedFileName"
        }

        $checksumPath = "$isoPath.sha256"
        if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
            throw "Mangler checksum-fil: $ExpectedFileName.sha256"
        }

        $checksumText = (Get-Content -LiteralPath $checksumPath -Raw).Trim()
        $match = [regex]::Match($checksumText, '(?i)\b[0-9a-f]{64}\b')
        if (-not $match.Success) {
            throw 'Checksum-filen inneholder ikke en gyldig SHA-256.'
        }

        $expectedHash = $match.Value.ToUpperInvariant()
        $actualHash = (Get-FileHash -LiteralPath $isoPath -Algorithm SHA256).Hash.ToUpperInvariant()

        $details.Text = "ISO: $actualName`r`n`r`nForventet SHA-256:`r`n$expectedHash`r`n`r`nBeregnet SHA-256:`r`n$actualHash"

        if ($actualHash -ne $expectedHash) {
            $status.Text = 'STATUS: FAIL - ISO-en skal IKKE brukes.'
            $status.ForeColor = [System.Drawing.Color]::Tomato
            $rufus.Enabled = $false
            [System.Windows.Forms.MessageBox]::Show('SHA-256 stemmer ikke. Ikke skriv denne ISO-en til USB.', 'RAH OS - FAIL', 'OK', 'Error') | Out-Null
            return
        }

        $status.Text = 'STATUS: PASS - ISO-en er verifisert og klar for Rufus.'
        $status.ForeColor = [System.Drawing.Color]::LightGreen
        $rufus.Enabled = $true
    }
    catch {
        $status.Text = 'STATUS: FAIL - se detaljene.'
        $status.ForeColor = [System.Drawing.Color]::Tomato
        $details.Text = $_.Exception.Message
        $rufus.Enabled = $false
    }
})

$rufus.Add_Click({
    Start-Process 'https://rufus.ie/'
})

[void]$form.ShowDialog()
