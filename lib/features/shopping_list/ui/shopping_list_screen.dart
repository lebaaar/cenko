import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cenko/features/shopping_list/data/shopping_list.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_invitation.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_provider.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/providers/current_user_provider.dart';
import 'package:cenko/shared/widgets/top_bar.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _newListNameCtrl = TextEditingController();

  @override
  void dispose() {
    _newListNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final uid = authState.asData?.value?.uid;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: MainTopBar(
                title: 'Shopping Lists',
                trailing: uid == null
                    ? null
                    : IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _showCreateListDialog(context, uid), tooltip: 'New list'),
              ),
            ),
            Expanded(
              child: uid == null ? const Center(child: Text('Please sign in to view your shopping lists')) : _Body(uid: uid),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateListDialog(BuildContext context, String uid) async {
    _newListNameCtrl.clear();
    final currentUser = ref.read(currentUserProvider).asData?.value;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var creating = false;
        String? error;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void doCreate() {
              final name = _newListNameCtrl.text.trim();
              if (name.isEmpty) {
                setDialogState(() => error = 'List name is required');
                return;
              }
              setDialogState(() {
                creating = true;
                error = null;
              });
              final router = GoRouter.of(context);
              ref
                  .read(sharedShoppingListRepositoryProvider)
                  .createList(ownerUid: uid, ownerName: currentUser?.name ?? 'Unknown', name: name)
                  .then((listId) {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (mounted) {
                      router.push('/list/$listId');
                    }
                  })
                  .catchError((e) {
                    if (mounted) {
                      setDialogState(() {
                        creating = false;
                        error = 'Could not create list: $e';
                      });
                    }
                  });
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New shopping list', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      if (error != null) ...[Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), const SizedBox(height: 8)],
                      TextField(
                        controller: _newListNameCtrl,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(labelText: 'List name'),
                        onSubmitted: creating ? null : (_) => doCreate(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: creating ? null : () => Navigator.of(dialogContext).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: creating ? null : doCreate,
                              child: Text(creating ? 'Creating...' : 'Create'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authStateProvider).asData?.value?.email ?? '';
    final listsAsync = ref.watch(userShoppingListsProvider(uid));
    final invitationsAsync = ref.watch(pendingInvitationsProvider(email));

    return listsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load lists: $e')),
      data: (lists) {
        final invitations = invitationsAsync.asData?.value ?? [];

        if (lists.isEmpty && invitations.isEmpty) {
          return const Center(
            child: Text('No shopping lists yet.\nTap + to create one.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15)),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          children: [
            if (invitations.isNotEmpty) ...[
              Text('Invitations', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              ...invitations.map((inv) => _InvitationCard(invitation: inv, uid: uid)),
              const SizedBox(height: 20),
            ],
            if (lists.isNotEmpty) ...[
              Text('Your lists', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              ...lists.map((list) => _ListCard(list: list)),
            ],
          ],
        );
      },
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context) {
    final isPrivate = list.members.length == 1;
    final memberNames = isPrivate ? 'Private' : list.members.map((m) => m.name).join(', ');
    final remaining = list.itemCount - list.boughtCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push('/list/${list.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(list.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(isPrivate ? Icons.lock_outline_rounded : Icons.people_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      memberNames,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.checklist_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    list.itemCount == 0 ? 'Empty' : '$remaining remaining · ${list.boughtCount} bought',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationCard extends ConsumerWidget {
  const _InvitationCard({required this.invitation, required this.uid});

  final ShoppingListInvitation invitation;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${invitation.invitedByName} invited you to join',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(invitation.listName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => _respond(context, ref, false), child: const Text('Decline')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _respond(context, ref, true),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respond(BuildContext context, WidgetRef ref, bool accept) async {
    final repo = ref.read(sharedShoppingListRepositoryProvider);
    final currentUser = ref.read(currentUserProvider).asData?.value;

    try {
      if (accept) {
        await repo.acceptInvitation(
          invitationId: invitation.id,
          listId: invitation.listId,
          listName: invitation.listName,
          uid: uid,
          userName: currentUser?.name ?? 'Unknown',
        );
        if (context.mounted) {
          context.push('/list/${invitation.listId}');
        }
      } else {
        await repo.declineInvitation(invitation.id);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
