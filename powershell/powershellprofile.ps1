Remove-Item Alias:ni -Force -ErrorAction Ignore
Import-Module posh-git
Import-Module Terminal-Icons
Import-Module 'C:\tools\gsudo\Current\gsudoModule.psd1'
Import-Module PSReadLine

Set-PSReadLineKeyHandler -Key "Tab" -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-Alias -Name v -Value nvim
oh-my-posh init pwsh --config 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/1_shell.omp.json' | Invoke-Expression