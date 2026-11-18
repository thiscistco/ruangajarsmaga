// File/password data stays in the caller's memory only, never persistent browser storage.
export async function runAccountBatches(send,onProgress){
 const summary={inserted:0,linked:0,skipped:0,errors:[]};
 let offset=0,total=null;
 while(true){
  let result;
  try{result=await send(offset);}catch(error){
   const stopped=new Error(`${error.message||'Koneksi terputus.'} Impor berhenti setelah ${offset} baris yang hasilnya sudah diterima. Batch berikutnya mungkin sudah diproses; periksa profil/Auth sebelum mengulang. Baris selanjutnya belum dikirim.`);
   stopped.summary=summary;stopped.processed=offset;stopped.total=total;throw stopped;
  }
  total=result.total;
  if(!Number.isInteger(total)||total<1||total>500||result.nextOffset!==Math.min(offset+10,total)||result.done!==(result.nextOffset===total)||!Array.isArray(result.summary?.errors))throw Error('Respons progres impor tidak valid. Periksa hasil sebelum mengulang.');
  for(const key of ['inserted','linked','skipped'])summary[key]+=result.summary[key]||0;
  summary.errors.push(...result.summary.errors);
  offset=result.nextOffset;
  onProgress({processed:offset,total,summary:{...summary,errors:[...summary.errors]}});
  if(result.done)return {...result,summary};
 }
}
