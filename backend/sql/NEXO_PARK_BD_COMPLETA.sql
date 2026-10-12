-- NEXO PARK V30. Solo instalación NUEVA. No ejecutar sobre datos existentes.

-- 01_schema.sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- PARKIA EMI UALP - Modelo físico PostgreSQL en castellano.
CREATE TABLE IF NOT EXISTS zonas_parqueo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo VARCHAR(30) UNIQUE NOT NULL,
  nombre VARCHAR(120) NOT NULL,
  descripcion TEXT,
  referencia_ubicacion VARCHAR(220),
  tipo_zona VARCHAR(30) NOT NULL DEFAULT 'GENERAL' CHECK(tipo_zona IN ('GENERAL','ESTUDIANTES','AUTORIDADES','ADMINISTRATIVO','VISITANTES')),
  estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVA' CHECK(estado IN ('ACTIVA','MANTENIMIENTO','INACTIVA')),
  creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo VARCHAR(50) UNIQUE NOT NULL,
  nombre VARCHAR(120) NOT NULL,
  descripcion TEXT,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS permisos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo VARCHAR(90) UNIQUE NOT NULL,
  modulo VARCHAR(70) NOT NULL,
  descripcion TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS roles_permisos (
  rol_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permiso_id UUID NOT NULL REFERENCES permisos(id) ON DELETE CASCADE,
  PRIMARY KEY (rol_id, permiso_id)
);

CREATE TABLE IF NOT EXISTS usuarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre_usuario VARCHAR(60) UNIQUE NOT NULL,
  hash_contrasena TEXT NOT NULL,
  nombre_completo VARCHAR(170) NOT NULL,
  correo VARCHAR(170),
  area_institucional VARCHAR(120),
  rol_id UUID NOT NULL REFERENCES roles(id),
  zona_asignada_id UUID REFERENCES zonas_parqueo(id),
  estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO' CHECK(estado IN ('ACTIVO','DESHABILITADO','BLOQUEADO')),
  intentos_fallidos INT NOT NULL DEFAULT 0,
  bloqueado_hasta TIMESTAMPTZ,
  ultimo_ingreso_en TIMESTAMPTZ,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE INDEX IF NOT EXISTS ix_usuarios_nombre_usuario_ci ON usuarios(LOWER(nombre_usuario));
CREATE INDEX IF NOT EXISTS ix_usuarios_bloqueado_hasta ON usuarios(bloqueado_hasta) WHERE bloqueado_hasta IS NOT NULL;

CREATE TABLE IF NOT EXISTS sesiones_autenticacion (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  jti UUID UNIQUE NOT NULL,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expira_en TIMESTAMPTZ NOT NULL,
  revocado_en TIMESTAMPTZ,
  direccion_ip VARCHAR(80),
  agente_usuario VARCHAR(500)
);
CREATE INDEX IF NOT EXISTS ix_sesiones_auth_usuario ON sesiones_autenticacion(usuario_id);
CREATE INDEX IF NOT EXISTS ix_sesiones_auth_validas ON sesiones_autenticacion(jti,usuario_id,expira_en) WHERE revocado_en IS NULL;

CREATE TABLE IF NOT EXISTS vehiculos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  placa VARCHAR(20) NOT NULL,
  tipo_vehiculo VARCHAR(40) NOT NULL DEFAULT 'AUTOMOVIL',
  marca VARCHAR(80),
  modelo VARCHAR(80),
  color VARCHAR(60),
  referencia_propietario VARCHAR(170),
  propietario_usuario_id UUID REFERENCES usuarios(id),
  foto_vehiculo TEXT,
  foto_placa TEXT,
  categoria_usuario VARCHAR(40) NOT NULL DEFAULT 'INSTITUCIONAL' CHECK(categoria_usuario IN ('MILITAR','CIVIL','ADMINISTRATIVO','ESTUDIANTE','VISITANTE','PROVEEDOR','INSTITUCIONAL')),
  estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO' CHECK(estado IN ('ACTIVO','SUSPENDIDO','RETIRADO')),
  creado_por UUID REFERENCES usuarios(id),
  creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_vehiculo_placa_activa ON vehiculos(UPPER(placa)) WHERE estado='ACTIVO';

CREATE TABLE IF NOT EXISTS autorizaciones_vehiculares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehiculo_id UUID NOT NULL REFERENCES vehiculos(id) ON DELETE CASCADE,
  tipo_autorizacion VARCHAR(30) NOT NULL DEFAULT 'PERMANENTE' CHECK(tipo_autorizacion IN ('PERMANENTE','TEMPORAL','EXCEPCIONAL')),
  valido_desde TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  valido_hasta TIMESTAMPTZ,
  motivo TEXT,
  estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVA' CHECK(estado IN ('ACTIVA','SUSPENDIDA','VENCIDA','REVOCADA')),
  autorizado_por UUID REFERENCES usuarios(id),
  creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS dispositivos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo VARCHAR(40) UNIQUE NOT NULL,
  tipo_dispositivo VARCHAR(35) NOT NULL CHECK(tipo_dispositivo IN ('CAMARA_ACCESO_LPR','CAMARA_OCUPACION','BARRERA','NODO_PROCESAMIENTO','RED','OTRO')),
  nombre VARCHAR(130) NOT NULL,
  zona_id UUID REFERENCES zonas_parqueo(id),
  punto_acceso VARCHAR(120),
  direccion_ip INET,
  ubicacion_logica VARCHAR(220),
  estado VARCHAR(20) NOT NULL DEFAULT 'EN_LINEA' CHECK(estado IN ('EN_LINEA','FUERA_LINEA','MANTENIMIENTO','ERROR','DESHABILITADO')),
  parametros JSONB NOT NULL DEFAULT '{}'::jsonb,
  ultima_comunicacion_en TIMESTAMPTZ,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS plazas_parqueo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  zona_id UUID NOT NULL REFERENCES zonas_parqueo(id),
  codigo VARCHAR(30) NOT NULL,
  tipo_plaza VARCHAR(30) NOT NULL DEFAULT 'ESTANDAR' CHECK(tipo_plaza IN ('ESTANDAR','MOTOCICLETA','ACCESIBLE','OFICIAL','VISITANTE')),
  estado_actual VARCHAR(25) NOT NULL DEFAULT 'SIN_DATOS' CHECK(estado_actual IN ('LIBRE','OCUPADA','FUERA_SERVICIO','SIN_DATOS')),
  confianza NUMERIC(5,2),
  region_interes JSONB,
  camara_id UUID REFERENCES dispositivos(id) DEFERRABLE INITIALLY DEFERRED,
  coordenada_x INT NOT NULL DEFAULT 1,
  coordenada_y INT NOT NULL DEFAULT 1,
  habilitada BOOLEAN NOT NULL DEFAULT TRUE,
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(zona_id, codigo)
);

CREATE TABLE IF NOT EXISTS eventos_acceso (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_evento VARCHAR(20) NOT NULL CHECK(tipo_evento IN ('INGRESO','SALIDA')),
  fecha_hora TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  punto_acceso VARCHAR(120) NOT NULL,
  camara_acceso_id UUID REFERENCES dispositivos(id),
  placa_detectada VARCHAR(20),
  vehiculo_id UUID REFERENCES vehiculos(id),
  imagen_url TEXT,
  evidencia_tipo VARCHAR(30) DEFAULT 'SIN_EVIDENCIA',
  confianza_reconocimiento NUMERIC(5,2),
  resultado_validacion VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE' CHECK(resultado_validacion IN ('AUTORIZADO','DENEGADO','PENDIENTE','MANUAL','INCIERTO')),
  autorizado_manual BOOLEAN NOT NULL DEFAULT FALSE,
  autorizado_por UUID REFERENCES usuarios(id),
  observaciones TEXT,
  origen VARCHAR(30) NOT NULL DEFAULT 'CAMARA_IA' CHECK(origen IN ('CAMARA_IA','MANUAL','API','SIMULADOR')),
  creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_eventos_acceso_fecha ON eventos_acceso(fecha_hora DESC);
CREATE INDEX IF NOT EXISTS ix_eventos_acceso_placa ON eventos_acceso(UPPER(placa_detectada));

CREATE TABLE IF NOT EXISTS resultados_reconocimiento_placa (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  evento_acceso_id UUID NOT NULL REFERENCES eventos_acceso(id) ON DELETE CASCADE,
  placa_detectada VARCHAR(20),
  confianza NUMERIC(5,2),
  resultado_crudo JSONB,
  estado_validacion VARCHAR(30) NOT NULL DEFAULT 'AUTOMATICO' CHECK(estado_validacion IN ('AUTOMATICO','MANUAL_CONFIRMADO','MANUAL_CORREGIDO','RECHAZADO')),
  placa_corregida VARCHAR(20),
  validado_por UUID REFERENCES usuarios(id),
  validado_en TIMESTAMPTZ,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS eventos_ocupacion (
  id BIGSERIAL PRIMARY KEY,
  plaza_id UUID NOT NULL REFERENCES plazas_parqueo(id),
  estado_anterior VARCHAR(25),
  estado_nuevo VARCHAR(25) NOT NULL CHECK(estado_nuevo IN ('LIBRE','OCUPADA','FUERA_SERVICIO','SIN_DATOS')),
  confianza NUMERIC(5,2),
  camara_id UUID REFERENCES dispositivos(id),
  origen VARCHAR(30) NOT NULL DEFAULT 'VISION_IA' CHECK(origen IN ('VISION_IA','MANUAL','SIMULADOR','DISPOSITIVO')),
  imagen_url TEXT,
  evidencia_tipo VARCHAR(30) DEFAULT 'SIN_EVIDENCIA',
  cambiado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_eventos_ocupacion_plaza_fecha ON eventos_ocupacion(plaza_id,cambiado_en DESC);

CREATE TABLE IF NOT EXISTS alertas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_alerta VARCHAR(50) NOT NULL,
  severidad VARCHAR(20) NOT NULL DEFAULT 'MEDIA' CHECK(severidad IN ('INFO','BAJA','MEDIA','ALTA','CRITICA')),
  titulo VARCHAR(180) NOT NULL,
  descripcion TEXT NOT NULL,
  estado VARCHAR(25) NOT NULL DEFAULT 'ABIERTA' CHECK(estado IN ('ABIERTA','ATENDIDA','CERRADA')),
  zona_id UUID REFERENCES zonas_parqueo(id),
  dispositivo_id UUID REFERENCES dispositivos(id),
  plaza_id UUID REFERENCES plazas_parqueo(id),
  evento_origen_id VARCHAR(80),
  asignado_a UUID REFERENCES usuarios(id),
  abierta_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atendida_en TIMESTAMPTZ,
  cerrada_en TIMESTAMPTZ,
  cerrada_por UUID REFERENCES usuarios(id)
);
CREATE INDEX IF NOT EXISTS ix_alertas_estado_severidad ON alertas(estado,severidad,abierta_en DESC);

CREATE TABLE IF NOT EXISTS acciones_alerta (
  id BIGSERIAL PRIMARY KEY,
  alerta_id UUID NOT NULL REFERENCES alertas(id) ON DELETE CASCADE,
  usuario_id UUID REFERENCES usuarios(id),
  accion VARCHAR(30) NOT NULL,
  comentario TEXT,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS bitacora_dispositivos (
  id BIGSERIAL PRIMARY KEY,
  dispositivo_id UUID NOT NULL REFERENCES dispositivos(id) ON DELETE CASCADE,
  tipo_evento VARCHAR(50) NOT NULL,
  estado_anterior VARCHAR(20),
  estado_nuevo VARCHAR(20),
  detalle JSONB,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auditoria (
  id BIGSERIAL PRIMARY KEY,
  usuario_id UUID REFERENCES usuarios(id),
  accion VARCHAR(90) NOT NULL,
  entidad VARCHAR(90) NOT NULL,
  entidad_id VARCHAR(90),
  detalle JSONB NOT NULL DEFAULT '{}'::jsonb,
  direccion_ip INET,
  agente_usuario TEXT,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_auditoria_fecha ON auditoria(creado_en DESC);

CREATE TABLE IF NOT EXISTS respaldos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitado_por UUID REFERENCES usuarios(id),
  tipo_respaldo VARCHAR(20) NOT NULL DEFAULT 'MANUAL' CHECK(tipo_respaldo IN ('MANUAL','PROGRAMADO','RESTAURACION')),
  nombre_archivo TEXT,
  estado VARCHAR(20) NOT NULL DEFAULT 'SOLICITADO' CHECK(estado IN ('SOLICITADO','EJECUTANDO','EXITOSO','FALLIDO','DESHABILITADO')),
  mensaje TEXT,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finalizado_en TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS configuracion_sistema (
  clave VARCHAR(100) PRIMARY KEY,
  valor JSONB NOT NULL,
  descripcion TEXT,
  actualizado_por UUID REFERENCES usuarios(id),
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION actualizar_fecha_modificacion() RETURNS TRIGGER AS $$
BEGIN NEW.actualizado_en=NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_usuarios_actualizado ON usuarios;
CREATE TRIGGER trg_usuarios_actualizado BEFORE UPDATE ON usuarios FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_modificacion();
DROP TRIGGER IF EXISTS trg_vehiculos_actualizado ON vehiculos;
CREATE TRIGGER trg_vehiculos_actualizado BEFORE UPDATE ON vehiculos FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_modificacion();
DROP TRIGGER IF EXISTS trg_zonas_actualizado ON zonas_parqueo;
CREATE TRIGGER trg_zonas_actualizado BEFORE UPDATE ON zonas_parqueo FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_modificacion();
DROP TRIGGER IF EXISTS trg_dispositivos_actualizado ON dispositivos;
CREATE TRIGGER trg_dispositivos_actualizado BEFORE UPDATE ON dispositivos FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_modificacion();


-- 02_seed.sql
INSERT INTO roles(codigo,nombre,descripcion) VALUES
('ADMINISTRADOR_SISTEMA','Administrador del sistema','Administración integral, seguridad y configuración.'),
('DIRECCION_GRADO','Dirección de Grado','Consulta ejecutiva del estado general y reportes.'),
('JEFE_OPERACIONES','Jefe de Operaciones','Gestión operativa de parqueos, vehículos, acceso y alertas.'),
('PERSONAL_GUARDIA','Personal de Guardia','Control del ingreso vehicular, validaciones excepcionales y eventos recientes.'),
('SOPORTE_TIC','Soporte TIC','Usuarios, dispositivos, auditoría, respaldo y continuidad.'),
('INFRAESTRUCTURA','Unidad de Infraestructura','Zonas, plazas, cámaras de ocupación y mantenimiento.'),
('RECURSOS_HUMANOS','Recursos Humanos','Consulta de vehículos, historial y reportes autorizados.'),
('ESTUDIANTE','Estudiante','Consulta exclusiva de disponibilidad de parqueos en su zona asignada.')
ON CONFLICT(codigo) DO NOTHING;

INSERT INTO permisos(codigo,modulo,descripcion) VALUES
('panel.ver','Panel','Ver panel general institucional.'),
('usuarios.gestionar','Usuarios','Administrar usuarios, roles y estados.'),
('usuarios.permisos','Usuarios','Administrar privilegios asignados a roles.'),
('vehiculos.ver','Vehículos','Consultar vehículos y autorizaciones.'),
('vehiculos.gestionar','Vehículos','Registrar y modificar vehículos y autorizaciones.'),
('acceso.ver','Acceso','Consultar eventos de ingreso y salida.'),
('acceso.validar','Acceso','Realizar validación manual excepcional de placa.'),
('parqueo.ver','Parqueos','Consultar zonas, plazas y dispositivos.'),
('parqueo.gestionar','Parqueos','Administrar zonas, plazas y dispositivos.'),
('ocupacion.ver','Ocupación','Consultar estados libre/ocupado determinados por visión artificial.'),
('ocupacion.actualizar','Ocupación','Registrar o simular cambios de ocupación.'),
('alertas.ver','Alertas','Consultar alertas operativas.'),
('alertas.gestionar','Alertas','Atender y cerrar alertas.'),
('historial.ver','Historial','Consultar trazabilidad histórica.'),
('reportes.generar','Reportes','Consultar y generar reportes.'),
('auditoria.ver','Auditoría','Consultar acciones registradas en auditoría.'),
('respaldos.gestionar','Respaldos','Solicitar y consultar respaldos.'),
('dispositivos.gestionar','Dispositivos','Administrar cámaras y dispositivos.'),
('configuracion.gestionar','Configuración','Administrar configuración técnica.'),
('estudiante.mi_parqueo','Estudiante','Ver únicamente disponibilidad y mapa de la zona asignada.')
ON CONFLICT(codigo) DO NOTHING;

-- Administrador: todos los permisos.
INSERT INTO roles_permisos(rol_id,permiso_id)
SELECT r.id,p.id FROM roles r CROSS JOIN permisos p WHERE r.codigo='ADMINISTRADOR_SISTEMA' ON CONFLICT DO NOTHING;

-- Dirección: lectura ejecutiva.
INSERT INTO roles_permisos(rol_id,permiso_id)
SELECT r.id,p.id FROM roles r JOIN permisos p ON p.codigo = ANY(ARRAY['panel.ver','parqueo.ver','ocupacion.ver','alertas.ver','historial.ver','reportes.generar'])
WHERE r.codigo='DIRECCION_GRADO' ON CONFLICT DO NOTHING;

-- Operaciones.
INSERT INTO roles_permisos(rol_id,permiso_id)
SELECT r.id,p.id FROM roles r JOIN permisos p ON p.codigo = ANY(ARRAY['panel.ver','vehiculos.ver','vehiculos.gestionar','acceso.ver','acceso.validar','parqueo.ver','ocupacion.ver','alertas.ver','alertas.gestionar','historial.ver','reportes.generar'])
WHERE r.codigo='JEFE_OPERACIONES' ON CONFLICT DO NOTHING;

-- Guardia.
INSERT INTO roles_permisos(rol_id,permiso_id)
SELECT r.id,p.id FROM roles r JOIN permisos p ON p.codigo = ANY(ARRAY['acceso.ver','acceso.validar','vehiculos.ver','alertas.ver','historial.ver'])
WHERE r.codigo='PERSONAL_GUARDIA' ON CONFLICT DO NOTHING;

-- TIC.
INSERT INTO roles_permisos(rol_id,permiso_id)
SELECT r.id,p.id FROM roles r JOIN permisos p ON p.codigo = ANY(ARRAY['panel.ver','usuarios.gestionar','parqueo.ver','alertas.ver','auditoria.ver','respaldos.gestionar','dispositivos.gestionar','configuracion.gestionar'])
WHERE r.codigo='SOPORTE_TIC' ON CONFLICT DO NOTHING;

-- Infraestructura.
INSERT INTO roles_permisos(rol_id,permiso_id)
SELECT r.id,p.id FROM roles r JOIN permisos p ON p.codigo = ANY(ARRAY['parqueo.ver','parqueo.gestionar','ocupacion.ver','ocupacion.actualizar','alertas.ver','alertas.gestionar','dispositivos.gestionar'])
WHERE r.codigo='INFRAESTRUCTURA' ON CONFLICT DO NOTHING;

-- RRHH.
INSERT INTO roles_permisos(rol_id,permiso_id)
SELECT r.id,p.id FROM roles r JOIN permisos p ON p.codigo = ANY(ARRAY['vehiculos.ver','historial.ver','reportes.generar'])
WHERE r.codigo='RECURSOS_HUMANOS' ON CONFLICT DO NOTHING;

-- Estudiante: SOLO su parqueo asignado.
INSERT INTO roles_permisos(rol_id,permiso_id)
SELECT r.id,p.id FROM roles r JOIN permisos p ON p.codigo='estudiante.mi_parqueo'
WHERE r.codigo='ESTUDIANTE' ON CONFLICT DO NOTHING;

INSERT INTO zonas_parqueo(codigo,nombre,descripcion,referencia_ubicacion,tipo_zona) VALUES
('Z-EST-TRASERA','Zona Estudiantes - Sector Trasero','Área de parqueo destinada a estudiantes. Es la única zona visible para el rol ESTUDIANTE.','Parte trasera de la EMI UALP','ESTUDIANTES'),
('Z-AUTORIDADES','Zona Autoridades','Área de parqueo institucional para autoridades y vehículos oficiales.','Sector administrativo','AUTORIDADES'),
('Z-ADMIN','Zona Administrativa','Área de parqueo para personal administrativo autorizado.','Sector administrativo','ADMINISTRATIVO')
ON CONFLICT(codigo) DO NOTHING;

-- Una cámara de acceso LPR/OCR valida placas; cámaras independientes observan la ocupación.
INSERT INTO dispositivos(codigo,tipo_dispositivo,nombre,zona_id,punto_acceso,ubicacion_logica,estado,ultima_comunicacion_en)
SELECT 'CAM-LPR-ING-01','CAMARA_ACCESO_LPR','Cámara IA de control de placas - ingreso',NULL,'INGRESO PRINCIPAL','Carril de ingreso vehicular','EN_LINEA',NOW()
ON CONFLICT(codigo) DO NOTHING;
INSERT INTO dispositivos(codigo,tipo_dispositivo,nombre,zona_id,ubicacion_logica,estado,ultima_comunicacion_en)
SELECT 'CAM-OCP-TR-01','CAMARA_OCUPACION','Cámara IA ocupación - Trasera 1',z.id,'Cobertura plazas E01-E10','EN_LINEA',NOW() FROM zonas_parqueo z WHERE z.codigo='Z-EST-TRASERA'
ON CONFLICT(codigo) DO NOTHING;
INSERT INTO dispositivos(codigo,tipo_dispositivo,nombre,zona_id,ubicacion_logica,estado,ultima_comunicacion_en)
SELECT 'CAM-OCP-TR-02','CAMARA_OCUPACION','Cámara IA ocupación - Trasera 2',z.id,'Cobertura plazas E11-E20','EN_LINEA',NOW() FROM zonas_parqueo z WHERE z.codigo='Z-EST-TRASERA'
ON CONFLICT(codigo) DO NOTHING;

-- 20 plazas del sector trasero de estudiantes, con posiciones para el mapa.
INSERT INTO plazas_parqueo(zona_id,codigo,tipo_plaza,estado_actual,confianza,camara_id,coordenada_x,coordenada_y)
SELECT z.id,x.codigo,x.tipo,x.estado,x.confianza,d.id,x.x,x.y
FROM zonas_parqueo z
JOIN (VALUES
(1,'E01','ESTANDAR','OCUPADA',97.2,1,1),(2,'E02','ESTANDAR','LIBRE',98.6,2,1),(3,'E03','ESTANDAR','LIBRE',97.9,3,1),(4,'E04','ESTANDAR','OCUPADA',96.8,4,1),(5,'E05','ACCESIBLE','LIBRE',99.1,5,1),
(6,'E06','ESTANDAR','OCUPADA',96.5,1,2),(7,'E07','ESTANDAR','LIBRE',98.2,2,2),(8,'E08','ESTANDAR','OCUPADA',97.4,3,2),(9,'E09','ESTANDAR','LIBRE',98.7,4,2),(10,'E10','ESTANDAR','LIBRE',98.9,5,2),
(11,'E11','ESTANDAR','LIBRE',97.8,1,3),(12,'E12','ESTANDAR','OCUPADA',96.9,2,3),(13,'E13','ESTANDAR','LIBRE',98.4,3,3),(14,'E14','ESTANDAR','LIBRE',98.0,4,3),(15,'E15','ESTANDAR','OCUPADA',96.2,5,3),
(16,'E16','ESTANDAR','LIBRE',99.0,1,4),(17,'E17','ESTANDAR','OCUPADA',95.8,2,4),(18,'E18','ESTANDAR','LIBRE',98.3,3,4),(19,'E19','ESTANDAR','LIBRE',97.7,4,4),(20,'E20','ESTANDAR','OCUPADA',96.6,5,4)
) AS x(n,codigo,tipo,estado,confianza,x,y) ON TRUE
JOIN dispositivos d ON d.codigo=CASE WHEN x.n<=10 THEN 'CAM-OCP-TR-01' ELSE 'CAM-OCP-TR-02' END
WHERE z.codigo='Z-EST-TRASERA'
ON CONFLICT(zona_id,codigo) DO NOTHING;

INSERT INTO configuracion_sistema(clave,valor,descripcion) VALUES
('umbral_alerta_capacidad','80'::jsonb,'Porcentaje de ocupación para alerta preventiva.'),
('minutos_inactividad_sesion','20'::jsonb,'Tiempo de inactividad antes de bloqueo de sesión.'),
('intervalo_actualizacion_estudiante_segundos','5'::jsonb,'Frecuencia de actualización automática del mapa del estudiante.'),
('metodo_control_ingreso','"CAMARA_LPR_VISION_IA"'::jsonb,'El ingreso se valida mediante cámara de visión artificial para lectura de placas.')
ON CONFLICT(clave) DO NOTHING;

INSERT INTO vehiculos(placa,tipo_vehiculo,marca,modelo,color,referencia_propietario,categoria_usuario,estado) VALUES
('1234ABC','AUTOMOVIL','Toyota','Corolla','Blanco','Vehículo institucional de demostración','INSTITUCIONAL','ACTIVO'),
('5678XYZ','CAMIONETA','Nissan','Frontier','Gris','Visitante autorizado','VISITANTE','ACTIVO'),
('EST2026','AUTOMOVIL','Suzuki','Swift','Azul','Estudiante de demostración','ESTUDIANTE','ACTIVO')
ON CONFLICT DO NOTHING;

INSERT INTO autorizaciones_vehiculares(vehiculo_id,tipo_autorizacion,valido_desde,valido_hasta,motivo,estado)
SELECT id,'PERMANENTE',NOW()-INTERVAL '30 days',NULL,'Registro institucional de demostración','ACTIVA' FROM vehiculos WHERE placa IN ('1234ABC','EST2026')
AND NOT EXISTS(SELECT 1 FROM autorizaciones_vehiculares a WHERE a.vehiculo_id=vehiculos.id);
INSERT INTO autorizaciones_vehiculares(vehiculo_id,tipo_autorizacion,valido_desde,valido_hasta,motivo,estado)
SELECT id,'TEMPORAL',NOW()-INTERVAL '1 day',NOW()+INTERVAL '7 days','Visita académica de demostración','ACTIVA' FROM vehiculos WHERE placa='5678XYZ'
AND NOT EXISTS(SELECT 1 FROM autorizaciones_vehiculares a WHERE a.vehiculo_id=vehiculos.id);


-- 03_views_functions.sql
CREATE OR REPLACE VIEW vista_disponibilidad_zonas AS
SELECT z.id zona_id,z.codigo,z.nombre,z.tipo_zona,z.estado,
       COUNT(p.id) total_plazas,
       COUNT(p.id) FILTER (WHERE p.estado_actual='LIBRE' AND p.habilitada) plazas_libres,
       COUNT(p.id) FILTER (WHERE p.estado_actual='OCUPADA' AND p.habilitada) plazas_ocupadas,
       COUNT(p.id) FILTER (WHERE p.estado_actual='FUERA_SERVICIO' OR NOT p.habilitada) plazas_fuera_servicio,
       COUNT(p.id) FILTER (WHERE p.estado_actual='SIN_DATOS') plazas_sin_datos,
       ROUND(100.0 * COUNT(p.id) FILTER (WHERE p.estado_actual='OCUPADA') / NULLIF(COUNT(p.id),0),2) porcentaje_ocupacion
FROM zonas_parqueo z LEFT JOIN plazas_parqueo p ON p.zona_id=z.id
GROUP BY z.id,z.codigo,z.nombre,z.tipo_zona,z.estado;

CREATE OR REPLACE VIEW vista_ultimos_eventos_acceso AS
SELECT e.id,e.tipo_evento,e.fecha_hora,e.punto_acceso,e.placa_detectada,e.confianza_reconocimiento,e.resultado_validacion,
       v.referencia_propietario,v.categoria_usuario,d.nombre camara_acceso
FROM eventos_acceso e LEFT JOIN vehiculos v ON v.id=e.vehiculo_id LEFT JOIN dispositivos d ON d.id=e.camara_acceso_id;

CREATE OR REPLACE FUNCTION cambiar_estado_plaza(p_plaza UUID,p_estado VARCHAR,p_confianza NUMERIC,p_camara UUID,p_origen VARCHAR DEFAULT 'VISION_IA')
RETURNS plazas_parqueo AS $$
DECLARE anterior VARCHAR; fila plazas_parqueo;
BEGIN
 SELECT estado_actual INTO anterior FROM plazas_parqueo WHERE id=p_plaza FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Plaza no encontrada'; END IF;
 UPDATE plazas_parqueo SET estado_actual=p_estado,confianza=p_confianza,camara_id=COALESCE(p_camara,camara_id),actualizado_en=NOW() WHERE id=p_plaza RETURNING * INTO fila;
 INSERT INTO eventos_ocupacion(plaza_id,estado_anterior,estado_nuevo,confianza,camara_id,origen) VALUES(p_plaza,anterior,p_estado,p_confianza,p_camara,p_origen);
 RETURN fila;
END; $$ LANGUAGE plpgsql;


-- 04_alertas_v11.sql
-- Migración idempotente V11, compatible con la tabla existente.
ALTER TABLE alertas ADD COLUMN IF NOT EXISTS clave_incidente VARCHAR(160);
CREATE UNIQUE INDEX IF NOT EXISTS ux_alertas_incidente_activo ON alertas(clave_incidente) WHERE clave_incidente IS NOT NULL AND estado <> 'CERRADA';
CREATE INDEX IF NOT EXISTS ix_acciones_alerta_fecha ON acciones_alerta(alerta_id,creado_en);


-- 05_auditoria_v15.sql
-- PARKIA V15: ejecutar idempotentemente sobre instalaciones existentes.
CREATE INDEX IF NOT EXISTS ix_auditoria_accion_fecha ON auditoria(accion, creado_en DESC);
CREATE INDEX IF NOT EXISTS ix_auditoria_usuario_fecha ON auditoria(usuario_id, creado_en DESC);
CREATE INDEX IF NOT EXISTS ix_bitacora_dispositivos_fecha ON bitacora_dispositivos(creado_en DESC);
CREATE INDEX IF NOT EXISTS ix_respaldos_fecha ON respaldos(creado_en DESC);
CREATE OR REPLACE FUNCTION parkia_bitacora_dispositivo_estado() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF OLD.estado IS DISTINCT FROM NEW.estado THEN
   INSERT INTO bitacora_dispositivos(dispositivo_id,tipo_evento,estado_anterior,estado_nuevo,detalle)
   VALUES(NEW.id,'CAMBIO_ESTADO',OLD.estado,NEW.estado,
     jsonb_build_object('codigo', NEW.codigo, 'nombre', NEW.nombre, 'origen','CAMBIO_DISPOSITIVO'));
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_parkia_dispositivo_estado ON dispositivos;
CREATE TRIGGER trg_parkia_dispositivo_estado AFTER UPDATE OF estado ON dispositivos
FOR EACH ROW EXECUTE FUNCTION parkia_bitacora_dispositivo_estado();


-- 06_mapeo_real_v17.sql

-- PARKIA V17 · Mapeo real del campus EMI UALP
-- Actualiza la nomenclatura y registra plazas/cámaras de acuerdo con la distribución validada en campo.

INSERT INTO zonas_parqueo(codigo,nombre,descripcion,referencia_ubicacion,tipo_zona)
VALUES
('Z-EST-TRASERA','Zona Estudiantes - Sector Trasero','Parqueo de estudiantes (motos) ubicado en la parte trasera del campus.','Parte trasera del campus EMI UALP','ESTUDIANTES'),
('Z-AUTORIDADES','Zona Autoridades - Frente Izquierdo','Parqueo institucional de autoridades ubicado en el frente izquierdo del campus.','Frente izquierdo del campus EMI UALP','AUTORIDADES'),
('Z-ADMIN','Zona Administrativa - Frente Derecho','Parqueo para personal administrativo ubicado en el frente derecho del campus.','Frente derecho del campus EMI UALP','ADMINISTRATIVO')
ON CONFLICT(codigo) DO NOTHING;

UPDATE zonas_parqueo SET
  nombre=CASE codigo
    WHEN 'Z-EST-TRASERA' THEN 'Zona Estudiantes - Sector Trasero'
    WHEN 'Z-AUTORIDADES' THEN 'Zona Autoridades - Frente Izquierdo'
    WHEN 'Z-ADMIN' THEN 'Zona Administrativa - Frente Derecho'
    ELSE nombre END,
  descripcion=CASE codigo
    WHEN 'Z-EST-TRASERA' THEN 'Parqueo de estudiantes (motos) ubicado en la parte trasera del campus.'
    WHEN 'Z-AUTORIDADES' THEN 'Parqueo institucional de autoridades ubicado en el frente izquierdo del campus.'
    WHEN 'Z-ADMIN' THEN 'Parqueo para personal administrativo ubicado en el frente derecho del campus.'
    ELSE descripcion END,
  referencia_ubicacion=CASE codigo
    WHEN 'Z-EST-TRASERA' THEN 'Parte trasera del campus EMI UALP'
    WHEN 'Z-AUTORIDADES' THEN 'Frente izquierdo del campus EMI UALP'
    WHEN 'Z-ADMIN' THEN 'Frente derecho del campus EMI UALP'
    ELSE referencia_ubicacion END,
  tipo_zona=CASE codigo
    WHEN 'Z-EST-TRASERA' THEN 'ESTUDIANTES'
    WHEN 'Z-AUTORIDADES' THEN 'AUTORIDADES'
    WHEN 'Z-ADMIN' THEN 'ADMINISTRATIVO'
    ELSE tipo_zona END
WHERE codigo IN ('Z-EST-TRASERA','Z-AUTORIDADES','Z-ADMIN');

INSERT INTO dispositivos(codigo,tipo_dispositivo,nombre,zona_id,punto_acceso,ubicacion_logica,estado,ultima_comunicacion_en)
SELECT 'CAM-LPR-ING-01','CAMARA_ACCESO_LPR','Cámara IA de control de placas - acceso principal',NULL,'INGRESO PRINCIPAL','Control general de ingreso vehicular','EN_LINEA',NOW()
WHERE NOT EXISTS (SELECT 1 FROM dispositivos WHERE codigo='CAM-LPR-ING-01');

INSERT INTO dispositivos(codigo,tipo_dispositivo,nombre,zona_id,ubicacion_logica,estado,ultima_comunicacion_en)
SELECT 'CAM-OCP-EST-01','CAMARA_OCUPACION','Cámara IA ocupación - Estudiantes trasero',z.id,'Cobertura general del parqueo de estudiantes (motos)','EN_LINEA',NOW()
FROM zonas_parqueo z WHERE z.codigo='Z-EST-TRASERA'
AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE codigo='CAM-OCP-EST-01');

INSERT INTO dispositivos(codigo,tipo_dispositivo,nombre,zona_id,ubicacion_logica,estado,ultima_comunicacion_en)
SELECT 'CAM-OCP-AUT-01','CAMARA_OCUPACION','Cámara IA ocupación - Autoridades frente izquierdo',z.id,'Cobertura del frente izquierdo para autoridades','EN_LINEA',NOW()
FROM zonas_parqueo z WHERE z.codigo='Z-AUTORIDADES'
AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE codigo='CAM-OCP-AUT-01');

INSERT INTO dispositivos(codigo,tipo_dispositivo,nombre,zona_id,ubicacion_logica,estado,ultima_comunicacion_en)
SELECT 'CAM-OCP-ADM-01','CAMARA_OCUPACION','Cámara IA ocupación - Administrativo frente derecho',z.id,'Cobertura del frente derecho para administrativos','EN_LINEA',NOW()
FROM zonas_parqueo z WHERE z.codigo='Z-ADMIN'
AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE codigo='CAM-OCP-ADM-01');

-- Plazas de estudiantes (motos) · sector trasero
INSERT INTO plazas_parqueo(zona_id,codigo,tipo_plaza,estado_actual,confianza,camara_id,coordenada_x,coordenada_y)
SELECT z.id, v.codigo, 'MOTOCICLETA', v.estado, v.confianza, d.id, v.x, v.y
FROM zonas_parqueo z
JOIN dispositivos d ON d.codigo='CAM-OCP-EST-01'
JOIN (VALUES
('EM01','LIBRE',1,1,97.4),('EM02','OCUPADA',2,1,95.8),('EM03','LIBRE',3,1,98.1),('EM04','LIBRE',4,1,97.9),('EM05','OCUPADA',5,1,95.7),('EM06','LIBRE',6,1,98.0),
('EM07','LIBRE',1,2,97.6),('EM08','OCUPADA',2,2,96.1),('EM09','LIBRE',3,2,98.4),('EM10','LIBRE',4,2,97.8),('EM11','OCUPADA',5,2,95.9),('EM12','LIBRE',6,2,98.2),
('EM13','LIBRE',1,3,97.7),('EM14','LIBRE',2,3,98.0),('EM15','OCUPADA',3,3,95.5),('EM16','LIBRE',4,3,97.5),('EM17','LIBRE',5,3,98.6),('EM18','OCUPADA',6,3,95.3),
('EM19','LIBRE',1,4,97.8),('EM20','LIBRE',2,4,98.2),('EM21','OCUPADA',3,4,95.0),('EM22','LIBRE',4,4,97.6),('EM23','LIBRE',5,4,98.3),('EM24','OCUPADA',6,4,95.4)
) AS v(codigo,estado,x,y,confianza) ON TRUE
WHERE z.codigo='Z-EST-TRASERA'
AND NOT EXISTS (SELECT 1 FROM plazas_parqueo p WHERE p.zona_id=z.id AND p.codigo=v.codigo);

-- Plazas para autoridades · frente izquierdo
INSERT INTO plazas_parqueo(zona_id,codigo,tipo_plaza,estado_actual,confianza,camara_id,coordenada_x,coordenada_y)
SELECT z.id, v.codigo, 'OFICIAL', v.estado, v.confianza, d.id, v.x, v.y
FROM zonas_parqueo z
JOIN dispositivos d ON d.codigo='CAM-OCP-AUT-01'
JOIN (VALUES
('AU01','LIBRE',1,1,97.8),('AU02','OCUPADA',2,1,96.2),('AU03','LIBRE',3,1,98.0),('AU04','LIBRE',4,1,97.4),
('AU05','OCUPADA',1,2,95.9),('AU06','LIBRE',2,2,98.3),('AU07','LIBRE',3,2,97.7),('AU08','OCUPADA',4,2,95.6)
) AS v(codigo,estado,x,y,confianza) ON TRUE
WHERE z.codigo='Z-AUTORIDADES'
AND NOT EXISTS (SELECT 1 FROM plazas_parqueo p WHERE p.zona_id=z.id AND p.codigo=v.codigo);

-- Plazas administrativas · frente derecho
INSERT INTO plazas_parqueo(zona_id,codigo,tipo_plaza,estado_actual,confianza,camara_id,coordenada_x,coordenada_y)
SELECT z.id, v.codigo, 'ESTANDAR', v.estado, v.confianza, d.id, v.x, v.y
FROM zonas_parqueo z
JOIN dispositivos d ON d.codigo='CAM-OCP-ADM-01'
JOIN (VALUES
('AD01','LIBRE',1,1,98.4),('AD02','OCUPADA',2,1,95.2),('AD03','LIBRE',3,1,98.1),
('AD04','LIBRE',1,2,97.9),('AD05','OCUPADA',2,2,95.7),('AD06','LIBRE',3,2,98.2),
('AD07','LIBRE',1,3,97.6),('AD08','OCUPADA',2,3,95.9),('AD09','LIBRE',3,3,98.0)
) AS v(codigo,estado,x,y,confianza) ON TRUE
WHERE z.codigo='Z-ADMIN'
AND NOT EXISTS (SELECT 1 FROM plazas_parqueo p WHERE p.zona_id=z.id AND p.codigo=v.codigo);


-- 07_mapa_rectangulos_v26.sql

-- PARKIA V26 · Implantación basada en croquis oficial con rectángulos
-- Refuerza la distribución real del campus, incorpora el parqueo de motocicletas estudiantiles
-- y amplía el número de plazas para aproximarse a la geometría mostrada en el croquis validado.

INSERT INTO zonas_parqueo(codigo,nombre,descripcion,referencia_ubicacion,tipo_zona)
VALUES
('Z-EST-TRASERA','Zona Estudiantes - Sector Trasero','Parqueo principal de estudiantes, de acuerdo con la distribución de rectángulos del croquis oficial.','Sector posterior y central del campus EMI UALP','ESTUDIANTES'),
('Z-EST-MOTO','Zona Estudiantes - Motos','Parqueo lateral de motocicletas estudiantiles, ubicado en el costado oeste del campus.','Lateral oeste del campus EMI UALP','ESTUDIANTES'),
('Z-AUTORIDADES','Zona Autoridades - Frente Izquierdo','Parqueo institucional reservado para autoridades, según croquis oficial.','Frente derecho-oriental del campus EMI UALP','AUTORIDADES'),
('Z-ADMIN','Zona Administrativa - Frente Derecho','Parqueo operativo para personal administrativo, según croquis oficial.','Frente sur-oriental del campus EMI UALP','ADMINISTRATIVO')
ON CONFLICT(codigo) DO NOTHING;

UPDATE zonas_parqueo SET
  nombre=CASE codigo
    WHEN 'Z-EST-TRASERA' THEN 'Zona Estudiantes - Sector Trasero'
    WHEN 'Z-EST-MOTO' THEN 'Zona Estudiantes - Motos'
    WHEN 'Z-AUTORIDADES' THEN 'Zona Autoridades - Frente Izquierdo'
    WHEN 'Z-ADMIN' THEN 'Zona Administrativa - Frente Derecho'
    ELSE nombre END,
  descripcion=CASE codigo
    WHEN 'Z-EST-TRASERA' THEN 'Parqueo principal de estudiantes, de acuerdo con la distribución de rectángulos del croquis oficial.'
    WHEN 'Z-EST-MOTO' THEN 'Parqueo lateral de motocicletas estudiantiles, ubicado en el costado oeste del campus.'
    WHEN 'Z-AUTORIDADES' THEN 'Parqueo institucional reservado para autoridades, según croquis oficial.'
    WHEN 'Z-ADMIN' THEN 'Parqueo operativo para personal administrativo, según croquis oficial.'
    ELSE descripcion END,
  referencia_ubicacion=CASE codigo
    WHEN 'Z-EST-TRASERA' THEN 'Sector posterior y central del campus EMI UALP'
    WHEN 'Z-EST-MOTO' THEN 'Lateral oeste del campus EMI UALP'
    WHEN 'Z-AUTORIDADES' THEN 'Frente derecho-oriental del campus EMI UALP'
    WHEN 'Z-ADMIN' THEN 'Frente sur-oriental del campus EMI UALP'
    ELSE referencia_ubicacion END,
  tipo_zona=CASE codigo
    WHEN 'Z-EST-TRASERA' THEN 'ESTUDIANTES'
    WHEN 'Z-EST-MOTO' THEN 'ESTUDIANTES'
    WHEN 'Z-AUTORIDADES' THEN 'AUTORIDADES'
    WHEN 'Z-ADMIN' THEN 'ADMINISTRATIVO'
    ELSE tipo_zona END
WHERE codigo IN ('Z-EST-TRASERA','Z-EST-MOTO','Z-AUTORIDADES','Z-ADMIN');

INSERT INTO dispositivos(codigo,tipo_dispositivo,nombre,zona_id,ubicacion_logica,estado,ultima_comunicacion_en)
SELECT 'CAM-OCP-MOTO-01','CAMARA_OCUPACION','Cámara IA ocupación - Estudiantes moto',z.id,'Cobertura del lateral oeste para motocicletas estudiantiles','EN_LINEA',NOW()
FROM zonas_parqueo z WHERE z.codigo='Z-EST-MOTO'
AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE codigo='CAM-OCP-MOTO-01');

UPDATE dispositivos SET nombre='Cámara IA ocupación - Estudiantes sector trasero', ubicacion_logica='Cobertura del parqueo principal de estudiantes' WHERE codigo='CAM-OCP-EST-01';
UPDATE dispositivos SET nombre='Cámara IA ocupación - Autoridades', ubicacion_logica='Cobertura del parqueo de autoridades según croquis oficial' WHERE codigo='CAM-OCP-AUT-01';
UPDATE dispositivos SET nombre='Cámara IA ocupación - Administrativo', ubicacion_logica='Cobertura del parqueo administrativo según croquis oficial' WHERE codigo='CAM-OCP-ADM-01';

UPDATE plazas_parqueo p SET tipo_plaza='ESTANDAR'
FROM zonas_parqueo z WHERE p.zona_id=z.id AND z.codigo='Z-EST-TRASERA';
UPDATE plazas_parqueo p SET tipo_plaza='MOTOCICLETA'
FROM zonas_parqueo z WHERE p.zona_id=z.id AND z.codigo='Z-EST-MOTO';
UPDATE plazas_parqueo p SET tipo_plaza='OFICIAL'
FROM zonas_parqueo z WHERE p.zona_id=z.id AND z.codigo='Z-AUTORIDADES';
UPDATE plazas_parqueo p SET tipo_plaza='ESTANDAR'
FROM zonas_parqueo z WHERE p.zona_id=z.id AND z.codigo='Z-ADMIN';

-- Estudiantes
INSERT INTO plazas_parqueo(zona_id,codigo,tipo_plaza,estado_actual,confianza,camara_id,coordenada_x,coordenada_y)
SELECT z.id, v.codigo, 'ESTANDAR', v.estado, v.confianza, d.id, v.x, v.y
FROM zonas_parqueo z
JOIN dispositivos d ON d.codigo='CAM-OCP-EST-01'
JOIN (VALUES
('EM01','OCUPADA',1,1,95.4),
('EM02','LIBRE',2,1,98.6),
('EM03','LIBRE',3,1,98.6),
('EM04','OCUPADA',4,1,95.4),
('EM05','LIBRE',5,1,98.6),
('EM06','OCUPADA',6,1,95.4),
('EM07','LIBRE',7,1,98.6),
('EM08','LIBRE',8,1,98.6),
('EM09','OCUPADA',9,1,95.4),
('EM10','LIBRE',10,1,98.6),
('EM11','OCUPADA',1,2,95.4),
('EM12','LIBRE',2,2,98.6),
('EM13','LIBRE',3,2,98.6),
('EM14','OCUPADA',4,2,95.4),
('EM15','LIBRE',5,2,98.6),
('EM16','OCUPADA',6,2,95.4),
('EM17','LIBRE',7,2,98.6),
('EM18','LIBRE',8,2,98.6),
('EM19','OCUPADA',9,2,95.4),
('EM20','LIBRE',10,2,98.6),
('EM21','OCUPADA',1,3,95.4),
('EM22','LIBRE',2,3,98.6),
('EM23','LIBRE',3,3,98.6),
('EM24','OCUPADA',4,3,95.4),
('EM25','LIBRE',5,3,98.6),
('EM26','OCUPADA',6,3,95.4),
('EM27','LIBRE',7,3,98.6),
('EM28','LIBRE',8,3,98.6),
('EM29','OCUPADA',9,3,95.4),
('EM30','LIBRE',10,3,98.6),
('EM31','OCUPADA',1,4,95.4),
('EM32','LIBRE',2,4,98.6),
('EM33','LIBRE',3,4,98.6),
('EM34','OCUPADA',4,4,95.4),
('EM35','LIBRE',5,4,98.6),
('EM36','OCUPADA',6,4,95.4),
('EM37','LIBRE',7,4,98.6),
('EM38','LIBRE',8,4,98.6),
('EM39','OCUPADA',9,4,95.4),
('EM40','LIBRE',10,4,98.6),
('EM41','OCUPADA',1,5,95.4),
('EM42','LIBRE',2,5,98.6),
('EM43','LIBRE',3,5,98.6),
('EM44','OCUPADA',4,5,95.4),
('EM45','LIBRE',5,5,98.6),
('EM46','OCUPADA',6,5,95.4),
('EM47','LIBRE',7,5,98.6),
('EM48','LIBRE',8,5,98.6),
('EM49','OCUPADA',9,5,95.4),
('EM50','LIBRE',10,5,98.6),
('EM51','OCUPADA',1,6,95.4),
('EM52','LIBRE',2,6,98.6),
('EM53','LIBRE',3,6,98.6),
('EM54','OCUPADA',4,6,95.4),
('EM55','LIBRE',5,6,98.6),
('EM56','OCUPADA',6,6,95.4),
('EM57','LIBRE',7,6,98.6),
('EM58','LIBRE',8,6,98.6),
('EM59','OCUPADA',9,6,95.4),
('EM60','LIBRE',10,6,98.6),
('EM61','OCUPADA',1,7,95.4),
('EM62','LIBRE',2,7,98.6)
) AS v(codigo,estado,x,y,confianza) ON TRUE
WHERE z.codigo='Z-EST-TRASERA'
AND NOT EXISTS (SELECT 1 FROM plazas_parqueo p WHERE p.zona_id=z.id AND p.codigo=v.codigo);

-- Estudiantes moto
INSERT INTO plazas_parqueo(zona_id,codigo,tipo_plaza,estado_actual,confianza,camara_id,coordenada_x,coordenada_y)
SELECT z.id, v.codigo, 'MOTOCICLETA', v.estado, v.confianza, d.id, v.x, v.y
FROM zonas_parqueo z
JOIN dispositivos d ON d.codigo='CAM-OCP-MOTO-01'
JOIN (VALUES
('MT01','LIBRE',1,1,98.6),
('MT02','OCUPADA',2,1,95.4),
('MT03','LIBRE',3,1,98.6),
('MT04','LIBRE',4,1,98.6)
) AS v(codigo,estado,x,y,confianza) ON TRUE
WHERE z.codigo='Z-EST-MOTO'
AND NOT EXISTS (SELECT 1 FROM plazas_parqueo p WHERE p.zona_id=z.id AND p.codigo=v.codigo);

-- Autoridades
INSERT INTO plazas_parqueo(zona_id,codigo,tipo_plaza,estado_actual,confianza,camara_id,coordenada_x,coordenada_y)
SELECT z.id, v.codigo, 'OFICIAL', v.estado, v.confianza, d.id, v.x, v.y
FROM zonas_parqueo z
JOIN dispositivos d ON d.codigo='CAM-OCP-AUT-01'
JOIN (VALUES
('AU01','OCUPADA',1,1,95.4),
('AU02','LIBRE',2,1,98.6),
('AU03','LIBRE',3,1,98.6),
('AU04','LIBRE',4,1,98.6),
('AU05','OCUPADA',5,1,95.4),
('AU06','LIBRE',6,1,98.6),
('AU07','LIBRE',7,1,98.6),
('AU08','LIBRE',8,1,98.6),
('AU09','OCUPADA',9,1,95.4),
('AU10','LIBRE',10,1,98.6),
('AU11','LIBRE',1,2,98.6),
('AU12','LIBRE',2,2,98.6),
('AU13','OCUPADA',3,2,95.4),
('AU14','LIBRE',4,2,98.6)
) AS v(codigo,estado,x,y,confianza) ON TRUE
WHERE z.codigo='Z-AUTORIDADES'
AND NOT EXISTS (SELECT 1 FROM plazas_parqueo p WHERE p.zona_id=z.id AND p.codigo=v.codigo);

-- Administrativo
INSERT INTO plazas_parqueo(zona_id,codigo,tipo_plaza,estado_actual,confianza,camara_id,coordenada_x,coordenada_y)
SELECT z.id, v.codigo, 'ESTANDAR', v.estado, v.confianza, d.id, v.x, v.y
FROM zonas_parqueo z
JOIN dispositivos d ON d.codigo='CAM-OCP-ADM-01'
JOIN (VALUES
('AD01','OCUPADA',1,1,95.4),
('AD02','LIBRE',2,1,98.6),
('AD03','LIBRE',3,1,98.6),
('AD04','LIBRE',4,1,98.6),
('AD05','OCUPADA',5,1,95.4),
('AD06','LIBRE',6,1,98.6),
('AD07','LIBRE',7,1,98.6),
('AD08','LIBRE',8,1,98.6),
('AD09','OCUPADA',9,1,95.4),
('AD10','LIBRE',10,1,98.6),
('AD11','LIBRE',1,2,98.6),
('AD12','LIBRE',2,2,98.6),
('AD13','OCUPADA',3,2,95.4),
('AD14','LIBRE',4,2,98.6)
) AS v(codigo,estado,x,y,confianza) ON TRUE
WHERE z.codigo='Z-ADMIN'
AND NOT EXISTS (SELECT 1 FROM plazas_parqueo p WHERE p.zona_id=z.id AND p.codigo=v.codigo);


-- 08_casos_uso_v29.sql
-- PARKIA V29: nueve casos de uso y siete actores autorizados. Idempotente.
INSERT INTO permisos(codigo,modulo,descripcion) VALUES ('propietarios.ver','Propietarios','Consultar propietarios'),('propietarios.gestionar','Propietarios','Registrar y actualizar propietarios') ON CONFLICT(codigo) DO NOTHING;
INSERT INTO roles(codigo,nombre,descripcion,activo) VALUES ('ADMIN','Administrador','Gestión institucional integral',TRUE),('OPERADORES','Operadores','Operación vehicular y supervisión',TRUE),('SOPORTE','Soporte','Soporte técnico, seguridad y continuidad',TRUE),('RRHH','Recursos Humanos','Validación y registros autorizados',TRUE),('DIRECTOR','Director','Consulta de dirección e informes',TRUE),('GUARDIA','Guardia','Supervisión de accesos y alertas',TRUE),('PROPIETARIO','Propietario','Estudiante o docente, sin atribuciones de autoridades ni administrativos',TRUE) ON CONFLICT(codigo) DO UPDATE SET nombre=EXCLUDED.nombre,descripcion=EXCLUDED.descripcion,activo=TRUE;
UPDATE usuarios u SET rol_id=(SELECT id FROM roles WHERE codigo='ADMIN'),actualizado_en=NOW() WHERE u.rol_id=(SELECT id FROM roles WHERE codigo='ADMINISTRADOR_SISTEMA') AND EXISTS(SELECT 1 FROM roles WHERE codigo='ADMINISTRADOR_SISTEMA');
UPDATE usuarios u SET rol_id=(SELECT id FROM roles WHERE codigo='DIRECTOR'),actualizado_en=NOW() WHERE u.rol_id=(SELECT id FROM roles WHERE codigo='DIRECCION_GRADO') AND EXISTS(SELECT 1 FROM roles WHERE codigo='DIRECCION_GRADO');
UPDATE usuarios u SET rol_id=(SELECT id FROM roles WHERE codigo='OPERADORES'),actualizado_en=NOW() WHERE u.rol_id=(SELECT id FROM roles WHERE codigo='JEFE_OPERACIONES') AND EXISTS(SELECT 1 FROM roles WHERE codigo='JEFE_OPERACIONES');
UPDATE usuarios u SET rol_id=(SELECT id FROM roles WHERE codigo='GUARDIA'),actualizado_en=NOW() WHERE u.rol_id=(SELECT id FROM roles WHERE codigo='PERSONAL_GUARDIA') AND EXISTS(SELECT 1 FROM roles WHERE codigo='PERSONAL_GUARDIA');
UPDATE usuarios u SET rol_id=(SELECT id FROM roles WHERE codigo='SOPORTE'),actualizado_en=NOW() WHERE u.rol_id=(SELECT id FROM roles WHERE codigo='SOPORTE_TIC') AND EXISTS(SELECT 1 FROM roles WHERE codigo='SOPORTE_TIC');
UPDATE usuarios u SET rol_id=(SELECT id FROM roles WHERE codigo='SOPORTE'),actualizado_en=NOW() WHERE u.rol_id=(SELECT id FROM roles WHERE codigo='INFRAESTRUCTURA') AND EXISTS(SELECT 1 FROM roles WHERE codigo='INFRAESTRUCTURA');
UPDATE usuarios u SET rol_id=(SELECT id FROM roles WHERE codigo='RRHH'),actualizado_en=NOW() WHERE u.rol_id=(SELECT id FROM roles WHERE codigo='RECURSOS_HUMANOS') AND EXISTS(SELECT 1 FROM roles WHERE codigo='RECURSOS_HUMANOS');
UPDATE usuarios u SET rol_id=(SELECT id FROM roles WHERE codigo='PROPIETARIO'),actualizado_en=NOW() WHERE u.rol_id=(SELECT id FROM roles WHERE codigo='ESTUDIANTE') AND EXISTS(SELECT 1 FROM roles WHERE codigo='ESTUDIANTE');
CREATE TABLE IF NOT EXISTS perfiles_propietarios (usuario_id UUID PRIMARY KEY REFERENCES usuarios(id) ON DELETE CASCADE, tipo VARCHAR(12) NOT NULL CHECK(tipo IN ('ESTUDIANTE','DOCENTE')), creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(), actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW());
INSERT INTO perfiles_propietarios(usuario_id,tipo) SELECT u.id, CASE WHEN UPPER(COALESCE(u.area_institucional,'')) LIKE '%DOCENTE%' THEN 'DOCENTE' ELSE 'ESTUDIANTE' END FROM usuarios u JOIN roles r ON r.id=u.rol_id WHERE r.codigo='PROPIETARIO' ON CONFLICT(usuario_id) DO NOTHING;
UPDATE roles SET activo=FALSE WHERE codigo NOT IN ('ADMIN','OPERADORES','SOPORTE','RRHH','DIRECTOR','GUARDIA','PROPIETARIO');
DELETE FROM roles_permisos WHERE rol_id=(SELECT id FROM roles WHERE codigo='ADMIN');
INSERT INTO roles_permisos(rol_id,permiso_id) SELECT r.id,p.id FROM roles r CROSS JOIN permisos p WHERE r.codigo='ADMIN' ON CONFLICT DO NOTHING;
DELETE FROM roles_permisos WHERE rol_id=(SELECT id FROM roles WHERE codigo='OPERADORES');
INSERT INTO roles_permisos(rol_id,permiso_id) SELECT r.id,p.id FROM roles r JOIN permisos p ON p.codigo=ANY(ARRAY['panel.ver','propietarios.ver','propietarios.gestionar','vehiculos.ver','vehiculos.gestionar','acceso.ver','acceso.validar','parqueo.ver','parqueo.gestionar','ocupacion.ver','ocupacion.actualizar','alertas.ver','alertas.gestionar','historial.ver','reportes.generar']) WHERE r.codigo='OPERADORES' ON CONFLICT DO NOTHING;
DELETE FROM roles_permisos WHERE rol_id=(SELECT id FROM roles WHERE codigo='SOPORTE');
INSERT INTO roles_permisos(rol_id,permiso_id) SELECT r.id,p.id FROM roles r JOIN permisos p ON p.codigo=ANY(ARRAY['panel.ver','usuarios.gestionar','parqueo.ver','parqueo.gestionar','ocupacion.ver','ocupacion.actualizar','alertas.ver','alertas.gestionar','auditoria.ver','respaldos.gestionar','dispositivos.gestionar','configuracion.gestionar','historial.ver','propietarios.ver']) WHERE r.codigo='SOPORTE' ON CONFLICT DO NOTHING;
DELETE FROM roles_permisos WHERE rol_id=(SELECT id FROM roles WHERE codigo='RRHH');
INSERT INTO roles_permisos(rol_id,permiso_id) SELECT r.id,p.id FROM roles r JOIN permisos p ON p.codigo=ANY(ARRAY['usuarios.gestionar','propietarios.ver','propietarios.gestionar','vehiculos.ver','historial.ver','reportes.generar']) WHERE r.codigo='RRHH' ON CONFLICT DO NOTHING;
DELETE FROM roles_permisos WHERE rol_id=(SELECT id FROM roles WHERE codigo='DIRECTOR');
INSERT INTO roles_permisos(rol_id,permiso_id) SELECT r.id,p.id FROM roles r JOIN permisos p ON p.codigo=ANY(ARRAY['panel.ver','parqueo.ver','ocupacion.ver','alertas.ver','historial.ver','reportes.generar','auditoria.ver']) WHERE r.codigo='DIRECTOR' ON CONFLICT DO NOTHING;
DELETE FROM roles_permisos WHERE rol_id=(SELECT id FROM roles WHERE codigo='GUARDIA');
INSERT INTO roles_permisos(rol_id,permiso_id) SELECT r.id,p.id FROM roles r JOIN permisos p ON p.codigo=ANY(ARRAY['panel.ver','parqueo.ver','ocupacion.ver','alertas.ver','alertas.gestionar','vehiculos.ver','acceso.ver','acceso.validar','historial.ver','reportes.generar']) WHERE r.codigo='GUARDIA' ON CONFLICT DO NOTHING;
DELETE FROM roles_permisos WHERE rol_id=(SELECT id FROM roles WHERE codigo='PROPIETARIO');
INSERT INTO roles_permisos(rol_id,permiso_id) SELECT r.id,p.id FROM roles r JOIN permisos p ON p.codigo=ANY(ARRAY['estudiante.mi_parqueo']) WHERE r.codigo='PROPIETARIO' ON CONFLICT DO NOTHING;


-- 09_nexo_v30.sql
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

CREATE TABLE IF NOT EXISTS migraciones_parkia(version VARCHAR(30) PRIMARY KEY,aplicada_en TIMESTAMPTZ DEFAULT NOW());
INSERT INTO migraciones_parkia(version) VALUES ('V11_ALERTAS'),('V15_AUDITORIA'),('V17_MAPEO'),('V26_MAPA'),('V29_CASOS_USO'),('V30_NEXO') ON CONFLICT DO NOTHING;
