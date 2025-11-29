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
echo You need to enter the name of the Google Drive remote
echo that you configured with 'rclone config'.
echo.
echo To check your configured remotes:
echo 1. Open a new command prompt
echo 2. Run: rclone config
echo 3. Look for the remote name in the list
echo 4. Press 'q' to quit without making changes
echo 5. Return here and enter the remote name
echo.
set /p REMOTE_NAME="Enter remote name (e.g., shared_drive): "

if "%REMOTE_NAME%"=="" (
    echo ERROR: Remote name cannot be empty.
    echo.
    goto ask_remote
)

echo.
echo Remote name set to: %REMOTE_NAME%
echo.
echo NOTE: Remote connectivity will be tested when you run backup.bat
echo If the remote name is incorrect, backup.bat will show an error.
echo.

REM ========================================
REM Step 4: Generations
REM ========================================
:ask_generations
echo [4/4] Number of backup generations to keep
echo.
echo Recommendation: 30 (for ransomware protection)
echo Minimum: 7
echo.
set /p GENERATIONS="Enter number (default: 30): "

if "%GENERATIONS%"=="" set "GENERATIONS=30"

REM Validate number
echo %GENERATIONS%| findstr /r "^[1-9][0-9]*$" >nul
if errorlevel 1 (
    echo ERROR: Please enter a valid number.
    goto ask_generations
)

if %GENERATIONS% LSS 7 (
    echo WARNING: Less than 7 generations provides limited protection
    set /p CONTINUE="Continue with %GENERATIONS% generations? (Y/N): "
    if /i not "!CONTINUE!"=="Y" goto ask_generations
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
REM Step 5: Encrypt rclone config (MANDATORY)
REM ========================================
echo.
echo ========================================
echo [MANDATORY] Encrypting rclone configuration
echo ========================================
echo.
echo For security, you MUST set a password for rclone config.
echo This protects your Google Drive access token from theft.
echo.
echo CRITICAL SECURITY NOTICE:
echo - Without this, anyone with PC access can steal your data
echo - This is REQUIRED for all users
echo.
echo IMPORTANT: Remember this password!
echo If you forget it, you will need to reconfigure rclone.
echo.
echo Press any key to open rclone config...
pause >nul

echo.
echo Opening rclone config...
echo.
echo Please follow these steps:
echo ========================================
echo 1. Press 's' (Set configuration password)
echo 2. Enter a STRONG password (20+ characters recommended)
echo 3. Confirm the password
echo 4. Press 'q' to quit
echo ========================================
echo.
pause

"%RCLONE_PATH%" config

echo.
echo ========================================
echo Encryption Setup Complete
echo ========================================
echo.
echo Did you successfully complete the password setup?
echo.
echo If you pressed 's' and set a password, answer Y
echo If you skipped or encountered an error, answer N
echo.
:confirm_password
set /p PASSWORD_SET="Did you set a password? (Y/N): "

if /i "%PASSWORD_SET%"=="Y" goto password_confirmed
if /i "%PASSWORD_SET%"=="N" goto password_failed
echo Invalid input. Please enter Y or N.
goto confirm_password

:password_failed
echo.
echo ========================================
echo ERROR: Password setup incomplete
echo ========================================
echo.
echo rclone config password is MANDATORY for security.
echo.
echo Please run setup.bat again and complete the password setup:
echo 1. Press 's' when rclone config opens
echo 2. Enter a strong password
echo 3. Confirm the password
echo 4. Press 'q' to quit
echo.
pause
exit /b 1

:password_confirmed
echo.
echo Password setup confirmed!
echo.

REM ========================================
REM Password Handling Choice
REM ========================================
:ask_password_mode
echo ========================================
echo Password Storage Options
echo ========================================
echo.
echo How do you want to handle the rclone password?
echo.
echo Option 1: Save in config file
echo   - Pros: Fully automated, works with Task Scheduler
echo   - Cons: Password stored in PLAIN TEXT (less secure)
echo   - Best for: Dedicated backup PC in secure location
echo.
echo Option 2: Manual entry each time
echo   - Pros: Password never stored (more secure)
echo   - Cons: Cannot automate with Task Scheduler
echo   - Best for: Manual backups only
echo.
set /p PASSWORD_CHOICE="Enter choice (1 or 2): "

if "%PASSWORD_CHOICE%"=="1" goto save_password
if "%PASSWORD_CHOICE%"=="2" goto no_password
echo Invalid choice. Please enter 1 or 2.
goto ask_password_mode

:save_password
echo.
echo ========================================
echo WARNING: Security Trade-off
echo ========================================
echo.
echo Saving password in config.ini means:
echo - Anyone who accesses this PC can read the password
echo - The password will be visible in plain text
echo - Automated backups will work without user interaction
echo.
set /p FINAL_CONFIRM="Are you sure? (Y/N): "
if /i not "%FINAL_CONFIRM%"=="Y" goto ask_password_mode

echo.
set /p RCLONE_PASSWORD="Enter rclone config password: "

REM Save configuration with password
set CONFIG_FILE=%~dp0config.ini
(
echo [Settings]
echo RCLONE_PATH=%RCLONE_PATH%
echo NAS_PATH=%NAS_PATH%
echo REMOTE_NAME=%REMOTE_NAME%
echo GENERATIONS=%GENERATIONS%
echo RCLONE_CONFIG_PASS=!RCLONE_PASSWORD!
)>"%CONFIG_FILE%"

echo.
echo Configuration saved with password.
echo Backups will run automatically.
set AUTO_MODE=YES
goto security_summary

:no_password
REM Save configuration without password
set CONFIG_FILE=%~dp0config.ini
(
echo [Settings]
echo RCLONE_PATH=%RCLONE_PATH%
echo NAS_PATH=%NAS_PATH%
echo REMOTE_NAME=%REMOTE_NAME%
echo GENERATIONS=%GENERATIONS%
)>"%CONFIG_FILE%"

echo.
echo Configuration saved without password.
echo You will need to enter password manually when running backup.
set AUTO_MODE=NO
goto security_summary

REM ========================================
REM Security Summary
REM ========================================
:security_summary
echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo Configuration saved to: %CONFIG_FILE%
echo.
echo ========================================
echo Security Status Summary
echo ========================================
echo.
echo [1] rclone config: ENCRYPTED (password-protected)
echo [2] Backup location: %NAS_PATH%
echo [3] Automation: 

if "%AUTO_MODE%"=="YES" (
    echo     ENABLED - Password stored in config.ini
) else (
    echo     DISABLED - Manual password entry required
)

echo.
echo ========================================
echo CRITICAL: Secure Your NAS
echo ========================================
echo.
echo Your backups are stored on NAS. Please ensure:
echo.
echo 1. Enable NAS encryption
echo    - Consult your NAS manufacturer's documentation
echo    - Encrypt the volume/share where backups are stored
echo.
echo 2. Use strong NAS password
echo    - 20+ characters recommended
echo    - Enable 2-factor authentication if available
echo.
echo 3. Restrict NAS access
echo    - Limit access to backup PC's IP address only
echo    - Disable unnecessary services (FTP, etc.)
echo    - Keep firmware updated
echo.
echo 4. Physical security
echo    - Keep NAS in locked location
echo    - Consider off-site backup for critical data
echo.
echo 5. Backup PC security
echo    - Use strong Windows password (20+ characters)
echo    - Enable Windows Hello if available
echo    - Keep PC in physically secure location
echo.

echo ========================================
echo Next Steps
echo ========================================
echo 1. ENABLE NAS ENCRYPTION (critical)
echo 2. Run backup.bat to test the backup
echo 3. Verify backup files are created on NAS

if "%AUTO_MODE%"=="YES" (
    echo 4. Schedule backup.bat in Task Scheduler
    echo    - Recommended: Weekly on Sunday at 2 AM
) else (
    echo 4. Run backup.bat manually when needed
    echo    - Task Scheduler will NOT work (requires password)
)

echo.
echo ========================================
echo IMPORTANT: Test Remote Connection
echo ========================================
echo.
echo Before running backup.bat, verify your remote is working:
echo.
echo 1. Open a command prompt
echo 2. Run: rclone lsd %REMOTE_NAME%:
echo 3. Enter your rclone config password when prompted
echo 4. You should see a list of folders
echo.
echo If you get an error, the remote name is incorrect.
echo Run setup.bat again with the correct remote name.
echo.
pause