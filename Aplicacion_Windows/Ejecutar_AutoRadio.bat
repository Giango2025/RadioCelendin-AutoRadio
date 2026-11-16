@echo off
cd /d "%~dp0AutoRadio.App"
where dotnet >nul 2>nul
if errorlevel 1 (
 echo No se encontro dotnet. Instala Visual Studio con Desarrollo de escritorio de .NET.
 pause
 exit /b 1
)
echo Restaurando paquetes NuGet. La primera vez descarga el motor de audio VLC.
dotnet restore
if errorlevel 1 (
 echo ERROR de NuGet. Revisa Internet y los paquetes en Visual Studio.
 pause
 exit /b 1
)
dotnet run -c Release
if errorlevel 1 pause
