# One-line installer for the Windows side. From an ADMIN PowerShell window:
#   irm https://raw.githubusercontent.com/joek670/nitro-terminal-setup/main/bootstrap.ps1 | iex
# Downloads this repo to %USERPROFILE%\nitro-terminal-setup and runs install-windows.ps1.
# An existing copy of that folder is renamed to nitro-terminal-setup.bak-<timestamp>.

$ErrorActionPreference = 'Stop'
Set-ExecutionPolicy -Scope Process Bypass -Force

$dest = Join-Path $env:USERPROFILE 'nitro-terminal-setup'
$work = Join-Path $env:TEMP "nitro-terminal-setup-$(Get-Random)"
$zip  = Join-Path $work 'repo.zip'

New-Item -ItemType Directory -Path $work | Out-Null
Write-Host '==> Downloading joek670/nitro-terminal-setup'
Invoke-WebRequest 'https://github.com/joek670/nitro-terminal-setup/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing
Expand-Archive $zip -DestinationPath $work

if (Test-Path $dest) {
    $backup = "$dest.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Move-Item $dest $backup
    Write-Host "  moved existing folder to $backup"
}
Move-Item (Join-Path $work 'nitro-terminal-setup-main') $dest
Remove-Item $work -Recurse -Force
Write-Host "  saved to $dest"

Set-Location $dest
& (Join-Path $dest 'install-windows.ps1')
