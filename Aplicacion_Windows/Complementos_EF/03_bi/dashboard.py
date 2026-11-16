"""Dashboard docente gratuito: pip install streamlit pandas ; streamlit run dashboard.py"""
from pathlib import Path
import pandas as pd
import streamlit as st
P=Path(__file__).resolve().parent
st.set_page_config(page_title='AutoRadio - KPIs',layout='wide')
st.title('Radio Celendín AutoRadio | Indicadores de publicidad')
st.caption('Datos simulados de demostración. Para datos procedentes de SQL Server, exportar desde el Data Warehouse.')
df=pd.read_csv(P/'dashboard_datos.csv',encoding='utf-8-sig')
mes=st.selectbox('Filtrar mes', ['Todos']+sorted(df['mes'].unique().tolist()))
cliente=st.selectbox('Filtrar cliente',['Todos']+sorted(df['cliente'].unique().tolist()))
f=df.copy()
if mes!='Todos':f=f[f.mes==mes]
if cliente!='Todos':f=f[f.cliente==cliente]
a,b,c,d=st.columns(4)
a.metric('Spots programados',len(f));b.metric('Spots emitidos',int(f.emitidos.sum()))
c.metric('Cumplimiento',f'{100*f.emitidos.mean():.1f}%' if len(f) else 'N/D')
d.metric('Retraso medio',f'{f.atraso_seg.mean():.1f} s' if f.atraso_seg.count() else 'N/D')
st.subheader('Roll-up: emitidos por mes')
st.bar_chart(f.groupby('mes',as_index=True)['emitidos'].sum())
st.subheader('Drill-down: emitidos por campaña')
st.bar_chart(f.groupby('codigo_campana',as_index=True)['emitidos'].sum())
st.subheader('Detalle de emisiones (slice / dice)')
st.dataframe(f[['fecha_hora','cliente','codigo_campana','codigo_audio','estado','atraso_seg']],use_container_width=True)
