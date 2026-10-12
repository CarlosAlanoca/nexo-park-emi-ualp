import {iniciarVerificadorAlertas} from './modules/alertas/alertas.worker.js';
import {app} from './app.js';
import {env} from './config/env.js';
import {query} from './config/db.js';
import {migrate} from './config/migrate.js';
import {asegurarEstructuraAutenticacion,asegurarUsuariosDemo} from './core/autenticacion/bootstrap.service.js';
async function iniciar(){
 try{
  if(env.nodeEnv==='production'&&[env.jwtSecret,env.captchaSecret].some(x=>x.length<32||/change|cambiar|dev-secret/i.test(x)))throw Error('Configure JWT_SECRET y CAPTCHA_SECRET independientes de al menos 32 caracteres.');
  await query('SELECT 1');await migrate();await asegurarEstructuraAutenticacion();await asegurarUsuariosDemo();
  await query(`INSERT INTO perfiles_propietarios(usuario_id,tipo) SELECT u.id,CASE WHEN UPPER(COALESCE(u.area_institucional,'')) LIKE '%DOCENTE%' THEN 'DOCENTE' ELSE 'ESTUDIANTE' END FROM usuarios u JOIN roles r ON r.id=u.rol_id WHERE r.codigo='PROPIETARIO' ON CONFLICT(usuario_id) DO NOTHING`);
  iniciarVerificadorAlertas();app.listen(env.port,()=>console.log(`NEXO PARK EMI UALP en http://localhost:${env.port}`));
 }catch(e){console.error('No se pudo iniciar NEXO PARK:',e);process.exit(1)}
}
iniciar();
