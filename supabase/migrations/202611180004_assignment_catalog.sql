create function public.add_assignment_catalog(s uuid, kind text, label text, extra text) returns void language plpgsql security definer set search_path='' as $$
declare term uuid; row_id uuid;
begin
 if not private.has_role(s,'admin') then raise exception 'Akses ditolak' using errcode='42501'; end if;
 if label is null or length(btrim(label)) not between 1 and 120 then raise exception 'Nama tidak valid' using errcode='22023'; end if;
 case kind
 when 'guru' then
  if extra is null or length(extra)>254 or extra !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Email tidak valid' using errcode='22023'; end if;
  insert into public.teachers(school_id,name,email) values(s,btrim(label),lower(btrim(extra))) returning id into row_id;
 when 'mapel' then insert into public.subjects(school_id,name) values(s,btrim(label)) returning id into row_id;
 when 'kelas' then
  perform 1 from public.schools where id=s for update;
  select id into term from public.terms where school_id=s and active;
  if term is null or extra is null or extra not in ('X','XI','XII') then raise exception 'Semester atau tingkat tidak valid' using errcode='22023'; end if;
  insert into public.classes(school_id,term_id,name,grade) values(s,term,btrim(label),extra) returning id into row_id;
 else raise exception 'Jenis tidak valid' using errcode='22023'; end case;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail) values(s,auth.uid(),'assignment_catalog',row_id,jsonb_build_object('kind',kind));
end $$;
revoke all on function public.add_assignment_catalog(uuid,text,text,text) from public,anon;
grant execute on function public.add_assignment_catalog(uuid,text,text,text) to authenticated;
