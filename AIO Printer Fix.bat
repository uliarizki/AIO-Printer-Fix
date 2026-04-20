@echo off
title Alat Perbaikan Printer Terintegrasi

:: ===================================================
:: 1. Pengecekan Hak Akses Administrator Global
:: ===================================================
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ===================================================
    echo [AKSES DITOLAK] Skrip ini membutuhkan elevasi privilese.
    echo Mayoritas modifikasi registry dan layanan sistem (spooler)
    echo tidak akan berfungsi tanpa hak akses tingkat akar.
    echo.
    echo Tindakan: Buka Command Prompt sebagai Administrator
    echo sebelum menjalankan perintah curl.
    echo ===================================================
    pause
    exit
)

:: ===================================================
:: 2. Inisialisasi Direktori Backup Lokal (Persisten)
:: ===================================================
set "BACKUP_DIR=C:\PrinterFix_Backup"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

:MENU
cls
echo ===================================================
echo       SISTEM PERBAIKAN PRINTER TERINTEGRASI (AIO)
echo       Lokasi Backup: %BACKUP_DIR%
echo ===================================================
echo 1. Sinkronisasi Jaringan ^& Kredensial SMB
echo 2. Restart Layanan Print Spooler
echo 6. Nonaktifkan Windows Update (Permanen)
echo 7. [PULIHKAN] Rollback Konfigurasi (Restore Backup)
echo 0. Keluar
echo ===================================================
set /p pilihan=Masukkan angka pilihan Anda (0-7): 

if "%pilihan%"=="1" goto MODUL_SMB
if "%pilihan%"=="2" goto MODUL_SPOOLER
if "%pilihan%"=="6" goto MODUL_DISABLE_WU
if "%pilihan%"=="7" goto MODUL_ROLLBACK
if "%pilihan%"=="0" exit

:: Penanganan input tidak valid
echo [ERROR] Input tidak dikenali.
timeout /t 2 >nul
goto MENU

:: ===================================================
:: BLOK EKSEKUSI MODUL
:: ===================================================

:MODUL_SMB
cls
echo [*] Menyimpan backup registry SMB ke %BACKUP_DIR%...
reg export "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "%BACKUP_DIR%\SMB_Params.reg" /y >nul 2>&1
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation" "%BACKUP_DIR%\SMB_Policy.reg" /y >nul 2>&1

echo [*] Mengeksekusi Modul Sinkronisasi Jaringan ^& SMB...
powershell "Set-SmbClientConfiguration -RequireSecuritySignature $false -EnableSecuritySignature $true -EnableInsecureGuestLogons $true -Confirm:$false"
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v "RequireSecuritySignature" /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v "EnableSecuritySignature" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation" /v "AllowInsecureGuestAuth" /t REG_DWORD /d 1 /f
powershell "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private"
cmdkey /delete:192.168.58.88 2>nul
echo.
echo === INSTRUKSI KREDENSIAL ===
echo Masukkan user dan password printer saat prompt otentikasi muncul.
echo Jika ditanya user, ketik: 192.168.58.88\printer
echo.
net use \\192.168.58.88 /user:192.168.58.88\printer *
echo.
echo [OK] Proses selesai.
pause
goto MENU

:MODUL_SPOOLER
cls
echo [*] Mengeksekusi Restart Layanan Print Spooler...
net stop "Print Spooler"
net start "Print Spooler"
echo.
echo [OK] Proses selesai.
pause
goto MENU

:MODUL_RPC
cls
echo [*] Menyimpan backup registry RPC ^& Print ke %BACKUP_DIR%...
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" "%BACKUP_DIR%\RPC_Policy.reg" /y >nul 2>&1
reg export "HKLM\System\CurrentControlSet\Control\Print" "%BACKUP_DIR%\Print_Control.reg" /y >nul 2>&1

echo [*] Mengeksekusi Perbaikan RPC (Error 709 / 11b)...
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" /v RpcUseNamedPipeProtocol /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" /v RpcProtocols /t REG_DWORD /d 7 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" /v ForceKerberosForRpc /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Print" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f
echo Merestart Print Spooler...
net stop spooler
net start spooler
echo.
echo [OK] Proses selesai. Diperlukan restart sistem agar registri diterapkan penuh.
pause
goto MENU

:MODUL_KB
cls
echo [*] Menyimpan backup registry FeatureManagement ke %BACKUP_DIR%...
reg export "HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides" "%BACKUP_DIR%\KB_Override.reg" /y >nul 2>&1

echo [*] Mengeksekusi Perbaikan Pembaruan KB5006670...
reg add HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 713073804 /t REG_DWORD /d 0 /f
echo.
echo [OK] Proses selesai.
pause
goto MENU

:MODUL_0x000003eb
cls
echo [*] Menyimpan backup registry Driver Version-3 ke %BACKUP_DIR%...
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows x64\Drivers\Version-3" "%BACKUP_DIR%\Drivers_x64.reg" /y >nul 2>&1
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows NT x86\Drivers\Version-3" "%BACKUP_DIR%\Drivers_x86.reg" /y >nul 2>&1

echo [*] Mengeksekusi Pembersihan Driver (Error 0x000003eb)...
net stop spooler /y
echo Menghapus temporary spool files...
del /Q /F /S "%systemroot%\System32\Spool\Printers\*.*"
del /Q /F /S "%systemroot%\System32\Spool\Drivers\w32x86\3\*.*"
del /Q /F /S "%systemroot%\System32\Spool\Drivers\x64\3\*.*"
echo Membersihkan registry driver yang korup...
reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows x64\Drivers\Version-3" /f
reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows NT x86\Drivers\Version-3" /f
net start spooler
echo.
echo [OK] Proses selesai. Silakan coba tambahkan printer kembali.
pause
goto MENU

:MODUL_DISABLE_WU
cls
echo [*] Menyimpan backup registry Windows Update ke %BACKUP_DIR%...
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "%BACKUP_DIR%\WU_Policy.reg" /y >nul 2>&1

echo [*] Mengeksekusi Penonaktifan Windows Update...
echo 1. Menghentikan layanan Windows Update yang berjalan...
net stop wuauserv /y
echo 2. Menonaktifkan layanan dari startup sistem...
sc config wuauserv start= disabled
echo 3. Mengunci pembaruan otomatis via Registry...
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f
echo.
echo [PERINGATAN] Windows Update telah dinonaktifkan sepenuhnya.
echo [OK] Proses selesai.
pause
goto MENU

:MODUL_ROLLBACK
cls
echo [*] Memulai proses Rollback (Pemulihan Konfigurasi)...
if not exist "%BACKUP_DIR%" (
    echo [ERROR] Direktori backup %BACKUP_DIR% tidak ditemukan. 
    echo Tidak ada data yang bisa dipulihkan.
    pause
    goto MENU
)

echo 1. Mengimpor ulang file Registry dari backup...
for %%f in ("%BACKUP_DIR%\*.reg") do (
    echo    - Mengimpor: %%~nxf
    reg import "%%f" >nul 2>&1
)

echo 2. Memulihkan status layanan Windows Update ke Default (Manual/Demand)...
sc config wuauserv start= demand >nul 2>&1

echo 3. Merestart layanan terkait...
net stop spooler /y >nul 2>&1
net start spooler >nul 2>&1

echo.
echo [OK] Proses Rollback selesai. Konfigurasi awal telah dipulihkan.
pause
goto MENU
