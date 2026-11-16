using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using Microsoft.Data.SqlClient;

namespace AutoRadio;
public sealed record AudioTrack(string Code, string Title, string Artist, string Genre,
    string Type, string Format, string Path, int Duration)
{
    public override string ToString() => $"{Title} — {Artist} ({Code})";
}
public sealed record Block(int Id, string Reference, DateTime When, string IntroCode, string IntroPath)
{
    public override string ToString() => $"{When:dd/MM/yyyy HH:mm} — {Reference}";
}
public sealed record Spot(int Id, string Code, string Title, string Path, int Duration, int Priority);

public sealed class RadioRepository
{
    private readonly Func<string> _connection;
    public RadioRepository(Func<string> connection) => _connection = connection;
    private SqlConnection Open()
    {
        var cn = new SqlConnection(_connection());
        cn.Open();
        return cn;
    }
    private static SqlParameter P(string key, object? value) => new(key, value ?? DBNull.Value);
    private static string NewCode(string prefix) => prefix + Guid.NewGuid().ToString("N")[..10].ToUpperInvariant();

    public void CheckConnection()
    {
        using var cn = Open();
        using var cmd = new SqlCommand("SELECT COUNT(*) FROM dbo.Audio", cn);
        _ = cmd.ExecuteScalar();
    }
    public DataTable Table(string sql, params SqlParameter[] ps)
    {
        using var cn = Open();
        using var cmd = new SqlCommand(sql, cn) { CommandTimeout = 25 };
        cmd.Parameters.AddRange(ps);
        using var adapter = new SqlDataAdapter(cmd);
        var dt = new DataTable(); adapter.Fill(dt); return dt;
    }
    public int Execute(string sql, params SqlParameter[] ps)
    {
        using var cn = Open();
        using var cmd = new SqlCommand(sql, cn) { CommandTimeout = 25 };
        cmd.Parameters.AddRange(ps);
        return cmd.ExecuteNonQuery();
    }
    public object? Scalar(string sql, params SqlParameter[] ps)
    {
        using var cn = Open();
        using var cmd = new SqlCommand(sql, cn) { CommandTimeout = 25 };
        cmd.Parameters.AddRange(ps);
        return cmd.ExecuteScalar();
    }

    public DataTable Audios(string? term = null, string? type = null) => Table(@"
        SELECT codigo,titulo,artista,genero,tipo,formato,duracion_seg,ruta
        FROM dbo.Audio WHERE (@term='' OR titulo LIKE @q OR artista LIKE @q OR genero LIKE @q)
          AND (@tipo='' OR tipo=@tipo) ORDER BY tipo,titulo",
        P("@term", term ?? ""), P("@q", "%" + (term ?? "") + "%"), P("@tipo", type ?? ""));

    public AudioTrack? Track(string code)
    {
        var d = Table("SELECT codigo,titulo,artista,genero,tipo,formato,duracion_seg,ruta FROM dbo.Audio WHERE codigo=@code", P("@code", code));
        return d.Rows.Count == 0 ? null : ToTrack(d.Rows[0]);
    }
    private static AudioTrack ToTrack(DataRow r) => new(
        (string)r["codigo"], (string)r["titulo"], (string)r["artista"], (string)r["genero"],
        (string)r["tipo"], (string)r["formato"], (string)r["ruta"], Convert.ToInt32(r["duracion_seg"]));

    public void SaveAudio(AudioTrack a, bool update)
    {
        if (string.IsNullOrWhiteSpace(a.Title) || string.IsNullOrWhiteSpace(a.Path) || a.Duration <= 0)
            throw new ArgumentException("Título, ruta y duración positiva son obligatorios.");
        var sql = update
            ? @"UPDATE dbo.Audio SET titulo=@titulo,artista=@artista,genero=@genero,tipo=@tipo,
                formato=@formato,duracion_seg=@duracion,ruta=@ruta WHERE codigo=@codigo"
            : @"INSERT dbo.Audio(codigo,titulo,artista,genero,tipo,formato,duracion_seg,ruta)
                VALUES(@codigo,@titulo,@artista,@genero,@tipo,@formato,@duracion,@ruta)";
        Execute(sql, P("@codigo", a.Code), P("@titulo", a.Title.Trim()), P("@artista", a.Artist.Trim()),
            P("@genero", a.Genre.Trim()), P("@tipo", a.Type), P("@formato", a.Format),
            P("@duracion", a.Duration), P("@ruta", a.Path.Trim()));
    }
    public AudioTrack NewAudio(string title, string artist, string genre, string type, string format, string path, int secs)
        => new(NewCode("U"), title, artist, genre, type, format, path, secs);
    public void DeleteAudio(string code) => Execute("DELETE dbo.Audio WHERE codigo=@id", P("@id", code));

    public DataTable Clients() => Table("SELECT cliente_id,nombre FROM dbo.Cliente ORDER BY nombre");
    public void AddClient(string name)
    {
        if (string.IsNullOrWhiteSpace(name)) throw new ArgumentException("Escribe el nombre del cliente.");
        Execute("INSERT dbo.Cliente(nombre) VALUES(@n)", P("@n", name.Trim()));
    }
    public DataTable Campaigns() => Table(@"SELECT c.campana_id,c.codigo,c.nombre AS campana,cl.nombre AS cliente,
           c.fecha_inicio,c.fecha_fin FROM dbo.Campana c JOIN dbo.Cliente cl ON c.cliente_id=cl.cliente_id ORDER BY c.fecha_fin DESC");
    public void AddCampaign(int client, string title, DateTime start, DateTime end)
    {
        if (start.Date > end.Date) throw new ArgumentException("La fecha final debe ser posterior a la inicial.");
        if (string.IsNullOrWhiteSpace(title)) throw new ArgumentException("Escribe el nombre de la campaña.");
        Execute("INSERT dbo.Campana(codigo,cliente_id,nombre,fecha_inicio,fecha_fin) VALUES(@code,@c,@n,@a,@b)",
            P("@code", NewCode("C")), P("@c", client), P("@n", title.Trim()), P("@a", start.Date), P("@b", end.Date));
    }

    public DataTable Blocks(DateTime from, DateTime until) => Table(@"
        SELECT b.bloque_id,b.referencia,b.fecha_hora,b.codigo_cuna,a.titulo AS cuna,
          (SELECT COUNT(*) FROM dbo.SpotProgramado s WHERE s.bloque_id=b.bloque_id) AS anuncios,
          (SELECT COUNT(*) FROM dbo.SpotProgramado s WHERE s.bloque_id=b.bloque_id AND s.estado='PENDIENTE') AS pendientes
        FROM dbo.Bloque b JOIN dbo.Audio a ON a.codigo=b.codigo_cuna
        WHERE b.fecha_hora>=@from AND b.fecha_hora<@until ORDER BY b.fecha_hora",
        P("@from", from), P("@until", until));
    public void AddBlock(DateTime when, string introCode)
    {
        if (when < DateTime.Now.AddSeconds(-30)) throw new ArgumentException("No programes un bloque en el pasado.");
        if (Track(introCode)?.Type != "CUNA") throw new ArgumentException("El audio de apertura debe ser una CUÑA.");
        Execute("INSERT dbo.Bloque(referencia,fecha_hora,codigo_cuna) VALUES(@ref,@time,@intro)",
            P("@ref", NewCode("B")), P("@time", when), P("@intro", introCode));
    }
    public DataTable BlockSpots(int blockId) => Table(@"
        SELECT s.programacion_id,s.prioridad,s.estado,s.codigo_audio,a.titulo,a.duracion_seg,
               c.codigo AS codigo_campana,c.nombre AS campana,cl.nombre AS cliente
        FROM dbo.SpotProgramado s JOIN dbo.Audio a ON s.codigo_audio=a.codigo
             JOIN dbo.Campana c ON s.campana_id=c.campana_id
             JOIN dbo.Cliente cl ON c.cliente_id=cl.cliente_id
        WHERE s.bloque_id=@id ORDER BY s.prioridad,s.programacion_id", P("@id", blockId));
    public void AddSpot(int blockId, string campaignCode, string audioCode, int priority)
    {
        var reference = Scalar("SELECT referencia FROM dbo.Bloque WHERE bloque_id=@id", P("@id", blockId))?.ToString();
        if (reference is null) throw new ArgumentException("No se encontró el bloque.");
        using var cn = Open();
        using var cmd = new SqlCommand("dbo.usp_ProgramarSpot", cn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddRange(new[] { P("@BloqueRef", reference), P("@CampanaCodigo", campaignCode),
            P("@AudioCodigo", audioCode), P("@Prioridad", priority) });
        cmd.ExecuteNonQuery();
    }
    public Block? DueBlock()
    {
        var d = Table(@"SELECT TOP (1) b.bloque_id,b.referencia,b.fecha_hora,b.codigo_cuna,a.ruta AS cuna_ruta
             FROM dbo.Bloque b JOIN dbo.Audio a ON a.codigo=b.codigo_cuna
             WHERE b.fecha_hora<=SYSDATETIME() AND EXISTS
             (SELECT 1 FROM dbo.SpotProgramado s WHERE s.bloque_id=b.bloque_id AND s.estado='PENDIENTE')
             ORDER BY b.fecha_hora,b.bloque_id");
        return d.Rows.Count == 0 ? null : ToBlock(d.Rows[0]);
    }
    public Block? GetBlock(int id)
    {
        var d = Table(@"SELECT b.bloque_id,b.referencia,b.fecha_hora,b.codigo_cuna,a.ruta AS cuna_ruta
             FROM dbo.Bloque b JOIN dbo.Audio a ON a.codigo=b.codigo_cuna WHERE b.bloque_id=@id", P("@id", id));
        return d.Rows.Count == 0 ? null : ToBlock(d.Rows[0]);
    }
    private static Block ToBlock(DataRow r) => new(Convert.ToInt32(r["bloque_id"]),
        (string)r["referencia"], Convert.ToDateTime(r["fecha_hora"]),
        (string)r["codigo_cuna"], (string)r["cuna_ruta"]);
    public List<Spot> PendingSpots(int id)
    {
        var dt = Table(@"SELECT s.programacion_id,s.codigo_audio,a.titulo,a.ruta,a.duracion_seg,s.prioridad
            FROM dbo.SpotProgramado s JOIN dbo.Audio a ON a.codigo=s.codigo_audio
            WHERE s.bloque_id=@id AND s.estado='PENDIENTE' ORDER BY s.prioridad,s.programacion_id", P("@id", id));
        return dt.Rows.Cast<DataRow>().Select(r=> new Spot(Convert.ToInt32(r["programacion_id"]),
            (string)r["codigo_audio"], (string)r["titulo"], (string)r["ruta"],
            Convert.ToInt32(r["duracion_seg"]), Convert.ToInt32(r["prioridad"]))).ToList();
    }
    public void CompleteSpot(int id, bool emitted)
    {
        var count = Execute(@"UPDATE dbo.SpotProgramado SET estado=@estado,
          emision_real=CASE WHEN @emitida=1 THEN SYSDATETIME() ELSE NULL END
          WHERE programacion_id=@id AND estado='PENDIENTE'",
          P("@id", id), P("@emitida", emitted ? 1 : 0), P("@estado", emitted ? "EMITIDA" : "OMITIDA"));
        if (count != 1) throw new InvalidOperationException("El anuncio cambió de estado durante la reproducción.");
    }

    public DataTable Playlists() => Table("SELECT lista_id,nombre,creada_en FROM dbo.ListaReproduccion ORDER BY nombre");
    public void CreatePlaylist(string name)
    {
        if (string.IsNullOrWhiteSpace(name)) throw new ArgumentException("Indica un nombre.");
        Execute("INSERT dbo.ListaReproduccion(nombre) VALUES(@n)", P("@n", name.Trim()));
    }
    public DataTable PlaylistSongs(int id) => Table(@"SELECT d.orden,a.codigo,a.titulo,a.artista,a.genero,a.duracion_seg
        FROM dbo.ListaDetalle d JOIN dbo.Audio a ON a.codigo=d.codigo_audio WHERE d.lista_id=@id ORDER BY d.orden", P("@id", id));
    public void AddToPlaylist(int listId, string code)
    {
        if (Track(code)?.Type != "MUSICA") throw new ArgumentException("Solo se admiten canciones en la lista.");
        Execute(@"INSERT dbo.ListaDetalle(lista_id,codigo_audio,orden)
            SELECT @id,@code,ISNULL(MAX(orden),0)+1 FROM dbo.ListaDetalle WHERE lista_id=@id",
            P("@id", listId), P("@code", code));
    }
    public void RemoveFromPlaylist(int listId, string code) => Execute(
        "DELETE dbo.ListaDetalle WHERE lista_id=@l AND codigo_audio=@a", P("@l", listId), P("@a", code));

    public AudioTrack? NextEligibleMusic(int? listId, int songRepeat, int artistRepeat)
    {
        // El historial se comprueba incluso si hay una lista activa; no se ignoran restricciones.
        var d = Table(@"SELECT TOP (1) a.codigo,a.titulo,a.artista,a.genero,a.tipo,a.formato,a.duracion_seg,a.ruta
          FROM dbo.Audio a WHERE a.tipo='MUSICA'
            AND (@lista IS NULL OR EXISTS(SELECT 1 FROM dbo.ListaDetalle x WHERE x.lista_id=@lista AND x.codigo_audio=a.codigo))
            AND (@song=0 OR NOT EXISTS(SELECT 1 FROM dbo.HistorialMusical h WHERE h.codigo_audio=a.codigo
                  AND h.inicio>=DATEADD(MINUTE,-@song,SYSDATETIME())))
            AND (@artist=0 OR NOT EXISTS(SELECT 1 FROM dbo.HistorialMusical h WHERE h.artista=a.artista
                  AND h.inicio>=DATEADD(MINUTE,-@artist,SYSDATETIME())))
          ORDER BY NEWID()", P("@lista", listId), P("@song", songRepeat), P("@artist", artistRepeat));
        return d.Rows.Count == 0 ? null : ToTrack(d.Rows[0]);
    }
    public void LogMusic(AudioTrack track, bool automatic) => Execute(@"
        INSERT dbo.HistorialMusical(codigo_audio,artista,modo,inicio) VALUES(@c,@a,@m,SYSDATETIME())",
        P("@c", track.Code), P("@a", track.Artist), P("@m", automatic ? "AUTO" : "MANUAL"));
    public void LogError(string? code, string message)
    {
        try { Execute("INSERT dbo.IncidenciaArchivo(codigo_audio,mensaje) VALUES(@c,@m)",
            P("@c", code), P("@m", message.Length>390 ? message[..390] : message)); }
        catch { /* El mensaje principal se muestra al operador aunque falle la auditoría secundaria. */ }
    }
    public DataTable MusicHistory() => Table(@"SELECT TOP (150) h.inicio,h.codigo_audio,a.titulo,h.artista,h.modo
        FROM dbo.HistorialMusical h JOIN dbo.Audio a ON h.codigo_audio=a.codigo ORDER BY h.inicio DESC");
    public DataTable AdHistory() => Table(@"SELECT TOP (150) s.programacion_id,b.fecha_hora AS programada,
        s.emision_real,s.estado,s.prioridad,a.titulo,c.nombre AS campana
        FROM dbo.SpotProgramado s JOIN dbo.Bloque b ON b.bloque_id=s.bloque_id
        JOIN dbo.Audio a ON a.codigo=s.codigo_audio JOIN dbo.Campana c ON c.campana_id=s.campana_id
        ORDER BY b.fecha_hora DESC,s.prioridad");
    public DataTable Incidents() => Table("SELECT TOP (150) fecha_hora,codigo_audio,mensaje FROM dbo.IncidenciaArchivo ORDER BY fecha_hora DESC");
    public DataTable Stats() => Table(@"SELECT
        (SELECT COUNT(*) FROM dbo.Audio WHERE tipo='MUSICA') AS Canciones,
        (SELECT COUNT(*) FROM dbo.Audio WHERE tipo='ANUNCIO') AS Anuncios,
        (SELECT COUNT(*) FROM dbo.Bloque WHERE fecha_hora>=DATEADD(day,-30,SYSDATETIME())) AS Bloques30d,
        (SELECT COUNT(*) FROM dbo.SpotProgramado WHERE estado='EMITIDA') AS Emitidos,
        (SELECT COUNT(*) FROM dbo.SpotProgramado WHERE estado='OMITIDA') AS Omitidos,
        (SELECT COUNT(*) FROM dbo.IncidenciaArchivo) AS Incidencias");
}
