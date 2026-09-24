-- Volejbalová pokladna – database schema for Supabase.
-- Run once in Supabase → SQL Editor. Safe to run again (idempotent).
--
-- Access model:
--   * members.role = 'admin'  → can read and write everything
--   * members.role = 'viewer' → can only read
--   * anyone else (not signed in, or signed in but not in members) → no access

-- ---------- tables ----------
create table if not exists public.members (
  email text primary key check (email = lower(email)),
  role  text not null check (role in ('admin', 'viewer'))
);

create table if not exists public.players (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
create table if not exists public.trainings (like public.players including all);
create table if not exists public.payments  (like public.players including all);
create table if not exists public.settings  (like public.players including all);

-- ---------- helpers ----------
-- security definer: members table must be readable here even though
-- ordinary users only see their own row.
create or replace function public.member_role()
returns text
language sql stable security definer
set search_path = public
as $$
  select role from public.members
  where email = lower(coalesce(auth.jwt() ->> 'email', ''))
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end
$$;

-- ---------- row level security ----------
alter table public.members enable row level security;

drop policy if exists "members: read own row" on public.members;
create policy "members: read own row" on public.members
  for select to authenticated
  using (email = lower(coalesce(auth.jwt() ->> 'email', '')));

do $$
declare t text;
begin
  foreach t in array array['players', 'trainings', 'payments', 'settings'] loop
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists "read: members" on public.%I', t);
    execute format('create policy "read: members" on public.%I for select to authenticated using (public.member_role() is not null)', t);

    execute format('drop policy if exists "insert: admins" on public.%I', t);
    execute format('create policy "insert: admins" on public.%I for insert to authenticated with check (public.member_role() = ''admin'')', t);

    execute format('drop policy if exists "update: admins" on public.%I', t);
    execute format('create policy "update: admins" on public.%I for update to authenticated using (public.member_role() = ''admin'') with check (public.member_role() = ''admin'')', t);

    execute format('drop policy if exists "delete: admins" on public.%I', t);
    execute format('create policy "delete: admins" on public.%I for delete to authenticated using (public.member_role() = ''admin'')', t);

    execute format('drop trigger if exists touch_updated_at on public.%I', t);
    execute format('create trigger touch_updated_at before update on public.%I for each row execute function public.touch_updated_at()', t);

    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end
$$;

revoke all on public.members from anon, authenticated;
grant select on public.members to authenticated;

-- explicit grants: the project does not auto-expose new objects to the API
revoke execute on function public.member_role() from public, anon;
grant execute on function public.member_role() to authenticated;
grant usage on schema public to authenticated;

-- ---------- realtime (live updates for all open windows) ----------
do $$
declare t text;
begin
  foreach t in array array['players', 'trainings', 'payments', 'settings'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end
$$;
