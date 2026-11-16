# Radio Celendín AutoRadio

Proyecto académico de automatización radial y gestión de datos — Universidad Privada del Norte, curso **Base de Datos Avanzadas y Big Data (CIIN1021P)**, periodo 2026-2.

## Estado del proyecto

- Modelo de datos y scripts de SQL Server preparados.
- Se verificó una carga de **186 registros de audio de origen, 180 aceptados; 967 registros de agenda, 960 aceptados; 13 rechazos y 480 bloques** en una instancia local de SQL Server.
- El informe distingue las pruebas verificadas de las que todavía requieren evidencia de aprobación; **no se declara que las ocho pruebas hayan aprobado** sin confirmación.
- La aplicación Windows Forms se entrega como código fuente/prototipo, **no como ejecutable compilado y validado**.
- Los datos usados en el proyecto son **simulados**, no registros reales de la emisora.

## Estructura de archivos prevista

```text
SQL/                    01_CREAR_BASE.sql ... 05_CONSULTAS_CAPTURAS.sql
Datos_SIMULADOS/        CSV y JSON para la demostración
Aplicacion_Windows/     Código fuente C# y recursos de prueba
Documentacion/          Informe APA 7, presentación y guion
Herramientas/           Script auxiliar de ejecución
```

## Ejecución SQL Server

En una base de datos de **pruebas**, ejecutar desde SQL Server Management Studio en este orden:

1. `SQL/01_CREAR_BASE.sql`
2. `SQL/02_CREAR_OBJETOS.sql`
3. `SQL/03_CARGAR_DATOS.sql`
4. `SQL/04_PRUEBAS_SQLSERVER.sql`
5. `SQL/05_CONSULTAS_CAPTURAS.sql`

El script de carga genera datos de prueba; **no ejecutar contra bases con datos que deban conservarse**. La documentación completa describe requisitos y resultados observados.

## Privacidad

Este repositorio debe permanecer privado durante la revisión académica. No subir credenciales, cadenas de conexión con contraseñas ni datos personales no necesarios.

## Publicación

El README se publicó como preparación de la carga del proyecto. **El código y la documentación deben subirse en sus carpetas para completar la publicación.**
