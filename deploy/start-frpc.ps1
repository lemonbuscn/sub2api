$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir
Write-Host "Starting frpc ..." -ForegroundColor Cyan
& .\frpc.exe -c frpc.toml
