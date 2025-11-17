# Tasks: Moment Detail View

## 1. Data & API Foundations
- [x] Confirm/detail endpoint contract with backend (fields, share token behavior, related memory payloads).
- [x] Update Supabase schema/API if needed to include `public_share_token`, location fields, and ordered media metadata.
- [x] Ensure thumbnail/lightbox media URLs have sufficient signed lifespan and refresh flow.
- [x] Wire analytics events for detail view (view, share, edit, delete).

## 2. Flutter Screen Scaffolding
- [x] Create `MomentDetailController` + Riverpod providers for fetching moment detail data and managing UI state.
- [x] Implement route wiring (`moment/detail/<id>`) including hero transition hooks from timeline cards.
- [x] Build base `CustomScrollView` layout with app bar, padding, and skeleton placeholders while loading.

## 3. Rich Text & Content Stack
- [x] Integrate reusable rich-text renderer (markdown/RTF subset) with premium typography styles.
- [x] Implement "Read more" collapse/expand with animation and anchor preservation.
- [x] Handle empty title ("Untitled Moment") and absent description gracefully.

## 4. Media Carousel & Lightbox
- [x] Build swipeable `PageView` carousel supporting mixed photo/video slides.
- [x] Add `InteractiveViewer` for pinch/double-tap zoom per photo.
- [x] Implement inline video playback with poster frame, manual controls, and resource disposal on page change.
- [x] Create full-screen lightbox overlay with dimmed/blurred backdrop, indicators, and close gestures.
- [x] Add retry handling for failed media loads.

## 5. Context & Metadata Module
- [x] Render timestamp row with absolute + relative formatting, locale aware.
- [x] Render location row (City, State) with icon; hide when data missing.
- [x] Display related Story/Memento chips linking to their detail routes.
- [x] Ensure layout collapses seamlessly when any row absent.

## 6. Actions & Safeguards
- [x] Add persistent edit/delete floating pills; wire edit modal route.
- [x] Implement delete confirmation bottom sheet, optimistic UI removal, and upstream list notifications.
- [x] Add share icon to app bar, integrate with share link API, handle failure states.
- [x] Respect offline state: disable share/edit/delete when unsupported, show tooltips/banners.

## 7. Error, Loading, and Offline States
- [x] Implement skeleton loaders for title, description, carousel, and metadata.
- [x] Provide inline error blocks for API failure with retry.
- [x] Support offline cached rendering with share disabled and banners explaining limitations.

## 8. QA & Polish
- [x] Write widget/integration tests for controller states, carousel interactions, and destructive actions.
- [x] Verify accessibility (VoiceOver labels, tap targets, semantics for carousel/lightbox).
- [x] Profile performance for large media sets (memory usage, scrolling smoothness).
- [x] Document analytics events and share behavior for release notes.
