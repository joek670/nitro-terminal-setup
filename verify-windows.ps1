# Checks the Windows side of the Nitro terminal setup. Changes nothing.
# Run in a NEW PowerShell 7 window (so PATH changes from the install are picked up):
#   irm https://raw.githubusercontent.com/joek670/nitro-terminal-setup/main/verify-windows.ps1 | iex
# Keep this file ASCII-only.

$script:pass = 0; $script:fail = 0; $script:warn = 0
function Ok($m)   { Write-Host "  PASS  $m" -ForegroundColor Green;  $script:pass++ }
function Bad($m)  { Write-Host "  FAIL  $m" -ForegroundColor Red;    $script:fail++ }
function Meh($m)  { Write-Host "  WARN  $m" -ForegroundColor Yellow; $script:warn++ }
function Head($m) { Write-Host ''; Write-Host "== $m" -ForegroundColor Cyan }

function Test-Cmd([string]$Name, [string[]]$VersionArgs) {
    $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { Bad "$Name not found on PATH"; return }
    $ver = try { (& $cmd.Source @VersionArgs 2>&1 | Select-Object -First 1) -as [string] } catch { 'version unknown' }
    Ok "$Name  ($($ver.Trim()))"
}

Head 'Shell'
if ($PSVersionTable.PSVersion.Major -ge 7) { Ok "PowerShell $($PSVersionTable.PSVersion)" }
else { Bad "This is Windows PowerShell $($PSVersionTable.PSVersion). Open PowerShell 7 (pwsh) and re-run." }
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -in 'RemoteSigned', 'Unrestricted', 'Bypass') { Ok "Execution policy (CurrentUser): $policy" } else { Bad "Execution policy (CurrentUser) is $policy; the profile cannot load" }

Head 'Commands'
Test-Cmd pwsh '--version'
Test-Cmd git '--version'
Test-Cmd starship '--version'
Test-Cmd eza '--version'
Test-Cmd bat '--version'
Test-Cmd fzf '--version'
Test-Cmd rg '--version'
Test-Cmd fd '--version'
Test-Cmd zoxide '--version'
Test-Cmd nvim '--version'
Test-Cmd lazygit '--version'
Test-Cmd omp '--version'
if (Get-Command wt -ErrorAction SilentlyContinue) { Ok 'Windows Terminal (wt)' } else { Bad 'Windows Terminal (wt) not found' }

Head 'PowerShell profile and modules'
foreach ($m in 'PSReadLine', 'PSFzf') {
    $mod = Get-Module -ListAvailable $m | Sort-Object Version -Descending | Select-Object -First 1
    if ($mod) { Ok "$m module $($mod.Version)" } else { Bad "$m module not installed" }
}
$pwshProfile = $PROFILE.CurrentUserCurrentHost
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwshProfile = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Microsoft.PowerShell_profile.ps1'
}
if ((Test-Path $pwshProfile) -and (Select-String -Path $pwshProfile -Pattern 'starship init' -Quiet)) { Ok "Profile installed ($pwshProfile)" }
else { Bad "Profile missing or not ours ($pwshProfile)" }
if (Get-Command starship_precmd -ErrorAction SilentlyContinue -CommandType Function) { Ok 'Starship prompt active in this window' }
elseif ($env:STARSHIP_SHELL) { Ok 'Starship prompt active in this window' }
else { Meh 'Starship not active in this window (open a new PowerShell 7 tab and re-run)' }
if (Get-Command __zoxide_z -ErrorAction SilentlyContinue) { Ok 'zoxide (z) loaded' } else { Meh 'zoxide not loaded in this window' }
if ((Get-Command ll -ErrorAction SilentlyContinue).CommandType -eq 'Function') { Ok 'll / lt aliases loaded' } else { Meh 'll alias not loaded in this window' }

$starshipToml = Join-Path $HOME '.config\starship.toml'
if (Test-Path $starshipToml) { Ok "Starship config ($starshipToml)" } else { Bad "Starship config missing ($starshipToml)" }

Head 'Font'
$font = Get-ChildItem "$env:WINDIR\Fonts", "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -Filter 'JetBrainsMonoNerdFont*' -ErrorAction SilentlyContinue
if ($font) { Ok "JetBrainsMono Nerd Font ($($font.Count) files)" } else { Bad 'JetBrainsMono Nerd Font not installed' }

Head 'Windows Terminal settings'
$wtSettings = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $wtSettings) {
    Bad 'settings.json not found'
} else {
    try {
        $s = Get-Content $wtSettings -Raw | ConvertFrom-Json
        if ($s.schemes | Where-Object name -eq 'Catppuccin Mocha') { Ok 'Catppuccin Mocha scheme present' } else { Bad 'Catppuccin Mocha scheme missing' }
        $d = $s.profiles.defaults
        if ($d.colorScheme -eq 'Catppuccin Mocha') { Ok 'Catppuccin Mocha is the default scheme' } else { Bad "Default scheme is '$($d.colorScheme)'" }
        if ($d.font.face -eq 'JetBrainsMono Nerd Font') { Ok 'Default font is JetBrainsMono Nerd Font' } else { Bad "Default font is '$($d.font.face)'" }
        $def = $s.profiles.list | Where-Object guid -eq $s.defaultProfile | Select-Object -First 1
        if ($def.source -eq 'Windows.Terminal.PowershellCore') { Ok 'Default profile is PowerShell 7' } else { Meh "Default profile is '$($def.name)', not PowerShell 7" }
    } catch {
        Bad "Could not read settings.json: $($_.Exception.Message)"
    }
}

Head 'WSL'
$distros = (wsl.exe --list --quiet 2>$null) -replace "`0", '' | Where-Object { $_ }
$ubuntu = $distros | Where-Object { $_ -match '^Ubuntu' } | Select-Object -First 1
if ($ubuntu) { Ok "WSL distro: $ubuntu" } else { Bad 'No Ubuntu distro in WSL' }
$wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
if (Test-Path $wslConfig) {
    $mem = Select-String -Path $wslConfig -Pattern '^\s*memory\s*=\s*(.+)$' | Select-Object -First 1
    if ($mem) { Ok ".wslconfig caps WSL memory at $($mem.Matches[0].Groups[1].Value.Trim())" }
    else { Meh '.wslconfig has no memory= line, so WSL can use up to half your RAM (Windows default)' }
} else { Meh 'No .wslconfig (WSL defaults apply)' }

Head 'Summary'
Write-Host "  $script:pass passed, $script:fail failed, $script:warn warnings"
if ($script:fail -eq 0) { Write-Host '  Windows side is complete.' -ForegroundColor Green }
else { Write-Host '  Paste this output to Claude to fix the failures.' -ForegroundColor Yellow }
