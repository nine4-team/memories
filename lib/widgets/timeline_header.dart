import 'package:flutter/material.dart';

/// Sticky header for timeline hierarchy (Year → Season → Month)
class TimelineHeader extends SliverPersistentHeaderDelegate {
  final String label;
  final double minHeight;
  final double maxHeight;

  TimelineHeader({
    required this.label,
    this.minHeight = 48,
    this.maxHeight = 56,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = shrinkOffset / maxExtent;
    final opacity = 1.0 - (progress * 0.3).clamp(0.0, 0.3);

    return Semantics(
      header: true,
      label: label,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Opacity(
              opacity: opacity,
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant TimelineHeader oldDelegate) {
    return oldDelegate.label != label;
  }

  // Optional configuration methods - not all Flutter versions support these
  // They can be omitted if not available in the Flutter version being used

  @override
  TickerProvider get vsync {
    // This should never be called when used with SliverPersistentHeader
    throw UnimplementedError(
      'vsync is provided by SliverPersistentHeader widget',
    );
  }
}

/// Year header widget
class YearHeader extends StatelessWidget {
  final int year;

  const YearHeader({super.key, required this.year});

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: TimelineHeader(
        label: year.toString(),
        minHeight: 56,
        maxHeight: 64,
      ),
    );
  }
}

/// Season header widget
class SeasonHeader extends StatelessWidget {
  final String season;

  const SeasonHeader({super.key, required this.season});

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: TimelineHeader(
        label: season,
        minHeight: 48,
        maxHeight: 52,
      ),
    );
  }
}

/// Month header widget
class MonthHeader extends StatelessWidget {
  final int month;

  const MonthHeader({super.key, required this.month});

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: TimelineHeader(
        label: _getMonthName(month),
        minHeight: 44,
        maxHeight: 48,
      ),
    );
  }
}

