# Agent Guidelines — Loob Mobile (Flutter)

This document defines the coding conventions, architecture patterns, and best practices that AI agents **must** follow when working on the Flutter mobile codebase.

---

## Project Overview

Loob is a cross-platform mobile app (Flutter) for **Tealive** and **Baskbear** — a "Twin App" where users toggle between two brand experiences. The app supports multi-country (MY, TH), multi-language (en, ms, th), and multi-brand theming.

**Key design documents:**

- [`docs/architecture/MOBILE_ARCHITECTURE.md`](../docs/architecture/MOBILE_ARCHITECTURE.md)
- [`docs/architecture/SYSTEM_DESIGN.md`](../docs/architecture/SYSTEM_DESIGN.md)

---

## Tech Stack

| Layer                | Technology                  | Notes                                           |
| :------------------- | :-------------------------- | :---------------------------------------------- |
| Framework            | Flutter (Dart SDK ^3.10)    | Material 3 enabled                              |
| State Management     | `flutter_bloc` (BLoC/Cubit) | Strict BLoC vs Cubit rules — see below          |
| Dependency Injection | `get_it`                    | Manual registration in `core/di/injection.dart` |
| Networking           | `dio`                       | Interceptors for auth, context headers, logging |
| Authentication       | `firebase_auth`             | Phone/OTP, JWT injected via interceptor         |
| Local DB             | `drift` (SQLite)            | For relational data (cart, active orders)       |
| Key-Value Cache      | `shared_preferences`        | For settings, language preferences              |
| Image Caching        | `cached_network_image`      | Never store image blobs in DB                   |
| Fonts                | `google_fonts`              | Use semantic `AppTypography` tokens, not ad-hoc |

---

## Project Structure

```text
lib/
├── main.dart                  # Default entry point → devMY
├── main_dev_my.dart           # Flavor entry points per env × country
├── main_dev_th.dart
├── main_prod_my.dart
├── main_staging_my.dart
├── app.dart                   # Root widget (MultiBlocProvider, theme, locale)
├── shell.dart                 # Bottom nav scaffold with IndexedStack
├── core/
│   ├── auth/                  # AuthService interface + mocks
│   ├── config/                # AppConfig, AppEnv (flavor-based config)
│   ├── di/                    # GetIt service locator (injection.dart)
│   ├── localization/          # AppLocalizations, LanguageCubit
│   ├── network/               # ApiClient (Dio), ApiEndpoints, ApiException
│   ├── router/                # Named route definitions (AppRouter)
│   ├── theme/                 # AppTheme, ThemeCubit, brand definitions
│   │   └── tokens/            # AppColors, AppTypography, AppSpacing
│   └── utils/                 # Extensions, formatters
└── features/
    ├── campaigns/             # Banner feeds, promotions
    ├── cart/                  # Cart management (local + remote)
    ├── home/                  # Home feed page
    ├── menu/                  # Menu browsing, product detail, store selection
    ├── settings/              # User profile, language, preferences
    └── vouchers/              # Voucher wallet
```

---

## Architecture Rules

### Feature Module Structure

Every feature **must** follow this layered structure:

```text
features/<feature_name>/
├── data/
│   ├── datasources/           # Remote data sources (API calls)
│   ├── models/                # JSON-serializable DTOs
│   └── repositories/          # Repository implementations
├── domain/                    # (optional) Entities, use cases for complex logic
└── presentation/
    ├── cubit/ or bloc/        # State management
    ├── widgets/               # Reusable, feature-scoped widgets
    └── <feature>_page.dart    # Top-level page widget
```

**Rules:**

- `data/` must not import `presentation/` or Flutter widgets.
- `presentation/` accesses data only through repositories via DI.
- `domain/` (when present) must not import `data/` or `presentation/`.
- Cross-feature dependencies must go through the DI container (`sl<T>()`), never direct imports of another feature's internals.

### Dependency Injection

- All registrations live in `core/di/injection.dart`.
- Use `registerLazySingleton` for repositories and services.
- Use `registerFactory` for Cubits/BLoCs that should be recreated per usage.
- Access dependencies via `sl<T>()` — never construct repositories or services directly in widgets.

```dart
// ✅ Correct
final repo = sl<MenuRepository>();

// ❌ Wrong — bypasses DI
final repo = MenuRepository(client: ApiClient(config: config));
```

---

## State Management Rules

### Use `Cubit` When:

- State transitions are simple and linear (toggle, set value, load list).
- No debouncing, throttling, or stream transformation needed.
- Examples: `ThemeCubit`, `LanguageCubit`, `CartCubit` (simple add/remove).

### Use `Bloc` When:

- Complex async flows with event-driven state machines.
- Need debouncing (search), race condition handling, or stream transformers.
- Examples: `CheckoutBloc`, `SearchBloc`, `OrderStatusBloc`.

### State Naming Convention

```dart
// Cubit states — use sealed class or simple class
class MenuState {
  final MenuStatus status; // loading, loaded, error
  final List<Category> categories;
  final String? errorMessage;
}

// Bloc events — past tense or imperative
class MenuEvent {}
class MenuLoadRequested extends MenuEvent {}
class MenuFilterApplied extends MenuEvent {}
```

### BlocProvider Placement

- **Global providers** (theme, language, cart) go in `app.dart` via `MultiBlocProvider`.
- **Page-scoped providers** wrap the specific page widget, not the entire app.

---

## Theming & Design System

### Brand Theming

The app supports three visual modes controlled by `ThemeCubit`:

- **Discover** (neutral) — default landing mode
- **Tealive** — purple/playful palette
- **Baskbear** — dark/urban palette with orange accents

**Rules:**

- Always use `Theme.of(context)` to resolve colors, never hardcode hex values.
- Use `AppColors`, `AppTypography`, and `AppSpacing` tokens from `core/theme/tokens/`.
- Card shapes, elevation, and nav bar styling are defined in `AppTheme` — do not override per-widget.

```dart
// ✅ Correct — uses theme tokens
final color = Theme.of(context).colorScheme.primary;
const padding = EdgeInsets.all(AppSpacing.md);

// ❌ Wrong — hardcoded values
final color = Color(0xFF6B4EFF);
const padding = EdgeInsets.all(16);
```

### Spacing Tokens

Use `AppSpacing` constants for all padding, margin, and border radius values:

- `AppSpacing.xs`, `sm`, `md`, `lg`, `xl`, `xxl`
- `AppSpacing.radiusSm`, `radiusMd`, `radiusLg`, `radiusXl`, `radiusFull`
- `AppSpacing.pageHorizontal` for consistent page-level horizontal padding

### Typography

Use `AppTypography` for all text styles and apply them via `Theme.of(context).textTheme`:

```dart
// ✅ Correct
Text('Title', style: theme.textTheme.titleLarge);

// ❌ Wrong
Text('Title', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold));
```

---

## Networking

### ApiClient

- All HTTP calls go through `ApiClient` (wraps Dio).
- The client auto-injects `Authorization`, `X-Country-Code`, and `Accept-Language` headers via interceptors.
- Endpoints are defined as static methods in `core/network/api_endpoints.dart`.

### API Call Pattern

```dart
class MenuRemoteDataSource {
  final ApiClient client;
  MenuRemoteDataSource({required this.client});

  Future<List<CategoryModel>> fetchMenu(int storeId) async {
    final response = await client.dio.get(
      ApiEndpoints.menu,
      queryParameters: {'store_id': storeId},
    );
    // Parse response...
  }
}
```

### Error Handling

- Use `ApiException` from `core/network/api_exception.dart` for typed error handling.
- Never swallow exceptions silently — always propagate or log.
- In Cubits/BLoCs, catch and expose errors through state, do not use try-catch in widgets.

---

## Localization

### Adding Strings

- All user-facing strings must go through `AppLocalizations`.
- Access via the `context.l10n` extension (defined in `core/utils/extensions.dart`).
- Never hardcode user-visible text directly in widgets.

```dart
// ✅ Correct
Text(context.l10n.menu);

// ❌ Wrong
Text('Menu');
```

### Supported Locales

- `en` (English — default)
- `ms` (Malay)

When adding new strings, update all locale files.

---

## Layout & UI Guidelines

### Mobile-First, Portrait-Only

- The app is **locked to portrait mode** via `SystemChrome.setPreferredOrientations`.
- Use responsive constraints (`Flexible`, `Expanded`, `ConstrainedBox`) — never fixed heights for text containers.
- On tablets, the layout centers with `maxWidth: 600` rather than stretching.

### Widget Organization

- Keep page widgets focused on layout composition.
- Extract reusable components into `widgets/` subdirectory within the feature.
- Use `const` constructors wherever possible for performance.

### Glassmorphism & Visual Effects

The app uses premium UI patterns:

- `BackdropFilter` with `ImageFilter.blur` for frosted glass effects.
- `Color.withValues(alpha: ...)` (not the deprecated `.withValues(alpha: )`).
- `AnimatedTheme` for smooth brand transitions.
- Subtle shadows with `BoxShadow` using primary color tints.

---

## App Flavoring

### Entry Points

Each flavor has its own `main_<env>_<country>.dart`:

```text
main_dev_my.dart    → AppEnv.devMY
main_dev_th.dart    → AppEnv.devTH
main_prod_my.dart   → AppEnv.prodMY
main_staging_my.dart → AppEnv.stagingMY
```

All entry points call `mainWithEnv(AppEnv.xxx)` which:

1. Initializes Flutter bindings
2. Locks orientation to portrait
3. Configures DI with flavor-specific `AppConfig`
4. Runs the app

### AppConfig

`AppConfig.fromEnv(env)` provides:

- `baseUrl` — API endpoint for the flavor
- `defaultCountryCode` — `MY` or `TH`
- `defaultLanguage` — `en`, `ms`, or `th`

---

## Testing

### Unit Tests

- Test **service/business logic** first, not widget tests.
- Use mock repositories via DI substitution.
- Test files live alongside source: `<file>_test.dart` or in `test/` directory.

### Running Tests

```bash
flutter test                    # All tests
flutter test test/features/     # Feature tests only
```

### Analyzer

```bash
flutter analyze                 # Must pass with zero errors
```

The project uses `package:flutter_lints/flutter.yaml` lint rules.

---

## Common Pitfalls

| Pitfall                             | Correct Approach                                       |
| :---------------------------------- | :----------------------------------------------------- |
| Using `Color.value` property        | Use `.toARGB32()` or color component accessors instead |
| Using `.withValues(alpha: )`        | Use `.withValues(alpha: 0.5)` instead                  |
| Hardcoding strings in widgets       | Use `context.l10n.xxx`                                 |
| Hardcoding colors                   | Use `Theme.of(context).colorScheme.xxx`                |
| Fixed-height text containers        | Use `Flexible`/`Expanded` for text-wrapping safety     |
| Storing images in SQLite/Hive       | Use `cached_network_image` for image caching           |
| Creating repositories in widgets    | Use `sl<Repository>()` from DI                         |
| Importing across feature boundaries | Go through DI container, not direct imports            |

---

## Build & Run

```bash
# Install dependencies
flutter pub get

# Run code generation (if using injectable/drift)
dart run build_runner build --delete-conflicting-outputs

# Run the app (default: devMY)
flutter run

# Run a specific flavor
flutter run -t lib/main_dev_th.dart

# Analyze code
flutter analyze
```
