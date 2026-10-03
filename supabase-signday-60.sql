/* ============================================================================
   NGHSIANS — 60th SIGN DAY PASS  (batch 2027)   ·  v5  ·  idempotent

   ⏳  TEMPORARY FEATURE  ·  MARKER: TEMP-SIGNDAY-60  (sections S1-S5)
   The Sign Day half of supabase-schema.sql, split out so it can be run on its
   own. It has no CREATE TABLE in it, so Supabase never offers to "enable RLS"
   — and therefore never rewrites the script and breaks it.

   USE IT WHEN verified_profiles already exists — true for this project (the
   site is live and profiles load). If the "Potential issues detected" dialog
   still appears, press "Run without RLS": RLS and the policies are in place.

   HOW: Supabase Dashboard → SQL Editor → New query → paste this whole file.
   Re-running is safe, nothing is deleted, and section S5 undoes all of it.
   ============================================================================ */

/* ############################################################################
   ##  ⏳  TEMPORARY SECTION  ·  "NGHS 60th SIGN DAY" PASS  (BATCH 2027)        ##
   ##  ⏳  MARKER:  TEMP-SIGNDAY-60  ·  START                                    ##
   ##                                                                            ##
   ##  A one-off feature for the 60th Sign Day. Safe to re-run, deletes nothing, ##
   ##  and section S5 undoes all of it in one pass.                              ##
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


/* ── S1. TEMP-SIGNDAY-60 — columns + role check ─────────────────────────────── */
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


/* ── S2. TEMP-SIGNDAY-60 — guard / auto-issue trigger (the only multi-line body in this file) ─ */
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
        editor or section S4 — the dashboard has no auth.uid(), so it passes. */
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


/* ── S3. TEMP-SIGNDAY-60 — backfill: every 2027 student already in the table.
      Harmless to re-run: it only touches plain 'member' rows, so a tag you
      removed on purpose stays removed.                                            */
update public.verified_profiles set role = '27' where lower(trim(coalesce(batch_year, ''))) = '2027' and coalesce(nullif(trim(role), ''), 'member') = 'member';


/* ── S4. TEMP-SIGNDAY-60 — admin commands (run whichever you need) ────────────
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


/* ── S5. TEMP-SIGNDAY-60 — ROLLBACK / REMOVE THIS WHOLE FEATURE ────────────────
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
