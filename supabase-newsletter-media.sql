/* ============================================================================
   NGHSIANS — public newsletter image storage (safe to re-run)

   One-time setup for mailer.html's 1920 × 1080 hero-image uploader.
   Uploads require a signed-in NGHSIANS newsletter admin; images are public-read
   because recipients' email apps must be able to download the image over HTTPS.
   No subscriber data is stored in this bucket.

   Supabase Dashboard → SQL Editor → New query → paste → Run.
   ============================================================================ */

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values ('newsletter-media', 'newsletter-media', true, 8388608, array['image/png', 'image/jpeg', 'image/webp']) on conflict (id) do update set name = excluded.name, public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

/* Only the newsletter admins can upload into the campaigns/ prefix. The public
   bucket setting allows recipients to download known image URLs; it does not
   grant anyone upload access, and we intentionally do not add a public listing
   policy. */
drop policy if exists "Newsletter admins can upload campaign images" on storage.objects;
create policy "Newsletter admins can upload campaign images" on storage.objects for insert to authenticated with check (bucket_id = 'newsletter-media' and name like 'campaigns/%' and public.newsletter_is_admin());
