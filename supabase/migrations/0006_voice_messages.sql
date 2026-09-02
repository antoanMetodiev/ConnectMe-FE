-- ConnectMe: voice messages — kept permanently (unlike ephemeral photos).
-- Run once in Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.

insert into storage.buckets (id, name, public)
values ('voice-messages', 'voice-messages', false)
on conflict (id) do nothing;

-- Path convention is `{chat_id}/{filename}`, same as ephemeral-photos.
drop policy if exists "chat participants can upload voice messages" on storage.objects;
create policy "chat participants can upload voice messages"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'voice-messages'
    and exists (
      select 1 from public.chats c
      where c.id::text = (storage.foldername(name))[1]
        and (auth.uid() = c.user_a_id or auth.uid() = c.user_b_id)
    )
  );

drop policy if exists "chat participants can play voice messages" on storage.objects;
create policy "chat participants can play voice messages"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'voice-messages'
    and exists (
      select 1 from public.chats c
      where c.id::text = (storage.foldername(name))[1]
        and (auth.uid() = c.user_a_id or auth.uid() = c.user_b_id)
    )
  );
