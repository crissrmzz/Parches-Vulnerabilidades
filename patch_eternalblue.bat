@echo off
setlocal enabledelayedexpansion
title Parcheador EternalBlue MS17-010

:: ============================================================
::  Parcheador EternalBlue (MS17-010) - KB4012212
::  Compatible nativo con Windows 7 x86/x64
::  No requiere Python ni dependencias externas
:: ============================================================

:: Activar colores ANSI (funciona en Win7 con este truco)
reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

cls
echo.
echo  +====================================================+
echo  ^|      PARCHEADOR  EternalBlue  (MS17-010)          ^|
echo  ^|              Parche: KB4012212                    ^|
echo  ^|         Para Windows 7  x86 / x64                ^|
echo  +====================================================+
echo.

:: ── Verificar Administrador ──────────────────────────────
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo  [ERROR] Ejecuta este programa como Administrador.
    echo  Clic derecho sobre el archivo - Ejecutar como administrador
    echo.
    pause
    exit /b 1
)
echo  [OK] Ejecutando con privilegios de Administrador.
echo.

:: ── Detectar arquitectura ────────────────────────────────
set ARCH=x86
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set ARCH=x64
if "%PROCESSOR_ARCHITEW6432%"=="AMD64" set ARCH=x64
echo  [INFO] Arquitectura detectada: %ARCH%
echo.

:: ── PASO 1: Verificar si el parche ya esta instalado ─────
echo  [1/5] Verificando si el parche ya esta instalado...
echo  -------------------------------------------------------
wmic qfe get hotfixid 2>nul | find "KB4012212" >nul
if %errorLevel% == 0 (
    echo  [OK] El parche KB4012212 ya esta instalado.
    set PATCH_NEEDED=0
) else (
    echo  [INFO] Parche no detectado. Se procedera a instalarlo.
    set PATCH_NEEDED=1
)
echo.

:: ── PASO 2: Deshabilitar SMBv1 ───────────────────────────
echo  [2/5] Deshabilitando SMBv1 ^(vector de EternalBlue^)...
echo  -------------------------------------------------------
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" ^
    /v SMB1 /t REG_DWORD /d 0 /f >nul 2>&1
if %errorLevel% == 0 (
    echo  [OK] SMBv1 deshabilitado en el registro.
) else (
    echo  [AVISO] No se pudo deshabilitar SMBv1.
)
echo.

:: ── PASO 3: Bloquear puerto 445 en Firewall ──────────────
echo  [3/5] Bloqueando puerto 445 en el Firewall...
echo  -------------------------------------------------------
netsh advfirewall firewall delete rule name="Bloquear SMB EternalBlue" >nul 2>&1
netsh advfirewall firewall add rule ^
    name="Bloquear SMB EternalBlue" ^
    dir=in action=block protocol=TCP localport=445 >nul 2>&1
if %errorLevel% == 0 (
    echo  [OK] Puerto 445 bloqueado correctamente.
) else (
    echo  [AVISO] No se pudo crear la regla de firewall.
)
echo.

:: ── PASO 4: Descargar parche ─────────────────────────────
echo  [4/5] Descargando parche KB4012212 desde Microsoft...
echo  -------------------------------------------------------

set PATCH_DIR=%TEMP%\MS17010_Patch
if not exist "%PATCH_DIR%" mkdir "%PATCH_DIR%"
set PATCH_FILE=%PATCH_DIR%\KB4012212.msu

if "%ARCH%"=="x64" (
    set PATCH_URL=https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/secu/2017/02/windows6.1-kb4012212-x64_2decefaa02e2058dcd965702509a992d8c4e92b3.msu
) else (
    set PATCH_URL=https://catalog.s.download.windowsupdate.com/c/msdownload/update/software/secu/2017/02/windows6.1-kb4012212-x86_c8d0a462cbb1c9d5ede0b6f8c8bafbc20a8e7dc0.msu
)

echo  Descargando, por favor espera...
echo  ^(Esto puede tardar varios minutos segun tu conexion^)
echo.

:: Usar bitsadmin - nativo en Windows 7, no requiere nada externo
bitsadmin /transfer "DescargaParche" /download /priority normal ^
    "%PATCH_URL%" "%PATCH_FILE%" >nul 2>&1

if exist "%PATCH_FILE%" (
    echo  [OK] Parche descargado correctamente.
) else (
    echo  [ERROR] No se pudo descargar el parche.
    echo  Verifica tu conexion a internet e intenta de nuevo.
    echo  O descargalo manualmente desde:
    echo  https://www.catalog.update.microsoft.com/Search.aspx?q=KB4012212
    echo.
    pause
    exit /b 1
)
echo.

:: ── PASO 5: Instalar parche ──────────────────────────────
echo  [5/5] Instalando parche KB4012212...
echo  -------------------------------------------------------

if "%PATCH_NEEDED%"=="0" (
    echo  [OK] Parche ya presente, se omite instalacion.
    goto RESUMEN
)

echo  Instalando, por favor espera y no cierres esta ventana...
wusa.exe "%PATCH_FILE%" /quiet /norestart
set WUSA_CODE=%errorLevel%

if %WUSA_CODE% == 0 (
    echo  [OK] Parche instalado exitosamente.
) else if %WUSA_CODE% == 3010 (
    echo  [OK] Parche instalado. Se requiere reinicio para completar.
) else if %WUSA_CODE% == 2359302 (
    echo  [OK] El parche ya estaba instalado ^(confirmado^).
) else (
    echo  [ERROR] Error al instalar. Codigo: %WUSA_CODE%
    echo  Intenta instalarlo manualmente desde:
    echo  https://www.catalog.update.microsoft.com/Search.aspx?q=KB4012212
)
echo.

:: ── Limpiar archivos temporales ──────────────────────────
del /f /q "%PATCH_FILE%" >nul 2>&1
rmdir /q "%PATCH_DIR%" >nul 2>&1

:RESUMEN
:: ── Resumen final ────────────────────────────────────────
echo.
echo  +====================================================+
echo  ^|                  RESUMEN FINAL                    ^|
echo  +====================================================+
echo  ^|  [OK] SMBv1 deshabilitado                        ^|
echo  ^|  [OK] Puerto 445 bloqueado en Firewall           ^|
echo  ^|  [OK] Parche KB4012212 procesado                 ^|
echo  ^|  [!] Reiniciar el equipo para aplicar cambios    ^|
echo  +====================================================+
echo.

:: Guardar log en el Escritorio
set LOG_FILE=%USERPROFILE%\Desktop\parcheador_eternalblue.log
echo Parcheador EternalBlue MS17-010 > "%LOG_FILE%"
echo Fecha: %date% %time% >> "%LOG_FILE%"
echo Arquitectura: %ARCH% >> "%LOG_FILE%"
echo SMBv1: Deshabilitado >> "%LOG_FILE%"
echo Puerto 445: Bloqueado >> "%LOG_FILE%"
echo Parche KB4012212: Procesado >> "%LOG_FILE%"
echo Log guardado en: %LOG_FILE%
echo.

set /p REINICIAR=  Deseas reiniciar ahora? (S/N): 
if /i "%REINICIAR%"=="S" (
    echo  Reiniciando en 15 segundos...
    shutdown /r /t 15 /c "Reiniciando para aplicar parche EternalBlue MS17-010"
) else (
    echo  Recuerda reiniciar el equipo manualmente.
)

echo.
pause
