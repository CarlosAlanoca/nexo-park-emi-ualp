import {api, aviso, sesion} from '../api.js';
const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=String(text);return n;};
function csv(rows){return rows.map(row=>row.map(v=>'"'+String(v??'').replaceAll('"','""')+'"').join(',')).join('\r\n');}
function descargar(rows,nombre){const blob=new Blob(['\ufeff'+csv(rows)],{type:'text/csv;charset=utf-8'});const u=URL.createObjectURL(blob);const a=document.createElement('a');a.href=u;a.download=nombre;a.click();setTimeout(()=>URL.revokeObjectURL(u),1000);}
const today=new Date().toISOString().slice(0,10);const month=new Date(Date.now()-29*86400000).toISOString().slice(0,10);
export async function renderReportes(c){
 const root=el('section','reports-v14');const head=el('header','page-head');const t=el('div');t.append(el('h1','','Reportes y estadísticas'),el('p','','Indicadores y documentación oficial'));head.append(t);root.append(head);
 const filter=el('form','card panel report-controls');filter.innerHTML='<label>Desde <input type="date" name="desde" required></label><label>Hasta <input type="date" name="hasta" required></label><label>Zona <select name="zona"><option value="">Todas las zonas</option></select></label><button type="submit" class="btn btn-primary">Generar reporte</button><button type="button" class="btn primary" id="previewPDF">Vista previa PDF</button>';
 filter.elements.desde.value=month;filter.elements.hasta.value=today;root.append(filter);
 const out=el('div','report-body');root.append(out);
 const preview=el('div','pdf-preview-area');root.append(preview);c.replaceChildren(root);
 let pdfUrl=null;let pdfFilters=null;
 const clearPdf=()=>{preview.replaceChildren();if(pdfUrl){URL.revokeObjectURL(pdfUrl);pdfUrl=null;}pdfFilters=null;};
 async function mostrarVistaPDF(){
  const desde=filter.elements.desde.value,hasta=filter.elements.hasta.value,zona=filter.elements.zona.value;
  if(!desde||!hasta||desde>hasta){aviso('Seleccione un período válido antes de previsualizar.');return}
  clearPdf();const boton=c.querySelector('#previewPDF');boton.disabled=true;boton.textContent='Preparando documento...';
  try{
   const qs=new URLSearchParams({desde,hasta,zona});
   const r=await fetch('/api/reportes/pdf?'+qs,{headers:{'Authorization':'Bearer '+sesion.token},cache:'no-store'});
   if(!r.ok){let msg='No se pudo generar el documento.';try{msg=(await r.json()).message||msg}catch{}throw Error(msg)}
   const pdf=await r.blob();if(pdf.type!=='application/pdf'||pdf.size<200)throw Error('El archivo PDF no es válido.');
   pdfUrl=URL.createObjectURL(pdf);pdfFilters={desde,hasta,zona};
   const card=el('section','card panel pdf-preview-card');
   const header=el('div','pdf-preview-header');header.append(el('h2','','Previsualización del informe'));
   const download=el('button','btn primary','Descargar PDF');download.type='button';download.onclick=()=>{if(!pdfUrl)return;const a=document.createElement('a');a.href=pdfUrl;a.download='PARKIA_Informe_'+desde+'_'+hasta+'.pdf';document.body.appendChild(a);a.click();a.remove()};
   const close=el('button','btn','Cerrar');close.type='button';close.onclick=clearPdf;
   header.append(download,close);card.append(header);
   const iframe=el('iframe','pdf-frame');iframe.src=pdfUrl;iframe.title='Vista previa del reporte PDF institucional';card.append(iframe);
   preview.append(card);card.scrollIntoView({behavior:'smooth',block:'start'});
  }catch(ex){aviso(ex.message)}finally{boton.disabled=false;boton.textContent='Vista previa PDF';}
 }
 c.querySelector('#previewPDF').onclick=mostrarVistaPDF;
 for(const input of Array.from(filter.querySelectorAll('input,select')))input.addEventListener('change',clearPdf);
 
 let seq=0;const render=async()=>{const n=++seq,desde=filter.elements.desde.value,hasta=filter.elements.hasta.value,zona=filter.elements.zona.value;
 if(!desde||!hasta||desde>hasta)return aviso('Seleccione un periodo válido.');out.replaceChildren(el('p','card panel','Generando informe...'));
 try{const d=await api('/reportes/resumen?'+new URLSearchParams({desde,hasta,zona}));if(n!==seq||c.dataset.moduloActivo!=='reportes')return;
 const select=filter.elements.zona,old=select.value;if(select.options.length===1)for(const z of d.zonas){const o=document.createElement('option');o.value=z.id;o.textContent=z.nombre;select.append(o);}select.value=old;
 out.replaceChildren();const period=el('p','report-period',`Periodo: ${d.periodo.desde} al ${d.periodo.hasta} · Emitido: ${new Date(d.emitidoEn).toLocaleString('es-BO')}`);out.append(period);
 const ingresos=d.flujo.reduce((s,x)=>s+Number(x.ingresos),0),salidas=d.flujo.reduce((s,x)=>s+Number(x.salidas),0),valid=d.validaciones.reduce((s,x)=>s+Number(x.cantidad),0),libres=d.zonas.reduce((s,x)=>s+Number(x.plazas_libres),0);
 const stats=el('div','report-kpis');for(const [label,value] of [['Ingresos',ingresos],['Salidas',salidas],['Validaciones',valid],['Plazas libres ahora',libres]]){const k=el('article','card report-kpi');k.append(el('span','',label),el('strong','',value));stats.append(k);}out.append(stats);
 function seccion(titulo,headers,rows,file){const card=el('section','card panel report-section');const h=el('div','report-section-head');h.append(el('h2','',titulo));const btn=el('button','btn','Exportar CSV');btn.type='button';btn.onclick=()=>descargar([headers,...rows],file);h.append(btn);card.append(h);const wrap=el('div','report-table-wrap');const table=el('table','report-table');const tr=el('tr');for(const x of headers)tr.append(el('th','',x));const thead=el('thead');thead.append(tr);table.append(thead);const tb=el('tbody');for(const row of rows){const tr=el('tr');for(const x of row)tr.append(el('td','',x));tb.append(tr);}if(!rows.length){const tr=el('tr'),td=el('td','','No existen registros para este filtro.');td.colSpan=headers.length;tr.append(td);tb.append(tr);}table.append(tb);wrap.append(table);card.append(wrap);out.append(card);}
 const zonaRows=d.zonas.map(z=>[z.nombre,z.total_plazas,z.plazas_libres,z.plazas_ocupadas,z.fuera_servicio,z.sin_datos]);seccion('Ocupación y disponibilidad por zona',['Zona','Total','Libres','Ocupadas','Fuera de servicio','Sin datos'],zonaRows,'parkia_ocupacion.csv');
 seccion('Flujo vehicular por fecha',['Fecha','Ingresos','Salidas'],d.flujo.map(x=>[String(x.fecha).slice(0,10),x.ingresos,x.salidas]),'parkia_flujo.csv');
 seccion('Validaciones de acceso',['Resultado','Eventos'],d.validaciones.map(x=>[x.resultado_validacion,x.cantidad]),'parkia_validaciones.csv');
 seccion('Cambios históricos de ocupación',['Zona','Estado detectado','Eventos'],d.cambiosOcupacion.map(x=>[x.zona,x.estado,x.cantidad]),'parkia_cambios_ocupacion.csv');
 const note=el('p','report-footnote','La disponibilidad refleja el estado actual; los demás indicadores corresponden al período seleccionado.');out.append(note);
 }catch(e){if(n===seq)out.replaceChildren(el('div','card panel','No se pudo generar el informe: '+e.message));}};
 filter.addEventListener('submit',e=>{e.preventDefault();render();});await render();
}
