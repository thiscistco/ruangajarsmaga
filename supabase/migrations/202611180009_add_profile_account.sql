-- Auth user creation happens on the server; all public records commit atomically here.
create function public.add_profile_account(s uuid, actor uuid, kind text, account uuid, label text, email text, nis text default null, class_id uuid default null)
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
  if nis is null or length(btrim(nis)) not between 1 and 60 or not exists(
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
