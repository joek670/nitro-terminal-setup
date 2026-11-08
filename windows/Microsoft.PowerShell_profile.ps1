# PowerShell 7 profile - Nitro terminal setup
# Installed to $PROFILE by windows\configure.ps1. Keep this file ASCII-only.
#
# Kept fast on purpose: one PATH lookup for all tools, zoxide/Starship init scripts
# cached outside OneDrive, and PSFzf loaded once the prompt is idle.
# See where the time goes:  $env:NITRO_PROFILE_TIMING = 1; pwsh

$nitroClock = [Diagnostics.Stopwatch]::StartNew()
function Write-NitroTiming([string]$Label) {
    if ($env:NITRO_PROFILE_TIMING) { Write-Host ('{0,6} ms  {1}' -f $nitroClock.ElapsedMilliseconds, $Label) -ForegroundColor DarkGray }
}

# Find every tool the profile uses in one pass over PATH. A plain file check is
# ~15 ms; Get-Command costs ~250 ms the first time it runs in a session.
$nitroTools = @{}
$nitroExt = if ($IsWindows) { '.exe' } else { '' }
foreach ($dir in $env:PATH.Split([IO.Path]::PathSeparator)) {
    if (-not $dir) { continue }
    foreach ($name in 'eza', 'bat', 'fd', 'fzf', 'nvim', 'lazygit', 'zoxide', 'starship') {
        if ($nitroTools[$name]) { continue }
        $candidate = [IO.Path]::Combine($dir, $name + $nitroExt)
        if ([IO.File]::Exists($candidate)) { $nitroTools[$name] = $candidate }
    }
}
Remove-Variable dir, name, candidate, nitroExt -ErrorAction SilentlyContinue
Write-NitroTiming 'tool lookup'

# --- PSReadLine: history predictions, menu completion -------------------------
# PowerShell 7 loads PSReadLine itself in an interactive window; no module scan needed.
if (Get-Module PSReadLine) {
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView
    Set-PSReadLineOption -HistoryNoDuplicates -MaximumHistoryCount 20000
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}
Write-NitroTiming 'PSReadLine'

# --- Theme for CLI tools --------------------------------------------------------
$env:BAT_THEME = 'Catppuccin Mocha'
$env:FZF_DEFAULT_OPTS = @(
    '--height=40% --layout=reverse --border'
    '--color=bg+:#313244,spinner:#F5E0DC,hl:#F38BA8'
    '--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC'
    '--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8'
    '--color=selected-bg:#45475A,border:#6C7086,label:#CDD6F4'
) -join ' '
if ($nitroTools.fd) { $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git' }

# --- Modern replacements for ls / cat / grep -----------------------------------
if ($nitroTools.eza) {
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls { eza --icons --group-directories-first @args }
    function ll { eza -la --icons --git --group-directories-first @args }
    function lt { eza --tree --level=2 --icons @args }
}
if ($nitroTools.bat) { function bcat { bat --paging=never @args } }
if ($nitroTools.nvim) { Set-Alias vim nvim }
if ($nitroTools.lazygit) { Set-Alias lg lazygit }

# --- fzf: Ctrl+R history, Ctrl+T files ------------------------------------------
# Importing PSFzf takes a few hundred ms, so do it right after the first prompt appears.
if ($nitroTools.fzf -and (Get-Module PSReadLine)) {
    $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        if (Get-Module -ListAvailable PSFzf) {
            Import-Module PSFzf -Global
            Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
        }
    }
}

# --- Quick hop into the WSL Ubuntu home dir --------------------------------------
function dev { wsl.exe --cd ~ @args }
Write-NitroTiming 'aliases, fzf scheduled'

# --- zoxide (z / zi) and Starship prompt; keep these last ------------------------
# Their init scripts are cached in %LOCALAPPDATA% (not OneDrive) and rebuilt
# whenever the tool's exe is newer than the cache, e.g. after a winget upgrade.
function Import-NitroInit([string]$Name, [string]$Exe, [string[]]$InitArgs) {
    $dir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'nitro-terminal-setup\cache'
    $file = Join-Path $dir "$Name-init.ps1"
    $cached = Get-Item -LiteralPath $file -ErrorAction SilentlyContinue
    # winget puts some tools in WinGet\Links as symlinks; compare against the real exe.
    $exeItem = Get-Item -LiteralPath $Exe
    if ($exeItem.LinkTarget) {
        try { $exeItem = $exeItem.ResolveLinkTarget($true) } catch { }
    }
    if (-not $cached -or $cached.Length -eq 0 -or $exeItem.LastWriteTimeUtc -gt $cached.LastWriteTimeUtc) {
        $script = (& $Exe @InitArgs | Out-String)
        if (-not $script.Trim()) { return }
        $null = New-Item -ItemType Directory -Force -Path $dir
        Set-Content -LiteralPath $file -Value $script -Encoding utf8
    }
    $file
}
if ($nitroTools.zoxide) {
    $init = Import-NitroInit 'zoxide' $nitroTools.zoxide @('init', 'powershell')
    if ($init) { . $init }
    Write-NitroTiming 'zoxide'
}
if ($nitroTools.starship) {
    $init = Import-NitroInit 'starship' $nitroTools.starship @('init', 'powershell', '--print-full-init')
    if ($init) { . $init }
    Write-NitroTiming 'Starship'
}
Remove-Variable init -ErrorAction SilentlyContinue
