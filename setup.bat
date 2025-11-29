@echo off
setlocal enabledelayedexpansion

echo ========================================
echo Google Shared Drive Backup - Initial Setup
echo ========================================
echo.
echo This wizard will help you configure the backup system.
echo.

REM ========================================
REM Step 1: rclone Path
REM ========================================
:ask_rclone
echo [1/4] rclone.exe location
echo.
set "DEFAULT_RCLONE=C:\Users\%USERNAME%\AppData\Local\Programs\rclone\rclone.exe"
echo Default: %DEFAULT_RCLONE%
set /p RCLONE_PATH="Press Enter for default, or enter custom path: "

if "%RCLONE_PATH%"=="" set "RCLONE_PATH=%DEFAULT_RCLONE%"

if not exist "%RCLONE_PATH%" (
    echo.
    echo ERROR: File not found: %RCLONE_PATH%
    echo.
    goto ask_rclone
)
echo OK: %RCLONE_PATH%
echo.

REM ========================================
REM Step 2: NAS Path
REM ========================================
:ask_nas
echo [2/4] NAS backup location
echo.
echo Examples:
echo   - \\192.168.1.100\backup
echo   - \\NAS-SERVER\backup
echo   - Z:\backup (if mapped drive)
echo.
set /p NAS_PATH="Enter NAS path: "

if "%NAS_PATH%"=="" (
    echo ERROR: NAS path cannot be empty.
    echo.
    goto ask_nas
)

REM Test NAS accessibility
if not exist "%NAS_PATH%\" (
    echo.
    echo WARNING: Cannot access %NAS_PATH%
    echo Please make sure:
    echo   1. NAS is powered on and connected
    echo   2. Network credentials are configured
    echo   3. Path is correct
    echo.
    set /p CONTINUE="Continue anyway? (Y/N): "
    if /i not "!CONTINUE!"=="Y" goto ask_nas
)
echo OK: %NAS_PATH%
echo.

REM ========================================
REM Step 3: rclone Remote Name
REM ========================================
:ask_remote
echo [3/4] rclone remote name
echo.
echo Listing configured remotes:
"%RCLONE_PATH%" config show
echo.
set /p REMOTE_NAME="Enter remote name (e.g., shared_drive): "

if "%REMOTE_NAME%"=="" (
    echo ERROR: Remote name cannot be empty.
    echo.
    goto ask_remote
)

REM Test remote
"%RCLONE_PATH%" lsd %REMOTE_NAME%: >nul 2>&1
if errorlevel 1 (
    echo.
    echo WARNING: Cannot connect to remote "%REMOTE_NAME%"
    echo Please check the remote name is correct.
    echo.
    set /p CONTINUE="Continue anyway? (Y/N): "
    if /i not "!CONTINUE!"=="Y" goto ask_remote
)
echo OK: %REMOTE_NAME%
echo.

REM ========================================
REM Step 4: Generations
REM ========================================
:ask_generations
echo [4/4] Number of backup generations to keep
echo.
set /p GENERATIONS="Enter number (default: 7): "

if "%GENERATIONS%"=="" set "GENERATIONS=7"

REM Validate number
echo %GENERATIONS%| findstr /r "^[1-9][0-9]*$" >nul
if errorlevel 1 (
    echo ERROR: Please enter a valid number.
    goto ask_generations
)
echo OK: %GENERATIONS% generations
echo.

REM ========================================
REM Confirmation
REM ========================================
echo ========================================
echo Configuration Summary
echo ========================================
echo rclone path: %RCLONE_PATH%
echo NAS path: %NAS_PATH%
echo Remote name: %REMOTE_NAME%
echo Generations: %GENERATIONS%
echo ========================================
echo.
set /p CONFIRM="Save this configuration? (Y/N): "

if /i not "%CONFIRM%"=="Y" (
    echo Configuration cancelled.
    pause
    exit /b 1
)

REM ========================================
REM Save Configuration (NO TRAILING SPACES)
REM ========================================
set CONFIG_FILE=%~dp0config.ini

(
echo [Settings]
echo RCLONE_PATH=%RCLONE_PATH%
echo NAS_PATH=%NAS_PATH%
echo REMOTE_NAME=%REMOTE_NAME%
echo GENERATIONS=%GENERATIONS%
)>"%CONFIG_FILE%"

echo.
echo Configuration saved to: %CONFIG_FILE%
echo.
echo ========================================
echo Setup complete!
echo ========================================
echo.
echo Next steps:
echo 1. Run backup.bat to perform a test backup
echo 2. If successful, schedule backup.bat in Task Scheduler
echo.
pause