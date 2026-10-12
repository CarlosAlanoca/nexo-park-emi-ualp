-- V30: retain V29 data, enforce case-insensitive username uniqueness only when safe.
DO $$ BEGIN
 IF EXISTS (SELECT lower(nombre_usuario) FROM usuarios GROUP BY lower(nombre_usuario) HAVING count(*)>1) THEN
  RAISE EXCEPTION 'Hay usuarios duplicados por mayúsculas/minúsculas. Resolver antes de migrar a V30.';
 END IF;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS ux_usuarios_nombre_ci ON usuarios(lower(nombre_usuario));
INSERT INTO configuracion_sistema(clave,valor,descripcion) VALUES
 ('identidad_sistema','{"nombre":"NEXO PARK","institucion":"EMI UALP","version":"30.0.0","anterior":"PARKIA"}'::jsonb,'Identidad visual y versión')
 ON CONFLICT(clave) DO UPDATE SET valor=EXCLUDED.valor;

INSERT INTO permisos(codigo,modulo,descripcion) VALUES ('acceso.propio','Control de ingreso y salida','Consultar solo movimientos de vehículos propios') ON CONFLICT(codigo) DO NOTHING;
INSERT INTO roles_permisos(rol_id,permiso_id) SELECT r.id,p.id FROM roles r CROSS JOIN permisos p WHERE r.codigo IN ('PROPIETARIO','ADMIN') AND p.codigo='acceso.propio' ON CONFLICT DO NOTHING;
