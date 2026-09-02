-- ConnectMe: fix avatar re-upload failing RLS.
--
-- `public: true` on the bucket only affects the public-URL serving path —
-- the authenticated SDK upload flow (with upsert: true) still needs a
-- SELECT policy on storage.objects to check whether the file already
-- exists, which was missing, so re-uploading an avatar (an update to an
-- existing path) hit a row-level security violation.
-- Run once in Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.

drop policy if exists "anyone can view avatars" on storage.objects;
create policy "anyone can view avatars"
  on storage.objects for select
  using (bucket_id = 'avatars');
