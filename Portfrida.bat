@echo off
setlocal enabledelayedexpansion

echo [*] Connecting to Android device...
adb connect 127.0.0.1:62025 >nul

:: --- Kill frida-server processes ---
echo [*] Killing any running frida-server processes...
for /f "tokens=2" %%p in ('adb shell "ps -A | grep frida-server" 2^>nul') do (
    adb shell "su -c kill -9 %%p" >nul 2>&1
)

:: --- Free up port 27042 manually ---
echo [*] Checking for any process using port 27042...
for /f "tokens=2" %%p in ('adb shell "netstat -anp 2>/dev/null | grep 27042"') do (
    echo [*] Killing PID %%p holding port 27042...
    adb shell "su -c kill -9 %%p" >nul 2>&1
)

:: --- Pause briefly ---
timeout /t 2 >nul

:: --- Locate frida-server binary ---
echo [*] Looking for frida-server in /data/local/tmp...
set "frida_path="
for /f %%f in ('adb shell "ls /data/local/tmp/frida-server*" 2^>nul') do (
    set frida_path=%%f
    goto :found
)

:found
if defined frida_path (
    echo [*] Restarting frida-server: !frida_path!
    adb shell "su -c 'chmod +x !frida_path! && nohup !frida_path! >/dev/null 2>&1 &'"
    echo [✓] Frida server restarted.
) else (
    echo [!] Frida server not found in /data/local/tmp
)

pause
