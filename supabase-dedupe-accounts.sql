/* ============================================================================
   NGHSIANS — DUPLICATE ACCOUNTS  ·  find them, block new ones, lock the email
   Updated: 2026-10-08

   WHAT COUNTS AS A DUPLICATE
     Accounts that share an email once capitals and surrounding spaces are
     ignored ("Abdullah@Gmail.com " = "abdullah@gmail.com"). Both the login email
     (auth.users.email) and the email shown on the profile (verified_profiles.email)
     are compared. Accounts linked by any shared email form ONE group, so the same
     person is never split across two groups.

   THE RULE
     KEEP        the most recently created account in each group
     TERMINATE   every older account in that group (removed by supabase-dedupe-terminate.sql)
     REVIEW      never removed automatically. A group is REVIEW when it contains:
                   • an admin email (nghsians@gmail.com, umairhoquechowdhury13@gmail.com)
                   • a role other than member or 27 (elite, alumni, architect, ...)
                   • a newest account with no profile while an older one has a profile
                     (keeping the empty account would delete the real profile)

   FILES
     supabase-dedupe-accounts.sql    (this file) read-only preview, audit table,
                                     duplicate guard and email lock. Deletes NOTHING.
     supabase-dedupe-terminate.sql   deletes the TERMINATE accounts. Run it only
                                     after you have read the preview.

   HOW TO RUN
     1. Supabase Dashboard → SQL Editor → New query → paste THIS file →
        "Run without RLS". Sections 1, 4 and 5 are created. Section 6 (the lock) is
        the last statement and FAILS with "could not create unique index" while any
        duplicate is still left. That failure is the safety check, not a bug.
     2. Read the preview: select ONE line of section 2 and press Run (the editor
        shows only the last result of a run). Check every TERMINATE row. Then select
        ONE line of section 3 and check that no table outside the expected ones
        points at auth.users without ON DELETE CASCADE.
     3. When the preview is what you expect: paste supabase-dedupe-terminate.sql
        and Run it.
     4. Run section 6 again. It succeeds once no duplicate is left, REVIEW rows included.

   Each statement sits on its own line, as in supabase-schema.sql. The only
   multi-line statements are the two function bodies.
   ============================================================================ */


/* ── 1. Helper: the duplicate plan. READ-ONLY function, changes nothing. ────── */
create or replace function public.nghs_duplicate_plan() returns table (group_key text, group_size int, decision text, reason text, user_id uuid, kept_user_id uuid, login_email text, profile_email text, username text, role text, batch_year text, follower_count int, follows int, has_profile boolean, auth_created_at timestamp with time zone) language sql stable set search_path = '' as $plan$
with recursive keys as (
  select u.id as user_id, lower(btrim(u.email)) as k from auth.users u where nullif(btrim(u.email), '') is not null
  union
  select p.id, lower(btrim(p.email)) from public.verified_profiles p where nullif(btrim(p.email), '') is not null
),
pairs as (
  select distinct a.user_id as x, b.user_id as y from keys a join keys b on b.k = a.k and b.user_id <> a.user_id
),
reach as (
  select x, y from pairs
  union
  select r.x, p.y from reach r join pairs p on p.x = r.y
),
comp as (
  select s.user_id, string_agg(s.m::text, ',' order by s.m::text) as label
  from (select x as user_id, x as m from reach union select x as user_id, y as m from reach) s
  group by s.user_id
),
members as (
  select c.user_id, c.label, u.email as login_email, p.email as profile_email, p.username, p.role, p.batch_year,
         coalesce(p.follower_count, 0) as follower_count, (p.id is not null) as has_profile,
         coalesce(u.created_at, p.created_at) as created_at
  from comp c
  join auth.users u on u.id = c.user_id
  left join public.verified_profiles p on p.id = c.user_id
),
flagged as (
  select m.*,
         (lower(btrim(coalesce(m.login_email, ''))) in ('nghsians@gmail.com', 'umairhoquechowdhury13@gmail.com')
          or lower(btrim(coalesce(m.profile_email, ''))) in ('nghsians@gmail.com', 'umairhoquechowdhury13@gmail.com')) as is_admin,
         (coalesce(m.role, '') not in ('', 'member', '27')) as is_special_role,
         count(*) over (partition by m.label) as group_size,
         row_number() over (partition by m.label order by m.created_at desc nulls last, m.user_id::text desc) as newest_rank,
         first_value(m.user_id) over (partition by m.label order by m.created_at desc nulls last, m.user_id::text desc) as kept_user_id,
         first_value(m.has_profile) over (partition by m.label order by m.created_at desc nulls last, m.user_id::text desc) as newest_has_profile,
         bool_or(m.has_profile) over (partition by m.label) as any_has_profile
  from members m
),
graded as (
  select f.*,
         bool_or(f.is_admin) over (partition by f.label) as group_has_admin,
         bool_or(f.is_special_role) over (partition by f.label) as group_has_special_role,
         (not f.newest_has_profile and f.any_has_profile) as newest_lacks_profile
  from flagged f
)
select left(md5(g.label), 8) as group_key,
       g.group_size::int as group_size,
       case when (g.group_has_admin or g.group_has_special_role or g.newest_lacks_profile) then 'REVIEW'
            when g.newest_rank = 1 then 'KEEP'
            else 'TERMINATE' end as decision,
       case when g.group_has_admin then 'admin email in this group: not removed automatically'
            when g.group_has_special_role then 'role other than member/27 in this group: not removed automatically'
            when g.newest_lacks_profile then 'newest account has no profile but an older one does: check first'
            when g.newest_rank = 1 then 'newest account in the group: kept'
            else 'older duplicate of the newest account: will be terminated' end as reason,
       g.user_id,
       g.kept_user_id,
       g.login_email::text as login_email,
       g.profile_email::text as profile_email,
       g.username::text as username,
       g.role::text as role,
       g.batch_year::text as batch_year,
       g.follower_count::int as follower_count,
       (select count(*)::int from public.user_relationships r where r.follower_id = g.user_id) as follows,
       g.has_profile,
       g.created_at as auth_created_at
from graded g
$plan$;
revoke execute on function public.nghs_duplicate_plan() from public, anon, authenticated;


/* ── 2. PREVIEW — select ONE line below and press Run. Read-only. ──────────── */
select group_key, group_size, decision, reason, auth_created_at, user_id, kept_user_id, login_email, profile_email, username, role, batch_year, follower_count, follows, has_profile from public.nghs_duplicate_plan() order by group_key, auth_created_at desc nulls last;


/* ── 3. Every foreign key that points at auth.users — select ONE line, Run. ── */
select c.conrelid::regclass as referencing_table, a.attname as column_name, case c.confdeltype when 'c' then 'CASCADE' when 'n' then 'SET NULL' when 'd' then 'SET DEFAULT' when 'r' then 'RESTRICT' else 'NO ACTION' end as on_delete from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any(c.conkey) where c.contype = 'f' and c.confrelid = 'auth.users'::regclass order by 1, 2;


/* ── 4. Audit table: one row per account that was terminated (filled by the terminate file).
          RLS is ON and there are NO policies, so the public API can never read it. ─ */
create table if not exists public.account_dedupe_audit (id bigint generated always as identity primary key, user_id uuid not null unique, kept_user_id uuid, group_key text, decision text, reason text, login_email text, profile_email text, username text, role text, batch_year text, follower_count int, auth_created_at timestamp with time zone, planned_at timestamp with time zone default timezone('utc'::text, now()) not null, terminated_at timestamp with time zone, profile_snapshot jsonb, relationships_snapshot jsonb);
alter table if exists public.account_dedupe_audit enable row level security;
revoke all on public.account_dedupe_audit from anon, authenticated;
comment on table public.account_dedupe_audit is 'Older duplicate accounts removed by supabase-dedupe-terminate.sql, with a snapshot of their profile and follow links. RLS is on with no policies.';


/* ── 5. Guard: refuses a login email or profile email that another account already uses.
          Compares case-insensitively and ignores surrounding spaces. Only fires when the
          email itself changes, so existing duplicates never block logins or profile edits. ─ */
create or replace function public.nghs_block_duplicate_email() returns trigger language plpgsql security definer set search_path = '' as $dup$
declare
  v_key   text := lower(btrim(coalesce(new.email, '')));
  v_taken boolean;
begin
  if v_key = '' then
    return new;
  end if;
  if TG_OP = 'UPDATE' and lower(btrim(coalesce(old.email, ''))) = v_key then
    return new;
  end if;
  v_taken := exists (select 1 from auth.users u where u.id <> new.id and lower(btrim(coalesce(u.email, ''))) = v_key)
          or exists (select 1 from public.verified_profiles p where p.id <> new.id and lower(btrim(coalesce(p.email, ''))) = v_key);
  if v_taken then
    raise exception 'NGHSIANS: this email already belongs to another account.' using errcode = 'unique_violation', hint = 'Log in with the account that already uses this email.';
  end if;
  return new;
end;
$dup$;
drop trigger if exists nghs_block_duplicate_email on auth.users;
create trigger nghs_block_duplicate_email before insert or update of email on auth.users for each row execute function public.nghs_block_duplicate_email();
drop trigger if exists nghs_block_duplicate_email on public.verified_profiles;
create trigger nghs_block_duplicate_email before insert or update of email on public.verified_profiles for each row execute function public.nghs_block_duplicate_email();


/* ── 6. Lock: no two profiles may share a (case-insensitive) email.
          FAILS while any duplicate is left. Run it again after the terminate file
          and after every REVIEW group has been resolved. ─────────────────────── */
create unique index if not exists verified_profiles_email_unique on public.verified_profiles (lower(btrim(email))) where nullif(btrim(email), '') is not null;


/* ── 7. Optional, when you are finished: the helper is no longer needed.
          drop function if exists public.nghs_duplicate_plan();   (keep the audit table) ── */
