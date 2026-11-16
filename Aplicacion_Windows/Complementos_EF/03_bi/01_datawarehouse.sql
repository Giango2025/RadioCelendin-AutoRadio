USE master;
GO
IF DB_ID('RadioCelendinDW') IS NULL CREATE DATABASE RadioCelendinDW;
GO
USE RadioCelendinDW;
GO
IF OBJECT_ID('dbo.DimFecha','U') IS NULL
CREATE TABLE dbo.DimFecha(fecha_key INT PRIMARY KEY,fecha DATE NOT NULL UNIQUE,anio SMALLINT,mes TINYINT,dia TINYINT);
GO
IF OBJECT_ID('dbo.DimCliente','U') IS NULL
CREATE TABLE dbo.DimCliente(cliente_key INT IDENTITY PRIMARY KEY,cliente_id_origen INT NOT NULL UNIQUE,nombre NVARCHAR(120) NOT NULL);
GO
IF OBJECT_ID('dbo.DimCampana','U') IS NULL
CREATE TABLE dbo.DimCampana(campana_key INT IDENTITY PRIMARY KEY,campana_id_origen INT NOT NULL UNIQUE,codigo VARCHAR(12),nombre NVARCHAR(120));
GO
IF OBJECT_ID('dbo.DimAudio','U') IS NULL
CREATE TABLE dbo.DimAudio(audio_key INT IDENTITY PRIMARY KEY,codigo_audio VARCHAR(12) NOT NULL UNIQUE,titulo NVARCHAR(140),formato VARCHAR(8),duracion_seg INT);
GO
IF OBJECT_ID('dbo.FactEmision','U') IS NULL
CREATE TABLE dbo.FactEmision(
 fact_key BIGINT IDENTITY PRIMARY KEY,programacion_id_origen INT NOT NULL UNIQUE,
 fecha_key INT NOT NULL REFERENCES dbo.DimFecha(fecha_key),
 cliente_key INT NOT NULL REFERENCES dbo.DimCliente(cliente_key),
 campana_key INT NOT NULL REFERENCES dbo.DimCampana(campana_key),
 audio_key INT NOT NULL REFERENCES dbo.DimAudio(audio_key),
 programados INT NOT NULL DEFAULT 1,emitidos INT NOT NULL,
 omitidos INT NOT NULL,atraso_seg INT NULL,
 duracion_seg INT NOT NULL);
GO
