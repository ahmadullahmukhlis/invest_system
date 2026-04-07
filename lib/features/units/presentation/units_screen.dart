import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/unit_providers.dart';
import '../domain/unit.dart';

class UnitsScreen extends ConsumerWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Units Settings'),
        actions: [
          IconButton(
            onPressed: () async {
              final created = await showDialog<Unit>(
                context: context,
                builder: (_) => const _UnitFormDialog(),
              );
              if (created != null) {
                await ref.read(unitRepositoryProvider).upsert(created);
              }
            },
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: ListView.separated(
            itemCount: units.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final unit = units[index];
              return ListTile(
                title: Text(unit.name),
                subtitle: Text(unit.isActive ? 'Active' : 'Inactive'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'toggle') {
                      await ref
                          .read(unitRepositoryProvider)
                          .toggleActive(unit.id);
                    }
                    if (value == 'edit') {
                      final updated = await showDialog<Unit>(
                        context: context,
                        builder: (_) => _UnitFormDialog(existing: unit),
                      );
                      if (updated != null) {
                        await ref
                            .read(unitRepositoryProvider)
                            .upsert(updated);
                      }
                    }
                    if (value == 'delete') {
                      final confirm = await _confirmDelete(context);
                      if (confirm) {
                        await ref
                            .read(unitRepositoryProvider)
                            .deleteById(unit.id);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(unit.isActive ? 'Deactivate' : 'Activate'),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UnitFormDialog extends StatefulWidget {
  const _UnitFormDialog({this.existing});

  final Unit? existing;

  @override
  State<_UnitFormDialog> createState() => _UnitFormDialogState();
}

class _UnitFormDialogState extends State<_UnitFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _isActive = widget.existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Unit' : 'Edit Unit'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                title: const Text('Active'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final updated = Unit(
              id: widget.existing?.id ?? '',
              name: _name.text.trim(),
              isActive: _isActive,
            );
            Navigator.pop(context, updated);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<bool> _confirmDelete(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete unit?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}
