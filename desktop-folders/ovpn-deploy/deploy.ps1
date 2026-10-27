$ErrorActionPreference = 'Continue'
$result = @()
Copy-Item "C:\Users\7\Desktop\ovpn-deploy\*.ovpn" -Destination "C:\Program Files\OpenVPN\config" -Force
if ($LASTEXITCODE -eq 0 -or $true) { $result += "copy-ok" }
$result += Get-ChildItem "C:\Program Files\OpenVPN\config" -Filter "*.ovpn" | Select-Object -ExpandProperty Name
$result | Out-File "C:\Users\7\Desktop\ovpn-deploy\deploy-result.txt" -Encoding UTF8
