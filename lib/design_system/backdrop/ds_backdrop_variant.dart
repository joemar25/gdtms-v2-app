// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md

/// Which screen *role* owns this backdrop.
///
/// | Variant | Where |
/// |---------|--------|
/// | [shell] | Main tabs + [DsAppScaffold] list/detail pages |
/// | [gate]  | Splash, permissions, terms, update |
/// | [auth]  | Login, forgot password |
/// | [vivid] | Rare high-energy moments |
/// | [none]  | Solid scaffold only |
enum DsBackdrop { none, shell, gate, auth, vivid }
