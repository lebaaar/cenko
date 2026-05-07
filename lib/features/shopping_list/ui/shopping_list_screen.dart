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
                        error = e.toString().replaceFirst('Exception: ', '');
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
                              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
                              onPressed: creating ? null : () => Navigator.of(dialogContext).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: creating ? null : doCreate,
                              child: creating
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Create'),
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

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.uid});

  final String uid;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

enum SortOption {
  alphabeticalAZ('Alphabetical (A-Z)'),
  alphabeticalZA('Alphabetical (Z-A)'),
  recentlyUpdated('Recently updated'),
  mostItems('Most items'),
  leastItems('Least items');

  final String label;
  const SortOption(this.label);
}

class _BodyState extends ConsumerState<_Body> {
  SortOption _sortOption = SortOption.alphabeticalAZ;
  bool _acceptingInvitation = false;

  List<ShoppingList> _sortLists(List<ShoppingList> lists) {
    final sorted = [...lists];
    switch (_sortOption) {
      case SortOption.alphabeticalAZ:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortOption.alphabeticalZA:
        sorted.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case SortOption.recentlyUpdated:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case SortOption.mostItems:
        sorted.sort((a, b) => b.itemCount.compareTo(a.itemCount));
        break;
      case SortOption.leastItems:
        sorted.sort((a, b) => a.itemCount.compareTo(b.itemCount));
        break;
    }
    return sorted;
  }

  Future<void> _handleRefresh() async {
    // Refresh is automatic via Riverpod's realtime listeners, but this allows the UI to show the refresh animation
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authStateProvider).asData?.value?.email ?? '';
    final listsAsync = ref.watch(userShoppingListsProvider(widget.uid));
    final invitationsAsync = email.isEmpty ? const AsyncLoading<List<ShoppingListInvitation>>() : ref.watch(pendingInvitationsProvider(email));

    return Stack(
      children: [
        listsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load shopping lists: ${e.toString().replaceFirst('Exception: ', '')}')),
          data: (lists) {
            final sortedLists = _sortLists(lists);

            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
                children: [
                  invitationsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Could not load invitations')),
                    data: (invitations) => invitations.isEmpty
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Invitations'),
                              const SizedBox(height: 8),
                              ...invitations.map(
                                (inv) => _InvitationCard(
                                  invitation: inv,
                                  uid: widget.uid,
                                  onAcceptingChanged: (accepting) => setState(() => _acceptingInvitation = accepting),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                  ),
                  if (lists.isEmpty) ...[
                    const SizedBox(height: 80),
                    const Center(
                      child: Text('No shopping lists yet.\nTap + to create one.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15)),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Your lists'),
                        PopupMenuButton<SortOption>(
                          onSelected: (option) => setState(() => _sortOption = option),
                          itemBuilder: (context) => SortOption.values
                              .map(
                                (option) => PopupMenuItem(
                                  value: option,
                                  child: Row(
                                    children: [
                                      if (_sortOption == option) const Icon(Icons.check, size: 18) else const SizedBox(width: 18),
                                      const SizedBox(width: 12),
                                      Text(option.label),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          tooltip: 'Sort options',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sort, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                _sortOption.label.split('(')[0].trim(),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...sortedLists.map((list) => _ListCard(list: list)),
                  ],
                ],
              ),
            );
          },
        ),
        if (_acceptingInvitation)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context) {
    final isPrivate = list.members.length == 1;
    final memberNames = isPrivate ? 'Private list' : list.members.map((m) => m.name).join(', ');
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
                  Icon(
                    isPrivate ? Icons.lock_outline_rounded : Icons.people_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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

class _InvitationCard extends ConsumerStatefulWidget {
  const _InvitationCard({required this.invitation, required this.uid, required this.onAcceptingChanged});

  final ShoppingListInvitation invitation;
  final String uid;
  final Function(bool) onAcceptingChanged;

  @override
  ConsumerState<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<_InvitationCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
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
              '${widget.invitation.invitedByName} invited you to join',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(widget.invitation.listName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _loading ? null : () => _respond(false), child: const Text('Decline')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _loading ? null : () => _respond(true),
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

  Future<void> _respond(bool accept) async {
    if (_loading) return;
    setState(() => _loading = true);
    widget.onAcceptingChanged(true);

    final repo = ref.read(sharedShoppingListRepositoryProvider);
    final currentUser = ref.read(currentUserProvider).asData?.value;

    try {
      if (accept) {
        await repo.acceptInvitation(
          invitationId: widget.invitation.id,
          listId: widget.invitation.listId,
          listName: widget.invitation.listName,
          uid: widget.uid,
          userName: currentUser?.name ?? 'Unknown',
        );
      } else {
        await repo.declineInvitation(widget.invitation.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      widget.onAcceptingChanged(false);
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
