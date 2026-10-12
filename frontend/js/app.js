import {renderControlPropio} from '../modules/control/propio.js';
import { initTheme } from './theme.js';
import { api, sesion, tienePermiso } from './api.js';
import {renderMovil} from '../modules/movil/movil.js';
import { renderPanel } from '../modules/lugares/panel.js';
import { renderEstudiante, detenerConsultaEstudiante } from '../modules/movil/estudiante.js';
import { renderVehiculos } from '../modules/vehiculos/vehiculos.js';
import { renderAccesos } from '../modules/control/accesos.js';
import { renderParqueos } from '../modules/lugares/parqueos.js';
import { renderOcupacion } from '../modules/lugares/ocupacion.js';
import { renderAlertas } from '../modules/alertas/alertas.js';
import { renderHistorial } from '../modules/control/historial.js';
import { renderReportes } from '../modules/reportes/reportes.js';
import { renderUsuarios } from '../modules/usuarios/usuarios.js';
import { renderAuditoria } from '../modules/auditoria/auditoria.js';
import { renderRespaldos } from '../modules/auditoria/respaldos.js';
import { renderPropietarios } from '../modules/propietarios/propietarios.js';
import { renderAgrupado } from '../shared/agrupado.js';

const c = document.getElementById('content');
const menu = document.getElementById('menu');
function icon(id){const paths={usuarios:'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8M20 8v6m-3-3h6',reportes:'M4 3h12l4 4v14H4ZM8 16v-4m4 4V8m4 8v-6',propietarios:'M3 4h18v16H3ZM7 9h3m-3 6h10m-3-6h3',vehiculos:'M3 16V9l3-5h12l3 5v7ZM3 10h18M6 16v4m12-4v4M6 13h1m10 0h1',lugares:'M3 3h7v7H3ZM14 3h7v7h-7ZM3 14h7v7H3ZM14 14h7v7h-7Z',control:'M4 7h15m-4-4 4 4-4 4M20 17H5m4-4-4 4 4 4',alertas:'M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M9 21h6',auditoria:'M12 3 3 7v6c0 5 9 8 9 8s9-3 9-8V7ZM8 12l3 3 5-6',movil:'M7 2h10v20H7ZM10 18h4'};return '<svg viewBox="0 0 24 24" class="menu-icon"><path d="'+paths[id]+'"/></svg>'}


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
    { id:'usuarios', label:'Gestión de usuarios', icon:'♙', grupo:'GESTIÓN INSTITUCIONAL', perm:'usuarios.gestionar', render:(pane)=>renderUsuarios(pane) },
    { id:'reportes', label:'Informes y reportes', icon:'▥', grupo:'GESTIÓN INSTITUCIONAL', perm:'reportes.generar', render:(pane)=>renderReportes(pane) },
    { id:'propietarios', label:'Registro de propietarios', icon:'♧', grupo:'GESTIÓN INSTITUCIONAL', perm:'propietarios.ver', render:(pane)=>renderPropietarios(pane) },
    { id:'vehiculos', label:'Registro de vehículos', icon:'🚘', grupo:'OPERACIÓN', perm:'vehiculos.ver', render:(pane)=>renderVehiculos(pane) },
    { id:'lugares', label:'Gestión de lugares / clasificación', icon:'▦', grupo:'OPERACIÓN', perm:['panel.ver','parqueo.ver','ocupacion.ver'], render:(pane)=>renderAgrupado(pane,[{nombre:'Panel de supervisión',perm:'panel.ver',render:(pane)=>renderPanel(pane,u)},{nombre:'Parqueos y plazas',perm:'parqueo.ver',render:(pane)=>renderParqueos(pane)},{nombre:'Visión artificial',perm:'ocupacion.ver',render:(pane)=>renderOcupacion(pane)}]) },
    { id:'control', label:'Control de ingreso y salida', icon:'◉', grupo:'OPERACIÓN', perm:['acceso.ver','historial.ver','acceso.propio'], render:(pane)=>u.rol==='PROPIETARIO'?renderControlPropio(pane):renderAgrupado(pane,[{nombre:'Ingresos y salidas',perm:'acceso.ver',render:(pane)=>renderAccesos(pane)},{nombre:'Historial y trazabilidad',perm:'historial.ver',render:(pane)=>renderHistorial(pane)}]) },
    { id:'alertas', label:'Alertas y notificaciones', icon:'⚠', grupo:'OPERACIÓN', perm:'alertas.ver', render:(pane)=>renderAlertas(pane) },
    { id:'auditoria', label:'Auditoría y control', icon:'✓', grupo:'CONTROL Y ACCESO', perm:['auditoria.ver','respaldos.gestionar'], render:(pane)=>renderAgrupado(pane,[{nombre:'Auditoría',perm:'auditoria.ver',render:(pane)=>renderAuditoria(pane)},{nombre:'Respaldo y continuidad',perm:'respaldos.gestionar',render:(pane)=>renderRespaldos(pane)}]) },
    { id:'movil', label:'Componente móvil', icon:'▣', grupo:'CONTROL Y ACCESO', perm:'sesion.autenticada', render:(pane)=>renderMovil(pane,u) }
  ].filter(m => (m.id==='movil'?true:Array.isArray(m.perm)?m.perm.some(p=>tienePermiso(p)):tienePermiso(m.perm)));

  for (const g of [...new Set(modulos.map(m => m.grupo))]) {
    const h = document.createElement('h4');
    h.textContent = g;
    menu.append(h);
    for (const m of modulos.filter(x => x.grupo === g)) {
      const b = document.createElement('button');
      b.className = 'menu-item';
      b.dataset.id = m.id;
      b.innerHTML = `<span aria-hidden="true">${icon(m.id)}</span><span>${m.label}</span>`;
      b.onclick = () => navegar(m);
      menu.append(b);
    }
  }

  const sidebar=document.getElementById('sidebar'), menuButton=document.getElementById('menuBtn');
  const closeMenu=()=>{sidebar.classList.remove('open');menuButton.setAttribute('aria-expanded','false')};
  document.getElementById('mobileScrim').onclick=closeMenu;
  const dialog=document.getElementById('moduleDialog'), query=document.getElementById('moduleQuery'), results=document.getElementById('moduleResults');
  function search(){results.replaceChildren();const term=query.value.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();const found=modulos.filter(m=>m.label.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().includes(term));for(const m of found){const b=document.createElement('button');b.textContent=m.label;b.onclick=()=>{dialog.close();navegar(m)};results.append(b)}if(!found.length)results.textContent='No hay módulos disponibles con ese nombre.';}
  const openSearch=()=>{query.value='';search();dialog.showModal();query.focus()};
  document.getElementById('searchModules').onclick=openSearch;
  document.getElementById('closeSearch').onclick=()=>dialog.close();query.oninput=search;
  document.addEventListener('keydown',e=>{if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='k'){e.preventDefault();if(!dialog.open)openSearch()}if(e.key==='Escape')closeMenu()});
  const connection=()=>document.getElementById('offlineBanner').classList.toggle('hidden',navigator.onLine);
  window.addEventListener('online',connection);window.addEventListener('offline',connection);connection();
  let navigationVersion = 0;
  async function navegar(m) {
    if (!m) return;
    const thisVersion=++navigationVersion;
    detenerConsultaEstudiante();
    c.dataset.moduloActivo=m.id;
    document.getElementById('currentModule').textContent=m.label;
    document.title=m.label+' · NEXO PARK';
    closeMenu();
    document.querySelectorAll('.menu-item').forEach(x => x.classList.toggle('active', x.dataset.id === m.id));
    history.replaceState(null, '', `#${m.id}`);
    c.setAttribute('aria-busy','true');
    c.innerHTML = '<div class="skeleton" role="status" aria-label="Cargando módulo"><i></i><i></i><i></i></div>';
    const pane=document.createElement('div');pane.dataset.moduloActivo=m.id;
    pane.innerHTML=c.innerHTML;c.replaceChildren(pane);
    try {
      await m.render(pane);
    } catch (e) {
      if(thisVersion===navigationVersion && c.dataset.moduloActivo===m.id){
        c.replaceChildren();const card=document.createElement('div');card.className='card panel';
        card.classList.add('module-error');const h=document.createElement('h2');h.textContent='No se pudo cargar el módulo';
        const p=document.createElement('p');p.textContent=e.message||'Intente nuevamente.';
        const retry=document.createElement('button');retry.className='btn btn-primary';retry.textContent='Volver a intentar';retry.onclick=()=>navegar(m);card.append(h,p,retry);c.append(card);
      }
    }
    if(thisVersion===navigationVersion){c.setAttribute('aria-busy','false');c.focus({preventScroll:true});}
  }

  const wanted = location.hash.slice(1);
  const defaultId = u.rol === 'PROPIETARIO' ? 'movil' : (modulos.find(m=>m.id==='lugares')?'lugares':modulos[0]?.id);
  const initial = modulos.find(m => m.id === wanted) || modulos.find(m=>m.id===defaultId) || modulos[0];
  if (initial) navegar(initial);
  else c.innerHTML = '<div class="card panel"><h3>Sin módulos asignados</h3><p>Contacte al administrador del sistema.</p></div>';

  window.addEventListener('hashchange',()=>{const requested=location.hash.slice(1);const target=modulos.find(m=>m.id===requested);if(target && c.dataset.moduloActivo!==target.id)void navegar(target);});
  document.getElementById('logout').onclick = cerrarSesion;
  menuButton.onclick = () => {const open=sidebar.classList.toggle('open');menuButton.setAttribute('aria-expanded',String(open));};
  if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').catch(() => {});
}

iniciarAplicacion();
