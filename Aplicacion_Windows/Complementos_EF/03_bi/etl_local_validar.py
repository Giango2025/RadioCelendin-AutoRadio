"""ETL reproducible sobre CSV SIMULADOS, independiente de SQL Server.
Realizar 02_etl_dw.sql en SSMS para el DW oficial. Esta rutina verifica datasets y alimenta dashboard de práctica.
"""
from pathlib import Path
from datetime import datetime
import json, time, pandas as pd
ROOT=Path(__file__).resolve().parents[1]
DAT=ROOT/'00_datos'; OUT=Path(__file__).resolve().parent
start=time.perf_counter()
a=pd.read_csv(DAT/'catalogo_audio.csv',dtype=str,keep_default_na=False,encoding='utf-8-sig')
p=pd.read_csv(DAT/'programacion_publicitaria.csv',dtype=str,keep_default_na=False,encoding='utf-8-sig')
co=json.loads((DAT/'clientes_campanas.json').read_text(encoding='utf-8'))
valid_camps={v['codigo']:v for v in co}
reject_audio=[]; accepted_audio={}; audio_keys=set()
for i,row in a.iterrows():
    r=row.to_dict();c=r['codigo'];reason=None
    if not c or len(c)>12:reason='Codigo vacio o demasiado largo'
    elif c in audio_keys:reason='Codigo duplicado'
    elif not r['titulo'].strip():reason='Titulo vacio'
    elif not r['ruta'].strip():reason='Ruta vacia'
    elif r['tipo'] not in ['MUSICA','ANUNCIO','CUNA']:reason='Tipo invalido'
    elif r['formato'] not in ['MP3','WAV','FLAC','OGG']:reason='Formato invalido'
    elif not (r['duracion_seg'].isdigit() and 1<=int(r['duracion_seg'])<=10800):reason='Duracion invalida'
    elif not r['artista'].strip():reason='Artista vacio'
    elif not r['genero'].strip():reason='Genero vacio'
    if reason:reject_audio.append({'fila':i+2,'motivo':reason})
    else:accepted_audio[c]=r
    audio_keys.add(c)
reject_agenda=[];clean=[];programmed_keys=set()
for i,row in p.iterrows():
    r=row.to_dict();reason=None
    key=(r['bloque_ref'],r['codigo_audio'])
    try: planned=datetime.strptime(r['fecha_hora'],'%Y-%m-%d %H:%M:%S')
    except ValueError: planned=None
    try: actual=datetime.strptime(r['emision_real'],'%Y-%m-%d %H:%M:%S') if r['emision_real'] else None
    except ValueError: actual=None
    camp=valid_camps.get(r['codigo_campana'])
    audio=accepted_audio.get(r['codigo_audio'])
    if not r['bloque_ref'] or len(r['bloque_ref'])>12:reason='Referencia de bloque invalida'
    elif key in programmed_keys:reason='Spot duplicado en el mismo bloque'
    elif planned is None:reason='Fecha programada invalida'
    elif camp is None:reason='Campana no existe'
    elif audio is None or audio['tipo']!='ANUNCIO':reason='Audio no existe o no es anuncio'
    elif not(r['prioridad'].isdigit() and 1<=int(r['prioridad'])<=99):reason='Prioridad invalida'
    elif r['estado'] not in ['EMITIDA','OMITIDA','PENDIENTE']:reason='Estado invalido'
    elif (r['estado']=='EMITIDA' and actual is None) or (r['estado']!='EMITIDA' and bool(r['emision_real'])):reason='Fecha real inconsistente'
    elif not (camp['inicio']<=planned.strftime('%Y-%m-%d')<=camp['fin']):reason='Fuera de vigencia'
    if reason: reject_agenda.append({'fila':i+2,'motivo':reason})
    else:
        delay=int((actual-planned).total_seconds()) if actual else None
        clean.append({'bloque_ref':r['bloque_ref'],'fecha_hora':r['fecha_hora'],
           'fecha':planned.strftime('%Y-%m-%d'),'mes':planned.strftime('%Y-%m'),
           'codigo_campana':r['codigo_campana'],'cliente':camp['cliente'],
           'codigo_audio':r['codigo_audio'],'prioridad':int(r['prioridad']),
           'estado':r['estado'],'emitidos':int(r['estado']=='EMITIDA'),
           'omitidos':int(r['estado']=='OMITIDA'),'duracion_seg':int(audio['duracion_seg']),
           'atraso_seg':delay})
    programmed_keys.add(key)
df=pd.DataFrame(clean)
df.to_csv(OUT/'dashboard_datos.csv',index=False,encoding='utf-8-sig')
rej=pd.DataFrame([{'fuente':'Audio',**r} for r in reject_audio]+[{'fuente':'Agenda',**r} for r in reject_agenda])
rej.to_csv(OUT/'rechazos_detalle.csv',index=False,encoding='utf-8-sig')
metrics={'origen':'CSV simulados; verificados con pandas, NO con SQL Server','filas_audio_entrada':len(a),
 'filas_audio_aceptadas':len(accepted_audio),'filas_audio_rechazadas':len(reject_audio),
 'filas_agenda_entrada':len(p),'filas_agenda_aceptadas':len(df),'filas_agenda_rechazadas':len(reject_agenda),
 'bloques':int(df['bloque_ref'].nunique()),'campanas':len(valid_camps),
 'emitidos':int(df['emitidos'].sum()),'omitidos':int(df['omitidos'].sum()),
 'cumplimiento_pct':round(100*df['emitidos'].mean(),2),
 'retraso_medio_seg':round(df['atraso_seg'].mean(),2),
 'por_causa':rej.groupby(['fuente','motivo']).size().to_dict(),
 'etl_python_seg':round(time.perf_counter()-start,4)}
metrics['por_causa']={f'{k[0]}: {k[1]}':int(v) for k,v in metrics['por_causa'].items()}
(OUT/'metricas_demo.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2),encoding='utf8')
with (OUT/'etl_log_demo.txt').open('w',encoding='utf-8') as f:
 f.write('PRUEBA LOCAL REAL / datos simulados / sin SQL Server.\n')
 f.write('Fecha de ejecución: '+datetime.now().isoformat(timespec='seconds')+'\n')
 f.write(json.dumps(metrics,ensure_ascii=False,indent=2))
print(json.dumps(metrics,ensure_ascii=False,indent=2))
