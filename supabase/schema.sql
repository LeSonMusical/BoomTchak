-- ═══════════════════════════════════════════════════════════════════════════
-- BOOMTCHAK V3 — Schéma Supabase
-- À exécuter dans l'éditeur SQL Supabase (une seule fois, par le MX)
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Extensions ──────────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ── Profiles ────────────────────────────────────────────────────────────────
-- Un profil par utilisateur Google. Créé automatiquement au premier login.
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null,
  role        text not null default 'tx' check (role in ('mx','tx','sx')),
  display_name text,
  created_at  timestamptz default now()
);

-- Création automatique du profil au signup Google
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
declare
  _role text := 'tx';
begin
  insert into public.profiles (id, email, role, display_name)
  values (
    new.id,
    new.email,
    _role,
    coalesce(new.raw_user_meta_data->>'full_name', new.email)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── Familles ─────────────────────────────────────────────────────────────────
create table public.familles (
  id          text primary key,
  nom         text not null,
  scope       text not null default 'school' check (scope in ('school','teacher')),
  owner_id    uuid references public.profiles(id) on delete cascade,
  created_at  timestamptz default now(),
  ordre       int default 0
);
-- Migration si table déjà existante : ALTER TABLE public.familles ADD COLUMN IF NOT EXISTS ordre int default 0;

-- ── Patterns ─────────────────────────────────────────────────────────────────
create table public.patterns (
  id              text primary key,
  nom             text not null,
  sequence        text not null,
  pas             int not null,
  familles_ids    text[] default '{}',
  encyclo_ref     text,
  scope           text not null default 'teacher' check (scope in ('school','teacher')),
  approved        boolean default false,
  owner_id        uuid references public.profiles(id) on delete cascade,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- ── Grooves ──────────────────────────────────────────────────────────────────
create table public.grooves (
  id            text primary key,
  nom           text not null,
  familles_ids  text[] default '{}',
  band_defaut   text,
  tempo_min     int default 60,
  tempo_max     int default 300,
  tempo_defaut  int default 120,
  signature     text not null default '4/4',
  layers        jsonb not null default '[]',
  scope         text not null default 'teacher' check (scope in ('school','teacher')),
  approved      boolean default false,
  owner_id      uuid references public.profiles(id) on delete cascade,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- ── Encyclopédie ─────────────────────────────────────────────────────────────
create table public.encyclo (
  key         text primary key,
  chapo       text default '',
  bullets     jsonb default '[]',
  scope       text not null default 'school' check (scope in ('school','teacher')),
  approved    boolean default true,
  owner_id    uuid references public.profiles(id) on delete cascade,
  updated_at  timestamptz default now()
);

-- ── Parcours (phase suivante) ─────────────────────────────────────────────────
create table public.parcours (
  id          uuid primary key default uuid_generate_v4(),
  titre       text not null,
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  etapes      jsonb not null default '[]',
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- ── Données élèves (phase suivante) ──────────────────────────────────────────
create table public.student_data (
  id          uuid primary key default uuid_generate_v4(),
  sx_id       uuid not null references public.profiles(id) on delete cascade,
  tx_id       uuid references public.profiles(id),
  type        text not null,
  payload     jsonb not null default '{}',
  created_at  timestamptz default now()
);

-- ═══════════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS)
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.profiles     enable row level security;
alter table public.familles     enable row level security;
alter table public.patterns     enable row level security;
alter table public.grooves      enable row level security;
alter table public.encyclo      enable row level security;
alter table public.parcours     enable row level security;
alter table public.student_data enable row level security;

-- Helper : rôle de l'utilisateur courant
create or replace function public.current_role_name()
returns text language sql security definer as $$
  select role from public.profiles where id = auth.uid();
$$;

-- ── Profiles ─────────────────────────────────────────────────────────────────
create policy "Lecture profil propre ou MX"  on public.profiles for select
  using (id = auth.uid() or public.current_role_name() = 'mx');

create policy "Mise à jour profil propre ou MX" on public.profiles for update
  using (id = auth.uid() or public.current_role_name() = 'mx');

-- ── Familles ─────────────────────────────────────────────────────────────────
create policy "Lecture familles" on public.familles for select
  using (
    auth.uid() is not null and
    (scope = 'school' or owner_id = auth.uid() or public.current_role_name() = 'mx')
  );

create policy "Insert famille teacher/mx" on public.familles for insert
  with check (auth.uid() is not null);

create policy "Update famille proprio ou MX" on public.familles for update
  using (owner_id = auth.uid() or public.current_role_name() = 'mx');

create policy "Delete famille proprio ou MX" on public.familles for delete
  using (owner_id = auth.uid() or public.current_role_name() = 'mx');

-- ── Patterns ─────────────────────────────────────────────────────────────────
create policy "Lecture patterns" on public.patterns for select
  using (
    auth.uid() is not null and
    (
      (scope = 'school' and approved = true)
      or owner_id = auth.uid()
      or public.current_role_name() = 'mx'
    )
  );

create policy "Insert pattern" on public.patterns for insert
  with check (auth.uid() is not null and owner_id = auth.uid());

create policy "Update pattern proprio ou MX" on public.patterns for update
  using (owner_id = auth.uid() or public.current_role_name() = 'mx');

create policy "Delete pattern proprio ou MX" on public.patterns for delete
  using (owner_id = auth.uid() or public.current_role_name() = 'mx');

-- ── Grooves ──────────────────────────────────────────────────────────────────
create policy "Lecture grooves" on public.grooves for select
  using (
    auth.uid() is not null and
    (
      (scope = 'school' and approved = true)
      or owner_id = auth.uid()
      or public.current_role_name() = 'mx'
    )
  );

create policy "Insert groove" on public.grooves for insert
  with check (auth.uid() is not null and owner_id = auth.uid());

create policy "Update groove proprio ou MX" on public.grooves for update
  using (owner_id = auth.uid() or public.current_role_name() = 'mx');

create policy "Delete groove proprio ou MX" on public.grooves for delete
  using (owner_id = auth.uid() or public.current_role_name() = 'mx');

-- ── Encyclopédie ─────────────────────────────────────────────────────────────
create policy "Lecture encyclo" on public.encyclo for select
  using (
    auth.uid() is not null and
    (scope = 'school' or owner_id = auth.uid() or public.current_role_name() = 'mx')
  );

create policy "Insert encyclo" on public.encyclo for insert
  with check (auth.uid() is not null);

create policy "Update encyclo proprio ou MX" on public.encyclo for update
  using (owner_id = auth.uid() or public.current_role_name() = 'mx');

-- ── Parcours ─────────────────────────────────────────────────────────────────
create policy "Lecture parcours propre ou MX" on public.parcours for select
  using (owner_id = auth.uid() or public.current_role_name() = 'mx');

create policy "CRUD parcours propre" on public.parcours for all
  using (owner_id = auth.uid() or public.current_role_name() = 'mx');

-- ── Données élèves ───────────────────────────────────────────────────────────
create policy "Lecture student_data" on public.student_data for select
  using (
    sx_id = auth.uid()
    or tx_id = auth.uid()
    or public.current_role_name() = 'mx'
  );

create policy "Insert student_data" on public.student_data for insert
  with check (sx_id = auth.uid());

-- ── Presets métronome (v3.4.50) ──────────────────────────────────────────────
-- Un preset encode : beatsPerMeasure, subdivision, metroPattern (accents)
-- TX peut proposer un preset, MX approuve (même workflow que patterns/grooves)
create table public.metro_presets (
  id                 text primary key,
  label              text not null,
  beats_per_measure  int  not null,
  beat_unit          int  not null default 4,
  subdivision        int  not null default 2,
  step_unit          int  not null default 8,
  metro_pattern      text[]        not null,
  scope              text not null default 'school' check (scope in ('school','teacher')),
  source             text not null default 'school' check (source in ('base','school','teacher')),
  approved           bool not null default true,
  owner_id           uuid references auth.users(id) on delete set null,
  created_at         timestamptz default now(),
  updated_at         timestamptz default now()
);
alter table public.metro_presets enable row level security;

-- SELECT : école approuvé OU owner=moi OU MX
create policy "Lecture metro_presets"     on public.metro_presets for select
  using ((scope='school' and approved=true) or owner_id=auth.uid() or public.current_role_name()='mx');

-- INSERT : utilisateur authentifié, owner=moi
create policy "Insert metro_presets"      on public.metro_presets for insert
  with check (auth.uid() is not null and owner_id=auth.uid());

-- UPDATE : owner=moi OU MX
create policy "Update metro_presets"      on public.metro_presets for update
  using (owner_id=auth.uid() or public.current_role_name()='mx');

-- DELETE : owner=moi OU MX
create policy "Delete metro_presets"      on public.metro_presets for delete
  using (owner_id=auth.uid() or public.current_role_name()='mx');

-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION — Pour bases existantes créées avant v3.1
-- Exécuter ce bloc séparément si vous avez déjà une base :
-- ═══════════════════════════════════════════════════════════════════════════
/*
alter table public.patterns
  drop column if exists unite_temps,
  drop column if exists pas_par_mesure;

alter table public.grooves
  drop column if exists vitesse_mult,
  add column if not exists signature text not null default '4/4';
*/

-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION v3.4.50 — Pour bases existantes (ajouter metro_presets)
-- Exécuter séparément si vous avez déjà une base v3.x :
-- ═══════════════════════════════════════════════════════════════════════════
-- (copier/coller le bloc CREATE TABLE metro_presets ci-dessus)

-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION v3.4.66 — Ajouter colonne source à metro_presets
-- ═══════════════════════════════════════════════════════════════════════════
/*
alter table public.metro_presets
  add column if not exists source text not null default 'school'
    check (source in ('base','school','teacher'));
*/

-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION v3.6.3 — Colonne ordre pour patterns, grooves, familles
-- À exécuter dans Supabase SQL Editor (une seule fois)
-- ═══════════════════════════════════════════════════════════════════════════
alter table public.patterns  add column if not exists ordre int default 0;
alter table public.grooves   add column if not exists ordre int default 0;
alter table public.familles  add column if not exists ordre int default 0;

-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION v3.7.0 — Familles dynamiques pour presets métronome
-- À exécuter dans Supabase SQL Editor (une seule fois)
-- ═══════════════════════════════════════════════════════════════════════════

-- Table des familles de métronome
create table if not exists public.metro_familles (
  id          text primary key,
  nom         text not null,
  scope       text not null default 'school' check (scope in ('school','teacher')),
  owner_id    uuid references auth.users(id) on delete set null,
  created_at  timestamptz default now(),
  ordre       int default 0
);
alter table public.metro_familles enable row level security;

create policy "Lecture metro_familles" on public.metro_familles for select
  using (scope='school' or owner_id=auth.uid() or public.current_role_name()='mx');
create policy "Insert metro_familles" on public.metro_familles for insert
  with check (auth.uid() is not null);
create policy "Update metro_familles" on public.metro_familles for update
  using (owner_id=auth.uid() or public.current_role_name()='mx');
create policy "Delete metro_familles" on public.metro_familles for delete
  using (owner_id=auth.uid() or public.current_role_name()='mx');

-- Colonnes familles_ids et ordre sur metro_presets
alter table public.metro_presets
  add column if not exists familles_ids text[] default '{}',
  add column if not exists ordre        int    default 0;

-- ═══════════════════════════════════════════════════════════════════════════
-- SEED INITIAL — Exécuter seed_school_pool.sql après ce schéma
-- ═══════════════════════════════════════════════════════════════════════════
