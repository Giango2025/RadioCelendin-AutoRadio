-- REQUIERE: crear C:\AutoRadio\backups y permisos de escritura para el servicio SQL Server.
-- El ejemplo RESTAURA A OTRA BASE: jamás reemplazar la base de trabajo sin respaldo.
USE master;
GO
BACKUP DATABASE RadioCelendinAutoRadio
TO DISK=N'C:\AutoRadio\backups\AutoRadio_Full.bak'
WITH INIT, CHECKSUM, STATS=10;
GO
RESTORE VERIFYONLY FROM DISK=N'C:\AutoRadio\backups\AutoRadio_Full.bak' WITH CHECKSUM;
GO
RESTORE FILELISTONLY FROM DISK=N'C:\AutoRadio\backups\AutoRadio_Full.bak';
GO
/* IMPORTANTE: comprobar los nombres lógicos que devuelve FILELISTONLY antes de ejecutar lo siguiente.
   Comprobar también que C:\AutoRadio\datos exista, y que SQL Server tenga permisos.
   Si el resultado contiene otros nombres, reemplazar RadioCelendinAutoRadio / RadioCelendinAutoRadio_log. */
RESTORE DATABASE RadioCelendinAutoRadio_Restauracion
FROM DISK=N'C:\AutoRadio\backups\AutoRadio_Full.bak'
WITH MOVE N'RadioCelendinAutoRadio' TO N'C:\AutoRadio\datos\RadioCelendinAutoRadio_Restauracion.mdf',
MOVE N'RadioCelendinAutoRadio_log' TO N'C:\AutoRadio\datos\RadioCelendinAutoRadio_Restauracion_log.ldf',
RECOVERY, STATS=10;
GO
SELECT COUNT(*) AS audio_en_original FROM RadioCelendinAutoRadio.dbo.Audio;
SELECT COUNT(*) AS audio_en_restaura FROM RadioCelendinAutoRadio_Restauracion.dbo.Audio;
GO
