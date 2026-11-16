/* Ejecutar después de 01_modelo.sql y 02_objetos.sql. No elimina datos existentes. */
USE RadioCelendinAutoRadio;
GO
IF OBJECT_ID('dbo.ListaReproduccion','U') IS NULL
CREATE TABLE dbo.ListaReproduccion (
    lista_id INT IDENTITY PRIMARY KEY,
    nombre NVARCHAR(120) NOT NULL UNIQUE,
    creada_en DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO
IF OBJECT_ID('dbo.ListaDetalle','U') IS NULL
CREATE TABLE dbo.ListaDetalle (
    lista_id INT NOT NULL REFERENCES dbo.ListaReproduccion(lista_id),
    codigo_audio VARCHAR(12) NOT NULL REFERENCES dbo.Audio(codigo),
    orden INT NOT NULL CHECK (orden > 0),
    CONSTRAINT PK_ListaDetalle PRIMARY KEY(lista_id,codigo_audio),
    CONSTRAINT UQ_ListaDetalle_Orden UNIQUE(lista_id,orden)
);
GO
IF OBJECT_ID('dbo.HistorialMusical','U') IS NULL
CREATE TABLE dbo.HistorialMusical (
    reproduccion_id BIGINT IDENTITY PRIMARY KEY,
    codigo_audio VARCHAR(12) NOT NULL REFERENCES dbo.Audio(codigo),
    artista NVARCHAR(100) NOT NULL,
    inicio DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    modo VARCHAR(8) NOT NULL CHECK (modo IN ('AUTO','MANUAL'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.HistorialMusical') AND name='IX_HistorialMusical_AudioInicio')
    CREATE INDEX IX_HistorialMusical_AudioInicio ON dbo.HistorialMusical(codigo_audio,inicio DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.HistorialMusical') AND name='IX_HistorialMusical_ArtistaInicio')
    CREATE INDEX IX_HistorialMusical_ArtistaInicio ON dbo.HistorialMusical(artista,inicio DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Bloque') AND name='IX_Bloque_FechaHora')
    CREATE INDEX IX_Bloque_FechaHora ON dbo.Bloque(fecha_hora);
GO
/* Acepta formatos adicionales decodificados por VLC (M4A y AAC). */
DECLARE @oldCk SYSNAME;
SELECT TOP (1) @oldCk=name FROM sys.check_constraints
 WHERE parent_object_id=OBJECT_ID('dbo.Audio') AND definition LIKE '%formato%';
IF @oldCk IS NOT NULL
    EXEC(N'ALTER TABLE dbo.Audio DROP CONSTRAINT ' + QUOTENAME(@oldCk));
ALTER TABLE dbo.Audio WITH CHECK ADD CONSTRAINT CK_Audio_Formato_AutoRadio
 CHECK (formato IN ('MP3','WAV','OGG','FLAC','M4A','AAC'));
PRINT 'Extensión AutoRadio: listas, historial e incorporación de formatos listos.';
GO
