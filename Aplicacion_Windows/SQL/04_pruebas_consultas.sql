USE RadioCelendinAutoRadio;
GO
-- Prueba 1: contar catálogo cargado, campañas, bloques, spots, rechazos.
SELECT (SELECT COUNT(*) FROM dbo.Audio) AS audios_validos,
       (SELECT COUNT(*) FROM dbo.Campana) AS campanas,
       (SELECT COUNT(*) FROM dbo.Bloque) AS bloques,
       (SELECT COUNT(*) FROM dbo.SpotProgramado) AS spots_validos,
       (SELECT COUNT(*) FROM dbo.Rechazo) AS rechazos;
GO
-- Prueba 2: consultas de la operación.
SELECT TOP (10) codigo,titulo,artista,genero,formato FROM dbo.Audio WHERE tipo='MUSICA' ORDER BY titulo;
SELECT b.referencia,b.fecha_hora,b.codigo_cuna,s.codigo_audio,c.codigo AS campana,s.prioridad,s.estado
FROM dbo.Bloque b JOIN dbo.SpotProgramado s ON s.bloque_id=b.bloque_id
JOIN dbo.Campana c ON c.campana_id=s.campana_id ORDER BY b.fecha_hora,s.prioridad;
SELECT TOP (10) b.referencia,dbo.fn_DuracionBloque(b.bloque_id) AS duracion_spots_seg
FROM dbo.Bloque b ORDER BY b.fecha_hora;
GO
-- Prueba 3: auditoría real generada por INSERT/UPDATE. Una modificación dentro de transacción se confirma.
BEGIN TRANSACTION;
UPDATE TOP (1) dbo.SpotProgramado SET prioridad = CASE WHEN prioridad=1 THEN 2 ELSE 1 END
WHERE estado='OMITIDA';
COMMIT TRANSACTION;
SELECT TOP (8) * FROM dbo.Auditoria ORDER BY auditoria_id DESC;
GO
-- Prueba 4: error de vigencia, protección con ROLLBACK y SAVEPOINT.
-- Se crea un bloque posterior a la vigencia de C01 y se intenta programar una pieza de esa campaña.
BEGIN TRY
 BEGIN TRANSACTION;
 INSERT dbo.Bloque(referencia,fecha_hora,codigo_cuna) VALUES ('BPRUEBA99','2029-01-01T09:00:00','A0177');
 EXEC dbo.usp_ProgramarSpot @BloqueRef='BPRUEBA99',@CampanaCodigo='C01',@AudioCodigo='A0141',@Prioridad=1;
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
 SELECT ERROR_NUMBER() AS numero_error,ERROR_MESSAGE() AS mensaje_esperado;
END CATCH;
SELECT COUNT(*) AS bloques_prueba_persistidos FROM dbo.Bloque WHERE referencia='BPRUEBA99';
GO
-- Prueba 5: rollback forzado sin generar modificación final.
DECLARE @antes INT=(SELECT COUNT(*) FROM dbo.SpotProgramado WHERE estado='PENDIENTE');
BEGIN TRANSACTION;
UPDATE TOP (1) dbo.SpotProgramado SET estado='PENDIENTE',emision_real=NULL WHERE estado='OMITIDA';
ROLLBACK TRANSACTION;
SELECT @antes AS pendientes_antes,
 (SELECT COUNT(*) FROM dbo.SpotProgramado WHERE estado='PENDIENTE') AS pendientes_despues;
GO
-- Prueba 6: OLAP temporal (ROLL-UP) y SLICE por campaña.
SELECT YEAR(b.fecha_hora) AS anio,MONTH(b.fecha_hora) AS mes,
 COUNT(*) AS spots, SUM(CASE WHEN s.estado='EMITIDA' THEN 1 ELSE 0 END) AS emitidos
FROM dbo.SpotProgramado s JOIN dbo.Bloque b ON b.bloque_id=s.bloque_id
GROUP BY YEAR(b.fecha_hora),MONTH(b.fecha_hora) ORDER BY anio,mes;
GO
