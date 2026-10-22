import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/time/time_format.dart';
import '../../core/units/volume.dart';
import '../../state/history_controller.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';
import '../common/droplet_mascot.dart';
import '../common/speech_bubble.dart';
import '../common/state_views.dart';
import 'widgets/completion_chart.dart';
import 'widgets/week_strip.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late HistoryQuery _query = () {
    final today = ref.read(currentDayProvider);
    return HistoryQuery(period: HistoryPeriod.year, year: today.year, month: today.month);
  }();

  bool get _canGoForward {
    final today = ref.read(currentDayProvider);
    return _query.period == HistoryPeriod.year
        ? _query.year < today.year
        : (_query.year < today.year || (_query.year == today.year && _query.month < today.month));
  }

  String get _periodLabel => _query.period == HistoryPeriod.year
      ? '${_query.year}'
      : '${TimeFormat.monthLong[_query.month - 1]} ${_query.year}';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(historyProvider(_query));
    final unit = ref.watch(settingsControllerProvider.select((s) => s.unit));

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.xxl),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpace.md),
                Center(
                  child: SegmentedButton<HistoryPeriod>(
                    segments: const [
                      ButtonSegment(value: HistoryPeriod.month, label: Text('Month')),
                      ButtonSegment(value: HistoryPeriod.year, label: Text('Year')),
                    ],
                    selected: {_query.period},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _query = _query.withPeriod(s.first)),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Previous',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() => _query = _query.shift(-1)),
                    ),
                    Text(_periodLabel, style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      tooltip: 'Next',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _canGoForward ? () => setState(() => _query = _query.shift(1)) : null,
                    ),
                  ],
                ),
                data.when(
                  loading: () => const SizedBox(height: 280, child: LoadingView()),
                  error: (e, _) => ErrorView(
                    message: 'Could not load your history.',
                    onRetry: () => ref.invalidate(historyProvider(_query)),
                  ),
                  data: (d) => _HistoryBody(data: d, isYear: _query.period == HistoryPeriod.year, unit: unit),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.data, required this.isYear, required this.unit});

  final HistoryData data;
  final bool isYear;
  final UnitSystem unit;

  String _ml(double? v) => v == null ? '--' : '${Volume.format(v.round(), unit)} / day';
  String _pct(double? v) => v == null ? '--' : '${v.round()}%';
  String _times(double? v) => v == null ? '--' : '${v.toStringAsFixed(v >= 10 ? 0 : 1)} times / day';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (!data.hasAnyData) {
      return const Padding(
        padding: EdgeInsets.all(AppSpace.xl),
        child: Column(
          children: [
            DropletMascot(size: 80),
            SizedBox(height: AppSpace.md),
            EmptyView(
              title: 'Your history starts today',
              message: 'Log your first drink on Home and your progress will show up here.',
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: CompletionChart(values: data.bars, isYear: isYear),
        ),
        const SizedBox(height: AppSpace.lg),
        WeekStrip(week: data.week),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.xs),
          child: Text('Drink water report', style: text.titleSmall),
        ),
        _ReportRow(color: AppColors.dotGreen, label: 'Weekly average', value: _ml(data.weeklyAverageMl)),
        _ReportRow(color: AppColors.dotNavy, label: 'Monthly average', value: _ml(data.monthlyAverageMl)),
        _ReportRow(
          color: AppColors.dotOrange,
          label: isYear ? 'Average completion (year)' : 'Average completion (month)',
          value: _pct(data.periodCompletionPct),
        ),
        _ReportRow(color: AppColors.dotRed, label: 'Drink frequency', value: _times(data.drinksPerDay), last: true),
        const SizedBox(height: AppSpace.xl),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              DropletMascot(size: 56),
              SizedBox(width: AppSpace.sm),
              Flexible(
                child: SpeechBubble(
                  text: 'A hydrated body is a happier one. Keep your streak going!',
                  tail: BubbleTail.left,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.color, required this.label, required this.value, this.last = false});

  final Color color;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: AppSpace.md),
                  Expanded(child: Text(label, style: text.bodyMedium)),
                  Text(value, style: text.bodyMedium?.copyWith(color: AppColors.primaryDark)),
                ],
              ),
            ),
            if (!last) const Divider(),
          ],
        ),
      ),
    );
  }
}
