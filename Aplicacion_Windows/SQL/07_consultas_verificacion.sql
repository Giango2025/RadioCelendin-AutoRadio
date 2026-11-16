/* CONSULTAS PARA DEMOSTRAR EL SISTEMA EN SSMS */
USE RadioCelendinAutoRadio;
GO
-- 1. Tabla de audios y formatos registrados.
SELECT tipo,formato,COUNT(*) AS total FROM dbo.Audio GROUP BY tipo,formato ORDER BY tipo,formato;
-- 2. Música disponible con archivo local asignado.
SELECT TOP (30) codigo,titulo,artista,formato,ruta FROM dbo.Audio WHERE tipo='MUSICA' ORDER BY titulo;
-- 3. Agenda publicitaria completa y prioridad.
SELECT b.fecha_hora,b.referencia,s.prioridad,a.titulo AS spot,c.nombre AS campana,
       s.estado,s.emision_real
FROM dbo.Bloque b JOIN dbo.SpotProgramado s ON s.bloque_id=b.bloque_id
JOIN dbo.Audio a ON a.codigo=s.codigo_audio
JOIN dbo.Campana c ON c.campana_id=s.campana_id
ORDER BY b.fecha_hora DESC,s.prioridad;
-- 4. Historial automático/manual de canciones.
SELECT TOP(40) h.inicio,h.modo,a.titulo,h.artista FROM dbo.HistorialMusical h
JOIN dbo.Audio a ON a.codigo=h.codigo_audio ORDER BY h.inicio DESC;
-- 5. Auditoría de modificaciones publicitarias.
SELECT TOP(50) fecha_hora,usuario_bd,tabla,operacion,registro_id,valor_anterior,valor_nuevo
FROM dbo.Auditoria ORDER BY fecha_hora DESC;
-- 6. Mensajes por archivos ausentes / ilegibles.
SELECT TOP(50) fecha_hora,codigo_audio,mensaje FROM dbo.IncidenciaArchivo ORDER BY fecha_hora DESC;
-- 7. Duración de cada bloque de anuncios (sin cuña).
SELECT TOP(20) b.referencia,b.fecha_hora,dbo.fn_DuracionBloque(b.bloque_id) AS segundos_spots
FROM dbo.Bloque b ORDER BY b.fecha_hora DESC;
GO
