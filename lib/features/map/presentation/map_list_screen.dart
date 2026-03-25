import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:memomap/features/map/providers/current_map_provider.dart';
import 'package:memomap/features/map/providers/map_provider.dart';

class MapListScreen extends ConsumerWidget {
  const MapListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapsAsync = ref.watch(mapsProvider);
    final currentMapId = ref.watch(currentMapIdProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Maps'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: mapsAsync.when(
        data: (maps) {
          final isLastMap = maps.length <= 1;

          return ListView.builder(
            itemCount: maps.length,
            itemBuilder: (context, index) {
              final map = maps[index];
              final isSelected = map.id == currentMapId;
              final dateFormat = DateFormat('yyyy/MM/dd');

              return ListTile(
                leading: isSelected
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : const Icon(Icons.map_outlined),
                title: Text(
                  map.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  map.description ?? dateFormat.format(map.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (map.isLocal)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.cloud_off,
                          size: 16,
                          color: Colors.orange,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditMapDialog(context, ref, map),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, size: 20, color: isLastMap ? Colors.grey : Colors.red),
                      onPressed: isLastMap ? null : () => _showDeleteConfirmDialog(context, ref, map),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                onTap: () {
                  ref.read(currentMapIdProvider.notifier).setCurrentMapId(map.id);
                  context.pop();
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(mapsProvider),
                child: const Text('Reload'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMapDialog(context, ref),
        tooltip: 'Create new map',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateMapDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _CreateMapDialog(),
    );
  }

  void _showEditMapDialog(BuildContext context, WidgetRef ref, MapData map) {
    showDialog(
      context: context,
      builder: (context) => _EditMapDialog(map: map),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref, MapData map) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Map'),
        content: Text('Delete "${map.name}"?\nAll pins and drawings in this map will also be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(mapsProvider.notifier).deleteMap(map);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _CreateMapDialog extends ConsumerStatefulWidget {
  const _CreateMapDialog();

  @override
  ConsumerState<_CreateMapDialog> createState() => _CreateMapDialogState();
}

class _CreateMapDialogState extends ConsumerState<_CreateMapDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Map'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Map Name',
              hintText: 'e.g. Travel Plan',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'e.g. Summer 2024 Trip',
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _createMap,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createMap() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a map name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final description = _descriptionController.text.trim();
    final newMap = await ref.read(mapsProvider.notifier).createMap(
      name: name,
      description: description.isEmpty ? null : description,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (newMap != null) {
      ref.read(currentMapIdProvider.notifier).setCurrentMapId(newMap.id);
    }
  }
}

class _EditMapDialog extends ConsumerStatefulWidget {
  final MapData map;

  const _EditMapDialog({required this.map});

  @override
  ConsumerState<_EditMapDialog> createState() => _EditMapDialogState();
}

class _EditMapDialogState extends ConsumerState<_EditMapDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.map.name);
    _descriptionController = TextEditingController(text: widget.map.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Map'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Map Name',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _updateMap,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _updateMap() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a map name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final description = _descriptionController.text.trim();
    await ref.read(mapsProvider.notifier).updateMap(
      widget.map,
      name: name,
      description: description.isEmpty ? null : description,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }
}
