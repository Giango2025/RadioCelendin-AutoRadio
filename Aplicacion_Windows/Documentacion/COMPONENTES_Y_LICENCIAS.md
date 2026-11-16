# Dependencias y licencias

- Microsoft.Data.SqlClient (NuGet 5.2.2): controlador SQL Server; paquete de Microsoft.
- LibVLCSharp (NuGet 3.10.1): interfaz .NET para reproducción VLC (VideoLAN, licencia LGPL).
- VideoLAN.LibVLC.Windows (NuGet 3.0.24): motor multimedia nativo (VideoLAN, licencia LGPL y componentes de terceros).
- .NET SDK 8: herramienta para compilar el código de Windows Forms.

Los paquetes **no se incluyen** en el ZIP para evitar redistribuir binarios grandes; Visual
Studio los descargará desde nuget.org durante la restauración.

Antes de redistribuir comercialmente un instalador, revisa y cumple las licencias de
VideoLAN y de los códecs utilizados, así como los derechos de la música y publicidad.

Referencias:
- https://www.nuget.org/packages/LibVLCSharp/3.10.1
- https://www.nuget.org/packages/VideoLAN.LibVLC.Windows/3.0.24
- https://www.nuget.org/packages/Microsoft.Data.SqlClient/5.2.2
- https://learn.microsoft.com/en-us/dotnet/desktop/winforms/
