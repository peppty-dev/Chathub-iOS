## Live Interests from Chat: On-Device Keyword Extraction and Pill UX

### Purpose
Collect user interests implicitly from their chat messages, surface them as low-friction pill suggestions above the chat composer, and let users confirm or dismiss with a single tap. This feature operates fully on-device (no external APIs) and complements the broader four-layer profile model:

- **Layer 1 – Live Interests from Chat (this document)**
- **Layer 2 – Yes/No Profile Details** (binary toggles like “allow calls”, “likes men/women”)
- **Layer 3 – Descriptive Details** (height, occupation, hobbies, social handles)
- **Layer 4 – Activity Details** (message/call counts, engagement)


## Goals and Non-Goals

- **Goals**
  - Extract interest candidates in real-time from user messages, purely on-device.
  - Present at most 1–2 pill suggestions with Like/Dislike.
  - Save only user-approved interests to profile (`interest_tags`).
  - Keep UX non-intrusive with quality gating and cooldowns.
  - Ship the same behavior on iOS, Android, and Web.

- **Non-Goals**
  - No server-side NLP or external API calls.
  - No predefined “taxonomy” of allowed interests (basic stopwords/blacklist are acceptable).
  - Not a full-blown content moderation system (reuse existing moderation where needed).


## Cross-Platform Technical Overview (On-Device Only)

All platforms follow the same high-level pipeline and scoring. Platform-specific primitives differ only for tokenization/POS/NER.

### Common Pipeline
1. **Language detection** (best-effort; fallback to UI locale).
2. **Tokenization** into words and sentences.
3. **Normalization**: lowercase, diacritics fold, punctuation strip, emoji ignore.
4. **Stopword removal** per language (small lists shipped in-app).
5. **Optional lemmatization/stemming** (platform-dependent).
6. **Candidate generation**:
   - Noun phrases and named entities when available (iOS).
   - RAKE-style phrases split by stopwords/punctuation on other platforms.
   - Generate n-grams (uni-, bi-, tri-grams), prefer multiword phrases.
7. **Scoring** per candidate in a rolling window of recent messages.
8. **Gating & safety**: thresholds, time decay, cooldowns, blacklist.
9. **Suggestion**: at most one pill per send event (debounced), Like/Dislike.
10. **Persistence**: only accepted candidates are saved to profile.

### iOS
- Use Apple Natural Language (on-device):
  - Tokenization: `NLTokenizer`
  - POS & NER: `NLTagger` with `.lexicalClass`, `.nameType`, `.joinNames`
  - Language ID: `NLLanguageRecognizer`
- Prefer noun/proper-noun tokens and joined named entities (people/org/places, tech, titles).

### Android
- Tokenization: `BreakIterator` (ICU) or `java.text.BreakIterator`.
- Entity detection: built-in `TextClassifier` is limited; rely on RAKE/TextRank for general interests.
- Implement RAKE/TextRank/TF‑IDF locally; no network required.

### Web (React/React Native)
- Browser: `Intl.Segmenter` for word segmentation (fallback to regex where unavailable).
- Implement RAKE/TextRank/TF‑IDF in pure JS; no server calls.


## Scoring and Gating

- **Frequency**: Count mentions of a candidate in the last N messages (e.g., 50–100).
- **Multi-word boost**: `bi-gram * 1.2`, `tri-gram * 1.4` over unigram.
- **POS/NER boost (iOS)**: +`β` when candidate is a named entity or proper noun.
- **Recency decay**: `score *= exp(-Δt / τ)` to fade older messages.
- **Minimum threshold**: show only if `score ≥ T` (tunable; start around 2.0–3.0).
- **Repetition guard**: require ≥2 distinct mentions or a higher `T` for singletons.
- **Cooldown**: after surfacing a candidate, suppress it for e.g., 30–60 minutes.
- **Blacklist**: small local list to avoid unsafe/off-limits categories.


## Data Model & Storage

- **Persisted (profile)**
  - Firestore field: `Users/{userId}.interest_tags: string[]` (already present)
  - Local mirror: `SessionManager.shared.interestTags` / `UserSessionManager.interestTags`

- **Ephemeral (local only)**
  - `candidateScores: Map<string, { score: Double, lastSeenAt: Time, seenCount: Int, cooldownUntil?: Time, lastShownAt?: Time }>`
  - Not synced and cleared on logout or long inactivity.

- **Settings**
  - Toggle: “Smart Interest Suggestions” (on by default; user can opt out).
  - Manage: “Edit Interests” screen (reuse existing interest UI).


## iOS Integration Points (no schema change required)

- Hook in `chathub/Views/Chat/MessagesView.swift` after message send to update the rolling window and rescore. Only proceed if feature toggle is enabled and user is eligible (e.g., not in a sensitive context).
- Persist accepted pills using existing path:
  - Firestore `interest_tags` merge
  - Local `SessionManager.shared.interestTags`
- UI: Reuse presentation patterns from `InterestsDialogView` / `InterestsPopupView` for confirmation affordances; add a lightweight pill strip above the composer.


## UX Spec - Unified Periodic System

- **Display**: Single pill above the input with spring animation in/out
- **Timing**: 
  - Immediate display on chat entry
  - Periodic reappearance every 5-20 seconds (adaptive delay)
  - Session limit: 15 pills maximum per chat session
- **Actions**:
  - **Yes**: Accept interest (add to `interest_tags`) or confirm about-you detail; show toast "Added to interests"
  - **No**: Reject/dismiss suggestion; hide pill and schedule next
- **Content**: Alternates between interest suggestions and about-you questions using existing A/B logic
- **Smart Features**:
  - Adaptive delays increase after each interaction (5s → 20s max)
  - Context-aware: same quality filtering and rotation as before
  - Unified state management eliminates conflicts between entry/inline pills
- **Accessibility**: VoiceOver labels for pill and actions; large tap targets


## Privacy, Consent, and Safety

- On-device extraction; nothing sent to servers except interests explicitly approved by user.
- Clear toggle in Settings; link to privacy note.
- Allow users to delete interests anytime (Manage Interests).
- Maintain small blacklist to avoid sensitive categories.
- Respect existing moderation; never surface a pill for messages flagged as disallowed.


## Performance

- Keep a rolling buffer (e.g., last 50–100 messages) per chat.
- Run extraction/rescoring on a background thread.
- O(n) per update with small constants; avoid heavy POS/NER on long histories (iOS-only boost is optional for older messages).


## QA and Metrics (local)

- QA scenarios: multilingual, emojis, very short/long messages, repeated topics, toggling feature, offline mode.
- Telemetry (local only or privacy-safe aggregates): number of pills shown, accept rate, dismissal rate; DO NOT log raw text.


## Rollout

- Phase 1: iOS with POS/NER boost, Android/Web with RAKE; soft thresholds.
- Phase 2: Tune thresholds/decay/cooldowns using accept/dismiss ratios.
- Phase 3: Add per-language stopwords and optional lemmatization where supported.


## Appendix A: Minimal iOS Extraction Sketch

```swift
import NaturalLanguage

struct InterestCandidate { let text: String; let score: Double }

func extractCandidates(from text: String) -> [InterestCandidate] {
    let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
    tagger.string = text
    let opts: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther, .joinNames]

    var kept: [String] = []
    tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, schemes: [.lexicalClass, .nameType], options: opts) { tags, range in
        let token = String(text[range]).lowercased()
        guard !stopwords.contains(token) else { return true }
        let (lex, name) = tags
        if name == .personalName || name == .placeName || name == .organizationName ||
           lex == .noun || lex == .properNoun {
            kept.append(token)
        }
        return true
    }
    let phrases = buildNgrams(kept, maxN: 3)
    return scoreAndTopK(phrases)
}
```


## Appendix B: Minimal Android Extraction Sketch

```kotlin
fun tokenize(text: String): List<String> {
    val it = java.text.BreakIterator.getWordInstance()
    it.setText(text)
    var start = it.first()
    val out = mutableListOf<String>()
    var end = it.next()
    while (end != java.text.BreakIterator.DONE) {
        val w = text.substring(start, end).lowercase()
        if (w.any { it.isLetter() } && w !in STOPWORDS) out += w
        start = end
        end = it.next()
    }
    return out
}

fun extractCandidates(text: String): List<Pair<String, Double>> {
    val tokens = tokenize(text)
    val phrases = rakePhrases(tokens) // split on stopwords, build n-grams
    return scoreAndTopK(phrases)
}
```


## Appendix C: Minimal Web Extraction Sketch

```javascript
function tokens(text) {
  if (globalThis.Intl?.Segmenter) {
    const seg = new Intl.Segmenter(undefined, { granularity: 'word' })
    return [...seg.segment(text)]
      .map(s => s.segment.toLowerCase())
      .filter(w => /\p{L}/u.test(w))
  }
  return (text.toLowerCase().match(/\p{L}+/gu) || [])
}

function extractCandidates(text) {
  const toks = tokens(text).filter(w => !STOPWORDS.has(w))
  const phrases = buildNgrams(toks, 1, 3)
  return scoreAndTopK(phrases)
}
```


## Open Questions

- Default thresholds and decay constants per platform?
- Minimal initial stopword lists per supported language?
- Where to expose the Settings toggle (Profile > Privacy vs. Chat settings)?


## Implementation Checklist (High-Level)

- Feature flag and settings toggle
- Rolling window + candidate score store
- Platform-specific tokenizer and (optional) POS/NER boost
- Scoring, thresholds, decay, cooldowns, blacklist
- Pill UI above composer with Like/Dislike/Dismiss
- Save accepted interests to `interest_tags`; local mirror update
- Manage Interests entry and edits
- QA matrix and telemetry hooks (privacy-safe)


## Current iOS Implementation (Files, APIs, Behavior)

This section documents the unified periodic information gathering system in the iOS app.

- **Files**
  - `chathub/Core/Services/Interests/InterestExtractionService.swift` - On-device text analysis and scoring
  - `chathub/Core/Services/Interests/InterestSuggestionManager.swift` - Interest suggestion management
  - `chathub/Views/Chat/InfoGatherPill.swift` - Unified pill component for all info gathering
  - `chathub/Views/Chat/MessagesView.swift` - Unified periodic system implementation

### InterestExtractionService (Core Logic)

- Tokenization: `NLTokenizer(unit: .word)`
- POS/NER boosts: `NLTagger` with `.lexicalClass` + `.nameType` and `.joinNames`
- N-grams: 1–3 tokens per phrase, prefer longer phrases via boosts
- Scoring and gating (defaults):
  - `minScoreToSuggest = 2.75`, `minMentions = 2`, `strongSingleMentionThreshold = 4.5`
  - `biGramBoost = 1.2`, `triGramBoost = 1.4`, `posNerBoostPerToken = 0.25`
  - Decay time constant ≈ 30 minutes; cooldown after show = 10 minutes; dislike = 60 minutes
  - Per-session cap = 3 pills/hour; phrase length 3–30 chars; stopword filtering
- Public API:
  - `processMessage(chatId:text:existingInterests:) -> String?`
  - `markAccepted(chatId:phrase:)`
  - `markDisliked(chatId:phrase:)`

### InterestSuggestionManager (Persistence Bridge)

- Provides interest suggestions via `getSuggestedInterests()` for the periodic pill system
- `acceptInterest(_:chatId:completion:)` merges to Firestore (`interest_tags`) and updates session
- `rejectInterest(_:chatId:)` handles rejection cooldowns without persistence
- No longer processes outgoing messages for immediate suggestions (replaced by periodic system)

### Pill UI (InfoGatherPill)

- Capsule gradient pill with text and actions (X and thumbs-up), spring animated.
- Reusable as `InfoGatherPill(title:text:onYes:onNo:)`.

### Chat Integration (MessagesView.swift) - Unified Periodic System

- **Unified State**: `@State private var currentInfoGatherContent: InfoGatherContent?` with timer scheduling
- **UI**: Single `InfoGatherPill` appears periodically above the composer, alternating between interests and about-you questions
- **Trigger Logic**: 
  - Shows immediately on chat entry
  - Reappears every 5+ seconds after user interaction (adaptive delay)
  - Session limit of 15 pills maximum to prevent fatigue
- **User Interaction**: Any Yes/No response hides current pill and schedules next one after delay
- **Smart Features**: 
  - Adaptive delays (5s → 20s max) based on user engagement
  - Same alternating A/B logic for content selection
  - Proper cleanup on view dismissal

### Storage and Sync

- Firestore: `Users/{userId}.interest_tags: [String]` (merge); `interest_sentence` kept as `NSNull()` for parity.
- Local: `SessionManager.shared.interestTags` with `synchronize()`.

### Privacy & Performance

- All extraction is on-device. Only explicitly accepted interests sync to Firestore.
- Work runs on a background queue; results posted to main thread; per-hour cap and cooldowns control churn.


## Edit Profile Redesign (Pill-based About You + Interests)

We redesigned the Edit Profile screen to use pill-shaped controls for binary profile details and to surface both accepted and suggested interests at the bottom.

### UI Structure

1. Header: Profile photo, name, basic info (unchanged)
2. Profile Details: Text fields (height, occupation, hobbies, zodiac, socials)
3. About You (Pills): Replaces switches with tap-to-toggle pills; selected pills turn blue with an X indicator
4. Interests:
   - “Your Interests”: accepted items from `interest_tags`
   - “Suggested From Chats”: non-accepted candidates captured locally from the chat extraction

### Files and Components

- `Views/Users/EditProfileView.swift`
  - Replaced About You switch rows with `TogglePill` chips in a `FlowLayout`
  - Added “Interests” section showing accepted (`SessionManager.shared.interestTags`) and suggested (`InterestSuggestionManager.shared.getSuggestedInterests()`) tags
- `Views/Components/FlowLayout.swift`: wraps chips neatly
- `Views/Users/EditProfileView.swift` components:
  - `TogglePill`: tap to toggle; selected uses gradient with an X icon
  - `InterestsFlow` & `InterestTagPill`: display accepted (blue) and suggested (neutral) pills

### Data Flow

- About You pills map to existing Firestore keys (e.g., `single`, `married`, `voice_allowed`) with values `"true"`/`"null"` (unchanged schema)
- Accepted interests are persisted to `interest_tags` (as described above)
- Suggested interests are kept locally via `InterestSuggestionManager` (UserDefaults) and do not sync

### UX Details

- Selected About You pill shows a subtle X to indicate tap again to deselect
- Interests displayed after other details; accepted in blue, suggested in neutral gray
- Option to add free-text interests can be considered later (not implemented now)

