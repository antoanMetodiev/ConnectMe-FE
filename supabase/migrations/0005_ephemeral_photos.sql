-- ConnectMe: view-once photo messages.
-- Run once in Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.

-- Private bucket — objects are only reachable through RLS-checked
-- requests, and the app deletes each object right after it's viewed.
insert into storage.buckets (id, name, public)
values ('ephemeral-photos', 'ephemeral-photos', false)
on conflict (id) do nothing;

-- Path convention is `{chat_id}/{filename}` — storage.foldername(name)[1]
-- is the chat_id, checked against chat membership for every operation.
drop policy if exists "chat participants can upload ephemeral photos" on storage.objects;
create policy "chat participants can upload ephemeral photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'ephemeral-photos'
    and exists (
      select 1 from public.chats c
      where c.id::text = (storage.foldername(name))[1]
        and (auth.uid() = c.user_a_id or auth.uid() = c.user_b_id)
    )
  );

drop policy if exists "chat participants can view ephemeral photos" on storage.objects;
create policy "chat participants can view ephemeral photos"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'ephemeral-photos'
    and exists (
      select 1 from public.chats c
      where c.id::text = (storage.foldername(name))[1]
        and (auth.uid() = c.user_a_id or auth.uid() = c.user_b_id)
    )
  );

drop policy if exists "chat participants can delete ephemeral photos" on storage.objects;
create policy "chat participants can delete ephemeral photos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'ephemeral-photos'
    and exists (
      select 1 from public.chats c
      where c.id::text = (storage.foldername(name))[1]
        and (auth.uid() = c.user_a_id or auth.uid() = c.user_b_id)
    )
  );

-- Needed so a photo message's body can flip from "unopened" to "viewed"
-- once someone opens it.
drop policy if exists "participants can update chat messages" on public.messages;
create policy "participants can update chat messages"
  on public.messages for update
  to authenticated
  using (
    exists (
      select 1 from public.chats c
      where c.id = messages.chat_id
        and (auth.uid() = c.user_a_id or auth.uid() = c.user_b_id)
    )
  )
  with check (
    exists (
      select 1 from public.chats c
      where c.id = messages.chat_id
        and (auth.uid() = c.user_a_id or auth.uid() = c.user_b_id)
    )
  );
