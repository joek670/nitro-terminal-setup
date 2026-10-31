# Configures PowerShell 7, Starship and Windows Terminal.
# Runs under pwsh (PowerShell 7); install-windows.ps1 calls it, or run it directly:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File .\windows\configure.ps1
# Safe to re-run. Every file it replaces is backed up as <name>.bak-<timestamp>.

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Run this with pwsh (PowerShell 7), not Windows PowerShell 5.1.' }

$here   = $PSScriptRoot
$root   = Split-Path $here -Parent
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'

function Backup-File($Path) {
    if (Test-Path $Path) {
        Copy-Item $Path "$Path.bak-$stamp"
        Write-Host "  backed up $Path"
    }
}

function Install-ConfigFile($Source, $Destination) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
    Backup-File $Destination
    Copy-Item $Source $Destination -Force
    Unblock-File $Destination
    Write-Host "  wrote $Destination"
}

Write-Host '==> Execution policy (CurrentUser: RemoteSigned, so the profile can load)'
if ((Get-ExecutionPolicy -Scope CurrentUser) -in 'Undefined', 'Restricted', 'AllSigned') {
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
}

Write-Host '==> PowerShell modules'
foreach ($module in 'PSReadLine', 'PSFzf') {
    if (-not (Get-Module -ListAvailable $module)) {
        Install-Module $module -Scope CurrentUser -Force -AllowClobber
        Write-Host "  installed $module"
    }
}

Write-Host '==> PowerShell 7 profile'
Install-ConfigFile (Join-Path $here 'Microsoft.PowerShell_profile.ps1') $PROFILE.CurrentUserCurrentHost

Write-Host '==> Starship config'
Install-ConfigFile (Join-Path $root 'shared\starship.toml') (Join-Path $HOME '.config\starship.toml')

Write-Host '==> Windows Terminal'
$wtSettings = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $wtSettings) {
    Write-Warning 'Windows Terminal settings.json not found. Open Windows Terminal once, close it, then re-run this script.'
    return
}

Backup-File $wtSettings
# PowerShell 7's ConvertFrom-Json accepts the comments Windows Terminal writes.
$settings = Get-Content $wtSettings -Raw | ConvertFrom-Json -AsHashtable
$scheme   = Get-Content (Join-Path $here 'catppuccin-mocha.json') -Raw | ConvertFrom-Json -AsHashtable

$schemes = @($settings['schemes'] | Where-Object { $_ -and $_['name'] -ne $scheme['name'] })
$settings['schemes'] = $schemes + $scheme

if ($settings['profiles'] -isnot [System.Collections.IDictionary]) {
    Write-Warning 'settings.json uses the old list-only "profiles" format; leaving profiles untouched.'
} else {
    if (-not $settings['profiles']['defaults']) { $settings['profiles']['defaults'] = @{} }
    $defaults = $settings['profiles']['defaults']
    $defaults['colorScheme'] = 'Catppuccin Mocha'
    $defaults['font']        = @{ face = 'JetBrainsMono Nerd Font'; size = 11 }
    $defaults['cursorShape'] = 'bar'
    $defaults['padding']     = '8'
    $defaults['opacity']     = 95
    $defaults['useAcrylic']  = $false

    $pwshProfile = $settings['profiles']['list'] |
        Where-Object { $_['source'] -eq 'Windows.Terminal.PowershellCore' -and -not $_['hidden'] } |
        Select-Object -First 1
    if ($pwshProfile) {
        $settings['defaultProfile'] = $pwshProfile['guid']
        Write-Host '  default profile -> PowerShell 7'
    } else {
        Write-Warning 'No PowerShell 7 profile in Windows Terminal yet. Restart Windows Terminal and re-run to make it the default.'
    }
}

$settings['theme'] = 'dark'
$settings | ConvertTo-Json -Depth 32 | Set-Content $wtSettings -Encoding utf8
Write-Host "  updated $wtSettings"

Write-Host ''
Write-Host 'Done. Quake drop-down terminal: Win + ` (backtick), built into Windows Terminal.'
