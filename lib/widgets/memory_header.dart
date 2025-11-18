import 'package:flutter/material.dart';
import 'package:memories/widgets/timeline_header.dart';

/// Reusable header slivers for unified feed grouping
/// 
/// Provides Year, Season, and Month headers with sticky behavior
/// using the existing TimelineHeader infrastructure.

/// Year header for unified feed
/// 
/// Displays the year (e.g., "2025") and sticks while scrolling
class MemoryYearHeader extends StatelessWidget {
  final int year;

  const MemoryYearHeader({
    super.key,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    return YearHeader(year: year);
  }
}

/// Season header for unified feed
/// 
/// Displays the season (e.g., "Winter", "Spring") and sticks while scrolling
class MemorySeasonHeader extends StatelessWidget {
  final String season;

  const MemorySeasonHeader({
    super.key,
    required this.season,
  });

  @override
  Widget build(BuildContext context) {
    return SeasonHeader(season: season);
  }
}

/// Month header for unified feed
/// 
/// Displays the month name (e.g., "November") and sticks while scrolling
class MemoryMonthHeader extends StatelessWidget {
  final int month;

  const MemoryMonthHeader({
    super.key,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    return MonthHeader(month: month);
  }
}

