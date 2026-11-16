using System;
using System.Data;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace AutoRadio;
public sealed class MainForm : Form
{
    private readonly AppSettings _config=AppSettings.Load();
    private readonly RadioRepository _db;
    private AudioEngine? _audio;
    private readonly System.Windows.Forms.Timer _clock=new(){Interval=1000};
    private readonly TabControl _tabs=new(){Dock=DockStyle.Fill};
    private readonly ToolStripStatusLabel _statusText=new("Listo. Conecta SQL Server para comenzar.");
    private readonly Label _nowPlaying=new() { Text="EN EMISIÓN: —", Dock=DockStyle.Top,
        TextAlign=ContentAlignment.MiddleLeft,Height=46,Font=new Font("Segoe UI",13,FontStyle.Bold),Padding=new Padding(12,0,0,0) };
    private readonly DataGridView _playerSongs=Ui.Grid(),_playerBlocks=Ui.Grid(),_audioGrid=Ui.Grid();
    private readonly DataGridView _clientGrid=Ui.Grid(),_campaignGrid=Ui.Grid();
    private readonly DataGridView _scheduleGrid=Ui.Grid(),_spotGrid=Ui.Grid();
    private readonly DataGridView _listGrid=Ui.Grid(),_listSongs=Ui.Grid();
    private readonly DataGridView _historyMusic=Ui.Grid(),_historyAds=Ui.Grid(),_incidents=Ui.Grid();
    private readonly TextBox _search=Ui.Text();
    private readonly TextBox _connection=Ui.Text();
    private readonly Button _autoButton;
    private readonly NumericUpDown _songMinutes,_artistMinutes,_fadeMs;
    private readonly TrackBar _volume=new(){Minimum=0,Maximum=100,TickFrequency=10,Width=260};
    private readonly DateTimePicker _scheduleFilter=Ui.Date();
    private readonly DateTimePicker _radioDay=Ui.Date();
    private readonly Label _mode=new(){AutoSize=true,Text="MANUAL",Font=new Font("Segoe UI",10,FontStyle.Bold)};
    private bool _connected,_auto,_busy,_tickRunning,_songFinished;
    private readonly System.Collections.Generic.Dictionary<int,DateTime> _failedBlocks=new();
    private CancellationTokenSource? _adCancellation;

    public MainForm()
    {
        _db=new RadioRepository(()=>_config.ConnectionString);
        _autoButton=Ui.Button("Automático: APAGADO",ToggleAuto,195);
        _connection.Width=700;_connection.Text=_config.ConnectionString;
        _songMinutes=Ui.Number(_config.SongRepeatMinutes,0,129600);
        _artistMinutes=Ui.Number(_config.ArtistRepeatMinutes,0,129600);
        _fadeMs=Ui.Number(_config.FadeMilliseconds,0,10000);
        _volume.Value=Math.Clamp(_config.Volume,0,100);
        Text="RADIO CELENDÍN — AutoRadio 1.0 | Programación y automatización";
        MinimumSize=new Size(1100,710);Size=new Size(1350,840);StartPosition=FormStartPosition.CenterScreen;
        Font=new Font("Segoe UI",9);
        var status=new StatusStrip();status.Items.Add(_statusText);
        var top=new Panel { Dock=DockStyle.Top,Height=78,BackColor=Color.FromArgb(238,241,245) };
        var heading=new Label { Text="AutoRadio · Radio Celendín",Dock=DockStyle.Top,Height=30,
            Padding=new Padding(12,3,0,0),Font=new Font("Segoe UI",14,FontStyle.Bold) };
        top.Controls.Add(_nowPlaying);top.Controls.Add(heading);
        Controls.Add(_tabs);Controls.Add(top);Controls.Add(status);
        BuildEmission();BuildLibrary();BuildSchedule();BuildCampaigns();BuildPlaylists();BuildHistory();BuildSettings();
        _clock.Tick+=async (_,_)=>await TickAsync();_clock.Start();
        FormClosing+=(_,_)=>{_clock.Stop();_adCancellation?.Cancel();_audio?.Dispose();};
        Shown+=(_,_)=>ConnectIfPossible();
    }
    private TabPage Tab(string caption,Control control)
    {
        var tab=new TabPage(caption);tab.Controls.Add(control);_tabs.TabPages.Add(tab);return tab;
    }
    private void Report(string message) { _statusText.Text=$"{DateTime.Now:HH:mm:ss} · {message}"; }
    private void Error(Exception ex,string operation="Operación")
    {
        Report(operation+": "+ex.Message);
        MessageBox.Show(this,ex.Message,operation,MessageBoxButtons.OK,MessageBoxIcon.Warning);
    }
    private void Safe(Action a,string title="Operación") { try { a(); } catch(Exception ex) { Error(ex,title); } }
    private void ConnectIfPossible()
    {
        try { _db.CheckConnection();_connected=true;Report("Conectado a SQL Server.");RefreshAll(); }
        catch(Exception ex)
        { _connected=false;Report("Sin conexión. Abre Ajustes para indicar tu instancia SQL.");
          MessageBox.Show(this,"No se pudo conectar: "+ex.Message+"\n\nAbre Ajustes y comprueba el servidor, la base y la extensión 05.",
          "Configura SQL Server",MessageBoxButtons.OK,MessageBoxIcon.Information);_tabs.SelectedIndex=6; }
    }
    private void RefreshAll()
    {
        if(!_connected)return;
        Safe(()=>{LoadAudio();LoadRadio();LoadSchedule();LoadClients();LoadPlaylists();LoadHistory();},"Actualizar datos");
    }

    private void BuildEmission()
    {
        var split=new SplitContainer { Dock=DockStyle.Fill,SplitterDistance=625,Panel1MinSize=350,Panel2MinSize=300 };
        var songLabel=new Label { Text="BIBLIOTECA MUSICAL — selecciona una canción",Dock=DockStyle.Top,Height=26,Font=new Font("Segoe UI",9,FontStyle.Bold) };
        var songBar=Ui.Bar(Ui.Button("▶ Música",()=>PlaySelected(),128),Ui.Button("⏯ Pausar / seguir",()=>Safe(()=>_audio?.TogglePause()),143),
            Ui.Button("⏭ Siguiente",()=>Safe(()=>{_audio?.StopMusic();_songFinished=true;}),128));
        split.Panel1.Controls.Add(Ui.Page(_playerSongs,songLabel,songBar));
        var blockLabel=new Label { Text="BLOQUES PUBLICITARIOS — apertura + anuncios",Dock=DockStyle.Top,Height=26,Font=new Font("Segoe UI",9,FontStyle.Bold) };
        var buttonBar=Ui.Bar(_autoButton,Ui.Button("Emitir bloque",()=>_ = EmitSelectedBlockAsync(),145),
            Ui.Button("Detener anuncios",()=>_adCancellation?.Cancel(),155),_mode);
        split.Panel2.Controls.Add(Ui.Page(_playerBlocks,blockLabel,buttonBar));
        var refresh=Ui.Bar(Ui.Button("Actualizar biblioteca y horarios",RefreshAll,255),
            new Label { Text="Modo AUTO: reproduce música apta y emite los bloques pendientes al llegar su hora.",AutoSize=true,Padding=new Padding(5,10,0,0) });
        Tab("EN EMISIÓN",Ui.Page(split,refresh));
    }
    private void BuildLibrary()
    {
        _search.Width=265;_search.PlaceholderText="Título, artista o género";
        _search.TextChanged+=(_,_)=>{if(_connected)Safe(LoadAudio);};
        var bar=Ui.Bar(_search,Ui.Button("Buscar / refrescar",()=>Safe(LoadAudio),160),
            Ui.Button("+ Añadir audio",AddAudio,135),Ui.Button("Editar",EditAudio,85),
            Ui.Button("Eliminar",DeleteAudio,90),Ui.Button("Importar archivos",ImportFiles,150));
        Tab("BIBLIOTECA",Ui.Page(_audioGrid,bar));
    }
    private void BuildSchedule()
    {
        var split=new SplitContainer { Dock=DockStyle.Fill,Orientation=Orientation.Horizontal,SplitterDistance=310,
            Panel1MinSize=200,Panel2MinSize=160 };
        var filterbar=Ui.Bar(new Label {Text="Fecha",Width=42,TextAlign=ContentAlignment.MiddleCenter},_scheduleFilter,
            Ui.Button("Ver día",LoadSchedule,94),Ui.Button("Ver próximos 30 días",()=>LoadSchedule(30),180),
            Ui.Button("+ Crear bloque",NewBlock,137));
        split.Panel1.Controls.Add(Ui.Page(_scheduleGrid,filterbar));
        var spotBar=Ui.Bar(Ui.Button("+ Agregar anuncio",AddSpot,150),
            Ui.Button("Actualizar anuncios",LoadSpots,159),
            new Label {Text="Prioridad 1 = primero; la cuña se emite antes de todos los anuncios.",AutoSize=true,Padding=new Padding(8,10,0,0)});
        split.Panel2.Controls.Add(Ui.Page(_spotGrid,spotBar));
        _scheduleGrid.SelectionChanged+=(_,_)=>{if(_connected)Safe(LoadSpots);};
        Tab("PROGRAMACIÓN",split);
    }
    private void BuildCampaigns()
    {
        var split=new SplitContainer { Dock=DockStyle.Fill,Orientation=Orientation.Horizontal,SplitterDistance=250 };
        split.Panel1.Controls.Add(Ui.Page(_clientGrid,Ui.Bar(Ui.Button("+ Nuevo cliente",NewClient,160))));
        split.Panel2.Controls.Add(Ui.Page(_campaignGrid,Ui.Bar(Ui.Button("+ Nueva campaña",NewCampaign,168),
            new Label {Text="Las fechas de la campaña deben cubrir la hora del bloque.",AutoSize=true,Padding=new Padding(10,10,0,0)})));
        Tab("PUBLICIDAD",split);
    }
    private void BuildPlaylists()
    {
        var split=new SplitContainer { Dock=DockStyle.Fill,SplitterDistance=380 };
        split.Panel1.Controls.Add(Ui.Page(_listGrid,Ui.Bar(Ui.Button("+ Crear lista",NewPlaylist,155),
            Ui.Button("Activar esta lista",ActivatePlaylist,160))));
        split.Panel2.Controls.Add(Ui.Page(_listSongs,Ui.Bar(Ui.Button("+ Añadir canción",AddSongToPlaylist,157),
            Ui.Button("Quitar canción",RemoveSongFromPlaylist,150))));
        _listGrid.SelectionChanged+=(_,_)=>{if(_connected)Safe(LoadPlaylistSongs);};
        Tab("LISTAS MUSICALES",split);
    }
    private void BuildHistory()
    {
        var tabs=new TabControl { Dock=DockStyle.Fill };
        foreach(var (caption,grid) in new[]{("Historial musical",_historyMusic),("Emisiones publicitarias",_historyAds),("Errores de archivos",_incidents)})
        {
            var page=new TabPage(caption);page.Controls.Add(grid);tabs.TabPages.Add(page);
        }
        Tab("REPORTES",Ui.Page(tabs,Ui.Bar(Ui.Button("Actualizar reportes",()=>Safe(LoadHistory),170),
            Ui.Button("Indicadores generales",ShowStats,185))));
    }
    private void BuildSettings()
    {
        var layout=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=2,RowCount=10,Padding=new Padding(24)};
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,260));layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
        void Line(int n,string label,Control c)
        {
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute,62));
            layout.Controls.Add(new Label{Text=label,TextAlign=ContentAlignment.MiddleLeft,Dock=DockStyle.Fill},0,n);
            c.Anchor=AnchorStyles.Left|AnchorStyles.Right;layout.Controls.Add(c,1,n);
        }
        Line(0,"Conexión SQL Server",_connection);
        Line(1,"No repetir canción (minutos)",_songMinutes);
        Line(2,"No repetir artista (minutos)",_artistMinutes);
        Line(3,"Atenuación gradual (ms)",_fadeMs);
        Line(4,"Volumen general",_volume);
        Line(5,"Fecha de prueba (filtro en radio)",_radioDay);
        var notes=new Label{Text="Los intervalos admiten de 0 a 129 600 minutos (90 días).\n"+
          "No se guardan contraseñas SQL; se recomienda la autenticación integrada de Windows.\n"+
          "Los cambios se aplican desde Guardar y conectar.",AutoSize=true};
        Line(6,"Importante",notes);
        var buttons=Ui.Bar(Ui.Button("Guardar y conectar",SaveSettings,195),
            Ui.Button("Probar conexión",()=>Safe(()=>{_config.ConnectionString=_connection.Text;_db.CheckConnection();Report("Conexión correcta.");},"Conexión"),165));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute,65));layout.Controls.Add(buttons,1,7);
        Tab("AJUSTES",layout);
    }

    private void LoadAudio()
    {
        var dt=_db.Audios(_search.Text);_audioGrid.DataSource=dt;
        _playerSongs.DataSource=_db.Audios(null,"MUSICA");
    }
    private void LoadRadio()
    {
        _playerBlocks.DataSource=_db.Blocks(DateTime.Today.AddDays(-1),DateTime.Today.AddDays(31));
        Report("Biblioteca y agenda actualizadas.");
    }
    private void LoadSchedule() => LoadSchedule(1);
    private void LoadSchedule(int days)
    {
        _scheduleGrid.DataSource=_db.Blocks(_scheduleFilter.Value.Date,_scheduleFilter.Value.Date.AddDays(days));
        LoadSpots();
    }
    private void LoadSpots()
    {
        var id=Ui.SelectedInt(_scheduleGrid,"bloque_id");
        _spotGrid.DataSource=id.HasValue ? _db.BlockSpots(id.Value) : null;
    }
    private void LoadClients()
    {
        _clientGrid.DataSource=_db.Clients();_campaignGrid.DataSource=_db.Campaigns();
    }
    private void LoadPlaylists()
    {
        _listGrid.DataSource=_db.Playlists();LoadPlaylistSongs();
    }
    private void LoadPlaylistSongs()
    {
        var id=Ui.SelectedInt(_listGrid,"lista_id");
        _listSongs.DataSource=id.HasValue?_db.PlaylistSongs(id.Value):null;
    }
    private void LoadHistory()
    {
        _historyMusic.DataSource=_db.MusicHistory();_historyAds.DataSource=_db.AdHistory();
        _incidents.DataSource=_db.Incidents();
    }

    private void AddAudio()=>EditAudioCore(null);
    private void EditAudio()
    {
        var code=Ui.SelectedString(_audioGrid,"codigo");
        if(code is not null)Safe(()=>EditAudioCore(_db.Track(code)),"Editar audio");
    }
    private void EditAudioCore(AudioTrack? selected)
    {
        var name=Ui.Text(selected?.Title??"");var artist=Ui.Text(selected?.Artist??"Radio Celendín");
        var genre=Ui.Text(selected?.Genre??"General");var kind=Ui.Combo("MUSICA","ANUNCIO","CUNA");
        var format=Ui.Combo("MP3","WAV","FLAC","OGG","M4A","AAC");
        if(selected is not null) {kind.SelectedItem=selected.Type;format.SelectedItem=selected.Format;}
        var duration=Ui.Number(selected?.Duration??30,1,10800);
        var path=Ui.Text(selected?.Path??"");
        var browse=Ui.Button("Examinar audio...",()=>
        {
            using var ofd=new OpenFileDialog { Filter="Audio|*.mp3;*.wav;*.ogg;*.flac;*.m4a;*.aac|Todos|*.*" };
            if(ofd.ShowDialog(this)==DialogResult.OK) {path.Text=ofd.FileName;format.SelectedItem=Path.GetExtension(ofd.FileName).TrimStart('.').ToUpperInvariant();
                if(string.IsNullOrWhiteSpace(name.Text))name.Text=Path.GetFileNameWithoutExtension(ofd.FileName);}
        },160);
        if(!Ui.Dialog(this,selected is null?"Registrar audio":"Editar audio",("Título",name),("Artista / fuente",artist),
            ("Género / categoría",genre),("Tipo",kind),("Formato",format),("Duración (segundos)",duration),
            ("Ruta del archivo",path),("Buscar archivo",browse)))return;
        Safe(()=>{
            var tr=selected is null?_db.NewAudio(name.Text,artist.Text,genre.Text,kind.Text,format.Text,path.Text,(int)duration.Value)
                :selected with{Title=name.Text,Artist=artist.Text,Genre=genre.Text,Type=kind.Text,
                    Format=format.Text,Path=path.Text,Duration=(int)duration.Value};
            _db.SaveAudio(tr,selected is not null);
            if(!File.Exists(tr.Path))MessageBox.Show(this,"Se guardó el registro, pero todavía no existe el archivo en esa ruta.\n"+tr.Path,
                "Archivo pendiente",MessageBoxButtons.OK,MessageBoxIcon.Information);
            LoadAudio();Report("Audio registrado o editado: "+tr.Title);
        },"Guardar audio");
    }
    private void DeleteAudio()
    {
        var code=Ui.SelectedString(_audioGrid,"codigo");if(code is null)return;
        if(MessageBox.Show(this,"¿Eliminar "+code+"? No se permitirá si está asociado a campañas o listas.",
            "Confirmar",MessageBoxButtons.YesNo,MessageBoxIcon.Question)!=DialogResult.Yes)return;
        Safe(()=>{_db.DeleteAudio(code);LoadAudio();Report("Audio eliminado.");},"Eliminar audio");
    }
    private void ImportFiles()
    {
        using var ofd=new OpenFileDialog{Filter="Audios|*.mp3;*.wav;*.ogg;*.flac;*.m4a;*.aac",Multiselect=true,Title="Importar archivos de audio"};
        if(ofd.ShowDialog(this)!=DialogResult.OK)return;
        var type=Ui.Combo("MUSICA","ANUNCIO","CUNA");
        if(!Ui.Dialog(this,"Tipo de los archivos a importar",("Tipo de audio",type)))return;
        Safe(()=>{
            int ok=0;var errors=new System.Collections.Generic.List<string>();
            foreach(var file in ofd.FileNames)
            {
                try
                {
                    var info=new FileInfo(file);var approxSecs=(int)Math.Clamp(info.Length / 16000L,1L,10800L);
                    // Duración provisional por tamaño; editar manualmente según la duración real del audio.
                    var tr=_db.NewAudio(Path.GetFileNameWithoutExtension(file),"Radio Celendín","General",type.Text,
                        Path.GetExtension(file).Trim('.').ToUpperInvariant(),file,approxSecs);
                    _db.SaveAudio(tr,false);ok++;
                }
                catch(Exception ex){errors.Add(Path.GetFileName(file)+": "+ex.Message);}
            }
            LoadAudio();Report($"Importación: {ok} registros incorporados; {errors.Count} errores.");
            MessageBox.Show(this,$"Importados: {ok}\nNo importados: {errors.Count}\n\nLa duración es aproximada. Corrígela antes de emitir.\n"+
                string.Join("\n",errors.Take(8)),"Resultado de importación",MessageBoxButtons.OK,MessageBoxIcon.Information);
        },"Importar audios");
    }
    private void NewClient()
    {
        var name=Ui.Text();if(!Ui.Dialog(this,"Nuevo cliente",("Nombre comercial",name)))return;
        Safe(()=>{_db.AddClient(name.Text);LoadClients();},"Nuevo cliente");
    }
    private void NewCampaign()
    {
        var clients=_db.Clients();if(clients.Rows.Count==0){MessageBox.Show(this,"Registra primero un cliente.");return;}
        var client=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Width=320};
        foreach(DataRow r in clients.Rows)client.Items.Add(new Choice(r["cliente_id"].ToString()!,r["nombre"].ToString()!));
        client.SelectedIndex=0;
        var name=Ui.Text();var begin=Ui.Date(DateTime.Today);var end=Ui.Date(DateTime.Today.AddMonths(3));
        if(!Ui.Dialog(this,"Crear campaña",("Cliente",client),("Nombre",name),("Fecha inicial",begin),("Fecha final",end)))return;
        Safe(()=>{_db.AddCampaign(int.Parse(Ui.SelectedChoice(client)!.Code),name.Text,begin.Value,end.Value);LoadClients();},"Crear campaña");
    }
    private void NewBlock()
    {
        var cues=_db.Audios(null,"CUNA");
        if(cues.Rows.Count==0){MessageBox.Show(this,"Primero importa o registra una CUÑA institucional.");return;}
        var date=Ui.Date(DateTime.Now.AddMinutes(3),true);
        var cue=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Width=320};
        foreach(DataRow r in cues.Rows)cue.Items.Add(new Choice(r["codigo"].ToString()!,r["titulo"].ToString()!));
        cue.SelectedIndex=0;
        if(!Ui.Dialog(this,"Programar bloque",("Fecha y hora",date),("Cuña de apertura",cue)))return;
        Safe(()=>{_db.AddBlock(date.Value,Ui.SelectedChoice(cue)!.Code);
            _scheduleFilter.Value=date.Value.Date;LoadSchedule();LoadRadio();Report("Bloque registrado. Añade sus anuncios.");},"Crear bloque");
    }
    private void AddSpot()
    {
        var id=Ui.SelectedInt(_scheduleGrid,"bloque_id");
        if(!id.HasValue){MessageBox.Show(this,"Selecciona primero un bloque en la tabla superior.");return;}
        var audios=_db.Audios(null,"ANUNCIO");var campaigns=_db.Campaigns();
        if(audios.Rows.Count==0 || campaigns.Rows.Count==0){MessageBox.Show(this,"Necesitas al menos un ANUNCIO y una CAMPAÑA.");return;}
        var audio=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Width=320};
        foreach(DataRow r in audios.Rows)audio.Items.Add(new Choice(r["codigo"].ToString()!,r["titulo"].ToString()!));
        audio.SelectedIndex=0;
        var campaign=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Width=320};
        foreach(DataRow r in campaigns.Rows)campaign.Items.Add(new Choice(r["codigo"].ToString()!,
            $"{r["cliente"]} | {r["campana"]} [{Convert.ToDateTime(r["fecha_inicio"]):dd/MM}–{Convert.ToDateTime(r["fecha_fin"]):dd/MM/yyyy}]"));
        campaign.SelectedIndex=0;
        var priority=Ui.Number(1,1,99);
        if(!Ui.Dialog(this,"Programar spot",("Anuncio",audio),("Campaña",campaign),("Prioridad (1 primero)",priority)))return;
        Safe(()=>{_db.AddSpot(id.Value,Ui.SelectedChoice(campaign)!.Code,Ui.SelectedChoice(audio)!.Code,(int)priority.Value);
            LoadSpots();LoadRadio();Report("Anuncio asociado al bloque.");},"Programar anuncio");
    }
    private void NewPlaylist()
    {
        var name=Ui.Text();if(!Ui.Dialog(this,"Crear lista de música",("Nombre",name)))return;
        Safe(()=>{_db.CreatePlaylist(name.Text);LoadPlaylists();},"Crear lista");
    }
    private void AddSongToPlaylist()
    {
        var list=Ui.SelectedInt(_listGrid,"lista_id");if(!list.HasValue)return;
        var songs=_db.Audios(null,"MUSICA");if(songs.Rows.Count==0)return;
        var pick=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Width=320};
        foreach(DataRow r in songs.Rows)pick.Items.Add(new Choice(r["codigo"].ToString()!,r["titulo"].ToString()!));
        pick.SelectedIndex=0;
        if(!Ui.Dialog(this,"Agregar canción a la lista",("Canción",pick)))return;
        Safe(()=>{_db.AddToPlaylist(list.Value,Ui.SelectedChoice(pick)!.Code);LoadPlaylistSongs();},"Agregar a lista");
    }
    private void RemoveSongFromPlaylist()
    {
        var list=Ui.SelectedInt(_listGrid,"lista_id");var song=Ui.SelectedString(_listSongs,"codigo");
        if(!list.HasValue || song is null)return;
        Safe(()=>{_db.RemoveFromPlaylist(list.Value,song);LoadPlaylistSongs();},"Quitar de lista");
    }
    private void ActivatePlaylist()
    {
        var id=Ui.SelectedInt(_listGrid,"lista_id");if(!id.HasValue)return;
        _config.ActivePlaylistId=id;Safe(()=>{_config.Save();Report("Lista activa para modo automático: "+id);},"Activar lista");
    }
    private void ShowStats()
    {
        Safe(()=>{var dt=_db.Stats();if(dt.Rows.Count==0)return;
            var r=dt.Rows[0];MessageBox.Show(this,string.Join("\n",dt.Columns.Cast<DataColumn>().Select(c=>c.ColumnName+": "+r[c])),
                "Resumen de la base de datos",MessageBoxButtons.OK,MessageBoxIcon.Information);},"Indicadores");
    }
    private void SaveSettings()
    {
        Safe(()=>{_config.ConnectionString=_connection.Text.Trim();_config.SongRepeatMinutes=(int)_songMinutes.Value;
            _config.ArtistRepeatMinutes=(int)_artistMinutes.Value;_config.FadeMilliseconds=(int)_fadeMs.Value;
            _config.Volume=_volume.Value;_config.Save();
            if(_audio is not null)_audio.Volume=_config.Volume;
            _db.CheckConnection();_connected=true;RefreshAll();Report("Configuración guardada.");},"Guardar ajustes");
    }
    private void EnsureEngine()
    {
        if(_audio is not null)return;
        _audio=new AudioEngine{Volume=_config.Volume};
        _audio.SongFinished+=()=>{if(IsHandleCreated && !IsDisposed)BeginInvoke(new Action(()=>_songFinished=true));};
    }
    private void PlaySelected()
    {
        var code=Ui.SelectedString(_playerSongs,"codigo");if(code is null)return;
        Safe(()=>{var a=_db.Track(code);if(a is null)return;PlayTrack(a,false);},"Reproducción manual");
    }
    private bool PlayTrack(AudioTrack track,bool automatic)
    {
        try
        {
            EnsureEngine();_songFinished=false;_audio!.Volume=_config.Volume;
            _audio.PlayMusic(track);_db.LogMusic(track,automatic);
            _nowPlaying.Text="EN EMISIÓN: "+track.Title+" · "+track.Artist;
            Report((automatic?"Automático: ":"Manual: ")+track.Title);return true;
        }
        catch(Exception ex)
        {
            _db.LogError(track.Code,ex.Message);Report("No se pudo reproducir '"+track.Title+"': "+ex.Message);
            MessageBox.Show(this,ex.Message,"Archivo no legible",MessageBoxButtons.OK,MessageBoxIcon.Warning);
            return false;
        }
    }
    private void ToggleAuto()
    {
        _auto=!_auto;_autoButton.Text=_auto?"Automático: ACTIVO":"Automático: APAGADO";
        _mode.Text=_auto?"AUTO":"MANUAL";Report(_auto?"Modo automático activado.":"Modo manual activado.");
    }
    private async Task TickAsync()
    {
        if(_tickRunning || !_auto || !_connected || _busy)return;
        _tickRunning=true;
        try
        {
            var due=_db.DueBlock();
            if(due is not null && (!_failedBlocks.TryGetValue(due.Id,out var last) || DateTime.Now-last>TimeSpan.FromMinutes(1)))
            {await EmitBlockAsync(due);return;}
            if(_audio is null || (!_audio.MusicPlaying && !_audio.MusicPaused) || _songFinished)
            {
                _songFinished=false;
                var song=_db.NextEligibleMusic(_config.ActivePlaylistId,_config.SongRepeatMinutes,_config.ArtistRepeatMinutes);
                if(song is not null)PlayTrack(song,true);
                else Report("No existen canciones aptas según las restricciones de repetición. Ajusta los intervalos o la lista.");
            }
        }
        catch(Exception ex){Report("Error de automatización: "+ex.Message);}
        finally {_tickRunning=false;}
    }
    private async Task EmitSelectedBlockAsync()
    {
        var id=Ui.SelectedInt(_playerBlocks,"bloque_id")??Ui.SelectedInt(_scheduleGrid,"bloque_id");
        if(!id.HasValue){MessageBox.Show(this,"Selecciona un bloque en Emisión o Programación.");return;}
        try {var block=_db.GetBlock(id.Value);if(block is not null)await EmitBlockAsync(block);}
        catch(Exception ex){Error(ex,"Emitir bloque");}
    }
    private async Task EmitBlockAsync(Block block)
    {
        if(_busy)return;
        _busy=true;_adCancellation=new CancellationTokenSource();bool musicWasPaused=false;
        var warnings=new System.Collections.Generic.List<string>();
        try
        {
            EnsureEngine();
            var intro=_db.Track(block.IntroCode);
            if(intro is null || intro.Type!="CUNA")throw new InvalidOperationException("La cuña institucional del bloque no es válida.");
            if(!File.Exists(intro.Path))throw new FileNotFoundException("Falta la cuña institucional. Bloque sin emitir.",intro.Path);
            musicWasPaused=await _audio!.PauseForAdvertisingAsync(_config.FadeMilliseconds,_adCancellation.Token);
            _nowPlaying.Text="PUBLICIDAD: apertura institucional · "+block.Reference;
            await _audio.PlayAdvertisementAsync(intro.Path,intro.Duration,_adCancellation.Token);
            foreach(var spot in _db.PendingSpots(block.Id))
            {
                if(_adCancellation.IsCancellationRequested)break;
                try
                {
                    _nowPlaying.Text="PUBLICIDAD: "+spot.Title+" · prioridad "+spot.Priority;
                    await _audio.PlayAdvertisementAsync(spot.Path,spot.Duration,_adCancellation.Token);
                    _db.CompleteSpot(spot.Id,true);
                    Report("Spot emitido: "+spot.Title);
                }
                catch(OperationCanceledException){break;}
                catch(Exception ex)
                {
                    _db.LogError(spot.Code,ex.Message);
                    // No se certifica un anuncio como emitido si el archivo falla.
                    try {_db.CompleteSpot(spot.Id,false);}catch(Exception dbEx){warnings.Add(dbEx.Message);}
                    warnings.Add(spot.Title+": "+ex.Message);
                }
            }
            if(_adCancellation.IsCancellationRequested)Report("Bloque detenido; los anuncios restantes siguen PENDIENTES.");
        }
        catch(OperationCanceledException){Report("Bloque interrumpido por operador.");}
        catch(Exception ex)
        {
            _failedBlocks[block.Id]=DateTime.Now;_db.LogError(block.IntroCode,ex.Message);
            warnings.Add("Bloque "+block.Reference+": "+ex.Message);
        }
        finally
        {
            try {if(musicWasPaused && _audio is not null)await _audio.ResumeAfterAdvertisingAsync(_config.FadeMilliseconds);}
            catch(Exception ex){warnings.Add("Al reanudar música: "+ex.Message);}
            _adCancellation?.Dispose();_adCancellation=null;_busy=false;
            Safe(()=>{LoadRadio();LoadSchedule();},"Actualizar después de publicidad");
            if(warnings.Count>0)MessageBox.Show(this,string.Join("\n\n",warnings.Take(5)),
                "Incidencias en emisión",MessageBoxButtons.OK,MessageBoxIcon.Warning);
        }
    }
}
