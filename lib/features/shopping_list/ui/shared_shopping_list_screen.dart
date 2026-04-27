import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:cenko/core/utils/price_util.dart';
import 'package:cenko/features/deals/data/catalog_deal_item.dart';
import 'package:cenko/features/shopping_list/data/shopping_list.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_item.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_provider.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/providers/catalog_deals_provider.dart';
import 'package:cenko/shared/providers/current_user_provider.dart';
import 'package:cenko/shared/services/deal_text_matcher_service.dart';

class SharedShoppingListScreen extends ConsumerStatefulWidget {
  const SharedShoppingListScreen({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<SharedShoppingListScreen> createState() => _SharedShoppingListScreenState();
}

class _SharedShoppingListScreenState extends ConsumerState<SharedShoppingListScreen> {
  bool _updatingBought = false;
  final DealTextMatcherService _dealMatcher = const DealTextMatcherService();

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _renameCtrl = TextEditingController();
  final _inviteEmailCtrl = TextEditingController();
  bool _saving = false;
  String? _formError;
  String? _editingItemId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _unitCtrl.dispose();
    _renameCtrl.dispose();
    _inviteEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final uid = authState.asData?.value?.uid;
    final listAsync = ref.watch(shoppingListProvider(widget.listId));
    final dealsAsync = ref.watch(allCatalogDealsProvider);

    final list = listAsync.asData?.value;
    final pendingInviteCount = uid == null ? 0 : ref.watch(listPendingInvitationsProvider(widget.listId)).asData?.value.length ?? 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(
              list: list,
              uid: uid,
              onRename: list == null ? null : () => _showRenameDialog(context, list),
              onInvite: (list == null || uid == null) ? null : () => _showInviteDialog(context, uid, list),
              onLeave: (list == null || uid == null) ? null : () => _confirmLeaveOrDelete(uid, list),
              onManageMembers: (list == null || uid == null || list.ownerId != uid || (list.members.length <= 1 && pendingInviteCount == 0))
                  ? null
                  : () => _showManageMembersDialog(uid, list),
            ),
            if (uid != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _showAddActions(context, uid),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add item'),
                    style: FilledButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: uid == null
                    ? const Center(child: Text('Please sign in'))
                    : listAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Failed to load list: ${e.toString().replaceFirst('Exception: ', '')}')),
                        data: (list) {
                          if (list == null) {
                            return const Center(child: Text('List not found'));
                          }
                          return _ItemsList(
                            listId: widget.listId,
                            uid: uid,
                            list: list,
                            deals: dealsAsync.asData?.value,
                            dealMatcher: _dealMatcher,
                            updatingBought: _updatingBought,
                            onToggleBought: (itemId, bought) => _setBought(uid: uid, itemId: itemId, bought: bought),
                            onEdit: (item) => _openItemForm(uid: uid, item: item),
                            onDelete: (item) => _confirmDeleteItem(context: context, item: item),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddActions(BuildContext context, String uid) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Add to list', style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
                ListTile(
                  leading: SvgPicture.asset(
                    'assets/icons/barcode_scanner.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.onSurfaceVariant, BlendMode.srcIn),
                  ),
                  title: const Text('Scan barcode'),
                  subtitle: const Text('Use your camera to scan a barcode'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go('/scan?mode=barcode&from=list&listId=${widget.listId}');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_note_rounded),
                  title: const Text('Add manually'),
                  subtitle: const Text('Manually enter item details'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openItemForm(uid: uid);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openItemForm({required String uid, ShoppingListItem? item}) async {
    _editingItemId = item?.id;
    _nameCtrl.text = item?.name ?? '';
    _quantityCtrl.text = item != null && item.quantity > 1 ? item.quantity.toString() : '';
    _unitCtrl.text = item?.unit ?? '';
    _formError = null;
    _formKey.currentState?.reset();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item == null ? 'Add item' : 'Edit item', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(item == null ? 'Add a new item to the list' : 'Update item details', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    if (_formError != null) ...[
                      Text(_formError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _nameCtrl,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Item name'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Item name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: TextFormField(
                            controller: _quantityCtrl,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(labelText: 'Quantity'),
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                if (int.tryParse(value.trim()) == null || int.parse(value.trim()) < 1) {
                                  return 'Invalid';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _unitCtrl,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(labelText: 'Unit'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(foregroundColor: Colors.white),
                        onPressed: _saving ? null : () => _saveItemForm(uid: uid, setModalState: setModalState),
                        child: Text(_saving ? 'Saving...' : (item == null ? 'Add item' : 'Save changes')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveItemForm({required String uid, required StateSetter setModalState}) async {
    if (!_formKey.currentState!.validate()) return;

    setModalState(() {
      _saving = true;
      _formError = null;
    });

    final repo = ref.read(sharedShoppingListRepositoryProvider);

    try {
      final quantity = int.tryParse(_quantityCtrl.text.trim()) ?? 1;
      final unit = _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim();

      if (_editingItemId != null) {
        await repo.updateItem(listId: widget.listId, itemId: _editingItemId!, name: _nameCtrl.text, quantity: quantity, unit: unit);
      } else {
        await repo.addItem(listId: widget.listId, addedBy: uid, name: _nameCtrl.text, quantity: quantity, unit: unit);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setModalState(() {
          _formError = 'Failed to save item: ${e.toString().replaceFirst('Exception: ', '')}';
          _saving = false;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDeleteItem({required BuildContext context, required ShoppingListItem item}) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var deleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.onErrorContainer, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Delete ${item.name}?', style: Theme.of(context).textTheme.titleLarge)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Item will be removed from the list', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: deleting ? null : () => Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.error,
                                foregroundColor: Theme.of(context).colorScheme.onError,
                              ),
                              onPressed: deleting
                                  ? null
                                  : () async {
                                      setDialogState(() => deleting = true);
                                      try {
                                        await ref
                                            .read(sharedShoppingListRepositoryProvider)
                                            .deleteItem(listId: widget.listId, itemId: item.id, wasBought: item.isBought);
                                        if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                                      } catch (e) {
                                        if (!dialogContext.mounted) return;
                                        setDialogState(() => deleting = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to delete item: ${e.toString().replaceFirst('Exception: ', '')}')),
                                        );
                                      }
                                    },
                              child: Text(deleting ? 'Deleting...' : 'Delete'),
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
    return shouldDelete == true;
  }

  Future<void> _setBought({required String uid, required String itemId, required bool bought}) async {
    setState(() => _updatingBought = true);
    try {
      await ref.read(sharedShoppingListRepositoryProvider).setBought(listId: widget.listId, itemId: itemId, bought: bought);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update item: ${e.toString().replaceFirst('Exception: ', '')}')));
    } finally {
      if (mounted) setState(() => _updatingBought = false);
    }
  }

  Future<void> _showRenameDialog(BuildContext context, ShoppingList list) async {
    _renameCtrl.text = list.name;
    _renameCtrl.selection = TextSelection(baseOffset: 0, extentOffset: list.name.length);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var saving = false;
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void doRename() {
              final name = _renameCtrl.text.trim();
              if (name.isEmpty) {
                setDialogState(() => error = 'Name is required');
                return;
              }
              setDialogState(() {
                saving = true;
                error = null;
              });
              ref
                  .read(sharedShoppingListRepositoryProvider)
                  .renameList(listId: widget.listId, name: name, memberUids: list.members.map((m) => m.userId).toList())
                  .then((_) {
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  })
                  .catchError((e) {
                    if (mounted) {
                      setDialogState(() {
                        saving = false;
                        error = 'Failed to rename list: ${e.toString().replaceFirst('Exception: ', '')}';
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
                      Text('Rename list', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      if (error != null) ...[Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), const SizedBox(height: 8)],
                      TextField(
                        controller: _renameCtrl,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(labelText: 'List name'),
                        onSubmitted: saving ? null : (_) => doRename(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: saving ? null : doRename,
                              child: Text(saving ? 'Saving...' : 'Rename'),
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

  Future<void> _showInviteDialog(BuildContext context, String uid, ShoppingList list) async {
    _inviteEmailCtrl.clear();
    final currentUser = ref.read(currentUserProvider).asData?.value;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var inviting = false;
        String? error;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void doInvite() {
              final email = _inviteEmailCtrl.text.trim();
              if (email.isEmpty) {
                setDialogState(() => error = 'Email is required');
                return;
              }
              final currentEmail = ref.read(authStateProvider).asData?.value?.email ?? '';
              if (email.toLowerCase() == currentEmail.toLowerCase()) {
                setDialogState(() => error = 'You cannot invite yourself');
                return;
              }
              setDialogState(() {
                inviting = true;
                error = null;
              });
              final messenger = ScaffoldMessenger.of(context);
              ref
                  .read(sharedShoppingListRepositoryProvider)
                  .inviteByEmail(
                    listId: widget.listId,
                    listName: list.name,
                    invitedByUid: uid,
                    invitedByName: currentUser?.name ?? 'Unknown',
                    email: email,
                  )
                  .then((_) {
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    messenger.showSnackBar(SnackBar(content: Text('Invitation sent to $email')));
                  })
                  .catchError((e) {
                    if (mounted) {
                      setDialogState(() {
                        inviting = false;
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
                      Text('Invite to list', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('Invite user to join this shopping list', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      if (error != null) ...[Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), const SizedBox(height: 8)],
                      TextField(
                        controller: _inviteEmailCtrl,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(labelText: 'Email address'),
                        onSubmitted: inviting ? null : (_) => doInvite(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              child: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: inviting ? null : doInvite,
                              child: Text(inviting ? 'Inviting...' : 'Invite'),
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

  Future<void> _showManageMembersDialog(String ownerUid, ShoppingList list) async {
    final repo = ref.read(sharedShoppingListRepositoryProvider);
    final initialInvitations = await repo.getListPendingInvitations(list.id);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var pendingInvitations = List.of(initialInvitations);
        final members = list.members.where((m) => m.userId != ownerUid).toList();

        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                      Text('Manage members', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        '${list.members.length} member${list.members.length == 1 ? '' : 's'}'
                        '${pendingInvitations.isNotEmpty ? ' · ${pendingInvitations.length} pending' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      _MemberRow(
                        name: list.members.firstWhere((m) => m.userId == ownerUid, orElse: () => list.members.first).name,
                        isOwner: true,
                        isSelf: true,
                      ),
                      if (members.isNotEmpty) ...[
                        const Divider(height: 20),
                        ...members.map(
                          (member) => _MemberRow(
                            name: member.name,
                            isOwner: false,
                            isSelf: false,
                            onMakeOwner: () async {
                              try {
                                await repo.transferOwnership(listId: list.id, currentOwnerUid: ownerUid, newOwnerUid: member.userId);
                                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
                                }
                              }
                            },
                            onRemove: () async {
                              try {
                                await repo.removeMember(listId: list.id, memberUid: member.userId);
                                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
                                }
                              }
                            },
                          ),
                        ),
                      ],
                      if (pendingInvitations.isNotEmpty) ...[
                        const Divider(height: 20),
                        Text(
                          'Pending invitations',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        ...pendingInvitations.map(
                          (inv) => _PendingInvitationRow(
                            email: inv.invitedEmail,
                            onCancel: () async {
                              try {
                                await repo.cancelInvitation(inv.id);
                                setDialogState(() => pendingInvitations.remove(inv));
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
                                }
                              }
                            },
                          ),
                        ),
                      ],
                      if (members.isEmpty && pendingInvitations.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text('No other members yet.', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Close'),
                        ),
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

  Future<void> _confirmLeaveOrDelete(String uid, ShoppingList list) async {
    final isOwner = list.ownerId == uid;
    final action = isOwner ? 'Delete' : 'Leave';
    final description = isOwner
        ? 'This will permanently delete ${list.name} and all its items for all members'
        : 'You will be removed from ${list.name} and will no longer see it in your lists';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
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
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Theme.of(dialogContext).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                        child: Icon(
                          isOwner ? Icons.delete_rounded : Icons.exit_to_app_rounded,
                          color: Theme.of(dialogContext).colorScheme.onErrorContainer,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text('$action list?', style: Theme.of(dialogContext).textTheme.titleLarge)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(description, style: Theme.of(dialogContext).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(dialogContext).colorScheme.error,
                            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: Text(action),
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

    if (confirmed != true || !mounted) return;

    try {
      if (isOwner) {
        await ref
            .read(sharedShoppingListRepositoryProvider)
            .deleteList(listId: widget.listId, memberUids: list.members.map((m) => m.userId).toList());
      } else {
        await ref.read(sharedShoppingListRepositoryProvider).leaveList(uid: uid, listId: widget.listId);
      }
      if (!mounted) return;
      context.go('/list');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to $action list: ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.list, required this.uid, required this.onRename, required this.onInvite, required this.onLeave, this.onManageMembers});

  final ShoppingList? list;
  final String? uid;
  final VoidCallback? onRename;
  final VoidCallback? onInvite;
  final VoidCallback? onLeave;
  final VoidCallback? onManageMembers;

  @override
  Widget build(BuildContext context) {
    final isOwner = list != null && uid != null && list!.ownerId == uid;
    final memberNames = list?.members.map((m) => m.name).join(', ') ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/list')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list?.name ?? 'Shopping List',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (memberNames.isNotEmpty)
                  Text(
                    memberNames,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (list != null) ...[
            IconButton(icon: const Icon(Icons.person_add_rounded), onPressed: onInvite, tooltip: 'Invite people'),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    onRename?.call();
                  case 'manage':
                    onManageMembers?.call();
                  case 'leave':
                    onLeave?.call();
                }
              },
              itemBuilder: (context) => [
                if (onManageMembers != null) const PopupMenuItem(value: 'manage', child: Text('Manage members')),
                const PopupMenuItem(value: 'rename', child: Text('Rename list')),
                PopupMenuItem(
                  value: 'leave',
                  child: Text(isOwner ? 'Delete list' : 'Leave list', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  const _ItemsList({
    required this.listId,
    required this.uid,
    required this.list,
    required this.deals,
    required this.dealMatcher,
    required this.updatingBought,
    required this.onToggleBought,
    required this.onEdit,
    required this.onDelete,
  });

  final String listId;
  final String uid;
  final ShoppingList list;
  final List<CatalogDealItem>? deals;
  final DealTextMatcherService dealMatcher;
  final bool updatingBought;
  final void Function(String itemId, bool bought) onToggleBought;
  final void Function(ShoppingListItem item) onEdit;
  final Future<bool> Function(ShoppingListItem item) onDelete;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final itemsAsync = ref.watch(shoppingListItemsProvider(listId));
        return itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load items: ${e.toString().replaceFirst('Exception: ', '')}')),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Text('Tap "Add item" to add items to this shopping list', style: TextStyle(fontSize: 15), textAlign: TextAlign.center),
              );
            }

            final bestDealById = _buildBestDeals(items);

            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => onDelete(item),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 18),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(16)),
                    child: Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  child: _ShoppingItemTile(
                    item: item,
                    bestDeal: bestDealById[item.id],
                    onToggleBought: updatingBought ? null : (v) => onToggleBought(item.id, v),
                    onEdit: () => onEdit(item),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Map<String, CatalogDealItem> _buildBestDeals(List<ShoppingListItem> items) {
    if (deals == null || deals!.isEmpty) return const {};

    final result = <String, CatalogDealItem>{};
    for (final item in items) {
      final terms = <String>{};
      final name = item.name.trim();
      if (name.isNotEmpty) terms.add(name);
      if (terms.isEmpty) continue;

      final matched = dealMatcher.matchDeals(shoppingListTexts: terms, deals: deals!, minScore: 0.48);
      if (matched.isEmpty) continue;

      result[item.id] = matched.reduce((a, b) => a.salePriceCents <= b.salePriceCents ? a : b);
    }
    return result;
  }
}

class _ShoppingItemTile extends StatelessWidget {
  const _ShoppingItemTile({required this.item, required this.bestDeal, required this.onToggleBought, required this.onEdit});

  final ShoppingListItem item;
  final CatalogDealItem? bestDeal;
  final ValueChanged<bool>? onToggleBought;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.68));

    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggleBought == null ? null : () => onToggleBought!(!item.isBought),
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  border: Border.all(color: item.isBought ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline, width: 2),
                  borderRadius: BorderRadius.circular(6),
                  color: item.isBought ? Theme.of(context).colorScheme.primary : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: item.isBought ? Icon(Icons.check_rounded, size: 18, color: Theme.of(context).colorScheme.onPrimary) : null,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: item.isBought ? FontWeight.w500 : FontWeight.w600,
                        decoration: item.isBought ? TextDecoration.lineThrough : null,
                        color: item.isBought ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.65) : null,
                      ),
                    ),
                    if (_quantityUnitText() != null) ...[const SizedBox(height: 2), Text(_quantityUnitText()!, style: subtitleStyle)],
                    if (_subtitleText() != null) ...[const SizedBox(height: 2), Text(_subtitleText()!, style: subtitleStyle)],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _subtitleText() {
    final deal = bestDeal;
    if (deal == null) return 'No current deal';
    final savings = deal.savingsCents;
    if (savings > 0) {
      return 'Best now at ${deal.storeName} ${formatCents(deal.salePriceCents)} (save ${formatCents(savings)})';
    }
    return 'Best now at ${deal.storeName} ${formatCents(deal.salePriceCents)}';
  }

  String? _quantityUnitText() {
    final hasQty = item.quantity > 1;
    final hasUnit = item.unit != null && item.unit!.isNotEmpty;
    if (!hasQty && !hasUnit) return null;
    if (hasQty && hasUnit) return '${item.quantity} ${item.unit}';
    if (hasQty) return '× ${item.quantity}';
    return item.unit;
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.name, required this.isOwner, required this.isSelf, this.onMakeOwner, this.onRemove});

  final String name;
  final bool isOwner;
  final bool isSelf;
  final VoidCallback? onMakeOwner;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isSelf ? '$name (You)' : name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  isOwner ? 'Owner' : 'Member',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (!isSelf && !isOwner)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'owner') onMakeOwner?.call();
                if (value == 'remove') onRemove?.call();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'owner', child: Text('Make owner')),
                PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove from list', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PendingInvitationRow extends StatelessWidget {
  const _PendingInvitationRow({required this.email, required this.onCancel});

  final String email;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(Icons.mail_outline_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text('Pending', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'cancel') onCancel();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'cancel',
                child: Text('Cancel invitation', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
