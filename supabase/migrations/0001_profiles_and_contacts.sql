-- ConnectMe: public profiles + contact requests
-- Run once in Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.

-- 1. Public profile mirror of auth.users (auth.users itself isn't queryable
--    via the client libraries, so search/contacts need their own table).
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles are viewable by authenticated users" on public.profiles;
create policy "profiles are viewable by authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "users can update own profile" on public.profiles;
create policy "users can update own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

-- Keep profiles in sync with auth.users automatically.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'display_name', new.email)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.handle_user_updated()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.profiles
  set
    display_name = coalesce(new.raw_user_meta_data ->> 'display_name', new.email),
    email = new.email
  where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
  after update on auth.users
  for each row execute function public.handle_user_updated();

-- Backfill profiles for any user created before this migration ran.
insert into public.profiles (id, email, display_name)
select id, email, coalesce(raw_user_meta_data ->> 'display_name', email)
from auth.users
on conflict (id) do nothing;

-- 2. Contact requests — one row per directed invite; accepted = contact.
create table if not exists public.contact_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

alter table public.contact_requests enable row level security;

drop policy if exists "users can view their own contact requests" on public.contact_requests;
create policy "users can view their own contact requests"
  on public.contact_requests for select
  to authenticated
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

drop policy if exists "users can send contact requests" on public.contact_requests;
create policy "users can send contact requests"
  on public.contact_requests for insert
  to authenticated
  with check (auth.uid() = requester_id);

drop policy if exists "addressee can respond to a request" on public.contact_requests;
create policy "addressee can respond to a request"
  on public.contact_requests for update
  to authenticated
  using (auth.uid() = addressee_id)
  with check (auth.uid() = addressee_id);

drop policy if exists "requester can cancel a pending request" on public.contact_requests;
create policy "requester can cancel a pending request"
  on public.contact_requests for delete
  to authenticated
  using (auth.uid() = requester_id and status = 'pending');
