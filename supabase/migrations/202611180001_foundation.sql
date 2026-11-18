create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.schools (id uuid primary key default gen_random_uuid(), name text not null);
create table public.memberships (
 school_id uuid references public.schools on delete cascade, user_id uuid references auth.users on delete cascade,
 role text check(role in ('admin','teacher','student')), active boolean not null default true,
 primary key(school_id,user_id,role)
);
create index memberships_user_idx on public.memberships(user_id);
create table public.terms (
 school_id uuid references public.schools on delete cascade, id uuid default gen_random_uuid(),
 academic_year text not null, semester text not null check(semester in ('ganjil','genap')), active boolean not null default false,
 primary key(school_id,id), unique(school_id,academic_year,semester)
);
create unique index terms_one_active on public.terms(school_id) where active;
create table public.classes (
 school_id uuid not null, id uuid default gen_random_uuid(), term_id uuid not null, name text not null,
 grade text not null check(grade in ('X','XI','XII')), primary key(school_id,id), unique(school_id,term_id,name),
 foreign key(school_id,term_id) references public.terms(school_id,id)
);
create table public.subjects (
 school_id uuid references public.schools on delete cascade, id uuid default gen_random_uuid(), name text not null,
 primary key(school_id,id), unique(school_id,name)
);
create table public.teachers (
 school_id uuid references public.schools on delete cascade, id uuid default gen_random_uuid(), user_id uuid,
 role text generated always as ('teacher'::text) stored, name text not null, email text not null,
 primary key(school_id,id), unique(school_id,user_id), foreign key(school_id,user_id,role) references public.memberships(school_id,user_id,role)
);
create unique index teachers_email_idx on public.teachers(school_id,lower(email));
create table public.students (
 school_id uuid references public.schools on delete cascade, id uuid default gen_random_uuid(), user_id uuid,
 role text generated always as ('student'::text) stored, name text not null, nis text not null,
 primary key(school_id,id), unique(school_id,nis), unique(school_id,user_id), foreign key(school_id,user_id,role) references public.memberships(school_id,user_id,role)
);
create table public.assignments (
 school_id uuid not null, id uuid default gen_random_uuid(), teacher_id uuid not null, class_id uuid not null, subject_id uuid not null,
 primary key(school_id,id), unique(school_id,teacher_id,class_id,subject_id),
 foreign key(school_id,teacher_id) references public.teachers(school_id,id), foreign key(school_id,class_id) references public.classes(school_id,id),
 foreign key(school_id,subject_id) references public.subjects(school_id,id)
);
create table public.enrollments (
 school_id uuid not null, class_id uuid not null, student_id uuid not null, primary key(school_id,class_id,student_id),
 foreign key(school_id,class_id) references public.classes(school_id,id), foreign key(school_id,student_id) references public.students(school_id,id)
);
create table public.materials (
 school_id uuid not null, id uuid default gen_random_uuid(), assignment_id uuid not null, title text not null, body text not null,
 published_at timestamptz, published_by uuid references auth.users, primary key(school_id,id),
 foreign key(school_id,assignment_id) references public.assignments(school_id,id)
);
create table public.attendance (
 school_id uuid not null, id uuid default gen_random_uuid(), assignment_id uuid not null, student_id uuid not null, class_id uuid not null, day date not null,
 status text not null check(status in ('Hadir','Izin','Sakit','Alpa')), primary key(school_id,id), unique(school_id,assignment_id,student_id,day),
 foreign key(school_id,assignment_id) references public.assignments(school_id,id), foreign key(school_id,class_id,student_id) references public.enrollments(school_id,class_id,student_id)
);
alter table public.assignments add unique(school_id,id,class_id);
alter table public.attendance add foreign key(school_id,assignment_id,class_id) references public.assignments(school_id,id,class_id);
create table public.journals (
 school_id uuid not null, id uuid default gen_random_uuid(), assignment_id uuid not null, title text not null, day date not null,
 primary key(school_id,id), foreign key(school_id,assignment_id) references public.assignments(school_id,id)
);
create table public.grades (
 school_id uuid not null, id uuid default gen_random_uuid(), assignment_id uuid not null, class_id uuid not null, student_id uuid not null,
 score numeric not null check(score between 0 and 100), published_at timestamptz,
 primary key(school_id,id), foreign key(school_id,assignment_id,class_id) references public.assignments(school_id,id,class_id),
 foreign key(school_id,class_id,student_id) references public.enrollments(school_id,class_id,student_id)
);
create table public.audit_log (
 school_id uuid references public.schools, id uuid default gen_random_uuid(), actor_id uuid not null references auth.users,
 action text not null, entity_id uuid not null, detail jsonb not null, created_at timestamptz not null default now(), primary key(school_id,id)
);

create function private.has_role(s uuid, r text) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.memberships where school_id=s and user_id=auth.uid() and role=r and active)
$$;
create function private.owns_assignment(s uuid, a uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select private.has_role(s,'teacher') and exists(select 1 from public.assignments x join public.teachers t on (t.school_id,t.id)=(x.school_id,x.teacher_id) where x.school_id=s and x.id=a and t.user_id=auth.uid())
$$;
create function private.owns_student(s uuid, p uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select private.has_role(s,'student') and exists(select 1 from public.students x where x.school_id=s and x.id=p and x.user_id=auth.uid())
$$;
create function private.enrolled_assignment(s uuid, a uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.assignments x join public.enrollments e using(school_id,class_id) where x.school_id=s and x.id=a and private.owns_student(s,e.student_id))
$$;
revoke all on all functions in schema private from public;
grant execute on all functions in schema private to authenticated;

alter table public.schools enable row level security;
revoke all on public.schools from anon,authenticated;
grant select on public.schools to authenticated;
create policy school_read on public.schools for select to authenticated using(private.has_role(id,'admin') or private.has_role(id,'teacher') or private.has_role(id,'student'));
do $$ declare t text; begin
 foreach t in array array['memberships','terms','classes','subjects','teachers','students','assignments','enrollments','materials','attendance','journals','grades','audit_log'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from anon, authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
  execute format('create policy admin_read on public.%I for select to authenticated using(private.has_role(school_id,''admin''))',t);
 end loop;
end $$;
create policy own_membership on public.memberships for select to authenticated using(user_id=auth.uid() and active);
create policy own_teacher on public.teachers for select to authenticated using(user_id=auth.uid() and private.has_role(school_id,'teacher'));
create policy own_student on public.students for select to authenticated using(private.owns_student(school_id,id));
create policy teacher_assignment on public.assignments for select to authenticated using(private.owns_assignment(school_id,id));
create policy own_enrollment on public.enrollments for select to authenticated using(private.owns_student(school_id,student_id));
create policy material_audience on public.materials for select to authenticated using(private.owns_assignment(school_id,assignment_id) or (published_at is not null and private.enrolled_assignment(school_id,assignment_id)));
create policy attendance_audience on public.attendance for select to authenticated using(private.owns_assignment(school_id,assignment_id) or private.owns_student(school_id,student_id));
create policy journal_teacher on public.journals for select to authenticated using(private.owns_assignment(school_id,assignment_id));
create policy grade_audience on public.grades for select to authenticated using(private.owns_assignment(school_id,assignment_id) or (published_at is not null and private.owns_student(school_id,student_id)));

create function public.publish_material(s uuid, m uuid) returns void language plpgsql security definer set search_path='' as $$
declare a uuid;
begin
 select assignment_id into a from public.materials where school_id=s and id=m for update;
 if a is null or not (private.has_role(s,'admin') or private.owns_assignment(s,a)) then raise exception 'Akses ditolak' using errcode='42501'; end if;
 update public.materials set published_at=now(),published_by=auth.uid() where school_id=s and id=m and published_at is null;
 if not found then raise exception 'Materi sudah diterbitkan'; end if;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail) values(s,auth.uid(),'publish_material',m,'{}');
end $$;
create function public.correct_attendance(s uuid, a uuid, new_status text, reason text) returns void language plpgsql security definer set search_path='' as $$
declare previous text;
begin
 if not private.has_role(s,'admin') then raise exception 'Akses ditolak' using errcode='42501'; end if;
 if new_status is null or new_status not in ('Hadir','Izin','Sakit','Alpa') or reason is null or length(trim(reason)) not between 1 and 500 then raise exception 'Status dan alasan wajib valid'; end if;
 select status into previous from public.attendance where school_id=s and id=a for update;
 if previous is null or previous=new_status then raise exception 'Pilih absensi dan status baru yang valid'; end if;
 update public.attendance set status=new_status where school_id=s and id=a;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail) values(s,auth.uid(),'correct_attendance',a,jsonb_build_object('before',previous,'after',new_status,'reason',trim(reason)));
end $$;
create function public.audit_teacher_preview(s uuid, t uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.has_role(s,'admin') or not exists(select 1 from public.teachers where school_id=s and id=t) then raise exception 'Akses ditolak' using errcode='42501'; end if;
 insert into public.audit_log(school_id,actor_id,action,entity_id,detail) values(s,auth.uid(),'teacher_preview',t,'{}');
end $$;
revoke all on function public.publish_material(uuid,uuid),public.correct_attendance(uuid,uuid,text,text),public.audit_teacher_preview(uuid,uuid) from public,anon;
grant execute on function public.publish_material(uuid,uuid),public.correct_attendance(uuid,uuid,text,text),public.audit_teacher_preview(uuid,uuid) to authenticated;
