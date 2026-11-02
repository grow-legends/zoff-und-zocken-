-- Zoff & Zocken – Datenbank einrichten
-- In Supabase: SQL Editor → New query → alles einfügen → Run

-- Spieler: ein Eintrag pro Person mit Profil, Bestwerten, Tagesrunden und Turnierergebnissen
create table if not exists public.players (
  id uuid primary key references auth.users (id) on delete cascade,
  doc jsonb not null default '{}'::jsonb check (pg_column_size(doc) < 250000),
  updated_at timestamptz not null default now()
);

-- Turniere und Duelle
create table if not exists public.tournaments (
  id text primary key check (char_length(id) <= 40),
  doc jsonb not null check (pg_column_size(doc) < 20000),
  created_by uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Zugriffsregeln: alle dürfen lesen, jeder schreibt nur seine eigenen Sachen
alter table public.players enable row level security;
alter table public.tournaments enable row level security;

drop policy if exists "Spieler lesen" on public.players;
drop policy if exists "Eigenes Profil anlegen" on public.players;
drop policy if exists "Eigenes Profil ändern" on public.players;
drop policy if exists "Turniere lesen" on public.tournaments;
drop policy if exists "Turnier anlegen" on public.tournaments;
drop policy if exists "Eigenes Turnier löschen" on public.tournaments;

create policy "Spieler lesen" on public.players
  for select using (true);
create policy "Eigenes Profil anlegen" on public.players
  for insert to authenticated with check (auth.uid() = id);
create policy "Eigenes Profil ändern" on public.players
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

create policy "Turniere lesen" on public.tournaments
  for select using (true);
create policy "Turnier anlegen" on public.tournaments
  for insert to authenticated with check (auth.uid() = created_by);
create policy "Eigenes Turnier löschen" on public.tournaments
  for delete to authenticated using (auth.uid() = created_by);

grant select on public.players, public.tournaments to anon, authenticated;
grant insert, update on public.players to authenticated;
grant insert, delete on public.tournaments to authenticated;

-- Live-Updates für Bestenliste und Turniere einschalten
do $$
begin
  begin
    alter publication supabase_realtime add table public.players;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.tournaments;
  exception when duplicate_object then null;
  end;
end $$;
