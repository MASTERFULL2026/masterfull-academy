create table if not exists public.academy_courses (
  course_id text primary key,
  name text not null,
  description text not null default '',
  teacher_name text not null default 'Profesor',
  published boolean not null default false,
  updated_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.academy_exams (
  exam_id text primary key,
  course_id text not null references public.academy_courses(course_id) on delete cascade,
  title text not null,
  minutes integer not null check (minutes between 1 and 300),
  questions_to_show integer not null check (questions_to_show > 0),
  attempts_allowed integer not null check (attempts_allowed between 1 and 20),
  option_count integer not null check (option_count between 2 and 8),
  published boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.academy_questions (
  exam_id text not null references public.academy_exams(exam_id) on delete cascade,
  question_id text not null,
  position integer not null check (position >= 0),
  text text not null,
  image text not null default '',
  options jsonb not null check (jsonb_typeof(options) = 'array'),
  correct integer not null check (correct >= 0),
  published boolean not null default true,
  primary key (exam_id, question_id)
);

alter table public.academy_courses enable row level security;
alter table public.academy_exams enable row level security;
alter table public.academy_questions enable row level security;

drop policy if exists "academy_courses_read_published" on public.academy_courses;
create policy "academy_courses_read_published" on public.academy_courses
for select to authenticated using (published = true or public.is_teacher());

drop policy if exists "academy_courses_teacher_write" on public.academy_courses;
create policy "academy_courses_teacher_write" on public.academy_courses
for all to authenticated using (public.is_teacher())
with check (public.is_teacher() and updated_by = auth.uid());

drop policy if exists "academy_exams_read_published" on public.academy_exams;
create policy "academy_exams_read_published" on public.academy_exams
for select to authenticated using (
  published = true and exists (
    select 1 from public.academy_courses c
    where c.course_id = academy_exams.course_id and c.published = true
  )
  or public.is_teacher()
);

drop policy if exists "academy_exams_teacher_write" on public.academy_exams;
create policy "academy_exams_teacher_write" on public.academy_exams
for all to authenticated using (public.is_teacher()) with check (public.is_teacher());

drop policy if exists "academy_questions_read_published" on public.academy_questions;
create policy "academy_questions_read_published" on public.academy_questions
for select to authenticated using (
  published = true and exists (
    select 1 from public.academy_exams e
    join public.academy_courses c on c.course_id = e.course_id
    where e.exam_id = academy_questions.exam_id and e.published = true and c.published = true
  )
  or public.is_teacher()
);

drop policy if exists "academy_questions_teacher_write" on public.academy_questions;
create policy "academy_questions_teacher_write" on public.academy_questions
for all to authenticated using (public.is_teacher()) with check (public.is_teacher());

create or replace function public.publish_academy_course(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  course_data jsonb := payload -> 'course';
  exam_data jsonb;
  question_data jsonb;
  stable_course_id text := trim(course_data ->> 'id');
  stable_exam_id text;
  published_exam_count integer := 0;
  published_question_count integer := 0;
  question_position integer;
begin
  if auth.uid() is null or not public.is_teacher() then
    raise exception 'Solo un profesor puede publicar cursos.' using errcode = '42501';
  end if;
  if stable_course_id is null or stable_course_id = '' then
    raise exception 'El curso no tiene un ID estable.';
  end if;
  if jsonb_typeof(payload -> 'exams') <> 'array' or jsonb_array_length(payload -> 'exams') = 0 then
    raise exception 'Debes publicar al menos un examen antes de publicar el curso.';
  end if;

  insert into public.academy_courses(course_id, name, description, teacher_name, published, updated_by)
  values (
    stable_course_id,
    trim(course_data ->> 'name'),
    coalesce(course_data ->> 'description', ''),
    coalesce(nullif(trim(course_data ->> 'teacher_name'), ''), 'Profesor'),
    false,
    auth.uid()
  )
  on conflict (course_id) do update set
    name = excluded.name,
    description = excluded.description,
    teacher_name = excluded.teacher_name,
    published = false,
    updated_by = auth.uid(),
    updated_at = now();

  for exam_data in select value from jsonb_array_elements(payload -> 'exams')
  loop
    stable_exam_id := trim(exam_data ->> 'id');
    if stable_exam_id is null or stable_exam_id = '' then raise exception 'Un examen no tiene ID estable.'; end if;
    if jsonb_typeof(exam_data -> 'questions') <> 'array' or jsonb_array_length(exam_data -> 'questions') = 0 then
      raise exception 'El examen % no contiene preguntas.', stable_exam_id;
    end if;

    insert into public.academy_exams(exam_id, course_id, title, minutes, questions_to_show, attempts_allowed, option_count, published)
    values (
      stable_exam_id, stable_course_id, trim(exam_data ->> 'title'),
      (exam_data ->> 'minutes')::integer, (exam_data ->> 'questions_to_show')::integer,
      (exam_data ->> 'attempts_allowed')::integer, (exam_data ->> 'option_count')::integer, false
    )
    on conflict (exam_id) do update set
      course_id = excluded.course_id, title = excluded.title, minutes = excluded.minutes,
      questions_to_show = excluded.questions_to_show, attempts_allowed = excluded.attempts_allowed,
      option_count = excluded.option_count, published = false, updated_at = now();

    update public.academy_questions set published = false where exam_id = stable_exam_id;
    question_position := 0;
    for question_data in select value from jsonb_array_elements(exam_data -> 'questions')
    loop
      insert into public.academy_questions(exam_id, question_id, position, text, image, options, correct, published)
      values (
        stable_exam_id, trim(question_data ->> 'id'), question_position,
        question_data ->> 'text', coalesce(question_data ->> 'image', ''),
        question_data -> 'options', (question_data ->> 'correct')::integer, true
      )
      on conflict (exam_id, question_id) do update set position = excluded.position,
        text = excluded.text, image = excluded.image, options = excluded.options,
        correct = excluded.correct, published = true;
      question_position := question_position + 1;
      published_question_count := published_question_count + 1;
    end loop;

    update public.academy_exams set published = true, updated_at = now() where exam_id = stable_exam_id;
    published_exam_count := published_exam_count + 1;
  end loop;

  update public.academy_courses set published = true, updated_at = now() where course_id = stable_course_id;

  insert into public.course_changes(course_id, name, description, deleted, updated_by)
  values (stable_course_id, course_data ->> 'name', coalesce(course_data ->> 'description', ''), false, auth.uid())
  on conflict (course_id) do update set deleted = false, name = excluded.name,
    description = excluded.description, updated_by = auth.uid(), updated_at = now();

  return jsonb_build_object('course_id', stable_course_id, 'exam_count', published_exam_count, 'question_count', published_question_count);
end;
$$;

revoke all on function public.publish_academy_course(jsonb) from public, anon;
grant execute on function public.publish_academy_course(jsonb) to authenticated;

revoke all on public.academy_courses, public.academy_exams, public.academy_questions from anon, authenticated;
grant select, insert, update, delete on public.academy_courses, public.academy_exams, public.academy_questions to authenticated;

-- Recupera cualquier publicación creada por el flujo anterior, si la tabla existe.
do $$
declare
  legacy record;
  legacy_exam jsonb;
  legacy_question jsonb;
  pos integer;
begin
  if to_regclass('public.published_courses') is null then return; end if;
  for legacy in execute 'select * from public.published_courses where published = true'
  loop
    insert into public.academy_courses(course_id, name, description, teacher_name, published, updated_by)
    values (legacy.course_id, legacy.name, coalesce(legacy.description, ''), coalesce(legacy.teacher_name, 'Profesor'), true, legacy.updated_by)
    on conflict (course_id) do update set name = excluded.name, description = excluded.description,
      teacher_name = excluded.teacher_name, published = true, updated_at = now();

    for legacy_exam in select value from jsonb_array_elements(coalesce(legacy.exams, '[]'::jsonb))
    loop
      insert into public.academy_exams(exam_id, course_id, title, minutes, questions_to_show, attempts_allowed, option_count, published)
      values (legacy_exam ->> 'id', legacy.course_id, legacy_exam ->> 'title', (legacy_exam ->> 'minutes')::integer,
        (legacy_exam ->> 'questions_to_show')::integer, (legacy_exam ->> 'attempts_allowed')::integer,
        (legacy_exam ->> 'option_count')::integer, true)
      on conflict (exam_id) do update set course_id = excluded.course_id, title = excluded.title, published = true, updated_at = now();
      pos := 0;
      for legacy_question in select value from jsonb_array_elements(coalesce(legacy_exam -> 'questions', '[]'::jsonb))
      loop
        insert into public.academy_questions(exam_id, question_id, position, text, image, options, correct, published)
        values (legacy_exam ->> 'id', legacy_question ->> 'id', pos, legacy_question ->> 'text',
          coalesce(legacy_question ->> 'image', ''), legacy_question -> 'options', (legacy_question ->> 'correct')::integer, true)
        on conflict (exam_id, question_id) do update set position = excluded.position, text = excluded.text,
          image = excluded.image, options = excluded.options, correct = excluded.correct, published = true;
        pos := pos + 1;
      end loop;
    end loop;
    update public.course_changes set deleted = false, updated_at = now() where course_id = legacy.course_id;
  end loop;
end;
$$;
