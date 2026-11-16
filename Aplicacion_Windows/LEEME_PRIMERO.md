# Radio Celendín AutoRadio — programa de escritorio para Windows

**Entrega:** proyecto de código fuente C# Windows Forms + SQL Server, SQL de instalación,
archivos WAV sintéticos de demostración y módulos complementarios de la EF.
**No contiene un EXE precompilado:** para obtenerlo se requiere Windows con Visual Studio /.NET 8
(ejecutar `Crear_EXE_Windows.bat`). El motor VLC se descarga mediante NuGet.
**NO está certificado para radiodifusión comercial** y la instalación debe probarse en el equipo del usuario.

## Por qué Windows Forms y SQL Server

- Ya cuentas con SSMS/SQL Server para ejecutar los scripts de la EF.
- Windows Forms permite trabajar en escritorio con listas, catálogos y botones de reproducción.
- SQL Server garantiza relaciones entre clientes, campañas, cuñas, bloques y emisiones.
- LibVLCSharp + VideoLAN.LibVLC.Windows admite MP3/WAV/OGG/FLAC y otros formatos
  populares (M4A y AAC), sujetos al archivo y decodificador.

## 1. Instala Visual Studio

Si tienes Visual Studio: abre Visual Studio Installer → **Modificar** → selecciona
**Desarrollo de escritorio de .NET** → Instalar; comprueba que tengas .NET 8 SDK.
No hace falta instalar plugins de ChatGPT. **NuGet** descarga automáticamente:
`Microsoft.Data.SqlClient`, `LibVLCSharp` y `VideoLAN.LibVLC.Windows`.
También puedes usar `dotnet --version` desde Windows Terminal.

## 2. Crea la base de datos en SSMS (orden obligatorio)

Abre y ejecuta cada archivo con F5 **una sola vez y siguiendo este orden**:

1. `SQL/01_modelo.sql` — base `RadioCelendinAutoRadio` y tablas originales.
2. `SQL/02_objetos.sql` — procedimientos, triggers, función y auditoría.
3. `SQL/03_datos_demo.sql` — datos **ficticios**, ejecuta solo en base de prueba.
4. `SQL/05_extension_aplicacion.sql` — listas musicales, historial e índices,
   amplía la restricción de formatos a MP3/WAV/OGG/FLAC/M4A/AAC.
5. Opcional para clases: `SQL/04_pruebas_consultas.sql` — pruebas de transacciones.
6. Para la demostración de audio: ejecuta `Copiar_Audios_Demo.bat` y luego
   `SQL/06_preparar_demo_audio_local.sql`. Crea un bloque de dos anuncios para
   **3 minutos después de la ejecución** y una lista llamada «Demostración musical».
7. Para capturas: `SQL/07_consultas_verificacion.sql`.

**No ejecutes `03_datos_demo.sql` repetidamente:** contiene operaciones de inserción y
carga por lotes de demostración; evita duplicar o alterar el resultado inicial.

## 3. Abre y ejecuta el programa

1. Descomprime toda la carpeta del ZIP, sin mover archivos por separado.
2. En Visual Studio: **Abrir → Proyecto o solución** → `AutoRadio.App/AutoRadio.App.csproj`.
3. Espera a «Restaurando paquetes NuGet» (se necesita Internet la primera vez).
4. Selecciona arquitectura **x64** y ejecuta con **F5**.
5. Si tu servidor no es `localhost\\SQLEXPRESS`, abre la pestaña **AJUSTES** y cambia
   `Server=...` por el nombre exacto de tu instancia de SSMS. Guardar y conectar.
6. Para generar el EXE y sus librerías, ejecuta `Crear_EXE_Windows.bat`.
   Se creará `Publicacion_Windows/AutoRadio.exe` junto con sus dependencias.

El archivo de ajustes se guarda en `%LOCALAPPDATA%\\AutoRadio\\ajustes.json` y se
recomienda autenticación integrada de Windows. No se permiten contraseñas SQL guardadas
en texto plano mediante esta pantalla.

## 4. Cómo realizar la demostración real de la radio

1. Abre **LISTAS MUSICALES**, elige «Demostración musical» y pulsa **Activar esta lista**.
2. Abre **AJUSTES** y cambia «No repetir canción» a **0** y «No repetir artista» a **0**
   para que las señales cortas puedan reproducirse continuamente durante la prueba.
   En una emisora con biblioteca grande, utiliza valores como 120 y 30 minutos.
3. Abre **EN EMISIÓN**, activa **Automático**. Se iniciará una de tres pistas originales
   sintéticas (no son música comercial ni anuncios de terceros).
4. El bloque recién creado se reproducirá a su hora: la música baja gradualmente,
   se pausa, suena primero la cuña de apertura, luego el anuncio prioritario 1 y después 2.
5. Al finalizar, el programa reanuda la canción y recupera el volumen gradualmente.
6. Abre **REPORTES** y comprueba `EMITIDA`, historial musical y auditoría.
7. Puedes probar **modo manual**, los botones de pausa y la emisión de un bloque seleccionado.

## 5. Qué permite cada pestaña

| Pestaña | Funciones |
|---|---|
| EN EMISIÓN | Música manual, pausa, avance, automático, publicidad y detener bloque. |
| BIBLIOTECA | Búsqueda, alta, modificación, eliminación e importación de canciones, cuñas y anuncios. |
| PROGRAMACIÓN | Fechas y horarios libres, cuña inicial, anuncios por prioridad, control de campañas. |
| PUBLICIDAD | Registro de clientes y campañas con vigencia. |
| LISTAS MUSICALES | Crear listas, añadir/quitar canciones y activar lista de rotación. |
| REPORTES | Historial musical, anuncios emitidos/omitidos, problemas de archivos e indicadores. |
| AJUSTES | Cadena SQL, antirrepetición configurable hasta 90 días, fade, volumen. |

## 6. Funcionalidades y limitaciones transparentes

- **Programación a una hora arbitraria:** se guarda un instante local en SQL; el reloj del
  servidor y el equipo de reproducción deben estar sincronizados.
- **Cuña obligatoria:** antes de los anuncios se reproduce la cuña indicada por el bloque;
  si está ausente, se suspende el bloque y sus anuncios se mantienen pendientes.
- **Prioridad:** 1 corresponde al primer anuncio dentro del bloque; gana sobre 2, 3, etc.
- **Error de archivo:** se muestra un mensaje y se registra la incidencia; un anuncio fallido
  se marca `OMITIDA`, no como emitido. Otros anuncios válidos pueden continuar.
- **Antirrepetición:** hasta 90 días. Si no existe canción que cumpla los límites,
  el automático se detiene y lo comunica; no se salta las reglas silenciosamente.
- **Importación por carpeta:** registra rutas; la duración se estima por el tamaño del archivo.
  Debes corregirla manualmente antes de producir emisiones reales.
- **La programación es de un solo equipo operador** y no tiene mecanismos de alta
  disponibilidad, streaming, RDS, registro profesional de cumplimiento ni consola de aire.
  No sustituye un producto comercial Jazler.
- **Pruebas:** el código y el SQL se verificaron estáticamente en el entorno de creación;
  no se compiló ni probó la reproducción real en Windows porque este entorno es Linux
  y no cuenta con SDK de .NET/SQL Server locales. Quedan por validar en tu PC.

## 7. Pruebas de la EF

- SQL Server: ejecutar `SQL/04_pruebas_consultas.sql` y las consultas de verificación.
- Complementos: las carpetas `Complementos_EF/02_seguridad`, `03_bi` y `04_bigdata`
  contienen los scripts y notebooks del proyecto integrador anterior; deben ejecutarse
  por separado y documentar evidencias reales. No son módulos que se activen desde la
  interfaz Windows Forms.
- Obtén capturas reales de la ventana, SQL Server, triggers, transacciones y reportes.
- Los audios y registros incluidos son **solo datos originales/simulados de prueba**.

## 8. Solución de problemas frecuente

- **No se conecta:** verifica el nombre exacto en SSMS, permisos de Windows y que
  `RadioCelendinAutoRadio` exista; ejecuta 05_extension si faltan tablas de lista.
- **No aparece música:** asigna rutas reales o ejecuta la copia WAV + SQL 06.
- **No se puede emitir:** revisa campañas vigentes, bloques pendientes y cuña válida.
- **NuGet falla:** verifica Internet, plataforma x64 y restauración en Visual Studio.
- **No hay audio:** revisa el dispositivo predeterminado de Windows y el volumen.
- **Warning / error compilación:** comparte el mensaje completo de Visual Studio, el
  `.cs` y la línea para corregirlo; el paquete incluye los fuentes editables.

Este proyecto se entrega como base funcional implementable para **demostración académica**,
no como un programa ya ejecutado ni homologado en una emisora en funcionamiento.
