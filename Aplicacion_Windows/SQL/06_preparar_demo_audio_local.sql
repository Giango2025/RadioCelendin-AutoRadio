/* Ejecutar DESPUÉS de copiar Ejemplos\audio\*.wav a C:\AutoRadio\audios\.
   Las señales de ejemplo son sintetizadas, no son programas de Radio Celendín. */
USE RadioCelendinAutoRadio;
GO
IF NOT EXISTS(SELECT 1 FROM dbo.Audio WHERE codigo='A0001')
    THROW 52001,'Faltan datos de demostracion. Ejecuta 03_datos_demo.sql.',1;
UPDATE dbo.Audio SET ruta=N'C:\AutoRadio\audios\musica_prueba.wav',formato='WAV',duracion_seg=9
 WHERE codigo='A0001';
UPDATE dbo.Audio SET ruta=N'C:\AutoRadio\audios\musica_prueba_2.wav',formato='WAV',duracion_seg=9 WHERE codigo='A0002';
UPDATE dbo.Audio SET ruta=N'C:\AutoRadio\audios\musica_prueba_3.wav',formato='WAV',duracion_seg=9 WHERE codigo='A0003';
UPDATE dbo.Audio SET ruta=N'C:\AutoRadio\audios\apertura_prueba.wav',formato='WAV',duracion_seg=4
 WHERE codigo='A0177';
UPDATE dbo.Audio SET ruta=N'C:\AutoRadio\audios\anuncio_prueba.wav',formato='WAV',duracion_seg=5
 WHERE codigo='A0141';
UPDATE dbo.Audio SET ruta=N'C:\AutoRadio\audios\anuncio_prueba.wav',formato='WAV',duracion_seg=5
 WHERE codigo='A0142';
IF NOT EXISTS(SELECT 1 FROM dbo.ListaReproduccion WHERE nombre=N'Demostración musical')
    INSERT dbo.ListaReproduccion(nombre) VALUES(N'Demostración musical');
DECLARE @lista INT=(SELECT lista_id FROM dbo.ListaReproduccion WHERE nombre=N'Demostración musical');
INSERT dbo.ListaDetalle(lista_id,codigo_audio,orden)
SELECT @lista,v.codigo,v.orden FROM (VALUES ('A0001',1),('A0002',2),('A0003',3)) v(codigo,orden)
WHERE NOT EXISTS(SELECT 1 FROM dbo.ListaDetalle d WHERE d.lista_id=@lista AND d.codigo_audio=v.codigo);
DECLARE @id VARCHAR(12)='T'+UPPER(LEFT(REPLACE(CONVERT(VARCHAR(36),NEWID()),'-',''),10));
INSERT dbo.Bloque(referencia,fecha_hora,codigo_cuna)
VALUES(@id,DATEADD(MINUTE,3,SYSDATETIME()),'A0177');
EXEC dbo.usp_ProgramarSpot @BloqueRef=@id,@CampanaCodigo='C01',@AudioCodigo='A0141',@Prioridad=1;
EXEC dbo.usp_ProgramarSpot @BloqueRef=@id,@CampanaCodigo='C02',@AudioCodigo='A0142',@Prioridad=2;
SELECT b.referencia,b.fecha_hora,a.titulo AS cuña
 FROM dbo.Bloque b JOIN dbo.Audio a ON a.codigo=b.codigo_cuna WHERE b.referencia=@id;
SELECT s.prioridad,a.titulo,s.estado FROM dbo.SpotProgramado s
 JOIN dbo.Audio a ON a.codigo=s.codigo_audio JOIN dbo.Bloque b ON b.bloque_id=s.bloque_id
 WHERE b.referencia=@id ORDER BY s.prioridad;
PRINT 'Bloque de prueba creado para dentro de 3 minutos.';
