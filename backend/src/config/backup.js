import fs from 'node:fs/promises';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';
import {query,pool} from './db.js';
import {env} from './env.js';
let id,temporary;
try{
 if(!env.allowBackupCommands)throw Error('Habilite ALLOW_BACKUP_COMMANDS=true para ejecutar pg_dump desde la consola autorizada.');
 const dir=path.resolve(env.backupDir);await fs.mkdir(dir,{recursive:true,mode:0o700});
 const file=path.join(dir,'nexo_'+new Date().toISOString().replace(/[:.]/g,'-')+'.dump');temporary=file+'.tmp';
 id=(await query("INSERT INTO respaldos(tipo_respaldo,estado,nombre_archivo,mensaje) VALUES('MANUAL','EJECUTANDO',$1,'Ejecución por consola autorizada') RETURNING id",[file])).rows[0].id;
 const url=new URL(env.databaseUrl);const childEnv={...process.env,PGHOST:url.hostname,PGPORT:url.port||'5432',PGDATABASE:decodeURIComponent(url.pathname.slice(1)),PGUSER:decodeURIComponent(url.username),PGPASSWORD:decodeURIComponent(url.password)};
 const output=await new Promise((resolve,reject)=>{const child=spawn('pg_dump',['--format=custom','--no-owner','--file='+temporary],{env:childEnv,shell:false});let error='';child.stderr.on('data',b=>error+=b.toString().slice(0,2000));child.on('error',reject);child.on('exit',code=>code===0?resolve(''):reject(Error('pg_dump terminó con código '+code+'. Verifique conectividad y herramientas PostgreSQL.')));});
 await fs.chmod(temporary,0o600);await fs.rename(temporary,file);temporary=null;
 const checksum=createHash('sha256').update(await fs.readFile(file)).digest('hex');await fs.writeFile(file+'.sha256',checksum+'  '+path.basename(file)+'\n',{mode:0o600});
 await query("UPDATE respaldos SET estado='EXITOSO',mensaje=$2,finalizado_en=NOW() WHERE id=$1",[id,'pg_dump finalizado. SHA256 '+checksum]);
 console.log('Respaldo creado:',file,'\nSHA256:',checksum);
}catch(e){if(temporary)await fs.rm(temporary,{force:true}).catch(()=>{});if(id)await query("UPDATE respaldos SET estado='FALLIDO',mensaje=$2,finalizado_en=NOW() WHERE id=$1",[id,e.message]).catch(()=>{});console.error(e.message);process.exitCode=1}finally{await pool.end()}
