/* Radio Celendín AutoRadio - modelo OLTP. SQL Server 2019+; solo para demostración académica. */
USE master;
GO
IF DB_ID(N'RadioCelendinAutoRadio') IS NULL CREATE DATABASE RadioCelendinAutoRadio;
GO
USE RadioCelendinAutoRadio;
GO
IF OBJECT_ID('dbo.Audio','U') IS NULL
CREATE TABLE dbo.Audio(
 codigo VARCHAR(12) NOT NULL PRIMARY KEY,
 titulo NVARCHAR(140) NOT NULL,
 artista NVARCHAR(100) NOT NULL,
 genero NVARCHAR(50) NOT NULL,
 tipo VARCHAR(10) NOT NULL CHECK (tipo IN ('MUSICA','ANUNCIO','CUNA')),
 duracion_seg INT NOT NULL CHECK (duracion_seg BETWEEN 1 AND 10800),
 formato VARCHAR(8) NOT NULL CHECK (formato IN ('MP3','WAV','FLAC','OGG')),
 ruta NVARCHAR(255) NOT NULL,
 creado_en DATETIME2(0) NOT NULL CONSTRAINT DF_Audio_Creado DEFAULT SYSDATETIME(),
 CONSTRAINT CK_Audio_Titulo CHECK (LEN(LTRIM(RTRIM(titulo)))>0),
 CONSTRAINT CK_Audio_Ruta CHECK (LEN(LTRIM(RTRIM(ruta)))>0)
);
GO
IF OBJECT_ID('dbo.Cliente','U') IS NULL
CREATE TABLE dbo.Cliente(cliente_id INT IDENTITY PRIMARY KEY,nombre NVARCHAR(120) NOT NULL UNIQUE);
GO
IF OBJECT_ID('dbo.Campana','U') IS NULL
CREATE TABLE dbo.Campana(
 campana_id INT IDENTITY PRIMARY KEY,codigo VARCHAR(12) NOT NULL UNIQUE,
 cliente_id INT NOT NULL REFERENCES dbo.Cliente(cliente_id),nombre NVARCHAR(120) NOT NULL,
 fecha_inicio DATE NOT NULL,fecha_fin DATE NOT NULL,
 CONSTRAINT CK_Campana_Fechas CHECK (fecha_inicio<=fecha_fin));
GO
IF OBJECT_ID('dbo.Bloque','U') IS NULL
CREATE TABLE dbo.Bloque(
 bloque_id INT IDENTITY PRIMARY KEY,referencia VARCHAR(12) NOT NULL UNIQUE,
 fecha_hora DATETIME2(0) NOT NULL, codigo_cuna VARCHAR(12) NOT NULL DEFAULT 'A0177'
 REFERENCES dbo.Audio(codigo),
 creado_en DATETIME2(0) NOT NULL DEFAULT SYSDATETIME());
GO
IF OBJECT_ID('dbo.SpotProgramado','U') IS NULL
CREATE TABLE dbo.SpotProgramado(
 programacion_id INT IDENTITY PRIMARY KEY,
 bloque_id INT NOT NULL REFERENCES dbo.Bloque(bloque_id),
 campana_id INT NOT NULL REFERENCES dbo.Campana(campana_id),
 codigo_audio VARCHAR(12) NOT NULL REFERENCES dbo.Audio(codigo),
 prioridad TINYINT NOT NULL CHECK (prioridad BETWEEN 1 AND 99),
 estado VARCHAR(12) NOT NULL CHECK (estado IN ('EMITIDA','OMITIDA','PENDIENTE')),
 emision_real DATETIME2(0) NULL,
 CONSTRAINT UQ_BloqueAudio UNIQUE(bloque_id,codigo_audio));
GO
IF OBJECT_ID('dbo.Auditoria','U') IS NULL
CREATE TABLE dbo.Auditoria(
 auditoria_id BIGINT IDENTITY PRIMARY KEY,
 tabla SYSNAME NOT NULL, registro_id INT NOT NULL,
 operacion VARCHAR(10) NOT NULL, valor_anterior NVARCHAR(600) NULL,
 valor_nuevo NVARCHAR(600) NULL, usuario_bd SYSNAME NOT NULL DEFAULT ORIGINAL_LOGIN(),
 fecha_hora DATETIME2(3) NOT NULL DEFAULT SYSDATETIME());
GO
IF OBJECT_ID('dbo.StgAudio','U') IS NULL
CREATE TABLE dbo.StgAudio(
 fila_id INT IDENTITY PRIMARY KEY,lote_id INT NOT NULL,
 codigo NVARCHAR(30) NULL,titulo NVARCHAR(140) NULL,artista NVARCHAR(100) NULL,
 genero NVARCHAR(50) NULL,tipo NVARCHAR(30) NULL,duracion_seg NVARCHAR(30) NULL,
 formato NVARCHAR(20) NULL,ruta NVARCHAR(255) NULL);
GO
IF OBJECT_ID('dbo.StgAgenda','U') IS NULL
CREATE TABLE dbo.StgAgenda(
 fila_id INT IDENTITY PRIMARY KEY,lote_id INT NOT NULL,
 bloque_ref NVARCHAR(30),fecha_hora NVARCHAR(30),codigo_campana NVARCHAR(30),
 codigo_audio NVARCHAR(30),prioridad NVARCHAR(20),estado NVARCHAR(30),emision_real NVARCHAR(30));
GO
IF OBJECT_ID('dbo.Rechazo','U') IS NULL
CREATE TABLE dbo.Rechazo(
 rechazo_id BIGINT IDENTITY PRIMARY KEY,lote_id INT NOT NULL,fuente VARCHAR(20) NOT NULL,
 fila_id INT NOT NULL,motivo NVARCHAR(150) NOT NULL,fecha_hora DATETIME2(0) DEFAULT SYSDATETIME(),
 CONSTRAINT UQ_Rechazo UNIQUE(lote_id,fuente,fila_id));
GO
IF OBJECT_ID('dbo.IncidenciaArchivo','U') IS NULL
CREATE TABLE dbo.IncidenciaArchivo(
 incidencia_id INT IDENTITY PRIMARY KEY,codigo_audio VARCHAR(12) NULL REFERENCES dbo.Audio(codigo),
 mensaje NVARCHAR(400) NOT NULL,fecha_hora DATETIME2(0) NOT NULL DEFAULT SYSDATETIME());
GO
