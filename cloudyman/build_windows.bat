@echo off
setlocal
cd /d "%~dp0"
py -3 -m pip install --upgrade pyinstaller || exit /b 1
py -3 -m PyInstaller --noconfirm --clean --onefile --windowed --name Cloudyman launcher.py || exit /b 1
echo.
echo Build completed: dist\Cloudyman.exe
echo COPY dist\Cloudyman.exe TO HAVOC-NINE-MMO\cloudyman\Cloudyman.exe
echo Run from there, with H9XASH and h9web as sibling directories.
pause
