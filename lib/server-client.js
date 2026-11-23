import {cookies,headers} from 'next/headers';
import {createServerClient} from '@supabase/ssr';
import {createClient} from '@supabase/supabase-js';
const hosted=process.env.VERCEL==='1';
export async function client(token){
 const {SUPABASE_URL:url,SUPABASE_PUBLISHABLE_KEY:key}=process.env;
 if(!url||!key)return null;
 if(token)return createClient(url,key,{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
 const jar=await cookies();
 const h=await headers();
 const secure=h.get('x-forwarded-proto')?.split(',')[0].trim()==='https'||h.get('host')?.endsWith('.e2b.app')||process.env.NODE_ENV==='production';
 return createServerClient(url,key,{cookies:{getAll:()=>jar.getAll(),setAll:items=>items.forEach(({name,value,options})=>jar.set(name,value,{...options,path:'/',maxAge:options.maxAge??60*60*24*30,httpOnly:true,secure,sameSite:secure&&!hosted?'none':'lax',partitioned:secure&&!hosted}))}});
}
