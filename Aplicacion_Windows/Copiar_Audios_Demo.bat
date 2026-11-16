@echo off
setlocal
set "DEST=C:\AutoRadio\audios"
if not exist "%DEST%" mkdir "%DEST%"
xcopy /Y /Q "%~dp0Ejemplos\audio\*.wav" "%DEST%\" >nul
if errorlevel 1 (
 echo ERROR copiando archivos. Abre como usuario con permiso de escritura en C:\AutoRadio.
 pause
 exit /b 1
)
echo Audios de prueba copiados a %DEST%
echo Ahora ejecuta SQL\06_preparar_demo_audio_local.sql en SSMS.
pause
