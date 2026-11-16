USE RadioCelendinAutoRadio;
GO
-- Medir con 'Incluir plan de ejecución real' (Ctrl+M) y registrar resultados a mano.
IF EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Bloque_FechaHora' AND object_id=OBJECT_ID('dbo.Bloque'))
 DROP INDEX IX_Bloque_FechaHora ON dbo.Bloque;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT b.fecha_hora,s.estado,s.codigo_audio FROM dbo.Bloque b
JOIN dbo.SpotProgramado s ON s.bloque_id=b.bloque_id
WHERE b.fecha_hora BETWEEN '2026-11-08T00:00:00' AND '2026-11-09T00:00:00';
GO
CREATE INDEX IX_Bloque_FechaHora ON dbo.Bloque(fecha_hora) INCLUDE(referencia);
GO
SELECT b.fecha_hora,s.estado,s.codigo_audio FROM dbo.Bloque b
JOIN dbo.SpotProgramado s ON s.bloque_id=b.bloque_id
WHERE b.fecha_hora BETWEEN '2026-11-08T00:00:00' AND '2026-11-09T00:00:00';
GO
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
-- Advertencia: con pocos datos SQL Server puede continuar usando scans y no ganar tiempo.
