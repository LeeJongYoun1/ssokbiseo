-- Supabase SQL Editor에서 한 번 실행한다. 하루 호출 횟수 카운터.
create table if not exists public.counters (
  k text primary key,
  n integer not null default 0,
  updated_at timestamptz not null default now()
);
-- RLS를 켜고 정책을 만들지 않으면 anon/authenticated는 표에 접근할 수 없다. 서버는 service_role로만 접근한다.
alter table public.counters enable row level security;

create or replace function public.incr_counter(p_key text) returns integer
language plpgsql security definer set search_path = public as $$
declare v integer;
begin
  delete from public.counters where updated_at < now() - interval '2 days'; -- 옛 날짜 키 정리
  insert into public.counters (k, n) values (p_key, 1)
    on conflict (k) do update set n = counters.n + 1, updated_at = now()
    returning n into v;
  return v;
end $$;

revoke all on function public.incr_counter(text) from public, anon, authenticated;
grant execute on function public.incr_counter(text) to service_role;
