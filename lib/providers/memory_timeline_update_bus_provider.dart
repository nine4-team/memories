import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_timeline_update_bus_provider.g.dart';

/// Event types for memory timeline updates
enum MemoryTimelineEventType {
  /// Memory was created on the server
  created,

  /// Memory was updated on the server
  updated,

  /// Memory was deleted on the server
  deleted,
}

/// Event representing a memory timeline update
class MemoryTimelineEvent {
  /// The type of event
  final MemoryTimelineEventType type;

  /// The ID of the memory that was updated or deleted
  final String memoryId;

  /// Create a created event
  MemoryTimelineEvent.created(this.memoryId) : type = MemoryTimelineEventType.created;

  /// Create an updated event
  MemoryTimelineEvent.updated(this.memoryId) : type = MemoryTimelineEventType.updated;

  /// Create a deleted event
  MemoryTimelineEvent.deleted(this.memoryId) : type = MemoryTimelineEventType.deleted;

  @override
  String toString() => 'MemoryTimelineEvent($type, $memoryId)';
}

/// Bus for emitting memory timeline update events
///
/// This decouples capture/detail screens from the unified feed controller.
/// Screens emit events when memories are updated or deleted, and the feed
/// controller subscribes to react accordingly.
class MemoryTimelineUpdateBus {
  final StreamController<MemoryTimelineEvent> _controller;

  MemoryTimelineUpdateBus() : _controller = StreamController<MemoryTimelineEvent>.broadcast();

  /// Stream of memory timeline events
  Stream<MemoryTimelineEvent> get stream => _controller.stream;

  /// Emit a created event for a memory
  void emitCreated(String memoryId) {
    debugPrint('[MemoryTimelineUpdateBus] Emitting created event for memory: $memoryId');
    _controller.add(MemoryTimelineEvent.created(memoryId));
  }

  /// Emit an updated event for a memory
  void emitUpdated(String memoryId) {
    debugPrint('[MemoryTimelineUpdateBus] Emitting updated event for memory: $memoryId');
    _controller.add(MemoryTimelineEvent.updated(memoryId));
  }

  /// Emit a deleted event for a memory
  void emitDeleted(String memoryId) {
    debugPrint('[MemoryTimelineUpdateBus] Emitting deleted event for memory: $memoryId');
    _controller.add(MemoryTimelineEvent.deleted(memoryId));
  }

  /// Dispose the bus and close the stream controller
  void dispose() {
    _controller.close();
  }
}

/// Provider for the memory timeline update bus
///
/// Kept alive so all parts of the app (timeline, capture, detail) share
/// a single global bus instance. This prevents events from being missed
/// due to provider disposal or separate instances per scope.
@Riverpod(keepAlive: true)
MemoryTimelineUpdateBus memoryTimelineUpdateBus(MemoryTimelineUpdateBusRef ref) {
  final bus = MemoryTimelineUpdateBus();
  ref.onDispose(() {
    bus.dispose();
  });
  return bus;
}

