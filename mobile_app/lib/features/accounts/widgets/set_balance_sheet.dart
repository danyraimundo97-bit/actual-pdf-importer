import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/log/app_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/inline_note.dart';
import '../../../shared/widgets/sheet_body.dart';
import '../account_page_controller.dart';

const _log = AppLog('accounts');

/// Asks what the account really holds. Returns the adjustment the backend
/// added (0 if the balance was already right), or null if cancelled.
Future<int?> showSetBalanceSheet(BuildContext context, {required String accountId, required int currentCents}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SetBalanceSheet(accountId: accountId, currentCents: currentCents),
  );
}

class _SetBalanceSheet extends ConsumerStatefulWidget {
  final String accountId;
  final int currentCents;

  const _SetBalanceSheet({required this.accountId, required this.currentCents});

  @override
  ConsumerState<_SetBalanceSheet> createState() => _SetBalanceSheetState();
}

class _SetBalanceSheetState extends ConsumerState<_SetBalanceSheet> {
  late bool _negative = widget.currentCents < 0;
  String _text = '';
  bool _saving = false;
  String? _error;

  /// A sign toggle rather than a typed minus: many Android number keyboards
  /// have no minus key.
  int? get _targetCents {
    if (_text.trim().isEmpty) return null;
    final cents = parseSignedAmountInput(_text)?.abs();
    if (cents == null) return null;
    return _negative ? -cents : cents;
  }

  Future<void> _save() async {
    final target = _targetCents;
    if (target == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final adjustment = await ref.read(accountPageProvider(widget.accountId).notifier).setBalance(target);
      if (mounted) Navigator.of(context).pop(adjustment);
    } catch (e, stack) {
      _log.error('Balance not set', e, stack, {'account': widget.accountId});
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the balance on this phone.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _targetCents;
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    final difference = target == null ? null : target - widget.currentCents;

    return SheetBody(
      title: 'Set balance',
      description:
          'Enter what this account really holds. Your transactions stay as they are; '
          'the difference is added as one adjustment dated today.',
      actions: [
        OutlinedButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        BusyButton(
          label: _error == null ? 'Save' : 'Try again',
          busy: _saving,
          onPressed: target == null ? null : _save,
        ),
      ],
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Positive'), icon: Icon(Icons.add_rounded)),
            ButtonSegment(value: true, label: Text('Negative'), icon: Icon(Icons.remove_rounded)),
          ],
          selected: {_negative},
          onSelectionChanged: (s) => setState(() => _negative = s.first),
        ),
        const SizedBox(height: Space.lg),
        TextField(
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: figures(context.text.headlineSmall),
          decoration: InputDecoration(
            labelText: 'Real balance',
            hintText: '0,00',
            prefixText: _negative ? '− ' : null,
            suffixText: ' €',
          ),
          onChanged: (text) => setState(() {
            _text = text;
            _error = null;
          }),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: Space.md),
        Text('Current balance: ${formatCents(widget.currentCents)}', style: muted),
        if (difference != null)
          Text(difference == 0 ? 'No adjustment needed.' : 'Adjustment: ${formatCents(difference)}', style: muted),
        if (_error != null) ...[const SizedBox(height: Space.md), InlineNote(message: _error!, tone: NoteTone.error)],
      ],
    );
  }
}
