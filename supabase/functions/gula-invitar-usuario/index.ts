// Supabase Edge Function: gula-invitar-usuario
// Secrets SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY provided by Supabase runtime.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const headers={'Access-Control-Allow-Origin':'https://valdesmorenohd-commits.github.io','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Content-Type':'application/json'};
const response=(body,status=200)=>new Response(JSON.stringify(body),{status,headers});
Deno.serve(async(req)=>{
 if(req.method==='OPTIONS')return new Response(null,{headers});
 if(req.method!=='POST')return response({error:'Método no permitido'},405);
 try{
  const url=Deno.env.get('SUPABASE_URL'),anon=Deno.env.get('SUPABASE_ANON_KEY'),service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if(!url||!anon||!service)return response({error:'Configuración de servidor incompleta'},500);
  const bearer=req.headers.get('Authorization')||'';
  if(!bearer.startsWith('Bearer '))return response({error:'Sesión requerida'},401);
  const auth=createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:{user},error:authError}=await auth.auth.getUser(bearer.slice(7));
  if(authError||!user)return response({error:'Sesión inválida'},401);
  const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:profile,error:profileError}=await admin.from('gula_usuarios').select('rol,activo').eq('user_id',user.id).maybeSingle();
  if(profileError||!profile?.activo||profile.rol!=='admin')return response({error:'Solo el administrador puede invitar usuarios'},403);
  const {nombre,correo,rol}=await req.json();
  if(typeof nombre!=='string'||!nombre.trim()||nombre.length>100||typeof correo!=='string'||!/^\S+@\S+\.\S+$/.test(correo)||!['admin','usuario'].includes(rol))return response({error:'Datos inválidos'},400);
  const email=correo.trim().toLowerCase();
  const {data:invited,error:inviteError}=await admin.auth.admin.inviteUserByEmail(email,{redirectTo:'https://valdesmorenohd-commits.github.io/gula-comandas/'});
  if(inviteError)return response({error:inviteError.message},400);
  if(!invited?.user?.id)return response({error:'No se recibió identificador de cuenta'},500);
  const {error:saveError}=await admin.from('gula_usuarios').upsert({user_id:invited.user.id,nombre:nombre.trim(),rol,activo:true},{onConflict:'user_id'});
  if(saveError)return response({error:'Se envió la invitación, pero no se pudo activar el acceso. Contacta al administrador.'},500);
  return response({ok:true});
 }catch(e){return response({error:'No se pudo completar la invitación'},500)}
});
