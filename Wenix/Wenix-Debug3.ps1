# https://docs.microsoft.com/ru-ru/dotnet/api/system.io.file.openread?view=netframework-4.8
# https://docs.microsoft.com/ru-ru/dotnet/api/system.io.file.openwrite?view=netframework-4.8

$WatchDogTimer = [system.diagnostics.stopwatch]::startNew()

$file_read  = "C:\.it\PE\boot.wim"
$file_write = "C:\.it\PE\boot.wim_1"

try
{
    $source = [System.IO.File]::OpenRead(  $file_read  )
    $target = [System.IO.File]::OpenWrite( $file_write )
    
    
    [byte[]] $buf = New-Object byte[] 1023  # 1024
    
    [uint32] $tail = $source.Length % $buf.Length
    
    while ($source.Read($buf, 0, $buf.Length) -gt $tail)
    {
        # $source.Length, $source.Position, [System.Text.Encoding]::Default.GetString($buf)
        $target.Write($buf, 0, $buf.Length)
    }
    
    if ($tail -gt 0) { $target.Write($buf[0..($tail - 1)], 0, $tail) }
}

finally
{
    $source.Dispose()
    $target.Dispose()
}

Write-Host ("{0,5:N2} minutes" -f $WatchDogTimer.Elapsed.TotalMinutes)
