create function public.save_school_settings(s uuid, school_name text, year_label text, semester_label text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not private.has_role(s,'admin') then raise exception 'Akses ditolak' using errcode='42501'; end if;
 if school_name is null or length(btrim(school_name)) not between 1 and 120 or year_label is null or year_label !~ '^[0-9]{4}/[0-9]{4}$' or semester_label is null or semester_label not in ('ganjil','genap') then raise exception 'Pengaturan tidak valid' using errcode='22023'; end if;
 if substring(year_label,1,4)::int < 1900 or substring(year_label,6,4)::int <> substring(year_label,1,4)::int + 1 then raise exception 'Tahun ajaran tidak valid' using errcode='22023'; end if;
 update public.schools set name=btrim(school_name) where id=s;
 update public.terms set active=false where school_id=s and active and (academic_year,semester)<>(year_label,semester_label);
 insert into public.terms(school_id,academic_year,semester,active) values(s,year_label,semester_label,true)
 on conflict(school_id,academic_year,semester) do update set active=true;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail) values(s,auth.uid(),'school_settings',s,jsonb_build_object('name',btrim(school_name),'year',year_label,'semester',semester_label));
end $$;
revoke all on function public.save_school_settings(uuid,text,text,text) from public,anon;
grant execute on function public.save_school_settings(uuid,text,text,text) to authenticated;
