-- Global course overrides used by the teacher dashboard.
create table if not exists public.course_changes (
  course_id text primary key,
  name text,
  description text,
  deleted boolean not null default false,
  updated_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_at timestamptz not null default now(),
  constraint course_changes_id_check check (length(trim(course_id)) between 1 and 100),
  constraint course_changes_name_check check (name is null or length(trim(name)) between 1 and 80),
  constraint course_changes_description_check check (description is null or length(description) <= 250)
);

alter table public.course_changes enable row level security;

drop policy if exists "course_changes_select_authenticated" on public.course_changes;
drop policy if exists "course_changes_insert_teacher" on public.course_changes;
drop policy if exists "course_changes_update_teacher" on public.course_changes;
drop policy if exists "course_changes_delete_teacher" on public.course_changes;

create policy "course_changes_select_authenticated"
on public.course_changes for select to authenticated
using (true);

create policy "course_changes_insert_teacher"
on public.course_changes for insert to authenticated
with check (public.is_teacher() and updated_by = auth.uid());

create policy "course_changes_update_teacher"
on public.course_changes for update to authenticated
using (public.is_teacher())
with check (public.is_teacher() and updated_by = auth.uid());

create policy "course_changes_delete_teacher"
on public.course_changes for delete to authenticated
using (public.is_teacher());

drop trigger if exists course_changes_set_updated_at on public.course_changes;
create trigger course_changes_set_updated_at
before update on public.course_changes
for each row execute function public.set_updated_at();

revoke all on public.course_changes from anon;
revoke all on public.course_changes from authenticated;
grant select, insert, update, delete on public.course_changes to authenticated;
