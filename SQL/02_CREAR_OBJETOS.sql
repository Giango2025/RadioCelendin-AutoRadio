/* Objetos verificables: 3 SP, 2 triggers de integridad/auditoría, 1 función y SAVE TRANSACTION. */
USE RadioCelendinAutoRadio;
GO
CREATE OR ALTER FUNCTION dbo.fn_DuracionBloque(@BloqueId INT)
RETURNS INT
AS BEGIN
 DECLARE @resultado INT;
 SELECT @resultado=COALESCE(SUM(a.duracion_seg),0)
 FROM dbo.SpotProgramado s INNER JOIN dbo.Audio a ON a.codigo=s.codigo_audio
 WHERE s.bloque_id=@BloqueId;
 RETURN COALESCE(@resultado,0);
END;
GO
CREATE OR ALTER TRIGGER dbo.trg_AuditarSpot
ON dbo.SpotProgramado AFTER INSERT,UPDATE,DELETE
AS BEGIN
 SET NOCOUNT ON;
 INSERT dbo.Auditoria(tabla,registro_id,operacion,valor_anterior,valor_nuevo)
 SELECT 'SpotProgramado',COALESCE(i.programacion_id,d.programacion_id),
 CASE WHEN d.programacion_id IS NULL THEN 'INSERT' WHEN i.programacion_id IS NULL THEN 'DELETE' ELSE 'UPDATE' END,
 CASE WHEN d.programacion_id IS NULL THEN NULL
      ELSE CONCAT('estado=',d.estado,'; prioridad=',d.prioridad,'; audio=',d.codigo_audio) END,
 CASE WHEN i.programacion_id IS NULL THEN NULL
      ELSE CONCAT('estado=',i.estado,'; prioridad=',i.prioridad,'; audio=',i.codigo_audio) END
 FROM inserted i FULL OUTER JOIN deleted d ON d.programacion_id=i.programacion_id;
END;
GO
CREATE OR ALTER TRIGGER dbo.trg_ValidarSpot
ON dbo.SpotProgramado AFTER INSERT,UPDATE
AS BEGIN
 SET NOCOUNT ON;
 IF EXISTS (
 SELECT 1 FROM inserted i JOIN dbo.Campana c ON c.campana_id=i.campana_id
 JOIN dbo.Bloque b ON b.bloque_id=i.bloque_id JOIN dbo.Audio a ON a.codigo=i.codigo_audio
 WHERE a.tipo <> 'ANUNCIO' OR CONVERT(date,b.fecha_hora) NOT BETWEEN c.fecha_inicio AND c.fecha_fin
 OR (i.estado='EMITIDA' AND i.emision_real IS NULL)
 OR (i.estado<>'EMITIDA' AND i.emision_real IS NOT NULL)
 ) THROW 51001,'Spot incompatible, campana fuera de vigencia o fecha de emision inconsistente.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.trg_ValidarCuna
ON dbo.Bloque AFTER INSERT,UPDATE
AS BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN dbo.Audio a ON a.codigo=i.codigo_cuna WHERE a.tipo <> 'CUNA')
 THROW 51002,'Todo bloque debe comenzar con una cuna institucional.',1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_IngestarCatalogo @LoteId INT
AS BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT OFF;
 BEGIN TRY
  BEGIN TRANSACTION;
  SAVE TRANSACTION sp_catalogo;
  ;WITH R AS(
   SELECT s.*,ROW_NUMBER() OVER(PARTITION BY s.codigo ORDER BY s.fila_id) rn
   FROM dbo.StgAudio s WHERE s.lote_id=@LoteId),
  V AS (
   SELECT R.*,
    CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(codigo,''))),'') IS NULL OR LEN(codigo)>12 THEN 'Codigo vacio o demasiado largo'
         WHEN rn>1 OR EXISTS(SELECT 1 FROM dbo.Audio a WHERE a.codigo=R.codigo) THEN 'Codigo duplicado'
         WHEN NULLIF(LTRIM(RTRIM(COALESCE(titulo,''))),'') IS NULL THEN 'Titulo vacio'
         WHEN NULLIF(LTRIM(RTRIM(COALESCE(ruta,''))),'') IS NULL THEN 'Ruta vacia'
         WHEN tipo NOT IN ('MUSICA','ANUNCIO','CUNA') OR tipo IS NULL THEN 'Tipo invalido'
         WHEN formato NOT IN ('MP3','WAV','FLAC','OGG') OR formato IS NULL THEN 'Formato invalido'
         WHEN TRY_CONVERT(INT,duracion_seg) IS NULL OR TRY_CONVERT(INT,duracion_seg) NOT BETWEEN 1 AND 10800 THEN 'Duracion invalida'
         WHEN NULLIF(LTRIM(RTRIM(COALESCE(artista,''))),'') IS NULL THEN 'Artista vacio'
         WHEN NULLIF(LTRIM(RTRIM(COALESCE(genero,''))),'') IS NULL THEN 'Genero vacio'
         ELSE NULL END motivo
   FROM R)
  SELECT * INTO #ValAudio FROM V;
  INSERT dbo.Rechazo(lote_id,fuente,fila_id,motivo)
  SELECT @LoteId,'Audio',v.fila_id,v.motivo FROM #ValAudio v
  WHERE v.motivo IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.Rechazo e WHERE e.lote_id=@LoteId AND e.fuente='Audio' AND e.fila_id=v.fila_id);
  INSERT dbo.Audio(codigo,titulo,artista,genero,tipo,duracion_seg,formato,ruta)
  SELECT codigo,titulo,artista,genero,tipo,TRY_CONVERT(INT,duracion_seg),formato,ruta
  FROM #ValAudio WHERE motivo IS NULL;
  COMMIT TRANSACTION;
 END TRY BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_IngestarAgenda @LoteId INT
AS BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT OFF;
 BEGIN TRY
  BEGIN TRANSACTION;
  SAVE TRANSACTION sp_agenda;
  ;WITH R AS (
   SELECT s.*,ROW_NUMBER() OVER(PARTITION BY s.bloque_ref,s.codigo_audio ORDER BY s.fila_id) rn
   FROM dbo.StgAgenda s WHERE lote_id=@LoteId),
  V AS (
   SELECT R.*,
    CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(bloque_ref,''))),'') IS NULL OR LEN(bloque_ref)>12 THEN 'Referencia de bloque invalida'
     WHEN rn>1 THEN 'Spot duplicado en el mismo bloque'
     WHEN TRY_CONVERT(DATETIME2(0),fecha_hora,120) IS NULL THEN 'Fecha programada invalida'
     WHEN c.campana_id IS NULL THEN 'Campana no existe'
     WHEN a.codigo IS NULL OR a.tipo<>'ANUNCIO' THEN 'Audio no existe o no es anuncio'
     WHEN TRY_CONVERT(INT,R.prioridad) IS NULL OR TRY_CONVERT(INT,R.prioridad) NOT BETWEEN 1 AND 99 THEN 'Prioridad invalida'
     WHEN R.estado NOT IN ('EMITIDA','OMITIDA','PENDIENTE') OR R.estado IS NULL THEN 'Estado invalido'
     WHEN (R.estado='EMITIDA' AND TRY_CONVERT(DATETIME2(0),NULLIF(R.emision_real,''),120) IS NULL)
          OR (R.estado<>'EMITIDA' AND NULLIF(R.emision_real,'') IS NOT NULL) THEN 'Fecha real inconsistente'
     WHEN CONVERT(date,TRY_CONVERT(DATETIME2(0),fecha_hora,120)) NOT BETWEEN c.fecha_inicio AND c.fecha_fin THEN 'Fuera de vigencia'
     WHEN EXISTS (SELECT 1 FROM dbo.SpotProgramado z JOIN dbo.Bloque b0 ON b0.bloque_id=z.bloque_id WHERE b0.referencia=R.bloque_ref AND z.codigo_audio=R.codigo_audio) THEN 'Ya programado'
     ELSE NULL END motivo
   FROM R LEFT JOIN dbo.Campana c ON c.codigo=R.codigo_campana
   LEFT JOIN dbo.Audio a ON a.codigo=R.codigo_audio)
  SELECT * INTO #ValAgenda FROM V;
  INSERT dbo.Rechazo(lote_id,fuente,fila_id,motivo)
  SELECT @LoteId,'Agenda',v.fila_id,v.motivo FROM #ValAgenda v WHERE motivo IS NOT NULL
  AND NOT EXISTS(SELECT 1 FROM dbo.Rechazo e WHERE e.lote_id=@LoteId AND e.fuente='Agenda' AND e.fila_id=v.fila_id);
  INSERT dbo.Bloque(referencia,fecha_hora,codigo_cuna)
  SELECT v.bloque_ref,MIN(TRY_CONVERT(DATETIME2(0),v.fecha_hora,120)),'A0177'
  FROM #ValAgenda v WHERE v.motivo IS NULL
  AND NOT EXISTS(SELECT 1 FROM dbo.Bloque b WHERE b.referencia=v.bloque_ref)
  GROUP BY v.bloque_ref;
  INSERT dbo.SpotProgramado(bloque_id,campana_id,codigo_audio,prioridad,estado,emision_real)
  SELECT b.bloque_id,c.campana_id,v.codigo_audio,TRY_CONVERT(TINYINT,v.prioridad),v.estado,
   TRY_CONVERT(DATETIME2(0),NULLIF(v.emision_real,''),120)
  FROM #ValAgenda v JOIN dbo.Bloque b ON b.referencia=v.bloque_ref
  JOIN dbo.Campana c ON c.codigo=v.codigo_campana
  WHERE v.motivo IS NULL;
  COMMIT TRANSACTION;
 END TRY BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO
/* Procedimiento manual: demuestra SAVEPOINT dentro de una transacción de usuario. */
CREATE OR ALTER PROCEDURE dbo.usp_ProgramarSpot
 @BloqueRef VARCHAR(12),@CampanaCodigo VARCHAR(12),@AudioCodigo VARCHAR(12),@Prioridad TINYINT
AS BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT OFF;
 DECLARE @propia BIT=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
 BEGIN TRY
  IF @propia=1 BEGIN TRANSACTION;
  SAVE TRANSACTION spot_reserva;
  DECLARE @bloque INT=(SELECT bloque_id FROM dbo.Bloque WHERE referencia=@BloqueRef);
  DECLARE @campana INT=(SELECT campana_id FROM dbo.Campana WHERE codigo=@CampanaCodigo);
  IF @bloque IS NULL OR @campana IS NULL THROW 51003,'Bloque o campana inexistente.',1;
  IF @Prioridad NOT BETWEEN 1 AND 99 THROW 51004,'Prioridad fuera de rango.',1;
  INSERT dbo.SpotProgramado(bloque_id,campana_id,codigo_audio,prioridad,estado)
  VALUES(@bloque,@campana,@AudioCodigo,@Prioridad,'PENDIENTE');
  IF @propia=1 COMMIT TRANSACTION;
 END TRY BEGIN CATCH
  IF XACT_STATE()=-1 ROLLBACK TRANSACTION;
  ELSE IF XACT_STATE()=1 BEGIN
    IF @propia=1 ROLLBACK TRANSACTION;
    ELSE ROLLBACK TRANSACTION spot_reserva;
  END;
  THROW;
 END CATCH
END;
GO
