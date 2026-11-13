@echo off
setlocal
cd /d "%~dp0"
py -3 -m pip install --upgrade aiohttp pyinstaller || exit /b 1
py -3 -m PyInstaller --noconfirm --clean --onefile --windowed --name Cloudyman --add-data "client.html;." --add-data "server.py;." --hidden-import aiohttp --hidden-import server launcher.py || exit /b 1
echo Compiled GUI: dist\Cloudyman.exe
pause
