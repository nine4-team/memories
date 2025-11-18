import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'feature_flags_provider.g.dart';

/// Feature flag for the new dictation plugin behavior
/// 
/// When enabled, uses the latest plugin build that surfaces raw-audio references
/// along with streaming transcripts/event channels.
/// 
/// Default: false (legacy behavior) for QA comparison before broad rollout.
@riverpod
Future<bool> useNewDictationPlugin(UseNewDictationPluginRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('feature_flag_new_dictation_plugin') ?? false;
}

/// Synchronous provider that watches the async feature flag
/// Returns false if the async provider is loading or has an error
@riverpod
bool useNewDictationPluginSync(UseNewDictationPluginSyncRef ref) {
  final asyncValue = ref.watch(useNewDictationPluginProvider);
  return asyncValue.valueOrNull ?? false;
}

/// Set the new dictation plugin feature flag
Future<void> setUseNewDictationPlugin(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('feature_flag_new_dictation_plugin', enabled);
}

