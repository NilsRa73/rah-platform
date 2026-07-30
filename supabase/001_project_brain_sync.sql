-- RAH Raven Project Brain cloud synchronization
-- Run this file once in Supabase SQL Editor.

create table if not exists public.rah_user_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  client_updated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.rah_user_state enable row level security;

revoke all on public.rah_user_state from anon;
grant select, insert, update, delete on public.rah_user_state to authenticated;

create policy "Users read their own RAH state"
on public.rah_user_state for select
to authenticated
using (auth.uid() = user_id);

create policy "Users create their own RAH state"
on public.rah_user_state for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users update their own RAH state"
on public.rah_user_state for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users delete their own RAH state"
on public.rah_user_state for delete
to authenticated
using (auth.uid() = user_id);

create or replace function public.set_rah_user_state_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists rah_user_state_updated_at on public.rah_user_state;
create trigger rah_user_state_updated_at
before update on public.rah_user_state
for each row execute function public.set_rah_user_state_updated_at();

comment on table public.rah_user_state is
'Private per-user RAH Command Center state. Access is restricted by RLS to auth.uid().';
