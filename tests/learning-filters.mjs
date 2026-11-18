import assert from 'node:assert/strict';
import {changeFilter,learningOptions,selectLearningRows,defaultSort,filterError,describeLearningFilters} from '../lib/learning-filters.mjs';
import {buildLearningReport,reportWorkbook} from '../lib/learning-export.mjs';
import * as XLSX from 'xlsx';
const data={pengaturan:{nama:'Sekolah Uji'},guru:[{id:'g1',nama:'Budi'},{id:'g1',nama:'Budi'},{id:'g2',nama:'Ani'}],kelas:[{id:'c1',nama:'X-2',tingkat:'X'},{id:'c2',nama:'X-10',tingkat:'X'},{id:'c3',nama:'XI-1',tingkat:'XI'},{id:'c4',nama:'X-2',tingkat:'X'}],penugasan:[
 {kelasId:'c1',kelas:'X-2',mapelId:'m1',mapel:'Fisika',guruId:'g1',nama:'Budi',semester:{academic_year:'2026/2027',semester:'ganjil'}},
 {kelasId:'c2',kelas:'X-10',mapelId:'m2',mapel:'Kimia',guruId:'g2',nama:'Ani',semester:{academic_year:'2026/2027',semester:'ganjil'}},
 {kelasId:'c3',kelas:'XI-1',mapelId:'m2',mapel:'Kimia',guruId:'g2',nama:'Ani',semester:{academic_year:'2026/2027',semester:'genap'}},
 {kelasId:'c4',kelas:'X-2',mapelId:'m1',mapel:'Fisika',guruId:'g1',nama:'Budi',semester:{academic_year:'2025/2026',semester:'ganjil'}}]};
const rows=[
 {id:'1',nama:'Zaki',kelas:'X-2',kelasId:'c1',mapel:'Fisika',mapelId:'m1',guru:'g1',tahun:'2026/2027',semester:'ganjil',tingkat:'X',siswaId:'s1',tanggal:'2026-11-18',status:'Hadir',nilai:0},
 {id:'2',nama:'Ani',kelas:'X-10',kelasId:'c2',mapel:'Kimia',mapelId:'m2',guru:'g2',tahun:'2026/2027',semester:'ganjil',tingkat:'X',siswaId:'s2',tanggal:'2026-11-19',status:'Alpa',nilai:'90'},
 {id:'3',nama:'Zaki',kelas:'X-2',kelasId:'c4',mapel:'Fisika',mapelId:'m1',guru:'g1',tahun:'2025/2026',semester:'ganjil',tingkat:'X',siswaId:'s3',tanggal:'2025-11-18',status:'Izin',nilai:20},
 {id:'4',nama:'Ani',kelas:'XI-1',kelasId:'c3',mapel:'Kimia',mapelId:'m2',guru:'g2',tahun:'2026/2027',semester:'genap',tingkat:'XI',siswaId:'s2',tanggal:'2027-01-19',status:'Sakit',nilai:null}
];
const ids=rs=>rs.map(r=>r.id);
const opts=learningOptions(data,rows,{tahun:'2026/2027',semester:'ganjil',tingkat:'X',kelasId:'c1'});
assert.deepEqual(opts.kelasId.map(o=>o.value),['c1','c2']);
assert.deepEqual(opts.mapelId.map(o=>o.value),['m1']);assert.deepEqual(opts.guru.map(o=>o.value),['g1']);assert.deepEqual(opts.siswaId.map(o=>o.value),['s1']);
assert.equal(learningOptions(data,rows,{}).guru.length,2);
assert.deepEqual(changeFilter({tahun:'2026/2027',semester:'ganjil',tingkat:'X',kelasId:'c1',mapelId:'m1',guru:'g1',siswaId:'s1',status:'Hadir'},'tahun','2025/2026'),{tahun:'2025/2026',status:'Hadir'});
assert.deepEqual(ids(selectLearningRows('absensi',rows,data,{tahun:'2026/2027',semester:'ganjil',kelasId:'c1'})),['1']);
assert.deepEqual(ids(selectLearningRows('absensi',rows,data,{from:'2026-11-18',to:'2026-11-19'})),['2','1']);
assert.deepEqual(ids(selectLearningRows('absensi',rows,data,{status:'Hadir',siswaId:'s1'})),['1']);
assert.deepEqual(ids(selectLearningRows('jurnal',rows,data,{},'date_asc')),['3','1','2','4']);
assert.deepEqual(ids(selectLearningRows('nilai',rows,data,{min:'0',max:'0'})),['1']);
assert.deepEqual(ids(selectLearningRows('nilai',rows,data,{},'score_desc')),['2','3','1','4']);
assert.deepEqual(ids(selectLearningRows('nilai',rows,data,{},'score_asc')),['1','3','2','4']);
assert.deepEqual(ids(selectLearningRows('absensi',rows,data,{},'class_asc')),['1','3','2','4']);
assert.deepEqual(ids(selectLearningRows('absensi',rows,data,{},'teacher_asc','BUDI')),['1','3']);
assert.deepEqual(selectLearningRows('jurnal',rows,data,{from:'2026-12-01',to:'2026-11-01'}),[]);
assert.ok(filterError('nilai',{min:'80',max:'60'}));assert.ok(filterError('nilai',{min:'-1'}));assert.equal(filterError('nilai',{min:'0',max:'100'}),'');
assert.equal(defaultSort('jurnal'),'date_desc');assert.equal(defaultSort('materi'),'name_asc');
const materials=[{...rows[0],status:'Draf',nama:'Z materi',isi:'Isi satu'},{...rows[1],status:'Terbit',nama:'A materi',isi:'Isi dua'}];
assert.deepEqual(ids(selectLearningRows('materi',materials,data,{status:'Draf'})),['1']);
assert.deepEqual(ids(selectLearningRows('materi',materials,data,{},'name_asc','isi dua')),['2']);
assert.deepEqual(rows.map(r=>r.id),['1','2','3','4']); // sorting never mutates source
const f={tahun:'2026/2027',kelasId:'c1'};
const selected=selectLearningRows('nilai',rows,data,f,'score_desc');
const summary=describeLearningFilters('nilai',f,learningOptions(data,rows,f),'score_desc');
assert.match(summary,/X-2/);assert.match(summary,/Nilai tertinggi/);
const report=buildLearningReport('nilai',selected,data,'',new Date('2026-11-18T00:00:00Z'),summary);
assert.equal(report.rows.length,1);assert.equal(report.rows[0][0],'Zaki');assert.equal(report.rows[0].at(-1),0);
const workbook=reportWorkbook(XLSX,report);assert.equal(workbook.Sheets.Laporan.B6.v,summary);
assert.deepEqual(selectLearningRows('absensi',[],{},{}),[]);
console.log('Lulus: filter bertingkat, semester/kelas identik beda tahun, reset turunan, siswa/status/tanggal/nilai, sort natural, dan konsistensi ekspor.');
