// deno-lint-ignore-file no-explicit-any
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return json({ error: 'Missing or invalid authorization header' }, 401)
  }

  const token = authHeader.slice(7)

  // Admin client — service role bypasses RLS for cleanup queries
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  )

  // Verify caller JWT → get uid
  const { data: { user }, error: authError } = await admin.auth.getUser(token)
  if (authError || !user) return json({ error: 'Unauthorized' }, 401)

  const uid = user.id

  try {
    //  1. Fetch owned lists with their members
    const { data: ownedLists, error: ownedErr } = await admin
      .from('shopping_list')
      .select('id, name, shopping_list_member(user_id)')
      .eq('created_by_user_id', uid)
    if (ownedErr) throw ownedErr

    //  2. Block if any owned list has other members
    const blockedLists = (ownedLists ?? []).filter((list: any) =>
      (list.shopping_list_member as Array<{ user_id: string }>)
        .some((m) => m.user_id !== uid)
    )
    if (blockedLists.length > 0) {
      return json({
        error: 'Cannot delete account while owning shared lists. Transfer ownership or delete them first.',
        owned_lists: blockedLists.map((l: any) => l.name as string),
      }, 409)
    }

    //  3. Null out bought_by_user_id (nullable FK, no ON DELETE rule)
    const { error: boughtErr } = await admin
      .from('shopping_list_item')
      .update({ bought_by_user_id: null })
      .eq('bought_by_user_id', uid)
    if (boughtErr) throw boughtErr

    //  4. Delete items added by user on lists they don't own
    //    added_by_user_id is NOT NULL with no ON DELETE — must clean manually
    //    before the auth user delete to avoid FK violation.
    const ownedListIds = (ownedLists ?? []).map((l: any) => l.id as number)

    const { data: memberRows, error: memberErr } = await admin
      .from('shopping_list_member')
      .select('shopping_list_id')
      .eq('user_id', uid)
    if (memberErr) throw memberErr

    const nonOwnedListIds = (memberRows ?? [])
      .map((r: any) => r.shopping_list_id as number)
      .filter((id) => !ownedListIds.includes(id))

    if (nonOwnedListIds.length > 0) {
      const { error: itemsErr } = await admin
        .from('shopping_list_item')
        .delete()
        .eq('added_by_user_id', uid)
        .in('shopping_list_id', nonOwnedListIds)
      if (itemsErr) throw itemsErr
    }

    //  5. Delete pending invitations sent or received
    //    invited_by_user_id and invited_user_id have no ON DELETE cascade.
    const { error: invErr } = await admin
      .from('shopping_list_invitation')
      .delete()
      .or(`invited_by_user_id.eq.${uid},invited_user_id.eq.${uid}`)
    if (invErr) throw invErr

    //  6. Delete auth user
    //    Cascade chain:
    //      auth.users → public.user
    //                 → shopping_list (owned) → shopping_list_member
    //                                         → shopping_list_item
    //                                         → shopping_list_invitation (list cascade)
    //                 → shopping_list_member (membership rows)
    //                 → receipt → receipt_item
    const { error: deleteErr } = await admin.auth.admin.deleteUser(uid)
    if (deleteErr) throw deleteErr

    console.log(`[delete-my-account] deleted uid=${uid}`)
    return json({ success: true })
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Internal server error'
    console.error(`[delete-my-account] error uid=${uid}:`, err)
    return json({ error: message }, 500)
  }
})
