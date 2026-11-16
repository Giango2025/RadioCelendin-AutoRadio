"""Mide SOLO SQL Server con volúmenes comparables; ejecutar en la PC con ODBC Driver 18.
Uso: python 02_benchmark_sqlserver.py 'localhost\\SQLEXPRESS'
"""
import sys, time, csv
from pathlib import Path
import pyodbc
server=sys.argv[1] if len(sys.argv)>1 else r'localhost\SQLEXPRESS'
cs='DRIVER={ODBC Driver 18 for SQL Server};SERVER='+server+';DATABASE=RadioCelendinDW;Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;'
sql='''WITH x AS (SELECT TOP (?) e.emitidos, c.codigo FROM dbo.FactEmision e
 JOIN dbo.DimCampana c ON c.campana_key=e.campana_key ORDER BY e.fact_key)
 SELECT codigo,SUM(emitidos) emitidos,COUNT(*) cantidad FROM x GROUP BY codigo'''
records=[]
with pyodbc.connect(cs) as cn:
 cur=cn.cursor()
 for n in (100,500,960):
  t=time.perf_counter();cur.execute(sql,n);rows=cur.fetchall();elapsed=time.perf_counter()-t
  records.append([n,round(elapsed,6),len(rows)]);print(n,elapsed,len(rows))
with (Path(__file__).parent/'tiempos_sqlserver.csv').open('w',newline='',encoding='utf8') as f:
 w=csv.writer(f);w.writerow(['filas','segundos','campanas']);w.writerows(records)
