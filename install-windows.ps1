# Nitro terminal setup - Windows side.
# Run from an ADMIN PowerShell window, in this folder:
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   .\install-windows.ps1
# Options: -SkipWsl (don't install WSL/Ubuntu), -SkipCliTools (only terminal, shell, prompt, font),
#          -SkipAI (don't install the oh-my-pi coding agent)
# Safe to re-run: installed packages are skipped and replaced config files are backed up.
# Keep this file ASCII-only: Windows PowerShell 5.1 misreads non-ASCII in BOM-less files.

[CmdletBinding()]
param(
    [switch]$SkipWsl,
    [switch]$SkipCliTools,
    [switch]$SkipAI
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Run this from an Administrator PowerShell window (needed for WSL and fonts).' }
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget not found. Install "App Installer" from the Microsoft Store, then re-run.'
}

function Install-WingetPackage([string]$Id) {
    # Native commands + 'Stop' can throw on stderr in Windows PowerShell 5.1.
    $ErrorActionPreference = 'Continue'
    winget list --id $Id --exact --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host "  [skip] $Id already installed"; return }
    Write-Host "  [install] $Id"
    winget install --id $Id --exact --source winget --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { Write-Warning "winget could not install $Id (exit $LASTEXITCODE)" }
}

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

Write-Host '==> Core: Windows Terminal, PowerShell 7, Git, Starship'
'Microsoft.WindowsTerminal', 'Microsoft.PowerShell', 'Git.Git', 'Starship.Starship' |
    ForEach-Object { Install-WingetPackage $_ }

if (-not $SkipCliTools) {
    Write-Host '==> CLI tools for PowerShell: eza, bat, fzf, ripgrep, fd, zoxide, Neovim, lazygit'
    'eza-community.eza', 'sharkdp.bat', 'junegunn.fzf', 'BurntSushi.ripgrep.MSVC', 'sharkdp.fd',
    'ajeetdsouza.zoxide', 'Neovim.Neovim', 'JesseDuffield.lazygit' |
        ForEach-Object { Install-WingetPackage $_ }
}

if (-not $SkipAI) {
    Write-Host '==> AI coding agent: oh-my-pi (omp)'
    $omp = Get-Command omp -ErrorAction SilentlyContinue
    if ($omp) {
        Write-Host "  [skip] omp already installed at $($omp.Source)"
    } else {
        Install-WingetPackage 'can1357.oh-my-pi'
    }
}

Write-Host '==> Font: JetBrainsMono Nerd Font'
$fontInstalled = Get-ChildItem "$env:WINDIR\Fonts", "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -Filter 'JetBrainsMonoNerdFont*' -ErrorAction SilentlyContinue
if ($fontInstalled) {
    Write-Host '  [skip] already installed'
} else {
    Install-WingetPackage 'DEVCOM.JetBrainsMonoNerdFont'
    $fontInstalled = Get-ChildItem "$env:WINDIR\Fonts", "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -Filter 'JetBrainsMonoNerdFont*' -ErrorAction SilentlyContinue
    if (-not $fontInstalled) {
        Write-Host '  winget package unavailable; downloading from the Nerd Fonts GitHub release'
        $tmp = Join-Path $env:TEMP "nerdfont-$(Get-Random)"
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $zip = Join-Path $tmp 'JetBrainsMono.zip'
        Invoke-WebRequest 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip' -OutFile $zip -UseBasicParsing
        Expand-Archive $zip -DestinationPath $tmp
        $fontsDir = "$env:WINDIR\Fonts"
        $regKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        Get-ChildItem $tmp -Filter 'JetBrainsMonoNerdFont-*.ttf' | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $fontsDir $_.Name) -Force
            New-ItemProperty -Path $regKey -Name "$($_.BaseName) (TrueType)" -Value $_.Name -PropertyType String -Force | Out-Null
        }
        Remove-Item $tmp -Recurse -Force
        Write-Host '  installed from GitHub'
    }
}

if (-not $SkipWsl) {
    Write-Host '==> WSL2 resource limits (.wslconfig)'
    $wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
    if (Test-Path $wslConfig) {
        Write-Host "  [skip] $wslConfig already exists; leaving it alone"
    } else {
        $totalGB = [math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
        $wslGB = [math]::Max(4, [math]::Floor($totalGB / 2))
        @(
            '# Created by nitro-terminal-setup. Caps WSL so games keep most of the RAM.'
            '[wsl2]'
            "memory=${wslGB}GB"
            'swap=4GB'
            ''
            '[experimental]'
            '# Hand unused WSL memory back to Windows over time.'
            'autoMemoryReclaim=gradual'
        ) | Set-Content $wslConfig -Encoding ascii
        Write-Host "  wrote $wslConfig (memory=${wslGB}GB of ${totalGB}GB)"
    }

    Write-Host '==> WSL2 + Ubuntu'
    $distros = & { $ErrorActionPreference = 'Continue'; (wsl.exe --list --quiet 2>$null) -replace "`0", '' } |
        Where-Object { $_ }
    if ($distros -match '^Ubuntu') {
        Write-Host '  [skip] Ubuntu already installed'
    } else {
        & { $ErrorActionPreference = 'Continue'; wsl.exe --install --distribution Ubuntu --no-launch }
        Write-Host '  Ubuntu installed. A reboot may be needed before it can start.'
    }
}

Write-Host '==> Configure PowerShell 7 profile, Starship and Windows Terminal'
Update-SessionPath
$pwsh = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
if (-not (Test-Path $pwsh)) { $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source }
if (-not $pwsh) { throw 'PowerShell 7 (pwsh) not found after install. Open a new window and run windows\configure.ps1 with pwsh.' }
& $pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'windows\configure.ps1')

Write-Host ''
Write-Host 'Windows side done. Next:'
Write-Host '  1. Reboot if WSL was just installed.'
Write-Host '  2. Open Windows Terminal -> Ubuntu tab, create your Linux username/password.'
Write-Host '  3. In Ubuntu, run the WSL installer from this folder, e.g.:'
$wslPath = '/mnt/' + $here.Substring(0, 1).ToLower() + ($here.Substring(2) -replace '\\', '/')
Write-Host "       bash '$wslPath/wsl/install-wsl.sh'"
