@echo off
cd /d "%~dp0AutoRadio.App"
where dotnet >nul 2>nul
if errorlevel 1 (
 echo Instala .NET SDK 8 con Visual Studio.
 pause
 exit /b 1
)
echo Publicando para Windows x64, con runtime .NET incluido.
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false -o "%~dp0Publicacion_Windows"
if errorlevel 1 (
 echo ERROR de compilacion o descarga NuGet. Lee el mensaje anterior.
 pause
 exit /b 1
)
echo Listo. Programa: Publicacion_Windows\AutoRadio.exe
echo Conserva la carpeta completa Publicacion_Windows; incluye el motor de audio VLC.
pause
