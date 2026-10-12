import {api,fecha} from '../../js/api.js';
export async function renderControlPropio(c){
 const d=await api('/estudiante/mis-accesos');
 const section=document.createElement('section');const h=document.createElement('h1');h.textContent='Mis ingresos y salidas';const p=document.createElement('p');p.textContent='Últimos 100 movimientos de los vehículos asociados a tu cuenta. La consulta no autoriza el ingreso ni modifica registros.';
 section.append(h,p);const wrap=document.createElement('div');wrap.className='table-wrap';const table=document.createElement('table');const thead=document.createElement('thead'),head=document.createElement('tr');for(const label of ['Fecha y hora','Placa','Movimiento','Resultado','Punto']){const th=document.createElement('th');th.textContent=label;head.append(th)}thead.append(head);table.append(thead);const body=document.createElement('tbody');
 for(const e of d.items){const tr=document.createElement('tr');for(const v of [fecha(e.fecha_hora),e.placa_detectada,e.tipo_evento,e.resultado_validacion,e.punto_acceso]){const td=document.createElement('td');td.textContent=v||'—';tr.append(td)}body.append(tr)}
 if(!d.items.length){const tr=document.createElement('tr'),td=document.createElement('td');td.colSpan=5;td.textContent='Todavía no hay movimientos asociados a tus vehículos.';tr.append(td);body.append(tr)}table.append(body);wrap.append(table);section.append(wrap);c.replaceChildren(section);
}
