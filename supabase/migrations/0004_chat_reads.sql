-- ConnectMe: read receipts ("Seen") for chats.
-- Run once in Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.

create table if not exists public.chat_reads (
  chat_id uuid not null references public.chats (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (chat_id, user_id)
);

alter table public.chat_reads enable row level security;

drop policy if exists "participants can view read state" on public.chat_reads;
create policy "participants can view read state"
  on public.chat_reads for select
  to authenticated
  using (
    exists (
      select 1 from public.chats c
      where c.id = chat_reads.chat_id
        and (auth.uid() = c.user_a_id or auth.uid() = c.user_b_id)
    )
  );

drop policy if exists "users can insert their own read state" on public.chat_reads;
create policy "users can insert their own read state"
  on public.chat_reads for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.chats c
      where c.id = chat_reads.chat_id
        and (auth.uid() = c.user_a_id or auth.uid() = c.user_b_id)
    )
  );

drop policy if exists "users can update their own read state" on public.chat_reads;
create policy "users can update their own read state"
  on public.chat_reads for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_reads'
  ) then
    alter publication supabase_realtime add table public.chat_reads;
  end if;
end $$;
