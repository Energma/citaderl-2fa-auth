import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/profile.dart';
import '../../core/providers.dart';
import '../theme/palette.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profileListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
      body: profiles.when(
        data: (list) => list.isEmpty
            ? const Center(child: Text('No profiles'))
            : ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                onReorder: (old, newIdx) {
                  // TODO: persist reorder
                },
                itemBuilder: (context, index) {
                  final p = list[index];
                  return Card(
                    key: ValueKey(p.id),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: p.color),
                      title: Text(p.name),
                      trailing: PopupMenuButton(
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                        onSelected: (v) {
                          if (v == 'edit') _showEditDialog(p);
                          if (v == 'delete') _deleteProfile(p);
                        },
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showAddDialog() {
    _showProfileDialog(null);
  }

  void _showEditDialog(Profile profile) {
    _showProfileDialog(profile);
  }

  void _showProfileDialog(Profile? existing) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    int selectedColor = existing?.colorValue ?? Palette.profileColors[0].toARGB32();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New Profile' : 'Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: Palette.profileColors.map((c) {
                  final isSelected = c.toARGB32() == selectedColor;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = c.toARGB32()),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Theme.of(ctx).colorScheme.onSurface, width: 3)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final repo = ref.read(profileRepositoryProvider);
                if (existing != null) {
                  await repo.update(existing.copyWith(
                    name: name,
                    colorValue: selectedColor,
                  ));
                } else {
                  await repo.add(Profile(
                    name: name,
                    colorValue: selectedColor,
                  ));
                }
                ref.invalidate(profileListProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteProfile(Profile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Delete "${profile.name}"? Tokens in this profile will be unassigned.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(profileRepositoryProvider).delete(profile.id);
      ref.invalidate(profileListProvider);
    }
  }
}
