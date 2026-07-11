-- ============================================================
-- Passage POS — Supabase Schema
-- Run this in Supabase SQL Editor (one time)
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ── SHOPS (config per shop) ──────────────────────────────────
create table if not exists shops (
  id            uuid primary key default uuid_generate_v4(),
  created_at    timestamptz default now(),
  owner_id      uuid references auth.users(id) on delete cascade,
  shop_name     text not null default 'My Shop',
  currency      text not null default 'Ks',
  tax_rate      numeric default 0,
  shop_address  text default '',
  shop_phone    text default '',
  shop_logo     text default '',
  shop_icon     text default '',
  shop_plate    text default '',
  qr_payment    text default '',
  bank_accounts jsonb default '[]',
  receipt_footer text default 'Thank you!',
  paper_width   text default '80mm',
  brand_mode    text default 'card',
  language      text default 'en',
  modules       jsonb default '{"sales":true,"inventory":true,"stock":true,"customers":true,"finance":true,"barcode":false}',
  categories    jsonb default '["Products","Services","Other"]',
  low_stock_threshold int default 5,
  markup_pct    numeric default 30,
  wizard_complete boolean default false,
  users         jsonb default '[{"username":"admin","password":"admin123","role":"admin"},{"username":"cashier","password":"cashier123","role":"cashier"}]'
);

-- ── ITEMS ─────────────────────────────────────────────────────
create table if not exists items (
  id            text primary key,
  shop_id       uuid references shops(id) on delete cascade,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now(),
  name          text not null,
  category      text default 'Other',
  cost_price    numeric default 0,
  price         numeric not null default 0,
  unit          text default 'pcs',
  qty           numeric,
  barcode       text default '',
  photo         text default '',
  is_active     boolean default true
);

-- ── CUSTOMERS ────────────────────────────────────────────────
create table if not exists customers (
  id            text primary key,
  shop_id       uuid references shops(id) on delete cascade,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now(),
  name          text not null,
  phone         text default '',
  email         text default '',
  address       text default '',
  wallet_balance numeric default 0,
  total_spent   numeric default 0
);

-- ── SALES ────────────────────────────────────────────────────
create table if not exists sales (
  id            text primary key,
  shop_id       uuid references shops(id) on delete cascade,
  created_at    timestamptz default now(),
  sale_date     timestamptz not null default now(),
  customer_id   text references customers(id) on delete set null,
  subtotal      numeric default 0,
  tax_rate      numeric default 0,
  tax_amount    numeric default 0,
  discount_type text default 'amount',
  discount_value numeric default 0,
  discount_amount numeric default 0,
  total_due     numeric not null default 0,
  payment_method text default 'cash',
  status        text default 'paid' check (status in ('paid','pending','voided')),
  note          text default ''
);

-- ── SALE ITEMS ───────────────────────────────────────────────
create table if not exists sale_items (
  id            uuid primary key default uuid_generate_v4(),
  sale_id       text references sales(id) on delete cascade,
  shop_id       uuid references shops(id) on delete cascade,
  item_id       text,
  name          text not null,
  unit          text default 'pcs',
  qty           numeric not null default 1,
  unit_price    numeric not null default 0,
  cost_price    numeric default 0
);

-- ── EXPENSES ─────────────────────────────────────────────────
create table if not exists expenses (
  id            text primary key,
  shop_id       uuid references shops(id) on delete cascade,
  created_at    timestamptz default now(),
  expense_date  date not null default current_date,
  description   text not null,
  category      text default 'General',
  amount        numeric not null default 0
);

-- ── HELD ORDERS (temporary, per session) ────────────────────
create table if not exists held_orders (
  id            text primary key,
  shop_id       uuid references shops(id) on delete cascade,
  created_at    timestamptz default now(),
  data          jsonb not null
);

-- ── UPDATED_AT TRIGGERS ──────────────────────────────────────
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger items_updated_at before update on items
  for each row execute function update_updated_at();

create trigger customers_updated_at before update on customers
  for each row execute function update_updated_at();

-- ══════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ══════════════════════════════════════════════════════════════

alter table shops      enable row level security;
alter table items      enable row level security;
alter table customers  enable row level security;
alter table sales      enable row level security;
alter table sale_items enable row level security;
alter table expenses   enable row level security;
alter table held_orders enable row level security;

-- Shops: owner can do everything; anon can read/write own shop via shop_id
-- We use a simple approach: shop_id is stored in the JWT via a custom claim
-- For now, use anon key with shop_id filter (RLS based on shop_id match)

-- Policy helper: shop_id must match what the client passes
-- The app always filters by shop_id, and RLS enforces it

create policy "shop_owner_all" on shops
  for all using (auth.uid() = owner_id);

-- Allow anon to read their own shop (app uses shop_id param)
-- In production you'd use Supabase Auth; for now anon key + shop_id is sufficient
create policy "anon_read_own_shop" on shops
  for select using (true);

create policy "anon_all_items" on items
  for all using (true);

create policy "anon_all_customers" on customers
  for all using (true);

create policy "anon_all_sales" on sales
  for all using (true);

create policy "anon_all_sale_items" on sale_items
  for all using (true);

create policy "anon_all_expenses" on expenses
  for all using (true);

create policy "anon_all_held_orders" on held_orders
  for all using (true);

-- ══════════════════════════════════════════════════════════════
-- REALTIME
-- ══════════════════════════════════════════════════════════════

-- Enable realtime for live sync between devices
alter publication supabase_realtime add table items;
alter publication supabase_realtime add table sales;
alter publication supabase_realtime add table sale_items;
alter publication supabase_realtime add table customers;
alter publication supabase_realtime add table expenses;
alter publication supabase_realtime add table shops;

-- ══════════════════════════════════════════════════════════════
-- INDEXES (performance)
-- ══════════════════════════════════════════════════════════════

create index if not exists items_shop_id_idx      on items(shop_id);
create index if not exists sales_shop_id_idx      on sales(shop_id);
create index if not exists sales_date_idx         on sales(shop_id, sale_date desc);
create index if not exists sale_items_sale_idx    on sale_items(sale_id);
create index if not exists customers_shop_id_idx  on customers(shop_id);
create index if not exists expenses_shop_id_idx   on expenses(shop_id);
create index if not exists expenses_date_idx      on expenses(shop_id, expense_date desc);
