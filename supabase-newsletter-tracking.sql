/* ============================================================================
   NGHSIANS — newsletter email-status tracking (safe to re-run)

   Adds per-recipient status for every campaign send so the mailer can show,
   for each email you send: Sent · Received (delivered) · Opened · Link opened.

   Nothing here touches subscriber data. The table has NO client-readable
   policy — only the security-definer RPCs below can read or write it, exactly
   like newsletter_send_log.

   Run in Supabase → SQL Editor → New query → paste → Run.
   ============================================================================ */

/* ---- per-recipient status for each send ---------------------------------- */
create table if not exists public.newsletter_send_recipients (
  id          bigserial primary key,
  send_id     uuid not null references public.newsletter_send_log(id) on delete cascade,
  email       text not null,
  token       uuid not null default gen_random_uuid(),
  sent_at     timestamptz,
  delivered_at timestamptz,
  opened_at   timestamptz,
  clicked_at  timestamptz,
  created_at  timestamptz not null default timezone('utc', now())
);
create unique index if not exists newsletter_send_recipients_token_idx
  on public.newsletter_send_recipients(token);
create index if not exists newsletter_send_recipients_send_idx
  on public.newsletter_send_recipients(send_id);
create index if not exists newsletter_send_recipients_email_idx
  on public.newsletter_send_recipients(email);
alter table if exists public.newsletter_send_recipients enable row level security;
drop policy if exists "No client access to recipient status." on public.newsletter_send_recipients;
create policy "No client access to recipient status." on public.newsletter_send_recipients
  for all using (false) with check (false);

/* ---- record a send + one row per recipient, return per-email tokens ------ */
create or replace function public.newsletter_admin_record_send(
  p_pin text, p_subject text, p_preview text, p_body text, p_sent_by text, p_recipients jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_ok boolean; v_send_id uuid; v_tokens jsonb := '{}'::jsonb; r record; v_token uuid;
  v_count int := 0;
begin
  select public.newsletter_check_pin(p_pin) into v_ok;
  if not v_ok then raise exception 'Wrong PIN.'; end if;
  if not public.newsletter_is_admin() then raise exception 'Not authorised.'; end if;
  v_count := jsonb_array_length(coalesce(p_recipients, '[]'::jsonb));
  insert into public.newsletter_send_log
    (subject, preview_text, body_html, recipient_count, sent_by, status)
  values (p_subject, p_preview, p_body, v_count, p_sent_by, 'sent')
  returning id into v_send_id;
  for r in select value from jsonb_array_elements(coalesce(p_recipients, '[]'::jsonb)) loop
    insert into public.newsletter_send_recipients (send_id, email, sent_at)
      values (v_send_id, lower(r.value->>'email'), now())
      returning token into v_token;
    v_tokens := jsonb_set(v_tokens, array[lower(r.value->>'email')], to_jsonb(v_token::text));
  end loop;
  return jsonb_build_object('send_id', v_send_id, 'tokens', v_tokens);
end; $fn$;
revoke all on function public.newsletter_admin_record_send(text, text, text, text, text, jsonb) from public;
grant execute on function public.newsletter_admin_record_send(text, text, text, text, text, jsonb) to anon, authenticated, service_role;

/* ---- record an open / click / delivered event (public endpoint) ---------- */
create or replace function public.newsletter_record_event(p_token uuid, p_event text)
returns void language plpgsql security definer set search_path = public as $fn$
begin
  if p_event = 'opened' then
    update public.newsletter_send_recipients set opened_at = coalesce(opened_at, now()) where token = p_token;
  elsif p_event = 'clicked' then
    update public.newsletter_send_recipients set clicked_at = coalesce(clicked_at, now()) where token = p_token;
  elsif p_event = 'delivered' then
    update public.newsletter_send_recipients set delivered_at = coalesce(delivered_at, now()) where token = p_token;
  end if;
end; $fn$;
revoke all on function public.newsletter_record_event(uuid, text) from public;
grant execute on function public.newsletter_record_event(uuid, text) to anon, authenticated, service_role;

/* ---- per-send status summary for the mailer ------------------------------ */
create or replace function public.newsletter_admin_send_status(p_pin text)
returns table(
  id uuid, subject text, recipient_count int, sent int, received int, opened int, clicked int, created_at timestamptz
) language plpgsql security definer set search_path = public as $fn$
declare v_ok boolean;
begin
  select public.newsletter_check_pin(p_pin) into v_ok;
  if not v_ok then raise exception 'Wrong PIN.'; end if;
  if not public.newsletter_is_admin() then raise exception 'Not authorised.'; end if;
  return query
  select l.id, l.subject,
    count(r.id)::int as recipient_count,
    count(r.sent_at)::int as sent,
    count(r.delivered_at)::int as received,
    count(r.opened_at)::int as opened,
    count(r.clicked_at)::int as clicked,
    l.created_at
  from public.newsletter_send_log l
  left join public.newsletter_send_recipients r on r.send_id = l.id
  group by l.id, l.subject, l.created_at
  order by l.created_at desc
  limit 50;
end; $fn$;
revoke all on function public.newsletter_admin_send_status(text) from public;
grant execute on function public.newsletter_admin_send_status(text) to anon, authenticated, service_role;

/* ---- per-recipient detail for one send ----------------------------------- */
create or replace function public.newsletter_admin_send_detail(p_pin text, p_send_id uuid)
returns table(email text, sent_at timestamptz, delivered_at timestamptz, opened_at timestamptz, clicked_at timestamptz)
language plpgsql security definer set search_path = public as $fn$
declare v_ok boolean;
begin
  select public.newsletter_check_pin(p_pin) into v_ok;
  if not v_ok then raise exception 'Wrong PIN.'; end if;
  if not public.newsletter_is_admin() then raise exception 'Not authorised.'; end if;
  return query
  select r.email, r.sent_at, r.delivered_at, r.opened_at, r.clicked_at
  from public.newsletter_send_recipients r
  where r.send_id = p_send_id
  order by r.email;
end; $fn$;
revoke all on function public.newsletter_admin_send_detail(text, uuid) from public;
grant execute on function public.newsletter_admin_send_detail(text, uuid) to anon, authenticated, service_role;

/* ---- mark delivered/bounced for the latest send to an address (webhook) ---- */
create or replace function public.newsletter_record_event_by_email(p_email text, p_event text)
returns void language plpgsql security definer set search_path = public as $fn$
begin
  if p_event = 'delivered' then
    update public.newsletter_send_recipients r
      set delivered_at = coalesce(r.delivered_at, now())
      where r.email = lower(p_email)
        and r.delivered_at is null
        and r.send_id = (select max(send_id) from public.newsletter_send_recipients where email = lower(p_email));
  elsif p_event = 'bounced' then
    update public.newsletter_send_recipients r
      set delivered_at = null
      where r.email = lower(p_email)
        and r.send_id = (select max(send_id) from public.newsletter_send_recipients where email = lower(p_email));
  end if;
end; $fn$;
revoke all on function public.newsletter_record_event_by_email(text, text) from public;
grant execute on function public.newsletter_record_event_by_email(text, text) to service_role;
