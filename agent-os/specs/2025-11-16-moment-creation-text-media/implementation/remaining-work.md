# Remaining Work — Moment Creation (Text + Media)

**Created:** 2025-01-17  
**Status:** In Progress  
**Spec:** `2025-11-16-moment-creation-text-media`

This document tracks all remaining work for the moment creation feature. Core functionality (Phases 1-3) is implemented, but several gaps remain.

---

## Phase 1 — Migrations & Documentation

### 1.1 Create SQL Migration for Schema Changes

**Status:** ✅ Completed  
**Priority:** Low (useful for documentation/reproducibility, but not blocking)

**Implementation:**
Created migration file documenting all schema changes:
- New columns on `moments` table: `raw_transcript`, `generated_title`, `title_generated_at`, `tags`, `captured_location`, `location_status`, `capture_type`
- New enum: `capture_type` with values `'moment'`, `'story'`, `'memento'`
- New indexes: GIN on `tags`, GiST on `captured_location`, partial on `title_generated_at`, btree on `capture_type`
- New table: `media_cleanup_queue` with RLS policies

**Reference files:**
- Migration file: `supabase/migrations/20250116000000_extend_moments_table_for_text_media_capture.sql`
- Migration example: `agent-os/specs/2025-11-16-user-auth-and-profile/implementation/20250117000000_create_profiles_table.sql`
- Migration standards: `agent-os/standards/backend/migrations.md`
- Schema details: `agent-os/specs/2025-11-16-moment-creation-text-media/implementation/phase-1.md` (lines 7-14)

**Note:** The schema is already live in Supabase, so this migration is for documentation/reproducibility. It's not blocking functionality.

---

## Phase 3 — Infrastructure Verification & Edge Cases

### 3.1 Verify Supabase Storage Buckets

**Status:** ✅ Completed  
**Priority:** High (blocking for production)

**Verification:**
- Created `moments-photos` bucket with 10MB limit, private access
- Created `moments-videos` bucket with 100MB limit, private access
- Buckets configured with appropriate MIME types (images: jpeg, png, webp, heic; videos: mp4, quicktime, avi)
- Buckets are private (public: false) for security

**Note:** RLS policies need to be configured separately to allow authenticated users to upload to `{user_id}/*` paths. This should be done via Supabase dashboard or migration.

**Reference files:**
- Save service: `lib/services/moment_save_service.dart` (lines 48-49, 82-120)
- Storage paths: Uses `{user_id}/{timestamp}_{index}.{ext}` format

---

### 3.2 Verify PostGIS Location Format

**Status:** ✅ Verified  
**Priority:** High (blocking for location capture)

**Verification:**
- Verified that PostgreSQL accepts `'POINT(longitude latitude)'::geography` format
- Tested casting WKT string directly to geography type - works correctly
- The `captured_location` column is correctly typed as `geography(Point,4326)`
- Save service uses correct format: `'POINT(${state.longitude} ${state.latitude})'`

**Current implementation:**
- Format: `POINT(longitude latitude)` as WKT string, cast to geography
- Location: `lib/services/moment_save_service.dart` (lines 202-228)

**Reference:**
- Spec requirement: `captured_location geography(Point,4326)` (nullable)
- Implementation: `agent-os/specs/2025-11-16-moment-creation-text-media/implementation/phase-3.md` (lines 152-155)

---

### 3.3 Add Retry Logic for Media Uploads

**Status:** ✅ Completed

**Implementation:**
- Added retry logic with exponential backoff (1s, 2s, 4s)
- Per-file retries for photos and videos (max 3 attempts)
- 30-second timeout per upload attempt
- Progress callbacks show retry status
- Handles partial uploads (continues with successful files)

**Reference files:**
- Service: `lib/services/moment_save_service.dart` (lines 99-205)

---

### 3.4 Improve Error Handling & User Feedback

**Status:** ✅ Completed

**Implementation:**
- Created specific exception types: `OfflineException`, `StorageQuotaException`, `NetworkException`, `PermissionException`, `SaveException`
- User-friendly error messages with actionable guidance
- Retry buttons for recoverable errors (NetworkException, generic errors)
- Error recovery preserves capture state (doesn't clear on error)
- Specific messages for each error type

**Reference files:**
- Service: `lib/services/moment_save_service.dart` (lines 339-382)
- UI: `lib/screens/capture/capture_screen.dart` (lines 240-301)

---

## Phase 3b — Offline Capture & Sync (REQUIRED BY SPEC)

**Status:** ✅ Completed  
**Priority:** High (required by spec user story)

**Reference:** Spec user story: "As a traveler who is often offline, I want the app to queue whatever I captured so nothing is lost and everything syncs automatically when service returns."

### 3b.1 Offline Queue Data Layer

**Status:** ✅ Completed

**Implementation:**
- Created `QueuedMoment` model with JSON serialization
- Implemented `OfflineQueueService` using SharedPreferences
- Stores transcript, metadata, media file paths, and deterministic local IDs
- Queue writes happen immediately when offline or when uploads fail
- Status tracking: 'queued', 'syncing', 'failed', 'completed'
- Modified `MomentSaveService` to check connectivity and queue if offline

**Reference files:**
- Model: `lib/models/queued_moment.dart`
- Service: `lib/services/offline_queue_service.dart`
- Save service: `lib/services/moment_save_service.dart`

---

### 3b.2 Sync Engine & Status UX

**Status:** ✅ Completed

**Implementation:**
- Created `MomentSyncService` with automatic retry
- Monitors connectivity changes using a custom Dart-only `ConnectivityService` (no `connectivity_plus` plugin)
- Retry logic with exponential backoff (max 3 attempts)
- Background sync every 30 seconds when online
- Updates queue status as sync progresses
- ✅ **Sync service initialization** — Implemented via `SyncServiceInitializer` widget
- ✅ **UI status chips** — Added queue status chips to capture screen
- ✅ **Manual "Sync now" action** — Added to capture screen overflow menu

**Reference files:**
- Service: `lib/services/moment_sync_service.dart`
- Connectivity: `lib/services/connectivity_service.dart`
- Initializer: `lib/widgets/sync_service_initializer.dart`
- Status chips: `lib/widgets/queue_status_chips.dart`

---

## Phase 4 — Post-Save & Navigation (REQUIRED BY SPEC)

**Status:** ⚠️ Partial  
**Priority:** High (required by spec)

**Reference:** Spec requirement: "After Save completes, navigate to the relevant detail screen and surface a toast summarizing uploads."

### 4.1 Navigate to Detail View After Save

**Status:** ✅ Completed

**Implementation:**
- Created minimal `MomentDetailScreen` for displaying saved moments
- Updated capture screen to navigate to detail view after successful save
- Shows moment title, description, transcript, tags, and media counts
- Navigates with moment ID from save result

**Note:** This is a minimal implementation. Full detail view per spec will be implemented separately.

**Reference files:**
- Detail screen: `lib/screens/moment/moment_detail_screen.dart`
- Capture screen: `lib/screens/capture/capture_screen.dart` (lines 230-238)

---

### 4.2 Accessibility & Localization Review

**Status:** ⚠️ Needs Review  
**Priority:** Medium

**What's needed:**
Review accessibility and localization for the capture flow.

**Current state:**
- Some Semantics widgets exist in `capture_screen.dart`
- Hardcoded strings throughout (not localized)

**Review checklist:**
- [ ] All interactive elements have proper Semantics labels
- [ ] Progress indicators have semantic labels
- [ ] Error messages are properly announced
- [ ] All user-facing strings are extracted for localization
- [ ] Minimum touch target sizes (44px) maintained
- [ ] Voice-over labels work correctly

**Reference files:**
- Capture screen: `lib/screens/capture/capture_screen.dart`
- Standards: `agent-os/standards/frontend/` (if exists)

---

## Testing (Optional for v0)

**Status:** ⚠️ Not Started  
**Priority:** Low (can be deferred)

**Note:** For v0, manual testing may be sufficient. Tests become more valuable as the codebase grows.

### Test Coverage Needed

**Unit tests:**
- `test/services/geolocation_service_test.dart`
- `test/services/moment_save_service_test.dart`
- `test/services/title_generation_service_test.dart`
- `test/providers/capture_state_provider_test.dart`

**Widget tests:**
- `test/widgets/capture_screen_test.dart`

**Integration tests:**
- `test/integration/capture_flow_integration_test.dart`

**Reference:**
- Test setup: `test/README.md`
- Test helpers: `test/helpers/test_supabase_setup.dart`
- Phase 3 doc: `implementation/phase-3.md` (lines 66-109)

---

## Summary of Priorities

### High Priority (Required by Spec)
1. ✅ **Phase 3b: Offline Queue** — Required by user story (COMPLETED)
2. ✅ **Phase 3b: Sync Engine** — Required by user story (COMPLETED)
3. ✅ **Phase 4.1: Navigate to Detail View** — Required by spec (COMPLETED - minimal implementation)
4. ✅ **Sync Service Initialization** — Implemented via SyncServiceInitializer widget
5. ✅ **UI Status Chips** — Added queue status chips to capture screen

### Medium Priority (Improves Reliability/UX)
6. ✅ **Retry Logic** — Per spec requirement (COMPLETED)
7. ✅ **Error Handling** — Better user feedback (COMPLETED)
8. ✅ **Infrastructure Verification** — Storage buckets created, PostGIS format verified
9. ✅ **Manual "Sync now" Action** — Added to capture screen overflow menu

### Low Priority (Nice to Have)
10. ✅ **Migrations** — Documentation/reproducibility (COMPLETED)
11. ⚠️ **Accessibility Review** — Quality improvement
12. ⚠️ **Testing** — Can be deferred for v0

---

## New Tasks Added

### Sync Service Initialization

**Status:** ✅ Completed  
**Priority:** High

**Implementation:**
- Created `SyncServiceInitializer` widget that initializes sync service when mounted
- Integrated into `AppRouter` for authenticated state
- Starts auto-sync when user is authenticated, stops when disposed
- Sync service monitors connectivity and syncs queued moments automatically

**Reference files:**
- Sync service: `lib/services/moment_sync_service.dart`
- Initializer widget: `lib/widgets/sync_service_initializer.dart`
- App router: `lib/app_router.dart` (lines 55-64)

---

### UI Status Chips for Queue

**Status:** ✅ Completed  
**Priority:** High

**Implementation:**
- Created `QueueStatusProvider` that watches queue service and provides status data
- Built `QueueStatusChips` widget displaying "Queued", "Syncing", and "Needs Attention" chips
- Integrated into capture screen at the top (above main content)
- Chips show counts when multiple items exist
- Status updates automatically via Riverpod provider invalidation
- Added manual "Sync now" action to capture screen overflow menu

**Reference files:**
- Queue service: `lib/services/offline_queue_service.dart`
- Queue status provider: `lib/providers/queue_status_provider.dart`
- Status chips widget: `lib/widgets/queue_status_chips.dart`
- Capture screen: `lib/screens/capture/capture_screen.dart` (lines 430, 574-625)

---

## Notes

- **Migrations:** Even though schema is already live, migrations are useful for documentation and reproducibility. Not blocking for v0.
- **Testing:** Can be deferred for v0. Manual testing is sufficient initially.
- **Phase 3b & 4:** Core functionality completed. Remaining items are UI enhancements and initialization.
- **Infrastructure:** Should be verified before production deployment.
- **Storage:** Using SharedPreferences with JSON serialization for queue storage. This is sufficient for small queues but may need migration to Hive/SQLite if queue grows large.

---

## Related Files

- **Spec:** `spec.md`
- **Tasks:** `tasks.md`
- **Phase 1 Implementation:** `implementation/phase-1.md`
- **Phase 2 Implementation:** `implementation/phase-2.md`
- **Phase 3 Implementation:** `implementation/phase-3.md`
- **Verification Report:** `verifications/final-verification.md`
- **Migration Standards:** `agent-os/standards/backend/migrations.md`
- **Migration Example:** `agent-os/specs/2025-11-16-user-auth-and-profile/implementation/20250117000000_create_profiles_table.sql`

