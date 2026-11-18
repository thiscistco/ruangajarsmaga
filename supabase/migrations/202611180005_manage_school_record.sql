create function public.manage_school_record(s uuid, kind text, item uuid, operation text, payload jsonb default '{}') returns void
language plpgsql security definer set search_path='' as $$
declare tab text; label text:=btrim(payload->>'nama'); extra text; affected integer; t uuid; c uuid; m uuid;
begin
 if not private.has_role(s,'admin') then raise exception 'Akses ditolak' using errcode='42501'; end if;
 tab:=case kind when 'guru' then 'teachers' when 'siswa' then 'students' when 'kelas' then 'classes' when 'mapel' then 'subjects' when 'penugasan' then 'assignments' end;
 if tab is null or operation is null or operation not in ('edit','delete') then raise exception 'Operasi tidak valid' using errcode='22023'; end if;
 perform 1 from public.schools where id=s for update;
 if operation='delete' then
  if (kind='guru' and exists(select 1 from public.teachers where school_id=s and id=item and user_id is not null))
  or (kind='siswa' and exists(select 1 from public.students where school_id=s and id=item and user_id is not null))
  then raise exception 'Profil terkait akun login' using errcode='23503'; end if;
  execute format('delete from public.%I where school_id=$1 and id=$2',tab) using s,item;
 else
  if kind<>'penugasan' and (label is null or length(label) not between 1 and 120) then raise exception 'Nama tidak valid' using errcode='22023'; end if;
  case kind
  when 'guru' then
   extra:=lower(btrim(payload->>'email'));
   if extra is null or length(extra)>254 or extra !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Email tidak valid' using errcode='22023'; end if;
   update public.teachers set name=label,email=extra where school_id=s and id=item;
  when 'siswa' then
   extra:=btrim(payload->>'nis');
   if extra is null or length(extra) not between 1 and 60 then raise exception 'NIS tidak valid' using errcode='22023'; end if;
   update public.students set name=label,nis=extra where school_id=s and id=item;
  when 'kelas' then
   extra:=payload->>'tingkat';
   if extra is null or extra not in ('X','XI','XII') then raise exception 'Tingkat tidak valid' using errcode='22023'; end if;
   update public.classes set name=label,grade=extra where school_id=s and id=item;
  when 'mapel' then update public.subjects set name=label where school_id=s and id=item;
  when 'penugasan' then
   t:=(payload->>'guru')::uuid; c:=(payload->>'kelas')::uuid; m:=(payload->>'mapel')::uuid;
   if not exists(select 1 from public.assignments a join public.classes x on (a.school_id,a.class_id)=(x.school_id,x.id) join public.terms y on (x.school_id,x.term_id)=(y.school_id,y.id) where a.school_id=s and a.id=item and y.active)
   or not exists(select 1 from public.classes x join public.terms y on (x.school_id,x.term_id)=(y.school_id,y.id) where x.school_id=s and x.id=c and y.active)
   or not exists(select 1 from public.teachers where school_id=s and id=t)
   or not exists(select 1 from public.subjects where school_id=s and id=m)
   then raise exception 'Pilih data semester aktif' using errcode='22023'; end if;
   if exists(select 1 from public.attendance where school_id=s and assignment_id=item)
   or exists(select 1 from public.grades where school_id=s and assignment_id=item)
   or exists(select 1 from public.materials where school_id=s and assignment_id=item)
   or exists(select 1 from public.journals where school_id=s and assignment_id=item)
   then raise exception 'Penugasan sudah digunakan' using errcode='23503'; end if;
   update public.assignments set teacher_id=t,class_id=c,subject_id=m where school_id=s and id=item;
  end case;
 end if;
 get diagnostics affected=row_count;
 if affected<>1 then raise exception 'Data tidak ditemukan' using errcode='22023'; end if;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail) values(s,auth.uid(),'catalog_'||operation,item,jsonb_build_object('kind',kind));
end $$;
revoke all on function public.manage_school_record(uuid,text,uuid,text,jsonb) from public,anon;
grant execute on function public.manage_school_record(uuid,text,uuid,text,jsonb) to authenticated;
