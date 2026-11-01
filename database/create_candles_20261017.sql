-- MIGRAÇÃO DE REFERÊNCIA. Já aplicada no projeto Supabase exclusivo em 17/10/2026.
-- Nunca execute em bancos dos outros aplicativos.
create extension if not exists pgcrypto;

create table public.candles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid(),
  uf text not null constraint valid_uf check (uf in
    ('AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO')),
  cause text not null constraint valid_cause check (cause in
    ('democracia','justica','politicas','paz')),
  lit_on date not null default ((now() at time zone 'America/Sao_Paulo')::date),
  created_at timestamptz not null default now(),
  constraint unique_daily_candle unique(user_id, lit_on)
);
create index candles_day_created_idx on public.candles(lit_on, created_at desc, id desc);

alter table public.candles enable row level security;
revoke all on public.candles from public, anon, authenticated;
grant select (id, uf, cause, lit_on, created_at) on public.candles to anon, authenticated;
grant insert (uf, cause) on public.candles to authenticated;

create policy "Leitura pública de velas recentes" on public.candles
for select to anon, authenticated
using (
  lit_on >= (now() at time zone 'America/Sao_Paulo')::date - 7
  and lit_on <= (now() at time zone 'America/Sao_Paulo')::date
);
create policy "Uma vela por pessoa e dia" on public.candles
for insert to authenticated
with check (
  auth.uid() is not null
  and user_id = (select auth.uid())
  and lit_on = (now() at time zone 'America/Sao_Paulo')::date
);

create view public.daily_candle_stats with (security_invoker=true) as
select lit_on, count(*)::integer as total_candles, count(distinct uf)::integer as total_ufs
from public.candles group by lit_on;
revoke all on public.daily_candle_stats from public, anon, authenticated;
grant select on public.daily_candle_stats to anon, authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='candles'
  ) then
    alter publication supabase_realtime add table public.candles;
  end if;
end
$$;
