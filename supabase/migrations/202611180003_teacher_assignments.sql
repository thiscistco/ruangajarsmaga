create function public.add_teacher_assignment(s uuid, t uuid, c uuid, subject uuid) returns void
language plpgsql security definer set search_path='' as $$
declare new_id uuid;
begin
 if not private.has_role(s,'admin') then raise exception 'Akses ditolak' using errcode='42501'; end if;
 perform 1 from public.schools where id=s for update;
 if not exists(select 1 from public.classes x join public.terms y on (x.school_id,x.term_id)=(y.school_id,y.id) where x.school_id=s and x.id=c and y.active)
 or not exists(select 1 from public.teachers where school_id=s and id=t)
 or not exists(select 1 from public.subjects where school_id=s and id=subject) then raise exception 'Data penugasan tidak valid' using errcode='22023'; end if;
 insert into public.assignments(school_id,teacher_id,class_id,subject_id) values(s,t,c,subject) returning id into new_id;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail) values(s,auth.uid(),'teacher_assignment',new_id,jsonb_build_object('teacher_id',t,'class_id',c,'subject_id',subject));
end $$;
revoke all on function public.add_teacher_assignment(uuid,uuid,uuid,uuid) from public,anon;
grant execute on function public.add_teacher_assignment(uuid,uuid,uuid,uuid) to authenticated;
