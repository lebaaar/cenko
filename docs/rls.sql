-- ═══════════════════════════════════════════════════════════════════════════
-- CENKO — RLS policies
-- Run this after schema.sql.
-- ═══════════════════════════════════════════════════════════════════════════

-- private schema
-- PostgREST only exposes the public schema via REST, so functions placed here
-- cannot be called directly by clients — fixing the two security warnings:
--   "Public Can Execute SECURITY DEFINER Function"
--   "Signed-In Users Can Execute SECURITY DEFINER Function"
create schema if not exists private;

-- Allow authenticated users to use this schema (needed for RLS to call the fn)
grant usage on schema private to authenticated;

-- Helper function
--
-- Returns all shopping_list_ids the current user belongs to as a member.
-- SECURITY DEFINER lets it query shopping_list_member without triggering that
-- table's own RLS policy, which breaks the mutual recursion that would
-- otherwise occur between the shopping_list ↔ shopping_list_member policies.
--
-- Lives in private schema → not callable via REST → no security warning.
--
create or replace function private.get_my_shopping_list_ids()
returns setof integer
language sql
security definer
set search_path = public
stable
as $$
  select shopping_list_id from shopping_list_member where user_id = auth.uid()
$$;

-- Only authenticated role may execute it (anon gets nothing)
grant execute on function private.get_my_shopping_list_ids() to authenticated;

-- Enable RLS on every table
alter table plan                     enable row level security;
alter table "user"                   enable row level security;
alter table store                    enable row level security;
alter table product                  enable row level security;
alter table shopping_list            enable row level security;
alter table shopping_list_member     enable row level security;
alter table shopping_list_item       enable row level security;
alter table shopping_list_invitation enable row level security;
alter table receipt                  enable row level security;
alter table receipt_item             enable row level security;

-- plan
-- Read-only, all authenticated users
create policy "plan: authenticated read"
  on plan for select to authenticated using (true);

-- "user"
-- All authenticated users can read all profiles (needed for invitation lookups
-- and member name display).
-- password_hash is always null — Supabase manages passwords in auth schema.
create policy "user: authenticated read all"
  on "user" for select to authenticated using (true);

-- INSERT is handled by the handle_new_auth_user trigger (security definer).
-- No client insert policy needed.

create policy "user: update own"
  on "user" for update to authenticated
  using  (id = auth.uid())
  with check (id = auth.uid());

-- DELETE cascades from auth.users deletion — no client delete policy needed.

-- store
create policy "store: authenticated read"
  on store for select to authenticated using (true);

-- product
create policy "product: authenticated read"
  on product for select to authenticated using (true);

-- shopping_list
-- A user can see a list if they created it or if they are a member.
-- Uses the private security-definer helper to avoid cross-table recursion
-- with shopping_list_member.
create policy "shopping_list: read own or member"
  on shopping_list for select to authenticated using (
    created_by_user_id = auth.uid()
    or id = any(array(select private.get_my_shopping_list_ids()))
  );

create policy "shopping_list: insert own"
  on shopping_list for insert to authenticated
  with check (created_by_user_id = auth.uid());

-- Any member (owner or not) can update the list row (name, updated_at, etc.).
-- Delete is the owner-only privilege, not update.
create policy "shopping_list: update members"
  on shopping_list for update to authenticated
  using  (id = any(array(select private.get_my_shopping_list_ids())))
  with check (id = any(array(select private.get_my_shopping_list_ids())));

create policy "shopping_list: delete own"
  on shopping_list for delete to authenticated
  using (created_by_user_id = auth.uid());

-- shopping_list_member
-- Uses the private security-definer helper to avoid self-referential recursion.
-- The creator is always inserted as a member in createList, so no separate
-- creator branch is needed here.
create policy "shopping_list_member: read"
  on shopping_list_member for select to authenticated using (
    shopping_list_id = any(array(select private.get_my_shopping_list_ids()))
  );

-- List creator can add any member directly (e.g. adding self as owner on
-- creation via trigger or app code).
-- Invited users can add themselves when a pending invitation exists for them.
create policy "shopping_list_member: creator insert or accept invitation"
  on shopping_list_member for insert to authenticated
  with check (
    shopping_list_id in (
      select id from shopping_list where created_by_user_id = auth.uid()
    )
    or (
      user_id = auth.uid()
      and shopping_list_id in (
        select shopping_list_id from shopping_list_invitation
        where invited_user_id = auth.uid()
      )
    )
  );

-- Members can leave a list themselves; list owners can remove any member.
create policy "shopping_list_member: leave or owner remove"
  on shopping_list_member for delete to authenticated using (
    user_id = auth.uid()
    or shopping_list_id in (
      select id from shopping_list where created_by_user_id = auth.uid()
    )
  );

-- shopping_list_item
-- All policies use the private security-definer helper so they don't chain
-- through shopping_list_member's own RLS policy.
create policy "shopping_list_item: members read"
  on shopping_list_item for select to authenticated using (
    shopping_list_id = any(array(select private.get_my_shopping_list_ids()))
  );

create policy "shopping_list_item: members insert"
  on shopping_list_item for insert to authenticated
  with check (
    added_by_user_id = auth.uid()
    and shopping_list_id = any(array(select private.get_my_shopping_list_ids()))
  );

create policy "shopping_list_item: members update"
  on shopping_list_item for update to authenticated using (
    shopping_list_id = any(array(select private.get_my_shopping_list_ids()))
  );

create policy "shopping_list_item: members delete"
  on shopping_list_item for delete to authenticated using (
    shopping_list_id = any(array(select private.get_my_shopping_list_ids()))
  );

-- shopping_list_invitation
create policy "shopping_list_invitation: inviter or invited read"
  on shopping_list_invitation for select to authenticated using (
    invited_by_user_id = auth.uid() or invited_user_id = auth.uid()
  );

-- Any list member can send an invitation.
create policy "shopping_list_invitation: members can invite"
  on shopping_list_invitation for insert to authenticated
  with check (
    invited_by_user_id = auth.uid()
    and shopping_list_id = any(array(select private.get_my_shopping_list_ids()))
  );

-- Inviter can cancel; invited user can accept or decline (both paths delete the row).
create policy "shopping_list_invitation: inviter or invited delete"
  on shopping_list_invitation for delete to authenticated using (
    invited_by_user_id = auth.uid() or invited_user_id = auth.uid()
  );

-- receipt
create policy "receipt: own read"
  on receipt for select to authenticated using (user_id = auth.uid());

create policy "receipt: own insert"
  on receipt for insert to authenticated
  with check (user_id = auth.uid());

create policy "receipt: own update"
  on receipt for update to authenticated
  using (user_id = auth.uid());

create policy "receipt: own delete"
  on receipt for delete to authenticated
  using (user_id = auth.uid());

-- receipt_item
-- Access is gated through the parent receipt row.
create policy "receipt_item: own read"
  on receipt_item for select to authenticated using (
    receipt_id in (select id from receipt where user_id = auth.uid())
  );

create policy "receipt_item: own insert"
  on receipt_item for insert to authenticated
  with check (
    receipt_id in (select id from receipt where user_id = auth.uid())
  );

create policy "receipt_item: own update"
  on receipt_item for update to authenticated
  using (
    receipt_id in (select id from receipt where user_id = auth.uid())
  );

create policy "receipt_item: own delete"
  on receipt_item for delete to authenticated using (
    receipt_id in (select id from receipt where user_id = auth.uid())
  );
