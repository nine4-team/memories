/// Localized strings for the capture screen
/// 
/// TODO: Migrate to proper localization using flutter_localizations and .arb files
/// For now, this centralizes strings to make future localization easier
class CaptureStrings {
  // Screen title
  static const String screenTitle = 'Capture Memory';

  // Memory type labels
  static const String memoryTypeMoment = 'Moment';
  static const String memoryTypeStory = 'Story';
  static const String memoryTypeMemento = 'Memento';

  // Dictation
  static const String dictationStartHint = 'Tap the microphone to start dictating';
  static const String dictationStartLabel = 'Start dictation';
  static const String dictationStopLabel = 'Stop dictation';
  static const String dictationCancelLabel = 'Cancel dictation';
  static const String dictationTranscriptLabel = 'Dictation transcript';

  // Description
  static const String descriptionLabel = 'Description (optional)';
  static const String descriptionHint = 'Add any additional details...';
  static const String descriptionInputLabel = 'Description input';

  // Media
  static const String addPhotoLabel = 'Add photo';
  static const String addVideoLabel = 'Add video';
  static const String photoButtonLabel = 'Photo';
  static const String videoButtonLabel = 'Video';
  static const String addPhotoDialogTitle = 'Add Photo';
  static const String addVideoDialogTitle = 'Add Video';
  static const String cameraOption = 'Camera';
  static const String galleryOption = 'Gallery';

  // Tags
  static const String tagsHint = 'Add tags (optional)';

  // Save
  static const String saveButtonLabel = 'Save';
  static const String saveMemoryLabel = 'Save memory';
  static const String savingMemoryLabel = 'Saving memory';
  static const String saveProgressComplete = 'Complete!';
  static const String saveProgressUploadingMedia = 'Uploading media...';
  static const String saveProgressUploadingPhotos = 'Uploading photos...';
  static const String saveProgressUploadingVideos = 'Uploading videos...';
  static const String saveProgressSavingMoment = 'Saving moment...';
  static const String saveProgressGeneratingTitle = 'Generating title...';
  static const String saveProgressCapturingLocation = 'Capturing location...';
  static const String saveProgressPreparing = 'Preparing...';

  // Validation
  static const String saveValidationMementoMessage = 'Please add description text or at least one photo/video';
  static const String saveValidationMessage = 'Please add at least one item (transcript, media, or tag)';

  // Success messages
  static const String memorySavedSuccess = 'Memory saved';
  static const String memorySavedWithLocation = 'Memory saved with location';
  static const String memorySavedWithMedia = 'Memory saved ({count} {item})';
  static const String memorySavedWithLocationAndMedia = 'Memory saved with location ({count} {item})';
  static const String itemSingular = 'item';
  static const String itemPlural = 'items';

  // Title edit dialog
  static const String titleEditDialogLabel = 'Edit title dialog';
  static const String titleEditDialogTitle = 'Edit Title';
  static const String titleEditInputLabel = 'Title input field';
  static const String titleEditInputHint = 'Enter title';
  static const String titleEditKeepOriginalLabel = 'Keep original title';
  static const String titleEditKeepOriginalButton = 'Keep Original';
  static const String titleEditSaveLabel = 'Save edited title';
  static const String titleEditSaveButton = 'Save';

  // Cancel/Discard
  static const String cancelButtonLabel = 'Cancel';
  static const String discardDialogLabel = 'Discard changes confirmation dialog';
  static const String discardDialogTitle = 'Discard changes?';
  static const String discardDialogMessage = 'You have unsaved changes. Are you sure you want to discard them?';
  static const String discardKeepEditingLabel = 'Keep editing';
  static const String discardKeepEditingButton = 'Keep Editing';
  static const String discardChangesLabel = 'Discard changes';
  static const String discardButton = 'Discard';

  // Queue status
  static const String storyQueuedOnline = 'Story queued for sync';
  static const String storyQueuedOffline = 'Story queued for sync when connection is restored';
  static const String memoryQueuedOffline = 'Memory queued for sync when connection is restored';

  // Sync
  static const String syncNowLabel = 'Sync Now';
  static const String syncNowSyncing = 'Syncing queued moments...';
  static const String syncCompleted = 'Sync completed';
  static const String syncFailed = 'Sync failed';

  // Error messages
  static const String errorMessageLabel = 'Error message';
  static const String saveFailedGeneric = 'Failed to save';
  static const String queueFailed = 'Failed to queue story';

  // Retry
  static const String retryButton = 'Retry';
  static const String okButton = 'OK';
}

