import {tienePermiso} from '../api.js';
/** Composición accesible: pestañas dentro del mismo caso de uso sin exponer nuevos módulos. */
export async function renderAgrupado(c, secciones){
  const validas=secciones.filter(s=>tienePermiso(s.perm));
  if(!validas.length){c.textContent='No tiene permisos de consulta.';return;}
  const host=document.createElement('div');host.className='caso-uso-host';
  const tabs=document.createElement('nav');tabs.className='case-tabs';tabs.setAttribute('aria-label','Funciones del módulo');
  const detail=document.createElement('div');detail.className='case-detail';
  c.replaceChildren(host);host.append(tabs,detail);
  let version=0;
  async function activate(index){
    const n=++version;
    tabs.querySelectorAll('button').forEach((b,i)=>{b.classList.toggle('active',i===index);b.setAttribute('aria-selected',String(i===index))});
    const working=document.createElement('div');working.className='case-render';
    detail.replaceChildren(working);
    try { await validas[index].render(working); }
    catch(err){ if(version===n && detail.contains(working)){working.textContent=err.message||'No se pudo cargar el módulo.';} }
  }
  validas.forEach((s,i)=>{const b=document.createElement('button');b.type='button';b.textContent=s.nombre;b.className='case-tab';b.setAttribute('role','tab');b.onclick=()=>activate(i);tabs.appendChild(b)});
  await activate(0);
}
