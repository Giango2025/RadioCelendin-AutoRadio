using System;
using System.IO;
using System.Text.Json;

namespace AutoRadio;
public sealed class AppSettings
{
    public string ConnectionString { get; set; } = @"Server=localhost\SQLEXPRESS;Database=RadioCelendinAutoRadio;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;";
    public int SongRepeatMinutes { get; set; } = 120;
    public int ArtistRepeatMinutes { get; set; } = 30;
    public int FadeMilliseconds { get; set; } = 1600;
    public int Volume { get; set; } = 85;
    public int? ActivePlaylistId { get; set; }

    private static string Filename => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "AutoRadio", "ajustes.json");

    public static AppSettings Load()
    {
        try { return File.Exists(Filename)
            ? JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(Filename)) ?? new()
            : new(); }
        catch { return new(); }
    }

    public void Save()
    {
        // Seguridad: no se almacenan contraseñas SQL en el archivo de ajustes.
        if (ConnectionString.Contains("Password=", StringComparison.OrdinalIgnoreCase) ||
            ConnectionString.Contains("Pwd=", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Utiliza autenticación de Windows; no se guardan contraseñas SQL en texto plano.");
        SongRepeatMinutes = Math.Clamp(SongRepeatMinutes, 0, 129600); // hasta 90 días
        ArtistRepeatMinutes = Math.Clamp(ArtistRepeatMinutes, 0, 129600);
        FadeMilliseconds = Math.Clamp(FadeMilliseconds, 0, 10000);
        Volume = Math.Clamp(Volume, 0, 100);
        Directory.CreateDirectory(Path.GetDirectoryName(Filename)!);
        File.WriteAllText(Filename, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
    }
}
