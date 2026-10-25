/* Gula PDF: generador local sin bibliotecas externas. PDF de una pagina con imagen JPEG. */
(function(){'use strict';
const MM=72/25.4, PX=12, W=58*PX, PAD=4*PX;
const fmt=n=>'$'+Math.round(Number(n)||0).toLocaleString('es-CL');
function loadLogo(src){return new Promise(resolve=>{if(!src)return resolve(null);const img=new Image();img.onload=()=>resolve(img);img.onerror=()=>resolve(null);img.src=src;});}
function cleanLogo(img){
 const c=document.createElement('canvas');c.width=img.naturalWidth||img.width;c.height=img.naturalHeight||img.height;
 const g=c.getContext('2d',{willReadFrequently:true});g.drawImage(img,0,0);
 const data=g.getImageData(0,0,c.width,c.height),p=data.data;
 let left=c.width,top=c.height,right=-1,bottom=-1;
 for(let y=0;y<c.height;y++)for(let x=0;x<c.width;x++){
  const k=(y*c.width+x)*4,r=p[k],green=p[k+1],blue=p[k+2],alpha=p[k+3];
  // Eliminar negro exterior y fondo blanco/crema; conservar tinta verde oliva.
  const dark=Math.max(r,green,blue)<48;
  const light=Math.min(r,green,blue)>205;
  const ink=alpha>20&&!dark&&!light&&green>=r*.72&&green>=blue*.7;
  if(ink){left=Math.min(left,x);right=Math.max(right,x);top=Math.min(top,y);bottom=Math.max(bottom,y);}
  if(dark||light){p[k+3]=0;}
 }
 g.putImageData(data,0,0);
 if(right<left)return c;
 const margin=Math.max(8,Math.round((right-left)*.04));
 left=Math.max(0,left-margin);right=Math.min(c.width-1,right+margin);
 top=Math.max(0,top-margin);bottom=Math.min(c.height-1,bottom+margin);
 const out=document.createElement('canvas');out.width=right-left+1;out.height=bottom-top+1;
 out.getContext('2d').drawImage(c,left,top,out.width,out.height,0,0,out.width,out.height);
 return out;
}
function jpegPDF(dataUrl,heightMM){
 const raw=atob(dataUrl.split(',')[1]);const jpg=new Uint8Array(raw.length);for(let i=0;i<raw.length;i++)jpg[i]=raw.charCodeAt(i);
 const encoder=new TextEncoder(),chunks=[];let offset=0;const positions=[0];
 function add(x){let b=typeof x==='string'?encoder.encode(x):x;chunks.push(b);offset+=b.length;}
 function obj(n,s){positions[n]=offset;add(n+' 0 obj\n'+s+'\nendobj\n');}
 const pageW=(58*MM).toFixed(3),pageH=(heightMM*MM).toFixed(3);
 add('%PDF-1.4\n');obj(1,'<< /Type /Catalog /Pages 2 0 R >>');obj(2,'<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
 obj(3,`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pageW} ${pageH}] /Resources << /XObject << /Im1 4 0 R >> >> /Contents 5 0 R >>`);
 positions[4]=offset;add(`4 0 obj\n<< /Type /XObject /Subtype /Image /Width ${W} /Height ${Math.round(heightMM*PX)} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${jpg.length} >>\nstream\n`);add(jpg);add('\nendstream\nendobj\n');
 const cmd=`q\n${pageW} 0 0 ${pageH} 0 0 cm\n/Im1 Do\nQ\n`;obj(5,`<< /Length ${encoder.encode(cmd).length} >>\nstream\n${cmd}endstream`);
 const start=offset;add('xref\n0 6\n0000000000 65535 f \n');for(let i=1;i<=5;i++)add(String(positions[i]).padStart(10,'0')+' 00000 n \n');add(`trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${start}\n%%EOF`);
 return new Blob(chunks,{type:'application/pdf'});
}
async function generate(order,settings){
 const logo=await loadLogo(settings.logo);const c=document.createElement('canvas');c.width=W;c.height=12000;const x=c.getContext('2d');x.fillStyle='#fff';x.fillRect(0,0,c.width,c.height);x.fillStyle='#000';let y=PAD;
 function txt(t,size=9,bold=false,center=false){const font=Math.round(size*PX*0.36);x.font=`${bold?'700':'400'} ${font}px Arial,sans-serif`;const max=W-PAD*2;const words=String(t??'').split(/\s+/);let line='';const lines=[];for(const word of words){const test=line?line+' '+word:word;if(x.measureText(test).width>max&&line){lines.push(line);line=word;}else line=test;}if(line)lines.push(line);for(const part of lines){y+=font*1.32;x.textAlign=center?'center':'left';x.fillText(part,center?W/2:PAD,y);y+=font*.28;}y+=5;}
 function rule(){y+=12;x.fillRect(PAD,y,W-PAD*2,2);y+=15;}
 if(logo){const clean=cleanLogo(logo);const w=Math.min(W-PAD*2,310),h=Math.min(150,clean.height/clean.width*w);x.save();x.fillStyle='#fff';x.fillRect((W-w)/2,y,w,h);x.drawImage(clean,(W-w)/2,y,w,h);x.restore();y+=h+15;}else txt('GULA',19,true,true);
 txt('COMANDA N.º '+String(order.number).padStart(3,'0'),10,true,true);rule();
 txt('Cliente: '+order.customer,9,true);if(order.phone)txt('Tel: '+order.phone,8);
 txt('Fecha: '+(order.created?new Date(order.created).toLocaleDateString('es-CL'):'Sin fecha'),8);
 txt('Entrega: '+(order.date?order.date.split('-').reverse().join('-'):'')+' a las '+order.time+' hrs.',10,true);
 txt('Tipo: '+order.deliveryType+' | Pago: '+order.payment,8);rule();
 for(const it of order.items){txt(it.qty+' x '+it.name,9,true);txt(fmt(it.price)+' c/u  =  '+fmt(it.price*it.qty),8);if(it.note)txt('Obs: '+it.note,8);y+=8;}rule();
 txt('TOTAL: '+fmt(order.total),12,true);if(order.notes){rule();txt('OBSERVACIONES:',9,true);txt(order.notes,9);}rule();
 if(settings.whatsapp)txt(settings.whatsapp,8,false,true);if(settings.footer)txt(settings.footer,8,false,true);
 y+=PAD;const h=Math.ceil(y);const final=document.createElement('canvas');final.width=W;final.height=h;final.getContext('2d').drawImage(c,0,0,W,h,0,0,W,h);
 return jpegPDF(final.toDataURL('image/jpeg',.90),h/PX);
}
window.GulaPDF={generate};
})();
