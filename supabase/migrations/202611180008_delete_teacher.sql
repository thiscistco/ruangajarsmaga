-- Explicit, audited deletion. Auth identity and unrelated roles/history are preserved.
create function public.delete_teacher_permanently(s uuid, item uuid, confirmed_name text default null, expected jsonb default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare teacher_name text; account uuid; counts jsonb; assignment_ids uuid[];
begin
 if not private.has_role(s,'admin') then raise exception 'Admin required' using errcode='42501'; end if;
 select name,user_id into teacher_name,account from public.teachers where school_id=s and id=item for update;
 if not found then raise exception 'Teacher not found' using errcode='P0002'; end if;
 -- Lock assignments as well: concurrent child inserts must finish before counting/deleting.
 perform 1 from public.assignments where school_id=s and teacher_id=item order by id for update;
 select coalesce(array_agg(id),'{}'::uuid[]) into assignment_ids from public.assignments where school_id=s and teacher_id=item;
 counts:=jsonb_build_object(
 'penugasan',cardinality(assignment_ids),
 'absensi',(select count(*) from public.attendance where school_id=s and assignment_id=any(assignment_ids)),
 'nilai',(select count(*) from public.grades where school_id=s and assignment_id=any(assignment_ids)),
 'materi',(select count(*) from public.materials where school_id=s and assignment_id=any(assignment_ids)),
 'jurnal',(select count(*) from public.journals where school_id=s and assignment_id=any(assignment_ids)));
 if confirmed_name is null then return jsonb_build_object('nama',teacher_name,'counts',counts,'hasAccount',account is not null); end if;
 if confirmed_name is distinct from teacher_name or expected is distinct from counts then
  raise exception 'Confirmation changed' using errcode='22023';
 end if;
 delete from public.attendance where school_id=s and assignment_id=any(assignment_ids);
 delete from public.grades where school_id=s and assignment_id=any(assignment_ids);
 delete from public.materials where school_id=s and assignment_id=any(assignment_ids);
 delete from public.journals where school_id=s and assignment_id=any(assignment_ids);
 delete from public.assignments where school_id=s and teacher_id=item;
 delete from public.teachers where school_id=s and id=item;
 delete from public.memberships where school_id=s and user_id=account and role='teacher';
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail)
 values(s,auth.uid(),'teacher_permanent_delete',item,jsonb_build_object('counts',counts,'auth_identity_preserved',true));
 return jsonb_build_object('deleted',true);
end $$;
revoke all on function public.delete_teacher_permanently(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.delete_teacher_permanently(uuid,uuid,text,jsonb) to authenticated;
