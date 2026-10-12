import { initTheme } from './theme.js';
import { api, sesion, tienePermiso } from './api.js';
import { renderPanel } from './pages/panel.js';
import { renderEstudiante, detenerConsultaEstudiante } from './pages/estudiante.js';
import { renderVehiculos } from './pages/vehiculos.js';
import { renderAccesos } from './pages/accesos.js';
import { renderParqueos } from './pages/parqueos.js';
import { renderOcupacion } from './pages/ocupacion.js';
import { renderAlertas } from './pages/alertas.js';
import { renderHistorial } from './pages/historial.js';
import { renderReportes } from './pages/reportes.js';
import { renderUsuarios } from './pages/usuarios.js';
import { renderAuditoria } from './pages/auditoria.js';
import { renderRespaldos } from './pages/respaldos.js';
import { renderPropietarios } from './pages/propietarios.js';
import { renderAgrupado } from './pages/agrupado.js';

const c = document.getElementById('content');
const menu = document.getElementById('menu');

async function cerrarSesion() {
  const boton = document.getElementById('logout');
  boton.disabled = true;
  boton.textContent = 'Saliendo...';
  try {
    if (sesion.token) await api('/autenticacion/logout', { method: 'POST' });
  } catch {
    // Aunque la red falle, las credenciales locales se eliminan.
  } finally {
    sesion.limpiar();
    location.replace('/login');
  }
}

async function validarSesion() {
  if (!sesion.token) {
    location.replace('/login');
    return null;
  }
  try {
    const data = await api('/autenticacion/yo');
    sesion.actualizarUsuario(data.usuario);
    return data.usuario;
  } catch {
    sesion.limpiar();
    location.replace('/login');
    return null;
  }
}

async function iniciarAplicacion() {
  initTheme('themeToggle');
  const u = await validarSesion();
  if (!u) return;

  document.getElementById('userName').textContent = u.nombreCompleto;
  document.getElementById('userRole').textContent = u.nombreRol;
  document.getElementById('avatar').textContent = (u.nombreCompleto || 'U').trim().charAt(0).toUpperCase();

  // Nueve módulos del modelo aprobado; no existen menús independientes fuera de estos casos de uso.
  const modulos = [
    { id:'usuarios', label:'Gestión de usuarios', icon:'♙', grupo:'GESTIÓN INSTITUCIONAL', perm:'usuarios.gestionar', render:()=>renderUsuarios(c) },
    { id:'reportes', label:'Informes y reportes', icon:'▥', grupo:'GESTIÓN INSTITUCIONAL', perm:'reportes.generar', render:()=>renderReportes(c) },
    { id:'propietarios', label:'Registro de propietarios', icon:'♧', grupo:'GESTIÓN INSTITUCIONAL', perm:'propietarios.ver', render:()=>renderPropietarios(c) },
    { id:'vehiculos', label:'Registro de vehículos', icon:'🚘', grupo:'OPERACIÓN', perm:'vehiculos.ver', render:()=>renderVehiculos(c) },
    { id:'lugares', label:'Gestión de lugares / clasificación', icon:'▦', grupo:'OPERACIÓN', perm:['panel.ver','parqueo.ver','ocupacion.ver'], render:()=>renderAgrupado(c,[{nombre:'Panel de supervisión',perm:'panel.ver',render:()=>renderPanel(c,u)},{nombre:'Parqueos y plazas',perm:'parqueo.ver',render:()=>renderParqueos(c)},{nombre:'Visión artificial',perm:'ocupacion.ver',render:()=>renderOcupacion(c)}]) },
    { id:'control', label:'Control de ingreso y salida', icon:'◉', grupo:'OPERACIÓN', perm:['acceso.ver','historial.ver'], render:()=>renderAgrupado(c,[{nombre:'Ingresos y salidas',perm:'acceso.ver',render:()=>renderAccesos(c)},{nombre:'Historial y trazabilidad',perm:'historial.ver',render:()=>renderHistorial(c)}]) },
    { id:'alertas', label:'Alertas y notificaciones', icon:'⚠', grupo:'OPERACIÓN', perm:'alertas.ver', render:()=>renderAlertas(c) },
    { id:'auditoria', label:'Auditoría y control', icon:'✓', grupo:'CONTROL Y ACCESO', perm:['auditoria.ver','respaldos.gestionar'], render:()=>renderAgrupado(c,[{nombre:'Auditoría',perm:'auditoria.ver',render:()=>renderAuditoria(c)},{nombre:'Respaldo y continuidad',perm:'respaldos.gestionar',render:()=>renderRespaldos(c)}]) },
    { id:'movil', label:'Componente móvil', icon:'▣', grupo:'CONTROL Y ACCESO', perm:'estudiante.mi_parqueo', render:()=>renderEstudiante(c) }
  ].filter(m => (Array.isArray(m.perm)?m.perm.some(p=>tienePermiso(p)):tienePermiso(m.perm)) && (m.id!=='movil'||u.rol==='PROPIETARIO'));

  for (const g of [...new Set(modulos.map(m => m.grupo))]) {
    const h = document.createElement('h4');
    h.textContent = g;
    menu.append(h);
    for (const m of modulos.filter(x => x.grupo === g)) {
      const b = document.createElement('button');
      b.className = 'menu-item';
      b.dataset.id = m.id;
      b.innerHTML = `<span>${m.icon}</span><span>${m.label}</span>`;
      b.onclick = () => navegar(m);
      menu.append(b);
    }
  }

  let navigationVersion = 0;
  async function navegar(m) {
    if (!m) return;
    const thisVersion=++navigationVersion;
    detenerConsultaEstudiante();
    c.dataset.moduloActivo=m.id;
    document.querySelectorAll('.menu-item').forEach(x => x.classList.toggle('active', x.dataset.id === m.id));
    history.replaceState(null, '', `#${m.id}`);
    c.innerHTML = '<div class="empty">Cargando módulo...</div>';
    try {
      await m.render();
    } catch (e) {
      if(thisVersion===navigationVersion && c.dataset.moduloActivo===m.id){
        c.replaceChildren();const card=document.createElement('div');card.className='card panel';
        const h=document.createElement('h3');h.textContent='No se pudo cargar el módulo';
        const p=document.createElement('p');p.textContent=e.message||'Intente nuevamente.';
        card.append(h,p);c.append(card);
      }
    }
    document.getElementById('sidebar').classList.remove('open');
  }

  const wanted = location.hash.slice(1);
  const defaultId = u.rol === 'PROPIETARIO' ? 'movil' : (modulos.find(m=>m.id==='lugares')?'lugares':modulos[0]?.id);
  const initial = modulos.find(m => m.id === wanted) || modulos.find(m=>m.id===defaultId) || modulos[0];
  if (initial) navegar(initial);
  else c.innerHTML = '<div class="card panel"><h3>Sin módulos asignados</h3><p>Contacte al administrador del sistema.</p></div>';

  window.addEventListener('hashchange',()=>{const requested=location.hash.slice(1);const target=modulos.find(m=>m.id===requested);if(target && c.dataset.moduloActivo!==target.id)void navegar(target);});
  document.getElementById('logout').onclick = cerrarSesion;
  document.getElementById('menuBtn').onclick = () => document.getElementById('sidebar').classList.toggle('open');
  if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').catch(() => {});
}

iniciarAplicacion();
