import fs from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';
import zlib from 'node:zlib';

/** Portable A4 PDF generator. No browser, external service or PDF package required. */
class PDF {
  constructor(){this.objects=[null];this.pages=[];this.pending=[];this.width=595.28;this.height=841.89;this.font1=this.object('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>');this.font2=this.object('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>');this.gs=this.object('<< /Type /ExtGState /ca 0.14 /CA 0.14 >>');this.images={};this.buf=[];this.pg=null;this.top=0;}
  object(value){this.objects.push(value);return this.objects.length-1;}
  stream(data, props=''){const b=Buffer.isBuffer(data)?data:Buffer.from(data,'latin1');return Buffer.concat([Buffer.from(`<< /Length ${b.length} ${props} >>\nstream\n`,'latin1'),b,Buffer.from('\nendstream','latin1')]);}
  fmt(n){return Number(n.toFixed(2));}
  esc(value){return String(value??'').replace(/[\\()]/g,c=>'\\'+c).replace(/[\r\n\t]/g,' ').replace(/[\u2012-\u2015]/g,'-').replace(/[\u2018\u2019]/g,"'").replace(/[\u201C\u201D]/g,'"').replace(/[^\u0020-\u00ff]/g,'?');}
  push(s){this.buf.push(s)}
  color(hex){return [1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)/255).map(v=>this.fmt(v)).join(' ')}
  rect(x,top,w,h,fill,stroke=null){const y=this.height-top-h;if(fill)this.push(`${this.color(fill)} rg`);if(stroke)this.push(`${this.color(stroke)} RG 0.7 w`);this.push(`${this.fmt(x)} ${this.fmt(y)} ${this.fmt(w)} ${this.fmt(h)} re ${fill&&stroke?'B':fill?'f':'S'}`)}
  line(x1,t1,x2,t2,color='#dce7f2',lw=.65){this.push(`${this.color(color)} RG ${lw} w ${this.fmt(x1)} ${this.fmt(this.height-t1)} m ${this.fmt(x2)} ${this.fmt(this.height-t2)} l S`)}
  text(str,x,top,size=10,bold=false,color='#183451'){const s=this.esc(str);this.push(`${this.color(color)} rg BT /${bold?'F2':'F1'} ${size} Tf 1 0 0 1 ${this.fmt(x)} ${this.fmt(this.height-top-size)} Tm (${s}) Tj ET`)}
  wrap(str,width,size=9){const out=[];let line='';const max=Math.max(8,Math.floor(width/(size*0.54)));for(const w of String(str??'').split(/\s+/)){if((line+' '+w).trim().length>max){if(line)out.push(line);line=w}else line=(line+' '+w).trim()}if(line)out.push(line);return out.length?out:[''];}
  multiline(str,x,top,w,size=9,color='#183451',bold=false,step=15){for(const l of this.wrap(str,w,size)){this.text(l,x,top,size,bold,color);top+=step}return top}
  async imageAsJpeg(file,key){try{const j=await sharp(file).flatten({background:'#ffffff'}).resize({width:460,withoutEnlargement:true}).jpeg({quality:85}).toBuffer();const info=await sharp(j).metadata();const dict=`/Type /XObject /Subtype /Image /Width ${info.width} /Height ${info.height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode`;
    const id=this.object(this.stream(j,dict));this.images[key]={id,width:info.width,height:info.height};}catch{/* logos optional when missing */}}
  image(key,x,top,w,h,alpha=false){const img=this.images[key];if(!img)return;this.push('q');if(alpha)this.push('/GS1 gs');this.push(`${this.fmt(w)} 0 0 ${this.fmt(h)} ${this.fmt(x)} ${this.fmt(this.height-top-h)} cm /${key} Do Q`)}
  newPage(){if(this.pg)this.finishPage();this.buf=[];this.pg={};this.top=132;this.rect(0,0,this.width,93,'#0a3761');this.rect(0,93,this.width,4,'#13a7d2');this.rect(36,18,113,57,'#ffffff');this.image('Parkia',44,29,97,35);this.text('ESCUELA MILITAR DE INGENIERÍA',176,31,14,true,'#ffffff');this.text('Unidad Académica La Paz  |  PARKIA',176,55,9,false,'#cbe6f7');this.text('REPORTE OFICIAL',36,109,10,true,'#0b527e');}
  finishPage(){if(!this.pg)return;const num=this.pages.length+1;this.line(36,786,559,786,'#d3e0ed');this.text('PARKIA | Gestión institucional de parqueos',36,796,8,false,'#557189');this.text(`Página ${num}`,517,796,8,false,'#557189');this.image('Emi',435,714,118,51,true);
    const body=this.buf.join('\n')+'\n';const zip=zlib.deflateSync(Buffer.from(body,'latin1'));const content=this.object(this.stream(zip,'/Filter /FlateDecode'));this.pages.push(content);this.pg=null;}
  space(n=12){this.top+=n}
  ensure(h){if(this.top+h>765){this.newPage()}}
  title(t){this.ensure(52);this.text(t,36,this.top,16,true,'#0c345e');this.top+=28;this.line(36,this.top,559,this.top,'#bed9ec',1);this.top+=15;}
  card(x,top,w,h,label,value){this.rect(x,top,w,h,'#edf5fb','#d3e5f2');this.text(label,x+10,top+9,8,false,'#557189');this.text(String(value),x+10,top+25,18,true,'#0c4a77')}
  table(headers,rows,widths){const x=36,tableW=523;const colW=widths||headers.map(()=>tableW/headers.length);const heads=()=>{this.ensure(36);this.rect(x,this.top,tableW,26,'#0b477b');let xx=x;headers.forEach((h,i)=>{this.text(h,xx+6,this.top+7,8,true,'#ffffff');xx+=colW[i]});this.top+=26};heads();
    if(!rows.length)rows=[['Sin registros para los filtros aplicados']];
    for(let idx=0;idx<rows.length;idx++){const row=rows[idx];const splitted=headers.map((_,i)=>this.wrap(String(row[i]??''),colW[i]-11,8));const rh=Math.min(64,Math.max(26,8+Math.max(...splitted.map(a=>a.length))*11));if(this.top+rh>762){this.newPage();this.text('Continuación',36,this.top,11,true,'#0b477b');this.top+=22;heads()}
      this.rect(x,this.top,tableW,rh,idx%2?'#f2f7fc':'#ffffff','#e2ebf3');let xx=x;for(let col=0;col<headers.length;col++){for(let z=0;z<Math.min(splitted[col].length,4);z++)this.text(splitted[col][z],xx+6,this.top+5+z*11,8,false,'#183451');xx+=colW[col]}this.top+=rh;}
    this.top+=18;
  }
  async render(){this.finishPage();const kids=[];const pagesId=this.object('');const infoId=this.object('<< /Producer (PARKIA EMI UALP) /Title (Informe institucional PARKIA) >>');
    const imgs=Object.entries(this.images).map(([k,v])=>`/${k} ${v.id} 0 R`).join(' ');
    for(const cid of this.pages){const pid=this.object(`<< /Type /Page /Parent ${pagesId} 0 R /MediaBox [0 0 ${this.width} ${this.height}] /Resources << /Font << /F1 ${this.font1} 0 R /F2 ${this.font2} 0 R >> /XObject << ${imgs} >> /ExtGState << /GS1 ${this.gs} 0 R >> >> /Contents ${cid} 0 R >>`);kids.push(pid)}
    this.objects[pagesId]=`<< /Type /Pages /Count ${kids.length} /Kids [${kids.map(i=>i+' 0 R').join(' ')}] >>`;
    const catalog=this.object(`<< /Type /Catalog /Pages ${pagesId} 0 R >>`);
    const parts=[Buffer.from('%PDF-1.4\n%âãÏÓ\n','latin1')],offsets=[0];let length=parts[0].length;
    for(let i=1;i<this.objects.length;i++){offsets.push(length);let obj=this.objects[i];if(!Buffer.isBuffer(obj))obj=Buffer.from(String(obj),'latin1');const item=Buffer.concat([Buffer.from(`${i} 0 obj\n`),obj,Buffer.from('\nendobj\n')]);parts.push(item);length+=item.length}
    const start=length;let xref=`xref\n0 ${this.objects.length}\n0000000000 65535 f \n`;for(let i=1;i<offsets.length;i++)xref+=String(offsets[i]).padStart(10,'0')+' 00000 n \n';xref+=`trailer\n<< /Size ${this.objects.length} /Root ${catalog} 0 R /Info ${infoId} 0 R >>\nstartxref\n${start}\n%%EOF`;
    parts.push(Buffer.from(xref,'latin1'));return Buffer.concat(parts);
  }
}
export async function generarInformePDF(data,{usuario='Institución',zonaNombre='Todas las zonas'}={}){
  const pdf=new PDF();const base=process.env.FRONTEND_DIR||path.resolve(process.cwd(),'../frontend');
  await pdf.imageAsJpeg(path.join(base,'assets/logo/parkia-logo.svg'),'Parkia');
  await pdf.imageAsJpeg(path.join(base,'assets/logo/emi-logo.png'),'Emi');
  pdf.newPage();pdf.title('Informe de flujo, ocupación y validaciones');
  const periodo=data.periodo||{};
  pdf.text('PERIODO DE CONSULTA',36,pdf.top,9,true,'#58758e');pdf.text(`${periodo.desde}   al   ${periodo.hasta}`,180,pdf.top,10,true,'#193e60');pdf.top+=22;
  pdf.text('ZONA CONSULTADA',36,pdf.top,9,true,'#58758e');pdf.multiline(zonaNombre,180,pdf.top,360,9,'#193e60');pdf.top+=24;
  pdf.text('FECHA DE EMISIÓN',36,pdf.top,9,true,'#58758e');pdf.text(new Date(data.emitidoEn).toLocaleString('es-BO'),180,pdf.top,9,false,'#193e60');pdf.top+=24;
  pdf.text('EMITIDO POR',36,pdf.top,9,true,'#58758e');pdf.multiline(usuario,180,pdf.top,355,9,'#193e60');pdf.top+=44;
  const sum=(arr,key)=>arr.reduce((a,r)=>a+Number(r[key]||0),0);
  const totalIn=sum(data.flujo,'ingresos'),totalOut=sum(data.flujo,'salidas'),valid=sum(data.validaciones,'cantidad'),free=sum(data.zonas,'plazas_libres');
  const cards=[['Ingresos',totalIn],['Salidas',totalOut],['Validaciones',valid],['Plazas libres actuales',free]];
  cards.forEach(([label,value],i)=>pdf.card(36+i*132,pdf.top,126,70,label,value));pdf.top+=102;
  pdf.title('Disponibilidad actual por zona');
  pdf.table(['Zona','Total','Libres','Ocupadas','Fuera serv.','Sin datos'],data.zonas.map(z=>[z.nombre,z.total_plazas,z.plazas_libres,z.plazas_ocupadas,z.fuera_servicio,z.sin_datos]),[197,61,63,74,69,59]);
  pdf.title('Flujo vehicular por día');
  pdf.table(['Fecha','Ingresos','Salidas'],data.flujo.map(r=>[String(r.fecha).slice(0,10),r.ingresos,r.salidas]),[235,144,144]);
  pdf.title('Resultado de validaciones');
  pdf.table(['Resultado','Eventos'],data.validaciones.map(r=>[r.resultado_validacion,r.cantidad]),[390,133]);
  pdf.title('Cambios de ocupación');
  pdf.table(['Zona','Estado','Eventos'],data.cambiosOcupacion.map(r=>[r.zona,r.estado,r.cantidad]),[291,134,98]);
  pdf.ensure(90);pdf.multiline('Nota metodológica: la disponibilidad corresponde al estado actual de las plazas; los flujos, las validaciones y los cambios históricos corresponden al periodo y filtros seleccionados. Los datos provienen de registros institucionales sin modificación por este informe.',36,pdf.top,518,8,'#557189',false,13);
  return pdf.render();
}
