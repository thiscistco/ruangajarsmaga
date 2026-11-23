import assert from 'node:assert/strict';
import {webAccess} from '../lib/web-access.mjs';
const user={id:'u'};
function db(rows,failed){return {from(table){let filters=[];const query={select(){return query},eq(k,v){filters.push([k,v]);return query},limit(n){query.max=n;return query},then(resolve,reject){return Promise.resolve({data:(rows[table]||[]).filter(row=>filters.every(([k,v])=>row[k]===v)).slice(0,query.max),error:failed===table?{}:null}).then(resolve,reject)}};return query}}}
const m=(role,school_id='a',active=true)=>({user_id:'u',school_id,role,active});
const profile={id:'p',user_id:'u',school_id:'a'};
assert.equal(await webAccess(db({}),null),null);
assert.equal(await webAccess(db({memberships:[m('teacher','a',false)],teachers:[profile]}),user),null);
assert.equal(await webAccess(db({memberships:[m('teacher')]}),user),null);
assert.equal(await webAccess(db({memberships:[m('teacher')],teachers:[{...profile,user_id:'other'}]}),user),null);
assert.equal(await webAccess(db({memberships:[m('teacher')],teachers:[{...profile,school_id:'b'}]}),user),null);
assert.equal(await webAccess(db({memberships:[m('student')],students:[profile,profile]}),user),null);
assert.equal(await webAccess(db({memberships:[m('admin'),m('student','b')]}),user),null);
for(const [role,table] of [['teacher','teachers'],['student','students']])assert.deepEqual(await webAccess(db({memberships:[m(role)],[table]:[profile]}),user),{schoolId:'a',roles:[role]});
assert.deepEqual(await webAccess(db({memberships:[m('admin'),m('teacher')],teachers:[profile]}),user),{schoolId:'a',roles:['admin','teacher']});
assert.deepEqual(await webAccess(db({memberships:[m('admin')]}),user),{schoolId:'a',roles:['admin']});
await assert.rejects(()=>webAccess(db({},'memberships'),user));
await assert.rejects(()=>webAccess(db({memberships:[m('student')]},'students'),user));
console.log('Web access: active roles, profile matching, multi-school rejection, fail-closed queries PASS');
