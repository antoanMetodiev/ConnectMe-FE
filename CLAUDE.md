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

**Свързан е реален Supabase проект** (URL `https://ezfpwfsxenxceossrtps.supabase.co`).
Credentials-ите живеят само в `env.json` в root-а на репото — **gitignore-нат, никога не се
commit-ва**. Шаблонът/полетата са в `env.example.json` (committed). За build/run с реален
Supabase:
```
flutter run --dart-define-from-file=env.json
flutter build web --dart-define-from-file=env.json
```
Без `env.json` (или без стойности в него) приложението продължава да буутва нормално —
`Env.isSupabaseConfigured` пази `Supabase.initialize` да не гърми, а auth действията показват
приятелска грешка вместо да чупят UI.

Ключът, който Supabase дава, вече се казва **publishable key** (не "anon key" — старото име е
deprecated в `supabase_flutter`); в кода/env полето е `SUPABASE_PUBLISHABLE_KEY`.

## Current scope

**Стратегията се смени с решение на потребителя (2026-08-31): вертикални срезове, не
"целия frontend после backend".** Вървим feature по feature (auth → chat → ...), всеки път с
реално свързан Supabase зад него, вместо всичко да е mock и да се жичи накрая. Все пак:

- Repository слоят си остава абстрактен (`AuthRepository` interface + `SupabaseAuthRepository`
  имплементация) — не заради "може после да сменим Supabase", а защото е чист/testable dependency
  boundary.
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
- [x] Live reload за преглед на телефона — `web/index.html` polls `main.dart.js` (Last-Modified)
      на всеки 1.5s и си прави reload; `dhttpd` (`dart pub global activate dhttpd`) сервира
      `build/web` постоянно на `0.0.0.0:8090`. Workflow: `flutter build web
      --dart-define-from-file=env.json` след промяна → телефонът/браузърът се обновяват сами,
      без рестарт на сървъра.
- [x] Auth — Login + Sign Up екрани (`lib/features/auth/presentation/`), реално свързани към
      Supabase Auth (`lib/features/auth/data/supabase_auth_repository.dart`) през Riverpod
      `AsyncNotifier` (`lib/features/auth/application/auth_controller.dart`). Routes: `/`
      (login), `/signup`. Успешен login → `/dev/components` (временна "home" дестинация, докато
      няма реален Home/Chats екран).
- [~] Google Sign-In (OAuth) — кодът е готов (`AuthRepository.signInWithGoogle`,
      бутон на login+signup), **но изисква конфигурация извън кода**, която само потребителят
      може да направи:
      1. Google Cloud Console → OAuth client (Web application) → Authorized redirect URI:
         `https://ezfpwfsxenxceossrtps.supabase.co/auth/v1/callback` → копирай Client ID +
         Client Secret.
      2. Supabase Dashboard → Authentication → Providers → Google → Enable → постави
         Client ID + Secret.
      3. Supabase Dashboard → Authentication → URL Configuration → Redirect URLs → добави
         текущия dev адрес (в момента `http://192.168.0.101:8090` — LAN IP, ще трябва да се
         обнови ако се смени/при преминаване към истински домейн).
      `AuthController` вече слуша `authStateChanges()` (не само еднократен return), точно за да
      хване сесията след OAuth redirect-а.
- [ ] Navigation shell
- [ ] Splash / onboarding / profile setup екрани (останалата част от auth flow-а по брифа)
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
