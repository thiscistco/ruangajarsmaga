create function public.import_teachers(s uuid, rows jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r record; inserted int:=0; skipped int:=0; errors jsonb:='[]'; n int:=0;
begin
 if not private.has_role(s,'admin') then raise exception 'Akses ditolak' using errcode='42501'; end if;
 if rows is null or jsonb_typeof(rows)<>'array' or jsonb_array_length(rows)=0 then raise exception 'Data impor kosong' using errcode='22023'; end if;
 if jsonb_array_length(rows)>5000 then raise exception 'Maksimal 5000 baris per impor' using errcode='22023'; end if;
 perform 1 from public.schools where id=s for update;
 for r in select * from jsonb_to_recordset(rows) as x(nama text, email text) loop
  n:=n+1;
  if r.nama is null or length(btrim(r.nama)) not between 1 and 120 then errors:=errors||jsonb_build_object('baris',n,'pesan','Nama tidak valid');
  elsif r.email is null or length(r.email)>254 or r.email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then errors:=errors||jsonb_build_object('baris',n,'pesan','Email tidak valid');
  else
   insert into public.teachers(school_id,name,email) values(s,btrim(r.nama),lower(btrim(r.email))) on conflict do nothing;
   if found then inserted:=inserted+1; else skipped:=skipped+1; end if;
  end if;
 end loop;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail) values(s,auth.uid(),'import_teachers',s,jsonb_build_object('inserted',inserted,'skipped',skipped));
 return jsonb_build_object('inserted',inserted,'skipped',skipped,'errors',errors);
end $$;
revoke all on function public.import_teachers(uuid,jsonb) from public,anon;
grant execute on function public.import_teachers(uuid,jsonb) to authenticated;

create function public.import_subjects(s uuid, rows jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r record; inserted int:=0; skipped int:=0; errors jsonb:='[]'; n int:=0;
begin
 if not private.has_role(s,'admin') then raise exception 'Akses ditolak' using errcode='42501'; end if;
 if rows is null or jsonb_typeof(rows)<>'array' or jsonb_array_length(rows)=0 then raise exception 'Data impor kosong' using errcode='22023'; end if;
 if jsonb_array_length(rows)>5000 then raise exception 'Maksimal 5000 baris per impor' using errcode='22023'; end if;
 perform 1 from public.schools where id=s for update;
 for r in select * from jsonb_to_recordset(rows) as x(nama text) loop
  n:=n+1;
  if r.nama is null or length(btrim(r.nama)) not between 1 and 120 then errors:=errors||jsonb_build_object('baris',n,'pesan','Nama tidak valid');
  else
   insert into public.subjects(school_id,name) values(s,btrim(r.nama)) on conflict do nothing;
   if found then inserted:=inserted+1; else skipped:=skipped+1; end if;
  end if;
 end loop;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail) values(s,auth.uid(),'import_subjects',s,jsonb_build_object('inserted',inserted,'skipped',skipped));
 return jsonb_build_object('inserted',inserted,'skipped',skipped,'errors',errors);
end $$;
revoke all on function public.import_subjects(uuid,jsonb) from public,anon;
grant execute on function public.import_subjects(uuid,jsonb) to authenticated;

create function public.import_classes(s uuid, rows jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r record; inserted int:=0; skipped int:=0; errors jsonb:='[]'; n int:=0; term uuid;
begin
 if not private.has_role(s,'admin') then raise exception 'Akses ditolak' using errcode='42501'; end if;
 if rows is null or jsonb_typeof(rows)<>'array' or jsonb_array_length(rows)=0 then raise exception 'Data impor kosong' using errcode='22023'; end if;
 if jsonb_array_length(rows)>5000 then raise exception 'Maksimal 5000 baris per impor' using errcode='22023'; end if;
 perform 1 from public.schools where id=s for update;
 select id into term from public.terms where school_id=s and active;
 if term is null then raise exception 'Tetapkan semester aktif terlebih dahulu' using errcode='22023'; end if;
 for r in select * from jsonb_to_recordset(rows) as x(nama text, tingkat text) loop
  n:=n+1;
  if r.nama is null or length(btrim(r.nama)) not between 1 and 120 then errors:=errors||jsonb_build_object('baris',n,'pesan','Nama tidak valid');
  elsif r.tingkat is null or r.tingkat not in ('X','XI','XII') then errors:=errors||jsonb_build_object('baris',n,'pesan','Tingkat harus X, XI, atau XII');
  else
   insert into public.classes(school_id,term_id,name,grade) values(s,term,btrim(r.nama),r.tingkat) on conflict do nothing;
   if found then inserted:=inserted+1; else skipped:=skipped+1; end if;
  end if;
 end loop;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail) values(s,auth.uid(),'import_classes',s,jsonb_build_object('inserted',inserted,'skipped',skipped));
 return jsonb_build_object('inserted',inserted,'skipped',skipped,'errors',errors);
end $$;
revoke all on function public.import_classes(uuid,jsonb) from public,anon;
grant execute on function public.import_classes(uuid,jsonb) to authenticated;

create function public.import_students(s uuid, rows jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r record; inserted int:=0; skipped int:=0; errors jsonb:='[]'; n int:=0; term uuid; cid uuid; sid uuid;
begin
 if not private.has_role(s,'admin') then raise exception 'Akses ditolak' using errcode='42501'; end if;
 if rows is null or jsonb_typeof(rows)<>'array' or jsonb_array_length(rows)=0 then raise exception 'Data impor kosong' using errcode='22023'; end if;
 if jsonb_array_length(rows)>5000 then raise exception 'Maksimal 5000 baris per impor' using errcode='22023'; end if;
 perform 1 from public.schools where id=s for update;
 select id into term from public.terms where school_id=s and active;
 if term is null then raise exception 'Tetapkan semester aktif terlebih dahulu' using errcode='22023'; end if;
 for r in select * from jsonb_to_recordset(rows) as x(nama text, nis text, kelas text) loop
  n:=n+1;
  if r.nama is null or length(btrim(r.nama)) not between 1 and 120 then errors:=errors||jsonb_build_object('baris',n,'pesan','Nama tidak valid');
  elsif r.nis is null or length(btrim(r.nis)) not between 1 and 60 then errors:=errors||jsonb_build_object('baris',n,'pesan','NIS tidak valid');
  else
   select id into cid from public.classes where school_id=s and term_id=term and name=btrim(r.kelas);
   if cid is null then errors:=errors||jsonb_build_object('baris',n,'pesan','Kelas tidak ditemukan pada semester aktif');
   else
    insert into public.students(school_id,name,nis) values(s,btrim(r.nama),btrim(r.nis)) on conflict do nothing returning id into sid;
    if sid is not null then
     insert into public.enrollments(school_id,class_id,student_id) values(s,cid,sid) on conflict do nothing;
     inserted:=inserted+1;
    else skipped:=skipped+1; end if;
   end if;
  end if;
 end loop;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail) values(s,auth.uid(),'import_students',s,jsonb_build_object('inserted',inserted,'skipped',skipped));
 return jsonb_build_object('inserted',inserted,'skipped',skipped,'errors',errors);
end $$;
revoke all on function public.import_students(uuid,jsonb) from public,anon;
grant execute on function public.import_students(uuid,jsonb) to authenticated;

create function public.import_assignments(s uuid, rows jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r record; inserted int:=0; skipped int:=0; errors jsonb:='[]'; n int:=0; term uuid; tid uuid; cid uuid; mid uuid;
begin
 if not private.has_role(s,'admin') then raise exception 'Akses ditolak' using errcode='42501'; end if;
 if rows is null or jsonb_typeof(rows)<>'array' or jsonb_array_length(rows)=0 then raise exception 'Data impor kosong' using errcode='22023'; end if;
 if jsonb_array_length(rows)>5000 then raise exception 'Maksimal 5000 baris per impor' using errcode='22023'; end if;
 perform 1 from public.schools where id=s for update;
 select id into term from public.terms where school_id=s and active;
 if term is null then raise exception 'Tetapkan semester aktif terlebih dahulu' using errcode='22023'; end if;
 for r in select * from jsonb_to_recordset(rows) as x(guru text, kelas text, mapel text) loop
  n:=n+1;
  select id into tid from public.teachers where school_id=s and name=btrim(r.guru);
  select id into cid from public.classes where school_id=s and term_id=term and name=btrim(r.kelas);
  select id into mid from public.subjects where school_id=s and name=btrim(r.mapel);
  if tid is null or cid is null or mid is null then errors:=errors||jsonb_build_object('baris',n,'pesan','Guru, kelas, atau mata pelajaran tidak ditemukan');
  else
   insert into public.assignments(school_id,teacher_id,class_id,subject_id) values(s,tid,cid,mid) on conflict do nothing;
   if found then inserted:=inserted+1; else skipped:=skipped+1; end if;
  end if;
 end loop;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail) values(s,auth.uid(),'import_assignments',s,jsonb_build_object('inserted',inserted,'skipped',skipped));
 return jsonb_build_object('inserted',inserted,'skipped',skipped,'errors',errors);
end $$;
revoke all on function public.import_assignments(uuid,jsonb) from public,anon;
grant execute on function public.import_assignments(uuid,jsonb) to authenticated;
