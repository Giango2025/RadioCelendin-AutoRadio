using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using LibVLCSharp.Shared;

namespace AutoRadio;

/// <summary>Motor de audio local. No reproduce simultáneamente la música y los anuncios.</summary>
public sealed class AudioEngine : IDisposable
{
    private readonly LibVLC _vlc;
    private readonly MediaPlayer _music;
    private readonly MediaPlayer _ad;
    private Media? _musicMedia;
    public string? CurrentSongCode { get; private set; }
    public event Action? SongFinished;
    public int Volume { get; set; } = 85;
    public bool MusicPlaying => _music.IsPlaying;
    public bool MusicPaused => _music.State == VLCState.Paused;
    public long MusicPositionMs => _music.Time;
    public long MusicLengthMs => _music.Length;

    public AudioEngine()
    {
        Core.Initialize();
        _vlc = new LibVLC("--no-video", "--quiet");
        _music = new MediaPlayer(_vlc);
        _ad = new MediaPlayer(_vlc);
        _music.EndReached += (_, _) => SongFinished?.Invoke();
    }

    public void PlayMusic(AudioTrack item)
    {
        EnsureAudio(item.Path);
        _music.Stop();
        _musicMedia?.Dispose();
        _musicMedia = new Media(_vlc, new Uri(Path.GetFullPath(item.Path)));
        _music.Media = _musicMedia;
        _music.Volume = Volume;
        if (!_music.Play()) throw new IOException("El reproductor no pudo iniciar la canción: " + item.Path);
        CurrentSongCode = item.Code;
    }
    public void TogglePause()
    {
        if (_music.IsPlaying) _music.SetPause(true);
        else if (MusicPaused) _music.SetPause(false);
    }
    public void StopMusic()
    {
        CurrentSongCode = null;
        _music.Stop();
    }
    public void StopAdvertising() => _ad.Stop();

    public async Task<bool> PauseForAdvertisingAsync(int fadeMs, CancellationToken ct)
    {
        if (!_music.IsPlaying) return false;
        var steps = Math.Max(1, fadeMs / 80);
        for (var i = steps; i >= 0; i--)
        {
            ct.ThrowIfCancellationRequested();
            _music.Volume = Volume * i / steps;
            await Task.Delay(Math.Max(1, fadeMs / steps), ct);
        }
        _music.SetPause(true);
        return true;
    }
    public async Task ResumeAfterAdvertisingAsync(int fadeMs)
    {
        if (!MusicPaused) return;
        _music.Volume = 0;
        _music.SetPause(false);
        var steps = Math.Max(1, fadeMs / 80);
        for (var i = 0; i <= steps; i++)
        {
            _music.Volume = Volume * i / steps;
            await Task.Delay(Math.Max(1, fadeMs / steps));
        }
        _music.Volume = Volume;
    }

    public async Task PlayAdvertisementAsync(string path, int durationSec, CancellationToken ct)
    {
        EnsureAudio(path);
        _ad.Stop();
        using var media = new Media(_vlc, new Uri(Path.GetFullPath(path)));
        _ad.Media = media;
        _ad.Volume = Volume;
        var completion = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        void OnFinished(object? _, EventArgs __) => completion.TrySetResult(true);
        void OnError(object? _, EventArgs __) => completion.TrySetException(new IOException("Error del decodificador de audio."));
        _ad.EndReached += OnFinished;
        _ad.EncounteredError += OnError;
        try
        {
            if (!_ad.Play()) throw new IOException("El reproductor rechazó el archivo: " + path);
            // La duración declarada se usa solo como límite de seguridad para detectar bloqueos.
            await completion.Task.WaitAsync(TimeSpan.FromSeconds(Math.Clamp(durationSec * 3 + 60, 120, 10860)), ct);
        }
        finally
        {
            _ad.EndReached -= OnFinished;
            _ad.EncounteredError -= OnError;
            _ad.Stop();
            _ad.Media = null;
        }
    }
    public static void EnsureAudio(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
            throw new FileNotFoundException("No se encuentra el archivo. Revisa la ruta de la biblioteca: " + path, path);
        var ext = Path.GetExtension(path).ToLowerInvariant();
        if (ext is not (".mp3" or ".wav" or ".ogg" or ".flac" or ".m4a" or ".aac"))
            throw new NotSupportedException("Formato no permitido por el catálogo: " + ext);
    }
    public void Dispose()
    {
        _ad.Stop(); _music.Stop();
        _musicMedia?.Dispose();
        _ad.Dispose(); _music.Dispose(); _vlc.Dispose();
    }
}
