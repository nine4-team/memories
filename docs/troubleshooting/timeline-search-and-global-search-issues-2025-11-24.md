## Timeline Search & Global Search Issues (Unresolved)

**Date:** 2025-11-24  
**Status:** 🔴 Unresolved  

This document tracks two related but distinct problems with the new global search integration on the Timeline screen:

- **Issue A:** Timeline search empty state UI is visually broken.  
- **Issue B:** Search results are incomplete / missing even when the query is definitely present in both tags and the `search_vector` field.

---

## Issue A — Timeline Search Empty State UI Broken

### Problem Description

When searching from the Timeline tab using the global search field, the **“No memories match your search”** empty state renders in a corrupted layout:

- The icon and text are squashed into a very narrow vertical strip on the **left side** of the screen.
- The message text effectively appears as **one character per line**, running down the side of the viewport.
- The rest of the content area is mostly blank whitespace.

**Expected behavior:**

- The empty state should be horizontally centered under the global search bar, with the icon and text in a compact column.
- The message text should wrap normally across the available width.

**Current behavior:**

- Even after code changes (see Attempts below), the empty state still renders in the same broken vertical layout when there are no search results.

### Suspected Context / Layout

- The Timeline screen (`UnifiedTimelineScreen`) is built as:
  - A `Stack` containing:
    - A `Column` with:
      - A fixed-height spacer for the search bar (~64 px).
      - An `Expanded` region that shows either:
        - `SearchResultsList` when there is an active query with results, or
        - Timeline content when not searching.
    - A `Positioned` `GlobalSearchBar` pinned to the top, spanning full width.
- `GlobalSearchBar` itself returns a `Column` that includes:
  - The search `TextField`.
  - Optional recent searches.
  - Loading / error / empty states below the field.

Because `GlobalSearchBar` is used **inside a `Stack`** via `Positioned`, its internal layout can end up constrained in surprising ways depending on how the enclosing `Stack` and `Column` interact with available height.

### Attempts So Far (UI)

#### Attempt 1 — Simple Container Layout for Empty State

**What we did:**

- Original empty state in `GlobalSearchBar._buildEmptyState()` used:
  - `Container` → `Column(mainAxisSize: MainAxisSize.min, …)` with icon + text.
- This layout relied on the parent taking full width.

**Why it failed:**

- In real Timeline layout, the parent constraints cause the `Container` to collapse horizontally.
- As a result, the empty state column becomes extremely narrow, and the text is rendered one character per line.
- The UI in the Timeline still looked “all fucked up” (same as the original screenshot).

#### Attempt 2 — Force Full Width + Centering

**What we did:**

- Updated `GlobalSearchBar._buildEmptyState()` to:
  - Wrap the content in a `SizedBox(width: double.infinity, …)`.
  - Use a `Center` to center the inner `Column`.
  - Explicitly set `textAlign: TextAlign.center` on the empty-state message.

**Code (current state):**

```314:333:lib/widgets/global_search_bar.dart
  Widget _buildEmptyState() {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'No memories match your search',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

**Why it failed:**

- Despite these changes, the visual result on device **did not change**:
  - Still shows the empty-state text vertically along the left edge.
  - Still visually broken when performing a search from the Timeline tab.
- This strongly suggests that the root cause is **higher up in the layout tree** (e.g., `Stack`/`Positioned`/`Column` constraints) rather than in the empty-state widget itself.

**Status for Issue A:**  
- ❌ Bug still reproducible.  
- ❌ UI changes so far have not corrected the Timeline empty-state layout.  
- 🔎 Next step will need to be a deeper inspection/refactor of the Timeline screen’s `Stack` + `Positioned` layout for `GlobalSearchBar` and how it interacts with the main content scrollable.

---

## Issue B — Search Results Missing / Incomplete

### Problem Description

Global search appears to be **functionally broken** in at least some cases:

- Searching for a specific keyword from the Timeline tab:
  - The keyword is **definitely present**:
    - In the memory’s **tag list**.
    - In the unified **`search_vector`** field used for full-text search.
  - However, **no results** are returned for that query.
- This is not just a UI-only bug — the search backend is apparently failing to return data that should match.

**Expected behavior:**

- Any memory whose tags or text fields (that feed `search_vector`) contain the query term should be returned in the search results, ranking aside.

**Current behavior:**

- Queries that should match known memories come back **empty**.
- On the UI side, the Timeline displays the (broken) empty state instead of valid results.

### Relevant Implementation Pieces

- `search_provider.dart`:
  - `SearchQuery` provider stores the raw query string.
  - `DebouncedSearchQuery` debounces input by 250 ms.
  - `SearchResults` provider:
    - Watches `debouncedSearchQueryProvider`.
    - Calls `SearchService.searchMemories(query: query, page: page)`.
    - Manages pagination, loading flags, and error messages.
- `SearchService` (not fully analyzed in this doc):
  - Expected to call Supabase RPC / SQL that uses the `search_vector` column defined in the full-text search spec.
- Data model:
  - Unified `memories` table with `tags` and `search_vector` per spec in `agent-os/specs/2025-11-17-search-functionality-full-text/spec.md`.

At this point we have **user-level evidence** (known keyword present in tags + search vector) but not yet a precise DB-level repro captured in this doc.

### Attempts So Far (Logic / Provider Layer)

#### Attempt 1 — Fix “Uninitialized Provider” Crash

**Symptom (before fix):**

- When the app tried to build `GlobalSearchBar` inside the real app shell, Riverpod threw:
  - `Bad state: Tried to read the state of an uninitialized provider`
  - Stack traced into `SearchResults.build` and `_performSearch`, where `state.copyWith(...)` was being called before `state` was ever set.

**What we changed:**

- In `SearchResults.build()`, we now **always initialize** `state` before doing any logic or calling `_performSearch`:

```113:137:lib/providers/search_provider.dart
  @override
  SearchResultsState build() {
    // Always start from a known initial state before we do anything that
    // reads or updates `state` (e.g., inside `_performSearch`). This avoids
    // "uninitialized provider" errors on first use in the app shell.
    state = SearchResultsState.initial();

    // Watch debounced query and trigger search when it changes
    final debouncedQuery = ref.watch(debouncedSearchQueryProvider);
    
    // Only search if query is non-empty and different from last query
    if (debouncedQuery.isNotEmpty && debouncedQuery != _lastQuery) {
      _lastQuery = debouncedQuery;
      // Cancel any pending search
      _lastSearchFuture?.ignore();
      // Trigger new search
      _lastSearchFuture = _performSearch(debouncedQuery, page: 1);
    } else if (debouncedQuery.isEmpty && _lastQuery != null) {
      // Clear results when query is cleared
      _lastQuery = null;
      // `state` has already been reset to the initial value above.
    }

    return state;
  }
```

**Result:**

- The “uninitialized provider” crash is resolved — `SearchResults` can now safely call `_performSearch` on first use.
- **However**, this fix only removed a runtime error; it did **not** address the underlying issue of search returning no results when it should.
- From the user’s perspective, **search is still broken**: valid queries still return nothing.

#### Attempt 2 — UI Empty-State Tweaks (see Issue A)

**Why it doesn’t fix the logic bug:**

- Those changes only affect how the empty state is rendered when `searchResultsState.items.isEmpty`.
- They do not modify how queries are issued or how the backend matches on `tags` / `search_vector`.

### Current Status for Issue B

- ❌ Search still fails to return results for queries that should match known memories.  
- ❌ We have not yet validated the shape of the Supabase query, `search_vector` construction, or tag integration in this doc.  
- ✅ Provider-level crash fixed (but functional behavior remains wrong).  
- 🔎 Next steps will need to include:
  - Verifying the Supabase RPC / SQL implementation for full-text search.
  - Checking the actual row values (especially `tags` and `search_vector`) for a specific failing memory.
  - Confirming that the client is sending the query string exactly as expected (no unwanted trimming/escaping/normalization).

---

## Summary

- **Issue A — Timeline search empty state UI**  
  - The empty-state message (“No memories match your search”) still renders in a broken, vertically stacked layout on the left side of the Timeline when there are no search results.  
  - Multiple attempts to adjust the local layout in `GlobalSearchBar._buildEmptyState()` have **not** changed the on-device behavior, which suggests the bug likely lives in the higher-level Timeline + `Stack` layout.

- **Issue B — Search not returning expected results**  
  - Even when a query term is known to exist in both the `tags` and `search_vector` fields, full-text search returns **no results**.  
  - We fixed an uninitialized provider crash in `SearchResults`, but the **functional search behavior remains broken** and requires deeper investigation at the Supabase / SQL / indexing level.

Both issues are currently **unresolved** and must be treated as active troubleshooting items. This document is the canonical place to track observations, attempted fixes, and future experiments for the Timeline + global search stack.


