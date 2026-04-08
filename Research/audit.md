# Audit: swift-paths

## Legacy — Consolidated 2026-04-08

### From: swift-institute/Research/audit-foundations.md (2026-04-03)

**Pre-publication audit — P0/P1/P2 checks**

#### P1: Multi-type Files [API-IMPL-005] — Type + Error Pattern

| File | Nature |
|------|--------|
| `Path.Component.Extension.swift` | `Extension` struct + `Error` enum |
| `Path.swift` | `Path` struct + `Error` enum + `Storage` internal |
| `Path.Component.swift` | `Component` struct + `Error` enum |
| `Path.Component.Stem.swift` | `Stem` struct + `Error` enum |

swift-paths consistently places `Error` enums in the same file as the type they serve. This is a systematic pattern that warrants a policy decision: split errors into separate files per [API-IMPL-005], or document an exception for co-located error types.

**Recommended action** (Should Fix): Split co-located `Error` enums into separate files:
- `Path.Error.swift`
- `Path.Component.Error.swift`
- `Path.Component.Extension.Error.swift`
- `Path.Component.Stem.Error.swift`

---

### From: swift-institute/Research/platform-compliance-audit.md (2026-03-19)

**Skill**: platform — [PLAT-ARCH-001-010], [PATTERN-001], [PATTERN-004a], [PATTERN-005]

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| H-25 | HIGH | [PLAT-ARCH-008] | Path.Introspection.swift:32,142,157 | `#if os(Windows)` Windows separator detection in path analysis. | OPEN — Blocked by missing `Kernel.Path.Separator` |
| H-26 | HIGH | [PLAT-ARCH-008] | Path.Navigation.swift:33,81,134,183,248 | `#if os(Windows)` separator in path navigation (parent, join, etc.). | OPEN |
| H-27 | HIGH | [PLAT-ARCH-008] | Path.Component.swift:40,136 | `#if os(Windows)` separator in component splitting. | OPEN |
| H-28 | HIGH | [PLAT-ARCH-008] | Path.swift:103,160,227 | `#if os(Windows)` separator in path construction. | OPEN |
| H-29 | HIGH | [PLAT-ARCH-008] | Path.Component.Stem.swift:46 | `#if os(Windows)` separator awareness. | OPEN |
| H-30 | HIGH | [PLAT-ARCH-008] | Path.Component.Extension.swift:50 | `#if os(Windows)` separator awareness. | OPEN |

**Fix for all**: Unify path separator in Kernel. `Kernel.Path.Separator` constant or `Kernel.Path.isSeparator(_:)` would eliminate all conditionals.
