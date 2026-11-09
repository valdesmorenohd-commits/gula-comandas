'use strict';
const URL_SB='https://cesvcjccnpzeplfyrvbm.supabase.co',KEY_SB='sb_publishable_SmM4au0Qm9tI2aynSd88KQ_X9yFLmtN';
const api=window.supabase.createClient(URL_SB,KEY_SB,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true,storageKey:'gula-comandas-staging-auth'}});
const $=id=>document.getElementById(id),money=n=>'$'+Math.round(Number(n)||0).toLocaleString('es-CL');
const uid=()=>crypto.randomUUID(),safe=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','"':'&quot;',"'":'&#39;'}[c]));
const localDate=()=>{const d=new Date();return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')};
let isAdmin=false, currentProfile=null;
let db={products:[],orders:[],settings:{footer:'Gracias por preferir Gula',whatsapp:'+56 9 3306 8109',logo:''}},cart=[],editing=null,authorized=false;
const fail=e=>{console.error(e);alert('No se pudo completar la operación: '+(e?.message||e))};
function toast(s){$('toast').textContent=s;$('toast').style.display='block';setTimeout(()=>$('toast').style.display='none',2500)}
function check(r){if(r.error)throw r.error;return r.data}
function tab(t){if(!isAdmin&&['products','inventory','settings','users'].includes(t))return;document.querySelectorAll('main section').forEach(s=>s.classList.toggle('hidden',s.id!==t));document.querySelectorAll('nav button').forEach(b=>{b.classList.toggle('active',b.dataset.tab===t);b.classList.toggle('secondary',b.dataset.tab!==t)});if(t==='history')renderHistory();if(t==='products')renderProducts();if(t==='inventory')renderInventory();if(t==='reports')renderReports();if(t==='users')renderUsers()}
document.querySelectorAll('nav button').forEach(b=>b.onclick=()=>tab(b.dataset.tab));
function renderSelect(){const s=$('productSelect'),selected=s.value,q=($('productSearch')?.value||'').trim().toLocaleLowerCase('es');const found=db.products.filter(p=>p.name.toLocaleLowerCase('es').includes(q));s.innerHTML=found.map(p=>'<option value="'+safe(p.id)+'">'+safe(p.name)+'</option>').join('');if(found.some(p=>p.id===selected))s.value=selected;syncPrice()}
$('productSearch').oninput=renderSelect;
$('qtyMinus').onclick=()=>{$('qty').value=Math.max(1,(Number($('qty').value)||1)-1)};
$('qtyPlus').onclick=()=>{$('qty').value=Math.max(1,(Number($('qty').value)||0)+1)};
function syncPrice(){const p=db.products.find(p=>p.id===$('productSelect').value);$('unitPrice').value=p?.price??0}
$('productSelect').onchange=syncPrice;
function renderCart(){$('cart').innerHTML=cart.map((i,k)=>'<div class="item"><div class="row"><div><b>'+safe(i.qty)+' × '+safe(i.name)+'</b><div class="muted">'+money(i.price)+' c/u '+safe(i.note)+'</div></div><div><b>'+money(i.qty*i.price)+'</b><br><button class="danger" data-remove="'+k+'">Quitar</button></div></div></div>').join('');$('total').textContent=money(cart.reduce((s,i)=>s+i.qty*i.price,0));document.querySelectorAll('[data-remove]').forEach(b=>b.onclick=()=>{cart.splice(Number(b.dataset.remove),1);renderCart()})}
$('addItem').onclick=async()=>{
 const btn=$('addItem');
 if(btn.disabled)return;
 const p=db.products.find(p=>p.id===$('productSelect').value),qty=Number($('qty').value),price=Number($('unitPrice').value);
 if(!p||!Number.isInteger(qty)||qty<1||!Number.isInteger(price)||price<0)return alert('Revisa cantidad y precio.');
 btn.disabled=true;
 let stockNotice=null;
 try{
  if(p.controlaStock){
   const requested=qty+cart.filter(i=>i.product_id===p.id).reduce((sum,i)=>sum+i.qty,0);
   const date=$('deliveryDate').value;
   const isMenu=p.categoria==='MENU_FINDE';
   if(isMenu&&!date)return alert('Selecciona una fecha de entrega para comprobar el stock del menú.');
   const q=isMenu?api.from('gula_stock_diario').select('disponible').eq('producto_id',p.id).eq('fecha',date).maybeSingle():api.from('gula_stock_general').select('disponible').eq('producto_id',p.id).maybeSingle();
   const row=check(await q);
   if(!row)return alert('Stock sin configurar para '+p.name+(isMenu?' el '+date:'')+'. Ingresa el stock inicial en Inventario.');
   const available=Number(row.disponible);
   if(available===0)return alert('Producto agotado: '+p.name+'. Stock disponible: 0 unidades.');
   if(available<requested)return alert('Stock insuficiente para '+p.name+'. Disponible: '+available+' '+(available===1?'unidad':'unidades')+'. Solicitado: '+requested+'.');
   stockNotice='Producto: '+p.name+'\\nStock disponible: '+available+' unidades\\nAgregadas ahora: '+qty+' unidades'+(requested>qty?'\\nTotal en este pedido: '+requested+' unidades':'')+'\\nQuedarían disponibles: '+(available-requested)+' unidades\\n\\nEl stock se descontará al guardar la comanda.';
  }
  cart.push({product_id:p.id,name:p.name,qty,price,note:$('itemNote').value.trim()});
  $('qty').value=1;$('itemNote').value='';renderCart();
  if(stockNotice)alert(stockNotice.replaceAll('\\n','\n'));
 }catch(e){fail(e)}finally{btn.disabled=false}
};
function clearForm(){if($('productSearch'))$('productSearch').value='';editing=null;['customer','phone','notes'].forEach(k=>$(k).value='');$('deliveryDate').value=localDate();$('deliveryTime').value='13:00';$('deliveryType').value='Retiro';$('payment').value='Pendiente';cart=[];$('initialPaymentAmount').value='';$('initialPaymentMethod').value='EFECTIVO';$('formTitle').textContent='Nueva comanda';renderCart();updateInitialPaymentUI()}
function fromOrder(o){const dt=o.fecha_entrega?new Date(o.fecha_entrega):null;const date=dt?new Intl.DateTimeFormat('en-CA',{timeZone:'America/Santiago',year:'numeric',month:'2-digit',day:'2-digit'}).format(dt):'';const time=dt?new Intl.DateTimeFormat('en-GB',{timeZone:'America/Santiago',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).format(dt):'';return {id:o.id,number:o.numero,customer:o.cliente,phone:o.telefono,date,time,deliveryType:o.tipo_entrega,payment:o.estado_pago,notes:o.notas,items:o.items,total:o.total,cancelada:!!o.cancelada,created:o.creado_en}}
function toDelivery(date,time){const naive=new Date(date+'T'+time+':00Z');const f=new Intl.DateTimeFormat('en-GB',{timeZone:'America/Santiago',hour:'2-digit',minute:'2-digit',hourCycle:'h23',year:'numeric',month:'2-digit',day:'2-digit'});const parts=Object.fromEntries(f.formatToParts(naive).filter(p=>p.type!=='literal').map(p=>[p.type,p.value]));const asUTC=Date.UTC(+parts.year,+parts.month-1,+parts.day,+parts.hour,+parts.minute);return new Date(naive.getTime()+(naive.getTime()-asUTC)).toISOString()}
async function refresh(){const [p,o,c,pagos,usuarios]=await Promise.all([api.from('gula_productos').select('*').eq('activo',true).order('nombre'),api.from('gula_comandas').select('*').order('numero',{ascending:false}).limit(1000),api.from('gula_configuracion').select('*').eq('clave','general').maybeSingle(),api.from('gula_pagos').select('id,comanda_id,monto,medio,creado_en,creado_por').order('creado_en',{ascending:true}).limit(5000),api.from('gula_usuarios').select('user_id,nombre')]);db.products=check(p).map(x=>({id:x.id,name:x.nombre,price:x.precio,categoria:x.categoria,controlaStock:!!x.controla_stock}));const payRows=check(pagos),userNames=new Map(check(usuarios).map(u=>[u.user_id,u.nombre]));db.orders=check(o).map(fromOrder).map(order=>({...order,payments:payRows.filter(pay=>pay.comanda_id===order.id).map(pay=>({...pay,registrado_por:userNames.get(pay.creado_por)||'Usuario'}))}));db.settings={footer:'Gracias por preferir Gula',whatsapp:'+56 9 3306 8109',logo:'',...(check(c)?.valor||{})};renderSelect();renderHistory();renderProducts();renderReports();loadSettings()}
// Migración de comandas: apagada hasta configurar un Supabase aislado.
// Este interruptor NO debe activarse mientras las RPC no estén auditadas.
const GULA_STAGING_RPC_ENABLED=true;
let gulaPendingOperation=null;
function gulaRpcItems(items){
 if(!items.length)throw Error('Agrega productos a la comanda.');
 const seen=new Set();
 return items.map(i=>{
  if(!i.product_id||!db.products.some(p=>p.id===i.product_id))
   throw Error('Esta comanda contiene productos antiguos sin identificador. No puede migrarse automáticamente.');
  if(!Number.isInteger(i.qty)||i.qty<1)throw Error('Cantidad inválida.');
  if(seen.has(i.product_id))throw Error('Consolida los productos repetidos antes de guardar.');
  seen.add(i.product_id);
  return {product_id:i.product_id,qty:i.qty,note:i.note||''};
 });
}
async function gulaSaveViaRpc(customer,date,time){
 if(!GULA_STAGING_RPC_ENABLED)throw Error('Migración no habilitada.');
 if(new URL(URL_SB).hostname==='yobauucfbpdsrmrjjdhy.supabase.co')throw Error('Bloqueado: las RPC de pruebas no pueden usarse con Supabase de producción.');
 if(!window.GulaStagingAdapter)throw Error('Falta cargar el adaptador RPC.');
 const adapter=window.GulaStagingAdapter.makeAdapter(api,true);
 const order={
  id:editing,customer,phone:$('phone').value.trim(),
  deliveryIso:toDelivery(date,time),deliveryType:$('deliveryType').value,
  notes:$('notes').value.trim(),items:gulaRpcItems(cart)
 };
 // No guardar estado de pago desde un selector: solo se deriva de abonos reales.
 // El estado se deriva exclusivamente del pago real registrado por RPC.
 if(editing&&db.orders.find(o=>o.id===editing)?.payment!=='Pendiente')
  throw Error('No se puede editar una comanda con abonos o pagos.');
 if(editing){
  const result=await adapter.editar(order);
  return result.comanda_id;
 }
 if(!gulaPendingOperation)gulaPendingOperation=crypto.randomUUID();
 // Conservar clave tras fallo de red ambiguo para evitar doble descuento.
 const result=await adapter.crear(order,gulaPendingOperation);
 gulaPendingOperation=null;
 return result.comanda_id;
}
let pendingCreatedOrderId=null,pendingCreatedPaymentKey=null,pendingCreatedPaymentSignature=null;
function updateInitialPaymentUI(){
 const state=$('payment').value,editingOrder=!!editing;
 $('initialPaymentFields').classList.toggle('hidden',state==='Pendiente'||editingOrder);
 $('initialPaymentAmountWrap').classList.toggle('hidden',state!=='Abono');
 $('payment').disabled=editingOrder;
}
$('payment').onchange=updateInitialPaymentUI;
function initialPaymentRequest(){
 const state=$('payment').value;
 if(state==='Pendiente')return null;
 const total=cart.reduce((sum,item)=>sum+item.qty*item.price,0);
 const amount=state==='Pagado'?total:Number($('initialPaymentAmount').value);
 if(!Number.isSafeInteger(amount)||amount<=0||amount>total||(state==='Abono'&&amount>=total))
  throw Error('El abono debe ser mayor que $0 y menor que el total de la comanda.');
 return {amount,method:$('initialPaymentMethod').value};
}
async function describeStockFailure(){
 const items=gulaRpcItems(cart),byId=new Map();
 for(const item of items)byId.set(item.product_id,(byId.get(item.product_id)||0)+item.qty);
 const date=$('deliveryDate').value;
 for(const [id,qty] of byId){
  const p=db.products.find(x=>x.id===id);
  if(!p?.controlaStock)continue;
  const isMenu=p.categoria==='MENU_FINDE';
  if(isMenu&&!date)return 'Selecciona una fecha de entrega para comprobar el stock del menú.';
  const query=isMenu?api.from('gula_stock_diario').select('disponible').eq('producto_id',id).eq('fecha',date).maybeSingle():api.from('gula_stock_general').select('disponible').eq('producto_id',id).maybeSingle();
  const row=check(await query);
  if(!row)return 'Stock sin configurar para '+p.name+(isMenu?' el '+date:'')+'. Ingresa el stock inicial en Inventario.';
  const available=Number(row.disponible);
  if(available===0)return 'Producto agotado: '+p.name+'. Stock disponible: 0 unidades.';
  if(available<qty)return 'Stock insuficiente para '+p.name+'. Disponible: '+available+' '+(available===1?'unidad':'unidades')+'. Solicitado: '+qty+'.';
 }
 return null;
}
async function saveOrder(){
 if(!authorized)return null;
 if(editing&&!isAdmin){alert('Solo el administrador puede editar comandas');return null}
 const customer=$('customer').value.trim(),date=$('deliveryDate').value,time=$('deliveryTime').value;
 if(!customer||!date||!time||!cart.length){alert('Completa cliente, fecha, hora y agrega al menos un producto.');return null}
 const btn=$('save'),printBtn=$('savePrint');
 if(btn.disabled||printBtn.disabled)return null;
 btn.disabled=true;printBtn.disabled=true;
 try{
  const payment=editing?null:initialPaymentRequest();
  const payload={cliente:customer,telefono:$('phone').value.trim(),fecha_entrega:toDelivery(date,time),tipo_entrega:$('deliveryType').value,estado_pago:'Pendiente',notas:$('notes').value.trim(),items:cart.map(i=>({...i})),total:cart.reduce((sum,i)=>sum+i.qty*i.price,0),actualizado_en:new Date().toISOString()};
  if(!GULA_STAGING_RPC_ENABLED)throw Error('Los pagos requieren las RPC de pruebas habilitadas.');
  let id=pendingCreatedOrderId;
  if(!id)id=await gulaSaveViaRpc(customer,date,time);
  if(!editing)pendingCreatedOrderId=id;
  if(payment){
   const signature=[id,payment.amount,payment.method].join(':');
   if(pendingCreatedPaymentSignature!==signature){pendingCreatedPaymentKey=crypto.randomUUID();pendingCreatedPaymentSignature=signature}
   const adapter=window.GulaStagingAdapter.makeAdapter(api,true);
   await adapter.abonar(id,payment.amount,payment.method,pendingCreatedPaymentKey);
  }
  const rr=await api.from('gula_comandas').select('*').eq('id',id).single();
  const order=fromOrder(check(rr));
  pendingCreatedOrderId=null;pendingCreatedPaymentKey=null;pendingCreatedPaymentSignature=null;
  clearForm();
  await refresh();
  toast('Comanda N.º '+order.number+' guardada'+(payment?' con pago '+payment.method:'')+'.');
  return order;
 }catch(e){
  if(pendingCreatedOrderId)alert('La comanda pudo haberse creado. No crees otra: revisa el Historial y verifica el pago antes de reintentar.');
  if(/stock insuficiente|stock no configurado|stock agotado/i.test(String(e?.message||''))){try{const detail=await describeStockFailure();if(detail){alert(detail);return null}}catch(diagnosticError){console.warn('No se pudo consultar el detalle del stock',diagnosticError)}}
  fail(e);return null;
 }finally{btn.disabled=false;printBtn.disabled=false}
}
$('save').onclick=saveOrder;$('savePrint').onclick=async()=>{const o=await saveOrder();if(o)await makePDF(o)};$('clear').onclick=clearForm;
function paymentHistoryHTML(o){const pays=o.payments||[];const paid=pays.reduce((sum,p)=>sum+Number(p.monto||0),0);const created=o.created?new Date(o.created).toLocaleString('es-CL',{dateStyle:'short',timeStyle:'short'}):'Sin registro';return '<div class="muted">Creada: '+safe(created)+'</div><div class="muted">Pagos registrados: '+pays.length+' · Abonado: '+money(paid)+' · Saldo: '+money(Math.max(0,o.total-paid))+'</div>'+(pays.length?'<div class="muted">'+pays.map(p=>safe(new Date(p.creado_en).toLocaleString('es-CL',{dateStyle:'short',timeStyle:'short'}))+' · '+money(p.monto)+' · '+safe(p.medio==='TEF'?'Transferencia (TEF)':'Efectivo')+' · '+safe(p.registrado_por)).join('<hr>')+'</div>':'<div class="muted">Sin abonos registrados</div>')}
function renderHistory(){
 const q=$('search').value.toLowerCase();
 const orders=db.orders.filter(o=>o.customer.toLowerCase().includes(q)||String(o.number).includes(q));
 $('historyList').innerHTML=orders.length?orders.map(o=>'<div class="item"><div class="row"><div><b>#'+o.number+' · '+safe(o.customer)+'</b><div class="muted">Entrega: '+safe(o.date)+' '+safe(o.time)+' · '+safe(o.payment)+(o.cancelada?' · CANCELADA':'')+'</div>'+paymentHistoryHTML(o)+'<b>'+money(o.total)+'</b></div></div><div class="actions">'+(isAdmin&&!o.cancelada?'<button class="secondary" data-edit="'+o.id+'">Editar</button>':'')+(!o.cancelada&&o.payment!=='Pagado'?'<button class="secondary" data-abonar="'+o.id+'">Abonar</button>':'')+'<button data-pdf="'+o.id+'">Compartir / Imprimir</button><button class="secondary" data-download="'+o.id+'">Descargar PDF</button>'+(isAdmin&&!o.cancelada?'<button class="danger" data-delete="'+o.id+'">Cancelar</button>':'')+'</div></div>').join(''):'<p class="muted">No hay pedidos guardados.</p>';
 document.querySelectorAll('[data-abonar]').forEach(b=>b.onclick=()=>{const o=db.orders.find(x=>x.id===b.dataset.abonar);if(!o||o.cancelada)return;$('abonoOrder').value=o.id;$('abonoSelected').textContent='Comanda #'+o.number+' · '+o.customer+' · Total '+money(o.total);$('abonoAmount').value='';$('abonoStatus').textContent='';$('abonoAmount').focus()});
 document.querySelectorAll('[data-edit]').forEach(b=>b.onclick=()=>editOrder(b.dataset.edit));
 document.querySelectorAll('[data-pdf]').forEach(b=>b.onclick=()=>makePDF(db.orders.find(o=>o.id===b.dataset.pdf)));
 document.querySelectorAll('[data-download]').forEach(b=>b.onclick=()=>makePDF(db.orders.find(o=>o.id===b.dataset.download),'download'));
 document.querySelectorAll('[data-delete]').forEach(b=>b.onclick=async()=>{if(!isAdmin)return;if(!confirm('¿Cancelar esta comanda? Se devolverá el stock reservado. No se puede cancelar si tiene pagos.'))return;try{const adapter=window.GulaStagingAdapter.makeAdapter(api,GULA_STAGING_RPC_ENABLED);await adapter.cancelar(b.dataset.delete);await refresh();toast('Comanda cancelada; stock restituido.')}catch(e){fail(e)}});
}

let pendingAbonoKey=null;
let pendingAbonoSignature=null;
$('abonoSave').onclick=async()=>{
 if(!authorized)return;
 const id=$('abonoOrder').value,monto=Number($('abonoAmount').value),medio=$('abonoMethod').value;
 if(!id||!Number.isSafeInteger(monto)||monto<=0)return alert('Selecciona una comanda e ingresa un monto válido.');
 const order=db.orders.find(o=>o.id===id);
 if(!order||order.cancelada||order.payment==='Pagado')return alert('Esta comanda no admite nuevos abonos.');
 const btn=$('abonoSave');btn.disabled=true;
 try{
  const adapter=window.GulaStagingAdapter.makeAdapter(api,GULA_STAGING_RPC_ENABLED);
  const signature=[id,monto,medio].join(':');
  if(pendingAbonoSignature!==signature){pendingAbonoKey=crypto.randomUUID();pendingAbonoSignature=signature;}
  const result=await adapter.abonar(id,monto,medio,pendingAbonoKey);
  pendingAbonoKey=null;pendingAbonoSignature=null;
  $('abonoStatus').textContent='Abonado: '+money(result.abonado)+' · Saldo: '+money(result.saldo);
  $('abonoAmount').value='';
  await refresh();
  toast('Abono registrado correctamente.');
 }catch(e){fail(e)}finally{btn.disabled=false}
};
function ordersForReport(){const d=$('reportDate')?.value;return db.orders.filter(o=>o.date===d&&!o.cancelada)}
function productSummary(orders){const products=new Map();for(const o of orders)for(const i of o.items||[]){const key=i.name||'Sin nombre',entry=products.get(key)||{name:key,qty:0,total:0};entry.qty+=Number(i.qty)||0;entry.total+=(Number(i.qty)||0)*(Number(i.price)||0);products.set(key,entry)}return [...products.values()].sort((a,b)=>b.total-a.total)}
function reportPayments(orders){return orders.flatMap(o=>(o.payments||[]).map(p=>({...p,orderNumber:o.number})))}
function renderReports(){
 if(!isAdmin||!$('reportSummary'))return;
 const orders=ordersForReport(),products=productSummary(orders),total=orders.reduce((s,o)=>s+(Number(o.total)||0),0),counts={Pagado:0,Abono:0,Pendiente:0};
 for(const o of orders)counts[o.payment]=(counts[o.payment]||0)+1;
 const payments=reportPayments(orders);
 const cash=payments.filter(p=>p.medio==='EFECTIVO').reduce((n,p)=>n+Number(p.monto||0),0);
 const tef=payments.filter(p=>p.medio==='TEF').reduce((n,p)=>n+Number(p.monto||0),0);
 const received=cash+tef;
 $('reportSummary').innerHTML='<div class="grid"><div class="item"><b>Comandas</b><p>'+orders.length+'</p></div><div class="item"><b>Total de pedidos</b><p>'+money(total)+'</p></div><div class="item"><b>Recibido en efectivo</b><p>'+money(cash)+'</p></div><div class="item"><b>Recibido por TEF</b><p>'+money(tef)+'</p></div><div class="item"><b>Total recaudado</b><p>'+money(received)+'</p></div><div class="item">Marcadas pagadas: '+counts.Pagado+'</div><div class="item">Con abono: '+counts.Abono+'</div><div class="item">Pendientes: '+counts.Pendiente+'</div></div>';
 $('reportProducts').innerHTML=products.length?products.map(p=>'<div class="item row"><span>'+safe(p.name)+' · '+p.qty+' un.</span><b>'+money(p.total)+'</b></div>').join(''):'<p class="muted">No hay productos para esta fecha.</p>';
 $('reportOrders').innerHTML=orders.length?orders.map(o=>'<div class="item"><div class="row"><span>#'+safe(o.number)+' · '+safe(o.customer)+' · '+safe(o.payment)+'</span><b>'+money(o.total)+'</b></div><div class="muted">Efectivo: '+money((o.payments||[]).filter(p=>p.medio==='EFECTIVO').reduce((n,p)=>n+Number(p.monto||0),0))+' · TEF: '+money((o.payments||[]).filter(p=>p.medio==='TEF').reduce((n,p)=>n+Number(p.monto||0),0))+'</div></div>').join(''):'<p class="muted">No hay comandas para esta fecha.</p>';
}
function exportReportCsv(){
 if(!isAdmin)return;
 const orders=ordersForReport();
 const data=[['Comanda','Cliente','Fecha entrega','Estado','Total pedido','Recibido efectivo','Recibido TEF','Total recibido','Saldo'],...orders.map(o=>{const payments=o.payments||[],cash=payments.filter(p=>p.medio==='EFECTIVO').reduce((n,p)=>n+Number(p.monto||0),0),tef=payments.filter(p=>p.medio==='TEF').reduce((n,p)=>n+Number(p.monto||0),0);return [o.number,o.customer,o.date,o.payment,o.total,cash,tef,cash+tef,Math.max(0,o.total-cash-tef)]})];
 const csv=String.fromCharCode(65279)+data.map(row=>row.map(v=>'"'+String(v??'').replace(/"/g,'""')+'"').join(';')).join(String.fromCharCode(13,10));
 download(new Blob([csv],{type:'text/csv;charset=utf-8'}),'Gula-reporte-'+$('reportDate').value+'.csv');
}

$('search').oninput=renderHistory;
function editOrder(id){if(!isAdmin)return;const o=db.orders.find(o=>o.id===id);if(!o||o.cancelada)return;editing=o.id;for(const [k,v] of Object.entries({customer:o.customer,phone:o.phone,deliveryDate:o.date,deliveryTime:o.time,deliveryType:o.deliveryType,payment:o.payment,notes:o.notes}))$(k).value=v;cart=o.items.map(i=>({...i,product_id:i.product_id||null}));$('formTitle').textContent='Editar comanda N.º '+o.number;renderCart();updateInitialPaymentUI();tab('new');window.scrollTo(0,0)}
let pendingInitialKey=null,pendingInitialSignature=null;
$('stockInitialSave').onclick=async()=>{
 if(!isAdmin)return;
 const id=$('stockInitialProduct').value,qty=Number($('stockInitialQty').value),p=db.products.find(x=>x.id===id);
 if(!p||!p.controlaStock||!Number.isSafeInteger(qty)||qty<=0||!$('stockInitialQty').value.trim())return alert('Selecciona un producto e ingresa una cantidad inicial válida.');
 const date=p.categoria==='MENU_FINDE'?$('stockDate').value:null;
 if(p.categoria==='MENU_FINDE'&&!date)return alert('Selecciona la fecha del menú.');
 const signature=[id,date||'',qty].join(':');
 if(pendingInitialSignature!==signature){pendingInitialKey=crypto.randomUUID();pendingInitialSignature=signature;}
 const btn=$('stockInitialSave');btn.disabled=true;
 try{
  const result=await api.rpc('gula_configurar_stock_inicial',{p_producto_id:id,p_fecha:date,p_cantidad:qty,p_clave:pendingInitialKey});
  const data=check(result);
  pendingInitialKey=null;pendingInitialSignature=null;
  $('stockInitialQty').value='';
  $('stockInitialStatus').textContent='Stock inicial configurado: '+data.disponible+' unidades.';
  await renderInventory();toast('Stock inicial guardado.');
 }catch(e){fail(e)}finally{btn.disabled=false}
};
let pendingStockKey=null,pendingStockSignature=null;
async function renderInventory(){
 if(!isAdmin||!$('stockList'))return;
 if(!$('stockDate').value)$('stockDate').value=localDate();
 const date=$('stockDate').value;
 try{
  const [general,diario]=await Promise.all([
   api.from('gula_stock_general').select('producto_id,disponible'),
   api.from('gula_stock_diario').select('producto_id,disponible,cantidad_inicial').eq('fecha',date)
  ]);
  const generalMap=new Map(check(general).map(x=>[x.producto_id,x.disponible]));
  const diarioMap=new Map(check(diario).map(x=>[x.producto_id,x.disponible]));
  const products=db.products.filter(p=>p.controlaStock);
  const select=$('stockProduct'),selected=select.value;
  select.innerHTML=products.map(p=>'<option value="'+safe(p.id)+'">'+safe(p.name)+'</option>').join('');
  if(products.some(p=>p.id===selected))select.value=selected;
  const initialSelect=$('stockInitialProduct'),initialSelected=initialSelect.value;
  initialSelect.innerHTML=products.map(p=>'<option value="'+safe(p.id)+'">'+safe(p.name)+'</option>').join('');
  if(products.some(p=>p.id===initialSelected))initialSelect.value=initialSelected;
  $('stockList').innerHTML=products.length?products.map(p=>{
   const isMenu=p.categoria==='MENU_FINDE';
   const available=(isMenu?diarioMap:generalMap).get(p.id);
   return '<div class="item row"><span><b>'+safe(p.name)+'</b><div class="muted">'+(isMenu?'Menú · '+safe(date):'Stock general')+'</div></span><b>'+(available===undefined?'Sin configurar':available+' un.')+'</b></div>';
  }).join(''):'<p class="muted">Todavía no hay productos con control de stock.</p>';
 }catch(e){fail(e)}
}
$('stockDate').onchange=renderInventory;
$('stockRefresh').onclick=renderInventory;
$('stockAdjust').onclick=async()=>{
 if(!isAdmin)return;
 const id=$('stockProduct').value,delta=Number($('stockDelta').value),p=db.products.find(p=>p.id===id);
 if(!p||!p.controlaStock||!Number.isSafeInteger(delta)||delta===0)return alert('Selecciona un producto y una variación válida.');
 const date=p.categoria==='MENU_FINDE'?$('stockDate').value:null;
 if(p.categoria==='MENU_FINDE'&&!date)return alert('Selecciona la fecha del menú.');
 const reason=$('stockReason').value;
 if(!reason)return alert('Selecciona un motivo del ajuste.');
 const signature=[id,date||'',delta,reason].join(':');
 if(pendingStockSignature!==signature){pendingStockKey=crypto.randomUUID();pendingStockSignature=signature;}
 const btn=$('stockAdjust');btn.disabled=true;
 try{
  const adapter=window.GulaStagingAdapter.makeAdapter(api,GULA_STAGING_RPC_ENABLED);
  const result=await adapter.ajustarStock(id,date,delta,pendingStockKey,reason);
  pendingStockKey=null;pendingStockSignature=null;
  $('stockDelta').value='';$('stockReason').value='';
  $('stockStatus').textContent='Existencias actualizadas: '+result.disponible+' unidades.';
  await renderInventory();toast('Inventario actualizado.');
 }catch(e){fail(e)}finally{btn.disabled=false}
};
function renderProducts(){if(!isAdmin)return;$('productsList').innerHTML=db.products.map(p=>'<div class="item"><div class="grid"><div><label>Nombre</label><input data-pname="'+p.id+'" value="'+safe(p.name)+'"></div><div><label>Precio ($)</label><input type="number" min="0" step="1" data-pprice="'+p.id+'" value="'+p.price+'"></div></div><div class="actions"><button class="secondary" data-psave="'+p.id+'">Guardar cambios</button><button class="danger" data-pdel="'+p.id+'">Eliminar</button></div></div>').join('');document.querySelectorAll('[data-psave]').forEach(b=>b.onclick=async()=>{if(!isAdmin)return;const id=b.dataset.psave,name=document.querySelector('[data-pname="'+id+'"]').value.trim(),price=Number(document.querySelector('[data-pprice="'+id+'"]').value);if(!name||!Number.isInteger(price)||price<0)return alert('Revisa nombre y precio.');if(db.products.some(p=>p.id!==id&&p.name.toLocaleLowerCase('es')===name.toLocaleLowerCase('es')))return alert('Ya existe otro producto con ese nombre.');try{check(await api.from('gula_productos').update({nombre:name,precio:price,actualizado_en:new Date().toISOString()}).eq('id',id).select());toast('Producto actualizado');await refresh()}catch(e){fail(e)}});document.querySelectorAll('[data-pdel]').forEach(b=>b.onclick=async()=>{if(!confirm('¿Eliminar este producto del catálogo?'))return;try{check(await api.from('gula_productos').update({activo:false}).eq('id',b.dataset.pdel).select());await refresh()}catch(e){fail(e)}})}

$('addProduct').onclick=async()=>{if(!isAdmin)return;const name=$('productName').value.trim(),price=Number($('productPrice').value);if(!name||!Number.isInteger(price)||price<0)return alert('Ingresa nombre y precio válido.');const old=db.products.find(p=>p.name.toLowerCase()===name.toLowerCase());if(old&&!confirm('Este producto existe. ¿Actualizar precio?'))return;try{check(old?await api.from('gula_productos').update({precio:price,actualizado_en:new Date().toISOString()}).eq('id',old.id).select():await api.from('gula_productos').insert({nombre:name,precio:price,categoria:$('productCategory').value,controla_stock:$('productTrackStock').checked}).select());$('productName').value='';$('productPrice').value='';await refresh()}catch(e){fail(e)}};
function loadSettings(){$('footer').value=db.settings.footer||'';$('whatsapp').value=db.settings.whatsapp||'';if(db.settings.logo){$('logoPreview').src=db.settings.logo;$('logoPreview').classList.remove('hidden')}else $('logoPreview').classList.add('hidden')}
$('logoFile').onchange=e=>{const file=e.target.files[0];if(!file)return;if(file.size>450000)return alert('Para sincronizar, el logo debe pesar menos de 450 KB.');const reader=new FileReader();reader.onload=()=>{$('logoPreview').src=reader.result;$('logoPreview').classList.remove('hidden');db.settings.logo=reader.result};reader.readAsDataURL(file)};
$('saveSettings').onclick=async()=>{if(!isAdmin)return;db.settings.footer=$('footer').value;db.settings.whatsapp=$('whatsapp').value;try{check(await api.from('gula_configuracion').upsert({clave:'general',valor:db.settings,actualizado_en:new Date().toISOString()}).select());toast('Ajustes guardados en la nube')}catch(e){fail(e)}};
function download(blob,name){const a=document.createElement('a'),url=URL.createObjectURL(blob);a.href=url;a.download=name;document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),60000)}
$('export').onclick=()=>download(new Blob([JSON.stringify(db,null,2)],{type:'application/json'}),'gula-respaldo-'+localDate()+'.json');
$('importBtn').disabled=true;$('importBtn').title='Importación desactivada en versión de prueba para evitar sobrescribir pedidos compartidos';
async function makePDF(o,mode='share'){if(!o)return;try{if(!window.GulaPDF)throw Error('No se cargó pdf-engine.js');const paymentRows=check(await api.from('gula_pagos').select('monto,medio,creado_en').eq('comanda_id',o.id).order('creado_en',{ascending:true}));const blob=await GulaPDF.generate({...o,payments:paymentRows},db.settings),filename='Gula-comanda-'+String(o.number).padStart(3,'0')+'.pdf';if(mode==='download'){download(blob,filename);toast('PDF descargado');return}const file=new File([blob],filename,{type:'application/pdf'});if(navigator.canShare?.({files:[file]})){try{await navigator.share({files:[file],title:filename});return}catch(e){if(e.name==='AbortError')return}}download(blob,filename)}catch(e){fail(e)}}
async function login(){const email=$('loginEmail').value.trim(),password=$('loginPassword').value;if(!email||!password)return alert('Ingresa correo y contraseña');$('loginButton').disabled=true;try{check(await api.auth.signInWithPassword({email,password}));await initialize()}catch(e){fail(e)}finally{$('loginButton').disabled=false}}
async function initialize(){try{const {data:{user}}=await api.auth.getUser();if(!user){authorized=false;$('loginPanel').classList.remove('hidden');$('appShell').classList.add('hidden');return}const r=await api.from('gula_usuarios').select('activo,nombre,rol').eq('user_id',user.id).maybeSingle();currentProfile=check(r);if(!currentProfile?.activo)throw Error('Esta cuenta no está autorizada para usar Gula');isAdmin=currentProfile.rol==='admin';authorized=true;document.querySelectorAll('[data-admin-only]').forEach(el=>el.classList.toggle('hidden',!isAdmin));await refresh();$('loginPanel').classList.add('hidden');$('appShell').classList.remove('hidden');$('signedIn').textContent=(currentProfile.nombre||user.email)+' · '+(isAdmin?'Administrador':'Usuario');if(isAdmin)await renderUsers();clearForm()}catch(e){authorized=false;$('appShell').classList.add('hidden');$('loginPanel').classList.remove('hidden');fail(e)}}
$('loginButton').onclick=login;$('loginPassword').onkeydown=e=>{if(e.key==='Enter')login()};$('logoutButton').onclick=async()=>{await api.auth.signOut();authorized=false;isAdmin=false;currentProfile=null;db.orders=[];db.products=[];initialize()};
$('reportDate').value=localDate();$('reportDate').onchange=renderReports;
$('reportCsv').onclick=exportReportCsv;
clearForm();initialize();setInterval(()=>{if(authorized&&document.visibilityState==='visible')refresh().catch(console.error)},30000);

async function renderUsers(){
 if(!isAdmin)return;
 try{
  const users=check(await api.from('gula_usuarios').select('user_id,nombre,rol,activo').order('nombre'));
  $('usersList').innerHTML=users.map(u=>'<div class="item"><b>'+safe(u.nombre||'Sin nombre')+'</b><div class="grid"><div><label>Nombre</label><input data-uname="'+u.user_id+'" value="'+safe(u.nombre||'')+'"></div><div><label>Rol</label><select data-urole="'+u.user_id+'"><option value="usuario" '+(u.rol==='usuario'?'selected':'')+'>Usuario</option><option value="admin" '+(u.rol==='admin'?'selected':'')+'>Administrador</option></select></div></div><label><input type="checkbox" style="width:auto;min-height:auto" data-uactive="'+u.user_id+'" '+(u.activo?'checked':'')+'> Cuenta activa</label><button data-usave="'+u.user_id+'">Guardar cambios</button></div>').join('');
  document.querySelectorAll('[data-usave]').forEach(b=>b.onclick=async()=>{
   if(!isAdmin)return;const id=b.dataset.usave, nombre=document.querySelector('[data-uname="'+id+'"]').value.trim(),rol=document.querySelector('[data-urole="'+id+'"]').value,activo=document.querySelector('[data-uactive="'+id+'"]').checked;
   const {data:{user}}=await api.auth.getUser();
   if(user?.id===id&&(!activo||rol!=='admin'))return alert('No puedes quitarte tu propio acceso de administrador.');
   if(!nombre)return alert('Ingresa un nombre.');
   try{check(await api.from('gula_usuarios').update({nombre,rol,activo}).eq('user_id',id).select());toast('Usuario actualizado');await renderUsers()}catch(e){fail(e)}
  });
 }catch(e){console.error(e);$('usersList').textContent='No se pudo cargar la lista de usuarios.'}
}
$('inviteButton').onclick=async()=>{
 if(!isAdmin)return;const nombre=$('inviteName').value.trim(),correo=$('inviteEmail').value.trim().toLowerCase(),rol=$('inviteRole').value;
 if(!nombre||!/^\S+@\S+\.\S+$/.test(correo))return alert('Ingresa un nombre y un correo válido.');
 $('inviteButton').disabled=true;
 try{const {data,error}=await api.functions.invoke('gula-invitar-usuario',{body:{nombre,correo,rol}});if(error)throw error;if(data?.error)throw Error(data.error);$('inviteStatus').textContent='Invitación enviada a '+correo;$('inviteName').value='';$('inviteEmail').value='';await renderUsers()}
 catch(e){fail(e);$('inviteStatus').textContent='No se pudo enviar. Revisa que la función de invitaciones esté desplegada en Supabase.'}
 finally{$('inviteButton').disabled=false}
};

