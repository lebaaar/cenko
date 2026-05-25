import 'package:cenko/features/shopping_list/data/shopping_list.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_invitation.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_provider.dart';
import 'package:cenko/l10n/app_localizations.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/providers/current_user_provider.dart';
import 'package:cenko/shared/services/snack_bar_service.dart';
import 'package:cenko/shared/widgets/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final uid = authState.asData?.value?.user.id;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: MainTopBar(
                title: AppLocalizations.of(context)!.shoppingListsTitle,
                trailing: uid == null
                    ? null
                    : IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _showCreateListDialog(context, uid), tooltip: AppLocalizations.of(context)!.shoppingListNewTooltip),
              ),
            ),
            Expanded(
              child: uid == null ? Center(child: Text(AppLocalizations.of(context)!.shoppingListSignInPrompt)) : _Body(uid: uid),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateListDialog(BuildContext context, String uid) async {
    _newListNameCtrl.clear();
    final currentUser = ref.read(currentUserProvider).asData?.value;

    final l10n = AppLocalizations.of(context)!;
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
                setDialogState(() => error = l10n.shoppingListNameRequired);
                return;
              }
              setDialogState(() {
                creating = true;
                error = null;
              });
              final router = GoRouter.of(context);
              ref
                  .read(sharedShoppingListRepositoryProvider)
                  .createList(ownerUid: uid, ownerName: currentUser?.displayName ?? 'Unknown', name: name, isFreePlan: currentUser?.isFreePlan == true)
                  .then((listId) {
                    ref.invalidate(userShoppingListsProvider(uid));
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
                      Text(l10n.shoppingListCreateTitle, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      if (error != null) ...[Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), const SizedBox(height: 8)],
                      TextField(
                        controller: _newListNameCtrl,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(labelText: l10n.shoppingListNameLabel),
                        onSubmitted: creating ? null : (_) => doCreate(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
                              onPressed: creating ? null : () => Navigator.of(dialogContext).pop(),
                              child: Text(l10n.cancel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: creating ? null : doCreate,
                              child: creating
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(l10n.create),
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
  recentlyUpdated('Recently updated');

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
    }
    return sorted;
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(userShoppingListsProvider(widget.uid));
    ref.invalidate(pendingInvitationsProvider(widget.uid));
  }

  String _sortOptionLabel(SortOption option, AppLocalizations l10n) {
    switch (option) {
      case SortOption.alphabeticalAZ:
        return l10n.sortAlphaAZ;
      case SortOption.alphabeticalZA:
        return l10n.sortAlphaZA;
      case SortOption.recentlyUpdated:
        return l10n.sortRecentlyUpdated;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final listsAsync = ref.watch(userShoppingListsProvider(widget.uid));
    final invitationsAsync = ref.watch(pendingInvitationsProvider(widget.uid));

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
                    error: (e, _) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(l10n.shoppingListCouldNotLoadInvitations)),
                    data: (invitations) => invitations.isEmpty
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.shoppingListInvitationsSection),
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
                    Center(
                      child: Text(l10n.shoppingListEmptyState, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.shoppingListYourLists),
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
                                      Text(_sortOptionLabel(option, l10n)),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          tooltip: l10n.dealsSort,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sort, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                _sortOptionLabel(_sortOption, l10n).split('(')[0].trim(),
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

class _ListCard extends ConsumerWidget {
  const _ListCard({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isPrivate = list.members.length == 1;
    final memberNames = isPrivate ? l10n.listPrivate : list.members.map((m) => m.name).join(', ');

    // Watch items directly — this stream fires whenever items change (realtime),
    // giving us live counts without needing watchUserLists to re-emit.
    final itemsAsync = ref.watch(shoppingListItemsProvider(list.id));
    final items = itemsAsync.asData?.value;
    final total = items?.length ?? 0;
    final bought = items?.where((i) => i.isBought).length ?? 0;
    final remaining = total - bought;
    final allDone = total > 0 && remaining == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push('/list/${list.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(list.name, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    isPrivate ? Icons.lock_outline_rounded : Icons.people_rounded,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      memberNames,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (items != null) ...[
                const SizedBox(height: 10),
                if (total == 0)
                  Text(
                    l10n.listEmpty,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  )
                else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: bought / total,
                      minHeight: 4,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(allDone ? cs.primary : cs.primary.withValues(alpha: 0.65)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (allDone)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 13, color: cs.primary),
                            const SizedBox(width: 4),
                            Text(l10n.listAllDone, style: tt.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
                          ],
                        )
                      else
                        Text(
                          l10n.listRemainingCount(remaining),
                          style: tt.bodySmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w500),
                        ),
                      if (bought > 0) ...[
                        const SizedBox(width: 8),
                        Text('·', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        Icon(Icons.check_rounded, size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(
                          l10n.listBoughtCount(bought),
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
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
              AppLocalizations.of(context)!.listInvitedToJoin(widget.invitation.invitedByName),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(widget.invitation.listName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _loading ? null : () => _respond(false), child: Text(AppLocalizations.of(context)!.decline)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _loading ? null : () => _respond(true),
                    child: Text(AppLocalizations.of(context)!.accept),
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
          uid: widget.uid,
          isFreePlan: currentUser?.isFreePlan == true,
        );
      } else {
        await repo.declineInvitation(widget.invitation.id);
      }
      ref.invalidate(pendingInvitationsProvider(widget.uid));
      ref.invalidate(userShoppingListsProvider(widget.uid));
    } catch (e) {
      if (mounted) {
        SnackBarService.show(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      widget.onAcceptingChanged(false);
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
