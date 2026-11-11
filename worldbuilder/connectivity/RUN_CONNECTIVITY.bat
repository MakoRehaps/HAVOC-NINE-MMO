@echo off
setlocal
if "%~2"=="" (echo Usage: RUN_CONNECTIVITY.bat "D:\HAVOC-NINE-MMO" "D:\HAVOC-NINE-MMO\H9XASH\ts\maps\h9_siege_meridian.bsp" & exit /b 2)
node "%~1\worldbuilder\connectivity\scan-bsp.mjs" --repo "%~1" --bsp "%~2" --out "%~1\worldbuilder\generated\connectivity"
exit /b %errorlevel%
