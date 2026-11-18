import assert from 'node:assert/strict';
import * as XLSX from 'xlsx';
import {runAccountBatches} from '../lib/import-batches.mjs';
import {buildLearningReport,reportWorkbook} from '../lib/learning-export.mjs';
let offsets=[],progress=[];
const result=await runAccountBatches(async offset=>{offsets.push(offset);return {nextOffset:offset+10,total:500,done:offset===490,summary:{inserted:8,linked:1,skipped:0,errors:[{baris:offset+11,pesan:'Test error'}]}}},p=>progress.push(p.processed));
assert.equal(offsets.length,50);assert.equal(progress.at(-1),500);assert.equal(result.summary.inserted,400);assert.equal(result.summary.linked,50);assert.equal(result.summary.errors.length,50);
let sent=0;
await assert.rejects(runAccountBatches(async offset=>{sent++;if(offset===10)throw Error('Disconnected');return {nextOffset:10,total:30,done:false,summary:{inserted:10,errors:[]}}},()=>{}),e=>e.processed===10&&e.summary.inserted===10&&/mungkin/.test(e.message));
assert.equal(sent,2); // failed batch is never automatically retried
const partial=await runAccountBatches(async offset=>({nextOffset:Math.min(offset+10,13),total:13,done:offset===10,summary:{inserted:offset===0?10:3,errors:[]}}),()=>{});
assert.equal(partial.summary.inserted,13);
const data={guru:[{id:'t',nama:'Guru'}],pengaturan:{nama:'Sekolah <script>'}};
const rows=[{nama:'=HYPERLINK("https://example.test")',kelas:'X-1',mapel:'Fisika',guru:'t',tanggal:'2026-11-18',status:'Hadir',nilai:0,isi:'<script>alert(1)</script>\nLong material'}];
for(const page of ['absensi','jurnal','materi','nilai']){
 const report=buildLearningReport(page,rows,data,'X-1',new Date('2026-11-18T00:00:00Z'));
 assert.equal(report.rows.length,1);assert.equal(report.query,'X-1');assert.ok(report.rows[0].includes('Guru'));
 const wb=reportWorkbook(XLSX,report);const bytes=XLSX.write(wb,{type:'buffer',bookType:'xlsx'});const sheet=XLSX.read(bytes,{type:'buffer'}).Sheets.Laporan;
 assert.equal(sheet.A8.t,'s');assert.equal(sheet.A8.f,undefined);assert.equal(sheet.A8.v,rows[0].nama);
 if(page==='nilai')assert.equal(report.rows[0].at(-1),0);
 if(page==='materi')assert.ok(report.rows[0].includes(rows[0].isi));
}
assert.throws(()=>buildLearningReport('guru',rows,data,''));
assert.equal(buildLearningReport('absensi',[],data,'').rows.length,0);
console.log('Lulus: 500 baris / 50 batch, progres, hasil parsial tanpa retry otomatis, empat ekspor Excel dan teks bukan formula.');
