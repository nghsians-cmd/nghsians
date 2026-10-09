/* ============================================================================
   NGHSIANS — TERMINATE THE OLDER DUPLICATE ACCOUNTS   ⚠  THIS DELETES ACCOUNTS
   Updated: 2026-10-08

   RUN THIS ONLY AFTER reading the preview (section 2 of supabase-dedupe-accounts.sql)
   and checking that every TERMINATE row is an account you expect to remove.
   It needs supabase-dedupe-accounts.sql to have been run first (it creates the
   helper function public.nghs_duplicate_plan() and the audit table).

   WHAT IT REMOVES — only the accounts marked TERMINATE by the preview
     1. their follow links (public.user_relationships)
     2. their profile row (public.verified_profiles)
     3. their login account (auth.users)
   Before anything is deleted, a copy of each profile and its follow links is
   saved to public.account_dedupe_audit. KEEP and REVIEW accounts are never touched.

   SAFE TO RE-RUN: it only handles accounts that are not yet marked terminated.

   HOW TO RUN: paste this WHOLE file → "Run without RLS". The result panel shows
   the audit rows. If a statement fails, stop: nothing after it ran, and the
   audit table shows what is still pending (terminated_at is empty).
   ============================================================================ */


/* ── T1. Audit table (same definition as supabase-dedupe-accounts.sql, section 4) ─ */
create table if not exists public.account_dedupe_audit (id bigint generated always as identity primary key, user_id uuid not null unique, kept_user_id uuid, group_key text, decision text, reason text, login_email text, profile_email text, username text, role text, batch_year text, follower_count int, auth_created_at timestamp with time zone, planned_at timestamp with time zone default timezone('utc'::text, now()) not null, terminated_at timestamp with time zone, profile_snapshot jsonb, relationships_snapshot jsonb);
alter table if exists public.account_dedupe_audit enable row level security;
revoke all on public.account_dedupe_audit from anon, authenticated;


/* ── T2. Record the TERMINATE accounts and save their profile + follow links BEFORE deleting ── */
insert into public.account_dedupe_audit (user_id, kept_user_id, group_key, decision, reason, login_email, profile_email, username, role, batch_year, follower_count, auth_created_at, profile_snapshot, relationships_snapshot) select d.user_id, d.kept_user_id, d.group_key, d.decision, d.reason, d.login_email, d.profile_email, d.username, d.role, d.batch_year, d.follower_count, d.auth_created_at, (select to_jsonb(p) from public.verified_profiles p where p.id = d.user_id), (select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) from public.user_relationships r where r.follower_id = d.user_id or r.following_id = d.user_id) from public.nghs_duplicate_plan() d where d.decision = 'TERMINATE' on conflict (user_id) do nothing;


/* ── T3. Delete the follow links of the pending accounts (both directions) ─────── */
delete from public.user_relationships r where exists (select 1 from public.account_dedupe_audit a where a.terminated_at is null and (a.user_id = r.follower_id or a.user_id = r.following_id));


/* ── T4. Delete their profile rows ─────────────────────────────────────────────── */
delete from public.verified_profiles p where exists (select 1 from public.account_dedupe_audit a where a.terminated_at is null and a.user_id = p.id);


/* ── T5. Delete their login accounts (sessions and identities go with them) ───── */
delete from auth.users u where exists (select 1 from public.account_dedupe_audit a where a.terminated_at is null and a.user_id = u.id);


/* ── T6. Mark the accounts that are now gone ───────────────────────────────────── */
update public.account_dedupe_audit a set terminated_at = timezone('utc'::text, now()) where a.terminated_at is null and not exists (select 1 from auth.users u where u.id = a.user_id);


/* ── T7. Result: every account this file has terminated, newest run first ─────── */
select id, user_id, kept_user_id, login_email, profile_email, username, role, reason, planned_at, terminated_at from public.account_dedupe_audit order by id;
