# PARKIA EMI UALP — V29 · Arquitectura y módulos

## Diagrama corregido
Se consolidan los 13 módulos funcionales previos en **9 casos de uso visibles**. No se borran subsistemas: se agrupan mediante pestañas y componentes internos.

| Módulo aprobado | Funciones conservadas/integradas | Accesos previstos |
|---|---|---|
| Gestión de usuarios | Cuentas, roles, permisos, habilitación | Administrador, Soporte, RRHH |
| Informes y reportes | Indicadores, flujo, ocupación, validaciones, CSV y PDF | Administrador, Operadores, RRHH, Director, Guardia |
| Registro de propietarios | Registro de estudiantes/docentes, zonas, cambios | Administrador, Operadores, RRHH; Soporte consulta |
| Registro de vehículos | Vehículos, fotografías, placas y autorizaciones | Administrador, Operadores; consulta limitada a otros |
| Gestión de lugares / clasificación | Panel supervisión, plazas, cámaras, IA y calibración | Administrador, Operadores, Soporte, Guardia, Director según permisos |
| Control de ingreso y salida | Lectura LPR, validación manual, historial/trazabilidad | Administrador, Operadores, Guardia; consultas según permisos |
| Alertas y notificaciones | Incidentes, atención, cierre, prevención de duplicados | Administrador, Operadores, Soporte, Guardia; Director consulta |
| Auditoría y control | Auditoría, seguridad, respaldos y continuidad | Administrador, Soporte; Director consulta de auditoría |
| Componente móvil | Consulta de disponibilidad de zona asignada | Propietario solamente |

## Actores únicos
- ADMIN · Administrador
- OPERADORES · Operadores
- SOPORTE · Soporte
- RRHH · Recursos Humanos
- DIRECTOR · Director
- GUARDIA · Guardia
- PROPIETARIO · Propietario (estudiante o docente, **no** autoridad ni administrativo)

Los antiguos roles se migran sin eliminar usuarios ni historial. La tabla de roles conserva las entradas históricas desactivadas para mantener integridad referencial; únicamente los 7 actores anteriores pueden asignarse a nuevas cuentas.

## Seguridad y privacidad
- Las rutas servidor requieren sesión y permisos.
- La creación y modificación de propietarios se realiza en su módulo específico (no desde el formulario genérico de usuarios).
- La cuenta PROPIETARIO solo recibe `estudiante.mi_parqueo` y debe tener zona asignada.
- Las vistas operativas no muestran propietarios al usuario móvil.
- La descarga PDF y la previsualización requieren `reportes.generar`.
- Los reportes solo leen datos existentes y no actualizan históricos.
- Las solicitudes de respaldo no equivalen a respaldo automático.

## Reportes institucionales
El mismo servicio de consultas alimenta la vista en pantalla y el PDF, con filtros de fechas y zona. El PDF usa formato A4, identidad PARKIA, encabezado EMI y logo EMI semitransparente en la esquina inferior derecha. Incluye fecha, emisor, período, indicadores, tablas y páginas numeradas.

La previsualización carga el PDF autenticado dentro de la interfaz y habilita la descarga a continuación. No incluye datos de ejemplo en la generación real.

## Límites de validación
Pendiente verificar integración real con PostgreSQL, Docker, cámaras, permisos de usuarios institucionales y compatibilidad de visualización del PDF en el navegador del evaluador. Una prueba de sintaxis no sustituye pruebas de extremo a extremo.
