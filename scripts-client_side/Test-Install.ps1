<#

# когда wim файл выбран, можно приступить к работе с ЖД
# нужно узнать что это за диск (может быть подключено несколько, в разном порядке)
# узнать номер раздела с wim-файлами
# удалить все разделы, кроме него
# сделать 1й раздел 1_BOOT на 2048  МБ
# сделать 2й раздел 2_OS   на 81920 МБ
# сделать 3й раздел 3_PE   на оставшееся место

# применить на 3й раздел boot.wim из winPE
# прописать загрузку PE с ЖД
# скопировать туда же файлы для загрузки ram-диска
# прописать загрузку ram-диска
# удалить загрузку PE с ЖД

# применить на 2й раздел выбранный install.wim
# если применилось без ошибок - прописать ОС в загрузчик 
#>


# Path                 :       \\?\Volume{755ed038-850c-42bb-96f9-3d2695ba99e8}\
# AccessPaths          : {D:\, \\?\Volume{755ed038-850c-42bb-96f9-3d2695ba99e8}\}

$wim_vol = Get-Volume | Where-Object {$_.FileSystemLabel -match 'wim'} ######

if ($null -eq $wim_vol) { break }  # отсутствует том с wim-файлами


$ITfolder = $wim_vol.DriveLetter + ':\.IT'
if (Test-Path $ITfolder)
# проверить существует ли на этом томе папка $wim_vol.DriveLetter\.IT
# если папка есть, проверить, есть ли PE-шный boot.wim, если его нет - смысла что-то делать тоже нет
# если да, то проверить существование install.wim`ов и вывести доступные для переустановки
{
    $wimsOS = Get-ChildItem -Recurse -Filter 'install.wim' -Path "$ITfolder\10"
    $wimsPE = Get-ChildItem -Recurse -Filter 'boot.wim' -Path "$ITfolder\PE"
    
    $OSFile = $wimsOS.FullName # | Out-GridView -Title 'Please Select OS' -OutputMode Single
    $PEfile = $wimsPE.FullName
    
    $OSFile
    $PEfile
}
else { break }


$wim_part = Get-Partition | Where-Object {$_.AccessPaths -contains $wim_vol.Path}
# $wim_disk = Get-Disk | Where-Object {$_.Path -eq $wim_part.DiskPath}

Remove-Partition -DiskNumber $wim_part.DiskNumber -PartitionNumber (1..($wim_part.PartitionNumber - 1))

New-Partition -DiskNumber $wim_part.DiskNumber -DriveLetter ([Char]'B') -Size  2GB -IsActive | Format-Volume -FileSystem 'NTFS' -NewFileSystemLabel "1_BOOT"
New-Partition -DiskNumber $wim_part.DiskNumber -DriveLetter ([Char]'O') -Size 78GB           | Format-Volume -FileSystem 'NTFS' -NewFileSystemLabel "2_OS"
New-Partition -DiskNumber $wim_part.DiskNumber -DriveLetter ([Char]'P') -Size 13GB           | Format-Volume -FileSystem 'NTFS' -NewFileSystemLabel "3_PE"


Start-Process -Wait -FilePath "$env:windir\System32\dism.exe" -ArgumentList "/Apply-Image", "/ImageFile:$PEfile", "/Index:1", "/ApplyDir:P:\"
Start-Process -Wait -FilePath "$env:windir\System32\BCDboot.exe" -ArgumentList "P:\Windows", "/s B:", "/f ALL"

Start-Process -Wait -FilePath "$env:windir\System32\dism.exe" -ArgumentList "/Apply-Image", "/ImageFile:$OSFile", "/Index:1", "/ApplyDir:O:\"
Start-Process -Wait -FilePath "$env:windir\System32\BCDboot.exe" -ArgumentList "O:\Windows"
