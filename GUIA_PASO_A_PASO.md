# Guía rápida: Radio Celendín AutoRadio

## Requisitos
- SQL Server y SQL Server Management Studio (SSMS).
- Instancia local de prueba, por ejemplo `(localdb)\MSSQLLocalDB`.
- Para el prototipo Windows Forms: Visual Studio y .NET 8.

## Carga en una base de prueba
En SSMS, ejecutar los scripts en el siguiente orden:

1. `SQL/01_CREAR_BASE.sql`: crear estructura.
2. `SQL/02_CREAR_OBJETOS.sql`: procedimientos, triggers y función.
3. `SQL/03_CARGAR_DATOS.sql`: cargar datos simulados una sola vez en una base nueva.
4. `SQL/04_PRUEBAS_SQLSERVER.sql`: ejecutar ocho pruebas.
5. `SQL/05_CONSULTAS_CAPTURAS.sql`: consultar resultados y evidencias.

**Precaución:** no repetir la carga en una base que ya contiene registros válidos. No ejecutar estos archivos en una base de producción.

## Resultado de referencia del conjunto simulado
- 186 audios de entrada, 180 aceptados.
- 967 registros de agenda, 960 aceptados.
- 13 rechazos y 480 bloques.

Estos conteos se verificaron en un entorno local; las ocho pruebas T-SQL deben acreditarse por separado. Si hay resultados FALLIDO o consultas vacías, no deben presentarse como aprobadas.

## Materiales del repositorio
La carpeta `Documentacion/` incluye el informe y la presentación. El proyecto Windows Forms se publica como código fuente, sin asegurar que esté compilado o plenamente probado.

## Estado de publicación
La carga de todos los archivos de código y documentación se completará por separado; el repositorio puede estar incompleto mientras solo se muestran README y archivos de preparación.
