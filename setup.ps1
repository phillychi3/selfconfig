Disable-UAC
Packeges = @{
    "vscode",
    "git",
    "7zip.install",
    "terminal-icons.powershell",
    "poshgit",
    "gsudo",
    "notepadplusplus.install",
    "nodejs",
    "vlc-nightly",
    "microsoft-windows-terminal"
    "oh-my-posh",
    "neovim"
}

Fontes = @(
    "nerd-fonts-hack",
    "nerd-fonts-firacode"
)

choco upgrade -y all
choco install -y $Chocolatey_Packeges
choco install -y $Fontes
choco install -y git --package-parameters="'/GitAndUnixToolsOnPath /WindowsTerminal'"
executeScript
npm i -g @antfu/ni


if (!(Test-Path -Path $PROFILE -PathType Leaf)) {
    try {

        if (!(Test-Path -Path ($env:userprofile + "\Documents\PowerShell"))) {
            New-Item -Path ($env:userprofile + "\Documents\PowerShell") -ItemType "directory"
        }
        Invoke-RestMethod https://github.com/phillychi3/selfconfig/raw/main/powershell/powershellprofile.ps1 -OutFile $PROFILE
        Write-Host "created profile success"
    }
    catch {
        throw $_.Exception.Message
    }
}
else {
    Get-Item -Path $PROFILE | Move-Item -Destination oldpowershellprofile.ps1 -Force
    Invoke-RestMethod https://github.com/phillychi3/selfconfig/raw/main/powershell/powershellprofile.ps1 -OutFile $PROFILE
    Write-Host "updated profile success"
    Write-Host "old profile saved as oldpowershellprofile.ps1"
}
& $profile

# 終端機 (穩定/一般版本) ： %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
# 終端機 (預覽版本) ： %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json
# 終端機 (未封裝：) ：) ： %LOCALAPPDATA%\Microsoft\Windows Terminal\settings.json
if (!(Test-Path -Path ($env:LOCALAPPDATA + "\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" -PathType Leaf))) {
    try {
        Invoke-RestMethod https://github.com/phillychi3/selfconfig/raw/main/powershell/setting.json -OutFile ($env:LOCALAPPDATA + "\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json")
        Write-Host "created windows terminal settings success"
    }
    catch {
        throw $_.Exception.Message
    }
}
else {
    Get-Item -Path ($env:LOCALAPPDATA + "\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json") | Move-Item -Destination oldsettings.json -Force
    Invoke-RestMethod https://github.com/phillychi3/selfconfig/raw/main/powershell/setting.json -OutFile ($env:LOCALAPPDATA + "\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json")
    Write-Host "updated windows terminal settings success"
    Write-Host "old settings saved as oldsettings.json"
}

# git clone https://github.com/phillychi3/selfconfig $HOME\AppData\Local\nvim --depth 1
# Get-ChildItem -Path $HOME\AppData\Local\nvim | Where-Object { $_.Name -ne "neovim" } | Remove-Item -Force -Recurse
# Get-ChildItem -Path $HOME\AppData\Local\nvim\neovim | Move-Item -Destination $HOME\AppData\Local\nvim -Force -Recurse
# Remove-Item -Path $HOME\AppData\Local\nvim\neovim -Force -Recurse

# git clone https://github.com/phillychi3/cutenvim $HOME\AppData\Local\nvim --depth 1


Enable-UAC