import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/time/time_format.dart';
import '../../../core/units/volume.dart';
import '../../../domain/models/cup.dart';
import '../../../domain/models/intake_entry.dart';

/// Result of [showAmountSheet].
class AmountSheetResult {
  const AmountSheetResult(this.amountMl, this.loggedAt);
  final int amountMl;
  final DateTime loggedAt;
}

/// Bottom sheet to log a custom amount or edit an existing drink.
/// Only today's times can be picked, and never a time in the future.
Future<AmountSheetResult?> showAmountSheet(
  BuildContext context, {
  required UnitSystem unit,
  required int initialMl,
  required DateTime initialTime,
  required DateTime now,
  bool editing = false,
  String? title,
  String? submitLabel,
  bool showTime = true,
}) {
  return showModalBottomSheet<AmountSheetResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AmountSheet(
      unit: unit,
      initialMl: initialMl,
      initialTime: initialTime,
      now: now,
      editing: editing,
      title: title,
      submitLabel: submitLabel,
      showTime: showTime,
    ),
  );
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.unit,
    required this.initialMl,
    required this.initialTime,
    required this.now,
    required this.editing,
    required this.title,
    required this.submitLabel,
    required this.showTime,
  });

  final UnitSystem unit;
  final int initialMl;
  final DateTime initialTime;
  final DateTime now;
  final bool editing;
  final String? title;
  final String? submitLabel;
  final bool showTime;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late final TextEditingController _amount =
      TextEditingController(text: Volume.format(widget.initialMl, widget.unit, withUnit: false));
  late TimeOfDay _time = TimeOfDay.fromDateTime(widget.initialTime);
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  DateTime get _pickedDateTime {
    final base = widget.initialTime;
    return DateTime(base.year, base.month, base.day, _time.hour, _time.minute);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    final value = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (value == null) {
      setState(() => _error = 'Enter an amount.');
      return;
    }
    final ml = Volume.toMl(value, widget.unit);
    final amountError = IntakeRules.validateAmount(ml);
    if (amountError != null) {
      setState(() => _error = amountError);
      return;
    }
    final when = _pickedDateTime;
    if (when.isAfter(widget.now.add(const Duration(minutes: 1)))) {
      setState(() => _error = 'Pick a time that has already passed.');
      return;
    }
    Navigator.of(context).pop(AmountSheetResult(ml, when));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.lg + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title ?? (widget.editing ? 'Edit drink' : 'Log a drink'), style: text.titleLarge),
          const SizedBox(height: AppSpace.lg),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final preset in CupPreset.all)
                ActionChip(
                  label: Text(Volume.format(preset.ml, widget.unit)),
                  onPressed: () => setState(() {
                    _amount.text = Volume.format(preset.ml, widget.unit, withUnit: false);
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _amount,
            autofocus: !widget.editing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: Volume.unitLabel(widget.unit),
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.showTime) ...[
            const SizedBox(height: AppSpace.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Time'),
              trailing: Text(TimeFormat.timeOfDay(context, _time), style: text.titleSmall),
              onTap: _pickTime,
            ),
          ],
          const SizedBox(height: AppSpace.md),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.submitLabel ?? (widget.editing ? 'Save' : 'Add drink')),
          ),
        ],
      ),
    );
  }
}
