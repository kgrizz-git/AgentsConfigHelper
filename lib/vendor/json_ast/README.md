# Vendored: json_ast

**Upstream:** [jhomlala/json_ast](https://github.com/jhomlala/json_ast)
**License:** MIT (see [LICENSE](LICENSE))
**Vendored:** 2026-08
**Rationale:** The upstream package is not published on pub.dev at the version needed for comment-preserving JSONC edits. Vendoring avoids a git dependency and allows local patches if required. The `utils/substring.dart` helper is included.

CI coverage deliberately excludes `lib/vendor/` from the 80% line-coverage gate.
