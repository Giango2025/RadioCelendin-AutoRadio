# Requiere Windows PowerShell 5.1, SQL Server de pruebas y autenticacion Windows.
# No instala nada ni se conecta a servidores externos: usa SOLO la instancia indicada.
param([string]$Servidor = '.\SQLEXPRESS', [switch]$SoloPruebas)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Data

$Base = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Evidencias = Join-Path $Base 'Evidencias_SQLServer'
New-Item -ItemType Directory -Force -Path $Evidencias | Out-Null
$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogPath = Join-Path $Evidencias ("ejecucion_" + $Stamp + ".log")
$script:Conexion = $null

function Escribir-Log([string]$Mensaje) {
    $linea = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' | ' + $Mensaje
    Write-Host $linea
    Add-Content -LiteralPath $LogPath -Value $linea -Encoding UTF8
}

function Exportar-Consulta([string]$Nombre, [string]$Consulta) {
    $tabla = New-Object System.Data.DataTable
    $adaptador = New-Object System.Data.SqlClient.SqlDataAdapter
    $comando = $script:Conexion.CreateCommand()
    $comando.CommandText = $Consulta
    $comando.CommandTimeout = 120
    $adaptador.SelectCommand = $comando
    [void]$adaptador.Fill($tabla)
    $filas = @()
    foreach ($r in $tabla.Rows) {
        $obj = [ordered]@{}
        foreach ($col in $tabla.Columns) {
            $v = $r[$col.ColumnName]
            if ($v -eq [DBNull]::Value) { $v = '' }
            $obj[$col.ColumnName] = $v
        }
        $filas += [pscustomobject]$obj
    }
    $destino = Join-Path $Evidencias ($Nombre + '.csv')
    if ($filas.Count -gt 0) {
        $filas | Export-Csv -LiteralPath $destino -NoTypeInformation -Encoding UTF8
    } else {
        Set-Content -LiteralPath $destino -Value 'SIN FILAS' -Encoding UTF8
    }
    Escribir-Log "$Nombre : $($tabla.Rows.Count) filas exportadas a CSV"
}

function Exportar-Evidencias {
    Exportar-Consulta '01_conteos_sql' @"
SELECT
 (SELECT COUNT(*) FROM dbo.StgAudio WHERE lote_id=1) AS audio_origen,
 (SELECT COUNT(*) FROM dbo.Audio) AS audio_aceptado,
 (SELECT COUNT(*) FROM dbo.Rechazo WHERE lote_id=1 AND fuente='Audio') AS audio_rechazado,
 (SELECT COUNT(*) FROM dbo.StgAgenda WHERE lote_id=1) AS agenda_origen,
 (SELECT COUNT(*) FROM dbo.SpotProgramado) AS agenda_aceptado,
 (SELECT COUNT(*) FROM dbo.Rechazo WHERE lote_id=1 AND fuente='Agenda') AS agenda_rechazado;
"@
    Exportar-Consulta '02_resultados_pruebas_sql' 'SELECT TOP (100) resultado_id,ejecucion_id,fecha_utc,prueba,estado,detalle,usuario_sql FROM dbo.EP_ResultadoPrueba ORDER BY resultado_id DESC;'
    Exportar-Consulta '03_rechazos_sql' 'SELECT fuente,motivo,COUNT(*) AS total FROM dbo.Rechazo WHERE lote_id=1 GROUP BY fuente,motivo ORDER BY fuente,motivo;'
    Exportar-Consulta '04_auditoria_sql' 'SELECT TOP (30) auditoria_id,tabla,registro_id,operacion,valor_anterior,valor_nuevo,usuario_bd,fecha_hora FROM dbo.Auditoria ORDER BY auditoria_id DESC;'
    Exportar-Consulta '05_objetos_sql' "SELECT name,type_desc FROM sys.objects WHERE name IN ('usp_IngestarCatalogo','usp_IngestarAgenda','usp_ProgramarSpot','trg_AuditarSpot','trg_ValidarSpot','trg_ValidarCuna','fn_DuracionBloque') ORDER BY type_desc,name;"
    Exportar-Consulta '06_programacion_B0001_sql' "SELECT b.referencia,b.fecha_hora,cuna.titulo AS cuna,s.prioridad,a.titulo AS anuncio,s.estado FROM dbo.Bloque b JOIN dbo.Audio cuna ON cuna.codigo=b.codigo_cuna JOIN dbo.SpotProgramado s ON s.bloque_id=b.bloque_id JOIN dbo.Audio a ON a.codigo=s.codigo_audio WHERE b.referencia='B0001' ORDER BY s.prioridad;"
}

try {
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder.DataSource = $Servidor
    $builder.InitialCatalog = 'master'
    $builder.IntegratedSecurity = $true
    $builder.TrustServerCertificate = $true  # SOLO ENTORNO DE LABORATORIO
    $builder.ConnectTimeout = 15
    $script:Conexion = New-Object System.Data.SqlClient.SqlConnection
    $script:Conexion.ConnectionString = $builder.ConnectionString
    $script:Conexion.Open()
    Escribir-Log "Conectado correctamente a: $Servidor / Windows Authentication"
    if (-not $SoloPruebas) {
        # No volver a cargar los 1.153 INSERT de staging en una base que ya tiene catalogo.
        $comprobar = $script:Conexion.CreateCommand()
        $comprobar.CommandText = "SELECT OBJECT_ID(N'RadioCelendinAutoRadio.dbo.Audio',N'U')"
        $existeTabla = $comprobar.ExecuteScalar()
        $comprobar.Dispose()
        if (($null -ne $existeTabla) -and ($existeTabla -ne [DBNull]::Value)) {
            $comprobar = $script:Conexion.CreateCommand()
            $comprobar.CommandText = "SELECT COUNT(*) FROM RadioCelendinAutoRadio.dbo.Audio"
            $nFilas = [int]$comprobar.ExecuteScalar()
            $comprobar.Dispose()
            if ($nFilas -gt 0) {
                throw "La base YA contiene $nFilas audios. No se recargaron datos para evitar duplicados. Usa REPETIR_SOLO_PRUEBAS.bat para verificarla sin cargar de nuevo."
            }
        }
    }
    $archivos = if ($SoloPruebas) {
        @('04_PRUEBAS_SQLSERVER.sql')
    } else {
        @('01_CREAR_BASE.sql','02_CREAR_OBJETOS.sql',
          '03_CARGAR_DATOS.sql','04_PRUEBAS_SQLSERVER.sql')
    }
    foreach ($nombre in $archivos) {
        $ruta = Join-Path (Join-Path $Base 'SQL') $nombre
        Escribir-Log "EJECUTANDO: $nombre"
        $contenido = [System.IO.File]::ReadAllText($ruta,[System.Text.Encoding]::UTF8)
        $lotes = [regex]::Split($contenido,'(?im)^[ \t]*GO[ \t]*(?:--[^\r\n]*)?\r?$')
        $n = 0
        foreach ($lote in $lotes) {
            if ([string]::IsNullOrWhiteSpace($lote)) { continue }
            $n++
            $cmd = $script:Conexion.CreateCommand()
            $cmd.CommandText = $lote
            $cmd.CommandTimeout = 300
            try {
                [void]$cmd.ExecuteNonQuery()
            } catch {
                throw "ERROR EN $nombre, lote $n : $($_.Exception.Message)"
            } finally {
                $cmd.Dispose()
            }
        }
        Escribir-Log "OK: $nombre ($n lotes procesados)"
    }
    Escribir-Log 'Exportando resultados obtenidos realmente en SQL Server...'
    Exportar-Evidencias
    Escribir-Log 'EJECUCION FINALIZADA SIN ERRORES SQL: conservar el log y los CSV.'
    exit 0
} catch {
    Escribir-Log ("FALLO: " + $_.Exception.Message)
    if ($script:Conexion -and $script:Conexion.State -eq [System.Data.ConnectionState]::Open) {
        try { Exportar-Evidencias } catch { Escribir-Log ("No se pudo exportar la evidencia: " + $_.Exception.Message) }
    }
    exit 1
} finally {
    if ($script:Conexion) { $script:Conexion.Close(); $script:Conexion.Dispose() }
}
