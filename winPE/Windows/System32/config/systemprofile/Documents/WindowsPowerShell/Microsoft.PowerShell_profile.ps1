# https://docs.microsoft.com/ru-ru/powershell/scripting/core-powershell/ise/how-to-use-profiles-in-windows-powershell-ise?view=powershell-6


function Update-Wenix  # поиск и импорт более свежей версии модуля
{
    param ([switch] $reload = $false)
    
    
    Import-Module -Force Wenix -Variable 'ModulePath'
    
    $FindedModules = @()
    
    foreach ($v in (Get-Volume | Where-Object {$null -ne $_.DriveLetter} | Sort-Object -Property DriveLetter) )  # поиск в алфавитном порядке C: D: etc
    {
        $w = $v.DriveLetter + ':\' + $ModulePath
        
        if (Test-Path -Path $w) { $FindedModules += Get-Module -ListAvailable "$w" }
    }
    
    if ( ($FindedModules | Sort-Object -Property 'Version' | Select-Object -Last 1).Version -gt (Get-Module -Name 'Wenix').Version )
    {
        Copy-Item -Recurse -Force -Path ($FindedModules.Path | Split-Path -Parent) -Destination "$env:SystemDrive\Windows\system32\config\systemprofile\Documents\WindowsPowerShell\Modules"
    }
    
    if ($reload) { Import-Module Wenix -Force }
}


#region Hot Key Definition
    
    # выход по сочетанию Ctrl + D
    Set-PSReadlineKeyHandler -Chord Ctrl+d -Function DeleteCharOrExit
    
    
    # запуск Far
    Set-PSReadlineKeyHandler -Chord Ctrl+f -ScriptBlock { Start-Process -FilePath "$env:SystemDrive\Far\Far.exe" -ArgumentList "$env:SystemDrive $env:WinDir\System32\config\systemprofile\Documents\WindowsPowerShell\Modules\" }
    
    
    # поиск / импорт свежей версии Wenix`а
    Set-PSReadlineKeyHandler -Chord Ctrl+u -ScriptBlock { Update-Wenix -reload }
    
#endregion


#region Hot Key Info
    
    Set-Location -Path $env:SystemDrive\  # переход в корень диска
    
    Get-PSDrive -PSProvider FileSystem | Select-Object Name, Root, Description, Free, Used | Format-Table -AutoSize  # информация о дисках
    
    Start-Process -FilePath "$env:SystemRoot\System32\startnet.cmd"
    
    Write-Host -ForegroundColor Magenta "      Ctrl + f to launch Far 3.0"
    
    Write-Host -ForegroundColor Magenta "      Ctrl + u to Update-Wenix"
    
#endregion


#region запуск меню
    
    $Global:WenixBootWimVerTempFile = New-TemporaryFile
    
    $Global:WenixbootWimVer = (Get-Module -list -Name Wenix | Get-Content -Encoding UTF8 | Where-Object {$_ -match 'ModuleVersion'}).Split(' = ')[-1].Replace("'", '')
    
    $Global:WenixbootWimVer | Out-File -Encoding unicode -FilePath $Global:WenixBootWimVerTempFile
    
    # Get-Content $Global:WenixBootWimVerTempFile
    
    Update-Wenix
    
    Import-Module -Force Wenix
    
    Use-Wenix
    
#endregion
