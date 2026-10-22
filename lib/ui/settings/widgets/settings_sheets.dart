import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tokens.dart';

class ChoiceOption<T> {
  const ChoiceOption(this.value, this.label, {this.description});
  final T value;
  final String label;
  final String? description;
}

/// Single-choice bottom sheet. Returns the picked value, or null if dismissed.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<ChoiceOption<T>> options,
  required T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          RadioGroup<T>(
            groupValue: selected,
            onChanged: (v) => Navigator.of(context).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final o in options)
                  RadioListTile<T>(
                    value: o.value,
                    title: Text(o.label),
                    subtitle: o.description == null ? null : Text(o.description!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
        ],
      ),
    ),
  );
}

/// Numeric input sheet with validation. Returns the parsed number or null.
Future<double?> showNumberSheet(
  BuildContext context, {
  required String title,
  required String label,
  required String suffix,
  required double? initial,
  required String? Function(double value) validate,
  bool decimal = false,
  String? helper,
  ({String label, double value})? suggestion,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _NumberSheet(
      title: title,
      label: label,
      suffix: suffix,
      initial: initial,
      validate: validate,
      decimal: decimal,
      helper: helper,
      suggestion: suggestion,
    ),
  );
}

class _NumberSheet extends StatefulWidget {
  const _NumberSheet({
    required this.title,
    required this.label,
    required this.suffix,
    required this.initial,
    required this.validate,
    required this.decimal,
    required this.helper,
    required this.suggestion,
  });

  final String title;
  final String label;
  final String suffix;
  final double? initial;
  final String? Function(double value) validate;
  final bool decimal;
  final String? helper;
  final ({String label, double value})? suggestion;

  @override
  State<_NumberSheet> createState() => _NumberSheetState();
}

class _NumberSheetState extends State<_NumberSheet> {
  late final TextEditingController _ctrl = TextEditingController(text: _fmt(widget.initial));
  String? _error;

  String _fmt(double? v) {
    if (v == null) return '';
    return widget.decimal ? v.toStringAsFixed(1) : v.round().toString();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (v == null) {
      setState(() => _error = 'Enter a number.');
      return;
    }
    final err = widget.validate(v);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = widget.suggestion;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: text.titleLarge),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(widget.decimal ? r'[0-9.,]' : r'[0-9]'))],
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: widget.label,
              suffixText: widget.suffix,
              helperText: widget.helper,
              helperMaxLines: 3,
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          if (s != null) ...[
            const SizedBox(height: AppSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _ctrl.text = _fmt(s.value);
                  _error = null;
                }),
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(s.label),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          FilledButton(onPressed: _submit, child: const Text('Save')),
        ],
      ),
    );
  }
}
