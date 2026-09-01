-- ConnectMe: keep contact_requests.updated_at current on status changes,
-- so "sent request accepted/declined" activity can be ordered by response
-- time instead of the original request's creation time.
-- Run once in Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_contact_requests_updated_at on public.contact_requests;
create trigger set_contact_requests_updated_at
  before update on public.contact_requests
  for each row execute function public.set_updated_at();
