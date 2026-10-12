import fs from 'node:fs/promises';
import {pool} from './db.js';
/** Atomic migration tracking. Advisory lock serializes concurrent app starts. */
export async function migrate(){
 const client=await pool.connect();
 try{
  await client.query('BEGIN');
  await client.query('SELECT pg_advisory_xact_lock(302026)');
  await client.query('CREATE TABLE IF NOT EXISTS migraciones_parkia(version VARCHAR(30) PRIMARY KEY,aplicada_en TIMESTAMPTZ DEFAULT NOW())');
  const steps=[['V11_ALERTAS','04_alertas_v11.sql'],['V15_AUDITORIA','05_auditoria_v15.sql'],['V17_MAPEO','06_mapeo_real_v17.sql'],['V26_MAPA','07_mapa_rectangulos_v26.sql'],['V29_CASOS_USO','08_casos_uso_v29.sql'],['V30_NEXO','09_nexo_v30.sql']];
  // Existing V29 has already applied these earlier scripts. Never overwrite user-edited maps.
  if((await client.query("SELECT 1 FROM migraciones_parkia WHERE version='V29_CASOS_USO'")).rowCount){
   for(const [version] of steps.slice(0,4))await client.query('INSERT INTO migraciones_parkia(version) VALUES ($1) ON CONFLICT DO NOTHING',[version]);
  }
  for(const [version,file] of steps){
   if((await client.query('SELECT 1 FROM migraciones_parkia WHERE version=$1',[version])).rowCount)continue;
   await client.query(await fs.readFile(new URL('../../sql/'+file,import.meta.url),'utf8'));
   await client.query('INSERT INTO migraciones_parkia(version) VALUES ($1)',[version]);
  }
  await client.query('COMMIT');
 }catch(e){await client.query('ROLLBACK');throw e}finally{client.release()}
}
