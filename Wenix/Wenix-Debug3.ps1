# https://docs.microsoft.com/ru-ru/dotnet/api/system.io.file.openread?view=netframework-4.8
# https://docs.microsoft.com/ru-ru/dotnet/api/system.io.file.openwrite?view=netframework-4.8

$WatchDogTimer = [system.diagnostics.stopwatch]::startNew()

$file_read  = "C:\.it\PE\boot.wim"    # исходник
$file_write = "C:\.it\PE\boot.wim_1"  # новый файл

try
{
    $source = [System.IO.File]::OpenRead(  $file_read  )  # исходник
    
    $target = [System.IO.File]::OpenWrite( $file_write )  # новый файл
    
    
    [byte[]] $buf = New-Object byte[] 1023  # буфер чтения
    
    [uint32] $tail = $source.Length % $buf.Length  # остаток от деленеия ~ размер хвоста, который нужно будет дописать после цикла
    
    while ($source.Read($buf, 0, $buf.Length) -gt $tail) { $target.Write($buf, 0, $buf.Length) }
    
    if ($tail -gt 0) { $target.Write($buf[ 0..($tail - 1) ], 0, $tail) }  # запись хвостика
}

finally
{
    $source.Dispose()
    
    $target.Dispose()
}

Write-Host ("{0,5:N2} minutes" -f $WatchDogTimer.Elapsed.TotalMinutes)

$HashSum = Get-FileHash -Algorithm MD5 -Path $file_write

$HashSum.Hash + ' *' + $file_write.Split('\')[-1] | Out-File -Encoding ascii -FilePath ($file_write + ".md5")

Write-Host ("{0,5:N2} minutes" -f $WatchDogTimer.Elapsed.TotalMinutes)
