-- ETL incremental desde OLTP validado hacia esquema estrella.
USE RadioCelendinDW;
GO
IF OBJECT_ID('dbo.EtlLog','U') IS NULL
CREATE TABLE dbo.EtlLog(log_id INT IDENTITY PRIMARY KEY,ejecutado_en DATETIME2(0) DEFAULT SYSDATETIME(),
 fuente VARCHAR(30),registros_origen INT,registros_cargados INT,duracion_ms INT,estado VARCHAR(20));
GO
SET NOCOUNT ON;
DECLARE @t DATETIME2(3)=SYSDATETIME(),@n INT;
BEGIN TRY
 BEGIN TRAN;
 INSERT dbo.DimFecha(fecha_key,fecha,anio,mes,dia)
 SELECT DISTINCT CONVERT(INT,CONVERT(CHAR(8),CAST(b.fecha_hora AS DATE),112)),
 CAST(b.fecha_hora AS DATE),YEAR(b.fecha_hora),MONTH(b.fecha_hora),DAY(b.fecha_hora)
 FROM RadioCelendinAutoRadio.dbo.Bloque b
 WHERE NOT EXISTS(SELECT 1 FROM dbo.DimFecha d WHERE d.fecha=CAST(b.fecha_hora AS DATE));
 INSERT dbo.DimCliente(cliente_id_origen,nombre)
 SELECT c.cliente_id,c.nombre FROM RadioCelendinAutoRadio.dbo.Cliente c
 WHERE NOT EXISTS(SELECT 1 FROM dbo.DimCliente d WHERE d.cliente_id_origen=c.cliente_id);
 INSERT dbo.DimCampana(campana_id_origen,codigo,nombre)
 SELECT c.campana_id,c.codigo,c.nombre FROM RadioCelendinAutoRadio.dbo.Campana c
 WHERE NOT EXISTS(SELECT 1 FROM dbo.DimCampana d WHERE d.campana_id_origen=c.campana_id);
 INSERT dbo.DimAudio(codigo_audio,titulo,formato,duracion_seg)
 SELECT a.codigo,a.titulo,a.formato,a.duracion_seg FROM RadioCelendinAutoRadio.dbo.Audio a
 WHERE NOT EXISTS(SELECT 1 FROM dbo.DimAudio d WHERE d.codigo_audio=a.codigo);
 INSERT dbo.FactEmision(programacion_id_origen,fecha_key,cliente_key,campana_key,audio_key,
  programados,emitidos,omitidos,atraso_seg,duracion_seg)
 SELECT s.programacion_id,CONVERT(INT,CONVERT(CHAR(8),CAST(b.fecha_hora AS DATE),112)),
 dc.cliente_key,dca.campana_key,da.audio_key,
 1,CASE WHEN s.estado='EMITIDA' THEN 1 ELSE 0 END,
 CASE WHEN s.estado='OMITIDA' THEN 1 ELSE 0 END,
 CASE WHEN s.estado='EMITIDA' THEN DATEDIFF(SECOND,b.fecha_hora,s.emision_real) ELSE NULL END,
 da.duracion_seg
 FROM RadioCelendinAutoRadio.dbo.SpotProgramado s
 JOIN RadioCelendinAutoRadio.dbo.Bloque b ON b.bloque_id=s.bloque_id
 JOIN RadioCelendinAutoRadio.dbo.Campana ca ON ca.campana_id=s.campana_id
 JOIN dbo.DimCampana dca ON dca.campana_id_origen=ca.campana_id
 JOIN dbo.DimCliente dc ON dc.cliente_id_origen=ca.cliente_id
 JOIN dbo.DimAudio da ON da.codigo_audio=s.codigo_audio
 WHERE NOT EXISTS(SELECT 1 FROM dbo.FactEmision f WHERE f.programacion_id_origen=s.programacion_id);
 SET @n=@@ROWCOUNT;
 INSERT dbo.EtlLog(fuente,registros_origen,registros_cargados,duracion_ms,estado)
 SELECT 'SpotProgramado',COUNT(*),@n,DATEDIFF(MILLISECOND,@t,SYSDATETIME()),'OK'
 FROM RadioCelendinAutoRadio.dbo.SpotProgramado;
 COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
SELECT TOP(5) * FROM dbo.EtlLog ORDER BY log_id DESC;
GO
