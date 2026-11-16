"""Opcional: exporta filas ya cargadas desde RadioCelendinDW para mostrar evidencias SQL reales.
Requiere: pip install pyodbc pandas; Microsoft ODBC Driver 18 for SQL Server.
Ejemplo: python exportar_sql_dw.py "localhost\\SQLEXPRESS".
"""
import sys
from pathlib import Path
import pandas as pd, pyodbc
server=sys.argv[1] if len(sys.argv)>1 else r'localhost\SQLEXPRESS'
cs=('DRIVER={ODBC Driver 18 for SQL Server};SERVER='+server+';DATABASE=RadioCelendinDW;'
    'Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;')
sql='''SELECT CONCAT(YEAR(f.fecha),'-',RIGHT('0'+CAST(MONTH(f.fecha) AS VARCHAR(2)),2)) mes,
 CONVERT(VARCHAR(10),f.fecha,120) fecha,CONVERT(VARCHAR(19),f.fecha,120) fecha_hora,
 cli.nombre cliente,c.codigo codigo_campana,a.codigo_audio,
 CASE WHEN e.emitidos=1 THEN 'EMITIDA' WHEN e.omitidos=1 THEN 'OMITIDA' ELSE 'PENDIENTE' END estado,
 e.emitidos,e.omitidos,e.atraso_seg,e.duracion_seg
 FROM dbo.FactEmision e JOIN dbo.DimFecha f ON f.fecha_key=e.fecha_key
 JOIN dbo.DimCliente cli ON cli.cliente_key=e.cliente_key
 JOIN dbo.DimCampana c ON c.campana_key=e.campana_key
 JOIN dbo.DimAudio a ON a.audio_key=e.audio_key'''
with pyodbc.connect(cs) as cn:
 df=pd.read_sql_query(sql,cn)
if df.empty:raise SystemExit('El DW está vacío. Primero ejecutar 02_etl_dw.sql.')
df.to_csv(Path(__file__).resolve().parent/'dashboard_datos.csv',index=False,encoding='utf-8-sig')
print('Exportadas',len(df),'filas desde SQL Server DW')
