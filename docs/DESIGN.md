# Design note

## Purpose

VibeSite tests a narrow proposition: a useful static publishing pipeline can be represented as typed Lean data while remaining small enough to audit in one sitting.

The project does not use theorem proving merely because Lean provides it. The initial value comes from a stricter ordinary-programming substrate: explicit data models, exhaustive pattern matching, a controlled rendering boundary, and one compiler-checked configuration language shared by content and generator.

## Design goals

1. **Small trusted core.** The generator should have few moving parts and no third-party Lean dependencies.
2. **Safe default rendering.** User-visible text and attributes must be escaped at the final HTML boundary.
3. **Deterministic output.** A site configuration should map to a predictable directory tree.
4. **Fail before emission.** Invalid route graphs should be rejected before page files are written.
5. **Inspectable content model.** The supported Markdown subset and its limitations should be obvious from the parser.
6. **Static-host portability.** Generated output should require no application server or JavaScript runtime.

## Non-goals for the first release

VibeSite is not currently:

- a CommonMark implementation;
- a template language or plugin host;
- an incremental build system;
- a content-management system;
- a live-reload development server;
- a filesystem Markdown discovery tool;
- a proof that generated HTML is semantically valid under the full HTML specification.

These exclusions keep the first trust boundary narrow.

## Pipeline

The build proceeds through five stages:

```text
SiteConfig
   │
   ├── validate route graph
   │
   └── published Page values
          │
          ├── parse Markdown-lite blocks and inlines
          │
          ├── construct Html tree
          │
          ├── escape and serialize
          │
          └── write deterministic route directories
```

`build` performs validation before creating page output. Once validation passes, each non-draft page is rendered independently.

## Core data model

`SiteConfig` owns site-wide metadata, output location, pages, and primary navigation. `Page` owns route, title, description, Markdown body, and draft state. `NavItem` deliberately contains only a label and route.

This is intentionally less flexible than a generic dictionary. The fields identify the current publishing contract directly and provide compiler-visible extension points.

## Route model and invariants

A route is currently stored as `String`, then normalized by removing leading and trailing slash characters. Its canonical public form is:

```text
/                  for the root page
/<normalized>/     for every other page
```

The corresponding filesystem path is `<output>/<normalized>/index.html`.

Validation enforces three invariants over published pages:

1. normalized routes are unique;
2. route segments do not equal `.` or `..`;
3. every navigation item resolves to a published route.

The runtime validator is a deliberate first-stage compromise. A stronger design would replace unrestricted route strings with a smart constructor:

```lean
structure Route where
  segments : List SafeSegment
```

The constructor would make unsafe routes unrepresentable and allow validation proofs to move closer to page construction.

## Markdown representation

The Markdown module separates block parsing from HTML rendering. Its block algebra is:

```lean
inductive Block where
  | heading
  | paragraph
  | unorderedList
  | orderedList
  | quote
  | code
  | rule
```

Inline parsing directly produces small `Html` trees for emphasis, strong text, code, and links. This keeps the parser compact, at the cost of not retaining a standalone inline syntax tree.

The parser is line-oriented and intentionally non-CommonMark. Ambiguous edge cases are resolved by simple local rules rather than by reproducing the full CommonMark state machine.

## HTML trust boundary

`Html` distinguishes three constructors:

- `text`, escaped as text content;
- `element`, whose attribute values are escaped during rendering;
- `raw`, emitted without escaping.

Normal page rendering uses `text` and `element`. `raw` is reserved for output already produced by the trusted renderer, such as a rendered fragment and the doctype wrapper. `Html.rawTrusted` makes the danger visible in its name but does not enforce provenance.

This prevents direct tag injection through page titles, descriptions, Markdown text, navigation labels, and code blocks. It does not validate URL schemes. Site configurations are therefore treated as trusted source code; accepting untrusted authors would require URL-policy checks and a stronger capability boundary around raw HTML.

## Layout and styling

The layout is fixed in `Site.lean` and includes:

- UTF-8 and responsive viewport metadata;
- title and description metadata;
- optional canonical links;
- primary navigation with `aria-current`;
- a semantic `article` body;
- generated footer text;
- a single root-relative stylesheet.

The stylesheet uses system fonts, a bounded reading width, automatic dark mode, and no external assets. This gives the generated site zero network dependencies beyond its own files.

## Failure model

`check` returns a non-zero process status when validation fails. `build` raises an `IO.userError` containing all currently collected validation messages before page emission.

The current duplicate detector reports the first duplicate normalized route. Unsafe routes and missing navigation targets are collected across the complete site. A future diagnostic type should include source identifiers and report every duplicate group.

Filesystem errors propagate through `IO`; they are not converted into custom diagnostics.

## Determinism and reproducibility

Given the same Lean toolchain, source tree, and configuration values, VibeSite emits the same logical files in page-list order. The generated documents contain no timestamps or random identifiers.

The repository pins Lean through `lean-toolchain`, and continuous integration builds the project and executes its regression suite.

## Extension points

The next defensible extensions are:

1. **Validated route constructors** to make traversal and malformed segments unrepresentable.
2. **Base-path support** so root-relative links work under subdirectory deployments.
3. **Assets** with an explicit copy manifest and collision checks.
4. **Filesystem content discovery** that parses typed front matter into `Page` values.
5. **Incremental builds** keyed by source and template hashes.
6. **Feeds and structured metadata** generated from explicit publication dates and tags.
7. **A retained Markdown AST** if transformations, table-of-contents generation, or source maps become necessary.

Each extension should preserve the central rule: widen the feature surface only when its validation and trust boundary remain legible.

## Security assumptions

VibeSite assumes that the Lean source defining the site is trusted. Under that assumption, it protects text and attribute serialization from accidental HTML injection.

It does not yet protect against:

- malicious link schemes supplied in trusted configuration;
- unsafe content passed explicitly through `Html.rawTrusted`;
- symlink or hostile-filesystem behaviour outside the validated route model;
- denial of service from extremely large source strings.

These limits should be revisited before embedding the generator in a multi-author or network-facing service.
