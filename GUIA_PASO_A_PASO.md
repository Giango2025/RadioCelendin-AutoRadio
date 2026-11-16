# GUÍA PASO A PASO — PRUEBA DE EP EN SQL SERVER

## A. Verifica el motor y la instancia
1. Abre **SQL Server Management Studio** (SSMS).
2. Conéctate como lo haces normalmente. Anota **Server name**.
3. Ejecuta `SELECT @@SERVERNAME AS instancia, @@VERSION AS version;` y toma una captura.
4. Si ves `SQL Server Management Studio`, pero no hay motor al que conectarte, instala
   **SQL Server Developer** o **SQL Server Express** por separado (SSMS no lo incluye).

## B. Automatización
Abre `EJECUTAR_EN_WINDOWS.bat`, responde `S` cuando confirme que es tu instancia de
pruebas y escribe el **Server name**. El lanzador ejecuta la creación, carga y
las 8 verificaciones; produce CSV/log a partir de la sesión SQL.

Usa `REPETIR_SOLO_PRUEBAS.bat` cuando ya exista la base cargada. Nunca repitas la
carga demo en una base de datos que tenga 180 audios; eso cambiaría los rechazos.

## C. Ejecución directamente en SSMS
Si falla el lanzador por políticas de PowerShell:
1. `File > Open > File` → `SQL/01_CREAR_BASE.sql` → `F5`.
2. Repite con `02_CREAR_OBJETOS.sql`.
3. Repite con `03_CARGAR_DATOS.sql` (UNA sola vez sobre una base nueva).
4. Repite con `04_PRUEBAS_SQLSERVER.sql`.
5. Por último `05_CONSULTAS_CAPTURAS.sql`. Selecciona la pestaña **Results**.

Las capturas del archivo 04 son importantes: la tabla `dbo.EP_ResultadoPrueba`
debe contener ocho filas APROBADO del último `ejecucion_id`. Si hay un
FALLIDO, no reportes éxito: revisa `detalle` y el log.

## D. Qué presentar ante el profesor (EP)
**Criterio 1:** presenta fuentes (CSV ficticios), 6 rechazos del catálogo,
7 de la agenda, sus causas, 3 requisitos verificables y 3 supuestos justificados.

**Criterio 2:** presenta el cronograma de 6+ hitos, ruta crítica, responsables y recursos;
la ejecución SQL es un hito de viabilidad.

**Criterio 3:** presenta al menos 2 alternativas técnicas frente a SQL Server
(procesos en C# vs. ETL externo) usando 3 criterios: trazabilidad, rendimiento
y mantenibilidad. Los tiempos reales deben medirse en SSMS si se citan.

**Criterio 4:** presenta el test de campaña vencida (rechazada, con ROLLBACK) y
el registro de auditoría; adjunta al menos dos evidencias: log + captura y un
veredicto real (viable/requiere ajuste/pivotar).

**Criterio 5:** presenta 4 riesgos mitigados, tres conocimientos previos y dos
cursos posteriores enlazados al proyecto.

## E. Capturas necesarias
- [ ] Nombre de la instancia SQL Server (`@@SERVERNAME`, `@@VERSION`).
- [ ] Base `RadioCelendinAutoRadio` → tablas del Explorador de objetos.
- [ ] Conteos de datos aceptados/rechazados y motivos.
- [ ] 3 SP, 3 triggers, 1 función.
- [ ] Cuña `A0177` y prioridades en `B0001`.
- [ ] Auditoría de UPDATE confirmado en `dbo.Auditoria`.
- [ ] Ocho filas de `dbo.EP_ResultadoPrueba`, sin fallidos.
- [ ] Log de PowerShell o resultado del script 04 con servidor/usuario/fecha.

## F. Explicación sencilla durante la exposición
1. “Creamos un modelo relacional para canciones, campañas y bloques publicitarios”.
2. “El proceso recibe datos y separa los inválidos; no los ingresamos a tablas limpias”.
3. “Un trigger impide programar publicidad vencida; otro audita los cambios”.
4. “Probamos `ROLLBACK` y `SAVEPOINT`: si hay un error, no quedan cambios indebidos”.
5. “Guardamos log y capturas del entorno SQL para respaldar la viabilidad”.

## G. Errores frecuentes
**Error 53 / server not found:** el nombre de la instancia es incorrecto o el
servicio SQL Server está detenido. Usa exactamente el nombre de SSMS.

**Error 18456:** la cuenta de Windows no tiene acceso a ese servidor; solicita
permisos al administrador del laboratorio.

**Error 262:** la cuenta no puede ejecutar `CREATE DATABASE`.
El docente debe autorizarlo en una instancia de pruebas.

**Error 2714:** la base u objeto ya existe parcialmente. No borres nada; muestra
el mensaje para adaptar la instalación sin perder datos.

**Algunas pruebas FALLIDO:** abre `dbo.EP_ResultadoPrueba` y compara los conteos;
no sigas presentándolas como aprobadas hasta corregir el error.

**Trusted certificate:** el lanzador permite `TrustServerCertificate=True` solo
para la instalación local de laboratorio; no es una configuración segura para
despliegues reales.

## H. Qué todavía NO representa este paquete
No entrega un `.exe` de Windows Forms, ni reproduce audio ni implementa el ETL
del proyecto EF; cumple la práctica EP de automatización SQL y evidencia
de viabilidad. La ejecución real debe hacerse en tu PC con SQL Server.
