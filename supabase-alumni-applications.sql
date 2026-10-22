/* ============================================================================
   NGHSIANS — ALUMNI INTERFACE APPLICATIONS
   Safe to run more than once. This migration creates:
     • alumni_application_settings: one editable eligibility/auto-approval row
     • alumni_applications: private account-linked drafts + reviewable submissions
     • alumni_directory: a public, approved-only view with no contact details

   Initial policy: batches through 2025 are approved automatically; 2026 is
   pending manual review; later batches are rejected. To change this next year,
   edit the one settings row (example at the end of this file).

   Supabase Dashboard → SQL Editor → New query → paste → Run.
   ============================================================================ */

create table if not exists public.alumni_application_settings (setting_key text primary key default 'default' check (setting_key = 'default'), max_eligible_batch integer not null default 2026 check (max_eligible_batch between 1900 and 2100), auto_approve_through_batch integer not null default 2025 check (auto_approve_through_batch between 1900 and 2100 and auto_approve_through_batch <= max_eligible_batch), updated_at timestamp with time zone not null default timezone('utc'::text, now()));
insert into public.alumni_application_settings (setting_key, max_eligible_batch, auto_approve_through_batch) values ('default', 2026, 2025) on conflict (setting_key) do nothing;
alter table public.alumni_application_settings enable row level security;
drop policy if exists "Anyone can read alumni eligibility settings" on public.alumni_application_settings;
create policy "Anyone can read alumni eligibility settings" on public.alumni_application_settings for select to anon, authenticated using (true);
revoke all on public.alumni_application_settings from anon;
grant select on public.alumni_application_settings to anon, authenticated;


/* ── Legacy roster sync ────────────────────────────────────────────────────
   Snapshot of the 43 cards currently published in alumnis.html. This private
   lookup lets PostgreSQL match a profile at account creation/update time, and
   backfills existing account holders. Keep this table in sync if you manually
   add/remove a legacy card in the static alumni directory. New applications
   are handled by alumni_applications and do not need to be added here.        */
create or replace function public.alumni_name_match_key(p_name text) returns text language sql immutable parallel safe as $alumni_name_key$
  select translate(regexp_replace(lower(btrim(coalesce(p_name, ''))), '[[:space:]]+', '', 'g'), '.,-/()''_', '');
$alumni_name_key$;
create table if not exists public.alumni_legacy_roster (full_name text not null, batch_year smallint not null, normalized_name text not null, constraint alumni_legacy_roster_batch_check check (batch_year between 1000 and 9999), constraint alumni_legacy_roster_name_batch_key unique (normalized_name, batch_year));
alter table public.alumni_legacy_roster enable row level security;
revoke all on table public.alumni_legacy_roster from anon, authenticated;
comment on table public.alumni_legacy_roster is 'Internal matching snapshot of existing alumnis.html cards. Read by the SECURITY DEFINER profile-matching trigger; never exposed to the public API.';
insert into public.alumni_legacy_roster (full_name, batch_year, normalized_name) values
  ('Umair Hoque Chowdhury', 2025, public.alumni_name_match_key('Umair Hoque Chowdhury')),
  ('Mohammad Emaz Uddin', 2016, public.alumni_name_match_key('Mohammad Emaz Uddin')),
  ('Khondaker Manirul Alam', 2010, public.alumni_name_match_key('Khondaker Manirul Alam')),
  ('Shiek Sayam', 2018, public.alumni_name_match_key('Shiek Sayam')),
  ('KM Ishmam Morshed', 2020, public.alumni_name_match_key('KM Ishmam Morshed')),
  ('Jawad Bin Ahmed', 2024, public.alumni_name_match_key('Jawad Bin Ahmed')),
  ('Junayed Habibullah Mezbah', 2025, public.alumni_name_match_key('Junayed Habibullah Mezbah')),
  ('Meheraz Azfar Chowdhury', 2025, public.alumni_name_match_key('Meheraz Azfar Chowdhury')),
  ('Inkiad Tahsin Tasnif', 2024, public.alumni_name_match_key('Inkiad Tahsin Tasnif')),
  ('Maain Bin Selim', 2025, public.alumni_name_match_key('Maain Bin Selim')),
  ('Mojahid Hasan Ador', 2025, public.alumni_name_match_key('Mojahid Hasan Ador')),
  ('Biprajit Bhowmick', 2025, public.alumni_name_match_key('Biprajit Bhowmick')),
  ('Subornaw Saha', 2020, public.alumni_name_match_key('Subornaw Saha')),
  ('Deen Mohammad Tanjim', 2020, public.alumni_name_match_key('Deen Mohammad Tanjim')),
  ('Anup Kamal Dipta', 2020, public.alumni_name_match_key('Anup Kamal Dipta')),
  ('সাগরময় সেনগুপ্ত', 2014, public.alumni_name_match_key('সাগরময় সেনগুপ্ত')),
  ('Md. Hasibur Rahman', 2021, public.alumni_name_match_key('Md. Hasibur Rahman')),
  ('Mushfiqur Rahman', 2019, public.alumni_name_match_key('Mushfiqur Rahman')),
  ('Md Shadman Sayem', 2025, public.alumni_name_match_key('Md Shadman Sayem')),
  ('Atul Barua', 2025, public.alumni_name_match_key('Atul Barua')),
  ('Md. Tawasir Ul Islam Tasin', 2020, public.alumni_name_match_key('Md. Tawasir Ul Islam Tasin')),
  ('Ahsan Jamil', 2024, public.alumni_name_match_key('Ahsan Jamil')),
  ('Shresthangshu Chowdhury', 2025, public.alumni_name_match_key('Shresthangshu Chowdhury')),
  ('Md Irfan Hossain', 2015, public.alumni_name_match_key('Md Irfan Hossain')),
  ('ইন্তেখাব আহমেদ সিয়াম', 2025, public.alumni_name_match_key('ইন্তেখাব আহমেদ সিয়াম')),
  ('Nafis Imtiaj', 2020, public.alumni_name_match_key('Nafis Imtiaj')),
  ('Faisal Ahmed Sabuj', 2010, public.alumni_name_match_key('Faisal Ahmed Sabuj')),
  ('Tanvirul Islam Niloy', 2017, public.alumni_name_match_key('Tanvirul Islam Niloy')),
  ('Shirajul Islam', 2008, public.alumni_name_match_key('Shirajul Islam')),
  ('Md Ibnul Inan Chowdhury', 2017, public.alumni_name_match_key('Md Ibnul Inan Chowdhury')),
  ('Mugdho Dey', 2022, public.alumni_name_match_key('Mugdho Dey')),
  ('Iftekhar Alam', 2012, public.alumni_name_match_key('Iftekhar Alam')),
  ('Ashraful Islam', 2012, public.alumni_name_match_key('Ashraful Islam')),
  ('Safayet Hossain', 2020, public.alumni_name_match_key('Safayet Hossain')),
  ('Md Rishad Hossain', 2019, public.alumni_name_match_key('Md Rishad Hossain')),
  ('Kazi Nahin Munkar', 2025, public.alumni_name_match_key('Kazi Nahin Munkar')),
  ('Anik Paul', 2024, public.alumni_name_match_key('Anik Paul')),
  ('Sirajum Monir Chyan', 2018, public.alumni_name_match_key('Sirajum Monir Chyan')),
  ('Al Ifran Sanim', 2024, public.alumni_name_match_key('Al Ifran Sanim')),
  ('Mohammad Tazrian Taz', 2025, public.alumni_name_match_key('Mohammad Tazrian Taz')),
  ('Farhan Ahmad', 2025, public.alumni_name_match_key('Farhan Ahmad')),
  ('Mohiuddin Mottakin Rahad', 2026, public.alumni_name_match_key('Mohiuddin Mottakin Rahad')),
  ('Dr Mohammed Nuruddin Jahed', 2002, public.alumni_name_match_key('Dr Mohammed Nuruddin Jahed'))
on conflict (normalized_name, batch_year) do update set full_name = excluded.full_name;

/* The existing profile UPDATE policy lets a member update their own row. This
   trigger stops client-side self-promotion to elite/alumni/architect while
   still allowing the trusted application + legacy-match triggers below to
   grant Alumni status. Admin SQL/Table Editor updates are left untouched. */
create or replace function public.alumni_role_guard() returns trigger language plpgsql set search_path = public as $alumni_role_guard$
declare
  v_actor uuid := auth.uid();
  v_is_admin boolean := lower(coalesce(auth.jwt() ->> 'email', '')) in ('nghsians@gmail.com', 'umairhoquechowdhury13@gmail.com');
begin
  if current_user <> 'authenticated' or v_actor is null or v_is_admin then return new; end if;
  if tg_op = 'INSERT' then
    if new.id = v_actor and lower(btrim(coalesce(new.role, ''))) in ('elite', 'alumni', 'architect') then new.role := 'member'; end if;
  elsif old.id = v_actor and new.role is distinct from old.role and lower(btrim(coalesce(new.role, ''))) in ('elite', 'alumni', 'architect') then
    new.role := old.role;
  end if;
  return new;
end;
$alumni_role_guard$;
drop trigger if exists alumni_role_guard on public.verified_profiles;
create trigger alumni_role_guard before insert or update on public.verified_profiles for each row execute function public.alumni_role_guard();

create or replace function public.match_legacy_alumni_profile() returns trigger language plpgsql security definer set search_path = public as $legacy_match$
declare
  v_batch_text text := btrim(coalesce(new.batch_year, ''));
  v_batch integer;
  v_max_batch integer;
begin
  if lower(btrim(coalesce(new.role, ''))) in ('architect', '27') then return new; end if;
  if v_batch_text !~ '^[0-9]{4}$' or coalesce(nullif(btrim(coalesce(new.full_name, '')), ''), nullif(btrim(coalesce(new.username, '')), '')) is null then return new; end if;
  v_batch := v_batch_text::integer;
  select max_eligible_batch into v_max_batch from public.alumni_application_settings where setting_key = 'default';
  if v_max_batch is null or v_batch > v_max_batch then return new; end if;
  if exists (select 1 from public.alumni_legacy_roster r where r.batch_year = v_batch and (r.normalized_name = public.alumni_name_match_key(new.full_name) or r.normalized_name = public.alumni_name_match_key(new.username))) then
    new.role := 'alumni';
  end if;
  return new;
end;
$legacy_match$;
drop trigger if exists verified_profiles_legacy_alumni_match on public.verified_profiles;
create trigger verified_profiles_legacy_alumni_match before insert or update of full_name, username, batch_year, role on public.verified_profiles for each row execute function public.match_legacy_alumni_profile();

/* Existing accounts matched by full name + batch become alumni immediately.
   The trigger above takes care of every profile created or edited afterward. */
update public.verified_profiles p set role = 'alumni'
where lower(btrim(coalesce(p.role, 'member'))) not in ('architect', '27', 'alumni')
  and btrim(coalesce(p.batch_year, '')) ~ '^[0-9]{4}$'
  and exists (
    select 1 from public.alumni_legacy_roster r
    where r.batch_year::text = btrim(p.batch_year)
      and (r.normalized_name = public.alumni_name_match_key(p.full_name) or r.normalized_name = public.alumni_name_match_key(p.username))
      and r.batch_year <= (select max_eligible_batch from public.alumni_application_settings where setting_key = 'default')
  );

create table if not exists public.alumni_applications (id uuid primary key default gen_random_uuid(), user_id uuid not null unique references auth.users(id) on delete cascade, full_name text not null default '', contact_email text, batch_year smallint, phone_number text not null default '', occupation text not null default '', college_university text, blood_group text not null default '', principal_names text not null default '', why_proud text not null default '', contribution text not null default '', newsletter_subscribed boolean not null default false, agreement_accepted boolean not null default false, status text not null default 'pending', submitted_at timestamp with time zone not null default timezone('utc'::text, now()), updated_at timestamp with time zone not null default timezone('utc'::text, now()), reviewed_at timestamp with time zone, reviewed_by uuid references auth.users(id) on delete set null, review_note text, profile_role_before_approval text, profile_role_granted boolean not null default false);
alter table public.alumni_applications add column if not exists college_university text;
alter table public.alumni_applications alter column full_name set default '';
alter table public.alumni_applications alter column batch_year drop not null;
alter table public.alumni_applications alter column phone_number set default '';
alter table public.alumni_applications alter column occupation set default '';
alter table public.alumni_applications alter column blood_group set default '';
alter table public.alumni_applications alter column principal_names set default '';
alter table public.alumni_applications alter column why_proud set default '';
alter table public.alumni_applications alter column contribution set default '';
alter table public.alumni_applications alter column newsletter_subscribed set default false;
alter table public.alumni_applications alter column agreement_accepted set default false;
alter table public.alumni_applications alter column status set default 'pending';
alter table public.alumni_applications drop constraint if exists alumni_applications_batch_year_check;
alter table public.alumni_applications drop constraint if exists alumni_applications_batch_required_check;
alter table public.alumni_applications drop constraint if exists alumni_applications_status_check;
alter table public.alumni_applications drop constraint if exists alumni_applications_name_check;
alter table public.alumni_applications drop constraint if exists alumni_applications_email_check;
alter table public.alumni_applications drop constraint if exists alumni_applications_phone_check;
alter table public.alumni_applications drop constraint if exists alumni_applications_occupation_check;
alter table public.alumni_applications drop constraint if exists alumni_applications_college_university_length_check;
alter table public.alumni_applications drop constraint if exists alumni_applications_blood_check;
alter table public.alumni_applications drop constraint if exists alumni_applications_principal_check;
alter table public.alumni_applications drop constraint if exists alumni_applications_why_check;
alter table public.alumni_applications drop constraint if exists alumni_applications_contribution_check;
alter table public.alumni_applications drop constraint if exists alumni_applications_newsletter_check;
alter table public.alumni_applications drop constraint if exists alumni_applications_agreement_check;
alter table public.alumni_applications add constraint alumni_applications_batch_year_check check (batch_year is null or batch_year between 1000 and 9999);
alter table public.alumni_applications add constraint alumni_applications_batch_required_check check (status = 'draft' or batch_year is not null);
alter table public.alumni_applications add constraint alumni_applications_status_check check (status in ('draft', 'pending', 'approved', 'denied'));
alter table public.alumni_applications add constraint alumni_applications_name_check check (status = 'draft' or length(trim(full_name)) between 2 and 180);
-- NOT VALID keeps rows from the earlier rollout from blocking this upgrade if
-- contact_email was previously optional. PostgreSQL still enforces the check
-- on every new or updated row, so new final submissions must include an email.
alter table public.alumni_applications add constraint alumni_applications_email_check check (status = 'draft' or (contact_email is not null and length(trim(contact_email)) between 3 and 254 and contact_email ~* '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$')) not valid;
alter table public.alumni_applications add constraint alumni_applications_phone_check check (status = 'draft' or length(trim(phone_number)) between 5 and 40);
alter table public.alumni_applications add constraint alumni_applications_occupation_check check (status = 'draft' or length(trim(occupation)) between 1 and 120);
alter table public.alumni_applications add constraint alumni_applications_college_university_length_check check (college_university is null or length(trim(college_university)) <= 180) not valid;
alter table public.alumni_applications add constraint alumni_applications_blood_check check (status = 'draft' or length(trim(blood_group)) between 1 and 20);
alter table public.alumni_applications add constraint alumni_applications_principal_check check (status = 'draft' or length(trim(principal_names)) between 1 and 1000);
alter table public.alumni_applications add constraint alumni_applications_why_check check (status = 'draft' or length(trim(why_proud)) between 5 and 5000);
alter table public.alumni_applications add constraint alumni_applications_contribution_check check (status = 'draft' or length(trim(contribution)) between 5 and 5000);
alter table public.alumni_applications add constraint alumni_applications_newsletter_check check (status = 'draft' or newsletter_subscribed is true);
alter table public.alumni_applications add constraint alumni_applications_agreement_check check (status = 'draft' or agreement_accepted is true);
alter table public.alumni_applications enable row level security;
drop policy if exists "Applicants can read their own application" on public.alumni_applications;
create policy "Applicants can read their own application" on public.alumni_applications for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Applicants can submit their own application" on public.alumni_applications;
create policy "Applicants can submit their own application" on public.alumni_applications for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Applicants can update their own application" on public.alumni_applications;
create policy "Applicants can update their own application" on public.alumni_applications for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "Alumni admins can manage applications" on public.alumni_applications;
create policy "Alumni admins can manage applications" on public.alumni_applications for all to authenticated using (lower(coalesce(auth.jwt() ->> 'email', '')) in ('nghsians@gmail.com', 'umairhoquechowdhury13@gmail.com')) with check (lower(coalesce(auth.jwt() ->> 'email', '')) in ('nghsians@gmail.com', 'umairhoquechowdhury13@gmail.com'));
revoke all on public.alumni_applications from anon;
grant select, insert, update on public.alumni_applications to authenticated;
comment on table public.alumni_applications is 'Private NGHSIANS alumni-interface applications and account-linked drafts. Drafts remain private; completed submissions are pending, approved, or denied. Contact data is not exposed in alumni_directory.';
comment on column public.alumni_applications.status is 'Private draft, pending, approved, or denied. Batches at or below the configured auto-approval year are approved on final submission; 2026 is manually reviewed.';
comment on column public.alumni_applications.batch_year is 'Applicant-entered four-digit batch year. Maximum is controlled by alumni_application_settings.max_eligible_batch.';
comment on column public.alumni_applications.college_university is 'Current college/university for applicants selecting Student; exposed on approved alumni cards.';
comment on column public.alumni_applications.profile_role_granted is 'Internal marker used to safely restore a previous profile role if an approved application is later denied.';
create index if not exists alumni_applications_status_batch_idx on public.alumni_applications (status, batch_year);
create index if not exists alumni_applications_submitted_at_idx on public.alumni_applications (submitted_at desc);

create or replace function public.prepare_alumni_application() returns trigger language plpgsql set search_path = public as $alumni_prepare$
declare
  v_auth_uid uuid := auth.uid();
  v_is_admin boolean := lower(coalesce(auth.jwt() ->> 'email', '')) in ('nghsians@gmail.com', 'umairhoquechowdhury13@gmail.com');
  v_profile_role text;
  v_max_batch integer;
  v_auto_through integer;
begin
  select max_eligible_batch, auto_approve_through_batch into v_max_batch, v_auto_through from public.alumni_application_settings where setting_key = 'default';
  if v_max_batch is null or v_auto_through is null then
    raise exception 'Alumni application settings are missing. Restore the default settings row before submitting.' using errcode = '55000';
  end if;
  if new.user_id is null then new.user_id := v_auth_uid; end if;
  if v_auth_uid is not null and new.user_id is distinct from v_auth_uid and not v_is_admin then
    raise exception 'You can only submit or update your own alumni application.' using errcode = '42501';
  end if;
  if v_auth_uid is not null and new.user_id = v_auth_uid then
    select lower(btrim(coalesce(role, ''))) into v_profile_role from public.verified_profiles where id = new.user_id;
    if v_profile_role = 'architect' then
      raise exception 'Architect accounts do not need an Alumni Interface application; their role is preserved.' using errcode = '23514';
    end if;
  end if;
  new.full_name := trim(coalesce(new.full_name, ''));
  new.contact_email := nullif(trim(coalesce(new.contact_email, '')), '');
  new.phone_number := trim(coalesce(new.phone_number, ''));
  new.occupation := trim(coalesce(new.occupation, ''));
  new.college_university := nullif(trim(coalesce(new.college_university, '')), '');
  if new.college_university is not null and length(new.college_university) > 180 then
    raise exception 'College/university name must be 180 characters or fewer.' using errcode = '23514';
  end if;
  if lower(new.occupation) = 'student' and new.college_university is null then
    if tg_op = 'INSERT' and new.status <> 'draft' then
      raise exception 'Enter your current college or university before submitting.' using errcode = '23514';
    elsif tg_op = 'UPDATE' and current_user = 'authenticated' and v_auth_uid = old.user_id and not v_is_admin and new.status <> 'draft' then
      raise exception 'Enter your current college or university before submitting.' using errcode = '23514';
    end if;
  end if;
  new.blood_group := upper(trim(coalesce(new.blood_group, '')));
  new.principal_names := trim(coalesce(new.principal_names, ''));
  new.why_proud := trim(coalesce(new.why_proud, ''));
  new.contribution := trim(coalesce(new.contribution, ''));
  if new.batch_year is not null and new.batch_year > v_max_batch then
    raise exception 'Batch % is not eligible for the Alumni Interface. The current maximum eligible batch is %.', new.batch_year, v_max_batch using errcode = '23514';
  end if;
  new.updated_at := timezone('utc'::text, now());
  if tg_op = 'INSERT' then
    new.submitted_at := timezone('utc'::text, now());
    new.profile_role_before_approval := null;
    new.profile_role_granted := false;
    new.review_note := null;
    if new.status = 'draft' then
      new.reviewed_at := null;
      new.reviewed_by := null;
      return new;
    end if;
    if new.batch_year is null then
      raise exception 'Enter your four-digit batch year before submitting.' using errcode = '23514';
    end if;
    if new.newsletter_subscribed is not true or new.agreement_accepted is not true then
      raise exception 'Please confirm newsletter subscription and the applicant agreement before submitting.' using errcode = '23514';
    end if;
    new.status := case when new.batch_year <= v_auto_through then 'approved' else 'pending' end;
    if new.status = 'approved' then
      new.reviewed_at := timezone('utc'::text, now());
      new.reviewed_by := null;
    else
      new.reviewed_at := null;
      new.reviewed_by := null;
    end if;
    return new;
  end if;
  new.id := old.id;
  new.user_id := old.user_id;
  if v_auth_uid is not null and v_auth_uid = old.user_id and current_user = 'authenticated' and not v_is_admin then
    if old.status in ('draft', 'pending', 'denied') and new.status = 'draft' then
      new.status := 'draft';
      new.submitted_at := old.submitted_at;
      new.reviewed_at := old.reviewed_at;
      new.reviewed_by := old.reviewed_by;
      new.review_note := old.review_note;
    elsif old.status in ('draft', 'denied') and new.status = 'pending' then
      if new.batch_year is null then
        raise exception 'Enter your four-digit batch year before submitting.' using errcode = '23514';
      end if;
      if new.newsletter_subscribed is not true or new.agreement_accepted is not true then
        raise exception 'Please confirm newsletter subscription and the applicant agreement before submitting.' using errcode = '23514';
      end if;
      new.submitted_at := timezone('utc'::text, now());
      new.review_note := null;
      new.status := case when new.batch_year <= v_auto_through then 'approved' else 'pending' end;
      if new.status = 'approved' then
        new.reviewed_at := timezone('utc'::text, now());
        new.reviewed_by := null;
      else
        new.reviewed_at := null;
        new.reviewed_by := null;
      end if;
    else
      new.status := old.status;
      new.submitted_at := old.submitted_at;
      new.reviewed_at := old.reviewed_at;
      new.reviewed_by := old.reviewed_by;
      new.review_note := old.review_note;
    end if;
    new.profile_role_before_approval := old.profile_role_before_approval;
    new.profile_role_granted := old.profile_role_granted;
  else
    new.submitted_at := old.submitted_at;
    if new.status is distinct from old.status then
      if new.status in ('approved', 'denied') then
        new.reviewed_at := timezone('utc'::text, now());
        new.reviewed_by := v_auth_uid;
      else
        new.reviewed_at := null;
        new.reviewed_by := null;
      end if;
    else
      new.reviewed_at := old.reviewed_at;
      new.reviewed_by := old.reviewed_by;
    end if;
    if current_user = 'authenticated' then
      new.profile_role_before_approval := old.profile_role_before_approval;
      new.profile_role_granted := old.profile_role_granted;
    end if;
  end if;
  return new;
end;
$alumni_prepare$;
drop trigger if exists alumni_applications_prepare on public.alumni_applications;
create trigger alumni_applications_prepare before insert or update on public.alumni_applications for each row execute function public.prepare_alumni_application();

create or replace function public.sync_alumni_application_role() returns trigger language plpgsql security definer set search_path = public as $alumni_sync$
declare
  v_previous_role text;
begin
  if new.status = 'approved' then
    if tg_op = 'UPDATE' then
      if old.status = 'approved' then return new; end if;
    end if;
    select coalesce(role, 'member') into v_previous_role from public.verified_profiles where id = new.user_id;
    if not found then
      v_previous_role := 'member';
      insert into public.verified_profiles (id, role) values (new.user_id, 'member') on conflict (id) do nothing;
    end if;
    if v_previous_role not in ('architect', '27', 'alumni') then
      update public.verified_profiles set role = 'alumni' where id = new.user_id and coalesce(role, 'member') not in ('architect', '27', 'alumni');
      update public.alumni_applications set profile_role_before_approval = v_previous_role, profile_role_granted = true where id = new.id;
    end if;
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if old.status = 'approved' and new.status <> 'approved' and old.profile_role_granted then
      update public.verified_profiles set role = coalesce(old.profile_role_before_approval, 'member') where id = new.user_id and role = 'alumni';
      update public.alumni_applications set profile_role_before_approval = null, profile_role_granted = false where id = new.id;
    end if;
  end if;
  return new;
end;
$alumni_sync$;
drop trigger if exists alumni_applications_sync_role on public.alumni_applications;
create trigger alumni_applications_sync_role after insert or update of status on public.alumni_applications for each row execute function public.sync_alumni_application_role();

create or replace view public.alumni_directory with (security_barrier = true) as select a.id as application_id, a.full_name, a.batch_year, a.occupation, a.blood_group, a.principal_names, a.why_proud, a.contribution, a.college_university from public.alumni_applications a where a.status = 'approved' and not exists (select 1 from public.verified_profiles p where p.id = a.user_id and lower(btrim(coalesce(p.role, ''))) = 'architect');
grant select on public.alumni_directory to anon, authenticated;
comment on view public.alumni_directory is 'Public-safe alumni interface records. Includes approved entries only and college/university when supplied; deliberately omits account IDs, emails, phone numbers, newsletter consent, review notes, and moderation metadata.';

/* Verify the setup and review applications:
   select setting_key, max_eligible_batch, auto_approve_through_batch from public.alumni_application_settings;
   select full_name, contact_email, batch_year, occupation, college_university, status, submitted_at, reviewed_at, review_note from public.alumni_applications order by submitted_at desc;

   Manual 2026 review: set status to 'approved' or 'denied' in Table Editor, or run:
   update public.alumni_applications set status = 'approved' where id = '<application-uuid>';
   update public.alumni_applications set status = 'denied', review_note = 'Not eligible' where id = '<application-uuid>';
   Approved updates verified_profiles.role and appears in the public alumni directory; denied requests do not.

   When the cutoff advances next year, update the single settings row. Example:
   update public.alumni_application_settings set max_eligible_batch = 2027, auto_approve_through_batch = 2026, updated_at = now() where setting_key = 'default';
*/
