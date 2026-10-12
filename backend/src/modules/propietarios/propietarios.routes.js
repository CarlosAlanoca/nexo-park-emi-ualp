import {Router} from 'express';
import {pool,query} from '../../config/db.js';
import {authenticate,requirePermission} from '../../middleware/auth.js';
import {asyncHandler} from '../../utils/asyncHandler.js';
import {hashPassword} from '../../utils/security.js';
export const propietariosRouter=Router();
propietariosRouter.use(authenticate);
const uuid=x=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(x||''));
const clean=(x,max=170)=>String(x||'').trim().slice(0,max);
const bad=(res,msg)=>res.status(400).json({message:msg});
propietariosRouter.get('/zonas',requirePermission('propietarios.ver'),asyncHandler(async(req,res)=>{
  const r=await query("SELECT id,codigo,nombre FROM zonas_parqueo WHERE estado='ACTIVA' AND tipo_zona='ESTUDIANTES' ORDER BY nombre");res.json(r.rows);
}));
propietariosRouter.get('/',requirePermission('propietarios.ver'),asyncHandler(async(req,res)=>{
  const r=await query(`SELECT u.id,u.nombre_usuario,u.nombre_completo,u.correo,u.area_institucional,u.estado,z.codigo zona_codigo,z.nombre zona_nombre,coalesce(pp.tipo,'ESTUDIANTE') tipo_propietario,COUNT(v.id)::int vehiculos
    FROM usuarios u JOIN roles ro ON ro.id=u.rol_id LEFT JOIN perfiles_propietarios pp ON pp.usuario_id=u.id LEFT JOIN zonas_parqueo z ON z.id=u.zona_asignada_id LEFT JOIN vehiculos v ON v.propietario_usuario_id=u.id
    WHERE ro.codigo='PROPIETARIO' GROUP BY u.id,z.id,pp.usuario_id ORDER BY u.nombre_completo LIMIT 1500`);res.json(r.rows);
}));
propietariosRouter.post('/',requirePermission('propietarios.gestionar'),asyncHandler(async(req,res)=>{
  const b=req.body||{},nombre=clean(b.nombreCompleto),usuario=clean(b.nombreUsuario,60),correo=clean(b.correo),tipo=clean(b.tipo,12),contrasena=String(b.contrasena||'');
  if(!nombre||!/^[a-zA-Z0-9._-]{3,60}$/.test(usuario)||contrasena.length<10||!['ESTUDIANTE','DOCENTE'].includes(tipo)||!uuid(b.zonaId))return bad(res,'Complete nombre, usuario, tipo, zona y contraseña de al menos 10 caracteres.');
  if(correo&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo))return bad(res,'Correo inválido.');
  const cl=await pool.connect();try{await cl.query('BEGIN');
    const zona=await cl.query("SELECT id FROM zonas_parqueo WHERE id=$1 AND estado='ACTIVA' AND tipo_zona='ESTUDIANTES'",[b.zonaId]);
    if(!zona.rowCount){await cl.query('ROLLBACK');return bad(res,'Asigne una zona de propietarios válida.');}
    const rol=await cl.query("SELECT id FROM roles WHERE codigo='PROPIETARIO' AND activo=TRUE");if(!rol.rowCount)throw new Error('Rol Propietario no configurado.');
    const u=await cl.query(`INSERT INTO usuarios(nombre_usuario,hash_contrasena,nombre_completo,correo,area_institucional,rol_id,zona_asignada_id) VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING id,nombre_usuario,nombre_completo`,[usuario,hashPassword(contrasena),nombre,correo||null,tipo,rol.rows[0].id,b.zonaId]);
    await cl.query('INSERT INTO perfiles_propietarios(usuario_id,tipo) VALUES($1,$2)',[u.rows[0].id,tipo]);
    await cl.query(`INSERT INTO auditoria(usuario_id,accion,entidad,entidad_id,detalle) VALUES($1,'PROPIETARIO_REGISTRAR','usuarios',$2,$3::jsonb)`,[req.user.sub,u.rows[0].id,JSON.stringify({tipo,nombre_usuario:usuario})]);
    await cl.query('COMMIT');res.status(201).json(u.rows[0]);
  }catch(e){await cl.query('ROLLBACK');if(e.code==='23505')return res.status(409).json({message:'El nombre de usuario ya existe.'});throw e;}finally{cl.release();}
}));
propietariosRouter.patch('/:id',requirePermission('propietarios.gestionar'),asyncHandler(async(req,res)=>{
  if(!uuid(req.params.id))return bad(res,'Identificador inválido.');
  const b=req.body||{},nombre=clean(b.nombreCompleto),correo=clean(b.correo),tipo=clean(b.tipo,12),estado=clean(b.estado,20);
  if(!nombre||!['ESTUDIANTE','DOCENTE'].includes(tipo)||!['ACTIVO','DESHABILITADO'].includes(estado)||!uuid(b.zonaId))return bad(res,'Los datos del propietario no son válidos.');
  if(correo&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo))return bad(res,'Correo inválido.');
  const cl=await pool.connect();try{await cl.query('BEGIN');
    const role=await cl.query('SELECT u.id FROM usuarios u JOIN roles r ON r.id=u.rol_id WHERE u.id=$1 AND r.codigo=$2 FOR UPDATE OF u',[req.params.id,'PROPIETARIO']);
    const zona=await cl.query("SELECT id FROM zonas_parqueo WHERE id=$1 AND estado='ACTIVA' AND tipo_zona='ESTUDIANTES'",[b.zonaId]);
    if(!role.rowCount||!zona.rowCount){await cl.query('ROLLBACK');return bad(res,'Propietario o zona inválidos.');}
    await cl.query('UPDATE usuarios SET nombre_completo=$2,correo=$3,area_institucional=$4,zona_asignada_id=$5,estado=$6,actualizado_en=NOW() WHERE id=$1',[req.params.id,nombre,correo||null,tipo,b.zonaId,estado]);
    await cl.query('INSERT INTO perfiles_propietarios(usuario_id,tipo) VALUES($1,$2) ON CONFLICT(usuario_id) DO UPDATE SET tipo=EXCLUDED.tipo,actualizado_en=NOW()',[req.params.id,tipo]);
    if(estado!=='ACTIVO')await cl.query('UPDATE sesiones_autenticacion SET revocado_en=NOW() WHERE usuario_id=$1 AND revocado_en IS NULL',[req.params.id]);
    await cl.query(`INSERT INTO auditoria(usuario_id,accion,entidad,entidad_id,detalle) VALUES($1,'PROPIETARIO_ACTUALIZAR','usuarios',$2,$3::jsonb)`,[req.user.sub,req.params.id,JSON.stringify({tipo,estado})]);
    await cl.query('COMMIT');res.json({ok:true});
  }catch(e){await cl.query('ROLLBACK');throw e;}finally{cl.release();}
}));
