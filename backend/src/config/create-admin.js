import {pool,query} from './db.js';
import {migrate} from './migrate.js';
import {hashPassword} from '../utils/security.js';
import {asegurarEstructuraAutenticacion} from '../core/autenticacion/bootstrap.service.js';
try{
 const username=process.env.ADMIN_USER,password=process.env.ADMIN_PASSWORD,name=process.env.ADMIN_NAME||'Administrador NEXO PARK';
 if(!username||!password||password.length<12||!/^[A-Za-z0-9._-]{3,60}$/.test(username))throw Error('Defina ADMIN_USER y ADMIN_PASSWORD (mínimo 12 caracteres).');
 await migrate();await asegurarEstructuraAutenticacion();
 const r=await query("INSERT INTO usuarios(nombre_usuario,hash_contrasena,nombre_completo,area_institucional,rol_id) SELECT $1,$2,$3,'Administración',id FROM roles WHERE codigo='ADMIN' AND activo=TRUE RETURNING id",[username,hashPassword(password),name]);
 if(!r.rowCount)throw Error('Rol ADMIN ausente. Inicialice el esquema y las semillas.');
 console.log('Cuenta administradora creada. Retire ADMIN_PASSWORD del entorno.');
}catch(e){console.error(e.code==='23505'?'La cuenta ya existe. No se reemplazó su contraseña.':e.message);process.exitCode=1}finally{await pool.end()}
