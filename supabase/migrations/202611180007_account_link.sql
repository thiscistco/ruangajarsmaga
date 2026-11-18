-- Only the trusted server may link an Auth account. Never accept a role from user metadata.
create function public.link_school_account(s uuid, actor uuid, kind text, item uuid, account uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare previous uuid; account_role text;
begin
 if not exists(select 1 from memberships where school_id=s and user_id=actor and role='admin' and active) then
  raise exception 'Admin required' using errcode='42501';
 end if;
 if kind='guru' then
  account_role:='teacher';
  select user_id into previous from teachers where school_id=s and id=item for update;
 elsif kind='siswa' then
  account_role:='student';
  select user_id into previous from students where school_id=s and id=item for update;
 else
  raise exception 'Invalid kind' using errcode='22023';
 end if;
 if not found then raise exception 'Profile not found' using errcode='P0002'; end if;
 if previous is not null then raise exception 'Already linked' using errcode='23505'; end if;
 insert into memberships(school_id,user_id,role,active) values(s,account,account_role,true);
 if kind='guru' then
  update teachers set user_id=account where school_id=s and id=item;
 else
  update students set user_id=account where school_id=s and id=item;
 end if;
 insert into audit_log(school_id,actor_id,action,entity_id,detail)
 values(s,actor,'create_account',item,jsonb_build_object('kind',kind,'user_id',account));
end $$;
revoke all on function public.link_school_account(uuid,uuid,text,uuid,uuid) from public,anon,authenticated;
grant execute on function public.link_school_account(uuid,uuid,text,uuid,uuid) to service_role;
