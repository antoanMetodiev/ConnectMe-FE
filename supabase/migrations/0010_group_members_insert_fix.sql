-- Fix: inserting group_members rows for people other than the creator failed
-- under RLS. The "creator can add members" branch of the insert policy did
-- `exists (select 1 from groups g where g.id = ... and g.created_by =
-- auth.uid())`, but that subquery is itself subject to groups' own RLS
-- (members-only SELECT), and the creator isn't a group_members row yet at
-- the moment they're being inserted -- so the subquery saw zero rows and the
-- check failed for every member row except the creator's own.
-- Fix: same trick as is_group_member -- a SECURITY DEFINER function that
-- checks group ownership without going through groups' RLS.

create or replace function public.is_group_creator(p_group_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.groups
    where id = p_group_id and created_by = p_user_id
  );
$$;

drop policy if exists "creator can add members, users can add themselves" on public.group_members;
create policy "creator can add members, users can add themselves"
  on public.group_members for insert
  to authenticated
  with check (
    user_id = auth.uid()
    or public.is_group_creator(group_id, auth.uid())
  );
