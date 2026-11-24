-- BEEBA media storage: public playback for post/story media, owner-only writes.
-- Safe to apply repeatedly.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'beeba-media',
  'beeba-media',
  true,
  52428800,
  array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm']
)
on conflict (id) do update
set public = true,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "BEEBA media is publicly readable" on storage.objects;
create policy "BEEBA media is publicly readable"
on storage.objects for select
to public
using (bucket_id = 'beeba-media');

drop policy if exists "BEEBA users upload own media" on storage.objects;
create policy "BEEBA users upload own media"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'beeba-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "BEEBA users update own media" on storage.objects;
create policy "BEEBA users update own media"
on storage.objects for update
to authenticated
using (
  bucket_id = 'beeba-media'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'beeba-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "BEEBA users delete own media" on storage.objects;
create policy "BEEBA users delete own media"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'beeba-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);
