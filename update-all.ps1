# Updates everything the Nitro terminal setup installed, plus every other winget app.
#
# Run now (admin PowerShell, any version):
#   irm https://raw.githubusercontent.com/joek670/nitro-terminal-setup/main/update-all.ps1 | iex
# From the repo folder, with options:
#   .\update-all.ps1                 run now
#   .\update-all.ps1 -Register       run now's steps on a schedule: weekly, Sunday 12:00 (see -Day / -At)
#   .\update-all.ps1 -Unregister     remove the scheduled task
#   -SkipWinget / -SkipWsl           leave that half out
#
# Runs under Windows PowerShell 5.1 on purpose: winget may upgrade PowerShell 7 itself,
# which fails if the updater is running inside it. Keep this file ASCII-only.
# Logs: %LOCALAPPDATA%\nitro-terminal-setup\logs (last 10 kept).

[CmdletBinding()]
param(
    [switch]$Register,
    [switch]$Unregister,
    [ValidateSet('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')]
    [string]$Day = 'Sunday',
    [string]$At = '12:00',
    [switch]$SkipWinget,
    [switch]$SkipWsl
)

$ErrorActionPreference = 'Continue'
$taskName  = 'Nitro terminal setup - update all'
$home_     = Join-Path $env:LOCALAPPDATA 'nitro-terminal-setup'
$installed = Join-Path $home_ 'update-all.ps1'
$logDir    = Join-Path $home_ 'logs'
$rawUrl    = 'https://raw.githubusercontent.com/joek670/nitro-terminal-setup/main/update-all.ps1'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if ($Unregister) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed scheduled task '$taskName' (if it existed)."
    return
}

if ($Register) {
    if (-not $isAdmin) { throw 'Run -Register from an Administrator PowerShell window.' }
    New-Item -ItemType Directory -Force -Path $home_ | Out-Null
    # The task runs a local copy, so a change on GitHub never runs as admin unseen.
    if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
        Copy-Item $PSCommandPath $installed -Force
    } else {
        Invoke-WebRequest $rawUrl -OutFile $installed -UseBasicParsing
    }
    Unblock-File $installed

    $action = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installed`""
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Day -At $At
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal `
        -Settings $settings -Description 'Updates winget apps, omp, WSL, Ubuntu, Homebrew and Neovim plugins.' -Force | Out-Null
    Write-Host "Scheduled '$taskName': every $Day at $At (runs at next login if the laptop was off)."
    Write-Host "Script copy: $installed"
    Write-Host 'Running it once now...'
}

if (-not $isAdmin) { Write-Warning 'Not running as Administrator: some winget upgrades and wsl --update may fail.' }

New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir ("update-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Start-Transcript -Path $log | Out-Null
Get-ChildItem $logDir -Filter 'update-*.log' | Sort-Object Name -Descending | Select-Object -Skip 10 | Remove-Item -Force

$results = New-Object System.Collections.Generic.List[string]
function Invoke-Step([string]$Name, [scriptblock]$Body) {
    Write-Host ''
    Write-Host "==> $Name" -ForegroundColor Cyan
    $global:LASTEXITCODE = 0
    try {
        # Pipe through Write-Host so native output lands in the transcript (5.1 skips it otherwise).
        & $Body 2>&1 | ForEach-Object { Write-Host (([string]$_) -replace "`0", '') }
        if ($LASTEXITCODE -ne 0) { $results.Add("WARN  $Name (exit $LASTEXITCODE)") } else { $results.Add("OK    $Name") }
    } catch {
        Write-Host $_ -ForegroundColor Red
        $results.Add("FAIL  $Name ($($_.Exception.Message))")
    }
}

$wslUbuntu = $false
if (-not $SkipWsl) {
    $distros = (wsl.exe --list --quiet 2>$null) -replace "`0", '' | Where-Object { $_ }
    $wslUbuntu = [bool]($distros -match '^Ubuntu$')
}
function Invoke-Wsl([string]$Command, [switch]$AsRoot) {
    # Windows PowerShell 5.1 mangles embedded double quotes in native arguments,
    # so ship the bash command base64-encoded.
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Command))
    $wslArgs = @('-d', 'Ubuntu')
    if ($AsRoot) { $wslArgs += @('-u', 'root') }
    wsl.exe @wslArgs -- bash -c "echo $b64 | base64 -d | bash"
}
$brewEnv = 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"; export PATH="$HOME/.bun/bin:$PATH"'

if (-not $SkipWinget) {
    Invoke-Step 'winget: upgrade all apps' {
        winget source update --disable-interactivity | Out-Null
        winget upgrade --all --silent --disable-interactivity --accept-package-agreements --accept-source-agreements
        # -1978335189 = "no applicable upgrade"; not an error.
        if ($LASTEXITCODE -eq -1978335189) { $global:LASTEXITCODE = 0 }
    }
}

if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    Invoke-Step 'PowerShell 7 modules: PSFzf, PSReadLine' {
        $moduleScript = @'
foreach ($m in 'PSFzf', 'PSReadLine') {
    if (Get-InstalledModule $m -ErrorAction SilentlyContinue) { Update-Module $m -Force -ErrorAction Continue }
    elseif ($m -eq 'PSReadLine') { Install-Module PSReadLine -Scope CurrentUser -Force -AllowClobber -ErrorAction Continue }
    Write-Output "$m $((Get-Module -ListAvailable $m | Sort-Object Version -Descending | Select-Object -First 1).Version)"
}
'@
        pwsh -NoProfile -EncodedCommand ([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($moduleScript)))
    }
}

if (Get-Command omp -ErrorAction SilentlyContinue) {
    Invoke-Step 'oh-my-pi (Windows)' { omp update }
}

if (-not $SkipWsl) {
    Invoke-Step 'WSL itself (wsl --update)' { wsl.exe --update }

    if ($wslUbuntu) {
        Invoke-Step 'Ubuntu packages (apt)' {
            Invoke-Wsl -AsRoot 'export DEBIAN_FRONTEND=noninteractive; apt-get update -q && apt-get -y -q full-upgrade && apt-get -y -q autoremove'
        }
        Invoke-Step 'Homebrew packages (tmux, sesh, Neovim, Starship, CLI tools, Bun)' {
            Invoke-Wsl "$brewEnv; brew update && brew upgrade && brew cleanup"
        }
        Invoke-Step 'oh-my-pi (WSL)' {
            Invoke-Wsl "$brewEnv; if command -v omp >/dev/null; then omp update; else echo 'omp not installed in WSL'; fi"
        }
        Invoke-Step 'Neovim plugins (LazyVim sync)' {
            Invoke-Wsl "$brewEnv; timeout 600 nvim --headless '+Lazy! sync' +qa"
        }
        Invoke-Step 'tmux Catppuccin theme' {
            Invoke-Wsl 'd=$HOME/.config/tmux/plugins/catppuccin/tmux; [ -d "$d/.git" ] && git -C "$d" fetch -q --tags --depth 1 origin && git -C "$d" checkout -q "$(git -C "$d" tag -l "v2.*" --sort=-v:refname | head -n 1)" && echo "catppuccin/tmux $(git -C "$d" describe --tags)" || echo "not installed"'
        }
    } else {
        $results.Add('SKIP  Ubuntu steps (no WSL distro named Ubuntu)')
    }
}

Write-Host ''
Write-Host '== Summary' -ForegroundColor Cyan
$results | ForEach-Object { Write-Host "  $_" }
Write-Host "  Log: $log"
Write-Host '  Windows itself, drivers and Store apps update through Windows Update / the Microsoft Store.'
Stop-Transcript | Out-Null
