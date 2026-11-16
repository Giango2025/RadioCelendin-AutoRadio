// Ejecutar en mongosh: .load('01_mongodb_crud.js')
// Solo metadatos semiestructurados SIMULADOS; campañas y programación siguen en SQL Server.
const bd = db.getSiblingDB('autoradio_demo');
bd.metadatos_audio.deleteMany({origen:'EF_DEMO'});
print('CREATE');
printjson(bd.metadatos_audio.insertMany([
 {codigo:'A0001',origen:'EF_DEMO',etiquetas:['folclore','regional'],normalizacion:{lufs:-16, pico_db:-1},locutores:[],calidad:{revisado:true},formatos:['MP3','WAV']},
 {codigo:'A0002',origen:'EF_DEMO',etiquetas:['pop'],normalizacion:{lufs:-14},catalogacion:{revisor:'operador demo',fecha:'2026-11-02'}},
 {codigo:'A0177',origen:'EF_DEMO',etiquetas:['identificacion','institucional'],restricciones:{antes_de_publicidad:true},versiones:[{idioma:'es',duracion_seg:12}]}
]));
print('READ');printjson(bd.metadatos_audio.find({origen:'EF_DEMO'}).toArray());
print('UPDATE');printjson(bd.metadatos_audio.updateOne({codigo:'A0001',origen:'EF_DEMO'},{$set:{'calidad.revisado':false}}));
print('DELETE (solo un documento temporal)');
bd.metadatos_audio.insertOne({codigo:'TEMP_BORRAR',origen:'EF_DEMO',notas:'documento efimero'});
printjson(bd.metadatos_audio.deleteOne({codigo:'TEMP_BORRAR',origen:'EF_DEMO'}));
bd.metadatos_audio.createIndex({codigo:1},{unique:true});
print('FINAL');printjson(bd.metadatos_audio.find({origen:'EF_DEMO'}).toArray());
