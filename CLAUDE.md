# ConnectMe — Frontend (Flutter)

## What this is

ConnectMe е мобилно чат приложение (Flutter + Dart), замислено като лично комуникационно
пространство, не социална мрежа. Пълният продуктов/UX бриф е в
[`docs/product-brief.md`](docs/product-brief.md) — чети го за всякакви въпроси около
функционалност, тон, навигация, забранени клишета (glassmorphism, WhatsApp/Telegram/IG copycat
и т.н.) и приоритети.

Разпространение: Google Play (Android) + custom сайт за директно сваляне на iOS build (не App
Store в началото).

## App identity

- Flutter project name: `connectme`
- Org / reverse-domain: `me.connect` (от бъдещия домейн `connect.me`, все още некупен)
- Android applicationId / iOS bundle id: `me.connect.connectme`

Това трябва да се потвърди (или смени) **преди първия реален publish в Google Play** — след
publish смяна на applicationId на практика означава нов listing/нова apps. Свободно е за смяна
по всяко време преди това.

## Local toolchain

- Flutter SDK е инсталиран локално в `C:\flutter` (stable channel, клонирано от
  `github.com/flutter/flutter`, не е част от репото) и добавен в user PATH.
- `flutter doctor` статус към момента на setup-а: Flutter, Windows, Chrome и Windows desktop
  target-и — OK. **Android toolchain** и **Visual Studio (C++ workload)** — липсват. Не пречат
  на текущата работа (dev/preview през Chrome или Windows desktop), но ще трябват преди реален
  Android build/emulator тест или publish в Play Store.

## Backend (decided)

Backend-ът е изцяло **Supabase**:

- **Database** — Postgres
- **Auth** — Supabase Auth
- **Storage** — Supabase Storage (аватари, chat media, voice messages, stories, view-once media)
- **Realtime** — Supabase Realtime (presence, typing, live messages, story views, call signaling
  support)
- **API** — Supabase auto REST/PostgREST + Postgres RPC функции, secure-нато с Row Level Security

Все още не свързваме нищо реално — виж "Current scope" по-долу. Когато дойде моментът,
`supabase_flutter` пакетът се вкарва зад абстрактния repository слой, без UI да се пипа.

## Current scope

**Само frontend засега.** Работим с mock/local данни; Supabase интеграцията ще се включи
по-късно. Затова:

- Няма нужда от реални API извиквания в началото — repository/service слоят трябва да е
  абстрахиран (интерфейси), за да може после лесно да се включи Supabase имплементация зад тях.
- Приоритет: UI, навигация, state management, дизайн система, компонентна библиотека.
- Кодим mobile-first, но responsive (таблет/по-широки екрани не трябва да чупят layout-а).

## Process (from the brief, §24)

1. Product understanding → 2. Information architecture (navigation, флоуве) → 3. Visual
direction (цветове, типография, shape/motion) → 4. Design system (Flutter theme + reusable
widgets) → 5. Core screens (Home, Contacts, Chat, Profile, Stories, Calls, Location) → 6.
Refinement.

Не прескачаме направо на "нахвърляй 30 екрана" — вървим стъпка по стъпка, потвърдено от
потребителя между стъпките.

## Project status

_(Обновявай тази секция след всяка завършена стъпка, за да остане вярна между сесии.)_

- [x] Flutter project scaffold — `flutter create` (android/ios/web/windows), feature-based
      `lib/` structure started (`lib/core/theme`, `lib/core/router`, `lib/shared/widgets`),
      `main.dart` → `app.dart` (`MaterialApp.router`) wired up, `flutter analyze` / `flutter test`
      clean
- [x] State management / routing decision — **Riverpod** (`flutter_riverpod`) +
      **go_router**; `.gitignore` fixed (was the flutter/flutter engine repo's own file — wrongly
      ignored `pubspec.lock` via `*.lock`, missing `.idea/`/`*.iml`; replaced with a proper
      Flutter-app `.gitignore`)
- [x] Visual direction — **"Harbor"**: тихо, премиум, структурирано. Избрана след 3 предложени
      посоки (Ember/Harbor/Dusk), показани като артефакт с mini chat mockup.
      - Primary `#2E5F6E` / on-primary `#FFFFFF`, background `#EFF3F4`, surface `#FFFFFF`,
        ink `#132025`, muted `#647B82`, border `#DCE4E6`, online `#3FA772` (фиксирана UX
        конвенция, извън избора на посока), error `#B3453A`, warning `#B8863A`. Dark вариант в
        `lib/core/theme/app_colors.dart` (`AppPalette.dark`).
      - Типография: **Sora** (headings/titles) + **Work Sans** (body/labels/чат), през
        `google_fonts`. Runtime fetch за момента — преди production да се обмисли бъндване на
        шрифтовете локално (offline-safe, по-бърз first load).
      - Shape: плоско, borders вместо elevation/shadow, малки радиуси (`AppRadius`: 6/8/10/14),
        без pill/heavy rounding.
- [x] Design system като Flutter theme — `lib/core/theme/`: `app_colors.dart` (palette +
      `AppColorsExt` ThemeExtension за presence/bubble цветове), `app_typography.dart`,
      `app_radius.dart`, `app_spacing.dart`, `app_theme.dart` (съставя `ThemeData.light/dark`)
- [x] Първи reusable widgets (`lib/shared/widgets/`) — `AppAvatar` (с presence dot),
      `AppPrimaryButton`, `MessageBubble` (sent/received), `MessageInputBar`. Демонстрирани в
      `lib/features/dev/component_gallery_screen.dart` (текущ `/` route — временен style-guide
      екран, ще се замени с реална навигация в следващата стъпка)
- [ ] Още core widgets по нужда (secondary button, inputs извън chat, cards, badges/chips,
      bottom sheets) — добавяме ги когато реален екран поиска, не предварително
- [ ] Navigation shell
- [ ] Auth flow screens (splash, onboarding, login, signup, profile setup)
- [ ] Home / Chats
- [ ] Chat screen
- [ ] Contacts
- [ ] Calls
- [ ] Stories
- [ ] Location sharing
- [ ] Settings / Privacy

## Conventions

- Mobile-first, но responsive.
- Реюзабилни widgets вместо copy-paste UI.
- Ясни states за всеки компонент: empty / loading / success / error / offline / permission
  denied / disabled (виж брифа §20).
- Никакви социални метрики (followers, likes и т.н.) — фокус върху хора и комуникация.
