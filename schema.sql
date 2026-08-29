-- =====================================================================
-- PRIME TRANSLADO — Schema Supabase / Postgres
-- =====================================================================
-- Como aplicar:
--   1. Supabase Dashboard > SQL Editor > cole este arquivo inteiro > Run
--   2. Ou via CLI: supabase db execute -f schema.sql
-- =====================================================================

-- Extensão pra gerar UUIDs
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- 1. TRANSPORTADORES
-- ---------------------------------------------------------------------
create table if not exists als_transportadores (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  cnpj        text,
  telefone    text,
  instagram   text,
  logo_url    text,
  is_padrao   boolean not null default false,
  created_at  timestamptz not null default now()
);

-- Garante que só existe UM transportador padrão por vez
create unique index if not exists uq_als_transportador_padrao
  on als_transportadores (is_padrao)
  where is_padrao = true;

-- ---------------------------------------------------------------------
-- 2. CLIENTES
-- ---------------------------------------------------------------------
create table if not exists als_clientes (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  telefone    text,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3. VOUCHERS
-- ---------------------------------------------------------------------

-- Sequence dedicada pra numeração automática (evita corrida/duplicidade)
create sequence if not exists als_vouchers_numero_seq start 76;

create table if not exists als_vouchers (
  id                  uuid primary key default gen_random_uuid(),
  numero              integer not null default nextval('als_vouchers_numero_seq'),

  cliente_id          uuid references als_clientes(id) on delete restrict,
  transportador_id    uuid references als_transportadores(id) on delete restrict,

  agencia_nome        text,

  num_adultos         integer not null default 0,
  num_criancas        integer not null default 0,
  num_bebes           integer not null default 0,

  valor               numeric(10,2),
  servico_descricao   text,

  data_ida            date,
  origem_ida          text,
  destino_ida         text,
  horario_ida         time,
  voo_ida             text,

  data_volta          date,
  origem_volta        text,
  destino_volta       text,
  horario_volta       time,
  voo_volta           text,

  observacoes         text,
  atendente           text,
  motorista            text,
  veiculo             text,
  data_atendimento    date,

  pdf_agencia_url     text,  -- link do PDF (com valor) salvo no Storage
  pdf_cliente_url     text,  -- link do PDF (sem valor) salvo no Storage

  created_at          timestamptz not null default now()
);

-- Garante que o número nunca se repete (defesa extra além da sequence)
create unique index if not exists uq_als_vouchers_numero on als_vouchers (numero);

-- Índices úteis pra busca no dashboard
create index if not exists idx_als_vouchers_cliente   on als_vouchers (cliente_id);
create index if not exists idx_als_vouchers_agencia    on als_vouchers (agencia_nome);
create index if not exists idx_als_vouchers_data_ida    on als_vouchers (data_ida);
create index if not exists idx_als_vouchers_created_at on als_vouchers (created_at desc);

-- ---------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY
-- ---------------------------------------------------------------------
-- Só usuário autenticado (login do irmão/amigo) lê e escreve.
-- A anon key fica exposta no front sem problema; quem protege é a RLS.

alter table als_transportadores enable row level security;
alter table als_clientes        enable row level security;
alter table als_vouchers        enable row level security;

-- TRANSPORTADORES
drop policy if exists "authenticated_all_als_transportadores" on als_transportadores;
create policy "authenticated_all_als_transportadores"
  on als_transportadores
  for all
  to authenticated
  using (true)
  with check (true);

-- CLIENTES
drop policy if exists "authenticated_all_als_clientes" on als_clientes;
create policy "authenticated_all_als_clientes"
  on als_clientes
  for all
  to authenticated
  using (true)
  with check (true);

-- VOUCHERS
drop policy if exists "authenticated_all_als_vouchers" on als_vouchers;
create policy "authenticated_all_als_vouchers"
  on als_vouchers
  for all
  to authenticated
  using (true)
  with check (true);

-- ---------------------------------------------------------------------
-- 5. STORAGE — bucket de logos (público, só leitura pra qualquer um)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('logos', 'logos', true)
on conflict (id) do nothing;

-- Leitura pública das logos (qualquer um pode ver, ninguém pode alterar)
drop policy if exists "public_read_logos" on storage.objects;
create policy "public_read_logos"
  on storage.objects
  for select
  to public
  using (bucket_id = 'logos');

-- Só autenticado pode subir/alterar/apagar logo
drop policy if exists "authenticated_write_logos" on storage.objects;
create policy "authenticated_write_logos"
  on storage.objects
  for all
  to authenticated
  using (bucket_id = 'logos')
  with check (bucket_id = 'logos');

-- Bucket opcional pra guardar os PDFs gerados (histórico)
insert into storage.buckets (id, name, public)
values ('als_vouchers-pdf', 'als_vouchers-pdf', true)
on conflict (id) do nothing;

drop policy if exists "public_read_vouchers_pdf" on storage.objects;
create policy "public_read_vouchers_pdf"
  on storage.objects
  for select
  to public
  using (bucket_id = 'als_vouchers-pdf');

drop policy if exists "authenticated_write_vouchers_pdf" on storage.objects;
create policy "authenticated_write_vouchers_pdf"
  on storage.objects
  for all
  to authenticated
  using (bucket_id = 'als_vouchers-pdf')
  with check (bucket_id = 'als_vouchers-pdf');

-- ---------------------------------------------------------------------
-- 6. SEED opcional — cadastra os dois als_transportadores já de cara
-- ---------------------------------------------------------------------
-- Descomente e edite com os dados reais antes de rodar:
--
-- insert into als_transportadores (nome, cnpj, telefone, instagram, is_padrao)
-- values
--   ('Prime Translado', '00.000.000/0000-00', '(00) 00000-0000', '@primetranslado', true),
--   ('Nome do Amigo',   null,                  '(00) 00000-0000', '@amigo_translado', false);
