/* ============================================================================
   NGHSIANS — NEWSLETTER → ACCOUNT MERGE  (idempotent / safe to re-run)
   Added: 2026-10-12

   WHAT THIS DOES
     The standalone Newsletter (MailerLite embed) is retired. The newsletter is
     now just a flag on the account, so the account IS the subscriber list:

       • 3 new columns on verified_profiles (opt-in, notice-seen, unsubscribe)
       • a newsletter_contacts table for imported MailerLite subscribers who
         have no NGHSIANS account yet
       • a newsletter_tokens table (no client access) holding the secret
         unsubscribe token — it deliberately does NOT live on
         verified_profiles, because that table is readable by the anon key
       • newsletter_subscribers — the one view the mailer reads (locked down:
         anon / authenticated cannot read it, only the admin RPC below)
       • newsletter_unsubscribe(token) — the link in the email footer
       • newsletter_admin_list(pin) / newsletter_admin_log / newsletter_admin_*
         — everything mailer.html needs, all admin-checked
       • a one-time backfill that ENROLS every current account holder

   WHY EVERY STATEMENT IS ON ITS OWN LINE
     Supabase's "Potential issues detected" dialog ("Run and enable RLS")
     rewrites the script line by line, and that rewrite can cut a multi-line
     CREATE TABLE in half. Nothing here spans more than one line except the
     function bodies ($fn$ … $fn$), which is the same shape the other schema
     files in this repo use.

   IF THAT DIALOG APPEARS: press "Run without RLS". This file enables RLS and
   creates every policy itself.

   HOW TO RUN
     Supabase Dashboard → SQL Editor → New query → paste this whole file → Run.
     Safe on a live site: nothing is dropped, no data is deleted, and every
     statement skips itself when it is already applied.

   AFTER RUNNING
     • Change the mailer PIN: select * from public.app_secrets; then
       update public.app_secrets set value='<new pin>' where key='mailer_pin';
   ============================================================================ */


/* ── 1. New columns on 'verified_profiles' ─────────────────────────────────── */
alter table if exists public.verified_profiles add column if not exists newsletter_opt_in boolean default false;
alter table if exists public.verified_profiles add column if not exists newsletter_notified boolean default false;
alter table if exists public.verified_profiles add column if not exists newsletter_opt_in_at timestamp with time zone;
alter table if exists public.verified_profiles add column if not exists newsletter_source text;
alter table if exists public.verified_profiles add column if not exists newsletter_unsubscribed_at timestamp with time zone;
comment on column public.verified_profiles.newsletter_opt_in is 'true = wants NGHSIANS news on this account email';
comment on column public.verified_profiles.newsletter_notified is 'true = the one-time "you will start receiving news" notice has been acknowledged';
comment on column public.verified_profiles.newsletter_source is 'how they joined: signup | notice | profile | legacy-account | import';


/* ── 2. BACKFILL — enrol every current account holder ─────────────────────────
      Everyone who already has an NGHSIANS account is subscribed as of now.
      newsletter_notified stays FALSE on purpose: that is what triggers the
      one-time "you will start receiving news…" popup on their next visit to
      account.html. Anyone who had already unsubscribed is left alone.        */
update public.verified_profiles set newsletter_opt_in = true, newsletter_opt_in_at = coalesce(newsletter_opt_in_at, now()), newsletter_source = coalesce(newsletter_source, 'legacy-account') where email is not null and newsletter_unsubscribed_at is null and coalesce(newsletter_opt_in, false) = false;


/* ── 3. Unsubscribe tokens — kept OFF verified_profiles on purpose ────────────
      verified_profiles is readable by the anon key (the network page needs
      it), so a token column there would let anyone unsubscribe anyone. This
      table has no client-readable policy at all: only the security-definer
      functions below can see it.                                            */
create table if not exists public.newsletter_tokens (profile_id uuid primary key references public.verified_profiles (id) on delete cascade, token uuid not null default gen_random_uuid() unique, created_at timestamp with time zone default timezone('utc'::text, now()) not null);
alter table if exists public.newsletter_tokens enable row level security;
drop policy if exists "No client access to unsubscribe tokens." on public.newsletter_tokens;
create policy "No client access to unsubscribe tokens." on public.newsletter_tokens for select using ( false );
create unique index if not exists newsletter_tokens_token_idx on public.newsletter_tokens (token);
insert into public.newsletter_tokens (profile_id) select id from public.verified_profiles on conflict (profile_id) do nothing;
create or replace function public.newsletter_ensure_token() returns trigger language plpgsql security definer set search_path = public as $tk$ begin insert into public.newsletter_tokens (profile_id) values (new.id) on conflict (profile_id) do nothing; return new; end; $tk$;
drop trigger if exists on_profile_created_newsletter_token on public.verified_profiles;
create trigger on_profile_created_newsletter_token after insert on public.verified_profiles for each row execute function public.newsletter_ensure_token();


/* ── 4. Imported contacts (MailerLite subscribers with no account) ────────────
      These people are not members, so they have no row in verified_profiles.
      They still get the newsletter until they unsubscribe.                   */
create table if not exists public.newsletter_contacts (id uuid default gen_random_uuid() primary key, email text not null unique, name text, batch_year text, phone text, source text default 'mailerlite-import', unsub_token uuid not null default gen_random_uuid(), unsubscribed_at timestamp with time zone, created_at timestamp with time zone default timezone('utc'::text, now()) not null);
alter table if exists public.newsletter_contacts enable row level security;
drop policy if exists "No client access to newsletter contacts." on public.newsletter_contacts;
create policy "No client access to newsletter contacts." on public.newsletter_contacts for select using ( false );
create unique index if not exists newsletter_contacts_unsub_token_idx on public.newsletter_contacts (unsub_token);


/* ── 5. Send log — history for mailer.html ────────────────────────────────── */
create table if not exists public.newsletter_send_log (id uuid default gen_random_uuid() primary key, subject text, preview_text text, body_html text, recipient_count int default 0, sent_by text, status text default 'sent', created_at timestamp with time zone default timezone('utc'::text, now()) not null);
alter table if exists public.newsletter_send_log enable row level security;
drop policy if exists "No client access to the send log." on public.newsletter_send_log;
create policy "No client access to the send log." on public.newsletter_send_log for select using ( false );


/* ── 6. Secret store — the mailer PIN lives here, not in the HTML ─────────── */
create table if not exists public.app_secrets (key text primary key, value text not null, updated_at timestamp with time zone default timezone('utc'::text, now()) not null);
alter table if exists public.app_secrets enable row level security;
drop policy if exists "No client access to app secrets." on public.app_secrets;
create policy "No client access to app secrets." on public.app_secrets for select using ( false );
insert into public.app_secrets (key, value) values ('mailer_pin', '602760') on conflict (key) do nothing;


/* ── 7. The subscriber list — a view, but NOT readable by the anon key ───────
      verified_profiles is public-readable today, so a plain view here would
      hand the whole mailing list to anyone with the anon key. The REVOKE
      below is the important line: mailer.html reads this through the
      newsletter_admin_list() RPC instead, which checks the admin + PIN.      */
drop view if exists public.newsletter_subscribers;
create view public.newsletter_subscribers with (security_invoker = true) as select p.id, p.email, p.username as name, p.batch_year, p.school_id, 'account'::text as kind, p.newsletter_source as source, p.newsletter_opt_in_at as subscribed_at, t.token as unsub_token, p.created_at from public.verified_profiles p left join public.newsletter_tokens t on t.profile_id = p.id where coalesce(p.newsletter_opt_in, false) = true and p.newsletter_unsubscribed_at is null and p.email is not null and p.email <> '';
revoke all on public.newsletter_subscribers from anon, authenticated;
grant select on public.newsletter_subscribers to service_role;
create or replace view public.newsletter_contacts_view with (security_invoker = true) as select id, email, name, batch_year, null::text as school_id, 'contact'::text as kind, source, created_at as subscribed_at, unsub_token, created_at from public.newsletter_contacts where unsubscribed_at is null and email is not null and email <> '';
revoke all on public.newsletter_contacts_view from anon, authenticated;
grant select on public.newsletter_contacts_view to service_role;


/* ── 8. Admin check — reused by every function below ────────────────────────
      Edit this list if the admin team changes. It is the same list as
      ADMIN_EMAILS in account.html.                                            */
create or replace function public.newsletter_is_admin() returns boolean language sql stable security definer set search_path = public as $fn$
  select coalesce((nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email'), '') = any (array['nghsians@gmail.com', 'umairhoquechowdhury13@gmail.com']);
$fn$;
revoke all on function public.newsletter_is_admin() from public;
grant execute on function public.newsletter_is_admin() to anon, authenticated, service_role;


/* ── 9. PIN check — the mailer PIN from app_secrets ───────────────────────── */
create or replace function public.newsletter_check_pin(p_pin text) returns boolean language plpgsql stable security definer set search_path = public as $fn$
declare ok boolean;
begin
  select value = nullif(trim(coalesce(p_pin, '')), '') into ok from public.app_secrets where key = 'mailer_pin';
  return coalesce(ok, false);
end;
$fn$;
revoke all on function public.newsletter_check_pin(text) from public;
grant execute on function public.newsletter_check_pin(text) to anon, authenticated, service_role;


/* ── 10. Admin: read the full subscriber list ──────────────────────────────── */
create or replace function public.newsletter_admin_list(p_pin text) returns table (id uuid, email text, name text, batch_year text, school_id text, kind text, source text, subscribed_at timestamp with time zone, unsub_token uuid) language plpgsql security definer set search_path = public as $fn$
begin
  if not public.newsletter_is_admin() then raise exception 'Not authorised.'; end if;
  if not public.newsletter_check_pin(p_pin) then raise exception 'Wrong PIN.'; end if;
  return query
    select v.id, v.email, v.name, v.batch_year, v.school_id, v.kind, v.source, v.subscribed_at, v.unsub_token
      from public.newsletter_subscribers v
    union all
    select c.id, c.email, c.name, c.batch_year, c.school_id, c.kind, c.source, c.subscribed_at, c.unsub_token
      from public.newsletter_contacts_view c
     order by 2;
end;
$fn$;
revoke all on function public.newsletter_admin_list(text) from public;
grant execute on function public.newsletter_admin_list(text) to anon, authenticated, service_role;


/* ── 11. Admin: stats for the mailer dashboard ────────────────────────────── */
create or replace function public.newsletter_admin_stats(p_pin text) returns json language plpgsql security definer set search_path = public as $fn$
declare result json;
begin
  if not public.newsletter_is_admin() then raise exception 'Not authorised.'; end if;
  if not public.newsletter_check_pin(p_pin) then raise exception 'Wrong PIN.'; end if;
  select json_build_object(
    'accounts',  (select count(*) from public.newsletter_subscribers where kind = 'account'),
    'contacts',  (select count(*) from public.newsletter_contacts_view),
    'total',     (select count(*) from public.newsletter_subscribers) + (select count(*) from public.newsletter_contacts_view),
    'opted_out', (select count(*) from public.verified_profiles where coalesce(newsletter_opt_in, false) = false or newsletter_unsubscribed_at is not null),
    'last_send', (select to_char(max(created_at), 'YYYY-MM-DD HH24:MI') from public.newsletter_send_log)
  ) into result;
  return result;
end;
$fn$;
revoke all on function public.newsletter_admin_stats(text) from public;
grant execute on function public.newsletter_admin_stats(text) to anon, authenticated, service_role;


/* ── 12. Admin: write the send log ────────────────────────────────────────── */
create or replace function public.newsletter_admin_log(p_pin text, p_subject text, p_preview text, p_body text, p_count int) returns uuid language plpgsql security definer set search_path = public as $fn$
declare new_id uuid;
begin
  if not public.newsletter_is_admin() then raise exception 'Not authorised.'; end if;
  if not public.newsletter_check_pin(p_pin) then raise exception 'Wrong PIN.'; end if;
  insert into public.newsletter_send_log (subject, preview_text, body_html, recipient_count, sent_by, status)
  values (p_subject, p_preview, p_body, coalesce(p_count, 0), coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email', 'admin'), 'sent')
  returning id into new_id;
  return new_id;
end;
$fn$;
revoke all on function public.newsletter_admin_log(text, text, text, text, int) from public;
grant execute on function public.newsletter_admin_log(text, text, text, text, int) to anon, authenticated, service_role;


/* ── 13. Admin: read the send log ─────────────────────────────────────────── */
create or replace function public.newsletter_admin_history(p_pin text, p_limit int default 20) returns table (id uuid, subject text, recipient_count int, sent_by text, status text, created_at timestamp with time zone) language plpgsql security definer set search_path = public as $fn$
begin
  if not public.newsletter_is_admin() then raise exception 'Not authorised.'; end if;
  if not public.newsletter_check_pin(p_pin) then raise exception 'Wrong PIN.'; end if;
  return query select l.id, l.subject, l.recipient_count, l.sent_by, l.status, l.created_at from public.newsletter_send_log l order by l.created_at desc limit greatest(coalesce(p_limit, 20), 1);
end;
$fn$;
revoke all on function public.newsletter_admin_history(text, int) from public;
grant execute on function public.newsletter_admin_history(text, int) to anon, authenticated, service_role;


/* ── 14. Admin: import MailerLite subscribers (skips duplicates) ────────────
      Paste a MailerLite export here. Anyone whose email already has an
      account gets newsletter_opt_in = true on that account; everyone else is
      inserted into newsletter_contacts.                                       */
create or replace function public.newsletter_admin_import(p_pin text, p_rows json) returns json language plpgsql security definer set search_path = public as $fn$
declare r json; v_email text; v_name text; v_batch text; matched int := 0; inserted int := 0; skipped int := 0;
begin
  if not public.newsletter_is_admin() then raise exception 'Not authorised.'; end if;
  if not public.newsletter_check_pin(p_pin) then raise exception 'Wrong PIN.'; end if;
  for r in select * from json_array_elements(coalesce(p_rows, '[]'::json)) loop
    v_email := lower(trim(coalesce(r ->> 'email', '')));
    v_name  := nullif(trim(coalesce(r ->> 'name', '')), '');
    v_batch := nullif(trim(coalesce(r ->> 'batch_year', r ->> 'batch', '')), '');
    if v_email = '' or v_email not like '%@%' then skipped := skipped + 1; continue; end if;
    update public.verified_profiles
       set newsletter_opt_in = true,
           newsletter_opt_in_at = coalesce(newsletter_opt_in_at, now()),
           newsletter_source = coalesce(newsletter_source, 'import')
     where lower(email) = v_email and newsletter_unsubscribed_at is null;
    if found then matched := matched + 1;
    else
      insert into public.newsletter_contacts (email, name, batch_year, source)
      values (v_email, v_name, v_batch, 'mailerlite-import')
      on conflict (email) do nothing;
      if found then inserted := inserted + 1; else skipped := skipped + 1; end if;
    end if;
  end loop;
  return json_build_object('matched_accounts', matched, 'contacts_added', inserted, 'skipped', skipped);
end;
$fn$;
revoke all on function public.newsletter_admin_import(text, json) from public;
grant execute on function public.newsletter_admin_import(text, json) to anon, authenticated, service_role;


/* ── 15. PUBLIC: unsubscribe from the email footer link ─────────────────────
      This one is callable by ANYONE (anon) — that is the point: the person
      clicking the link in their inbox is not signed in. The token is a random
      UUID that only ever appears in that email, so it cannot be guessed.     */
create or replace function public.newsletter_unsubscribe(p_token text) returns boolean language plpgsql security definer set search_path = public as $fn$
declare tok uuid; done boolean := false;
begin
  begin tok := nullif(trim(coalesce(p_token, '')), '')::uuid; exception when others then return false; end;
  if tok is null then return false; end if;
  update public.verified_profiles set newsletter_opt_in = false, newsletter_unsubscribed_at = now(), newsletter_notified = true where id = (select profile_id from public.newsletter_tokens where token = tok);
  if found then done := true; end if;
  update public.newsletter_contacts set unsubscribed_at = now() where unsub_token = tok;
  if found then done := true; end if;
  return done;
end;
$fn$;
revoke all on function public.newsletter_unsubscribe(text) from public;
grant execute on function public.newsletter_unsubscribe(text) to anon, authenticated, service_role;


/* ── 16. PUBLIC: re-subscribe with the same token (undo an accidental click) ─ */
create or replace function public.newsletter_resubscribe(p_token text) returns boolean language plpgsql security definer set search_path = public as $fn$
declare tok uuid; done boolean := false;
begin
  begin tok := nullif(trim(coalesce(p_token, '')), '')::uuid; exception when others then return false; end;
  if tok is null then return false; end if;
  update public.verified_profiles set newsletter_opt_in = true, newsletter_unsubscribed_at = null, newsletter_opt_in_at = now(), newsletter_source = coalesce(newsletter_source, 'resubscribe') where id = (select profile_id from public.newsletter_tokens where token = tok);
  if found then done := true; end if;
  update public.newsletter_contacts set unsubscribed_at = null where unsub_token = tok;
  if found then done := true; end if;
  return done;
end;
$fn$;
revoke all on function public.newsletter_resubscribe(text) from public;
grant execute on function public.newsletter_resubscribe(text) to anon, authenticated, service_role;


/* ── 17. VERIFY (optional) ──────────────────────────────────────────────────
   select count(*) from public.newsletter_subscribers;                        -- accounts opted in
   select count(*) from public.newsletter_contacts where unsubscribed_at is null;  -- imported contacts
   select count(*) from public.newsletter_tokens;                              -- unsubscribe tokens issued
   select newsletter_opt_in, newsletter_notified, newsletter_source, count(*)
     from public.verified_profiles group by 1, 2, 3 order by 4 desc;
   ─────────────────────────────────────────────────────────────────────────── */


/* ── 18. ROLLBACK — only if you want to undo the whole merge ────────────────
   drop function if exists public.newsletter_resubscribe(text);
   drop function if exists public.newsletter_unsubscribe(text);
   drop function if exists public.newsletter_admin_import(text, json);
   drop function if exists public.newsletter_admin_history(text, int);
   drop function if exists public.newsletter_admin_log(text, text, text, text, int);
   drop function if exists public.newsletter_admin_stats(text);
   drop function if exists public.newsletter_admin_list(text);
   drop function if exists public.newsletter_check_pin(text);
   drop function if exists public.newsletter_is_admin();
   drop view if exists public.newsletter_contacts_view;
   drop view if exists public.newsletter_subscribers;
   drop trigger if exists on_profile_created_newsletter_token on public.verified_profiles;
   drop function if exists public.newsletter_ensure_token();
   drop table if exists public.newsletter_tokens;
   drop table if exists public.newsletter_send_log;
   drop table if exists public.newsletter_contacts;
   alter table public.verified_profiles drop column if exists newsletter_unsubscribed_at;
   alter table public.verified_profiles drop column if exists newsletter_source;
   alter table public.verified_profiles drop column if exists newsletter_opt_in_at;
   alter table public.verified_profiles drop column if exists newsletter_notified;
   alter table public.verified_profiles drop column if exists newsletter_opt_in;
   ─────────────────────────────────────────────────────────────────────────── */
