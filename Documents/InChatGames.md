## In‑Chat Games: Product Specification

### Purpose
Create a curated set of romantic, flirty, PG‑13 two‑player games playable directly inside the message view. These are exclusive, in‑house games available with the "Play" subscription (unlimited play). This feature replaces the existing "infinitexo" button with a new, unified "In‑Chat Games" entry point that opens a compact game picker.

### Access & Monetization
- **Subscription gate**: All In‑Chat Games are unlocked for "Play" subscribers.
- **Teaser**: Offer one free teaser round per chat for non‑subscribers to drive conversion.
- **Upsell**: Show subscription upsell within the game picker and on game launch if locked.

## Game Catalog (10)

### 1) Romance Sketch & Guess
- **How it works**: Players take turns drawing prompts from a curated romantic word bank (e.g., "sunset beach," "first date," "chocolate"). The partner guesses the drawing within a set time limit.
- **Why it works**: Encourages creativity and interaction; curated words ensure appropriateness.
- **Subscriber perk**: Additional brushes, hints, and word packs.
- **Safety**: Vetted word lists; skip/replace word; report option.

### 2) Flirty 20 Questions
- **How it works**: One player thinks of a romantic item or scenario; the other has 20 yes/no questions to guess it. Predefined categories guide the topics.
- **Why it works**: Fosters curiosity and deepens understanding between players.
- **Subscriber perk**: Themed question packs (e.g., Travel, Cozy Nights, Retro Romance).
- **Safety**: Category constraints keep it PG‑13; skip/replace.

### 3) Truth or Flirt
- **How it works**: A PG‑13 version of Truth or Dare. Players draw cards prompting either a "truth" (e.g., "What's your favorite romantic memory?") or a "flirt" (e.g., "Send a song that reminds you of me").
- **Why it works**: Encourages vulnerability and playful interaction.
- **Subscriber perk**: Premium decks and streak multipliers.
- **Safety**: Curated deck with skip/replace and report.

### 4) Would You Rather: Date Night Edition
- **How it works**: Players choose between two romantic scenarios (e.g., "Stargazing picnic vs. rooftop dinner") and compare choices.
- **Why it works**: Reveals preferences and sparks playful debates.
- **Subscriber perk**: Themed scenario packs and prompts to explain choices.
- **Safety**: Curated PG‑13 scenarios; skip/replace.

### 5) Emoji Story Decoder
- **How it works**: One player creates a short story using emojis; the partner decodes the story within a time limit.
- **Why it works**: Encourages creativity and interpretation.
- **Subscriber perk**: Themed emoji packs and extended time limits.
- **Safety**: Emoji‑only input is inherently safe; skip/replace.

### 6) Two Truths and a Lie (Romance Edition)
- **How it works**: Players share two true statements and one false statement; the partner guesses the lie.
- **Why it works**: Facilitates sharing personal stories and learning about each other.
- **Subscriber perk**: Themed prompt packs and additional guessing attempts.
- **Safety**: Non‑sensitive prompt guidance; skip.

### 7) Fill‑in‑the‑Blanks: Love Lines
- **How it works**: Players send incomplete sentences to be filled in (e.g., "Our perfect Sunday is ___, then ___").
- **Why it works**: Encourages playful and flirty exchanges.
- **Subscriber perk**: Themed sentence packs and additional hints.
- **Safety**: Curated templates; skip/replace.

### 8) Dare Dice (No Dice): Sweet Challenges
- **How it works**: Players roll virtual dice (or pick 1–6) to receive playful dares (e.g., "Send a voice note humming a love song," "Write a 3‑line poem").
- **Why it works**: Adds spontaneity and fun to the conversation.
- **Subscriber perk**: Premium dare packs and customization options.
- **Safety**: Strict PG‑13 dare list; skips allowed; report.

### 9) Couple’s Trivia
- **How it works**: Players answer trivia questions about each other to test their knowledge and connection.
- **Why it works**: Strengthens bonds and encourages learning about each other.
- **Subscriber perk**: Themed trivia packs and score tracking.
- **Safety**: Non‑sensitive questions; skip.

### 10) Story Chain: Cozy Edition
- **How it works**: Players co‑create a romantic story by alternating sentences, building upon each other's contributions for 8–12 turns.
- **Why it works**: Fosters creativity and collaboration.
- **Subscriber perk**: Themed story starters and the ability to save/share stories.
- **Safety**: Curated prompts; skip/replace.

## Design Considerations
- **Access control**: All In‑Chat Games are accessible exclusively to "Play" subscribers; allow one free teaser round per chat to entice non‑subscribers.
- **Content safety**: Curated word banks and prompt decks ensure content remains appropriate; options to skip or replace prompts are available; ban lists and safe synonyms.
- **User experience**: Games open in a compact overlay within the chat; moves are mirrored as inline system messages to preserve conversation flow and transcript.
- **Game mechanics**: 30–60 second turns; 5–10 round sessions; quick rematch; turn indicator and timer.
- **Engagement features**: Points, streaks, badges; private by default to the pair; optional visibility controls.
- **Inclusivity**: Designed to be enjoyable for all users while supporting romantic/flirty themes.
- **Content moderation**: Always‑present controls to opt‑out, skip, replace prompt, and report content or behavior.

## Implementation Steps
1. **Interface update**: Replace the existing "infinitexo" button with a new "In‑Chat Games" button in the messaging view, opening a `GamesPickerView`.
2. **State sync**: Use lightweight game state messages over the chat transport to handle invitations, turns, timers, and results.
3. **Content packs**: Store curated decks/word banks as local JSON with capability for remote updates; include skip/replace logic and ban lists.
4. **Drawing interface**: Implement a simple canvas with stroke capture/replay for Sketch & Guess; add basic tools (pen/eraser, a few colors, clear).
5. **Monetization**: Paywall when launching a locked game; upsell in the picker; unlock all packs for subscribers.
6. **Telemetry**: Track starts, completes, skips, reports, conversion from teaser to subscribe; keep analytics privacy‑safe.
7. **Moderation hooks**: Provide inline report flow and escalation; enforce block/mute in game sessions.

## Recommended Initial Launch
- **Phase 1 (MVP)**: Romance Sketch & Guess; Would You Rather: Date Night; Truth or Flirt; Emoji Story Decoder.
- **Phase 2**: Two Truths and a Lie; Fill‑in‑the‑Blanks; Dare Dice; Couple’s Trivia; Story Chain; Flirty 20 Questions.

Each game ships with curated content, clear turn/timer mechanics, and skip/report controls to keep experiences delightful, inclusive, and PG‑13.


