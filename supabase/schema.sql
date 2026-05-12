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
-- MIGRATION v3.8.37 — Lecture publique (anon) pour contenus école approuvés
-- Permet aux utilisateurs non connectés de charger la base dès le démarrage.
-- À exécuter dans Supabase SQL Editor (une seule fois, par le MX).
-- Note : CREATE POLICY IF NOT EXISTS non supporté avant PG17 → bloc DO
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='patterns' AND policyname='Lecture publique school patterns') THEN
    CREATE POLICY "Lecture publique school patterns" ON public.patterns FOR SELECT
      USING (scope = 'school' AND approved = true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='grooves' AND policyname='Lecture publique school grooves') THEN
    CREATE POLICY "Lecture publique school grooves" ON public.grooves FOR SELECT
      USING (scope = 'school' AND approved = true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='familles' AND policyname='Lecture publique school familles') THEN
    CREATE POLICY "Lecture publique school familles" ON public.familles FOR SELECT
      USING (scope = 'school');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='encyclo' AND policyname='Lecture publique school encyclo') THEN
    CREATE POLICY "Lecture publique school encyclo" ON public.encyclo FOR SELECT
      USING (scope = 'school');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='metro_presets' AND policyname='Lecture publique school metro_presets') THEN
    CREATE POLICY "Lecture publique school metro_presets" ON public.metro_presets FOR SELECT
      USING (scope = 'school' AND approved = true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='metro_familles' AND policyname='Lecture publique school metro_familles') THEN
    CREATE POLICY "Lecture publique school metro_familles" ON public.metro_familles FOR SELECT
      USING (scope = 'school');
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION v3.8.53 — Paramètres metro embarqués dans grooves + raison de refus
-- À exécuter dans Supabase SQL Editor (une seule fois, par le MX).
-- ═══════════════════════════════════════════════════════════════════════════

-- Colonne metro (jsonb) : paramètres métronome embarqués dans le groove
-- { swing, felBeatSteps, beatsPerMeasure, beatUnit, subdivision }
alter table public.grooves
  add column if not exists metro jsonb default null;

-- Colonne reject_reason : raison de refus MX — lue par TX puis supprimée
alter table public.patterns
  add column if not exists reject_reason text default null;
alter table public.grooves
  add column if not exists reject_reason text default null;

-- Politique UPDATE pour MX sur les items teacher (pour pouvoir écrire reject_reason)
create policy if not exists "MX peut patcher patterns teacher" on public.patterns for update
  using (public.current_role_name() = 'mx');
create policy if not exists "MX peut patcher grooves teacher" on public.grooves for update
  using (public.current_role_name() = 'mx');

-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION v3.9.0 — Table bands (presets d'instruments) + band_familles
-- À exécuter dans Supabase SQL Editor (une seule fois, par le MX).
-- ═══════════════════════════════════════════════════════════════════════════

-- Familles de bands (partagées par tous les roles)
create table if not exists public.band_familles (
  id          text primary key,
  nom         text not null,
  scope       text not null default 'school' check (scope in ('school','teacher')),
  owner_id    uuid references public.profiles(id) on delete set null,
  ordre       int  default 0,
  created_at  timestamptz default now()
);

alter table public.band_familles enable row level security;

drop policy if exists "Lecture band_familles school"            on public.band_familles;
drop policy if exists "Insert band_familles"                    on public.band_familles;
drop policy if exists "Update/delete band_familles owner ou MX" on public.band_familles;
drop policy if exists "Delete band_familles owner ou MX"        on public.band_familles;

create policy "Lecture band_familles school" on public.band_familles for select
  using (scope = 'school');
create policy "Insert band_familles" on public.band_familles for insert
  with check (auth.uid() is not null);
create policy "Update/delete band_familles owner ou MX" on public.band_familles for update
  using (owner_id = auth.uid() or public.current_role_name() = 'mx');
create policy "Delete band_familles owner ou MX" on public.band_familles for delete
  using (owner_id = auth.uid() or public.current_role_name() = 'mx');

-- Presets de bands
create table if not exists public.bands (
  id          text primary key,
  nom         text not null,
  familles_ids text[] default '{}',
  -- Sons par layer
  low         text,  low_pitch  real,
  high        text,  high_pitch real,
  noise       text,  noise_pitch real,
  thumb_l     text,  thumb_l_pitch real,
  thumb_r     text,  thumb_r_pitch real,
  -- Sample audio optionnel (prévu v3.9+)
  sample_url  text default null,
  scope       text not null default 'school' check (scope in ('school','teacher')),
  approved    bool default false,
  owner_id    uuid references public.profiles(id) on delete set null,
  ordre       int  default 0,
  reject_reason text default null,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

alter table public.bands enable row level security;

drop policy if exists "Lecture bands school approuvés" on public.bands;
drop policy if exists "Insert bands owner"             on public.bands;
drop policy if exists "Update bands owner ou MX"       on public.bands;
drop policy if exists "Delete bands owner ou MX"       on public.bands;
drop policy if exists "Lecture publique school bands"  on public.bands;

create policy "Lecture bands school approuvés" on public.bands for select
  using ((scope = 'school' and approved = true) or owner_id = auth.uid() or public.current_role_name() = 'mx');
create policy "Insert bands owner" on public.bands for insert
  with check (owner_id = auth.uid());
create policy "Update bands owner ou MX" on public.bands for update
  using (owner_id = auth.uid() or public.current_role_name() = 'mx');
create policy "Delete bands owner ou MX" on public.bands for delete
  using (owner_id = auth.uid() or public.current_role_name() = 'mx');
create policy "Lecture publique school bands" on public.bands for select
  using (scope = 'school' and approved = true);

-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION v3.10.0 — Tables sound_familles + sound_presets
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.sound_familles (
  id          text primary key,
  nom         text not null,
  scope       text not null default 'school' check (scope in ('school','teacher')),
  owner_id    uuid references public.profiles(id) on delete set null,
  ordre       int  default 0,
  created_at  timestamptz default now()
);
alter table public.sound_familles enable row level security;
drop policy if exists "Lecture sound_familles school"     on public.sound_familles;
drop policy if exists "Insert sound_familles"             on public.sound_familles;
drop policy if exists "Update sound_familles owner ou MX" on public.sound_familles;
drop policy if exists "Delete sound_familles owner ou MX" on public.sound_familles;
create policy "Lecture sound_familles school" on public.sound_familles for select using (scope='school');
create policy "Insert sound_familles" on public.sound_familles for insert with check (auth.uid() is not null);
create policy "Update sound_familles owner ou MX" on public.sound_familles for update using (owner_id=auth.uid() or public.current_role_name()='mx');
create policy "Delete sound_familles owner ou MX" on public.sound_familles for delete using (owner_id=auth.uid() or public.current_role_name()='mx');

create table if not exists public.sound_presets (
  id           text primary key,
  nom          text not null,
  sound_id     text not null,
  pitch        real default 200,
  env          real default 0.3,
  vol          real default 0.5,
  familles_ids text[] default '{}',
  scope        text not null default 'school' check (scope in ('school','teacher')),
  approved     bool default false,
  owner_id     uuid references public.profiles(id) on delete set null,
  ordre        int  default 0,
  reject_reason text default null,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);
alter table public.sound_presets enable row level security;
drop policy if exists "Lecture sound_presets school"          on public.sound_presets;
drop policy if exists "Insert sound_presets owner"            on public.sound_presets;
drop policy if exists "Update sound_presets owner ou MX"      on public.sound_presets;
drop policy if exists "Delete sound_presets owner ou MX"      on public.sound_presets;
drop policy if exists "Lecture publique school sound_presets" on public.sound_presets;
create policy "Lecture sound_presets school" on public.sound_presets for select using ((scope='school' and approved=true) or owner_id=auth.uid() or public.current_role_name()='mx');
create policy "Insert sound_presets owner" on public.sound_presets for insert with check (owner_id=auth.uid());
create policy "Update sound_presets owner ou MX" on public.sound_presets for update using (owner_id=auth.uid() or public.current_role_name()='mx');
create policy "Delete sound_presets owner ou MX" on public.sound_presets for delete using (owner_id=auth.uid() or public.current_role_name()='mx');
create policy "Lecture publique school sound_presets" on public.sound_presets for select using (scope='school' and approved=true);

-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION v3.10.20 — Colonne type sur familles (pattern/groove/both)
-- ═══════════════════════════════════════════════════════════════════════════
alter table public.familles add column if not exists type text not null default 'both'
  check (type in ('pattern','groove','both'));

-- ═══════════════════════════════════════════════════════════════════════════
-- SEED INITIAL — Exécuter seed_school_pool.sql après ce schéma
-- ═══════════════════════════════════════════════════════════════════════════
