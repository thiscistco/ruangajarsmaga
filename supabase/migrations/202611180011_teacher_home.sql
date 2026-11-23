-- Private teacher planner. No changes to existing attendance/journals/grades.
create table public.teacher_planner_entries (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools,
 owner_id uuid not null references auth.users, kind text not null check(kind in ('agenda','note')),
 day date not null, title text not null check(length(btrim(title)) between 1 and 160),
 body text not null default '' check(length(body)<=5000), start_time time, end_time time,
 revision integer not null default 1, check(end_time is null or (start_time is not null and end_time>start_time))
);
create table public.teacher_meetings (
 id uuid primary key default gen_random_uuid(), series_id uuid not null, school_id uuid not null references public.schools,
 owner_id uuid not null references auth.users, assignment_id uuid not null,
 day date not null, start_time time not null, end_time time not null check(end_time>start_time),
 room text not null default '' check(length(room)<=100), cancelled boolean not null default false,
 revision integer not null default 1
 -- Assignment intentionally retained as historical identity, without a deletion-blocking FK.
);
create table public.teacher_planner_history (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools,
 owner_id uuid not null references auth.users, entity_id uuid not null, action text not null,
 reason text not null, before_data jsonb, after_data jsonb, created_at timestamptz not null default now()
);
create index teacher_entries_owner_day on public.teacher_planner_entries(owner_id,school_id,day);
create index teacher_meetings_owner_day on public.teacher_meetings(owner_id,school_id,day);
create index teacher_history_owner on public.teacher_planner_history(owner_id,school_id,created_at);
create function private.teacher_planner_owner(s uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.has_role(s,'teacher') and exists(select 1 from public.teachers where school_id=s and user_id=auth.uid())
$$;
revoke all on function private.teacher_planner_owner(uuid) from public,anon;
grant execute on function private.teacher_planner_owner(uuid) to authenticated;
do $$ declare t text; begin
 foreach t in array array['teacher_planner_entries','teacher_meetings','teacher_planner_history'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
 execute format('create policy planner_owner on public.%I for select to authenticated using(owner_id=auth.uid() and private.teacher_planner_owner(school_id))',t);
 end loop;
end $$;
create function public.teacher_home(s uuid, first_day date) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.teacher_planner_owner(s) then raise exception 'Akses ditolak' using errcode='42501'; end if;
 if first_day is null then raise exception 'Tanggal wajib' using errcode='22023'; end if;
 select jsonb_build_object(
 'name',(select name from public.teachers where school_id=s and user_id=auth.uid()),
 'assignments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'class_id',c.id,'class_name',c.name,'subject_id',u.id,'subject_name',u.name,'term',t.academic_year||' · '||t.semester)) from public.assignments a join public.teachers p on (p.school_id,p.id)=(a.school_id,a.teacher_id) join public.classes c on (c.school_id,c.id)=(a.school_id,a.class_id) join public.terms t on (t.school_id,t.id)=(c.school_id,c.term_id) join public.subjects u on (u.school_id,u.id)=(a.school_id,a.subject_id) where a.school_id=s and p.user_id=auth.uid() and t.active),'[]'::jsonb),
 'meetings',coalesce((select jsonb_agg(to_jsonb(m)||jsonb_build_object('class_name',c.name,'subject_name',u.name,'active',coalesce(t.active,false)) order by m.day,m.start_time) from public.teacher_meetings m left join public.assignments a on (a.school_id,a.id)=(m.school_id,m.assignment_id) left join public.classes c on (c.school_id,c.id)=(a.school_id,a.class_id) left join public.terms t on (t.school_id,t.id)=(c.school_id,c.term_id) left join public.subjects u on (u.school_id,u.id)=(a.school_id,a.subject_id) where m.school_id=s and m.owner_id=auth.uid() and m.day between first_day-7 and (first_day+interval '1 month'+interval '7 days')::date),'[]'::jsonb),
 'entries',coalesce((select jsonb_agg(e order by e.day,e.start_time) from public.teacher_planner_entries e where school_id=s and owner_id=auth.uid() and day between first_day-7 and (first_day+interval '1 month'+interval '7 days')::date),'[]'::jsonb),
 'history',coalesce((select jsonb_agg(h) from (select entity_id,action,reason,created_at from public.teacher_planner_history where school_id=s and owner_id=auth.uid() order by created_at desc limit 30) h),'[]'::jsonb)
 ) into result;
 return result;
end $$;
create function public.save_teacher_planner(s uuid, operation text, payload jsonb) returns void language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); item uuid:=nullif(payload->>'id','')::uuid; old_entry public.teacher_planner_entries; old_meeting public.teacher_meetings; m public.teacher_meetings;
 d date; until_day date; shift_days int; aid uuid; sid uuid; start_t time; end_t time; why text:=btrim(coalesce(payload->>'reason','')); scope_name text:=coalesce(payload->>'scope','single');
 today date:=(now() at time zone 'Asia/Jakarta')::date;
begin
 if not private.teacher_planner_owner(s) then raise exception 'Akses ditolak' using errcode='42501'; end if;
 -- Serialize mutations for one teacher, including concurrent requests in different tabs.
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 if operation in ('entry_save','entry_delete') then
  if item is not null then
   select * into old_entry from public.teacher_planner_entries where id=item and school_id=s and owner_id=uid for update;
   if not found then raise exception 'Data tidak ditemukan' using errcode='42501'; end if;
   if (payload->>'revision')::int is distinct from old_entry.revision then raise exception 'Data berubah, muat ulang' using errcode='40001'; end if;
  end if;
  if operation='entry_delete' then
   if item is null then raise exception 'ID wajib' using errcode='22023'; end if;
   delete from public.teacher_planner_entries where id=item;
  else
   if payload->>'kind' not in ('agenda','note') or payload->>'title' is null or length(btrim(payload->>'title')) not between 1 and 160 or length(coalesce(payload->>'body',''))>5000 then raise exception 'Isian tidak valid' using errcode='22023'; end if;
   d:=(payload->>'day')::date;
   start_t:=case when payload->>'kind'='agenda' then nullif(payload->>'start_time','')::time end;
   end_t:=case when payload->>'kind'='agenda' then nullif(payload->>'end_time','')::time end;
   if d is null or (end_t is not null and (start_t is null or end_t<=start_t)) then raise exception 'Tanggal/jam tidak valid' using errcode='22023'; end if;
   if item is null then
    insert into public.teacher_planner_entries(school_id,owner_id,kind,day,title,body,start_time,end_time) values(s,uid,payload->>'kind',d,btrim(payload->>'title'),coalesce(payload->>'body',''),start_t,end_t) returning id into item;
   else
    update public.teacher_planner_entries set kind=payload->>'kind',day=d,title=btrim(payload->>'title'),body=coalesce(payload->>'body',''),start_time=start_t,end_time=end_t,revision=revision+1 where id=item;
   end if;
  end if;
  -- Private contents never copied to the admin audit log.
  insert into public.teacher_planner_history(school_id,owner_id,entity_id,action,reason) values(s,uid,item,operation,'Agenda/catatan pribadi');
  return;
 end if;
 if operation not in ('meeting_create','meeting_edit','meeting_cancel') or scope_name not in ('single','future') then raise exception 'Operasi tidak valid' using errcode='22023'; end if;
 if operation<>'meeting_create' then
  select * into old_meeting from public.teacher_meetings where id=item and school_id=s and owner_id=uid for update;
  if not found then raise exception 'Jadwal tidak ditemukan' using errcode='42501'; end if;
  if old_meeting.cancelled or old_meeting.day<today then raise exception 'Riwayat tidak dapat diubah' using errcode='22023'; end if;
  if (payload->>'revision')::int is distinct from old_meeting.revision then raise exception 'Jadwal berubah, muat ulang' using errcode='40001'; end if;
  aid:=old_meeting.assignment_id;
  if length(why) not between 1 and 300 then raise exception 'Alasan perubahan wajib' using errcode='22023'; end if;
 else aid:=(payload->>'assignment_id')::uuid;
 end if;
 if not exists(select 1 from public.assignments a join public.teachers p on (p.school_id,p.id)=(a.school_id,a.teacher_id) join public.classes c on (c.school_id,c.id)=(a.school_id,a.class_id) join public.terms t on (t.school_id,t.id)=(c.school_id,c.term_id) where a.school_id=s and a.id=aid and p.user_id=uid and t.active) then raise exception 'Penugasan semester aktif tidak ditemukan' using errcode='42501'; end if;
 if operation<>'meeting_cancel' then
  d:=(payload->>'day')::date; start_t:=(payload->>'start_time')::time; end_t:=(payload->>'end_time')::time;
  if d is null or d<today or d>today+366 or start_t is null or end_t is null or end_t<=start_t or length(coalesce(payload->>'room',''))>100 then raise exception 'Tanggal/jam tidak valid' using errcode='22023'; end if;
 end if;
 if operation='meeting_create' then
  until_day:=coalesce(nullif(payload->>'until_day','')::date,d);
  if until_day<d or until_day>d+183 then raise exception 'Rentang jadwal maksimal 184 hari' using errcode='22023'; end if;
  sid:=gen_random_uuid();
  insert into public.teacher_meetings(series_id,school_id,owner_id,assignment_id,day,start_time,end_time,room)
   select sid,s,uid,aid,d+i*7,start_t,end_t,coalesce(payload->>'room','') from generate_series(0,(until_day-d)/7) i;
  insert into public.teacher_planner_history(school_id,owner_id,entity_id,action,reason,after_data) values(s,uid,sid,operation,'Jadwal baru',jsonb_build_object('day',d,'until_day',until_day,'assignment_id',aid));
 else
  shift_days:=case when operation='meeting_edit' then d-old_meeting.day else 0 end;
  if abs(shift_days)>6 then raise exception 'Pergeseran maksimal 6 hari' using errcode='22023'; end if;
  for m in select * from public.teacher_meetings where school_id=s and owner_id=uid and not cancelled and (id=item or (scope_name='future' and series_id=old_meeting.series_id and day>=old_meeting.day)) order by day for update loop
   if m.day+shift_days<today then raise exception 'Tidak dapat memindahkan ke masa lalu' using errcode='22023'; end if;
   insert into public.teacher_planner_history(school_id,owner_id,entity_id,action,reason,before_data,after_data) values(s,uid,m.id,operation,why,to_jsonb(m),jsonb_build_object('day',m.day+shift_days,'start_time',start_t,'end_time',end_t,'cancelled',operation='meeting_cancel'));
   update public.teacher_meetings set day=m.day+shift_days,start_time=coalesce(start_t,m.start_time),end_time=coalesce(end_t,m.end_time),room=case when operation='meeting_edit' then coalesce(payload->>'room','') else m.room end,cancelled=operation='meeting_cancel',revision=revision+1 where id=m.id;
  end loop;
 end if;
 if exists(select 1 from public.teacher_meetings a join public.teacher_meetings b on a.owner_id=b.owner_id and a.day=b.day and a.id<b.id and a.start_time<b.end_time and b.start_time<a.end_time where a.owner_id=uid and not a.cancelled and not b.cancelled and a.day>=today) then raise exception 'Jadwal bertumpuk' using errcode='23P01'; end if;
end $$;
revoke all on function public.teacher_home(uuid,date),public.save_teacher_planner(uuid,text,jsonb) from public,anon;
grant execute on function public.teacher_home(uuid,date),public.save_teacher_planner(uuid,text,jsonb) to authenticated;
