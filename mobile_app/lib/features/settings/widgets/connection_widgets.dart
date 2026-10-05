import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/actual_budget.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/skeleton.dart';

/// Importer address + access token, shared by Settings and the setup guide.
class ConnectionFields extends StatefulWidget {
  final TextEditingController urlController;
  final TextEditingController tokenController;
  final VoidCallback? onSubmitted;

  const ConnectionFields({
    super.key,
    required this.urlController,
    required this.tokenController,
    this.onSubmitted,
  });

  @override
  State<ConnectionFields> createState() => _ConnectionFieldsState();
}

class _ConnectionFieldsState extends State<ConnectionFields> {
  bool _showToken = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: 'Importer address',
          helper: 'Where backend_app is running on your network.',
          child: TextField(
            controller: widget.urlController,
            decoration: const InputDecoration(hintText: 'http://192.168.1.10:3000'),
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: Space.lg),
        LabeledField(
          label: 'Access token',
          helper: 'The IMPORT_TOKEN from the backend .env file.',
          child: TextField(
            controller: widget.tokenController,
            obscureText: !_showToken,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => widget.onSubmitted?.call(),
            decoration: InputDecoration(
              suffixIcon: IconButton(
                tooltip: _showToken ? 'Hide token' : 'Show token',
                icon: Icon(
                  _showToken ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _showToken = !_showToken),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The budgets on the Actual server, with the active one marked.
class BudgetList extends StatelessWidget {
  final List<ActualBudget> budgets;
  final bool loading;
  final String? selectedSyncId;
  final ValueChanged<ActualBudget> onSelect;

  const BudgetList({
    super.key,
    required this.budgets,
    required this.loading,
    required this.selectedSyncId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SkeletonRows(count: 3, twoLine: false, padding: EdgeInsets.zero);
    }
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        borderRadius: Radii.controlAll,
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < budgets.length; i++) ...[
            if (i > 0) const Divider(),
            _BudgetTile(
              budget: budgets[i],
              selected: budgets[i].syncId == selectedSyncId,
              onTap: () => onSelect(budgets[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  final ActualBudget budget;
  final bool selected;
  final VoidCallback onTap;

  const _BudgetTile({required this.budget, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.primary.withValues(alpha: 0.07) : colors.surfaceContainerLowest,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
        leading: Icon(budget.encrypted ? Icons.lock_outline_rounded : Icons.folder_outlined),
        title: Text(budget.name),
        subtitle: budget.encrypted ? const Text('End-to-end encrypted') : null,
        trailing: selected ? Icon(Icons.check_circle_rounded, color: colors.primary) : null,
        selected: selected,
        onTap: onTap,
      ),
    );
  }
}
