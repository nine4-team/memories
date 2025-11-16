# Tasks: Moment Detail View

## 1. Data & API Foundations
- [ ] Confirm/detail endpoint contract with backend (fields, share token behavior, related memory payloads).
- [ ] Update Supabase schema/API if needed to include `public_share_token`, location fields, and ordered media metadata.
- [ ] Ensure thumbnail/lightbox media URLs have sufficient signed lifespan and refresh flow.
- [ ] Wire analytics events for detail view (view, share, edit, delete).

## 2. Flutter Screen Scaffolding
- [ ] Create `MomentDetailController` + Riverpod providers for fetching moment detail data and managing UI state.
- [ ] Implement route wiring (`moment/detail/<id>`) including hero transition hooks from timeline cards.
- [ ] Build base `CustomScrollView` layout with app bar, padding, and skeleton placeholders while loading.

## 3. Rich Text & Content Stack
- [ ] Integrate reusable rich-text renderer (markdown/RTF subset) with premium typography styles.
- [ ] Implement “Read more” collapse/expand with animation and anchor preservation.
- [ ] Handle empty title (“Untitled Moment”) and absent description gracefully.

## 4. Media Carousel & Lightbox
- [ ] Build swipeable `PageView` carousel supporting mixed photo/video slides.
- [ ] Add `InteractiveViewer` for pinch/double-tap zoom per photo.
- [ ] Implement inline video playback with poster frame, manual controls, and resource disposal on page change.
- [ ] Create full-screen lightbox overlay with dimmed/blurred backdrop, indicators, and close gestures.
- [ ] Add retry handling for failed media loads.

## 5. Context & Metadata Module
- [ ] Render timestamp row with absolute + relative formatting, locale aware.
- [ ] Render location row (City, State) with icon; hide when data missing.
- [ ] Display related Story/Memento chips linking to their detail routes.
- [ ] Ensure layout collapses seamlessly when any row absent.

## 6. Actions & Safeguards
- [ ] Add persistent edit/delete floating pills; wire edit modal route.
- [ ] Implement delete confirmation bottom sheet, optimistic UI removal, and upstream list notifications.
- [ ] Add share icon to app bar, integrate with share link API, handle failure states.
- [ ] Respect offline state: disable share/edit/delete when unsupported, show tooltips/banners.

## 7. Error, Loading, and Offline States
- [ ] Implement skeleton loaders for title, description, carousel, and metadata.
- [ ] Provide inline error blocks for API failure with retry.
- [ ] Support offline cached rendering with share disabled and banners explaining limitations.

## 8. QA & Polish
- [ ] Write widget/integration tests for controller states, carousel interactions, and destructive actions.
- [ ] Verify accessibility (VoiceOver labels, tap targets, semantics for carousel/lightbox).
- [ ] Profile performance for large media sets (memory usage, scrolling smoothness).
- [ ] Document analytics events and share behavior for release notes.
