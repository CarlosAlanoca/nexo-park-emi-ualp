# Instalación y actualización a PARKIA V29

1. **Respaldar primero** el repositorio y la información real de PostgreSQL. Evite ejecutar `docker compose down -v`, ya que borra volúmenes.
2. Descomprima la V29 en una carpeta temporal, sin mezclar `node_modules`, contraseñas locales ni claves privadas de versiones anteriores.
3. Copie los archivos dentro del repositorio Git existente conservando `.git`, su archivo `.env` privado y los volúmenes de datos. Se recomienda guardar una rama de seguridad: `git switch -c backup-parkia-pre-v29` y volver a la rama de trabajo.
4. Construya y levante los servicios:

```powershell
docker compose up -d --build
docker compose ps
docker compose logs --tail=120 app
```

5. Abra `http://localhost:4000/login`. Entre con una cuenta autorizada y compruebe que el menú solo contiene nueve módulos según su rol.
6. Verifique los siete actores en Gestión de usuarios. Las cuentas antiguas quedan asociadas al rol vigente más parecido; asigne áreas/zonas concretas antes de usar el sistema en producción.
7. Pruebe Registro de propietarios: estudiante y docente, zona, estado y vínculo con Registro de vehículos. No registre allí funcionarios administrativos o autoridades.
8. Entre a Informes y reportes, seleccione fechas y zona, pulse **Generar reporte**, luego **Vista previa PDF** y finalmente **Descargar PDF**. Revise logos, tablas, fechas, paginación y legibilidad.
9. Compruebe Componente móvil con una cuenta Propietario; no debe mostrar pantallas administrativas ni permitir consultas de otra zona.
10. Haga una recarga de caché con `Ctrl + F5`. Si el navegador conserva un service worker antiguo, desregístrelo desde DevTools > Application > Service Workers.
11. Solo tras las pruebas publique el código:

```powershell
git add -A
git commit -m "PARKIA V29 nueve casos de uso siete actores y reportes PDF"
git push origin main
```

No ejecute sobre datos productivos sin una copia de seguridad recuperable. La migración SQL V29 registra su ejecución para no reasignar permisos en cada arranque.
