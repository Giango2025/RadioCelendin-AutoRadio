USE RadioCelendinDW;
GO
-- KPI 1: cumplimiento de spots programados (%); KPI 2: omisión (%); KPI 3: retraso medio (s).
SELECT COUNT(*) AS total_programados,SUM(emitidos) AS total_emitidos,SUM(omitidos) AS total_omitidos,
 CAST(100.0*SUM(emitidos)/NULLIF(SUM(programados),0) AS DECIMAL(6,2)) AS cumplimiento_pct,
 CAST(100.0*SUM(omitidos)/NULLIF(SUM(programados),0) AS DECIMAL(6,2)) AS omision_pct,
 CAST(AVG(CAST(atraso_seg AS FLOAT)) AS DECIMAL(8,2)) AS atraso_medio_seg
FROM dbo.FactEmision;
GO
-- Roll-up mensual.
SELECT f.anio,f.mes,SUM(e.programados) programados,SUM(e.emitidos) emitidos
FROM dbo.FactEmision e JOIN dbo.DimFecha f ON f.fecha_key=e.fecha_key
GROUP BY f.anio,f.mes ORDER BY f.anio,f.mes;
GO
-- Drill-down por día y campaña.
SELECT f.fecha,c.nombre,SUM(e.programados) programados,SUM(e.emitidos) emitidos
FROM dbo.FactEmision e JOIN dbo.DimFecha f ON f.fecha_key=e.fecha_key
JOIN dbo.DimCampana c ON c.campana_key=e.campana_key
GROUP BY f.fecha,c.nombre ORDER BY f.fecha,c.nombre;
GO
-- Misma agregación para comparación Spark (ambos agrupan por campaña).
SELECT c.codigo,SUM(e.emitidos) emitidos,COUNT(*) spots
FROM dbo.FactEmision e JOIN dbo.DimCampana c ON c.campana_key=e.campana_key
GROUP BY c.codigo ORDER BY c.codigo;
GO
