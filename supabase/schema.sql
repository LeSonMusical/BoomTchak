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
  -- Les emails du domaine scolaire reçoivent le rôle tx par défaut.
  -- Le MX peut ensuite changer le rôle manuellement.
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
  id          text primary key,          -- ex: 'fam_afrocubain'
  nom         text not null,
  scope       text not null default 'school' check (scope in ('school','teacher')),
  owner_id    uuid references public.profiles(id) on delete cascade,
  created_at  timestamptz default now()
);

-- ── Patterns ─────────────────────────────────────────────────────────────────
create table public.patterns (
  id              text primary key,
  nom             text not null,
  sequence        text not null,         -- ex: 'X..X..X.'
  pas             int not null,
  unite_temps     text not null default '1/8',
  pas_par_mesure  int not null default 8,
  familles_ids    text[] default '{}',   -- tableau d'IDs de familles
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
  vitesse_mult  numeric default 1,
  layers        jsonb not null default '[]', -- tableau de {id,patternId,mute,shift,halfOn,doubleOn,ternOn}
  scope         text not null default 'teacher' check (scope in ('school','teacher')),
  approved      boolean default false,
  owner_id      uuid references public.profiles(id) on delete cascade,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- ── Encyclopédie ─────────────────────────────────────────────────────────────
create table public.encyclo (
  key         text primary key,           -- ex: 'tres', 'salsa32'
  chapo       text default '',
  bullets     jsonb default '[]',         -- [["Titre","Texte"], ...]
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
  type        text not null,             -- 'pattern','response','score'
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
-- Lecture : tout le monde (authentifié) voit les familles école + les siennes
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

-- ═══════════════════════════════════════════════════════════════════════════
-- SEED INITIAL — À exécuter après avoir activé le login MX
-- Copier le contenu PTK_DEFAULT de l'app dans le pool école.
-- Utiliser le script seed_school_pool.js (voir README).
-- ═══════════════════════════════════════════════════════════════════════════
