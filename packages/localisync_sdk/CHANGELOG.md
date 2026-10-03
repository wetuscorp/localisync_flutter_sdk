# 0.1.0

- Initial Localisync protocol v1 implementation.
- Native cache byte accounting and large UTF-8 encoding run off the UI isolate;
  byte budgets, digest checks and atomic generation commits remain unchanged.
- Private blob workers verify and persist bytes while the root isolate retains
  the commit lock; large file buffers do not cross the UI isolate.
- Native content preparation transfers one locale at a time to isolates while
  preserving cross-locale inventories, application contracts and atomic activation.
- Compare contract metadata in bounded steps before native compilation; avoid sending
  the previous locale's complete entry graph to the compiler isolate.
- Consolidate protocol and platform adapters into one `localisync_sdk` package.
- Expose a pure Dart `core.dart` entry and keep the Git-only generator outside runtime dependencies.

## Optional diagnostics

- Add explicit, disabled-by-default diagnostic configuration with a separate write-only credential.
- Bound memory, deduplicate fixed codes and cancel reporting on disposal. No translation or application error content is collected; reporting failures preserve active translations.
