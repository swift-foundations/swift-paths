# Audit: swift-paths

## Platform — 2026-04-21

### Scope

- **Target**: `Sources/Paths/` (16 source files, L3 cross-platform unifier — paths domain)
- **Skill**: platform — [PLAT-ARCH-001/002], [PLAT-ARCH-008], [PLAT-ARCH-008a], [PLAT-ARCH-008c], [PLAT-ARCH-008d], [PLAT-ARCH-010/011/012], [PATTERN-005/009]
- **Files**: 16 source files; imports `Kernel_Path_Primitives` and `Binary_Primitives` only.

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| — | — | — | — | No Platform-rule violations found. | — |

### Summary

0 findings: 0 critical, 0 high, 0 medium, 0 low. swift-paths is CLEAN against the Platform skill.

**Verification against each rule:**

- **[PLAT-ARCH-008a] hard line (raw platform imports)** — PASS. No `import Darwin`/`Glibc`/`Musl`/`WinSDK` anywhere. The only `public import`s are `Kernel_Path_Primitives` (L1 vocabulary) in `Path.swift:12` and `Path.View.swift:12`, and `Binary_Primitives` in `Path.Binary.swift:12`. Package.swift declares dependencies only on `swift-kernel-primitives`, `swift-binary-primitives`, and `swift-kernel` (test target).

- **[PLAT-ARCH-008a] domain authority exception — all four conditions hold for every `#if os(Windows)`**:
  1. Domain authority — swift-paths is the canonical owner of path-separator conventions and drive-letter/UNC anchoring per the task framing.
  2. Kernel imports only — all platform access is through `Kernel_Path_Primitives` (L1).
  3. Domain strategy, not syscall selection — see [PLAT-ARCH-008d] verification below.
  4. Irreducible — absorbing separator conventions into the kernel would force the kernel to own path semantics it shouldn't own (per [PLAT-ARCH-008d] architectural background: unifiers own dispatch, domain packages own policy).

- **[PLAT-ARCH-008d] syscall-vs-policy test — every `#if` here encodes domain POLICY, not syscall MECHANICS**:
  | Site | Concern | Classification |
  |------|---------|----------------|
  | `Path.swift:103` separator/altSeparator constants | Which byte renders as the separator on this platform | Policy — consumer sees rendered paths differ |
  | `Path.swift:133`, `Path.swift:200`, `Path.Component.swift:40,101` UTF-16 vs UTF-8 validation/decoding | Encoding-width vocabulary (`UInt16` vs `UInt8` Char) | Policy — explicitly sanctioned by [PLAT-ARCH-008a] example 3 |
  | `Path.Introspection.swift:37` (isAbsolute), `:157` (endsWithSeparator), `:172` (isRoot) | UNC prefix, drive-letter root, altSeparator recognition | Policy — path-root convention is consumer-observable |
  | `Path.Navigation.swift:62` (parent), `:234` (_isSeparator), `:345` (Storage joining trailing-sep dedup) | Separator deduplication, parent-of-drive-root semantics | Policy — consumer sees different parent paths |
  | `Path.Navigation.swift:318` (Storage.init(driveLetter:)) | Windows-only `C:\` reconstruction | Policy — absent on POSIX by construction |
  | `Path.Component.swift:73` (reject `/` only) vs `:51` (reject `/` AND `\`) | Which bytes are forbidden in a component | Policy — separator set is path domain knowledge |
  | `Path.Component.Stem.swift:46`, `Path.Component.Extension.swift:50` | Reject both `/` and `\` on Windows | Policy — same as Component |

  No site dispatches a syscall. No site wraps an errno-to-enum mapping or a read/write loop. No candidate qualifies for pushing up into `swift-kernel`.

- **[PLAT-ARCH-008c] platform extensions over primitive conditionals** — PASS. `Path.View` (the ~Copyable, ~Escapable L2-bridging type in `Path.View.swift`) contains zero `#if` conditionals. This matches the rule's intent: L1-style view types stay unconditional; platform-varying behavior lives in the owning L3 `Path` type's extensions. The prior migration of `Path.View.parentBytes` / `.lastComponentBytes` / `.appending` into iso-9945 / windows-standard (cited in the task framing) is honored — nothing has regressed back into this package.

- **[PLAT-ARCH-008c] file-level gating as the preferred shape** — `Path.Component+PlatformNative.POSIX.swift` (`#if !os(Windows)` at file top, line 12) and `Path.Component+PlatformNative.Windows.swift` (`#if os(Windows)` at file top, line 12) use file-level gates rather than interior conditionals. This is the structurally cleanest shape for platform-specific constructors: each file compiles as a whole unit on its platform. No finding — this is exemplary.

- **[PLAT-ARCH-001/002/010/011/012] L3 placement** — PASS. swift-paths sits at L3 as a domain unifier. Its dependency `swift-kernel-primitives` is L1; its test-only dependency `swift-kernel` is the sibling L3 platform-stack unifier. No upward or lateral dependencies.

- **[PATTERN-005] Swift 6 language mode** — PASS. `// swift-tools-version: 6.3`, `platforms: [.v26]` across macOS/iOS/tvOS/watchOS/visionOS, full upcoming/experimental feature set applied via the target loop: `ExistentialAny`, `InternalImportsByDefault`, `MemberImportVisibility`, `NonisolatedNonsendingByDefault`, `InferIsolatedConformances`, `LifetimeDependence` (both upcoming and experimental), `Lifetimes`, `SuppressedAssociatedTypes`, `strictMemorySafety()`. Matches [PATTERN-005], [PATTERN-006], [PATTERN-007].

- **[PATTERN-009] typed-throws-safe catch patterns** — PASS. No catch blocks in the package rely on the `catch let error where` pattern; typed throws (`throws(Path.Error)`, `throws(Component.Error)`, etc.) are used throughout and errors propagate via `throw .case` inside initializers.

**Supersession note**: The prior 2026-03-19 legacy finding set (H-25 through H-30 in the Legacy section of the previous `audit.md`) flagged the `#if os(Windows)` sites in `Path.Introspection.swift`, `Path.Navigation.swift`, `Path.Component.swift`, `Path.swift`, `Path.Component.Stem.swift`, and `Path.Component.Extension.swift` as [PLAT-ARCH-008] violations and proposed a `Kernel.Path.Separator` unification. That finding set predates [PLAT-ARCH-008a] (domain authority exception) and [PLAT-ARCH-008d] (syscall-vs-policy test). Under the current rules, swift-paths is the canonical domain owner of path separator conventions — path separators are path domain knowledge, not kernel knowledge ([PLAT-ARCH-008a] example 1, verbatim). Unifying into `Kernel.Path.Separator` would force swift-kernel to absorb path-domain policy it should not own. H-25–H-30 are dropped as resolved-by-rule-evolution, not dropped as ignored.

---

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
</content>
</invoke>