alter table public.students alter column nis drop not null;
-- Auth user creation happens on the server; all public records commit atomically here.
create or replace function public.add_profile_account(s uuid, actor uuid, kind text, account uuid, label text, email text, nis text default null, class_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare item uuid; account_role text;
begin
 if not exists(select 1 from public.memberships where school_id=s and user_id=actor and role='admin' and active) then
  raise exception 'Admin required' using errcode='42501';
 end if;
 if kind is null or kind not in ('guru','siswa') or label is null or length(btrim(label)) not between 1 and 120
 or email is null or length(email)>254 or email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
  raise exception 'Invalid profile' using errcode='22023';
 end if;
 perform 1 from public.schools where id=s for update;
 if kind='siswa' then
  if (nis is not null and length(btrim(nis)) not between 1 and 60) or not exists(
   select 1 from public.classes c join public.terms t on (t.school_id,t.id)=(c.school_id,c.term_id)
   where c.school_id=s and c.id=class_id and t.active
  ) then raise exception 'Invalid NIS or active class' using errcode='22023'; end if;
 end if;
 if exists(select 1 from public.memberships where user_id=account) then
  raise exception 'Account already linked' using errcode='23505';
 end if;
 account_role:=case kind when 'guru' then 'teacher' else 'student' end;
 insert into public.memberships(school_id,user_id,role,active) values(s,account,account_role,true);
 if kind='guru' then
  insert into public.teachers(school_id,user_id,name,email) values(s,account,btrim(label),lower(btrim(email))) returning id into item;
 else
  insert into public.students(school_id,user_id,name,nis) values(s,account,btrim(label),btrim(nis)) returning id into item;
  insert into public.enrollments(school_id,class_id,student_id) values(s,class_id,item);
 end if;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail)
 values(s,actor,'create_profile_account',item,jsonb_build_object('kind',kind,'user_id',account));
 return item;
end $$;
revoke all on function public.add_profile_account(uuid,uuid,text,uuid,text,text,text,uuid) from public,anon,authenticated;
grant execute on function public.add_profile_account(uuid,uuid,text,uuid,text,text,text,uuid) to service_role;

create or replace function public.manage_school_record(s uuid, kind text, item uuid, operation text, payload jsonb default '{}'::jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare tab text; label text:=btrim(payload->>'nama'); extra text; affected integer; t uuid; c uuid; m uuid;
begin
 if not private.has_role(s,'admin') then raise exception 'Akses ditolak' using errcode='42501'; end if;
 tab:=case kind when 'guru' then 'teachers' when 'siswa' then 'students' when 'kelas' then 'classes' when 'mapel' then 'subjects' when 'penugasan' then 'assignments' end;
 if tab is null or operation is null or operation not in ('edit','delete') then raise exception 'Operasi tidak valid' using errcode='22023'; end if;
 perform 1 from public.schools where id=s for update;
 if operation='delete' then
  if (kind='guru' and exists(select 1 from public.teachers where school_id=s and id=item and user_id is not null)) or (kind='siswa' and exists(select 1 from public.students where school_id=s and id=item and user_id is not null)) then raise exception 'Profil terkait akun login' using errcode='23503'; end if;
  execute format('delete from public.%I where school_id=$1 and id=$2',tab) using s,item;
 else
  if kind<>'penugasan' and (label is null or length(label) not between 1 and 120) then raise exception 'Nama tidak valid' using errcode='22023'; end if;
  case kind
  when 'guru' then
   extra:=lower(btrim(payload->>'email'));
   if extra is null or length(extra)>254 or extra !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Email tidak valid' using errcode='22023'; end if;
   update public.teachers set name=label,email=extra where school_id=s and id=item;
  when 'siswa' then
   update public.students set name=label where school_id=s and id=item;
  when 'kelas' then
   extra:=payload->>'tingkat'; if extra is null or extra not in ('X','XI','XII') then raise exception 'Tingkat tidak valid' using errcode='22023'; end if;
   update public.classes set name=label,grade=extra where school_id=s and id=item;
  when 'mapel' then update public.subjects set name=label where school_id=s and id=item;
  when 'penugasan' then
   t:=(payload->>'guru')::uuid; c:=(payload->>'kelas')::uuid; m:=(payload->>'mapel')::uuid;
   if not exists(select 1 from public.assignments a join public.classes x on (a.school_id,a.class_id)=(x.school_id,x.id) join public.terms y on (x.school_id,x.term_id)=(y.school_id,y.id) where a.school_id=s and a.id=item and y.active) or not exists(select 1 from public.classes x join public.terms y on (x.school_id,x.term_id)=(y.school_id,y.id) where x.school_id=s and x.id=c and y.active) or not exists(select 1 from public.teachers where school_id=s and id=t) or not exists(select 1 from public.subjects where school_id=s and id=m) then raise exception 'Pilih data semester aktif' using errcode='22023'; end if;
   if exists(select 1 from public.attendance where school_id=s and assignment_id=item) or exists(select 1 from public.grades where school_id=s and assignment_id=item) or exists(select 1 from public.materials where school_id=s and assignment_id=item) or exists(select 1 from public.journals where school_id=s and assignment_id=item) then raise exception 'Penugasan sudah digunakan' using errcode='23503'; end if;
   update public.assignments set teacher_id=t,class_id=c,subject_id=m where school_id=s and id=item;
  end case;
 end if;
 get diagnostics affected=row_count;
 if affected<>1 then raise exception 'Data tidak ditemukan' using errcode='22023'; end if;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail) values(s,auth.uid(),'catalog_'||operation,item,jsonb_build_object('kind',kind));
end $$;
revoke all on function public.manage_school_record(uuid,text,uuid,text,jsonb) from public,anon;
grant execute on function public.manage_school_record(uuid,text,uuid,text,jsonb) to authenticated;

-- Preview and finalize use the same matching rules; never trust browser-supplied profile IDs.
create function public.import_profile_account(s uuid, actor uuid, kind text, label text, email text, class_name text default null, account uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare item uuid; cid uuid; linked uuid; matches integer; account_role text; outcome text;
begin
 if not exists(select 1 from public.memberships where school_id=s and user_id=actor and role='admin' and active) then
  raise exception 'Admin required' using errcode='42501';
 end if;
 if kind is null or kind not in ('guru','siswa') or label is null or length(btrim(label)) not between 1 and 120
 or email is null or length(email)>254 or email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
  raise exception 'Nama, email, atau role tidak valid' using errcode='22023';
 end if;
 perform 1 from public.schools where id=s for update;
 if kind='guru' then
  select id,user_id into item,linked from public.teachers where school_id=s and lower(teachers.email)=lower(btrim(import_profile_account.email)) for update;
  if item is not null and not exists(select 1 from public.teachers where school_id=s and id=item and lower(btrim(name))=lower(btrim(label))) then
   raise exception 'Email profil guru cocok tetapi nama berbeda. Periksa profil lama.' using errcode='22023';
  end if;
  if item is null and exists(select 1 from public.teachers where school_id=s and lower(btrim(name))=lower(btrim(label))) then
   raise exception 'Nama guru sudah ada dengan email berbeda. Periksa profil lama.' using errcode='22023';
  end if;
 else
  select c.id into cid from public.classes c join public.terms t on (t.school_id,t.id)=(c.school_id,c.term_id)
  where c.school_id=s and t.active and c.name=btrim(class_name);
  if cid is null then raise exception 'Kelas siswa tidak ditemukan di semester aktif' using errcode='22023'; end if;
  select count(*) into matches from public.students st where st.school_id=s and lower(btrim(st.name))=lower(btrim(label));
  if matches>1 then raise exception 'Nama siswa cocok dengan beberapa profil. Periksa secara manual.' using errcode='22023'; end if;
  if matches=1 then
   select id,user_id into item,linked from public.students where school_id=s and lower(btrim(name))=lower(btrim(label)) for update;
   if not exists(select 1 from public.enrollments e where e.school_id=s and e.student_id=item and e.class_id=cid) then
    raise exception 'Nama siswa sudah ada tetapi kelas tidak cocok. Periksa profil lama.' using errcode='22023';
   end if;
  end if;
 end if;
 if linked is not null then return jsonb_build_object('status','skipped'); end if;
 outcome:=case when item is null then 'created' else 'linked' end;
 if account is null then return jsonb_build_object('status',outcome); end if;
 if exists(select 1 from public.memberships where user_id=account) then raise exception 'Akun sudah tertaut' using errcode='23505'; end if;
 account_role:=case kind when 'guru' then 'teacher' else 'student' end;
 insert into public.memberships(school_id,user_id,role,active) values(s,account,account_role,true);
 if item is null then
  if kind='guru' then
   insert into public.teachers(school_id,user_id,name,email) values(s,account,btrim(label),lower(btrim(email))) returning id into item;
  else
   insert into public.students(school_id,user_id,name) values(s,account,btrim(label)) returning id into item;
   insert into public.enrollments(school_id,class_id,student_id) values(s,cid,item);
  end if;
 elsif kind='guru' then
  update public.teachers set user_id=account where school_id=s and id=item;
 else
  update public.students set user_id=account where school_id=s and id=item;
 end if;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail)
 values(s,actor,'import_account',item,jsonb_build_object('kind',kind,'result',outcome));
 return jsonb_build_object('status',outcome);
end $$;
revoke all on function public.import_profile_account(uuid,uuid,text,text,text,text,uuid) from public,anon,authenticated;
grant execute on function public.import_profile_account(uuid,uuid,text,text,text,text,uuid) to service_role;
