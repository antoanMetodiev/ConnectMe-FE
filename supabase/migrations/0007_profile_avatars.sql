-- ConnectMe: pick up Google's profile picture on sign-up/sign-in, and let
-- users upload their own avatar afterwards.
-- Run once in Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'display_name', new.email),
    coalesce(
      new.raw_user_meta_data ->> 'avatar_url',
      new.raw_user_meta_data ->> 'picture'
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.handle_user_updated()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.profiles
  set
    display_name = coalesce(new.raw_user_meta_data ->> 'display_name', new.email),
    email = new.email,
    avatar_url = coalesce(
      new.raw_user_meta_data ->> 'avatar_url',
      new.raw_user_meta_data ->> 'picture'
    )
  where id = new.id;
  return new;
end;
$$;

-- Backfill: existing users (e.g. already signed up with Google before this
-- migration) get their picture without needing to sign in again.
update public.profiles p
set avatar_url = coalesce(
  u.raw_user_meta_data ->> 'avatar_url',
  u.raw_user_meta_data ->> 'picture'
)
from auth.users u
where p.id = u.id
  and p.avatar_url is null
  and coalesce(
    u.raw_user_meta_data ->> 'avatar_url',
    u.raw_user_meta_data ->> 'picture'
  ) is not null;

-- Public bucket — profile pictures are meant to be visible to whoever can
-- already see the profile (any authenticated user, per the profiles
-- select policy), so a plain public URL is simplest.
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Path convention is `{user_id}/{filename}` — only the owning user may
-- write to their own folder.
drop policy if exists "users can upload their own avatar" on storage.objects;
create policy "users can upload their own avatar"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users can update their own avatar" on storage.objects;
create policy "users can update their own avatar"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users can delete their own avatar" on storage.objects;
create policy "users can delete their own avatar"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
