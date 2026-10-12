import {Router} from 'express';
import {authenticate} from '../../middleware/auth.js';
export const movilRouter=Router();
movilRouter.use(authenticate);
movilRouter.get('/contexto',(req,res)=>{
 const allowed=p=>req.user.permisos.includes('*')||req.user.permisos.includes(p);
 const candidates=[['control','Control de ingreso y salida','acceso.ver'],['lugares','Gestión de lugares','panel.ver'],['reportes','Informes y reportes','reportes.generar'],['alertas','Alertas y notificaciones','alertas.ver'],['usuarios','Gestión de usuarios','usuarios.gestionar'],['auditoria','Auditoría y control','auditoria.ver'],['propietarios','Registro de propietarios','propietarios.ver']];
 res.set('Cache-Control','private, no-store').json({rol:req.user.rol,accesos:candidates.filter(x=>allowed(x[2])).map(([modulo,nombre])=>({modulo,nombre}))});
});
