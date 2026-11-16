/*
  AUTORADIO - PRUEBAS DE EP EN SQL SERVER
  Requisitos: SQL Server 2019 o posterior, scripts 01, 02 y 03 completados.
  Datos: 100% SIMULADOS. Ninguna comprobacion puede declararse aprobada antes de ejecutarse.
  Este archivo no borra datos ni elimina la base. Los tests mutan SOLO datos ficticios.
*/
USE RadioCelendinAutoRadio;
GO
IF OBJECT_ID(N'dbo.EP_ResultadoPrueba',N'U') IS NULL
BEGIN
  CREATE TABLE dbo.EP_ResultadoPrueba
  (
    resultado_id INT IDENTITY(1,1) PRIMARY KEY,
    ejecucion_id UNIQUEIDENTIFIER NOT NULL,
    fecha_utc DATETIME2(0) NOT NULL CONSTRAINT DF_EP_Fecha DEFAULT SYSUTCDATETIME(),
    prueba NVARCHAR(150) NOT NULL,
    estado VARCHAR(8) NOT NULL CHECK (estado IN ('APROBADO','FALLIDO')),
    detalle NVARCHAR(1000) NOT NULL,
    usuario_sql SYSNAME NOT NULL DEFAULT ORIGINAL_LOGIN()
  );
END;
GO
SET NOCOUNT ON;
SET XACT_ABORT OFF;

DECLARE @run UNIQUEIDENTIFIER = NEWID();
DECLARE @aprobado BIT = 0;
DECLARE @detalle NVARCHAR(1000);
DECLARE @audios INT = (SELECT COUNT(*) FROM dbo.Audio);
DECLARE @spots INT = (SELECT COUNT(*) FROM dbo.SpotProgramado);
DECLARE @bloques INT = (SELECT COUNT(*) FROM dbo.Bloque);
DECLARE @rejAudio INT = (SELECT COUNT(*) FROM dbo.Rechazo WHERE lote_id=1 AND fuente='Audio');
DECLARE @rejAgenda INT = (SELECT COUNT(*) FROM dbo.Rechazo WHERE lote_id=1 AND fuente='Agenda');
DECLARE @stgAudio INT = (SELECT COUNT(*) FROM dbo.StgAudio WHERE lote_id=1);
DECLARE @stgAgenda INT = (SELECT COUNT(*) FROM dbo.StgAgenda WHERE lote_id=1);
DECLARE @b1 INT = (SELECT bloque_id FROM dbo.Bloque WHERE referencia='B0001');
DECLARE @durFuncion INT;
DECLARE @durSumatoria INT;
DECLARE @usuario SYSNAME = ORIGINAL_LOGIN();

PRINT '--- RADIO CELENDIN AUTORADIO: VERIFICACION EP EN SQL SERVER ---';
PRINT CONCAT('Ejecucion: ', CONVERT(VARCHAR(36),@run), ' | Usuario: ', @usuario);

-- Prueba 01: integridad de carga y conteos esperados del dataset ficticio.
SET @aprobado = CASE WHEN @audios=180 AND @spots=960 AND @bloques=480
  AND @rejAudio=6 AND @rejAgenda=7 AND @stgAudio=186 AND @stgAgenda=967 THEN 1 ELSE 0 END;
INSERT dbo.EP_ResultadoPrueba(ejecucion_id,prueba,estado,detalle)
VALUES(@run,N'01 - Carga y calidad de datos',
 CASE WHEN @aprobado=1 THEN 'APROBADO' ELSE 'FALLIDO' END,
 CONCAT('Staging audio=',@stgAudio,'; aceptados=',@audios,'; rechazados=',@rejAudio,
 '; staging agenda=',@stgAgenda,'; spots=',@spots,'; rechazados=',@rejAgenda,
 '; bloques=',@bloques,'. Esperado: 186/180/6; 967/960/7; 480 bloques.'));

-- Prueba 02: existen 3 SP, 3 triggers y una funcion escalar.
SET @aprobado = CASE WHEN OBJECT_ID(N'dbo.usp_IngestarCatalogo',N'P') IS NOT NULL
 AND OBJECT_ID(N'dbo.usp_IngestarAgenda',N'P') IS NOT NULL
 AND OBJECT_ID(N'dbo.usp_ProgramarSpot',N'P') IS NOT NULL
 AND OBJECT_ID(N'dbo.trg_AuditarSpot',N'TR') IS NOT NULL
 AND OBJECT_ID(N'dbo.trg_ValidarSpot',N'TR') IS NOT NULL
 AND OBJECT_ID(N'dbo.trg_ValidarCuna',N'TR') IS NOT NULL
 AND OBJECT_ID(N'dbo.fn_DuracionBloque',N'FN') IS NOT NULL THEN 1 ELSE 0 END;
INSERT dbo.EP_ResultadoPrueba(ejecucion_id,prueba,estado,detalle)
VALUES (@run,N'02 - Objetos T-SQL',
 CASE WHEN @aprobado=1 THEN 'APROBADO' ELSE 'FALLIDO' END,
 N'3 procedimientos, 3 triggers y funcion escalar: existencia en sys.objects.');

-- Prueba 03: cuna ANTES de los anuncios y prioridades 1 y 2 en el bloque B0001.
SET @aprobado = CASE WHEN @b1 IS NOT NULL
 AND EXISTS(SELECT 1 FROM dbo.Bloque b JOIN dbo.Audio a ON a.codigo=b.codigo_cuna
            WHERE b.bloque_id=@b1 AND a.tipo='CUNA')
 AND (SELECT COUNT(*) FROM dbo.SpotProgramado WHERE bloque_id=@b1)=2
 AND (SELECT MIN(prioridad) FROM dbo.SpotProgramado WHERE bloque_id=@b1)=1
 AND (SELECT MAX(prioridad) FROM dbo.SpotProgramado WHERE bloque_id=@b1)=2
 THEN 1 ELSE 0 END;
INSERT dbo.EP_ResultadoPrueba(ejecucion_id,prueba,estado,detalle)
VALUES (@run,N'03 - Cuna y prioridades',
 CASE WHEN @aprobado=1 THEN 'APROBADO' ELSE 'FALLIDO' END,
 N'Bloque B0001 debe tener una cuna de tipo CUNA y dos spots con prioridades 1 y 2.');

-- Prueba 04: la funcion debe igualar la sumatoria de duraciones.
SELECT @durFuncion = dbo.fn_DuracionBloque(@b1);
SELECT @durSumatoria=COALESCE(SUM(a.duracion_seg),0)
FROM dbo.SpotProgramado s JOIN dbo.Audio a ON a.codigo=s.codigo_audio
WHERE s.bloque_id=@b1;
SET @aprobado=CASE WHEN @durFuncion=@durSumatoria AND @durFuncion>0 THEN 1 ELSE 0 END;
INSERT dbo.EP_ResultadoPrueba(ejecucion_id,prueba,estado,detalle)
VALUES(@run,N'04 - Funcion duracion de bloque',
 CASE WHEN @aprobado=1 THEN 'APROBADO' ELSE 'FALLIDO' END,
 CONCAT('Funcion=',COALESCE(CONVERT(VARCHAR(12),@durFuncion),'NULL'),
 ' seg; sumatoria SQL=',COALESCE(CONVERT(VARCHAR(12),@durSumatoria),'NULL'),' seg.'));

-- Prueba 05: UPDATE confirmado genera auditoria.
DECLARE @idActualizar INT =
 (SELECT TOP (1) programacion_id FROM dbo.SpotProgramado
  WHERE estado='OMITIDA' ORDER BY programacion_id);
DECLARE @auditoriaAntes INT=(SELECT COUNT(*) FROM dbo.Auditoria);
DECLARE @auditoriaDespues INT=@auditoriaAntes;
DECLARE @errorAuditoria NVARCHAR(500)=N'';
IF @idActualizar IS NOT NULL
BEGIN
  BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.SpotProgramado
    SET prioridad = CASE WHEN prioridad=1 THEN 2 ELSE 1 END
    WHERE programacion_id=@idActualizar;
    COMMIT TRANSACTION;
    SELECT @auditoriaDespues=COUNT(*) FROM dbo.Auditoria;
    SET @aprobado=CASE WHEN @auditoriaDespues>@auditoriaAntes
      AND EXISTS(SELECT 1 FROM dbo.Auditoria WHERE registro_id=@idActualizar
      AND tabla='SpotProgramado' AND operacion='UPDATE') THEN 1 ELSE 0 END;
  END TRY
  BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SET @errorAuditoria=ERROR_MESSAGE();
    SET @aprobado=0;
  END CATCH;
END
ELSE SET @aprobado=0;
INSERT dbo.EP_ResultadoPrueba(ejecucion_id,prueba,estado,detalle)
VALUES(@run,N'05 - Auditoria trigger y COMMIT',
 CASE WHEN @aprobado=1 THEN 'APROBADO' ELSE 'FALLIDO' END,
 CONCAT('Auditoria antes=',@auditoriaAntes,'; despues=',@auditoriaDespues,
 '; ID modificado=',COALESCE(CONVERT(VARCHAR(12),@idActualizar),'NULL'),
 '. Error=',@errorAuditoria));

-- Prueba 06: error por campana vencida -> rollback, sin bloque persistente.
DECLARE @ref VARCHAR(12)='E'+LEFT(REPLACE(CONVERT(VARCHAR(36),NEWID()),'-',''),11);
DECLARE @errorVigencia INT=NULL;
DECLARE @msgVigencia NVARCHAR(500)=N'';
BEGIN TRY
  BEGIN TRANSACTION;
  INSERT dbo.Bloque(referencia,fecha_hora,codigo_cuna)
  VALUES(@ref,'2035-01-01T10:00:00','A0177');
  EXEC dbo.usp_ProgramarSpot
   @BloqueRef=@ref,@CampanaCodigo='C01',@AudioCodigo='A0143',@Prioridad=1;
  IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; -- NO se esperaba permitir el alta
END TRY
BEGIN CATCH
  SELECT @errorVigencia=ERROR_NUMBER(),@msgVigencia=ERROR_MESSAGE();
  IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
END CATCH;
SET @aprobado=CASE WHEN @errorVigencia=51001
 AND NOT EXISTS(SELECT 1 FROM dbo.Bloque WHERE referencia=@ref) THEN 1 ELSE 0 END;
INSERT dbo.EP_ResultadoPrueba(ejecucion_id,prueba,estado,detalle)
VALUES(@run,N'06 - Trigger de vigencia y ROLLBACK',
 CASE WHEN @aprobado=1 THEN 'APROBADO' ELSE 'FALLIDO' END,
 CONCAT('Numero capturado=',COALESCE(CONVERT(VARCHAR(12),@errorVigencia),'NULL'),
 '; bloque de prueba persistido=',
 CASE WHEN EXISTS(SELECT 1 FROM dbo.Bloque WHERE referencia=@ref) THEN 'SI' ELSE 'NO' END,
 '; mensaje=',@msgVigencia));

-- Prueba 07: punto de guardado conserva la primera insercion y deshace la segunda.
DECLARE @marca NVARCHAR(36)=CONVERT(NVARCHAR(36),NEWID());
DECLARE @mensajeOK NVARCHAR(90)=CONCAT('EP_COMMIT_',@marca);
DECLARE @mensajeUndo NVARCHAR(90)=CONCAT('EP_ROLLBACK_',@marca);
DECLARE @errorSavepoint NVARCHAR(500)=N'';
BEGIN TRY
  BEGIN TRANSACTION;
  INSERT dbo.IncidenciaArchivo(codigo_audio,mensaje) VALUES('A0001',@mensajeOK);
  SAVE TRANSACTION EP_PUNTO;
  INSERT dbo.IncidenciaArchivo(codigo_audio,mensaje) VALUES('A0001',@mensajeUndo);
  ROLLBACK TRANSACTION EP_PUNTO;
  COMMIT TRANSACTION;
  SET @aprobado=CASE WHEN EXISTS(SELECT 1 FROM dbo.IncidenciaArchivo WHERE mensaje=@mensajeOK)
     AND NOT EXISTS(SELECT 1 FROM dbo.IncidenciaArchivo WHERE mensaje=@mensajeUndo) THEN 1 ELSE 0 END;
END TRY
BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  SET @errorSavepoint=ERROR_MESSAGE();
  SET @aprobado=0;
END CATCH;
INSERT dbo.EP_ResultadoPrueba(ejecucion_id,prueba,estado,detalle)
VALUES(@run,N'07 - SAVEPOINT y COMMIT parcial',
 CASE WHEN @aprobado=1 THEN 'APROBADO' ELSE 'FALLIDO' END,
 CONCAT('Fila conservada=',
 CASE WHEN EXISTS(SELECT 1 FROM dbo.IncidenciaArchivo WHERE mensaje=@mensajeOK) THEN 'SI' ELSE 'NO' END,
 '; fila revertida=',
 CASE WHEN EXISTS(SELECT 1 FROM dbo.IncidenciaArchivo WHERE mensaje=@mensajeUndo) THEN 'SI' ELSE 'NO' END,
 '; error=',@errorSavepoint));

-- Prueba 08: excepcion TRY/CATCH en un procedimiento ante campana desconocida.
DECLARE @errorSP INT=NULL;
DECLARE @msgSP NVARCHAR(500)=N'';
BEGIN TRY
  EXEC dbo.usp_ProgramarSpot
    @BloqueRef='B0001',@CampanaCodigo='NO_EXISTE',@AudioCodigo='A0143',@Prioridad=1;
END TRY
BEGIN CATCH
  SELECT @errorSP=ERROR_NUMBER(),@msgSP=ERROR_MESSAGE();
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
END CATCH;
SET @aprobado=CASE WHEN @errorSP=51003 THEN 1 ELSE 0 END;
INSERT dbo.EP_ResultadoPrueba(ejecucion_id,prueba,estado,detalle)
VALUES(@run,N'08 - TRY/CATCH de procedimiento',
 CASE WHEN @aprobado=1 THEN 'APROBADO' ELSE 'FALLIDO' END,
 CONCAT('Numero=',COALESCE(CONVERT(VARCHAR(12),@errorSP),'NULL'),'; mensaje=',@msgSP));

-- Salidas de evidencia para SSMS.
SELECT @run AS EJECUCION_SQLSERVER, ORIGINAL_LOGIN() AS usuario,
 @@SERVERNAME AS servidor, DB_NAME() AS base_datos, SYSDATETIME() AS fecha_local;
SELECT prueba,estado,detalle,fecha_utc,usuario_sql
FROM dbo.EP_ResultadoPrueba WHERE ejecucion_id=@run ORDER BY resultado_id;
SELECT SUM(CASE WHEN estado='APROBADO' THEN 1 ELSE 0 END) AS APROBADOS,
       SUM(CASE WHEN estado='FALLIDO' THEN 1 ELSE 0 END) AS FALLIDOS
FROM dbo.EP_ResultadoPrueba WHERE ejecucion_id=@run;
IF EXISTS(SELECT 1 FROM dbo.EP_ResultadoPrueba
          WHERE ejecucion_id=@run AND estado='FALLIDO')
  THROW 52001,'ALGUNA PRUEBA EP FALLO. Ver tabla dbo.EP_ResultadoPrueba.',1;
PRINT 'EP: 8/8 verificaciones aprobadas en SQL Server (solo si se imprime tras ejecutar).';
GO
