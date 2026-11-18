import {NextResponse as R} from 'next/server';
import {cookies,headers} from 'next/headers';
import {createServerClient} from '@supabase/ssr';
import {createClient} from '@supabase/supabase-js';
import * as XLSX from 'xlsx';
export const dynamic='force-dynamic';
const json=(data,status=200)=>R.json(data,{status,headers:{'Cache-Control':'private, no-store'}});
const err=(error,status=400)=>json({error},status);
const hosted=process.env.VERCEL==='1';
const bearer=req=>req.headers.get('authorization')?.match(/^Bearer ([^\s]+)$/i)?.[1];
async function client(token){
 const {SUPABASE_URL:url,SUPABASE_PUBLISHABLE_KEY:key}=process.env;
 if(!url||!key)return null;
 if(token)return createClient(url,key,{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
 const jar=await cookies();
 const h=await headers();
 const secure=h.get('x-forwarded-proto')?.split(',')[0].trim()==='https'||h.get('host')?.endsWith('.e2b.app')||process.env.NODE_ENV==='production';
 return createServerClient(url,key,{cookies:{getAll:()=>jar.getAll(),setAll:items=>items.forEach(({name,value,options})=>jar.set(name,value,{...options,path:'/',maxAge:options.maxAge??60*60*24*30,httpOnly:true,secure,sameSite:secure&&!hosted?'none':'lax',partitioned:secure&&!hosted}))}});
}
async function schoolFor(db,user){
 const {data,error}=await db.from('memberships').select('school_id').eq('user_id',user.id).eq('role','admin').eq('active',true).order('school_id').limit(2);
 if(error||data?.length!==1)return null;
 return data[0].school_id;
}
async function read(db,s){
 const names=['teachers','students','classes','subjects','assignments','enrollments','attendance','materials','journals','grades','audit_log','memberships','schools','terms'];
 const result=await Promise.all(names.map(n=>db.from(n).select('*').eq(n==='schools'?'id':'school_id',s)));
 if(result.some(r=>r.error))throw Error('Gagal membaca data sekolah.');
 const [teachers,students,classes,subjects,assignments,enrollments,attendance,materials,journals,grades,audit,members,schools,terms]=result.map(x=>x.data);
 const cls=id=>classes.find(x=>x.id===id)?.name??'—', subj=id=>subjects.find(x=>x.id===id)?.name??'—', student=id=>students.find(x=>x.id===id)?.name??'—';
 const ctx=id=>{const a=assignments.find(x=>x.id===id);return {guru:a?.teacher_id,kelas:cls(a?.class_id)}};
 const gradeOrder=['X','XI','XII'];
 const shortKelas=name=>{const i=name.lastIndexOf('-');return i>0?name.slice(i+1):name};
 const groupKelas=ids=>{const g={};[...new Set(ids)].forEach(id=>{const c=classes.find(x=>x.id===id);if(c)(g[c.grade]=g[c.grade]||[]).push(shortKelas(c.name))});return Object.keys(g).sort((a,b)=>gradeOrder.indexOf(a)-gradeOrder.indexOf(b)).map(k=>{const names=g[k].sort((a,b)=>a.localeCompare(b,'id',{numeric:true}));return `${k} (${names.join(', ')})`}).join(', ')||'—'};
 return {penugasan:assignments.map(a=>({id:a.id,guruId:a.teacher_id,kelasId:a.class_id,mapelId:a.subject_id,nama:teachers.find(t=>t.id===a.teacher_id)?.name,kelas:cls(a.class_id),mapel:subj(a.subject_id),semester:terms.find(t=>t.id===classes.find(c=>c.id===a.class_id)?.term_id)})),pengaturan:{nama:schools[0]?.name,aktif:terms.find(t=>t.active),semester:terms.sort((a,b)=>b.academic_year.localeCompare(a.academic_year)||b.semester.localeCompare(a.semester))},guru:teachers.flatMap(t=>{const aa=assignments.filter(a=>a.teacher_id===t.id);const base={id:t.id,nama:t.name,email:t.email,aktif:members.some(m=>m.role==='teacher'&&m.user_id===t.user_id&&m.active)};if(!aa.length)return[{...base,mapel:'—',kelas:'—',rowKey:t.id+'-x'}];const groups=new Map();aa.forEach(a=>{const c=classes.find(x=>x.id===a.class_id);const key=a.subject_id+'|'+(c?c.grade:'');if(!groups.has(key))groups.set(key,{subject:a.subject_id,grade:c?c.grade:'',ids:[]});groups.get(key).ids.push(a.class_id)});return[...groups.values()].sort((x,y)=>subj(x.subject).localeCompare(subj(y.subject),'id')||gradeOrder.indexOf(x.grade)-gradeOrder.indexOf(y.grade)).map(g=>({...base,mapel:subj(g.subject),kelas:groupKelas(g.ids),kelasDetail:[...new Set(g.ids)].map(id=>cls(id)).sort((a,b)=>a.localeCompare(b,'id',{numeric:true})).join(', '),rowKey:t.id+'-'+g.subject+'-'+g.grade}))}),siswa:students.map(t=>({id:t.id,nama:t.name,nis:t.nis,kelas:enrollments.filter(e=>e.student_id===t.id).map(e=>cls(e.class_id)).sort((a,b)=>a.localeCompare(b,'id',{numeric:true})).join(', ')})),kelas:classes.map(c=>({id:c.id,nama:c.name,tingkat:c.grade,termId:c.term_id})).sort((a,b)=>a.nama.localeCompare(b.nama,'id',{numeric:true})),mapel:subjects.map(c=>({id:c.id,nama:c.name})),absensi:attendance.map(a=>({id:a.id,nama:student(a.student_id),tanggal:a.day,status:a.status,...ctx(a.assignment_id)})),materi:materials.map(a=>({id:a.id,nama:a.title,isi:a.body,status:a.published_at?'Terbit':'Draf',penerbit:a.published_by,...ctx(a.assignment_id)})),jurnal:journals.map(a=>({id:a.id,nama:a.title,tanggal:a.day,...ctx(a.assignment_id)})),nilai:grades.map(a=>({id:a.id,nama:student(a.student_id),nilai:a.score,...ctx(a.assignment_id)})),riwayat:audit.sort((a,b)=>b.created_at.localeCompare(a.created_at)).map(a=>({id:a.id,nama:({publish_material:'Materi diterbitkan',correct_attendance:'Absensi dikoreksi',teacher_preview:'Pratinjau guru dibuka',school_settings:'Pengaturan sekolah diperbarui',teacher_assignment:'Penugasan guru dibuat',assignment_catalog:'Data penugasan ditambahkan',catalog_edit:'Data diperbarui',catalog_delete:'Data dihapus'})[a.action]||a.action,detail:a.detail.reason?`${a.detail.before} → ${a.detail.after} · ${a.detail.reason}`:a.detail.year?`${a.detail.name} · ${a.detail.year} · ${a.detail.semester}`:a.entity_id,pelaku:a.actor_id,waktu:a.created_at}))};
}
export async function GET(req){
 const token=hosted?undefined:bearer(req);const db=await client(token);if(!db)return json({data:{},authenticated:false,configured:false});
 try{const {data:{user}}=await db.auth.getUser(token);const s=user&&await schoolFor(db,user);return json({data:s?await read(db,s):{},authenticated:!!s,configured:true});}catch{return err('Gagal memuat data sekolah.',503)}
}
const actionUsesCookies=action=>action==='login'||action==='logout';
export async function POST(req){
 // Form requests are same-origin; do not accept cross-site requests or non-JSON bodies.
 if(req.headers.get('sec-fetch-site')==='cross-site'||!req.headers.get('content-type')?.startsWith('application/json'))return err('Permintaan ditolak.',403);
 let body;try{body=await req.json()}catch{return err('Data tidak valid.')}
 if(!body||typeof body!=='object')return err('Data tidak valid.');
 const token=hosted?undefined:typeof body.sessionToken==='string'&&body.sessionToken.length<8192?body.sessionToken:bearer(req);const db=await client(actionUsesCookies(body.action)?undefined:token);if(!db)return err('Supabase belum dikonfigurasi untuk workspace ini.',503);
 const {action,id}=body;
 if(action==='login'){
  if(typeof body.email!=='string'||typeof body.password!=='string')return err('Masukkan email dan kata sandi.');
  const {data,error}=await db.auth.signInWithPassword({email:body.email,password:body.password});
  if(error||!data.user)return err('Tidak bisa masuk. Periksa kredensial.',401);
  const s=await schoolFor(db,data.user);
  if(!s){await db.auth.signOut({scope:'local'});return err('Akun tidak memiliki akses admin ke satu sekolah.',403);}
  try{return json({authenticated:true,accessToken:hosted?undefined:data.session?.access_token,data:await read(db,s)});}catch{await db.auth.signOut({scope:'local'});return err('Login berhasil, tetapi data sekolah gagal dimuat.',503);}
 }
 if(action==='logout'){await db.auth.signOut({scope:'local'});return json({authenticated:false});}
 const {data:{user}}=await db.auth.getUser(token);const s=user&&await schoolFor(db,user);if(!s)return err('Masuk sebagai admin terlebih dahulu.',401);
 if(action==='edit'||action==='delete'){
  if(typeof id!=='string'||!/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(id))return err('Data tidak valid.');
  const {error}=await db.rpc('manage_school_record',{s,kind:body.type,item:id,operation:action,payload:{nama:body.nama,email:body.email,nis:body.nis,tingkat:body.tingkat,guru:body.guru,kelas:body.kelas,mapel:body.mapel}});
  if(error)return err(({23503:'Data masih terkait dengan akun atau catatan lain dan tidak dapat diubah dengan tindakan ini.',23505:'Data duplikat.',42501:'Akses ditolak.'})[error.code]||'Periksa data dan semester aktif.',error.code==='42501'?403:400);
  try{return json({data:await read(db,s)});}catch{return err('Perubahan tersimpan, tetapi data belum bisa dimuat ulang.',503);}
 }
 if(action==='add'&&['guru','kelas','mapel'].includes(body.type)){
  const {error}=await db.rpc('add_assignment_catalog',{s,kind:body.type,label:body.nama,extra:body.email??body.tingkat??null});
  if(error)return err(error.code==='23505'?'Data ini sudah ada.':error.code==='42501'?'Akses ditolak.':'Periksa data dan semester aktif.',error.code==='42501'?403:400);
  try{return json({data:await read(db,s)});}catch{return err('Data tersimpan, tetapi belum bisa dimuat ulang.',503);}
 }
 if(action==='assignment'){
  const {guru,kelas,mapel}=body;
  if(![guru,kelas,mapel].every(v=>typeof v==='string'&&/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(v)))return err('Pilih guru, kelas, dan mata pelajaran.');
  const {error}=await db.rpc('add_teacher_assignment',{s,t:guru,c:kelas,subject:mapel});
  if(error)return err(error.code==='23505'?'Penugasan ini sudah ada.':error.code==='42501'?'Akses ditolak.':'Pilih data dari sekolah dan semester aktif.',error.code==='42501'?403:400);
  try{return json({data:await read(db,s)});}catch{return err('Penugasan tersimpan, tetapi data gagal dimuat ulang.',503);}
 }
 if(action==='settings'){
  const {error}=await db.rpc('save_school_settings',{s,school_name:body.nama,year_label:body.tahun,semester_label:body.semester});
  if(error)return err(error.code==='42501'?'Akses ditolak.':error.code==='22023'?'Periksa nama, tahun ajaran berurutan (YYYY/YYYY), dan semester.':'Pengaturan belum dapat disimpan.',error.code==='42501'?403:400);
  try{return json({data:await read(db,s)});}catch{return err('Pengaturan tersimpan, tetapi data belum bisa dimuat ulang.',503)}
 }
 if(action==='import'){
  const kinds={guru:['import_teachers',['nama','email']],siswa:['import_students',['nama','nis','kelas']],kelas:['import_classes',['nama','tingkat']],mapel:['import_subjects',['nama']],penugasan:['import_assignments',['guru','kelas','mapel']]};
  const spec=kinds[body.type];
  if(!spec||typeof body.file!=='string'||!body.file.length||body.file.length>15_000_000)return err('File impor tidak valid.');
  let parsed;
  try{
   const wb=XLSX.read(Buffer.from(body.file,'base64'),{type:'buffer'});
   const ws=wb.Sheets[wb.SheetNames[0]];
   if(!ws)return err('Sheet pertama tidak ditemukan.');
   const raw=XLSX.utils.sheet_to_json(ws,{header:1,defval:''});
   if(raw.length<2)return err('File kosong atau tidak memiliki baris data.');
   const headers=raw[0].map(h=>String(h).trim().toLowerCase());
   const idx=spec[1].map(f=>headers.indexOf(f));
   if(idx.some(i=>i<0))return err(`Kolom wajib: ${spec[1].join(', ')}.`);
   parsed=raw.slice(1).filter(r=>r.some(v=>String(v).trim()!=='')).map(r=>Object.fromEntries(spec[1].map((f,i)=>[f,String(r[idx[i]]??'').trim()])));
  }catch(e){if(e.message&&/Kolom|File|Sheet/.test(e.message))throw e;return err('File Excel tidak dapat dibaca.')}
  if(!parsed.length)return err('Tidak ada baris data untuk diimpor.');
  const {data:summary,error}=await db.rpc(spec[0],{s,rows:parsed});
  if(error)return err(error.code==='42501'?'Akses ditolak.':error.message||'Impor gagal.',error.code==='42501'?403:400);
  try{return json({data:await read(db,s),summary});}catch{return err('Impor tersimpan, tetapi data belum bisa dimuat ulang.',503)}
 }
 const routes={preview:['audit_teacher_preview',{s,t:id}],correct:['correct_attendance',{s,a:id,new_status:body.status,reason:body.alasan}],publish:['publish_material',{s,m:id}]};
 if(!Object.hasOwn(routes,action))return err('Pengelolaan data sekolah masuk Tahap 2.',409);
 if(typeof id!=='string'||!/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(id))return err('ID data tidak valid.');
 const [fn,args]=routes[action];const {error}=await db.rpc(fn,args);
 if(error)return err(error.code==='42501'?'Akses ditolak.':'Tindakan gagal. Periksa status dan data yang dipilih.',error.code==='42501'?403:400);
 try{return json({data:await read(db,s)});}catch{return err('Tindakan tersimpan, tetapi data belum bisa dimuat ulang.',503)}
}
