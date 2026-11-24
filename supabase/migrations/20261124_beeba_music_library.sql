-- BEEBA creator music library (run in Supabase SQL Editor)
create table if not exists public.beeba_music_tracks (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 title text not null check (char_length(title) between 1 and 100),
 artist text not null default '',
 audio_path text not null,
 artwork_url text,
 duration_seconds integer,
 rights_confirmed boolean not null default false,
 status text not null default 'pending' check (status in ('pending','approved','rejected')),
 created_at timestamptz not null default now()
);
alter table public.beeba_music_tracks enable row level security;
drop policy if exists "BEEBA approved tracks visible" on public.beeba_music_tracks;
create policy "BEEBA approved tracks visible" on public.beeba_music_tracks for select to authenticated using (status='approved' or user_id=auth.uid());
drop policy if exists "BEEBA creators upload own tracks" on public.beeba_music_tracks;
create policy "BEEBA creators upload own tracks" on public.beeba_music_tracks for insert to authenticated with check (user_id=auth.uid() and rights_confirmed=true and status='pending');
drop policy if exists "BEEBA creators delete own pending tracks" on public.beeba_music_tracks;
create policy "BEEBA creators delete own pending tracks" on public.beeba_music_tracks for delete to authenticated using (user_id=auth.uid() and status<>'approved');

alter table public.posts add column if not exists music_track_id uuid references public.beeba_music_tracks(id) on delete set null;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('beeba-music','beeba-music',false,52428800,array['audio/mpeg','audio/mp4','audio/aac','audio/ogg','audio/wav','audio/webm'])
on conflict (id) do update set public=false,file_size_limit=52428800,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "BEEBA users upload own music files" on storage.objects;
create policy "BEEBA users upload own music files" on storage.objects for insert to authenticated with check (bucket_id='beeba-music' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "BEEBA users read own music files" on storage.objects;
create policy "BEEBA users read own music files" on storage.objects for select to authenticated using (bucket_id='beeba-music' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "BEEBA users delete own music files" on storage.objects;
create policy "BEEBA users delete own music files" on storage.objects for delete to authenticated using (bucket_id='beeba-music' and (storage.foldername(name))[1]=auth.uid()::text);
