import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../core/widgets/desktop_scaffold.dart';
import '../../../core/widgets/desktop_table.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../ui/responsive.dart';
import '../../../data/user_providers.dart';
import '../data/unit_providers.dart';
import '../domain/unit.dart';

class UnitsScreen extends ConsumerWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRepo = ref.watch(userRepositoryProvider);
    final units = ref.watch(unitsProvider);
    final canCreateUnit = canCreate(userRepo, 'units');
    final canEditUnit = canEdit(userRepo, 'units');
    final canDeleteUnit = canRemove(userRepo, 'units');

    final isDesktop = Responsive.isDesktop(context);

    return DesktopScaffold(
      title: 'Units Settings',
      actions: [
        if (canCreateUnit)
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
            tooltip: 'Add unit',
          ),
      ],
      body: RefreshWrapper(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionHeader(
              title: 'Units',
              subtitle: '${units.length} records',
              icon: Icons.straighten,
            ),
            if (units.isEmpty)
              const EmptyStateCard(
                title: 'No units yet',
                subtitle: 'Add units to use in sales and purchases.',
                icon: Icons.straighten_outlined,
              )
            else if (isDesktop)
              DesktopTable(
                minWidth: 700,
                columns: const [
                  DataColumn(label: Text('Unit')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final unit in units)
                    _buildUnitRow(
                      context,
                      ref,
                      unit,
                      canEditUnit: canEditUnit,
                      canDeleteUnit: canDeleteUnit,
                    ),
                ],
              )
            else
              Column(
                children: [
                  for (final unit in units) ...[
                    _buildUnitCard(
                      context,
                      ref,
                      unit,
                      canEditUnit: canEditUnit,
                      canDeleteUnit: canDeleteUnit,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

DataRow _buildUnitRow(
  BuildContext context,
  WidgetRef ref,
  Unit unit, {
  required bool canEditUnit,
  required bool canDeleteUnit,
}) {
  final statusText = unit.isActive ? 'Active' : 'Inactive';
  final statusColor = unit.isActive ? AppColors.success : AppColors.muted;

  return DataRow(
    cells: [
      DataCell(Text(unit.name)),
      DataCell(
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(statusText),
          ],
        ),
      ),
      DataCell(
        Align(
          alignment: Alignment.centerLeft,
          child: _buildUnitActionsMenu(
            context,
            ref,
            unit,
            canEditUnit: canEditUnit,
            canDeleteUnit: canDeleteUnit,
          ),
        ),
      ),
    ],
  );
}

Widget _buildUnitCard(
  BuildContext context,
  WidgetRef ref,
  Unit unit, {
  required bool canEditUnit,
  required bool canDeleteUnit,
}) {
  return Card(
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (unit.isActive ? AppColors.success : AppColors.muted)
              .withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          unit.isActive
              ? Icons.check_circle_outline
              : Icons.pause_circle_outline,
          color: unit.isActive ? AppColors.success : AppColors.muted,
          size: 18,
        ),
      ),
      title: Text(unit.name),
      subtitle: Text(unit.isActive ? 'Active' : 'Inactive'),
      trailing: _buildUnitActionsMenu(
        context,
        ref,
        unit,
        canEditUnit: canEditUnit,
        canDeleteUnit: canDeleteUnit,
      ),
    ),
  );
}

Widget _buildUnitActionsMenu(
  BuildContext context,
  WidgetRef ref,
  Unit unit, {
  required bool canEditUnit,
  required bool canDeleteUnit,
}) {
  if (!canEditUnit && !canDeleteUnit) {
    return const SizedBox.shrink();
  }

  return PopupMenuButton<String>(
    onSelected: (value) async {
      if (value == 'toggle' && canEditUnit) {
        await ref.read(unitRepositoryProvider).toggleActive(unit.id);
      }
      if (value == 'edit' && canEditUnit) {
        final updated = await showDialog<Unit>(
          context: context,
          builder: (_) => _UnitFormDialog(existing: unit),
        );
        if (updated != null) {
          await ref.read(unitRepositoryProvider).upsert(updated);
        }
      }
      if (value == 'delete' && canDeleteUnit) {
        final confirm = await _confirmDelete(context);
        if (confirm) {
          await ref.read(unitRepositoryProvider).deleteById(unit.id);
        }
      }
    },
    itemBuilder: (_) => [
      if (canEditUnit)
        PopupMenuItem(
          value: 'toggle',
          child: Text(unit.isActive ? 'Deactivate' : 'Activate'),
        ),
      if (canEditUnit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
      if (canDeleteUnit)
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
    ],
  );
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
