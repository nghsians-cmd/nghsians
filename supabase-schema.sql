/* ============================================================================
   NGHSIANS — SUPABASE SCHEMA  (idempotent / safe to re-run)
   Updated: 2026-10-03  ·  v5: accepts role '27' without losing the batch guard

   WHY EVERY STATEMENT IS ON ITS OWN LINE
     Supabase's "Potential issues detected" dialog ("Run and enable RLS") rewrites
     the script before running it, and that rewrite works line by line — it can
     split a multi-line CREATE TABLE and leave an unterminated statement behind
     ("syntax error at or near \"alter\"", "syntax error at or near \"if\"").
     Nothing here spans more than one line except the two function bodies, so
     there is nothing for a line-based rewrite to cut.

   IF THAT DIALOG APPEARS: press "Run without RLS". This file already enables RLS
   and creates every policy itself, one line after each CREATE TABLE — you do not
     need Supabase to add anything.

   WHAT'S IN THIS VERSION
     • ⏳ TEMP SIGNDAY-60 (sections 8-12) — the NGHS 60th Sign Day pass for batch
       2027: role value '27', five signday_* columns, an expanded role check, a
       trigger that auto-issues the tag to 2027 registrants and refuses it for
       any other batch, admin commands, and a one-pass rollback. Sections 8-12
       are also the ONLY part you need if sections 0-7 already ran.
     • verified_profiles.whatsapp_number / instagram_username — the required
       WhatsApp + Instagram fields on account.html (signup, profile gate, Edit).

   HOW TO RUN
     1. Supabase Dashboard → SQL Editor → New query
     2. Paste this WHOLE file → "Run without RLS".
     3. Safe on a live site: nothing is dropped and no data is deleted. Every
        statement skips itself when it is already applied.
   ============================================================================ */


/* ── 0. QUICK MIGRATION — the only part you need if the old script already ran ── */
alter table if exists public.verified_profiles add column if not exists whatsapp_number text;
alter table if exists public.verified_profiles add column if not exists instagram_username text;


/* ── 1. 'verified_profiles' — created only if it does not exist yet ─────────── */
create table if not exists public.verified_profiles (id uuid references auth.users not null primary key, created_at timestamp with time zone default timezone('utc'::text, now()) not null);
alter table if exists public.verified_profiles enable row level security;


/* ── 2. Columns — each one is skipped automatically when it already exists ──── */
alter table public.verified_profiles add column if not exists full_name text;
alter table public.verified_profiles add column if not exists username text;
alter table public.verified_profiles add column if not exists email text;
alter table public.verified_profiles add column if not exists school_id text;
alter table public.verified_profiles add column if not exists batch_year text;
alter table public.verified_profiles add column if not exists whatsapp_number text;
alter table public.verified_profiles add column if not exists instagram_username text;
alter table public.verified_profiles add column if not exists role text default 'member';
alter table public.verified_profiles add column if not exists notified_of_verification boolean default false;
alter table public.verified_profiles add column if not exists follower_count int default 0;
comment on column public.verified_profiles.role is 'member | elite | alumni | architect | 27 (27 = TEMP-SIGNDAY-60 pass, batch 2027 only)';
comment on column public.verified_profiles.whatsapp_number is 'WhatsApp number in international form, e.g. +8801700000000';
comment on column public.verified_profiles.instagram_username is 'Instagram username without the @, e.g. nghsians';


/* ── 3. Deprecated 'is_verified' column — only needed if you still have it ─────
      Leave these two lines commented out unless a very old backup is being restored.
   update verified_profiles set role = 'elite' where is_verified = true;
   alter table verified_profiles drop column if exists is_verified;
   ─────────────────────────────────────────────────────────────────────────── */


/* ── 4. Policies for 'verified_profiles' (dropped first so re-running is safe) ─ */
drop policy if exists "Public profiles are viewable by everyone." on public.verified_profiles;
create policy "Public profiles are viewable by everyone." on public.verified_profiles for select using ( true );
drop policy if exists "Users can update own profile." on public.verified_profiles;
create policy "Users can update own profile." on public.verified_profiles for update using ( auth.uid() = id );
drop policy if exists "Users can insert own profile." on public.verified_profiles;
create policy "Users can insert own profile." on public.verified_profiles for insert with check ( auth.uid() = id );


/* ── 5. 'user_relationships' — the follow / unfollow system ─────────────────── */
create table if not exists public.user_relationships (id uuid default gen_random_uuid() primary key, follower_id uuid references auth.users not null, following_id uuid references auth.users not null, created_at timestamp with time zone default timezone('utc'::text, now()) not null, unique(follower_id, following_id));
alter table if exists public.user_relationships enable row level security;
drop policy if exists "Anyone can view relationships" on public.user_relationships;
create policy "Anyone can view relationships" on public.user_relationships for select using (true);
drop policy if exists "Users can follow others" on public.user_relationships;
create policy "Users can follow others" on public.user_relationships for insert with check (auth.uid() = follower_id);
drop policy if exists "Users can unfollow" on public.user_relationships;
create policy "Users can unfollow" on public.user_relationships for delete using (auth.uid() = follower_id);


/* ── 6. Trigger that keeps follower counts up to date (the one multi-line body) ─ */
create or replace function public.update_follower_count() returns trigger language plpgsql security definer as $fc$
begin
  if (TG_OP = 'INSERT') then
    update public.verified_profiles set follower_count = coalesce(follower_count, 0) + 1 where id = new.following_id;
    return new;
  elsif (TG_OP = 'DELETE') then
    update public.verified_profiles set follower_count = greatest(coalesce(follower_count, 0) - 1, 0) where id = old.following_id;
    return old;
  end if;
  return null;
end;
$fc$;
drop trigger if exists on_follow_change on public.user_relationships;
create trigger on_follow_change after insert or delete on public.user_relationships for each row execute function public.update_follower_count();


/* ── 7. VERIFY (optional) ────────────────────────────────────────────────────
   select column_name, data_type from information_schema.columns
    where table_name = 'verified_profiles'
      and column_name in ('whatsapp_number', 'instagram_username', 'role', 'follower_count')
    order by column_name;
   ─────────────────────────────────────────────────────────────────────────── */


/* ############################################################################
   ##  ⏳  TEMPORARY SECTION  ·  "NGHS 60th SIGN DAY" PASS  (BATCH 2027)        ##
   ##  ⏳  MARKER:  TEMP-SIGNDAY-60  ·  START                                    ##
   ##                                                                            ##
   ##  A one-off feature for the 60th Sign Day. Safe to re-run, deletes nothing, ##
   ##  and section 14 undoes all of it in one pass.                              ##
   ##                                                                            ##
   ##  WHAT IT DOES                                                              ##
   ##    • 5 signday_* columns on verified_profiles:                             ##
   ##        signday_status       'unconfirmed' | 'submitted' | 'issued'       ##
   ##        signday_email        the account email the student handed over      ##
   ##        signday_pass_code    ticket serial, e.g. SD60-27-4F2A-91BC          ##
   ##        signday_submitted_at when they pressed REGISTER on their card        ##
   ##        signday_notified     one-time "your pass is live" celebration       ##
   ##    • the role value  '27'  — the only thing you type by hand. It is only   ##
   ##      valid for batch_year = '2027': the trigger rejects it for every other ##
   ##      batch, and quietly withdraws it if a student edits their own batch    ##
   ##      away from 2027.                                                       ##
   ##    • auto-tags every new 2027 registration, backfills the 2027 students    ##
   ##      already in the table, and writes the ticket serial itself.            ##
   ##                                                                            ##
   ##  HOW IT PLAYS OUT                                                          ##
   ##    1. a 2027 student registers        → role '27' + status 'unconfirmed'   ##
   ##      appear on their own: blue tag + the registration notice               ##
   ##    2. they press REGISTER on the card → status 'submitted', their account  ##
   ##      email lands in signday_email                                          ##
   ##    3. you issue their pass            → type 'issued' in signday_status;   ##
   ##      the card becomes a live pass and they get a one-time celebration      ##
   ##      on their next sign-in.                                               ##
   ############################################################################ */


/* ── 8. TEMP-SIGNDAY-60 — columns + role check ──────────────────────────────── */
/* Replace the older role check that rejects '27'; keep the site's four normal roles. */
alter table public.verified_profiles drop constraint if exists verified_profiles_role_check;
alter table public.verified_profiles add constraint verified_profiles_role_check check (role in ('member', 'elite', 'alumni', 'architect', '27') and (role <> '27' or lower(trim(coalesce(batch_year, ''))) = '2027'));
alter table public.verified_profiles add column if not exists signday_status text not null default 'unconfirmed';
alter table public.verified_profiles add column if not exists signday_email text;
alter table public.verified_profiles add column if not exists signday_pass_code text;
alter table public.verified_profiles add column if not exists signday_submitted_at timestamp with time zone;
alter table public.verified_profiles add column if not exists signday_notified boolean not null default false;
comment on column public.verified_profiles.signday_status is 'TEMP-SIGNDAY-60: unconfirmed | submitted | issued for the batch-2027 Sign Day pass';
comment on column public.verified_profiles.signday_email is 'TEMP-SIGNDAY-60: account email the student handed to the Sign Day committee';
comment on column public.verified_profiles.signday_pass_code is 'TEMP-SIGNDAY-60: ticket serial printed on the pass card';
comment on column public.verified_profiles.signday_submitted_at is 'TEMP-SIGNDAY-60: when the student registered for the pass';
comment on column public.verified_profiles.signday_notified is 'TEMP-SIGNDAY-60: pass-issued celebration already shown';
alter table public.verified_profiles drop constraint if exists verified_profiles_signday_status_check;
alter table public.verified_profiles add constraint verified_profiles_signday_status_check check (signday_status in ('unconfirmed', 'submitted', 'issued'));


/* ── 9. TEMP-SIGNDAY-60 — guard / auto-issue trigger (the only other multi-line body) ─ */
create or replace function public.signday_guard() returns trigger language plpgsql as $sd$
declare
  v_batch     text := lower(trim(coalesce(new.batch_year, '')));
  v_role      text := lower(trim(coalesce(new.role, '')));
  v_oldrole   text := case when TG_OP = 'UPDATE' then lower(trim(coalesce(old.role, ''))) else '' end;
  v_oldstatus text := case when TG_OP = 'UPDATE' then coalesce(old.signday_status, 'unconfirmed') else 'unconfirmed' end;
  v_retired   boolean := false;
  v_claims    jsonb;
  v_email     text;
  v_is_admin  boolean;
begin
  /* A. the '27' role belongs to batch 2027 only */
  if TG_OP = 'INSERT' then
    if v_batch = '2027' and v_role in ('', 'member') then
      new.role := '27';
    elsif v_role = '27' and v_batch <> '2027' then
      raise exception 'TEMP-SIGNDAY-60: role "27" (NGHS 60th Sign Day) is only for batch 2027 — this row is batch %.', coalesce(nullif(v_batch, ''), 'not set') using hint = 'Set batch_year to 2027 first, or use another role (member / elite / alumni / architect).';
    end if;
  else
    if new.role = '27' and v_batch <> '2027' then
      if v_oldrole = '27' then
        new.role := 'member';
      else
        raise exception 'TEMP-SIGNDAY-60: role "27" (NGHS 60th Sign Day) is only for batch 2027 — this row is batch %.', coalesce(nullif(v_batch, ''), 'not set') using hint = 'Set batch_year to 2027 first, or use another role (member / elite / alumni / architect).';
      end if;
    elsif v_role = '' and v_oldrole = '27' and v_batch = '2027' then
      new.role := '27';
    end if;
  end if;
  /* B. the ticket serial, and retiring it when the tag is taken back */
  if new.role = '27' then
    if nullif(trim(coalesce(new.signday_pass_code, '')), '') is null then
      new.signday_pass_code := 'SD60-27-' || upper(substr(md5(new.id::text), 1, 4)) || '-' || upper(substr(md5(reverse(new.id::text)), 1, 4));
    end if;
  elsif TG_OP = 'UPDATE' and v_oldrole = '27' then
    new.signday_pass_code := null;
    new.signday_status := 'unconfirmed';
    new.signday_notified := false;
    v_retired := true;
  end if;
  /* C. who may change signday_status: the student may only go 'unconfirmed' ->
        'submitted' (their REGISTER button). 'issued' is yours, from the Table
        editor or section 11 — the dashboard has no auth.uid(), so it passes. */
  if not v_retired and new.signday_status is distinct from v_oldstatus then
    begin
      v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
    exception when others then
      v_claims := null;
    end;
    v_email := lower(coalesce(v_claims ->> 'email', ''));
    v_is_admin := auth.uid() is null or v_email = any (array['nghsians@gmail.com', 'umairhoquechowdhury13@gmail.com']);
    if not v_is_admin then
      if new.signday_status = 'submitted' and v_oldstatus = 'unconfirmed' then
        null;
      else
        new.signday_status := v_oldstatus;
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
      new.signday_notified := false;
    end if;
  end if;
  return new;
end;
$sd$;
drop trigger if exists signday_guard on public.verified_profiles;
create trigger signday_guard before insert or update on public.verified_profiles for each row execute function public.signday_guard();
create unique index if not exists verified_profiles_signday_pass_code_key on public.verified_profiles (signday_pass_code) where signday_pass_code is not null;
create index if not exists verified_profiles_signday_role_idx on public.verified_profiles (role, signday_status);


/* ── 10. TEMP-SIGNDAY-60 — backfill: every 2027 student already in the table.
      Harmless to re-run: it only touches plain 'member' rows, so a tag you
      removed on purpose stays removed.                                            */
update public.verified_profiles set role = '27' where lower(trim(coalesce(batch_year, ''))) = '2027' and coalesce(nullif(trim(role), ''), 'member') = 'member';


/* ── 11. TEMP-SIGNDAY-60 — admin commands (run whichever you need) ────────────
   Give the pass to one student (batch 2027 only, or the trigger refuses):
   update public.verified_profiles set role = '27' where id = '<uuid>';

   Issue a pass once you have their email:
   update public.verified_profiles set signday_status = 'issued' where lower(trim(coalesce(signday_email, email))) = 'student@example.com';

   Issue every pass that is waiting on you:
   update public.verified_profiles set signday_status = 'issued' where role = '27' and signday_status = 'submitted';

   Take a pass back (they go back to plain member, the ticket is retired):
   update public.verified_profiles set role = 'member' where id = '<uuid>';

   The roster — who registered, and who still has to:
   select username, school_id, batch_year, signday_status, signday_pass_code, coalesce(signday_email, email) as contact_email, signday_submitted_at from public.verified_profiles where role = '27' order by signday_status, username;

   Did it install?
   select t.tgname from pg_trigger t join pg_class c on c.oid = t.tgrelid where c.relname = 'verified_profiles' and t.tgname = 'signday_guard';
   select count(*) filter (where role = '27') as tagged, count(*) filter (where role = '27' and signday_status = 'submitted') as waiting from public.verified_profiles;
   ─────────────────────────────────────────────────────────────────────────── */


/* ── 12. TEMP-SIGNDAY-60 — ROLLBACK / REMOVE THIS WHOLE FEATURE ────────────────
      Uncomment all of it and run once. It returns role validation to the four
      normal roles, removes the Sign Day columns/trigger/indexes, and leaves all
      profile data and ordinary columns untouched. Then delete the TEMP-SIGNDAY-60
      regions from account.html.

   update public.verified_profiles set role = 'member' where role = '27';
   alter table public.verified_profiles drop constraint if exists verified_profiles_role_check;
   alter table public.verified_profiles add constraint verified_profiles_role_check check (role in ('member', 'elite', 'alumni', 'architect'));
   drop trigger if exists signday_guard on public.verified_profiles;
   drop function if exists public.signday_guard();
   drop index if exists public.verified_profiles_signday_pass_code_key;
   drop index if exists public.verified_profiles_signday_role_idx;
   alter table public.verified_profiles drop constraint if exists verified_profiles_signday_status_check;
   alter table public.verified_profiles drop column if exists signday_status;
   alter table public.verified_profiles drop column if exists signday_email;
   alter table public.verified_profiles drop column if exists signday_pass_code;
   alter table public.verified_profiles drop column if exists signday_submitted_at;
   alter table public.verified_profiles drop column if exists signday_notified;
   ─────────────────────────────────────────────────────────────────────────── */

/* ############################################################################
   ##  ⏳  TEMP-SIGNDAY-60  ·  END OF TEMPORARY SECTION                        ##
   ############################################################################ */
