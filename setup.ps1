param([switch]$Elevated)

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) {
        Write-Host "Error !! You need to run this script as an Administrator !!"
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    }
    exit
}
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

choco upgrade -y all

<#
    The MIT License (MIT)

    Copyright (c) 2016 QuietusPlus

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
#>

function Write-Menu {
    <#
        .SYNOPSIS
            Outputs a command-line menu which can be navigated using the keyboard.

        .DESCRIPTION
            Outputs a command-line menu which can be navigated using the keyboard.

            * Automatically creates multiple pages if the entries cannot fit on-screen.
            * Supports nested menus using a combination of hashtables and arrays.
            * No entry / page limitations (apart from device performance).
            * Sort entries using the -Sort parameter.
            * -MultiSelect: Use space to check a selected entry, all checked entries will be invoked / returned upon confirmation.
            * Jump to the top / bottom of the page using the "Home" and "End" keys.
            * "Scrolling" list effect by automatically switching pages when reaching the top/bottom.
            * Nested menu indicator next to entries.
            * Remembers parent menus: Opening three levels of nested menus means you have to press "Esc" three times.

            Controls             Description
            --------             -----------
            Up                   Previous entry
            Down                 Next entry
            Left / PageUp        Previous page
            Right / PageDown     Next page
            Home                 Jump to top
            End                  Jump to bottom
            Space                Check selection (-MultiSelect only)
            Enter                Confirm selection
            Esc / Backspace      Exit / Previous menu

        .EXAMPLE
            PS C:\>$menuReturn = Write-Menu -Title 'Menu Title' -Entries @('Menu Option 1', 'Menu Option 2', 'Menu Option 3', 'Menu Option 4')

            Output:

              Menu Title

               Menu Option 1
               Menu Option 2
               Menu Option 3
               Menu Option 4

        .EXAMPLE
            PS C:\>$menuReturn = Write-Menu -Title 'AppxPackages' -Entries (Get-AppxPackage).Name -Sort

            This example uses Write-Menu to sort and list app packages (Windows Store/Modern Apps) that are installed for the current profile.

        .EXAMPLE
            PS C:\>$menuReturn = Write-Menu -Title 'Advanced Menu' -Sort -Entries @{
                'Command Entry' = '(Get-AppxPackage).Name'
                'Invoke Entry' = '@(Get-AppxPackage).Name'
                'Hashtable Entry' = @{
                    'Array Entry' = "@('Menu Option 1', 'Menu Option 2', 'Menu Option 3', 'Menu Option 4')"
                }
            }

            This example includes all possible entry types:

            Command Entry     Invoke without opening as nested menu (does not contain any prefixes)
            Invoke Entry      Invoke and open as nested menu (contains the "@" prefix)
            Hashtable Entry   Opened as a nested menu
            Array Entry       Opened as a nested menu

        .NOTES
            Write-Menu by QuietusPlus (inspired by "Simple Textbased Powershell Menu" [Michael Albert])

        .LINK
            https://quietusplus.github.io/Write-Menu

        .LINK
            https://github.com/QuietusPlus/Write-Menu
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('InputObject')]
        $Entries,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [string]
        $Title,
        [Parameter()]
        [switch]
        $Sort,
        [Parameter()]
        [switch]
        $MultiSelect
    )
    $script:cfgPrefix = ' '
    $script:cfgPadding = 2
    $script:cfgSuffix = ' '
    $script:cfgNested = ' >'
    $script:cfgWidth = 30
    [System.Console]::CursorVisible = $false
    $script:colorForeground = [System.Console]::ForegroundColor
    $script:colorBackground = [System.Console]::BackgroundColor
    if ($Entries -like $null) {
        Write-Error "Missing -Entries parameter!"
        return
    }
    if ($host.Name -ne 'ConsoleHost') {
        Write-Error "[$($host.Name)] Cannot run inside current host, please use a console window instead!"
        return
    }
    function Set-Color ([switch]$Inverted) {
        switch ($Inverted) {
            $true {
                [System.Console]::ForegroundColor = $colorBackground
                [System.Console]::BackgroundColor = $colorForeground
            }
            Default {
                [System.Console]::ForegroundColor = $colorForeground
                [System.Console]::BackgroundColor = $colorBackground
            }
        }
    }
    function Get-Menu ($script:inputEntries) {
        Clear-Host
        if ($Title -notlike $null) {
            $host.UI.RawUI.WindowTitle = $Title
            $script:menuTitle = "$Title"
        } else {
            $script:menuTitle = 'Menu'
        }
        $script:pageSize = ($host.UI.RawUI.WindowSize.Height - 5)
        $script:menuEntries = @()
        switch ($inputEntries.GetType().Name) {
            'String' {
                $script:menuEntryTotal = 1
                $script:menuEntries = New-Object PSObject -Property @{
                    Command = ''
                    Name = $inputEntries
                    Selected = $false
                    onConfirm = 'Name'
                }; break
            }
            'Object[]' {
                $script:menuEntryTotal = $inputEntries.Length
                foreach ($i in 0..$($menuEntryTotal - 1)) {
                    $script:menuEntries += New-Object PSObject -Property @{
                        Command = ''
                        Name = $($inputEntries)[$i]
                        Selected = $false
                        onConfirm = 'Name'
                    }; $i++
                }; break
            }
            'Hashtable' {
                $script:menuEntryTotal = $inputEntries.Count
                foreach ($i in 0..($menuEntryTotal - 1)) {
                    if ($menuEntryTotal -eq 1) {
                        $tempName = $($inputEntries.Keys)
                        $tempCommand = $($inputEntries.Values)
                    } else {
                        $tempName = $($inputEntries.Keys)[$i]
                        $tempCommand = $($inputEntries.Values)[$i]
                    }
                    if ($tempCommand.GetType().Name -eq 'Hashtable') {
                        $tempAction = 'Hashtable'
                    } elseif ($tempCommand.Substring(0,1) -eq '@') {
                        $tempAction = 'Invoke'
                    } else {
                        $tempAction = 'Command'
                    }
                    $script:menuEntries += New-Object PSObject -Property @{
                        Name = $tempName
                        Command = $tempCommand
                        Selected = $false
                        onConfirm = $tempAction
                    }; $i++
                }; break
            }
            Default {
                Write-Error "Type `"$($inputEntries.GetType().Name)`" not supported, please use an array or hashtable."
                exit
            }
        }
        if ($Sort -eq $true) {
            $script:menuEntries = $menuEntries | Sort-Object -Property Name
        }
        $script:entryWidth = ($menuEntries.Name | Measure-Object -Maximum -Property Length).Maximum
        if ($MultiSelect) { $script:entryWidth += 4 }
        if ($entryWidth -lt $cfgWidth) { $script:entryWidth = $cfgWidth }
        $script:pageWidth = $cfgPrefix.Length + $cfgPadding + $entryWidth + $cfgPadding + $cfgSuffix.Length
        $script:pageCurrent = 0
        $script:pageTotal = [math]::Ceiling((($menuEntryTotal - $pageSize) / $pageSize))
        [System.Console]::WriteLine("")
        $script:lineTitle = [System.Console]::CursorTop
        [System.Console]::WriteLine("  $menuTitle" + "`n")
        $script:lineTop = [System.Console]::CursorTop
    }
    function Get-Page {
        if ($pageTotal -ne 0) { Update-Header }
        for ($i = 0; $i -le $pageSize; $i++) {
            [System.Console]::WriteLine("".PadRight($pageWidth) + ' ')
        }
        [System.Console]::CursorTop = $lineTop
        $script:pageEntryFirst = ($pageSize * $pageCurrent)
        if ($pageCurrent -eq $pageTotal) {
            $script:pageEntryTotal = ($menuEntryTotal - ($pageSize * $pageTotal))
        } else {
            $script:pageEntryTotal = $pageSize
        }
        $script:lineSelected = 0
        for ($i = 0; $i -le ($pageEntryTotal - 1); $i++) {
            Write-Entry $i
        }
    }
    function Write-Entry ([int16]$Index, [switch]$Update) {
        switch ($Update) {
            $true { $lineHighlight = $false; break }
            Default { $lineHighlight = ($Index -eq $lineSelected) }
        }
        $pageEntry = $menuEntries[($pageEntryFirst + $Index)].Name
        if ($MultiSelect) {
            switch ($menuEntries[($pageEntryFirst + $Index)].Selected) {
                $true { $pageEntry = "[X] $pageEntry"; break }
                Default { $pageEntry = "[ ] $pageEntry" }
            }
        }
        switch ($menuEntries[($pageEntryFirst + $Index)].onConfirm -in 'Hashtable', 'Invoke') {
            $true { $pageEntry = "$pageEntry".PadRight($entryWidth) + "$cfgNested"; break }
            Default { $pageEntry = "$pageEntry".PadRight($entryWidth + $cfgNested.Length) }
        }
        [System.Console]::Write("`r" + $cfgPrefix)
        if ($lineHighlight) { Set-Color -Inverted }
        [System.Console]::Write("".PadLeft($cfgPadding) + $pageEntry + "".PadRight($cfgPadding))
        if ($lineHighlight) { Set-Color }
        [System.Console]::Write($cfgSuffix + "`n")
    }
    function Update-Entry ([int16]$Index) {
        [System.Console]::CursorTop = ($lineTop + $lineSelected)
        Write-Entry $lineSelected -Update
        $script:lineSelected = $Index
        [System.Console]::CursorTop = ($lineTop + $Index)
        Write-Entry $lineSelected
        [System.Console]::CursorTop = $lineTop
    }
    function Update-Header {
        $pCurrent = ($pageCurrent + 1)
        $pTotal = ($pageTotal + 1)
        $pOffset = ($pTotal.ToString()).Length
        $script:pageNumber = "{0,-$pOffset}{1,0}" -f "$("$pCurrent".PadLeft($pOffset))","/$pTotal"
        [System.Console]::CursorTop = $lineTitle
        [System.Console]::CursorLeft = ($pageWidth - ($pOffset * 2) - 1)
        [System.Console]::WriteLine("$pageNumber")
    }
    Get-Menu $Entries
    Get-Page
    $menuNested = [ordered]@{}
    do { $inputLoop = $true
        [System.Console]::CursorTop = $lineTop
        [System.Console]::Write("`r")
        $menuInput = [System.Console]::ReadKey($false)
        $entrySelected = $menuEntries[($pageEntryFirst + $lineSelected)]
        switch ($menuInput.Key) {
            { $_ -in 'Escape', 'Backspace' } {
                if ($menuNested.Count -ne 0) {
                    $pageCurrent = 0
                    $Title = $($menuNested.GetEnumerator())[$menuNested.Count - 1].Name
                    Get-Menu $($menuNested.GetEnumerator())[$menuNested.Count - 1].Value
                    Get-Page
                    $menuNested.RemoveAt($menuNested.Count - 1) | Out-Null
                } else {
                    Clear-Host
                    $inputLoop = $false
                    [System.Console]::CursorVisible = $true
                    return $null
                }; break
            }
            'DownArrow' {
                if ($lineSelected -lt ($pageEntryTotal - 1)) {
                    Update-Entry ($lineSelected + 1)
                } elseif ($pageCurrent -ne $pageTotal) {
                    $pageCurrent++
                    Get-Page
                }; break
            }
            'UpArrow' {
                if ($lineSelected -gt 0) {
                    Update-Entry ($lineSelected - 1)
                } elseif ($pageCurrent -ne 0) {
                    $pageCurrent--
                    Get-Page
                    Update-Entry ($pageEntryTotal - 1)
                }; break
            }
            'Home' {
                if ($lineSelected -ne 0) {
                    Update-Entry 0
                } elseif ($pageCurrent -ne 0) {
                    $pageCurrent--
                    Get-Page
                    Update-Entry ($pageEntryTotal - 1)
                }; break
            }
            'End' {
                if ($lineSelected -ne ($pageEntryTotal - 1)) {
                    Update-Entry ($pageEntryTotal - 1)
                } elseif ($pageCurrent -ne $pageTotal) {
                    $pageCurrent++
                    Get-Page
                }; break
            }
            { $_ -in 'RightArrow','PageDown' } {
                if ($pageCurrent -lt $pageTotal) {
                    $pageCurrent++
                    Get-Page
                }; break
            }
            { $_ -in 'LeftArrow','PageUp' } {
                if ($pageCurrent -gt 0) {
                    $pageCurrent--
                    Get-Page
                }; break
            }
            'Spacebar' {
                if ($MultiSelect) {
                    switch ($entrySelected.Selected) {
                        $true { $entrySelected.Selected = $false }
                        $false { $entrySelected.Selected = $true }
                    }
                    Update-Entry ($lineSelected)
                }; break
            }
            'Insert' {
                if ($MultiSelect) {
                    $menuEntries | ForEach-Object {
                        $_.Selected = $true
                    }
                    Get-Page
                }; break
            }
            'Delete' {
                if ($MultiSelect) {
                    $menuEntries | ForEach-Object {
                        $_.Selected = $false
                    }
                    Get-Page
                }; break
            }
            'Enter' {
                if ($MultiSelect) {
                    Clear-Host
                    $menuEntries | ForEach-Object {
                        if (($_.Selected) -and ($_.Command -notlike $null) -and ($entrySelected.Command.GetType().Name -ne 'Hashtable')) {
                            Invoke-Expression -Command $_.Command
                        } elseif ($_.Selected) {
                            return $_.Name
                        }
                    }
                    $inputLoop = $false
                    [System.Console]::CursorVisible = $true
                    break
                }
                switch ($entrySelected.onConfirm) {
                    'Hashtable' {
                        $menuNested.$Title = $inputEntries
                        $Title = $entrySelected.Name
                        Get-Menu $entrySelected.Command
                        Get-Page
                        break
                    }
                    'Invoke' {
                        $menuNested.$Title = $inputEntries
                        $Title = $entrySelected.Name
                        Get-Menu $(Invoke-Expression -Command $entrySelected.Command.Substring(1))
                        Get-Page
                        break
                    }
                    'Command' {
                        Clear-Host
                        Invoke-Expression -Command $entrySelected.Command
                        $inputLoop = $false
                        [System.Console]::CursorVisible = $true
                        break
                    }
                    'Name' {
                        Clear-Host
                        return $entrySelected.Name
                        $inputLoop = $false
                        [System.Console]::CursorVisible = $true
                    }
                }
            }
        }
    } while ($inputLoop)
}

<#
    Main Script
#>

$menuReturn = Write-Menu -Title 'Select Install' -MultiSelect  @{
    'VSCode' = 'choco install -y vscode';
    '7zip' = 'choco install -y 7zip.install';
    'gsudo' = 'choco install -y gsudo';
    'Notepad++' = 'choco install -y notepadplusplus.install';
    'Node.js' = 'choco install -y nodejs';
    'VLC Nightly' = 'choco install -y vlc-nightly';
    'Windows Terminal' = 'choco install -y microsoft-windows-terminal';
    'Oh My Posh' = 'choco install -y oh-my-posh';
    'Neovim' = 'choco install -y neovim';
    'Nerd Fonts Hack' = 'choco install -y nerd-fonts-hack';
    'Nerd Fonts FiraCode' = 'choco install -y nerd-fonts-firacode';
    'Git' = 'choco install -y git --package-parameters="/GitAndUnixToolsOnPath /WindowsTerminal"';
}
$menuReturn

# choco install -y vscode
# choco install -y 7zip.install
# choco install -y gsudo
# choco install -y notepadplusplus.install
# choco install -y nodejs
# choco install -y vlc-nightly
# choco install -y microsoft-windows-terminal
# choco install -y oh-my-posh
# choco install -y neovim
# choco install -y nerd-fonts-hack
# choco install -y nerd-fonts-firacode
# choco install -y git --package-parameters="'/GitAndUnixToolsOnPath /WindowsTerminal'"
PowerShellGet\Install-Module Terminal-Icons -Scope CurrentUser -Force
PowerShellGet\Install-Module posh-git -Scope CurrentUser -Force
PowerShellGet\Install-Module PSReadLine -Scope CurrentUser -Force
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




if (!(Test-Path -Path ($env:LOCALAPPDATA + "\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json") -PathType Leaf)) {
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
