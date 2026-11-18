import * as XLSX from 'xlsx';

export function parseAccountWorkbook(file){
 if(typeof file!=='string'||!file.length||file.length>1_400_000)throw Error('File akun maksimal 1 MB.');
 let raw;
 try{
  const wb=XLSX.read(Buffer.from(file,'base64'),{type:'buffer',sheetRows:23});
  const sheet=wb.Sheets[wb.SheetNames[0]];
  if(sheet?.['!fullref']&&XLSX.utils.decode_range(sheet['!fullref']).e.r>20)throw Error('too-many');
  raw=XLSX.utils.sheet_to_json(sheet,{header:1,defval:'',raw:false});
 }catch(e){throw Error(e.message==='too-many'?'Impor akun harus berisi 1–20 baris. Pecah file besar menjadi beberapa bagian.':'File Excel tidak dapat dibaca.');}
 const fields=['role','nama','email','password','kelas'];
 const headers=(raw[0]||[]).map(v=>String(v).trim().toLowerCase());
 if(fields.some(f=>headers.filter(h=>h===f).length!==1))throw Error('Kolom wajib (tanpa duplikat): Role, Nama, Email, Password, Kelas.');
 const rows=raw.slice(1).map((r,i)=>({r,baris:i+2})).filter(({r})=>r.some(v=>String(v).trim()));
 if(!rows.length||rows.length>20)throw Error('Impor akun harus berisi 1–20 baris. Pecah file besar menjadi beberapa bagian.');
 return rows.map(({r,baris})=>({...Object.fromEntries(fields.map(f=>[f,String(r[headers.indexOf(f)]??'')])),baris}));
}

export async function importAccounts(admin,s,actor,rows){
 const summary={inserted:0,linked:0,skipped:0,errors:[]};
 const seen=new Set();
 const started=Date.now();
 for(const row of rows){
  const kind=row.role.trim().toLowerCase(),name=row.nama.trim(),email=row.email.trim().toLowerCase();
  const fail=pesan=>summary.errors.push({baris:row.baris,pesan});
  if(Date.now()-started>40000){fail('Belum diproses karena batas waktu batch. Impor ulang baris ini saja.');continue;}
  if(!['guru','siswa'].includes(kind)||!name||name.length>120||email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||row.password.length<8||row.password.length>128||(kind==='siswa'&&!row.kelas.trim())){
   fail('Isi role guru/siswa, nama, email valid, password 8–128 karakter, dan kelas untuk siswa.');continue;
  }
  if(seen.has(email)){fail('Email berulang di dalam file. Satu baris per akun.');continue;}
  seen.add(email);
  const args={s,actor,kind,label:name,email,class_name:kind==='siswa'?row.kelas.trim():null};
  try{
   const {data:match,error:matchError}=await admin.rpc('import_profile_account',{...args,account:null});
   if(matchError){fail(matchError.code==='22023'?matchError.message:'Gagal memeriksa profil. Periksa izin admin dan konfigurasi migrasi.');continue;}
   if(match?.status==='skipped'){summary.skipped++;continue;}
   const {data:created,error:createError}=await admin.auth.admin.createUser({email,password:row.password,email_confirm:true});
   if(createError||!created?.user){fail('Akun tidak dibuat: email mungkin sudah terdaftar atau tidak memenuhi kebijakan Auth. Akun lama tidak diambil alih.');continue;}
   const uid=created.user.id;
   const {data:result,error:saveError}=await admin.rpc('import_profile_account',{...args,account:uid});
   if(saveError||result?.status==='skipped'){
    const {error:cleanupError}=await admin.auth.admin.deleteUser(uid);
    if(cleanupError){fail('Gagal membersihkan akun Auth baru. Pengelola perlu memeriksa Auth sebelum mencoba lagi.');continue;}
    if(saveError){fail('Profil tidak disimpan. Data mungkin berubah; periksa profil/kelas dan coba lagi.');continue;}
    summary.skipped++;continue;
   }
   if(result.status==='linked')summary.linked++;else summary.inserted++;
  }catch{
   // Do not delete on an unknown network outcome: the database may have committed.
   fail('Hasil belum dapat dipastikan karena gangguan koneksi. Periksa profil dan Supabase Auth sebelum mengulang.');
  }
 }
 return summary;
}
