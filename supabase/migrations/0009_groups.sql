-- ConnectMe: text groups (persistent, multi-person chat). Group calls are
-- started from inside a group, not dialed ad-hoc — members must already
-- share a group first.
-- Run once in Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) > 0),
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table if not exists public.group_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

create index if not exists group_messages_group_id_created_at_idx
  on public.group_messages (group_id, created_at);

-- SECURITY DEFINER so policies that call it don't recursively re-trigger
-- group_members' own RLS policy.
create or replace function public.is_group_member(p_group_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = p_user_id
  );
$$;

alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_messages enable row level security;

drop policy if exists "members can view their groups" on public.groups;
create policy "members can view their groups"
  on public.groups for select
  to authenticated
  using (public.is_group_member(id, auth.uid()));

drop policy if exists "authenticated users can create groups" on public.groups;
create policy "authenticated users can create groups"
  on public.groups for insert
  to authenticated
  with check (created_by = auth.uid());

drop policy if exists "members can view group membership" on public.group_members;
create policy "members can view group membership"
  on public.group_members for select
  to authenticated
  using (public.is_group_member(group_id, auth.uid()));

drop policy if exists "creator can add members, users can add themselves" on public.group_members;
create policy "creator can add members, users can add themselves"
  on public.group_members for insert
  to authenticated
  with check (
    user_id = auth.uid()
    or exists (
      select 1 from public.groups g
      where g.id = group_members.group_id and g.created_by = auth.uid()
    )
  );

drop policy if exists "members can view group messages" on public.group_messages;
create policy "members can view group messages"
  on public.group_messages for select
  to authenticated
  using (public.is_group_member(group_id, auth.uid()));

drop policy if exists "members can send group messages" on public.group_messages;
create policy "members can send group messages"
  on public.group_messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_group_member(group_id, auth.uid())
  );

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'group_messages'
  ) then
    alter publication supabase_realtime add table public.group_messages;
  end if;
end $$;
