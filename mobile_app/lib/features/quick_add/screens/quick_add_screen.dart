import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/log/app_log.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/ledger_store.dart';
import '../../../data/models/quick_add.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/category_emoji.dart';
import '../../../shared/widgets/category_picker_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/inline_note.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../accounts/widgets/account_sheet.dart';
import '../quick_add_controller.dart';

const _log = AppLog('quick-add');

/// Add a transaction in seconds (e.g. a cash purchase): amount first, with
/// the keyboard already open, then payee (suggested from recent ones, which
/// also pre-fill the category), category, account, date and a note.
class QuickAddScreen extends ConsumerWidget {
  const QuickAddScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(quickAddOptionsProvider);
    final body = options.when(
      data: (o) => _QuickAddForm(options: o),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetry(
        message: e is ApiException ? e.message : 'Could not load your accounts and categories.',
        onRetry: () => ref.invalidate(quickAddOptionsProvider),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Add transaction'),
      ),
      body: body,
    );
  }
}

class _QuickAddForm extends ConsumerStatefulWidget {
  final QuickAddOptions options;

  const _QuickAddForm({required this.options});

  @override
  ConsumerState<_QuickAddForm> createState() => _QuickAddFormState();
}

class _QuickAddFormState extends ConsumerState<_QuickAddForm> {
  @override
  void initState() {
    super.initState();
    _applyOptions();
  }

  @override
  void didUpdateWidget(_QuickAddForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An account was just added here.
    if (oldWidget.options != widget.options) _applyOptions();
  }

  void _applyOptions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(quickAddControllerProvider.notifier).applyOptions(widget.options);
    });
  }

  Future<void> _addAccount() async {
    final edit = await showAccountSheet(context);
    if (edit == null) return;
    final id = await ref
        .read(ledgerStoreProvider)
        .createAccount(phoneScope, name: edit.name, offBudget: edit.offBudget, openingBalanceCents: edit.balanceCents);
    _log.info('Account added', {'account': id});
    ref.invalidate(quickAddOptionsProvider);
  }

  QuickAddController get _controller => ref.read(quickAddControllerProvider.notifier);

  Future<void> _pickCategory(bool income) async {
    final groups = widget.options.categoryGroups
        .where((g) => widget.options.incomeGroupIds.contains(g.id) == income)
        .toList();
    final choice = await pickCategory(context, groups.isEmpty ? widget.options.categoryGroups : groups);
    if (choice != null) _controller.setCategory(choice.id, choice.name);
  }

  Future<void> _pickDate(DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) _controller.setDate(picked);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final state = ref.read(quickAddControllerProvider);
    final ok = await _controller.save();
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    final what = state.payee.trim().isEmpty ? '' : ' at ${state.payee.trim()}';
    messenger.showSnackBar(SnackBar(content: Text('Added ${formatCents(state.amountCents!)}$what.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickAddControllerProvider);
    final colors = context.colors;
    final muted = context.text.bodyMedium?.copyWith(color: colors.onSurfaceVariant);
    final options = widget.options;

    if (options.accounts.isEmpty) {
      final onPhone = ref.watch(readsLedgerProvider).valueOrNull ?? true;
      if (!onPhone) {
        return Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Text('This budget has no open accounts yet. Create one in Actual first.', style: muted),
        );
      }
      return EmptyState(
        icon: Icons.account_balance_outlined,
        title: 'Add an account first',
        message: 'A transaction goes into an account. Add one to keep on this phone.',
        actionLabel: 'Add account',
        actionIcon: Icons.add_rounded,
        onAction: _addAccount,
      );
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final dateLabel = DateUtils.isSameDay(state.date, today)
        ? 'Today'
        : DateUtils.isSameDay(state.date, today.subtract(const Duration(days: 1)))
            ? 'Yesterday'
            : formatDisplayDate(state.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Expense'), icon: Icon(Icons.remove_rounded)),
                  ButtonSegment(value: true, label: Text('Income'), icon: Icon(Icons.add_rounded)),
                ],
                selected: {state.income},
                onSelectionChanged: (s) => _controller.setIncome(s.first),
              ),
              const SizedBox(height: Space.xl),
              _AmountField(income: state.income, onChanged: _controller.setAmount),
              const SizedBox(height: Space.xl),
              LabeledField(
                label: 'Payee',
                child: _PayeeField(
                  options: options,
                  onChanged: (name) => _controller.setPayee(name, options: options),
                ),
              ),
              const SizedBox(height: Space.lg),
              LabeledField(
                label: 'Category',
                child: _PickerTile(
                  icon: Icons.sell_outlined,
                  label: state.categoryName == null
                      ? 'No category'
                      : withEmoji(widget.options.categoryEmoji(state.categoryId), state.categoryName!),
                  muted: state.categoryName == null,
                  onTap: () => _pickCategory(state.income),
                ),
              ),
              const SizedBox(height: Space.lg),
              LabeledField(
                label: 'Account',
                child: DropdownButtonFormField<String>(
                  key: ValueKey(state.accountId),
                  initialValue: state.accountId,
                  isExpanded: true,
                  items: [
                    for (final a in options.accounts)
                      DropdownMenuItem(
                        value: a.id,
                        child: Text(a.offbudget ? '${a.name} (off budget)' : a.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) {
                    if (id != null) _controller.setAccount(id);
                  },
                ),
              ),
              const SizedBox(height: Space.lg),
              LabeledField(
                label: 'Date',
                child: _PickerTile(
                  icon: Icons.event_outlined,
                  label: dateLabel,
                  onTap: () => _pickDate(state.date),
                ),
              ),
              const SizedBox(height: Space.lg),
              LabeledField(
                label: 'Note',
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Optional'),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: _controller.setNotes,
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: Space.lg),
                InlineNote(message: state.error!, tone: NoteTone.error),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
            child: BusyButton(
              label: state.error == null ? 'Save' : 'Try again',
              busy: state.saving,
              onPressed: state.canSave ? _save : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  final bool income;
  final ValueChanged<String> onChanged;

  const _AmountField({required this.income, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = figures(context.text.displaySmall).copyWith(
      color: income ? colors.primary : colors.onSurface,
      fontWeight: FontWeight.w600,
    );
    return TextField(
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      textAlign: TextAlign.center,
      style: style,
      decoration: InputDecoration(
        hintText: '0,00',
        prefixText: income ? '+ ' : '− ',
        suffixText: ' €',
        prefixStyle: style,
        suffixStyle: style.copyWith(color: colors.onSurfaceVariant),
        border: InputBorder.none,
        filled: false,
      ),
      onChanged: onChanged,
    );
  }
}

class _PayeeField extends StatelessWidget {
  final QuickAddOptions options;
  final ValueChanged<String> onChanged;

  const _PayeeField({required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Autocomplete<RecentPayee>(
      displayStringForOption: (p) => p.name,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable.empty();
        return options.recentPayees.where((p) => p.name.toLowerCase().contains(query)).take(6);
      },
      onSelected: (p) => onChanged(p.name),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
        controller: controller,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(hintText: 'Who was it?'),
        onChanged: onChanged,
        onSubmitted: (_) => onSubmitted(),
      ),
      optionsViewBuilder: (context, onSelected, matches) {
        final colors = context.colors;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 3,
            color: colors.surfaceContainerHigh,
            borderRadius: Radii.controlAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final p in matches)
                    ListTile(
                      dense: true,
                      title: Text(p.name),
                      subtitle: options.categoryName(p.lastCategoryId) == null
                          ? null
                          : Text(withEmoji(options.categoryEmoji(p.lastCategoryId), options.categoryName(p.lastCategoryId)!)),
                      onTap: () => onSelected(p),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool muted;
  final VoidCallback onTap;

  const _PickerTile({required this.icon, required this.label, required this.onTap, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: Radii.controlAll,
      child: InkWell(
        borderRadius: Radii.controlAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md + 2),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colors.onSurfaceVariant),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  label,
                  style: context.text.bodyLarge?.copyWith(color: muted ? colors.onSurfaceVariant : colors.onSurface),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
