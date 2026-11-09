/* Gula Comandas — adaptador de integración para entorno de pruebas.
 * No se carga en index.html y NO modifica la aplicación publicada.
 * Requiere que el backend se haya validado y habilitado en Supabase de pruebas.
 * Importante: la app actual usa {name,qty,price,note}; las nuevas RPC requieren
 * {product_id,qty,note}. No usar hasta que todos los ítems tengan product_id.
 */
'use strict';
(function (root) {
  const validUuid = value => typeof value === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
  const asItems = items => {
    if (!Array.isArray(items) || !items.length) throw Error('Agrega productos.');
    const seen = new Set();
    return items.map(item => {
      if (!validUuid(item.product_id)) throw Error('Falta el identificador del producto.');
      if (!Number.isSafeInteger(item.qty) || item.qty < 1) throw Error('Cantidad inválida.');
      if (seen.has(item.product_id)) throw Error('Consolida productos repetidos.');
      seen.add(item.product_id);
      return {product_id:item.product_id, qty:item.qty, note:String(item.note||'')};
    });
  };
  const check = result => {
    if (result.error) throw result.error;
    if (!result.data) throw Error('Supabase no devolvió un resultado.');
    return result.data;
  };
  const makeAdapter = (client, enabled=false) => {
    if (!client || typeof client.rpc !== 'function') throw Error('Cliente Supabase requerido.');
    if (!enabled) throw Error('Integración deshabilitada hasta completar pruebas.');
    return Object.freeze({
      async crear(order, operationId) {
        if (!validUuid(operationId)) throw Error('Identificador de operación inválido.');
        return check(await client.rpc('gula_crear_comanda_segura',{
          p_cliente:String(order.customer||'').trim(),
          p_telefono:String(order.phone||''),
          p_fecha_entrega:order.deliveryIso,
          p_tipo_entrega:order.deliveryType,
          p_notas:String(order.notes||''),
          p_items:asItems(order.items),
          p_clave:operationId
        }));
      },
      async editar(order) {
        if (!validUuid(order.id)) throw Error('Comanda inválida.');
        return check(await client.rpc('gula_editar_comanda_segura',{
          p_comanda_id:order.id,
          p_cliente:String(order.customer||'').trim(),
          p_telefono:String(order.phone||''),
          p_fecha_entrega:order.deliveryIso,
          p_tipo_entrega:order.deliveryType,
          p_notas:String(order.notes||''),
          p_items:asItems(order.items)
        }));
      },
      async cancelar(id) {
        if (!validUuid(id)) throw Error('Comanda inválida.');
        return check(await client.rpc('gula_cancelar_comanda_segura',{p_comanda_id:id}));
      },
      async abonar(id, amount, method, operationId) {
        if (!validUuid(id) || !validUuid(operationId)) throw Error('Identificador inválido.');
        if (!Number.isSafeInteger(amount) || amount <= 0) throw Error('Monto inválido.');
        if (!['EFECTIVO','TEF'].includes(method)) throw Error('Medio de pago inválido.');
        return check(await client.rpc('gula_registrar_abono',{
          p_comanda_id:id,p_monto:amount,p_medio:method,p_clave_idempotencia:operationId
        }));
      },
      async ajustarStock(productId, dateOrNull, delta, operationId, reason) {
        if (!validUuid(productId) || !validUuid(operationId)) throw Error('Identificador inválido.');
        if (!Number.isSafeInteger(delta) || delta === 0) throw Error('Ajuste inválido.');
        if (!['PRODUCCION','REPOSICION','MERMA','CORRECCION'].includes(reason)) throw Error('Selecciona un motivo válido.');
        return check(await client.rpc('gula_ajustar_stock_con_motivo',{
          p_producto_id:productId,p_fecha:dateOrNull,
          p_delta:delta,p_clave_idempotencia:operationId,p_motivo:reason
        }));
      }
    });
  };
  root.GulaStagingAdapter = Object.freeze({makeAdapter,asItems});
})(typeof window !== 'undefined' ? window : globalThis);
