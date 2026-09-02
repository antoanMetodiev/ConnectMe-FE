-- ConnectMe: 24h stories (photo/video) visible only to accepted contacts,
-- with heart likes and story replies (delivered as a normal chat message).
-- Run once in Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.

-- SECURITY DEFINER so RLS policies that call it don't need the caller to
-- already have row access to contact_requests for both sides.
create or replace function public.are_contacts(a uuid, b uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.contact_requests
    where status = 'accepted'
      and (
        (requester_id = a and addressee_id = b)
        or (requester_id = b and addressee_id = a)
      )
  );
$$;

create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  media_path text not null,
  media_type text not null check (media_type in ('image', 'video')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

create index if not exists stories_user_id_expires_at_idx
  on public.stories (user_id, expires_at);

alter table public.stories enable row level security;

drop policy if exists "owner and contacts can view stories" on public.stories;
create policy "owner and contacts can view stories"
  on public.stories for select
  to authenticated
  using (
    user_id = auth.uid()
    or (expires_at > now() and public.are_contacts(user_id, auth.uid()))
  );

drop policy if exists "users can create their own stories" on public.stories;
create policy "users can create their own stories"
  on public.stories for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "users can delete their own stories" on public.stories;
create policy "users can delete their own stories"
  on public.stories for delete
  to authenticated
  using (user_id = auth.uid());

create table if not exists public.story_likes (
  story_id uuid not null references public.stories (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (story_id, user_id)
);

alter table public.story_likes enable row level security;

drop policy if exists "story audience can view likes" on public.story_likes;
create policy "story audience can view likes"
  on public.story_likes for select
  to authenticated
  using (
    exists (
      select 1 from public.stories s
      where s.id = story_likes.story_id
        and (s.user_id = auth.uid() or public.are_contacts(s.user_id, auth.uid()))
    )
  );

drop policy if exists "story audience can like" on public.story_likes;
create policy "story audience can like"
  on public.story_likes for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.stories s
      where s.id = story_id
        and s.expires_at > now()
        and (s.user_id = auth.uid() or public.are_contacts(s.user_id, auth.uid()))
    )
  );

drop policy if exists "users can remove their own like" on public.story_likes;
create policy "users can remove their own like"
  on public.story_likes for delete
  to authenticated
  using (user_id = auth.uid());

-- Private bucket — only reachable through RLS-checked requests (signed
-- URLs), never a public link.
insert into storage.buckets (id, name, public)
values ('stories', 'stories', false)
on conflict (id) do nothing;

-- Path convention is `{user_id}/{filename}`.
drop policy if exists "users can upload their own stories" on storage.objects;
create policy "users can upload their own stories"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'stories'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "owner and contacts can view story media" on storage.objects;
create policy "owner and contacts can view story media"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'stories'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.are_contacts((storage.foldername(name))[1]::uuid, auth.uid())
    )
  );

drop policy if exists "users can delete their own story media" on storage.objects;
create policy "users can delete their own story media"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'stories'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'stories'
  ) then
    alter publication supabase_realtime add table public.stories;
  end if;
end $$;
