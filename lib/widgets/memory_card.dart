import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/models/timeline_moment.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/widgets/story_card.dart';
import 'package:memories/widgets/moment_card.dart';
import 'package:memories/widgets/memento_card.dart';

/// Unified memory card wrapper that delegates to type-specific cards
/// 
/// Provides consistent padding, typography, and adds a type chip to indicate
/// the memory type (Story/Moment/Memento). Delegates actual rendering to
/// the appropriate card component (StoryCard, MomentCard, MementoCard).
class MemoryCard extends ConsumerWidget {
  final TimelineMoment memory;
  final VoidCallback onTap;

  const MemoryCard({
    super.key,
    required this.memory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine memory type from memoryType
    final memoryType = _getMemoryType(memory.memoryType);

    // Delegate to appropriate card component
    switch (memoryType) {
      case MemoryType.story:
        return StoryCard(
          story: memory,
          onTap: onTap,
        );
      case MemoryType.moment:
        return MomentCard(
          moment: memory,
          onTap: onTap,
        );
      case MemoryType.memento:
        return MementoCard(
          memento: memory,
          onTap: onTap,
        );
    }
  }

  /// Convert memoryType string to MemoryType enum
  MemoryType _getMemoryType(String memoryType) {
    switch (memoryType.toLowerCase()) {
      case 'story':
        return MemoryType.story;
      case 'memento':
        return MemoryType.memento;
      case 'moment':
      default:
        return MemoryType.moment;
    }
  }
}

