import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cenko/features/shopping_list/data/shopping_list_item.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_provider.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/widgets/top_bar.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  String? _pendingDeleteItemId;
  bool _deleting = false;
  bool _updatingBought = false;

  // Form modal state
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  bool _saving = false;
  String? _formError;
  String? _editingItemId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _barcodeCtrl.dispose();
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: MainTopBar(title: 'Shopping List'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: uid == null ? null : () => _showAddActions(context, uid),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add item'),
                  style: FilledButton.styleFrom(foregroundColor: Colors.white),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                child: uid == null
                    ? const Center(child: Text('Please sign in to manage your shopping list.'))
                    : ref
                          .watch(shoppingListItemsProvider(uid))
                          .when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (error, _) => Center(child: Text('Could not load shopping list: $error')),
                            data: (items) {
                              final pendingItem = _findPendingDeleteItem(items);
                              if (_pendingDeleteItemId != null && pendingItem == null) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    setState(() => _pendingDeleteItemId = null);
                                  }
                                });
                              }

                              if (items.isEmpty) {
                                return const Center(child: Text('No items yet. Tap "Add item" to create your list.'));
                              }

                              return Stack(
                                children: [
                                  ListView.separated(
                                    itemCount: items.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final item = items[index];
                                      return Dismissible(
                                        key: ValueKey(item.id),
                                        direction: DismissDirection.endToStart,
                                        confirmDismiss: (_) async {
                                          setState(() => _pendingDeleteItemId = item.id);
                                          return false;
                                        },
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(right: 18),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.errorContainer,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
                                        ),
                                        child: _ShoppingItemTile(
                                          item: item,
                                          onToggleBought: _updatingBought ? null : (value) => _setBought(uid: uid, itemId: item.id, bought: value),
                                          onEdit: () => _openItemForm(uid: uid, item: item),
                                        ),
                                      );
                                    },
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: pendingItem == null
                                        ? const SizedBox.shrink()
                                        : Center(
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 420),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                                child: Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(14),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Padding(
                                                        padding: const EdgeInsets.all(14),
                                                        child: Row(
                                                          children: [
                                                            Container(
                                                              width: 34,
                                                              height: 34,
                                                              alignment: Alignment.center,
                                                              decoration: BoxDecoration(
                                                                color: Theme.of(context).colorScheme.errorContainer,
                                                                borderRadius: BorderRadius.circular(10),
                                                              ),
                                                              child: Icon(
                                                                Icons.delete_rounded,
                                                                color: Theme.of(context).colorScheme.onErrorContainer,
                                                                size: 18,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 12),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    'Delete "${pendingItem.name}"?',
                                                                    style: Theme.of(context).textTheme.titleMedium,
                                                                  ),
                                                                  const SizedBox(height: 2),
                                                                  Text('This action cannot be undone.', style: Theme.of(context).textTheme.bodySmall),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: OutlinedButton(
                                                                onPressed: _deleting ? null : () => setState(() => _pendingDeleteItemId = null),
                                                                child: const Text('Cancel'),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 10),
                                                            Expanded(
                                                              child: FilledButton(
                                                                onPressed: _deleting ? null : () => _deletePendingItem(uid: uid),
                                                                style: FilledButton.styleFrom(
                                                                  backgroundColor: Theme.of(context).colorScheme.error,
                                                                  foregroundColor: Theme.of(context).colorScheme.onError,
                                                                ),
                                                                child: Text(_deleting ? 'Deleting...' : 'Delete'),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
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

  ShoppingListItem? _findPendingDeleteItem(List<ShoppingListItem> items) {
    final targetId = _pendingDeleteItemId;
    if (targetId == null) {
      return null;
    }

    for (final item in items) {
      if (item.id == targetId) {
        return item;
      }
    }

    return null;
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
                    child: Text('Add to shopping list', style: Theme.of(context).textTheme.titleLarge),
                  ),
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
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner_rounded),
                  title: const Text('Scan barcode'),
                  subtitle: const Text('Open scanner and scan item barcode'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/scan?mode=barcode&from=list');
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
    _formError = null;
    _formKey.currentState?.reset();

    await showModalBottomSheet<void>(
      context: context,
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
                    Text(
                      item == null ? 'Add a new item to your shopping list.' : 'Update item details.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    if (_formError != null) ...[
                      Text(_formError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _nameCtrl,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'Item name'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Item name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setModalState(() {
      _saving = true;
      _formError = null;
    });

    final repository = ref.read(shoppingListRepositoryProvider);

    try {
      if (_editingItemId != null) {
        await repository.updateItem(uid: uid, itemId: _editingItemId!, name: _nameCtrl.text);
      } else {
        await repository.addItem(uid: uid, name: _nameCtrl.text);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setModalState(() {
          _formError = 'Could not save item: $error';
          _saving = false;
        });
      }
    }
  }

  Future<void> _setBought({required String uid, required String itemId, required bool bought}) async {
    setState(() => _updatingBought = true);
    try {
      await ref.read(shoppingListRepositoryProvider).setBought(uid: uid, itemId: itemId, bought: bought);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update item: $error')));
    } finally {
      if (mounted) {
        setState(() => _updatingBought = false);
      }
    }
  }

  Future<void> _deletePendingItem({required String uid}) async {
    final targetId = _pendingDeleteItemId;
    if (targetId == null) {
      return;
    }

    setState(() => _deleting = true);
    try {
      await ref.read(shoppingListRepositoryProvider).deleteItem(uid: uid, itemId: targetId);
      if (mounted) {
        setState(() {
          _pendingDeleteItemId = null;
          _deleting = false;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete item: $error')));
    }
  }
}

class _ShoppingItemTile extends StatelessWidget {
  const _ShoppingItemTile({required this.item, required this.onToggleBought, required this.onEdit});

  final ShoppingListItem item;
  final ValueChanged<bool>? onToggleBought;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];
    if (item.brand != null) {
      subtitleParts.add('Brand: ${item.brand}');
    }
    if (item.barcode != null) {
      subtitleParts.add('Barcode: ${item.barcode}');
    }
    if (subtitleParts.isEmpty) {
      subtitleParts.add('Added manually');
    }

    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggleBought == null ? null : () => onToggleBought!(!(item.bought)),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: item.bought ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline, width: 2),
                  borderRadius: BorderRadius.circular(6),
                  color: item.bought ? Theme.of(context).colorScheme.primary : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: item.bought ? Icon(Icons.check_rounded, size: 16, color: Theme.of(context).colorScheme.onPrimary) : null,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: item.bought ? FontWeight.w500 : FontWeight.w600,
                        decoration: item.bought ? TextDecoration.lineThrough : null,
                        color: item.bought ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.65) : null,
                      ),
                    ),
                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitleParts.join(' • '),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
