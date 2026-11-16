/*
 Consultas para capturas reales de SSMS.
 Todas muestran datos de la base que TU ejecutaste, no resultados simulados en pantalla.
 Ejecutar tras el archivo 04. No modifica informacion.
*/
USE RadioCelendinAutoRadio;
GO
SELECT @@SERVERNAME AS servidor_real, DB_NAME() AS base_actual,
 ORIGINAL_LOGIN() AS sesion_sql, SYSDATETIME() AS fecha_local;
SELECT
 (SELECT COUNT(*) FROM dbo.StgAudio WHERE lote_id=1) AS audios_origen,
 (SELECT COUNT(*) FROM dbo.Audio) AS audios_validos,
 (SELECT COUNT(*) FROM dbo.Rechazo WHERE lote_id=1 AND fuente='Audio') AS audios_rechazados,
 (SELECT COUNT(*) FROM dbo.StgAgenda WHERE lote_id=1) AS agenda_origen,
 (SELECT COUNT(*) FROM dbo.SpotProgramado) AS anuncios_validos,
 (SELECT COUNT(*) FROM dbo.Rechazo WHERE lote_id=1 AND fuente='Agenda') AS agenda_rechazados;
GO
SELECT fuente,motivo,COUNT(*) AS registros_afectados
FROM dbo.Rechazo
WHERE lote_id=1 GROUP BY fuente,motivo ORDER BY fuente,motivo;
GO
SELECT TOP (12) codigo,titulo,artista,genero,tipo,duracion_seg,formato,ruta
FROM dbo.Audio ORDER BY codigo;
GO
-- En la emision se reproduce primero la cuna; luego los spots por prioridad ascendente.
SELECT b.referencia,b.fecha_hora,cuna.titulo AS cuna_institucional,
 s.prioridad,a.titulo AS anuncio,c.codigo AS campana,s.estado
FROM dbo.Bloque b
JOIN dbo.Audio cuna ON cuna.codigo=b.codigo_cuna
JOIN dbo.SpotProgramado s ON s.bloque_id=b.bloque_id
JOIN dbo.Audio a ON a.codigo=s.codigo_audio
JOIN dbo.Campana c ON c.campana_id=s.campana_id
WHERE b.referencia='B0001'
ORDER BY s.prioridad,s.programacion_id;
GO
SELECT TOP (15) auditoria_id,tabla,registro_id,operacion,valor_anterior,
 valor_nuevo,usuario_bd,fecha_hora
FROM dbo.Auditoria ORDER BY auditoria_id DESC;
GO
SELECT TOP (20) fecha_utc,prueba,estado,detalle,usuario_sql
FROM dbo.EP_ResultadoPrueba ORDER BY resultado_id DESC;
GO
SELECT o.name AS objeto, o.type_desc AS tipo
FROM sys.objects o
WHERE o.name IN ('usp_IngestarCatalogo','usp_IngestarAgenda','usp_ProgramarSpot',
'trg_AuditarSpot','trg_ValidarSpot','trg_ValidarCuna','fn_DuracionBloque')
ORDER BY o.type_desc,o.name;
GO
SELECT TOP (8) referencia,fecha_hora,
 dbo.fn_DuracionBloque(bloque_id) AS segundos_publicitarios
FROM dbo.Bloque ORDER BY fecha_hora;
GO
