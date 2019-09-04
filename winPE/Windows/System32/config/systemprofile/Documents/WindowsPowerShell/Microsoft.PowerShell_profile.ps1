# https://docs.microsoft.com/ru-ru/powershell/scripting/core-powershell/ise/how-to-use-profiles-in-windows-powershell-ise?view=powershell-6



# $LabelIn = "(win.*7)|(win.*10)"  # 'win7' / 'win 7' / 'win10' / 'win 10' - метка диска с ОС-источником wim-образа

# $LabelOut = "alt-air"            # метка диска для сохранения файла install.wim


# $wimFile  = "install.wim"        # файл wim-образа

# $wimName  = "Win 10 Pro x64"     # имя wim-образа

# $wimDesc  = "by alt-air"         # описание wim-образа


# foreach ($d in (Get-PSProvider -PSProvider FileSystem).Drives)
# {
#     if ($d.Description -match $LabelIn)  {$inp = $d.Root}  # определили по метке диск-источник ОС
    
#     if ($d.Description -match $LabelOut) {$out = $d.Root}  # определили по метке диск для сохранения wim-образа
# }



Set-PSReadlineKeyHandler -Chord Ctrl+d -Function DeleteCharOrExit  # выход по сочетанию Ctrl + D


Set-PSReadlineKeyHandler -Chord Ctrl+f -ScriptBlock {  # запуск Far
    $d = "$env:SystemDrive"
    
    # if (Test-Path -Path "$env:SystemDrive\Debug-Mount_Z.cmd")
    # {
    #     . "$env:SystemDrive\Debug-Mount_Z.cmd"
        
    #     if (Test-Path -Path 'Z:\') { $d = 'Z:' }
    # }
    
    Start-Process -FilePath "$env:SystemDrive\Far\Far.exe" -ArgumentList "$d $env:WinDir\System32\config\systemprofile\Documents\WindowsPowerShell\Modules\"
}


Set-PSReadlineKeyHandler -Chord Ctrl+u -ScriptBlock {  # перезагрузка модуля Wenix
    Get-Module -Name Wenix | Remove-Module
    
    Import-Module -Force Wenix
    
    Get-Module -Name Wenix
}

# Set-PSReadlineKeyHandler -Chord Ctrl+i -ScriptBlock {
# # захват образа на USB drive
#     $str = '/Capture-Image /CaptureDir:' + $inp + ' /ImageFile:"' + $out + $wimFile + '" /Name:"' + $wimName + '" /Description:"' + $wimDesc + '"'
#     Start-Process -FilePath $env:windir\System32\Dism.exe -ArgumentList $str
# }

# Set-PSReadlineKeyHandler -Chord Ctrl+Alt+i -ScriptBlock {
#     <#
#         чтобы во время работы скрипта Capture-Wim.ps1 по захвату wim-файла можно было продолжить работу в основной консоли PowerShell`а, был выбран окольный путь запуска скрипта через cmd
#         по окончании работы скрипт выключает компьютер
#     #>

#     # кодируем аргументы в base64-строку
#     $command = "$env:SystemDrive\Capture-Wim.ps1"
#     $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
#     $encodedCommand = [Convert]::ToBase64String($bytes)

#     # новый процесс
#     $proc = New-Object -TypeName System.Diagnostics.Process

#     # окольный путь запуска, через cmd, но так можно продолжить работу в основном окне PowerShell`а
#     $proc.StartInfo.FileName = "cmd.exe"
#     $proc.StartInfo.Arguments = "/c start powershell.exe -encodedCommand $encodedCommand"

#     $proc.StartInfo.UseShellExecute = $true  # использовать оболочку для запуска процесса
#     $proc.StartInfo.CreateNoWindow = $false  # запустить в новом окне

#     $proc.Start()  # запуск процесса
#     # $proc.WaitForExit()
# }



Set-Location -Path $env:SystemDrive\  # переход в корень диска

Get-PSDrive -PSProvider FileSystem | Select-Object Name, Root, Description, Free, Used | Format-Table -AutoSize  # информация о дисках

# Write-Host -ForegroundColor Magenta "      Ctrl + i to capture $inp to $out$wimFile"

# Write-Host -ForegroundColor Red     "Alt + Ctrl + i to capture $inp to $out$wimFile AND SHUTDOWN"

Start-Process -FilePath "$env:SystemRoot\System32\startnet.cmd"

Write-Host -ForegroundColor Magenta "      Ctrl + f to launch Far 3.0"

# Start-Process -FilePath "$env:SystemDrive\UltraVNC\winvnc.exe"
# Start-Process -FilePath 'wpeutil' -ArgumentList 'InitializeNetwork', '/NoWait'
# Start-Process -FilePath 'wpeutil' -ArgumentList 'DisableFirewall'



# запуск меню

Import-Module -Force Wenix
Use-Wenix
