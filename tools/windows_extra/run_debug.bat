@echo off
cd /d "%~dp0"
echo Running Crusader in debug mode... (log: crusader_log.txt)
Crusader.console.exe > crusader_log.txt 2>&1
echo.
echo Game closed. Please send crusader_log.txt if the game did not start.
pause
