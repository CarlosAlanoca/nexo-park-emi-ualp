import {renderEstudiante} from './estudiante.js';
import {api} from '../../js/api.js';
export async function renderMovil(c,u){
 if(u.rol==='PROPIETARIO')return renderEstudiante(c);
 const data=await api('/movil/contexto');
 const section=document.createElement('section');section.className='student-page';
 const head=document.createElement('header');head.className='page-head';
 const intro=document.createElement('div'),title=document.createElement('h1'),sub=document.createElement('p');
 title.textContent='Tu operación, a mano';sub.textContent='Accesos rápidos a tus herramientas. Los permisos se mantienen en cada dispositivo.';intro.append(title,sub);head.append(intro);section.append(head);
 const grid=document.createElement('div');grid.className='np-cards';
 for(const m of data.accesos){const card=document.createElement('article');card.className='card panel';const h=document.createElement('h2');h.textContent=m.nombre;const a=document.createElement('a');a.className='btn btn-primary';a.href='#'+m.modulo;a.textContent='Abrir módulo →';card.append(h,a);grid.append(card)}
 section.append(grid);c.replaceChildren(section);
}
