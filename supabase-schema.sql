-- ============================================================================
--  NGHSIANS — SUPABASE SCHEMA  (idempotent / safe to re-run)
--  Updated: 2026-10-01
--
--  WHAT'S NEW IN THIS VERSION
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
-- ============================================================================
alter table if exists verified_profiles add column if not exists whatsapp_number    text;
alter table if exists verified_profiles add column if not exists instagram_username text;

comment on column verified_profiles.whatsapp_number    is 'WhatsApp number in international form, e.g. +8801700000000';
comment on column verified_profiles.instagram_username is 'Instagram username without the @, e.g. nghsians';


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
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'verified_profiles' and column_name = 'instagram_username') then
    alter table verified_profiles add column instagram_username text;
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
