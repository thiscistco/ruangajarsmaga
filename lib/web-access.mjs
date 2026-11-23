// Resolve access only from server-verified membership and matching profiles.
export async function webAccess(db,user){
 if(!user)return null;
 const {data:members,error}=await db.from('memberships').select('school_id,role,active').eq('user_id',user.id).eq('active',true);
 if(error)throw Error('Gagal memeriksa akses akun.');
 const allowed=(members||[]).filter(m=>m.active&&['admin','teacher','student'].includes(m.role));
 const schools=[...new Set(allowed.map(m=>m.school_id))];
 if(schools.length!==1)return null;
 const schoolId=schools[0],roles=[];
 for(const role of ['admin','teacher','student']){
  if(!allowed.some(m=>m.role===role))continue;
  if(role==='admin'){roles.push(role);continue;}
  const {data,error}=await db.from(role==='teacher'?'teachers':'students').select('id').eq('school_id',schoolId).eq('user_id',user.id).limit(2);
  if(error)throw Error('Gagal memeriksa profil akun.');
  if(data?.length===1)roles.push(role);
 }
 return roles.length?{schoolId,roles}:null;
}
