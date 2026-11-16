@echo off
setlocal
chcp 65001 >NUL
title Radio Celendin AutoRadio - SQL Server EP
cd /d "%~dp0"
echo ==========================================================
echo  RADIO CELENDIN AUTORADIO - DEMOSTRACION EP SQL SERVER
echo ==========================================================
echo ATENCION: Esto crea una base llamada RadioCelendinAutoRadio.
echo Ejecute SOLO en su instancia SQL Server de PRUEBAS.
echo Si ya existe esa base, LEA README_PRIMERO.txt antes de continuar.
echo.
set /p ACEPTA="¿Confirmas que es una instancia de PRUEBAS? [S/N]: "
if /I not "%ACEPTA%"=="S" (
 echo Operacion cancelada.
 pause
 exit /b 1
)
echo.
echo Ejemplos de servidor: .  ^|  .\SQLEXPRESS  ^|  NOMBRE-PC\SQLEXPRESS
set /p SERVIDOR="Tu servidor SQL (Enter para .\SQLEXPRESS): "
if "%SERVIDOR%"=="" set "SERVIDOR=.\SQLEXPRESS"
echo.
echo Se conectara a: %SERVIDOR% usando autenticacion de Windows.
echo Se generara un LOG de la ejecucion y archivos CSV de evidencias.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Herramientas\Ejecutar_SQLServer.ps1" -Servidor "%SERVIDOR%"
set RESULTADO=%ERRORLEVEL%
echo.
if %RESULTADO% NEQ 0 (
 echo ERROR: Verifica el mensaje anterior y el archivo dentro de Evidencias_SQLServer.
 echo Puedes abrir cada SQL directamente en SQL Server Management Studio con F5.
) else (
 echo OK: El motor SQL Server ejecuto los scripts y las pruebas.
 echo Revisa Evidencias_SQLServer y haz las capturas dentro de SSMS.
)
echo.
pause
exit /b %RESULTADO%
