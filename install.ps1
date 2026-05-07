# ============================================================
#  Incognito Guard - Windows Installer
#  Run as Administrator in PowerShell
# ============================================================

param(
    [string]$ExtensionId = "REPLACE_WITH_YOUR_EXTENSION_ID"
)

# ── Check admin rights ─────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Host "ERROR: Please run this script as Administrator." -ForegroundColor Red
    Write-Host "Right-click PowerShell -> Run as Administrator" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Incognito Guard - Windows Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcExe     = Join-Path $scriptDir "IncognitoGuard.exe"
$srcConfig  = Join-Path $scriptDir "config.json"
$installDir = "C:\Program Files\IncognitoGuard"
$destExe    = "$installDir\IncognitoGuard.exe"
$destConfig = "$installDir\config.json"

# ── 1. Install to Program Files ────────────────────────────
Write-Host "`n[1/7] Installing to Program Files..." -ForegroundColor Cyan

if (-not (Test-Path $srcExe)) {
    Write-Host "ERROR: IncognitoGuard.exe not found in $scriptDir" -ForegroundColor Red
    pause
    exit 1
}

New-Item -ItemType Directory -Path $installDir -Force | Out-Null
Copy-Item $srcExe    $destExe    -Force
Copy-Item $srcConfig $destConfig -Force
Write-Host "[OK] Installed to $installDir" -ForegroundColor Green

# ── 2. Lock folder permissions ─────────────────────────────
Write-Host "[2/7] Locking folder permissions..." -ForegroundColor Cyan

try {
    $acl = Get-Acl $installDir
    $denyDelete = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "Users",
        "Delete,DeleteSubdirectoriesAndFiles,Write",
        "ContainerInherit,ObjectInherit",
        "None",
        "Deny"
    )
    $acl.AddAccessRule($denyDelete)
    Set-Acl $installDir $acl
    Write-Host "[OK] Folder locked — standard users cannot delete" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Could not lock permissions: $_" -ForegroundColor Yellow
}

# ── 3. Add to startup (HKLM — all users) ───────────────────
Write-Host "[3/7] Adding to system startup..." -ForegroundColor Cyan

$startupKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $startupKey -Name "IncognitoGuard" -Value "`"$destExe`""
Write-Host "[OK] Added to system startup (all users)" -ForegroundColor Green

# ── 4. Force-install Chrome extension ──────────────────────
Write-Host "[4/7] Setting Chrome policy..." -ForegroundColor Cyan
$chromePath = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
if (-not (Test-Path $chromePath)) { New-Item -Path $chromePath -Force | Out-Null }
Set-ItemProperty -Path $chromePath -Name "1" -Value "$ExtensionId;https://clients2.google.com/service/update2/crx"
Write-Host "[OK] Chrome policy set" -ForegroundColor Green

# ── 5. Force-install Edge extension ────────────────────────
Write-Host "[5/7] Setting Edge policy..." -ForegroundColor Cyan
$edgePath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
if (-not (Test-Path $edgePath)) { New-Item -Path $edgePath -Force | Out-Null }
Set-ItemProperty -Path $edgePath -Name "1" -Value "$ExtensionId;https://clients2.google.com/service/update2/crx"
Write-Host "[OK] Edge policy set" -ForegroundColor Green

# ── 6. Force-install Brave extension ───────────────────────
$bravePath = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist"
if (-not (Test-Path $bravePath)) { New-Item -Path $bravePath -Force | Out-Null }
Set-ItemProperty -Path $bravePath -Name "1" -Value "$ExtensionId;https://clients2.google.com/service/update2/crx"
Write-Host "[OK] Brave policy set" -ForegroundColor Green

# ── 7. Firefox policies.json ────────────────────────────────
Write-Host "[6/7] Setting Firefox policy..." -ForegroundColor Cyan
$ffPolicyDir = "C:\Program Files\Mozilla Firefox\distribution"
if (Test-Path "C:\Program Files\Mozilla Firefox") {
    if (-not (Test-Path $ffPolicyDir)) { New-Item -ItemType Directory -Path $ffPolicyDir -Force | Out-Null }
    $ffPolicy = @{
        policies = @{
            ExtensionSettings = @{
                "incognito-guard@yourname.com" = @{
                    installation_mode = "force_installed"
                    install_url       = "https://addons.mozilla.org/firefox/downloads/your-ext.xpi"
                }
            }
        }
    }
    $ffPolicy | ConvertTo-Json -Depth 5 | Set-Content "$ffPolicyDir\policies.json"
    Write-Host "[OK] Firefox policy set" -ForegroundColor Green
} else {
    Write-Host "[SKIP] Firefox not found" -ForegroundColor Yellow
}

# ── 8. Disable Task Manager for standard users ─────────────
Write-Host "[7/7] Restricting Task Manager..." -ForegroundColor Cyan
$tmKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
if (-not (Test-Path $tmKey)) { New-Item -Path $tmKey -Force | Out-Null }
Set-ItemProperty -Path $tmKey -Name "DisableTaskMgr" -Value 1 -Type DWord
Write-Host "[OK] Task Manager restricted for this user" -ForegroundColor Green

# ── 9. Launch the app ──────────────────────────────────────
Start-Process $destExe
Write-Host "[OK] Incognito Guard is now running" -ForegroundColor Green

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Setup complete! Restart your browsers." -ForegroundColor Green
Write-Host "  Installed to: $installDir" -ForegroundColor White
Write-Host "  Default PIN: 1234 (change in Settings)" -ForegroundColor Yellow
Write-Host "  Children cannot delete or move the app." -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
