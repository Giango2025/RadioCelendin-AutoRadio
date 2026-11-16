# Radio Celendín AutoRadio

Proyecto académico — Base de Datos Avanzadas y Big Data (CIIN1021P), UPN 2026-2.

## Descripción
Sistema académico de automatización de programación radial con SQL Server, ingesta de catálogo y agenda, auditoría de cambios y prototipo de interfaz Windows Forms en C#. **Los datos de clientes, campañas y programación son simulados**. El proyecto no representa una integración en producción con la emisora.

## Contenido

- `SQL/`: cinco scripts secuenciales para SQL Server.
- `Datos_SIMULADOS/`: CSV y JSON ficticios utilizados en las pruebas.
- `Herramientas/`, `EJECUTAR_EN_WINDOWS.bat`: utilidades de ejecución local.
- `Aplicacion_Windows/`: código fuente y utilidades para compilar el prototipo Windows Forms; no es un ejecutable compilado y probado en todos los equipos.
- `Documentacion/`: informe APA 7, presentación, guion y revisión de pendientes.

## Requisitos

- Windows, SQL Server y SQL Server Management Studio (SSMS).
- .NET 8 SDK para compilar el proyecto C# (consultar `Aplicacion_Windows/LEEME_PRIMERO.md`).
- Una base de datos **de pruebas**; nunca ejecutar scripts de carga sobre una base con datos valiosos.

## Cómo ejecutar SQL

1. En SSMS, conéctate a la instancia SQL Server que utilizarás (ejemplo: `(localdb)\MSSQLLocalDB`).
2. Ejecuta los archivos de `SQL/` en orden: `01_CREAR_BASE.sql`, `02_CREAR_OBJETOS.sql`, `03_CARGAR_DATOS.sql`, `04_PRUEBAS_SQLSERVER.sql` y `05_CONSULTAS_CAPTURAS.sql`.
3. Verifica la pestaña **Mensajes** y las tablas de resultados. No presupongas aprobadas las pruebas.
4. Para una instalación ya cargada, evita repetir la carga de datos sin revisar la guía.

Conteos de referencia para los datos simulados: 186 audios de origen, 180 aceptados, 967 filas de agenda, 960 spots aceptados, 13 rechazos y 480 bloques.

## Estado de validación

Los conteos de ingesta fueron verificados mediante capturas de SSMS. No se certifican aquí resultados definitivos de las ocho pruebas ni la funcionalidad de reproducción del prototipo en Windows. Consulta `Documentacion/Estado_Verificacion.txt` y el informe para las limitaciones.

## Privacidad y uso académico

Los datos operativos aportados son ficticios. Los documentos académicos contienen nombres de participantes y pueden incluir identificadores universitarios; mantenlos en un repositorio **privado** y revisa ese contenido antes de compartir el repositorio públicamente. No publiques contraseñas, tokens ni cadenas de conexión con credenciales.
