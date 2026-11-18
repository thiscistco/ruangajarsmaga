export const learningPages=['absensi','jurnal','materi','nilai'];
export const cascade=['tahun','semester','tingkat','kelasId','mapelId','guru','siswaId'];
export const filterLabels={tahun:'Tahun ajaran',semester:'Semester',tingkat:'Tingkat',kelasId:'Kelas',mapelId:'Mata pelajaran',guru:'Guru',siswaId:'Siswa',status:'Status',from:'Tanggal mulai',to:'Tanggal akhir',min:'Nilai minimum',max:'Nilai maksimum'};
const compare=(a,b)=>String(a??'').localeCompare(String(b??''),'id',{numeric:true,sensitivity:'base'});
export const defaultSort=page=>['absensi','jurnal'].includes(page)?'date_desc':'name_asc';
export function sortOptions(page){return [['name_asc','Nama / judul A–Z'],['name_desc','Nama / judul Z–A'],['class_asc','Kelas A–Z'],['class_desc','Kelas Z–A'],['teacher_asc','Guru A–Z'],...(['absensi','jurnal'].includes(page)?[['date_desc','Tanggal terbaru'],['date_asc','Tanggal terlama']]:[]),...(page==='nilai'?[['score_desc','Nilai tertinggi'],['score_asc','Nilai terendah']]:[])];}
export function changeFilter(filters,key,value){
 const next={...filters,[key]:value};
 const index=cascade.indexOf(key);
 if(index>=0)for(const child of cascade.slice(index+1))delete next[child];
 return next;
}
const matches=(row,filters,keys=cascade)=>keys.every(key=>!filters[key]||row[key]===filters[key]);
export function learningOptions(data,rows,filters){
 const contexts=(data.penugasan||[]).map(a=>({tahun:a.semester?.academic_year,semester:a.semester?.semester,tingkat:(data.kelas||[]).find(c=>c.id===a.kelasId)?.tingkat,kelasId:a.kelasId,mapelId:a.mapelId,guru:a.guruId,kelasLabel:`${a.kelas} · ${a.semester?.academic_year||'—'} · ${a.semester?.semester||'—'}`,mapelLabel:a.mapel,guruLabel:a.nama}));
 const result={};
 for(const [i,key] of cascade.entries()){
  const source=key==='siswaId'?rows:contexts;
  const choices=new Map();
  for(const r of source.filter(r=>matches(r,filters,cascade.slice(0,i)))){
   if(!r[key])continue;
   const label=key==='kelasId'?r.kelasLabel:key==='mapelId'?r.mapelLabel:key==='guru'?r.guruLabel:key==='siswaId'?r.nama:r[key];
   choices.set(r[key],label||r[key]);
  }
  result[key]=[...choices].map(([value,label])=>({value,label})).sort((a,b)=>key==='tingkat'?['X','XI','XII'].indexOf(a.value)-['X','XI','XII'].indexOf(b.value):key==='tahun'?compare(b.label,a.label):compare(a.label,b.label));
 }
 return result;
}
export function filterError(page,f){
 if(['absensi','jurnal'].includes(page)&&f.from&&f.to&&f.from>f.to)return 'Tanggal mulai tidak boleh melebihi tanggal akhir.';
 if(page==='nilai'){
  for(const key of ['min','max'])if(f[key]!==undefined&&f[key]!==''&&(!Number.isFinite(Number(f[key]))||Number(f[key])<0||Number(f[key])>100))return 'Batas nilai harus antara 0 dan 100.';
  if(f.min!==undefined&&f.min!==''&&f.max!==undefined&&f.max!==''&&Number(f.min)>Number(f.max))return 'Nilai minimum tidak boleh melebihi nilai maksimum.';
 }
 return '';
}
export function selectLearningRows(page,rows,data,filters={},sort=defaultSort(page),query=''){
 if(filterError(page,filters))return [];
 const teachers=new Map((data.guru||[]).map(t=>[t.id,t.nama]));
 const text=query.trim().toLocaleLowerCase('id');
 const selected=rows.filter(r=>{
  if(!matches(r,filters))return false;
  if(filters.status&&['absensi','materi'].includes(page)&&r.status!==filters.status)return false;
  if(['absensi','jurnal'].includes(page)&&((filters.from&&(!r.tanggal||r.tanggal<filters.from))||(filters.to&&(!r.tanggal||r.tanggal>filters.to))))return false;
  if(page==='nilai'){
   const score=r.nilai===null||r.nilai===undefined?NaN:Number(r.nilai);
   if(filters.min!==undefined&&filters.min!==''&&(!Number.isFinite(score)||score<Number(filters.min)))return false;
   if(filters.max!==undefined&&filters.max!==''&&(!Number.isFinite(score)||score>Number(filters.max)))return false;
  }
  return !text||[r.nama,r.kelas,r.mapel,r.tanggal,r.status,r.isi,r.nilai,teachers.get(r.guru)].some(v=>v!==undefined&&v!==null&&String(v).toLocaleLowerCase('id').includes(text));
 });
 const [key,direction]=sort.split('_');
 const get=r=>key==='date'?r.tanggal:key==='score'?r.nilai:key==='class'?r.kelas:key==='teacher'?teachers.get(r.guru):r.nama;
 return selected.sort((a,b)=>{
  const av=get(a),bv=get(b),missingA=av===undefined||av===null||av==='',missingB=bv===undefined||bv===null||bv==='';
  if(missingA!==missingB)return missingA?1:-1;
  const n=missingA?0:key==='score'?Number(av)-Number(bv):compare(av,bv);
  return (direction==='desc'?-n:n)||compare(a.id,b.id);
 });
}
export function describeLearningFilters(page,filters,options,sort){
 const parts=Object.entries(filters).filter(([,v])=>v!==''&&v!==undefined).map(([key,value])=>`${filterLabels[key]||key}: ${options[key]?.find(o=>o.value===value)?.label||value}`);
 parts.push(`Urutan: ${sortOptions(page).find(([key])=>key===sort)?.[1]||sort}`);
 return parts.join(' · ');
}
