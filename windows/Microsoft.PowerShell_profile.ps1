# PowerShell 7 profile - Nitro terminal setup
# Installed to $PROFILE by windows\configure.ps1. Keep this file ASCII-only.

function Test-Command($Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

# --- PSReadLine: history predictions, menu completion -------------------------
if (Get-Module -ListAvailable PSReadLine) {
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView
    Set-PSReadLineOption -HistoryNoDuplicates -MaximumHistoryCount 20000
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# --- Theme for CLI tools --------------------------------------------------------
$env:BAT_THEME = 'Catppuccin Mocha'
$env:FZF_DEFAULT_OPTS = @(
    '--height=40% --layout=reverse --border'
    '--color=bg+:#313244,spinner:#F5E0DC,hl:#F38BA8'
    '--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC'
    '--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8'
    '--color=selected-bg:#45475A,border:#6C7086,label:#CDD6F4'
) -join ' '
if (Test-Command fd) { $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git' }

# --- Modern replacements for ls / cat / grep -----------------------------------
if (Test-Command eza) {
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls { eza --icons --group-directories-first @args }
    function ll { eza -la --icons --git --group-directories-first @args }
    function lt { eza --tree --level=2 --icons @args }
}
if (Test-Command bat) { function bcat { bat --paging=never @args } }
if (Test-Command nvim) { Set-Alias vim nvim }
if (Test-Command lazygit) { Set-Alias lg lazygit }

# --- fzf: Ctrl+R history, Ctrl+T files ------------------------------------------
if ((Test-Command fzf) -and (Get-Module -ListAvailable PSFzf)) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# --- Quick hop into the WSL Ubuntu home dir --------------------------------------
function dev { wsl.exe --cd ~ @args }

# --- zoxide (z / zi) and Starship prompt; keep these last ------------------------
if (Test-Command zoxide) { Invoke-Expression (& { (zoxide init powershell | Out-String) }) }
if (Test-Command starship) { Invoke-Expression (&starship init powershell) }
