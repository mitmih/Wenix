#     кодируем аргументы в base64-строку
#     $command = "$env:SystemDrive\Capture-Wim.ps1"
#     $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
#     $encodedCommand = [Convert]::ToBase64String($bytes)

$txt_open = "администратор и его пароль"
$txt_bytesEnc = [System.Text.Encoding]::Unicode.GetBytes($txt_open)
$txt_encoded = [System.Convert]::ToBase64String($txt_bytesEnc)

$txt_bytesDec = [System.Convert]::FromBase64String($txt_encoded)
$txt_open_decoded = [System.Text.Encoding]::Unicode.GetString($txt_bytesDec)

$txt_open
$txt_open_decoded
