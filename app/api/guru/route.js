import {NextResponse} from 'next/server';
import {client} from '../../../lib/server-client';
import {webAccess} from '../../../lib/web-access.mjs';
export const dynamic='force-dynamic';
const json=(data,status=200)=>NextResponse.json(data,{status,headers:{'Cache-Control':'private, no-store'}});
async function handle(req,write){
 try{
  if(write&&(req.headers.get('sec-fetch-site')==='cross-site'||!req.headers.get('content-type')?.startsWith('application/json')))return json({error:'Permintaan ditolak.'},403);
  const token=process.env.VERCEL==='1'?undefined:req.headers.get('authorization')?.match(/^Bearer ([^\s]+)$/i)?.[1];
  const db=await client(token);if(!db)return json({error:'Supabase belum dikonfigurasi.'},503);
  const {data:{user}}=await db.auth.getUser(token);const access=await webAccess(db,user);
  if(!access?.roles.includes('teacher'))return json({error:'Akses guru aktif diperlukan.'},403);
  if(write){
   const raw=await req.text();if(raw.length>16000)return json({error:'Data terlalu besar.'},413);
   let body;try{body=JSON.parse(raw)}catch{return json({error:'Data tidak valid.'},400)}
   if(!body||!['entry_save','entry_delete','meeting_create','meeting_edit','meeting_cancel'].includes(body.operation)||!body.payload||typeof body.payload!=='object'||Array.isArray(body.payload))return json({error:'Data tidak valid.'},400);
   const {error}=await db.rpc('save_teacher_planner',{s:access.schoolId,operation:body.operation,payload:body.payload});
   if(error)return json({error:({'42501':'Akses atau penugasan tidak sesuai.','40001':'Data sudah berubah. Muat ulang sebelum menyimpan.','23P01':'Jadwal bertumpuk dengan pertemuan lain.','22023':'Periksa tanggal, jam, rentang, dan alasan perubahan. Riwayat lampau tidak dapat diubah.'})[error.code]||'Gagal menyimpan. Periksa isian lalu coba lagi.'},error.code==='42501'?403:error.code==='40001'?409:400);
   return json({saved:true});
  }
  const month=new URL(req.url).searchParams.get('month');
  if(!/^\d{4}-(0[1-9]|1[0-2])-01$/.test(month||''))return json({error:'Bulan tidak valid.'},400);
  const {data,error}=await db.rpc('teacher_home',{s:access.schoolId,first_day:month});
  if(error)return json({error:'Beranda belum dapat dimuat. Silakan coba lagi.'},503);
  return json({data});
 }catch{return json({error:'Tidak dapat menghubungi layanan. Silakan coba lagi.'},503)}
}
export const GET=req=>handle(req,false);
export const POST=req=>handle(req,true);
