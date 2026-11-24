-- BEEBA feature foundation migration
-- Run this in Supabase SQL Editor before enabling the matching app features.
-- Assumes existing public.stories, public.highlights, public.conversations,
-- and public.conversation_members tables from the current BEEBA app.

create extension if not exists pgcrypto;

-- 1) Private account preferences stored server-side.
create table if not exists public.beeba_user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.beeba_user_settings enable row level security;
drop policy if exists "Users read own BEEBA settings" on public.beeba_user_settings;
create policy "Users read own BEEBA settings" on public.beeba_user_settings
  for select to authenticated using (user_id = auth.uid());
drop policy if exists "Users insert own BEEBA settings" on public.beeba_user_settings;
create policy "Users insert own BEEBA settings" on public.beeba_user_settings
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "Users update own BEEBA settings" on public.beeba_user_settings;
create policy "Users update own BEEBA settings" on public.beeba_user_settings
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 2) Story archive. Existing and future stories get a durable archive record.
create table if not exists public.beeba_story_archive (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null unique,
  user_id uuid not null references auth.users(id) on delete cascade,
  media_url text not null,
  media_type text not null default 'image',
  created_at timestamptz not null default now(),
  archived_at timestamptz not null default now()
);
alter table public.beeba_story_archive enable row level security;
drop policy if exists "Users read own archived stories" on public.beeba_story_archive;
create policy "Users read own archived stories" on public.beeba_story_archive
  for select to authenticated using (user_id = auth.uid());
drop policy if exists "Users add own archived stories" on public.beeba_story_archive;
create policy "Users add own archived stories" on public.beeba_story_archive
  for insert to authenticated with check (user_id = auth.uid());

insert into public.beeba_story_archive (story_id,user_id,media_url,media_type,created_at)
select s.id,s.user_id,s.media_url,coalesce(s.media_type,'image'),coalesce(s.created_at,now())
from public.stories s
on conflict (story_id) do nothing;

create or replace function public.beeba_archive_story_after_insert()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.beeba_story_archive (story_id,user_id,media_url,media_type,created_at)
  values (new.id,new.user_id,new.media_url,coalesce(new.media_type,'image'),coalesce(new.created_at,now()))
  on conflict (story_id) do nothing;
  return new;
end;
$$;

drop trigger if exists beeba_archive_story_insert on public.stories;
create trigger beeba_archive_story_insert
after insert on public.stories
for each row execute function public.beeba_archive_story_after_insert();

-- 3) Link archived stories to highlights.
create table if not exists public.beeba_highlight_items (
  id uuid primary key default gen_random_uuid(),
  highlight_id uuid not null references public.highlights(id) on delete cascade,
  archive_id uuid not null references public.beeba_story_archive(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  unique (highlight_id,archive_id)
);
alter table public.beeba_highlight_items enable row level security;
drop policy if exists "Users view own highlight items" on public.beeba_highlight_items;
create policy "Users view own highlight items" on public.beeba_highlight_items
  for select to authenticated using (user_id = auth.uid());
drop policy if exists "Users add own highlight items" on public.beeba_highlight_items;
create policy "Users add own highlight items" on public.beeba_highlight_items
  for insert to authenticated with check (
    user_id = auth.uid()
    and exists (select 1 from public.highlights h where h.id = highlight_id and h.user_id = auth.uid())
    and exists (select 1 from public.beeba_story_archive a where a.id = archive_id and a.user_id = auth.uid())
  );
drop policy if exists "Users delete own highlight items" on public.beeba_highlight_items;
create policy "Users delete own highlight items" on public.beeba_highlight_items
  for delete to authenticated using (user_id = auth.uid());

-- 4) E2EE public identity keys and recipient-encrypted message envelopes.
-- Private keys remain on each user's device and must never be uploaded.
create table if not exists public.beeba_chat_keys (
  user_id uuid primary key references auth.users(id) on delete cascade,
  public_key jsonb not null,
  fingerprint text not null,
  key_version integer not null default 1,
  updated_at timestamptz not null default now()
);
alter table public.beeba_chat_keys enable row level security;
drop policy if exists "Authenticated users can read public chat keys" on public.beeba_chat_keys;
create policy "Authenticated users can read public chat keys" on public.beeba_chat_keys
  for select to authenticated using (true);
drop policy if exists "Users register own public chat key" on public.beeba_chat_keys;
create policy "Users register own public chat key" on public.beeba_chat_keys
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "Users rotate own public chat key" on public.beeba_chat_keys;
create policy "Users rotate own public chat key" on public.beeba_chat_keys
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.beeba_encrypted_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  ciphertext text not null,
  iv text not null,
  created_at timestamptz not null default now()
);
create index if not exists beeba_encrypted_messages_conversation_created
  on public.beeba_encrypted_messages(conversation_id,created_at);
create index if not exists beeba_encrypted_messages_recipient_created
  on public.beeba_encrypted_messages(recipient_id,created_at);
alter table public.beeba_encrypted_messages enable row level security;

drop policy if exists "Conversation members read encrypted envelopes" on public.beeba_encrypted_messages;
create policy "Conversation members read encrypted envelopes" on public.beeba_encrypted_messages
  for select to authenticated using (
    exists (select 1 from public.conversation_members cm
      where cm.conversation_id = beeba_encrypted_messages.conversation_id
      and cm.user_id = auth.uid())
  );
drop policy if exists "Conversation members send encrypted envelopes" on public.beeba_encrypted_messages;
create policy "Conversation members send encrypted envelopes" on public.beeba_encrypted_messages
  for insert to authenticated with check (
    sender_id = auth.uid()
    and exists (select 1 from public.conversation_members cm
      where cm.conversation_id = beeba_encrypted_messages.conversation_id
      and cm.user_id = auth.uid())
    and exists (select 1 from public.conversation_members cm
      where cm.conversation_id = beeba_encrypted_messages.conversation_id
      and cm.user_id = recipient_id)
  );

-- 5) Creator-provided music. This is for tracks the uploader owns or has licensed.
create table if not exists public.beeba_music_tracks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  artist text,
  audio_url text not null,
  artwork_url text,
  rights_confirmed boolean not null default false,
  created_at timestamptz not null default now(),
  constraint beeba_music_rights_required check (rights_confirmed = true)
);
alter table public.beeba_music_tracks enable row level security;
drop policy if exists "Authenticated users view licensed BEEBA tracks" on public.beeba_music_tracks;
create policy "Authenticated users view licensed BEEBA tracks" on public.beeba_music_tracks
  for select to authenticated using (true);
drop policy if exists "Users add music they have rights to" on public.beeba_music_tracks;
create policy "Users add music they have rights to" on public.beeba_music_tracks
  for insert to authenticated with check (user_id = auth.uid() and rights_confirmed = true);
drop policy if exists "Users delete own music" on public.beeba_music_tracks;
create policy "Users delete own music" on public.beeba_music_tracks
  for delete to authenticated using (user_id = auth.uid());
