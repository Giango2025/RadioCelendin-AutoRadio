@echo off
setlocal
chcp 65001 >NUL
title Radio Celendin AutoRadio - Solo pruebas EP
cd /d "%~dp0"
echo ==============================================================
echo  REEJECUTAR SOLO VERIFICACIONES EN LA BASE EXISTENTE
echo  No se vuelven a importar los datos ficticios.
echo ==============================================================
echo.
set /p SERVIDOR="Tu servidor SQL (Enter para .\SQLEXPRESS): "
if "%SERVIDOR%"=="" set "SERVIDOR=.\SQLEXPRESS"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Herramientas\Ejecutar_SQLServer.ps1" -Servidor "%SERVIDOR%" -SoloPruebas
set RESULTADO=%ERRORLEVEL%
if %RESULTADO% NEQ 0 (
 echo REVISAR MENSAJES DE ERROR EN Evidencias_SQLServer.
) else (
 echo VERIFICACION COMPLETADA: revisa Evidencias_SQLServer.
)
pause
exit /b %RESULTADO%
