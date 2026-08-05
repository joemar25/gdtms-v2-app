# Backdrop module

**One scenery system.** Do not add a second backdrop widget.

| File | Responsibility |
|------|----------------|
| `ds_backdrop_variant.dart` | `DsBackdrop` enum (`shell` / `gate` / `auth` / …) |
| `ds_backdrop_config.dart` | **Presets** — edit `shell` / `gate` / `auth` values here |
| `ds_backdrop_painter.dart` | Paint only (not exported) |
| `ds_brand_backdrop.dart` | Flutter widget |
| `backdrop.dart` | Barrel export |

## Where to change intensity

| Goal | Edit |
|------|------|
| Dashboard + lists | `DsBrandBackdropConfig.shell` |
| Splash / permissions | `DsBrandBackdropConfig.gate` |
| Login | `DsBrandBackdropConfig.auth` |

## Which wrapper

| Screen type | Wrapper | Backdrop |
|-------------|---------|----------|
| Main tabs | `ScaffoldWithNavBar` | `shell` (automatic) |
| Lists / detail | `DsAppScaffold` | `shell` (automatic) |
| Login | `AuthShell` | `auth` |
| Permissions / update | `DSGateShell` | `gate` |
| Initial sync | custom | own config |
