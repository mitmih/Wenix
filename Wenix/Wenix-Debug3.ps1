# https://docs.microsoft.com/ru-ru/dotnet/api/system.io.file.openread?view=netframework-4.8
# https://docs.microsoft.com/ru-ru/dotnet/api/system.io.file.openwrite?view=netframework-4.8

$file_read  = "C:\.it\PE\boot.wim.md5"
$file_write = "C:\.it\PE\boot.wim.md5.NEW"

try
{
    $source = [System.IO.File]::OpenRead(  $file_read  )
    $target = [System.IO.File]::OpenWrite( $file_write )
    
    [byte[]] $buf = New-Object byte[] 16  # 1024
    
    while ($source.read($buf, 0, $buf.Length) -gt 0)
    {
        [System.Text.Encoding]::Default.GetString($buf)
        $target.write($buf, 0, $buf.Length)
    }
}

finally
{
    $source.Dispose()
    $target.Dispose()
}
