-- Cipherly - Supabase schema
-- Run in the Supabase SQL editor (Dashboard > SQL Editor > New query).

-- Public directory: lets users find each other by e-mail and learn the
-- identity public key used to authenticate the end-to-end handshake.
-- Only PUBLIC keys are stored here; private keys never leave the device.
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  email        text not null unique,
  display_name text not null default '',
  public_key   text not null,
  updated_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles readable by signed-in users" on public.profiles;
create policy "profiles readable by signed-in users"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "users insert own profile" on public.profiles;
create policy "users insert own profile"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id and lower(email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id and lower(email) = lower(auth.jwt() ->> 'email'));

-- Chat messages are NOT stored anywhere on the server: they travel over a
-- direct WebRTC data channel. Supabase Realtime (broadcast + presence) is only
-- used to exchange connection offers/answers and ICE candidates.
