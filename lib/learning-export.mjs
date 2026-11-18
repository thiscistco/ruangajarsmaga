const specs={
 absensi:{title:'Absensi',columns:[['nama','Nama siswa'],['kelas','Kelas'],['mapel','Mata pelajaran'],['guruNama','Guru'],['tanggal','Tanggal'],['status','Status']]},
 jurnal:{title:'Jurnal Mengajar',columns:[['nama','Judul jurnal'],['kelas','Kelas'],['mapel','Mata pelajaran'],['guruNama','Guru'],['tanggal','Tanggal']]},
 materi:{title:'Materi Pembelajaran',columns:[['nama','Judul materi'],['kelas','Kelas'],['mapel','Mata pelajaran'],['guruNama','Guru'],['isi','Isi materi'],['status','Status']]},
 nilai:{title:'Penilaian',columns:[['nama','Nama siswa'],['kelas','Kelas'],['mapel','Mata pelajaran'],['guruNama','Guru'],['nilai','Nilai']]}
};
export function buildLearningReport(page,rows,data,query,now=new Date()){
 const spec=specs[page];if(!spec)throw Error('Menu tidak mendukung ekspor.');
 const teachers=new Map((data.guru||[]).map(t=>[t.id,t.nama]));
 return {title:spec.title,school:data.pengaturan?.nama||'Sekolah',query:query||'',createdAt:now.toLocaleString('id-ID',{timeZone:'Asia/Jakarta'}),filename:`ruangajar-${page}-${now.toISOString().slice(0,10)}.xlsx`,headers:spec.columns.map(([,label])=>label),rows:rows.map(r=>spec.columns.map(([key])=>key==='guruNama'?(teachers.get(r.guru)||'—'):(r[key]??'')))};
}
export function reportWorkbook(XLSX,report){
 const wb=XLSX.utils.book_new();
 const sheet=XLSX.utils.aoa_to_sheet([[report.title],[report.school],['Dicetak (WIB)',report.createdAt],['Pencarian',report.query||'Semua data yang dimuat'],['Jumlah baris',report.rows.length],[],report.headers,...report.rows]);
 // aoa_to_sheet writes strings (including leading =, +, -, @) as text, not formulas.
 sheet['!cols']=report.headers.map(h=>({wch:h==='Isi materi'?65:24}));
 XLSX.utils.book_append_sheet(wb,sheet,'Laporan');return wb;
}
