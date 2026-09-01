-- ConnectMe: 1:1 chats + messages, with realtime enabled for live delivery.
-- Run once in Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.

create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  user_a_id uuid not null references public.profiles (id) on delete cascade,
  user_b_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_a_id, user_b_id),
  check (user_a_id < user_b_id)
);

alter table public.chats enable row level security;

drop policy if exists "participants can view their chats" on public.chats;
create policy "participants can view their chats"
  on public.chats for select
  to authenticated
  using (auth.uid() = user_a_id or auth.uid() = user_b_id);

drop policy if exists "participants can create a chat" on public.chats;
create policy "participants can create a chat"
  on public.chats for insert
  to authenticated
  with check (auth.uid() = user_a_id or auth.uid() = user_b_id);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

create index if not exists messages_chat_id_created_at_idx
  on public.messages (chat_id, created_at);

alter table public.messages enable row level security;

drop policy if exists "participants can view chat messages" on public.messages;
create policy "participants can view chat messages"
  on public.messages for select
  to authenticated
  using (
    exists (
      select 1 from public.chats c
      where c.id = messages.chat_id
        and (auth.uid() = c.user_a_id or auth.uid() = c.user_b_id)
    )
  );

drop policy if exists "participants can send chat messages" on public.messages;
create policy "participants can send chat messages"
  on public.messages for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.chats c
      where c.id = messages.chat_id
        and (auth.uid() = c.user_a_id or auth.uid() = c.user_b_id)
    )
  );

-- Enable realtime so open chats receive new messages live.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;
