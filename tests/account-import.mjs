import assert from 'node:assert/strict';
import * as XLSX from 'xlsx';
import {parseAccountWorkbook,importAccounts} from '../lib/account-import.mjs';
const encode=rows=>{const wb=XLSX.utils.book_new();XLSX.utils.book_append_sheet(wb,XLSX.utils.aoa_to_sheet(rows),'Accounts');return XLSX.write(wb,{type:'base64',bookType:'xlsx'});};
const headers=['Role','Nama','Email','Password','Kelas'];
const row=['guru','Test teacher','teacher@example.test','  Password123  ',''];
const parsed=parseAccountWorkbook(encode([headers,row]));
assert.equal(parsed[0].password,'  Password123  ');
assert.equal(parsed[0].baris,2);
assert.throws(()=>parseAccountWorkbook(encode([headers.slice(1),row])),/Kolom/);
assert.throws(()=>parseAccountWorkbook(encode([headers,...Array(21).fill(row)])),/1–20/);
assert.throws(()=>parseAccountWorkbook('x'.repeat(1_400_001)),/1 MB/);
function mock({preview='created',result='created',saveError=false,cleanupError=false,createError=false}={}){
 const calls={create:0,delete:0,rpc:0};
 const client={rpc:async(_name,args)=>{calls.rpc++;return args.account?{data:{status:result},error:saveError?{code:'23505'}:null}:{data:{status:preview}};},auth:{admin:{createUser:async()=>{calls.create++;return createError?{error:{message:'MUST NOT LEAK'}}:{data:{user:{id:'new-auth-id'}}};},deleteUser:async()=>{calls.delete++;return {error:cleanupError?{}:null};}}}};
 return {client,calls};
}
let m=mock();let result=await importAccounts(m.client,'school','actor',parsed);assert.equal(result.inserted,1);assert.equal(m.calls.delete,0);
m=mock({preview:'linked',result:'linked'});result=await importAccounts(m.client,'school','actor',parsed);assert.equal(result.linked,1);
m=mock({preview:'skipped'});result=await importAccounts(m.client,'school','actor',parsed);assert.equal(result.skipped,1);assert.equal(m.calls.create,0);
m=mock({saveError:true});result=await importAccounts(m.client,'school','actor',parsed);assert.equal(result.errors.length,1);assert.equal(m.calls.delete,1);
m=mock({saveError:true,cleanupError:true});result=await importAccounts(m.client,'school','actor',parsed);assert.match(result.errors[0].pesan,/membersihkan/);
m=mock({createError:true});result=await importAccounts(m.client,'school','actor',parsed);assert.equal(m.calls.delete,0);assert.ok(!JSON.stringify(result).includes('MUST NOT LEAK'));
m=mock();result=await importAccounts(m.client,'school','actor',[...parsed,...parsed]);assert.equal(m.calls.create,1);assert.equal(result.errors.length,1);
m=mock();result=await importAccounts(m.client,'school','actor',[{...parsed[0],role:'admin'}]);assert.equal(m.calls.create,0);assert.equal(result.errors.length,1);
assert.ok(!JSON.stringify(result).includes(parsed[0].password));
console.log('Lulus: parsing Excel akun, batas ukuran/baris, validasi role, duplikat, skip, link, cleanup, dan pesan tanpa password.');
