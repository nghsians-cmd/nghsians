/* ============================================================================
   NGHSIANS — 60th SIGN DAY REGISTRATION FORM  (batch 2027)  ·  v1  ·  idempotent
   File: supabase-signday-form-27.sql

   WHAT THIS IS
     The database half of the "27 Form" (27form.html) + the committee rep
     panel (27rep.html). It stores every section of the form for each student
     who fills it out, and it connects the form to the existing Sign Day pass
     system on verified_profiles.

   PREREQUISITE (run first, once)
     supabase-schema.sql  (or supabase-signday-60.sql) — this file needs the
     verified_profiles table, its signday_* columns and the signday_guard
     trigger. Everything else here is new and creates itself.

   WHAT IT CREATES
     1. public.signday_registrations — ONE row per student (id = auth.users id,
        so it can never overlap or duplicate an account). Every form section
        is a column. RLS: a student can only read/submit/update their OWN row.
     2. public.signday_form_sync() — trigger: the moment a student submits the
        form, their verified_profiles row is marked signday_status 'submitted'
        (the student's "REGISTER" step happens automatically), their account
        email is stored in signday_email, and batch-2027 members are tagged
        role '27' (the Sign Day pass tag) if they are not tagged yet.
     3. PIN-protected admin functions (the PIN is 202725 — change it in all
        functions + 27rep.html if you ever rotate it):
          signday_roster(pass_pin)                                        → the whole roster
          activate_signday_pass(target_user_id, pass_pin, rep_name)       → pass goes ACTIVE (logged)
          deactivate_signday_pass(target_user_id, pass_pin, rep_name)     → back to pending (logged)
          signday_change_log(pass_pin)                                    → who changed what, newest first
     3b. signday_pass_log — ONE row per ACTIVE PASS / UNCONFIRMED click, with the
        rep's name typed on the 27rep.html PIN screen. Rows are never overwritten,
        so the history of a student keeps every rep who touched them.
        "ACTIVE PASS" on 27rep.html = verified_profiles.signday_status
        'issued' — the exact state account.html turns into the glowing
        "PASS ACTIVE" card. "UNCONFIRMED" = 'submitted' (registered, waiting).
     4. updated_at trigger + indexes.

   HOW THE PIECES CONNECT
     27form.html  → upsert into signday_registrations (own row only)
                  → trigger marks verified_profiles 'submitted' automatically
     27rep.html   → PIN gate → signday_roster() → spreadsheet view, live
                  → ACTIVE PASS button → activate_signday_pass() → 'issued'
                  → the student's account.html card becomes PASS ACTIVE by
                    itself (that rendering already exists in account.html)

   WHY EVERY STATEMENT IS ON ITS OWN LINE
     Supabase's "Potential issues detected" dialog rewrites the script line by
     line and can split a multi-line CREATE TABLE. Nothing here spans more
     than one line except the four function bodies, so there is nothing for a
     line-based rewrite to cut.

   HOW TO RUN
     1. Supabase Dashboard → SQL Editor → New query
     2. Paste this WHOLE file → "Run without RLS" (RLS + policies are here).
     3. Safe to re-run: no data is deleted. (v2 drops only the OLD 2-argument
        activate/deactivate functions, which the new 3-argument ones replace.)
   ============================================================================ */


/* ── 1. THE TABLE — one row per student, keyed by their auth user id ───────── */
create table if not exists public.signday_registrations (id uuid references auth.users not null primary key, email text, student_name text not null, tshirt_size text not null, shift text not null, section text not null, class_roll text not null, phone text not null, payment_method text not null, bkash_number text, deposit_to text, whatsapp_group text not null, batch_year text not null default '2027', submitted_at timestamp with time zone default timezone('utc'::text, now()) not null, updated_at timestamp with time zone default timezone('utc'::text, now()) not null);
alter table public.signday_registrations enable row level security;
comment on table public.signday_registrations is 'NGHS 60th Sign Day (batch 2027) registration form — one row per student, filled from 27form.html';
comment on column public.signday_registrations.id is 'auth.users id of the student — same key as verified_profiles, so the form can never overlap the account system';
comment on column public.signday_registrations.email is 'account email, copied from the session — shown read-only in the form';
comment on column public.signday_registrations.student_name is 'Student Name / transversal/শিক্ষার্থীর নাম';
comment on column public.signday_registrations.tshirt_size is 'S | M | L | XL | XXL';
comment on column public.signday_registrations.shift is 'Morning | Day (the original form said "Option 1" — fixed to Morning)';
comment on column public.signday_registrations.section is 'A | B | C | D';
comment on column public.signday_registrations.class_roll is 'Class Roll / Reaction/Schine রোল';
comment on column public.signday_registrations.phone is 'Participant Phone Number (whatsapp) / অংশগ্রহণকারীর ফোন নম্বর (হোয়াটসঅ্যাপ)';
comment on column public.signday_registrations.payment_method is 'online (bKash) | offline (cash) — the Offline/Online dropdown in the Email section';
comment on column public.signday_registrations.bkash_number is 'the bKash number the student paid from (online only, required)';
comment on column public.signday_registrations.deposit_to is 'who the student gave the cash deposit to (offline only, required)';
comment on column public.signday_registrations.whatsapp_group is 'Joined Already | Joined Right Now';
comment on column public.signday_registrations.batch_year is 'always 2027 — the form is locked to batch 2027';


/* ── 2. VALUE CHECKS — drop-then-add, so re-running is safe ────────────────── */
alter table public.signday_registrations drop constraint if exists signday_registrations_tshirt_check;
alter table public.signday_registrations add constraint signday_registrations_tshirt_check check (tshirt_size in ('S', 'M', 'L', 'XL', 'XXL'));
alter table public.signday_registrations drop constraint if exists signday_registrations_shift_check;
alter table public.signday_registrations add constraint signday_registrations_shift_check check (shift in ('Morning', 'Day'));
alter table public.signday_registrations drop constraint if exists signday_registrations_section_check;
alter table public.signday_registrations add constraint signday_registrations_section_check check (section in ('A', 'B', 'C', 'D'));
alter table public.signday_registrations drop constraint if exists signday_registrations_payment_check;
alter table public.signday_registrations add constraint signday_registrations_payment_check check (payment_method in ('online', 'offline'));
alter table public.signday_registrations drop constraint if exists signday_registrations_group_check;
alter table public.signday_registrations add constraint signday_registrations_group_check check (whatsapp_group in ('Joined Already', 'Joined Right Now'));
alter table public.signday_registrations drop constraint if exists signday_registrations_batch_check;
alter table public.signday_registrations add constraint signday_registrations_batch_check check (lower(trim(coalesce(batch_year, ''))) = '2027');
alter table public.signday_registrations drop constraint if exists signday_registrations_online_bkash_check;
alter table public.signday_registrations add constraint signday_registrations_online_bkash_check check (payment_method = 'offline' or nullif(btrim(coalesce(bkash_number, '')), '') is not null);
alter table public.signday_registrations drop constraint if exists signday_registrations_offline_deposit_check;
alter table public.signday_registrations add constraint signday_registrations_offline_deposit_check check (payment_method = 'online' or nullif(btrim(coalesce(deposit_to, '')), '') is not null);


/* ── 3. RLS — students touch only their own row; the rep panel uses the PIN
      functions in section 5 instead of reading the table directly ────────── */
drop policy if exists "Students can view own Sign Day form." on public.signday_registrations;
create policy "Students can view own Sign Day form." on public.signday_registrations for select using (auth.uid() = id);
drop policy if exists "Students can submit own Sign Day form." on public.signday_registrations;
create policy "Students can submit own Sign Day form." on public.signday_registrations for insert with check (auth.uid() = id);
drop policy if exists "Students can update own Sign Day form." on public.signday_registrations;
create policy "Students can update own Sign Day form." on public.signday_registrations for update using (auth.uid() = id) with check (auth.uid() = id);


/* ── 4. SYNC TRIGGER — form submitted ⇒ account marked 'submitted' + tagged ──
      Runs as the student (invoker): RLS lets them update their own
      verified_profiles row, and signday_guard allows the one transition a
      student is allowed to make: 'unconfirmed' → 'submitted'. An already
      'issued' pass is never downgraded. ─────────────────────────────────── */
create or replace function public.signday_form_sync() returns trigger language plpgsql as $fn$
begin
  update public.verified_profiles
     set signday_status = case when signday_status = 'unconfirmed' then 'submitted' else signday_status end,
         signday_email   = coalesce(nullif(btrim(coalesce(signday_email, '')), ''), new.email),
         role            = case when lower(trim(coalesce(batch_year, ''))) = '2027' and coalesce(nullif(btrim(role), ''), 'member') = 'member' then '27' else role end
   where id = new.id;
  return new;
end;
$fn$;
drop trigger if exists signday_form_sync on public.signday_registrations;
create trigger signday_form_sync after insert or update on public.signday_registrations for each row execute function public.signday_form_sync();


/* ── 5. PIN-PROTECTED ADMIN FUNCTIONS (used by 27rep.html) ───────────────────
      security definer + the PIN check. They run without a user session, so
      signday_guard treats them as the committee (auth.uid() is null) and the
      'issued' transition is allowed. The rep panel page creates its Supabase
      client with persistSession:false on purpose — a logged-in student must
      never be able to flip passes. ──────────────────────────────────────── */
create or replace function public.signday_roster(pass_pin text) returns table (id uuid, email text, student_name text, tshirt_size text, shift text, section text, class_roll text, phone text, payment_method text, bkash_number text, deposit_to text, whatsapp_group text, batch_year text, submitted_at timestamp with time zone, updated_at timestamp with time zone, profile_username text, profile_school_id text, profile_email text, profile_whatsapp text, signday_status text, signday_pass_code text, signday_email text) language plpgsql security definer set search_path = public as $fn$
begin
  if pass_pin is distinct from '202725' then
    raise exception 'Wrong PIN — the NGHS-27 rep panel is for the committee only.';
  end if;
  return query
    select r.id, r.email, r.student_name, r.tshirt_size, r.shift, r.section, r.class_roll, r.phone, r.payment_method, r.bkash_number, r.deposit_to, r.whatsapp_group, r.batch_year, r.submitted_at, r.updated_at, v.username, v.school_id, v.email, v.whatsapp_number, v.signday_status, v.signday_pass_code, v.signday_email
      from public.signday_registrations r
      left join public.verified_profiles v on v.id = r.id
     order by r.submitted_at desc;
end;
$fn$;
/* ── 5b. ACTION LOG — who pressed ACTIVE PASS / UNCONFIRMED, and when ─────────
      One row per click. rep_name is the name typed on the PIN screen of
      27rep.html. Nothing ever updates or deletes these rows, so a later
      change by another rep does not hide an earlier one. Only the PIN
      functions read it (RLS on, no policies, no grants to anon/authenticated). */
create table if not exists public.signday_pass_log (id bigint generated always as identity primary key, student_id uuid not null, student_name text, rep_name text not null, action text not null, status_before text, status_after text, created_at timestamp with time zone default timezone('utc'::text, now()) not null);
alter table public.signday_pass_log enable row level security;
comment on table public.signday_pass_log is 'Change log for the 27rep.html rep panel — one row per ACTIVE PASS / UNCONFIRMED click, with the rep name typed on the PIN screen';
comment on column public.signday_pass_log.rep_name is 'Name the rep typed on the 27rep.html PIN screen (the person who made this change)';
comment on column public.signday_pass_log.action is 'activated | unconfirmed';
create index if not exists signday_pass_log_student_idx on public.signday_pass_log (student_id, created_at desc);
create index if not exists signday_pass_log_created_idx on public.signday_pass_log (created_at desc);
revoke all on table public.signday_pass_log from anon, authenticated;

/* the v1 two-argument versions are replaced by the 3-argument versions below */
drop function if exists public.activate_signday_pass(uuid, text);
drop function if exists public.deactivate_signday_pass(uuid, text);

create or replace function public.activate_signday_pass(target_user_id uuid, pass_pin text, rep_name text default null) returns json language plpgsql security definer set search_path = public as $fn$
declare
  v_name   text := left(btrim(coalesce(rep_name, '')), 60);
  v_before text;
  v_after  text;
  v_student text;
begin
  if pass_pin is distinct from '202725' then
    raise exception 'Wrong PIN — the NGHS-27 rep panel is for the committee only.';
  end if;
  if v_name = '' then
    raise exception 'Type your name on the PIN screen first — it is saved in the change log.';
  end if;
  select signday_status into v_before from public.verified_profiles
   where id = target_user_id and role = '27' and lower(trim(coalesce(batch_year, ''))) = '2027';
  if not found then
    raise exception 'No batch-2027 Sign Day pass holder found for this student.';
  end if;
  update public.verified_profiles
     set signday_status = 'issued'
   where id = target_user_id;
  select signday_status into v_after from public.verified_profiles where id = target_user_id;
  select student_name into v_student from public.signday_registrations where id = target_user_id;
  insert into public.signday_pass_log (student_id, student_name, rep_name, action, status_before, status_after)
    values (target_user_id, v_student, v_name, 'activated', v_before, v_after);
  return json_build_object('ok', true, 'id', target_user_id, 'signday_status', v_after, 'rep_name', v_name);
end;
$fn$;

create or replace function public.deactivate_signday_pass(target_user_id uuid, pass_pin text, rep_name text default null) returns json language plpgsql security definer set search_path = public as $fn$
declare
  v_name   text := left(btrim(coalesce(rep_name, '')), 60);
  v_before text;
  v_after  text;
  v_student text;
begin
  if pass_pin is distinct from '202725' then
    raise exception 'Wrong PIN — the NGHS-27 rep panel is for the committee only.';
  end if;
  if v_name = '' then
    raise exception 'Type your name on the PIN screen first — it is saved in the change log.';
  end if;
  select signday_status into v_before from public.verified_profiles
   where id = target_user_id and role = '27' and lower(trim(coalesce(batch_year, ''))) = '2027';
  if not found then
    raise exception 'No batch-2027 Sign Day pass holder found for this student.';
  end if;
  update public.verified_profiles
     set signday_status = 'submitted'
   where id = target_user_id;
  select signday_status into v_after from public.verified_profiles where id = target_user_id;
  select student_name into v_student from public.signday_registrations where id = target_user_id;
  insert into public.signday_pass_log (student_id, student_name, rep_name, action, status_before, status_after)
    values (target_user_id, v_student, v_name, 'unconfirmed', v_before, v_after);
  return json_build_object('ok', true, 'id', target_user_id, 'signday_status', v_after, 'rep_name', v_name);
end;
$fn$;

create or replace function public.signday_change_log(pass_pin text) returns table (id bigint, student_id uuid, student_name text, rep_name text, action text, status_before text, status_after text, created_at timestamp with time zone) language plpgsql security definer set search_path = public as $fn$
begin
  if pass_pin is distinct from '202725' then
    raise exception 'Wrong PIN — the NGHS-27 rep panel is for the committee only.';
  end if;
  return query
    select l.id, l.student_id, l.student_name, l.rep_name, l.action, l.status_before, l.status_after, l.created_at
      from public.signday_pass_log l
     order by l.created_at desc, l.id desc
     limit 5000;
end;
$fn$;

revoke all on function public.activate_signday_pass(uuid, text, text) from public;
grant execute on function public.activate_signday_pass(uuid, text, text) to anon, authenticated;
revoke all on function public.deactivate_signday_pass(uuid, text, text) from public;
grant execute on function public.deactivate_signday_pass(uuid, text, text) to anon, authenticated;
revoke all on function public.signday_change_log(text) from public;
grant execute on function public.signday_change_log(text) to anon, authenticated;


/* ── 6. updated_at trigger + indexes ───────────────────────────────────────── */
create or replace function public.signday_touch_updated_at() returns trigger language plpgsql as $fn$
begin
  new.updated_at := timezone('utc'::text, now());
  return new;
end;
$fn$;
drop trigger if exists signday_registrations_touch on public.signday_registrations;
create trigger signday_registrations_touch before update on public.signday_registrations for each row execute function public.signday_touch_updated_at();
create index if not exists signday_registrations_shift_idx on public.signday_registrations (shift);
create index if not exists signday_registrations_section_idx on public.signday_registrations (section);
create index if not exists signday_registrations_payment_idx on public.signday_registrations (payment_method);
create index if not exists signday_registrations_submitted_idx on public.signday_registrations (submitted_at desc);


/* ── 7. ADMIN COMMANDS (run whichever you need in the SQL Editor) ────────────
   The roster, newest first (same data 27rep.html shows):
   select * from public.signday_roster('202725');

   Issue a pass by account email (the 27rep.html ACTIVE PASS button does this):
   select public.activate_signday_pass(id, '202725', 'Admin') from public.verified_profiles where lower(trim(coalesce(email, ''))) = 'student@example.com';

   Issue every pass that is waiting (all 'submitted'):
   select public.activate_signday_pass(id, '202725', 'Admin') from public.verified_profiles where role = '27' and signday_status = 'submitted';

   Take a pass back (registered but not approved — the UNCONFIRMED button):
   select public.deactivate_signday_pass(id, '202725', 'Admin') from public.verified_profiles where id = '<uuid>';

   Change log, newest first:
   select * from public.signday_change_log('202725');

   Counts:
   select count(*) as total, count(*) filter (where payment_method = 'online') as online, count(*) filter (where payment_method = 'offline') as offline, count(*) filter (where shift = 'Morning') as morning, count(*) filter (where shift = 'Day') as day from public.signday_registrations;

   Pass states across the roster:
   select coalesce(v.signday_status, 'none') as status, count(*) from public.signday_registrations r left join public.verified_profiles v on v.id = r.id group by 1 order by 1;

   Did it install?
   select t.tgname from pg_trigger t join pg_class c on c.oid = t.tgrelid where c.relname = 'signday_registrations' and t.tgname in ('signday_form_sync', 'signday_registrations_touch');
   select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('signday_roster', 'activate_signday_pass', 'deactivate_signday_pass', 'signday_change_log', 'signday_form_sync', 'signday_touch_updated_at') order by 1;
   ─────────────────────────────────────────────────────────────────────────── */


/* ── 8. ROLLBACK / REMOVE THIS WHOLE FEATURE ─────────────────────────────────
      Uncomment all of it and run once. It removes the form table, its
      triggers, the PIN functions and its indexes, and leaves
      verified_profiles (and the TEMP-SIGNDAY-60 pass feature) untouched.
      The signday_status values it set stay as they are — reset them by hand
      if you also want to withdraw the passes.

   drop trigger if exists signday_form_sync on public.signday_registrations;
   drop trigger if exists signday_registrations_touch on public.signday_registrations;
   drop function if exists public.signday_form_sync();
   drop function if exists public.signday_touch_updated_at();
   drop function if exists public.signday_roster(text);
   drop function if exists public.activate_signday_pass(uuid, text, text);
   drop function if exists public.deactivate_signday_pass(uuid, text, text);
   drop function if exists public.signday_change_log(text);
   drop index if exists public.signday_registrations_shift_idx;
   drop index if exists public.signday_registrations_section_idx;
   drop index if exists public.signday_registrations_payment_idx;
   drop index if exists public.signday_registrations_submitted_idx;
   drop table if exists public.signday_pass_log;
   drop table if exists public.signday_registrations;
   ─────────────────────────────────────────────────────────────────────────── */
