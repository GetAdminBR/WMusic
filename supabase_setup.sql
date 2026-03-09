-- WMusic Supabase setup (run in SQL Editor)
-- This creates tables, RPC for play counter, storage bucket and basic public policies
-- suitable for anonymous client-side usage from index.html/admin.html.

create extension if not exists pgcrypto;

create table if not exists public.tracks (
    id uuid primary key,
    title text not null,
    artist_name text not null,
    cover text,
    src text not null,
    lyrics text default '',
    plays integer not null default 0,
    section text not null default 'trending' check (section in ('trending', 'user', 'unlisted')),
    is_hidden boolean not null default false,
    uploader_id uuid, -- tracks may record who uploaded public files
    created_at timestamptz not null default now()
);

create table if not exists public.artists (
    id uuid primary key,
    name text not null,
    photo text,
    created_at timestamptz not null default now()
);

create table if not exists public.artist_tracks (
    artist_id uuid not null references public.artists(id) on delete cascade,
    track_id uuid not null references public.tracks(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (artist_id, track_id)
);

-- table used by client to persist likes per browser session
create table if not exists public.liked_tracks (
    browser_id uuid not null,
    track_id uuid not null,
    created_at timestamptz not null default now(),
    primary key (browser_id, track_id)
);

create or replace function public.increment_track_plays(input_track_id uuid)
returns table(id uuid, plays integer)
language plpgsql
security definer
set search_path = public
as $$
begin
    update public.tracks as t
    set plays = coalesce(t.plays, 0) + 1
    where t.id = input_track_id;

    return query
    select t.id, t.plays
    from public.tracks as t
    where t.id = input_track_id;
end;
$$;

revoke all on function public.increment_track_plays(uuid) from public;
grant execute on function public.increment_track_plays(uuid) to anon, authenticated;

alter table public.tracks enable row level security;
alter table public.artists enable row level security;
alter table public.artist_tracks enable row level security;
alter table public.liked_tracks enable row level security;

-- Public read/write policies for anon key usage in static frontend.
-- If you need stricter security, replace these with user-specific policies.
do $$
begin
    if not exists (
        select 1 from pg_policies where schemaname = 'public' and tablename = 'tracks' and policyname = 'tracks_public_all'
    ) then
        create policy tracks_public_all on public.tracks for all to anon, authenticated using (true) with check (true);
    end if;

    if not exists (
        select 1 from pg_policies where schemaname = 'public' and tablename = 'artists' and policyname = 'artists_public_all'
    ) then
        create policy artists_public_all on public.artists for all to anon, authenticated using (true) with check (true);
    end if;

    if not exists (
        select 1 from pg_policies where schemaname = 'public' and tablename = 'artist_tracks' and policyname = 'artist_tracks_public_all'
    ) then
        create policy artist_tracks_public_all on public.artist_tracks for all to anon, authenticated using (true) with check (true);
    end if;

    if not exists (
        select 1 from pg_policies where schemaname = 'public' and tablename = 'liked_tracks' and policyname = 'liked_tracks_public_all'
    ) then
        create policy liked_tracks_public_all on public.liked_tracks for all to anon, authenticated using (true) with check (true);
    end if;
end $$;

insert into storage.buckets (id, name, public)
values ('wmusic-media', 'wmusic-media', true)
on conflict (id) do update set public = excluded.public;

do $$
begin
    if not exists (
        select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'wmusic_media_public_read'
    ) then
        create policy wmusic_media_public_read
        on storage.objects
        for select
        to public
        using (bucket_id = 'wmusic-media');
    end if;

    if not exists (
        select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'wmusic_media_public_insert'
    ) then
        create policy wmusic_media_public_insert
        on storage.objects
        for insert
        to anon, authenticated
        with check (bucket_id = 'wmusic-media');
    end if;

    if not exists (
        select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'wmusic_media_public_update'
    ) then
        create policy wmusic_media_public_update
        on storage.objects
        for update
        to anon, authenticated
        using (bucket_id = 'wmusic-media')
        with check (bucket_id = 'wmusic-media');
    end if;

    if not exists (
        select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'wmusic_media_public_delete'
    ) then
        create policy wmusic_media_public_delete
        on storage.objects
        for delete
        to anon, authenticated
        using (bucket_id = 'wmusic-media');
    end if;
end $$;
