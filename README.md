# NEXO PARK · EMI UALP · V30

Evolución de PARKIA V29. Sistema de parqueos con **9 módulos y 7 actores**, frontend y backend reorganizados por módulo. Incluye portal EMI, acceso, consulta móvil, gestión operativa, PDF con vista previa y documentación actualizada.

## Empezar en Windows, Linux o macOS

1. Instalar Docker con Compose y tener el motor en ejecución.
2. Extraer todo el ZIP. Abrir una terminal en esta carpeta.
3. Ejecutar `docker compose up --build`.
4. Abrir **http://localhost:4000**.
5. Para detener, `docker compose down`. No agregar `-v` si quiere conservar la base.

El Compose es una configuración de **demostración local**, con `SEED_DEMO=true` por defecto. No exponerla a Internet como configuración productiva.

| Usuario | Contraseña de demostración | Actor |
|---|---|---|
| admin | PARKIA2026!Admin | Administrador |
| director | PARKIA2026!Dir | Director |
| operaciones | PARKIA2026!Ops | Operadores |
| guardia | PARKIA2026!Seg | Guardia |
| soporte | PARKIA2026!Tic | Soporte |
| rrhh | PARKIA2026!RRHH | Recursos Humanos |
| estudiante | PARKIA2026!Est | Propietario estudiante |
| docente | PARKIA2026!Doc | Propietario docente |

Los dos propietarios son el mismo actor. Las cuentas demo solo se crean si no existen; sus contraseñas no se reemplazan al reiniciar.

## Instalación sin Docker

Requisitos: Node.js 22 o posterior, PostgreSQL 16 o posterior, Tesseract con idioma `eng` para OCR.

1. Crear base y usuario de PostgreSQL.
2. Copiar `backend/.env.example` como `backend/.env` y ajustar `DATABASE_URL`.
3. Ejecutar desde la raíz: `npm run install:all`.
4. Inicializar una base nueva con `backend/sql/01_schema.sql`, `02_seed.sql` y `03_views_functions.sql`, en ese orden. Ejemplo: `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/sql/01_schema.sql -f backend/sql/02_seed.sql -f backend/sql/03_views_functions.sql`.
5. Ejecutar `npm start`. El proceso arranca desde backend y aplica migraciones pendientes 04–09 en transacción.

Alternativa para base NUEVA: ejecutar `backend/sql/NEXO_PARK_BD_COMPLETA.sql`. No combinar ambos caminos ni ejecutar semillas sobre una base operativa.

## Actualización desde V29

- Respaldar la base y ensayar la restauración antes del reemplazo.
- Conservar el `.env` real y el volumen PostgreSQL existente.
- Reemplazar el código con esta entrega y ejecutar `npm ci` en backend.
- Reiniciar. V30 reconoce la marca `V29_CASOS_USO` y no vuelve a aplicar mapas antiguos.
- Si existen usuarios que solo difieren por mayúsculas, la migración detiene el arranque para resolver el conflicto sin borrar datos.
- Recargar el navegador. El service worker elimina los cachés de versiones anteriores.

## Organización

Las carpetas `frontend/modules` y `backend/src/modules` contienen exactamente:

`usuarios`, `reportes`, `propietarios`, `vehiculos`, `lugares`, `control`, `alertas`, `auditoria`, `movil`.

Autenticación vive en `backend/src/core/autenticacion`; sesión y navegación en `frontend/js`; composición de pestañas en `frontend/shared`. Las rutas API y nombres de tablas históricos se conservan por compatibilidad.

Documentos actuales: **docs/vigente_v30**. Diagramas: **docs/diagramas_v30**. Documentación previa de referencia: **docs/historico_v29**, no representa la versión vigente.

## Pruebas

- `npm test`: verifica nueve carpetas en ambas capas e imports relativos.
- `npm run test:integration`: contra una instalación DEMO activa en localhost:4000. Crea un propietario de prueba; ejecutar solo en base de pruebas. `TEST_URL` permite cambiar el destino.
- `tests/resultados-integracion.json` documenta la corrida realizada con API real y PostgreSQL compatible PGlite.

Se verificaron navegación Chromium, autenticación, permisos, revocación y PDF. No se ejecutaron pruebas con cámaras/barreras físicas ni un despliegue Docker en este entorno. Las pruebas con datos de demo no acreditan precisión de visión artificial.

## Producción

Configurar `NODE_ENV=production`, `SEED_DEMO=false`, `JWT_SECRET` y `CAPTCHA_SECRET` independientes de al menos 32 caracteres aleatorios, credenciales propias, HTTPS y CORS. No usar las contraseñas del Compose.

Para crear el administrador inicial, ejecutar desde backend `npm run admin:create`, definiendo `ADMIN_USER`, `ADMIN_PASSWORD` (mínimo 12 caracteres) y opcionalmente `ADMIN_NAME` en el entorno. El script no sobrescribe una cuenta existente. Retirar la variable de contraseña después de usarla.

La web registra solicitudes y evidencias de respaldo. Para ejecutar una copia real desde consola, usar `npm run backup:create` desde backend con `ALLOW_BACKUP_COMMANDS=true`; genera un dump y su SHA256 y registra el resultado. La restauración se realiza externamente sobre una base separada. Las copias con comandos externos están deshabilitadas por defecto. Instalar herramientas PostgreSQL y validar rutas/permisos antes de habilitarlas. El OCR requiere Tesseract; los eventos simulados están marcados como SIMULADOR. La disponibilidad no implica reserva.

## Editar diagramas

Abrir los archivos `.dia` con Dia. Incluyen objetos y conectores editables; SVG y PNG facilitan la consulta. Se validó el XML del formato; no se ejecutó la aplicación de escritorio Dia durante esta entrega.
