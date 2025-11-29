@echo off
setlocal enabledelayedexpansion

set CONFIG_FILE=%~dp0config.ini

REM ========================================
REM Load Configuration
REM ========================================
if not exist "%CONFIG_FILE%" (
    echo ========================================
    echo Configuration file not found!
    echo ========================================
    echo.
    echo Please run setup.bat first to configure the backup system.
    echo.
    pause
    exit /b 1
)

echo Loading configuration from %CONFIG_FILE%...
for /f "usebackq tokens=1,2 delims==" %%a in ("%CONFIG_FILE%") do (
    if not "%%a"=="[Settings]" (
        set "%%a=%%b"
    )
)

REM Trim spaces from REMOTE_NAME
for /f "tokens=* delims= " %%a in ("%REMOTE_NAME%") do set "REMOTE_NAME=%%a"

REM ========================================
REM Handle rclone config password
REM ========================================
if not defined RCLONE_CONFIG_PASS (
    echo.
    echo ========================================
    echo Password Required
    echo ========================================
    echo.
    echo The rclone configuration is password-protected.
    echo.
    set /p RCLONE_CONFIG_PASS="Enter rclone config password: "
    echo.
)

REM ========================================
REM Timestamp Generation
REM ========================================
set TIMESTAMP=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%
set TIMESTAMP=%TIMESTAMP: =0%

echo ========================================
echo Google Shared Drive Backup to NAS
echo Start: %date% %time%
echo ========================================
echo Configuration:
echo - rclone: %RCLONE_PATH%
echo - NAS: %NAS_PATH%
echo - Remote: %REMOTE_NAME%
echo - Generations: %GENERATIONS%
echo - Target: %NAS_PATH%\gdrive\backup_%TIMESTAMP%
echo - Security: rclone config is encrypted
echo ========================================
echo.

REM ========================================
REM Pre-flight Checks
REM ========================================
echo [0/3] Pre-flight checks...

REM Check rclone exists
if not exist "%RCLONE_PATH%" (
    echo ERROR: rclone.exe not found at %RCLONE_PATH%
    echo Please run setup.bat to reconfigure.
    pause
    exit /b 1
)

REM Check NAS accessibility
if not exist "%NAS_PATH%\" (
    echo ERROR: NAS path not accessible: %NAS_PATH%
    echo Please check:
    echo - NAS is powered on
    echo - Network connection is active
    echo - Network credentials are configured
    pause
    exit /b 1
)

REM Create directories if not exist
if not exist "%NAS_PATH%\gdrive" mkdir "%NAS_PATH%\gdrive"
if not exist "%NAS_PATH%\gdrive\logs" mkdir "%NAS_PATH%\gdrive\logs"

echo Pre-flight checks passed.
echo.

REM ========================================
REM Backup: All Files (with Google Docs Export)
REM ========================================
echo [1/3] Backing up all files...
echo - Normal files: copied as-is
echo - Google Docs: exported as docx
echo - Google Sheets: exported as xlsx
echo - Google Slides: exported as pptx
echo.

"%RCLONE_PATH%" copy "%REMOTE_NAME%:" "%NAS_PATH%\gdrive\backup_%TIMESTAMP%" --drive-export-formats docx,xlsx,pptx --progress --transfers 4 --log-file "%NAS_PATH%\gdrive\logs\backup_%TIMESTAMP%.log" -v

if errorlevel 1 (
    echo.
    echo ERROR: Backup failed.
    echo Check log: %NAS_PATH%\gdrive\logs\backup_%TIMESTAMP%.log
    echo.
    echo Common causes:
    echo - Incorrect rclone config password
    echo - Network connection lost
    echo - Google Drive access token expired
    echo - NAS storage full
    echo.
    set BACKUP_FAILED=1
) else (
    echo Backup completed successfully.
)
echo.

REM ========================================
REM Verify Backup Created
REM ========================================
echo [2/3] Verifying backup...
if not exist "%NAS_PATH%\gdrive\backup_%TIMESTAMP%" (
    echo ERROR: Backup folder was not created.
    echo Skipping cleanup to preserve existing backups.
    echo.
    echo Please check:
    echo - Log file: %NAS_PATH%\gdrive\logs\backup_%TIMESTAMP%.log
    echo - NAS permissions
    echo - Available disk space
    pause
    exit /b 1
)
echo Backup folder verified.
echo.

REM ========================================
REM Cleanup: Delete Old Backups
REM ========================================
echo [3/3] Cleaning up old backups (keeping %GENERATIONS% generations)...

REM Count existing backups
set COUNT=0
for /f "delims=" %%i in ('dir /b /ad /o-n "%NAS_PATH%\gdrive\backup_*" 2^>nul') do (
    set /a COUNT+=1
)

if %COUNT% LEQ %GENERATIONS% (
    echo Currently %COUNT% generations exist. No cleanup needed.
    goto :summary
)

echo Found %COUNT% generations. Deleting old backups...

REM Delete old backups
set DELETED=0
set FAILED=0
for /f "skip=%GENERATIONS% delims=" %%i in ('dir /b /ad /o-n "%NAS_PATH%\gdrive\backup_*" 2^>nul') do (
    echo Deleting: %%i
    rd /s /q "%NAS_PATH%\gdrive\%%i"
    if errorlevel 1 (
        echo WARNING: Failed to delete %%i
        set /a FAILED+=1
    ) else (
        echo Successfully deleted: %%i
        set /a DELETED+=1
    )
)

echo Cleanup summary: %DELETED% deleted, %FAILED% failed
echo.

REM ========================================
REM Summary
REM ========================================
:summary
echo ========================================
echo Backup Summary
echo ========================================
echo Finish time: %date% %time%
echo Backup location: %NAS_PATH%\gdrive\backup_%TIMESTAMP%
echo Logs location: %NAS_PATH%\gdrive\logs\backup_%TIMESTAMP%.log

if defined BACKUP_FAILED (
    echo.
    echo ========================================
    echo WARNING: Backup operation failed
    echo ========================================
    echo.
    echo Please check the log file for details.
    echo.
    pause
    exit /b 1
) else (
    echo.
    echo ========================================
    echo All operations completed successfully
    echo ========================================
    echo.
)

pause
exit /b 0
