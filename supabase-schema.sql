-- ============================================================================
--  NGHSIANS — SUPABASE SCHEMA  (idempotent / safe to re-run)
--  Updated: 2026-10-03
--
--  WHAT'S NEW IN THIS VERSION
--    • ⏳ TEMP SIGNDAY-60 (sections 10-14) — the NGHS 60th Sign Day pass for
--      batch 2027: a new role value '27', five signday_* columns, a trigger
--      that auto-issues the tag to 2027 registrants and refuses it for every
--      other batch, plus the admin commands and a one-pass rollback.
--      Marked TEMPORARY start to finish — skip it entirely once the event is
--      over and run section 14 to undo it.
--
--  ALREADY IN PLACE (previous version)
--    • verified_profiles.whatsapp_number     text   -> stored as "+8801700000000"
--    • verified_profiles.instagram_username  text   -> stored as "nghsians" (no @)
--    These two columns power the new required fields on account.html
--    (signup form, the "Complete your profile" gate, and Edit mode).
--
--  HOW TO RUN
--    1. Supabase Dashboard -> SQL Editor -> New query
--    2. Paste this WHOLE file, press RUN.
--    3. Safe on a live site: nothing is dropped and no data is deleted.
--       Every statement only creates what is missing.
--
--  IMPORTANT
--    Run this BEFORE (or at the same time as) the updated account.html goes
--    live, otherwise the new fields can't be saved.
-- ============================================================================


-- ============================================================================
-- 0. QUICK MIGRATION — the only part you need if the old script already ran
--    (wrapped in a DO block so the file also runs on a brand-new database,
--     where verified_profiles does not exist yet)
-- ============================================================================
do $$
begin
  if to_regclass('public.verified_profiles') is not null then
    alter table public.verified_profiles add column if not exists whatsapp_number    text;
    alter table public.verified_profiles add column if not exists instagram_username text;
    comment on column verified_profiles.whatsapp_number    is 'WhatsApp number in international form, e.g. +8801700000000';
    comment on column verified_profiles.instagram_username is 'Instagram username without the @, e.g. nghsians';
  end if;
end $$;


-- 1. Safe Setup for 'verified_profiles' Table
-- Checks if table exists, if not creates it.
create table if not exists verified_profiles (
  id uuid references auth.users not null primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Enable Row Level Security (Security Best Practice)
alter table verified_profiles enable row level security;

-- 3. Safe Column Addition: Adds columns only if they are missing
do $$
begin
  -- Basic Profile Info
  if not exists (select 1 from information_schema.columns where table_name = 'verified_profiles' and column_name = 'full_name') then
    alter table verified_profiles add column full_name text;
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'verified_profiles' and column_name = 'username') then
    alter table verified_profiles add column username text;
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'verified_profiles' and column_name = 'email') then
    alter table verified_profiles add column email text;
  end if;

  -- Student Details
  if not exists (select 1 from information_schema.columns where table_name = 'verified_profiles' and column_name = 'school_id') then
    alter table verified_profiles add column school_id text;
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'verified_profiles' and column_name = 'batch_year') then
    alter table verified_profiles add column batch_year text;
  end if;

  -- Contact Details (NEW — added for the required WhatsApp / Instagram fields)
  if not exists (select 1 from information_schema.columns where table_name = 'verified_profiles' and column_name = 'whatsapp_number') then
    alter table verified_profiles add column whatsapp_number text;
    comment on column verified_profiles.whatsapp_number is 'WhatsApp number in international form, e.g. +8801700000000';
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'verified_profiles' and column_name = 'instagram_username') then
    alter table verified_profiles add column instagram_username text;
    comment on column verified_profiles.instagram_username is 'Instagram username without the @, e.g. nghsians';
  end if;

  -- Roles & Verification
  if not exists (select 1 from information_schema.columns where table_name = 'verified_profiles' and column_name = 'role') then
    alter table verified_profiles add column role text default 'member';
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'verified_profiles' and column_name = 'notified_of_verification') then
    alter table verified_profiles add column notified_of_verification boolean default false;
  end if;

  -- Network Stats
  if not exists (select 1 from information_schema.columns where table_name = 'verified_profiles' and column_name = 'follower_count') then
    alter table verified_profiles add column follower_count int default 0;
  end if;

end $$;

-- 4. Data Migration (One-time cleanup for old 'is_verified' column)
do $$
begin
  if exists (select 1 from information_schema.columns where table_name = 'verified_profiles' and column_name = 'is_verified') then
    -- Move old verified users to 'elite' role
    update verified_profiles set role = 'elite' where is_verified = true;
    -- We won't drop the column automatically just to be safe, but it's deprecated now.
  end if;
end $$;

-- 5. Policies for 'verified_profiles'
-- (Drop old ones first to avoid conflicts)

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


-- 6. Setup for 'user_relationships' (Follow/Unfollow System)
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


-- 8. Database Trigger for Auto-Updating Follower Counts
-- This function runs automatically whenever someone follows/unfollows

create or replace function update_follower_count()
returns trigger as $$
begin
  if (TG_OP = 'INSERT') then
    -- Increment count for the person being followed
    update verified_profiles
    set follower_count = follower_count + 1
    where id = new.following_id;
    return new;
  elsif (TG_OP = 'DELETE') then
    -- Decrement count for the person being unfollowed
    update verified_profiles
    set follower_count = follower_count - 1
    where id = old.following_id;
    return old;
  end if;
  return null;
end;
$$ language plpgsql security definer;

-- Drop trigger if exists to avoid duplication errors
drop trigger if exists on_follow_change on user_relationships;

create trigger on_follow_change
after insert or delete on user_relationships
for each row execute function update_follower_count();


-- ============================================================================
-- 9. VERIFY (optional) — should return two rows
-- ============================================================================
-- select column_name, data_type
-- from information_schema.columns
-- where table_name = 'verified_profiles'
--   and column_name in ('whatsapp_number', 'instagram_username');


-- ############################################################################
-- ##                                                                          ##
-- ##   ⏳  TEMPORARY SECTION  ·  "NGHS 60th SIGN DAY" PASS  (BATCH 2027)        ##
-- ##   ⏳  MARKER:  TEMP-SIGNDAY-60  ·  START                                    ##
-- ##                                                                          ##
-- ##   Everything between the START and END markers below is a one-off        ##
-- ##   feature for the 60th Sign Day. It is safe to re-run, deletes nothing,  ##
-- ##   and can be removed in one pass with the script in section 14.          ##
-- ##                                                                          ##
-- ##   WHAT IT DOES                                                           ##
-- ##     • Adds 5 new columns on verified_profiles (all named signday_*):     ##
-- ##         signday_status       'unconfirmed' | 'submitted' | 'issued'     ##
-- ##         signday_email        the account email the student handed over   ##
-- ##         signday_pass_code    ticket serial, e.g. SD60-27-4F2A-91BC       ##
-- ##         signday_submitted_at when they pressed REGISTER on their card     ##
-- ##         signday_notified     one-time "your pass is live" celebration     ##
-- ##     • Adds a new ROLE VALUE:  '27'  (this is what you type in the         ##
-- ##       Table editor's role column). It is ONLY valid for                  ##
-- ##       batch_year = '2027' — a trigger rejects it for every other batch.  ##
-- ##     • AUTO-ISSUES role '27' to every NEW account whose batch is 2027,    ##
-- ##       and backfills every 2027 student already in the table.             ##
-- ##     • Generates the pass serial on its own. Nothing to type.             ##
-- ##                                                                          ##
-- ##   HOW IT PLAYS OUT (Supabase → Table editor → verified_profiles)         ##
-- ##     1. A 2027 student registers         → role '27' + status              ##
-- ##        'unconfirmed' land on their own → they see the blue UNCONFIRMED    ##
-- ##        tag and the "Register For NGHS 60th Sign Day" notice.              ##
-- ##     2. They press REGISTER on the card  → signday_status = 'submitted'    ##
-- ##        and signday_email holds the address they gave.                     ##
-- ##     3. You issue their pass             → type 'issued' in                ##
-- ##        signday_status; the card turns into a live pass and they get       ##
-- ##        a one-time celebration on next sign-in.                           ##
-- ##                                                                          ##
-- ##   Students still waiting for a pass, in one query:                       ##
-- ##     select username, batch_year, signday_status, signday_email           ##
-- ##       from verified_profiles                                             ##
-- ##      where role = '27' order by signday_status, username;                ##
-- ############################################################################


-- ============================================================================
-- 10. TEMP-SIGNDAY-60 — columns
-- ============================================================================
do $$
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'verified_profiles'
                   and column_name = 'signday_status') then
    alter table public.verified_profiles
      add column signday_status text not null default 'unconfirmed';
  end if;

  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'verified_profiles'
                   and column_name = 'signday_email') then
    alter table public.verified_profiles add column signday_email text;
  end if;

  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'verified_profiles'
                   and column_name = 'signday_pass_code') then
    alter table public.verified_profiles add column signday_pass_code text;
  end if;

  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'verified_profiles'
                   and column_name = 'signday_submitted_at') then
    alter table public.verified_profiles
      add column signday_submitted_at timestamp with time zone;
  end if;

  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'verified_profiles'
                   and column_name = 'signday_notified') then
    alter table public.verified_profiles
      add column signday_notified boolean not null default false;
  end if;

  -- Only the three known states, so a typo in the Table editor gets caught.
  if not exists (select 1 from pg_constraint
                 where conrelid = 'public.verified_profiles'::regclass
                   and conname  = 'verified_profiles_signday_status_check') then
    alter table public.verified_profiles
      add constraint verified_profiles_signday_status_check
      check (signday_status in ('unconfirmed', 'submitted', 'issued'));
  end if;
end $$;

comment on column public.verified_profiles.signday_status       is 'TEMP-SIGNDAY-60: unconfirmed | submitted | issued for the batch-2027 Sign Day pass';
comment on column public.verified_profiles.signday_email        is 'TEMP-SIGNDAY-60: account email the student handed to the Sign Day committee';
comment on column public.verified_profiles.signday_pass_code    is 'TEMP-SIGNDAY-60: ticket serial printed on the pass card';
comment on column public.verified_profiles.signday_submitted_at is 'TEMP-SIGNDAY-60: when the student registered for the pass';
comment on column public.verified_profiles.signday_notified     is 'TEMP-SIGNDAY-60: pass-issued celebration already shown';


-- ============================================================================
-- 11. TEMP-SIGNDAY-60 — guard / auto-issue trigger
--     role '27'  <=>  batch_year '2027'.  No other batch can hold the tag,
--     and no student can mark their own pass as 'issued'.
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
  -- ── A. the '27' role belongs to batch 2027 only ────────────────────────────
  if TG_OP = 'INSERT' then
    if v_batch = '2027' and v_role in ('', 'member') then
      new.role := '27';                    -- auto-issue to a new 2027 registrant
    elsif v_role = '27' and v_batch <> '2027' then
      raise exception 'TEMP-SIGNDAY-60: role "27" (NGHS 60th Sign Day) is only for batch 2027 — this row is batch %.',
        coalesce(nullif(v_batch, ''), 'not set')
        using hint = 'Set batch_year to 2027 first, or use another role (member / elite / alumni / architect).';
    end if;
  else
    if new.role = '27' and v_batch <> '2027' then
      if v_oldrole = '27' then
        new.role := 'member';              -- they edited their batch away from 2027
      else
        raise exception 'TEMP-SIGNDAY-60: role "27" (NGHS 60th Sign Day) is only for batch 2027 — this row is batch %.',
          coalesce(nullif(v_batch, ''), 'not set')
          using hint = 'Set batch_year to 2027 first, or use another role (member / elite / alumni / architect).';
      end if;
    elsif coalesce(nullif(v_role, ''), '') = '' and v_oldrole = '27' and v_batch = '2027' then
      new.role := '27';                    -- keep the tag if a form blanks the role
    end if;
  end if;

  -- ── B. the ticket serial, and retiring it when the tag is taken back ──────
  if new.role = '27' then
    if nullif(trim(coalesce(new.signday_pass_code, '')), '') is null then
      new.signday_pass_code := 'SD60-27-'
        || upper(substr(md5(new.id::text),           1, 4)) || '-'
        || upper(substr(md5(reverse(new.id::text)),  1, 4));
    end if;
  elsif TG_OP = 'UPDATE' and v_oldrole = '27' then
    new.signday_pass_code := null;
    new.signday_status    := 'unconfirmed';
    new.signday_notified  := false;
    v_retired := true;                     -- our own reset, not a student edit
  end if;

  -- ── C. who may change signday_status ──────────────────────────────────────
  --      the student: 'unconfirmed' → 'submitted' (their REGISTER button)
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
        null;                                     -- their own registration: allowed
      else
        new.signday_status := v_oldstatus;        -- refused, but their save still works
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
      new.signday_notified := false;              -- so a re-issue celebrates again
    end if;
  end if;

  return new;
end;
$sd$;

drop trigger if exists signday_guard on public.verified_profiles;
create trigger signday_guard
before insert or update on public.verified_profiles
for each row execute function public.signday_guard();

-- Serials are unique by construction (they are derived from the row id); the
-- index lets you look a student up from the code printed on their pass.
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
-- Issue a pass once you have their email in your notebook:
--   update public.verified_profiles
--      set signday_status = 'issued'
--    where lower(trim(coalesce(signday_email, email))) = 'student@example.com';
--
-- Issue every pass that is waiting on you:
--   update public.verified_profiles
--      set signday_status = 'issued'
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


-- ============================================================================
-- 14. TEMP-SIGNDAY-60 — ROLLBACK / REMOVE THIS WHOLE FEATURE
--     Uncomment everything below and run it once. It drops only what the block
--     above added; verified_profiles and every normal column stay untouched.
--     Then delete the TEMP-SIGNDAY-60 sections from account.html.
-- ============================================================================
-- update public.verified_profiles set role = 'member' where role = '27';
-- drop trigger  if exists signday_guard on public.verified_profiles;
-- drop function if exists public.signday_guard();
-- drop index    if exists public.verified_profiles_signday_pass_code_key;
-- drop index    if exists public.verified_profiles_signday_role_idx;
-- alter table public.verified_profiles drop constraint if exists verified_profiles_signday_status_check;
-- alter table public.verified_profiles drop column if exists signday_status;
-- alter table public.verified_profiles drop column if exists signday_email;
-- alter table public.verified_profiles drop column if exists signday_pass_code;
-- alter table public.verified_profiles drop column if exists signday_submitted_at;
-- alter table public.verified_profiles drop column if exists signday_notified;

-- ############################################################################
-- ##   ⏳  TEMP-SIGNDAY-60  ·  END OF TEMPORARY SECTION                        ##
-- ############################################################################
