import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cenko/features/shopping_list/data/shopping_list_provider.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/widgets/top_bar.dart';

class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  onPressed: uid == null ? null : () => _showAddItemDialog(context, ref, uid),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add item'),
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
                              if (items.isEmpty) {
                                return const Center(child: Text('No items yet. Tap "Add item" to create your list.'));
                              }

                              return ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final subtitle = item.brand == null ? 'Added manually' : 'Brand: ${item.brand}';

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.checklist_rounded),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                                              const SizedBox(height: 2),
                                              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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

  Future<void> _showAddItemDialog(BuildContext context, WidgetRef ref, String uid) async {
    var name = '';
    var brand = '';
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add shopping list item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Item name'),
                    onChanged: (value) => name = value,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Brand (optional)'),
                    onChanged: (value) => brand = value,
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final trimmedName = name.trim();
                          if (trimmedName.isEmpty) return;

                          setDialogState(() => isSaving = true);
                          try {
                            await ref.read(shoppingListRepositoryProvider).addItem(uid: uid, name: trimmedName, brand: brand);
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (error) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Could not add item: $error')));
                            }
                            setDialogState(() => isSaving = false);
                          }
                        },
                  child: Text(isSaving ? 'Adding...' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
