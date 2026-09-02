-- ConnectMe: "who viewed my story" tracking.
-- Run once in Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.

create table if not exists public.story_views (
  story_id uuid not null references public.stories (id) on delete cascade,
  viewer_id uuid not null references public.profiles (id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (story_id, viewer_id)
);

alter table public.story_views enable row level security;

-- Privacy: only the story's owner sees the full viewer list (like every
-- other stories UI) — everyone else can only see their own view record,
-- which is enough for the client to know "have I already marked this
-- viewed" without granting visibility into who else viewed it.
drop policy if exists "owner sees viewers, viewer sees own view" on public.story_views;
create policy "owner sees viewers, viewer sees own view"
  on public.story_views for select
  to authenticated
  using (
    viewer_id = auth.uid()
    or exists (
      select 1 from public.stories s
      where s.id = story_views.story_id and s.user_id = auth.uid()
    )
  );

drop policy if exists "story audience can record a view" on public.story_views;
create policy "story audience can record a view"
  on public.story_views for insert
  to authenticated
  with check (
    viewer_id = auth.uid()
    and exists (
      select 1 from public.stories s
      where s.id = story_id
        and s.expires_at > now()
        and (s.user_id = auth.uid() or public.are_contacts(s.user_id, auth.uid()))
    )
  );
