-- ============================================================================
--  NGHSIANS — SUPABASE SCHEMA  (idempotent / safe to re-run)
--  Updated: 2026-10-03
--
--  WHAT'S NEW IN THIS VERSION
--    • No DO blocks (dollar-quoted "if not exists" wrappers) anywhere. Every
--      "only add it if it is missing" job is done with plain idempotent DDL —
--      add column if not exists, drop policy / trigger / constraint if exists —
--      so a paste that gets cut up mid-block can never leave a bare
--      "if ... then" for Postgres to choke on. The only multi-line bodies left
--      are the two functions (sections 8 and 11). If your editor ever
--      complains again, run one numbered section at a time.
--    • ⏳ TEMP SIGNDAY-60 (sections 10-14) — the NGHS 60th Sign Day pass for
--      batch 2027: role value '27', five signday_* columns, a trigger that
--      auto-issues the tag to 2027 registrants and refuses it for any other
--      batch, admin commands, and a one-pass rollback. Marked TEMPORARY start
--      to finish; sections 10-14 are also the only part you need if the rest
--      of this file has already been run.
--    • verified_profiles.whatsapp_number / instagram_username — the required
--      WhatsApp + Instagram fields on account.html (signup, profile gate, Edit).
--
--  HOW TO RUN
--    1. Supabase Dashboard -> SQL Editor -> New query
--    2. Paste this WHOLE file, press RUN.
--    3. Safe on a live site: nothing is dropped and no data is deleted.
--
--  IMPORTANT
--    Run this BEFORE (or together with) the updated account.html, otherwise the
--    new fields and the Sign Day pass cannot be saved.
-- ============================================================================


-- ============================================================================
-- 0. QUICK MIGRATION — the only part you need if the old script already ran
-- ============================================================================
alter table if exists public.verified_profiles add column if not exists whatsapp_number    text;
alter table if exists public.verified_profiles add column if not exists instagram_username text;
-- (their comments live in section 3, because COMMENT has no "if exists" form)


-- ============================================================================
-- 1. Safe Setup for 'verified_profiles' Table
-- Checks if table exists, if not creates it.
-- ============================================================================
create table if not exists verified_profiles (
  id uuid references auth.users not null primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Enable Row Level Security (Security Best Practice)
alter table verified_profiles enable row level security;

-- 3. Safe Column Addition (each one is skipped automatically when it exists)
alter table verified_profiles add column if not exists full_name text;
alter table verified_profiles add column if not exists username text;
alter table verified_profiles add column if not exists email text;

alter table verified_profiles add column if not exists school_id text;
alter table verified_profiles add column if not exists batch_year text;

alter table verified_profiles add column if not exists whatsapp_number    text;
alter table verified_profiles add column if not exists instagram_username text;

alter table verified_profiles add column if not exists role text default 'member';
alter table verified_profiles add column if not exists notified_of_verification boolean default false;

alter table verified_profiles add column if not exists follower_count int default 0;

comment on column verified_profiles.role      is 'member | elite | alumni | architect | 27 (27 = TEMP-SIGNDAY-60 pass, batch 2027 only)';
comment on column verified_profiles.whatsapp_number    is 'WhatsApp number in international form, e.g. +8801700000000';
comment on column verified_profiles.instagram_username is 'Instagram username without the @, e.g. nghsians';


-- ============================================================================
-- 4. Data Migration — old 'is_verified' column (deprecated, kept for safety)
--    One-time cleanup. Only needed if that column still exists in your
--    database; if it does not, leave these two lines commented out.
-- ============================================================================
-- update verified_profiles set role = 'elite' where is_verified = true;
-- alter table verified_profiles drop column if exists is_verified;


-- ============================================================================
-- 5. Policies for 'verified_profiles'
-- (Drop old ones first to avoid conflicts)
-- ============================================================================
drop policy if exists "Public profiles are viewable by everyone." on verified_profiles;
create policy "Public profiles are viewable by everyone."
  on verified_profiles for select
  using ( true );

drop policy if exists "Users can update own profile." on verified_profiles;
create policy "Users can update own profile."
  on verified_profiles for update
  using ( auth.uid() = id );

drop policy if exists "Users can insert own profile." on verified_profiles;
create policy "Users can insert own profile."
  on verified_profiles for insert
  with check ( auth.uid() = id );


-- ============================================================================
-- 6. Setup for 'user_relationships' (Follow/Unfollow System)
-- ============================================================================
create table if not exists user_relationships (
  id uuid default gen_random_uuid() primary key,
  follower_id uuid references auth.users not null,
  following_id uuid references auth.users not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(follower_id, following_id)
);

alter table user_relationships enable row level security;

-- 7. Policies for 'user_relationships'
drop policy if exists "Anyone can view relationships" on user_relationships;
create policy "Anyone can view relationships" on user_relationships for select using (true);

drop policy if exists "Users can follow others" on user_relationships;
create policy "Users can follow others" on user_relationships for insert with check (auth.uid() = follower_id);

drop policy if exists "Users can unfollow" on user_relationships;
create policy "Users can unfollow" on user_relationships for delete using (auth.uid() = follower_id);


-- ============================================================================
-- 8. Database Trigger for Auto-Updating Follower Counts
-- This function runs automatically whenever someone follows/unfollows
-- ============================================================================
create or replace function update_follower_count()
returns trigger
language plpgsql
security definer
as $fc$
begin
  if (TG_OP = 'INSERT') then
    update verified_profiles
    set follower_count = coalesce(follower_count, 0) + 1
    where id = new.following_id;
    return new;
  elsif (TG_OP = 'DELETE') then
    update verified_profiles
    set follower_count = greatest(coalesce(follower_count, 0) - 1, 0)
    where id = old.following_id;
    return old;
  end if;
  return null;
end;
$fc$;

-- Drop trigger if exists to avoid duplication errors
drop trigger if exists on_follow_change on user_relationships;

create trigger on_follow_change
after insert or delete on user_relationships
for each row execute function update_follower_count();


-- ============================================================================
-- 9. VERIFY (optional) — run after section 3
-- ============================================================================
-- select column_name, data_type
-- from information_schema.columns
-- where table_name = 'verified_profiles'
--   and column_name in ('whatsapp_number', 'instagram_username', 'role', 'follower_count')
-- order by column_name;


-- ############################################################################
-- ##                                                                          ##
-- ##   ⏳  TEMPORARY SECTION  ·  "NGHS 60th SIGN DAY" PASS  (BATCH 2027)        ##
-- ##   ⏳  MARKER:  TEMP-SIGNDAY-60  ·  START                                    ##
-- ##                                                                          ##
-- ##   Everything between the START and END markers is a one-off feature for  ##
-- ##   the 60th Sign Day. Safe to re-run, deletes nothing, and section 14     ##
-- ##   undoes all of it in one pass.                                          ##
-- ##                                                                          ##
-- ##   WHAT IT DOES                                                           ##
-- ##     • Adds 5 signday_* columns on verified_profiles:                     ##
-- ##         signday_status       'unconfirmed' | 'submitted' | 'issued'     ##
-- ##         signday_email        the account email the student handed over   ##
-- ##         signday_pass_code    ticket serial, e.g. SD60-27-4F2A-91BC       ##
-- ##         signday_submitted_at when they pressed REGISTER on their card     ##
-- ##         signday_notified     one-time "your pass is live" celebration    ##
-- ##     • Adds the role value  '27'  — the only thing you type by hand.      ##
-- ##       It is only valid for batch_year = '2027': the trigger rejects it   ##
-- ##       for every other batch, and quietly withdraws it if a student edits ##
-- ##       their own batch away from 2027.                                    ##
-- ##     • AUTO-TAGS every new 2027 registration, backfills the 2027 students  ##
-- ##       already in the table, and writes the ticket serial itself.         ##
-- ##                                                                          ##
-- ##   HOW IT PLAYS OUT                                                        ##
-- ##     1. A 2027 student registers        → role '27' + status               ##
-- ##        'unconfirmed' land on their own → they see the blue UNCONFIRMED   ##
-- ##        tag and the "Register For NGHS 60th Sign Day" notice.             ##
-- ##     2. They press REGISTER on the card → signday_status 'submitted' and  ##
-- ##        signday_email holds the address they gave.                       ##
-- ##     3. You issue their pass            → type 'issued' in                ##
-- ##        signday_status; the card becomes a live pass and they get a       ##
-- ##        one-time celebration on their next sign-in.                      ##
-- ############################################################################


-- ============================================================================
-- 10. TEMP-SIGNDAY-60 — columns
-- ============================================================================
alter table public.verified_profiles add column if not exists signday_status text not null default 'unconfirmed';
alter table public.verified_profiles add column if not exists signday_email text;
alter table public.verified_profiles add column if not exists signday_pass_code text;
alter table public.verified_profiles add column if not exists signday_submitted_at timestamp with time zone;
alter table public.verified_profiles add column if not exists signday_notified boolean not null default false;

comment on column public.verified_profiles.signday_status       is 'TEMP-SIGNDAY-60: unconfirmed | submitted | issued for the batch-2027 Sign Day pass';
comment on column public.verified_profiles.signday_email        is 'TEMP-SIGNDAY-60: account email the student handed to the Sign Day committee';
comment on column public.verified_profiles.signday_pass_code    is 'TEMP-SIGNDAY-60: ticket serial printed on the pass card';
comment on column public.verified_profiles.signday_submitted_at is 'TEMP-SIGNDAY-60: when the student registered for the pass';
comment on column public.verified_profiles.signday_notified     is 'TEMP-SIGNDAY-60: pass-issued celebration already shown';

-- Only the three known states, so a typo in the Table editor gets caught.
alter table public.verified_profiles drop constraint if exists verified_profiles_signday_status_check;
alter table public.verified_profiles
  add constraint verified_profiles_signday_status_check
  check (signday_status in ('unconfirmed', 'submitted', 'issued'));


-- ============================================================================
-- 11. TEMP-SIGNDAY-60 — guard / auto-issue trigger
-- ============================================================================
create or replace function public.signday_guard()
returns trigger
language plpgsql
as $sd$
declare
  v_batch     text := lower(trim(coalesce(new.batch_year, '')));
  v_role      text := lower(trim(coalesce(new.role, '')));
  v_oldrole   text := case when TG_OP = 'UPDATE'
                            then lower(trim(coalesce(old.role, ''))) else '' end;
  v_oldstatus text := case when TG_OP = 'UPDATE'
                            then coalesce(old.signday_status, 'unconfirmed') else 'unconfirmed' end;
  v_retired   boolean := false;
  v_claims    jsonb;
  v_email     text;
  v_is_admin  boolean;
begin
  -- ── A. the '27' role belongs to batch 2027 only ──────────────────────────
  if TG_OP = 'INSERT' then
    if v_batch = '2027' and v_role in ('', 'member') then
      new.role := '27';                       -- auto-tag a new 2027 registrant
    elsif v_role = '27' and v_batch <> '2027' then
      raise exception 'TEMP-SIGNDAY-60: role "27" (NGHS 60th Sign Day) is only for batch 2027 — this row is batch %.',
        coalesce(nullif(v_batch, ''), 'not set')
        using hint = 'Set batch_year to 2027 first, or use another role (member / elite / alumni / architect).';
    end if;
  else
    if new.role = '27' and v_batch <> '2027' then
      if v_oldrole = '27' then
        new.role := 'member';                 -- they edited their batch away from 2027
      else
        raise exception 'TEMP-SIGNDAY-60: role "27" (NGHS 60th Sign Day) is only for batch 2027 — this row is batch %.',
          coalesce(nullif(v_batch, ''), 'not set')
          using hint = 'Set batch_year to 2027 first, or use another role (member / elite / alumni / architect).';
      end if;
    elsif v_role = '' and v_oldrole = '27' and v_batch = '2027' then
      new.role := '27';                       -- keep the tag if a form blanks the role
    end if;
  end if;

  -- ── B. the ticket serial, and retiring it when the tag is taken back ─────
  if new.role = '27' then
    if nullif(trim(coalesce(new.signday_pass_code, '')), '') is null then
      new.signday_pass_code := 'SD60-27-'
        || upper(substr(md5(new.id::text),          1, 4)) || '-'
        || upper(substr(md5(reverse(new.id::text)), 1, 4));
    end if;
  elsif TG_OP = 'UPDATE' and v_oldrole = '27' then
    new.signday_pass_code := null;
    new.signday_status    := 'unconfirmed';
    new.signday_notified  := false;
    v_retired := true;                        -- our own reset, not a student edit
  end if;

  -- ── C. who may change signday_status ─────────────────────────────────────
  --      the student: 'unconfirmed' -> 'submitted' (their REGISTER button)
  --      'issued' is yours: the Table editor, or section 13 below.
  if not v_retired and new.signday_status is distinct from v_oldstatus then
    begin
      v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
    exception when others then
      v_claims := null;
    end;
    v_email := lower(coalesce(v_claims ->> 'email', ''));
    -- The dashboard / Table editor has no auth.uid() at all, so it passes through.
    v_is_admin := auth.uid() is null
               or v_email = any (array['nghsians@gmail.com', 'umairhoquechowdhury13@gmail.com']);

    if not v_is_admin then
      if new.signday_status = 'submitted' and v_oldstatus = 'unconfirmed' then
        null;                                 -- their own registration: allowed
      else
        new.signday_status := v_oldstatus;    -- refused, but their save still works
      end if;
    end if;

    if new.signday_status = 'submitted' and v_oldstatus = 'unconfirmed' then
      if new.signday_submitted_at is null then
        new.signday_submitted_at := timezone('utc'::text, now());
      end if;
      if nullif(trim(coalesce(new.signday_email, '')), '') is null then
        new.signday_email := coalesce(new.email, v_email);
      end if;
    end if;

    if new.signday_status <> 'issued' and new.signday_notified then
      new.signday_notified := false;          -- so a re-issue celebrates again
    end if;
  end if;

  return new;
end;
$sd$;

drop trigger if exists signday_guard on public.verified_profiles;

create trigger signday_guard
before insert or update on public.verified_profiles
for each row execute function public.signday_guard();

-- Serials are unique by construction (derived from the row id); the index lets
-- you look a student up from the code printed on their pass.
create unique index if not exists verified_profiles_signday_pass_code_key
  on public.verified_profiles (signday_pass_code)
  where signday_pass_code is not null;

create index if not exists verified_profiles_signday_role_idx
  on public.verified_profiles (role, signday_status);


-- ============================================================================
-- 12. TEMP-SIGNDAY-60 — one-time backfill: every 2027 student already in the
--     table gets the pass. Re-running is harmless — it only touches plain
--     'member' rows, so a tag you removed on purpose stays removed.
-- ============================================================================
update public.verified_profiles
   set role = '27'
 where lower(trim(coalesce(batch_year, ''))) = '2027'
   and coalesce(nullif(trim(role), ''), 'member') = 'member';


-- ============================================================================
-- 13. TEMP-SIGNDAY-60 — admin commands (run whenever you need to)
-- ============================================================================
-- Give the pass to one student (batch 2027 only, or the trigger refuses):
--   update public.verified_profiles set role = '27' where id = '<uuid>';
--
-- Issue a pass once you have their email:
--   update public.verified_profiles set signday_status = 'issued'
--    where lower(trim(coalesce(signday_email, email))) = 'student@example.com';
--
-- Issue every pass that is waiting on you:
--   update public.verified_profiles set signday_status = 'issued'
--    where role = '27' and signday_status = 'submitted';
--
-- Take a pass back (they go back to a plain member, the ticket is retired):
--   update public.verified_profiles set role = 'member' where id = '<uuid>';
--
-- The roster — who registered and who still has to:
--   select username, school_id, batch_year, signday_status, signday_pass_code,
--          coalesce(signday_email, email) as contact_email, signday_submitted_at
--     from public.verified_profiles
--    where role = '27'
--    order by signday_status, username;
--
-- Did it install? (returns the trigger, the 5 columns and the tag counts)
--   select t.tgname from pg_trigger t
--     join pg_class c on c.oid = t.tgrelid
--    where c.relname = 'verified_profiles' and t.tgname = 'signday_guard';
--   select count(*) filter (where role = '27') as tagged,
--          count(*) filter (where role = '27' and signday_status = 'submitted') as waiting
--     from public.verified_profiles;


-- ============================================================================
-- 14. TEMP-SIGNDAY-60 — ROLLBACK / REMOVE THIS WHOLE FEATURE
--     Uncomment everything below and run it once. It drops only what sections
--     10-12 added; verified_profiles and every normal column stay untouched.
--     Then delete the TEMP-SIGNDAY-60 regions from account.html.
-- ============================================================================
-- update public.verified_profiles set role = 'member' where role = '27';
-- drop trigger if exists signday_guard on public.verified_profiles;
-- drop function if exists public.signday_guard();
-- drop index if exists public.verified_profiles_signday_pass_code_key;
-- drop index if exists public.verified_profiles_signday_role_idx;
-- alter table public.verified_profiles drop constraint if exists verified_profiles_signday_status_check;
-- alter table public.verified_profiles drop column if exists signday_status;
-- alter table public.verified_profiles drop column if exists signday_email;
-- alter table public.verified_profiles drop column if exists signday_pass_code;
-- alter table public.verified_profiles drop column if exists signday_submitted_at;
-- alter table public.verified_profiles drop column if exists signday_notified;

-- ############################################################################
-- ##   ⏳  TEMP-SIGNDAY-60  ·  END OF TEMPORARY SECTION                        ##
-- ############################################################################
