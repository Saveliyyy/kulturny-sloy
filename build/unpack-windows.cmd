@echo off
setlocal
pushd "%~dp0" || exit /b 1
if exist KulturnySloy.exe (
    echo KulturnySloy.exe is already here.
    popd
    exit /b 0
)
powershell -NoProfile -Command "$ErrorActionPreference = 'Stop'; $pack = [IO.Path]::GetTempFileName(); try { $out = [IO.File]::OpenWrite($pack); try { foreach ($number in 1..7) { $part = 'KulturnySloy-win-x64.7z.{0:D3}' -f $number; $source = [IO.File]::OpenRead((Join-Path $PWD $part)); try { $source.CopyTo($out) } finally { $source.Dispose() } } } finally { $out.Dispose() }; if ((Get-FileHash -LiteralPath $pack -Algorithm SHA256).Hash -ne '78CA572F10F7987555FB81778F870778E60AC8A18754EBB167D88514B46372C6') { throw 'Archive checksum does not match.' }; & tar.exe -xkf $pack; if ($LASTEXITCODE -ne 0) { throw 'Could not extract KulturnySloy.exe.' } } finally { Remove-Item -LiteralPath $pack }"
set "result=%errorlevel%"
popd
if not "%result%"=="0" pause
exit /b %result%
