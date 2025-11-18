import 'package:shared_preferences/shared_preferences.dart';
import 'package:memories/models/memory_type.dart';

/// Service for persisting the last-selected tab in the unified feed
class UnifiedFeedTabPersistenceService {
  static const String _tabKey = 'unified_feed_last_selected_tab';

  /// Get the last selected tab
  /// 
  /// Returns null if no tab was previously selected (defaults to 'all')
  Future<MemoryType?> getLastSelectedTab() async {
    final prefs = await SharedPreferences.getInstance();
    final tabValue = prefs.getString(_tabKey);
    
    if (tabValue == null || tabValue == 'all') {
      return null; // null represents 'all'
    }
    
    return MemoryTypeExtension.fromApiValue(tabValue);
  }

  /// Save the last selected tab
  /// 
  /// [tab] is the memory type filter (null for 'all')
  Future<void> saveLastSelectedTab(MemoryType? tab) async {
    final prefs = await SharedPreferences.getInstance();
    final tabValue = tab?.apiValue ?? 'all';
    await prefs.setString(_tabKey, tabValue);
  }

  /// Clear the saved tab preference
  Future<void> clearSavedTab() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tabKey);
  }
}

