-- ============================================================
-- Passage POS v2 — Multi-tenant schema additions
-- Run this in Supabase SQL Editor AFTER schema.sql
-- ============================================================

-- ── SHOP REQUESTS ────────────────────────────────────────────
create table if not exists shop_requests (
  id            uuid primary key default uuid_generate_v4(),
  created_at    timestamptz default now(),
  shop_name     text not null,
  owner_name    text not null,
  email         text not null,
  phone         text default '',
  business_type text default 'general',
  plan          text default 'free' check (plan in ('free','pro')),
  status        text default 'pending' check (status in ('pending','approved','rejected')),
  notes         text default '',
  approved_at   timestamptz,
  rejected_at   timestamptz
);

-- ── ADD COLUMNS TO SHOPS ─────────────────────────────────────
alter table shops add column if not exists shop_code   text unique;
alter table shops add column if not exists plan        text default 'free' check (plan in ('free','pro'));
alter table shops add column if not exists status      text default 'active' check (status in ('active','suspended'));
alter table shops add column if not exists owner_name  text default '';
alter table shops add column if not exists owner_email text default '';
alter table shops add column if not exists owner_phone text default '';
alter table shops add column if not exists request_id  uuid references shop_requests(id);
alter table shops add column if not exists created_at  timestamptz default now();

-- ── GENERATE FRIENDLY SHOP CODES ─────────────────────────────
-- e.g. POS-A3F9 (easier to share than full UUID)
create or replace function generate_shop_code()
returns text as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code  text := 'POS-';
  i     int;
begin
  for i in 1..4 loop
    code := code || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  end loop;
  return code;
end;
$$ language plpgsql;

-- Auto-assign shop_code on insert if not set
create or replace function set_shop_code()
returns trigger as $$
begin
  if new.shop_code is null then
    loop
      new.shop_code := generate_shop_code();
      exit when not exists (select 1 from shops where shop_code = new.shop_code);
    end loop;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists shops_set_code on shops;
create trigger shops_set_code
  before insert on shops
  for each row execute function set_shop_code();

-- Backfill existing shops without codes
do $$
declare
  r record;
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
begin
  for r in select id from shops where shop_code is null loop
    loop
      code := 'POS-';
      for i in 1..4 loop
        code := code || substr(chars, floor(random() * length(chars) + 1)::int, 1);
      end loop;
      exit when not exists (select 1 from shops where shop_code = code);
    end loop;
    update shops set shop_code = code where id = r.id;
  end loop;
end $$;

-- RLS for shop_requests (anon can insert, only service role can update)
alter table shop_requests enable row level security;
create policy "anon_insert_requests" on shop_requests for insert with check (true);
create policy "anon_read_own_request" on shop_requests for select using (true);
create policy "anon_update_requests" on shop_requests for update using (true);

-- Index
create index if not exists shops_code_idx on shops(shop_code);
create index if not exists shops_email_idx on shops(owner_email);
create index if not exists requests_status_idx on shop_requests(status);
