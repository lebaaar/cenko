# Database schema

Cenko uses PostgreSQL relational database hosted on Supabase.
Database schema is available at [dbdiagram.io](https://dbdiagram.io/d/cenko-69cc2d8e78c6c4bc7ab354da), copu paste can be found bellow:

```dbml

Table user {
  id uuid [primary key, note: "matches auth.users(id)"]
  plan_id int [not null]
  display_name varchar(500) [not null]
  email varchar(320) [unique, not null]
  joined_at timestamptz [not null]
  password_hash text [null, note: "null if using SSO"]
  auth_provider varchar(50) [not null]
  google_id varchar(255) [null]
  theme varchar(10) [default: "system", note: "system, dark, light"]
  lang varchar(2) // en, sl
  notifications_enabled boolean [default: true]
}
Ref: user.plan_id > plan.plan_id

Table plan {
  plan_id int [primary key, increment]
  name varchar(100)  [not null, note: "Free, Pro"]
  lists_limit int [not null]
  shared_lists_limit int [not null]
  members_per_shared_list int [not null]
  monthly_receipt_scan_limit int [not null]
}

Table shopping_list {
  id int [primary key, increment]
  created_by_user_id uuid [not null]
  name varchar(500) [not null]
  created_at timestamptz [not null]
  updated_at timestamptz [not null]
}
Ref: shopping_list.created_by_user_id > user.id

Table shopping_list_item {
  id int [primary key, increment]
  name varchar(500) [not null]
  shopping_list_id int [not null]
  added_by_user_id uuid [not null]
  is_bought bool [not null]
  bought_by_user_id uuid [null]
  bought_at timestamptz [null]
  category varchar(100) [null]
  quantity int [null]
  unit varchar(100) [null]
  added_at timestamptz [not null]
  edited_at timestamptz [not null]
  Indexes {
    (shopping_list_id)
    (is_bought)
}
}
Ref: shopping_list_item.shopping_list_id > shopping_list.id
Ref: shopping_list_item.bought_by_user_id > user.id
Ref: shopping_list_item.added_by_user_id > user.id

Table shopping_list_member {
  id int [primary key, increment]
  user_id uuid [not null]
  shopping_list_id int [not null]
  role varchar(20) [not null, note: "use enum: owner | member. v1 supports only member, can be promoted to owner manually later."]
  joined_at timestamptz [not null]
  Indexes {
    (shopping_list_id)
    (user_id)
    (shopping_list_id, user_id) [unique]
  }
}
Ref: shopping_list_member.shopping_list_id > shopping_list.id
Ref: shopping_list_member.user_id > user.id

Table shopping_list_invitation [note: "Only pending entries live in this table. Accepted or declined get removed from table "] {
  id int [primary key, increment]
  invited_by_user_id uuid [not null]
  invited_user_id uuid [not null]
  shopping_list_id int [not null]
  sent_at timestamptz [not null]
  expires_at timestamptz [not null]
  Indexes {
    (shopping_list_id)
    (invited_by_user_id)
    (invited_user_id)
    (shopping_list_id, invited_by_user_id, invited_user_id) [unique]
  }
}
Ref: shopping_list_invitation.shopping_list_id > shopping_list.id
Ref: shopping_list_invitation.invited_by_user_id > user.id
Ref: shopping_list_invitation.invited_user_id > user.id

Table receipt {
  id int [primary key, increment]
  user_id uuid [not null]
  store_id int [null, note: "null if store is unrecognized"]
  total int [not null, note: "in cents"]
  receipt_date date [not null]
  scanned_at timestamptz [not null]
  raw_ocr text [not null]
  Indexes {
    (user_id)
    (store_id)
  }
}
Ref: receipt.user_id  > user.id
Ref: receipt.store_id > store.id

Table receipt_item {
  id int [primary key, increment]
  receipt_id int [not null]
  name text [not null]
  quantity int  [default: 1]
  unit_price int [not null, note: "in cents"]
  total_price int [not null, note: "in cents"]
  Indexes {
    (receipt_id)
  }
}
Ref: receipt_item.receipt_id  > receipt.id

Table store {
  id int [primary key, increment]
  name varchar(100) [not null, unique]
  logo_url text
  supported boolean [default: true, note: "if false = store is known but not yet fully supported"]
}

Table product [note: "scraper fills this table"] {
  id int [primary key, increment]
  store_id int [not null]
  name text [not null]
  sale_price int [not null, note: "in cents"]
  original_price int [not null, note: "in cents"]
  discount_pct int [not null]
  image_url text [null]
  valid_from timestamptz [null]
  valid_to timestamptz [null]
  scraped_at timestamptz [not null]
  Indexes {
    (store_id)
    (valid_from, valid_to)
  }
}
Ref: product.store_id  > store.id
```