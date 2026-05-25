-- plan
create table plan (
  plan_id  serial primary key,
  name     varchar(100) not null,
  lists_limit                  int not null,
  shared_lists_limit           int not null,
  members_per_shared_list      int not null,
  monthly_receipt_scan_limit   int not null
);

insert into plan (name, lists_limit, shared_lists_limit, members_per_shared_list, monthly_receipt_scan_limit) values
  ('Free', 5,  2,  5,  10),
  ('Pro',  50, 20, 20, 100);

-- "user"
create table "user" (
  id                    uuid        primary key references auth.users(id) on delete cascade,
  plan_id               int         not null references plan(plan_id),
  display_name          varchar(500) not null,
  email                 varchar(320) unique not null,
  joined_at             timestamptz not null default now(),
  password_hash         text,                         -- always null (Supabase owns auth)
  auth_provider         varchar(50)  not null,
  google_id             varchar(255),
  theme                 varchar(10)  not null default 'system',
  lang                  varchar(2)   not null default 'en',
  notifications_enabled boolean      not null default true
);

-- store
create table store (
  id        serial primary key,
  name      varchar(100) unique not null,
  logo_url  text,
  supported boolean not null default true
);

-- shopping_list
create table shopping_list (
  id                  serial primary key,
  created_by_user_id  uuid         not null references "user"(id) on delete cascade,
  name                varchar(500) not null,
  created_at          timestamptz  not null default now(),
  updated_at          timestamptz  not null default now()
);

-- shopping_list_member
create table shopping_list_member (
  id                serial primary key,
  user_id           uuid not null references "user"(id) on delete cascade,
  shopping_list_id  int  not null references shopping_list(id) on delete cascade,
  role              varchar(20) not null,   -- owner | member
  joined_at         timestamptz not null default now(),
  unique(shopping_list_id, user_id)
);

create index on shopping_list_member(shopping_list_id);
create index on shopping_list_member(user_id);

-- category
create table category (
  id    serial primary key,
  slug  text         not null unique,
  icon  varchar(500)          -- flutter icon name, e.g. 'eco_rounded'
);

insert into category (slug, icon) values
  ('fruits_and_vegetables',            'eco_rounded'),
  ('meat',                             'lunch_dining_rounded'),
  ('fish_and_seafood',                 'phishing_rounded'),
  ('dairy_products',                   'local_drink_rounded'),
  ('eggs',                             'egg_alt_rounded'),
  ('bakery',                           'bakery_dining_rounded'),
  ('pantry_staples',                   'rice_bowl_rounded'),
  ('cans_and_jars',                    'inventory_2_rounded'),
  ('seasonings_sauces_and_condiments', 'soup_kitchen_rounded'),
  ('frozen_foods',                     'ac_unit_rounded'),
  ('snacks_and_sweets',                'cookie_rounded'),
  ('drinks',                           'water_drop_rounded'),
  ('coffee_and_tea',                   'coffee_rounded'),
  ('baby_products',                    'child_friendly_rounded'),
  ('pet_supplies',                     'pets_rounded'),
  ('personal_care',                    'spa_rounded'),
  ('household_supplies',               'home_rounded'),
  ('cleaning_supplies',                'clean_hands_rounded'),
  ('home_and_garden',                  'yard_rounded'),
  ('other',                            'category_rounded');

-- shopping_list_item
create table shopping_list_item (
  id                serial primary key,
  name              varchar(500) not null,
  shopping_list_id  int  not null references shopping_list(id) on delete cascade,
  added_by_user_id  uuid not null references "user"(id),
  is_bought         bool not null default false,
  bought_by_user_id uuid references "user"(id),
  bought_at         timestamptz,
  quantity          int,
  unit              varchar(100),
  category_id       int  references category(id) on delete set null,
  added_at          timestamptz not null default now(),
  edited_at         timestamptz not null default now()
);

create index on shopping_list_item(shopping_list_id);
create index on shopping_list_item(is_bought);

-- shopping_list_invitation
-- Only pending rows live here; accepted/declined rows are deleted.
create table shopping_list_invitation (
  id                    serial primary key,
  invited_by_user_id    uuid not null references "user"(id),
  invited_user_id       uuid not null references "user"(id),
  shopping_list_id      int  not null references shopping_list(id) on delete cascade,
  sent_at               timestamptz not null default now(),
  expires_at            timestamptz not null,
  unique(shopping_list_id, invited_by_user_id, invited_user_id)
);

create index on shopping_list_invitation(shopping_list_id);
create index on shopping_list_invitation(invited_by_user_id);
create index on shopping_list_invitation(invited_user_id);

-- receipt
create table receipt (
  id            serial primary key,
  user_id       uuid not null references "user"(id) on delete cascade,
  store_id      int references store(id),  -- null when store is unrecognised
  total         int  not null,             -- cents
  receipt_date  date not null,
  scanned_at    timestamptz not null default now(),
  raw_ocr       text not null
);

create index on receipt(user_id);
create index on receipt(store_id);

-- receipt_item
create table receipt_item (
  id           serial primary key,
  receipt_id   int  not null references receipt(id) on delete cascade,
  name         text not null,
  quantity     int  not null default 1,
  unit_price   int  not null,  -- cents
  total_price  int  not null   -- cents
);

create index on receipt_item(receipt_id);

-- product
-- Filled by the scraper; never written by the app.
create table product (
  id              serial primary key,
  store_id        int  not null references store(id),
  name            text not null,
  sale_price      int  not null,   -- cents
  original_price  int  not null,   -- cents
  discount_pct    int  not null,
  image_url       text,
  valid_from      timestamptz,
  valid_to        timestamptz,
  scraped_at      timestamptz not null default now()
);

create index on product(store_id);
create index on product(valid_from, valid_to);

-- Trigger: create public."user" row + default shopping list on sign-up
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _display_name text;
  _auth_provider text;
  _google_id     text;
  _lang          text;
  _list_id       int;
begin
  _display_name := coalesce(
    new.raw_user_meta_data->>'display_name',   -- email sign-up
    new.raw_user_meta_data->>'full_name',       -- Google OAuth
    new.raw_user_meta_data->>'name',            -- fallback
    split_part(new.email, '@', 1)
  );

  _auth_provider := coalesce(
    new.raw_user_meta_data->>'auth_provider',   -- email sign-up
    new.raw_app_meta_data->>'provider',         -- Google OAuth ('google')
    'email'
  );

  _google_id := new.raw_user_meta_data->>'provider_id';
  _lang      := coalesce(new.raw_user_meta_data->>'lang', 'en');

  insert into public."user" (id, plan_id, display_name, email, joined_at, auth_provider, google_id, lang)
  values (new.id, 1, _display_name, new.email, now(), _auth_provider, _google_id, _lang);

  -- Create a default "My Shopping List" for the new user
  insert into public.shopping_list (created_by_user_id, name)
  values (new.id, 'My Shopping List')
  returning id into _list_id;

  insert into public.shopping_list_member (shopping_list_id, user_id, role)
  values (_list_id, new.id, 'owner');

  return new;
end;
$$;

-- Prevent this function being called directly by anyone
revoke execute on function public.handle_new_auth_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_auth_user();
