# Design note

## Purpose

LeanSite tests a narrow proposition: a useful static publishing pipeline can be represented as typed Lean data while remaining small enough to audit in one sitting.

The project does not use theorem proving merely because Lean provides it. The initial value comes from a stricter ordinary-programming substrate: explicit data models, hidden constructors, exhaustive pattern matching, a controlled rendering boundary, and one compiler-checked configuration language shared by content and generator.

## Design goals

1. **Small trusted core.** The generator should have few moving parts and no third-party Lean dependencies.
2. **Safe routes by construction.** A `Page` or `NavItem` must not contain an unsafe logical route.
3. **Safe default rendering.** User-visible text and attributes must be escaped at the final HTML boundary.
4. **Deterministic output.** A site configuration should map to a predictable directory tree.
5. **Fail before emission.** Invalid route graphs and deployment paths should be rejected before page files are written.
6. **Inspectable content model.** The supported Markdown subset and its limitations should be obvious from the parser.
7. **Static-host portability.** Generated output should require no application server or JavaScript runtime.
8. **Subpath correctness.** A site mounted below a domain root must generate coherent internal links without post-processing.

## Non-goals for the first release

LeanSite is not currently:

- a CommonMark implementation;
- a template language or plugin host;
- an incremental build system;
- a content-management system;
- a live-reload development server;
- a filesystem Markdown discovery tool;
- a proof that generated HTML is semantically valid under the full HTML specification.

These exclusions keep the first trust boundary narrow.

## Pipeline

```text
literal segments ── proof ─────┐
                               ├──> Route ──> Page / NavItem
runtime text ─── checked parse ┘                  │
                                                  ├── validate graph and base path
                                                  └── published Page values
                                                         │
                                                         ├── parse Markdown-lite
                                                         ├── resolve basePath
                                                         ├── construct Html tree
                                                         ├── escape and serialize
                                                         └── write route directories
```

Route safety is established before a site configuration exists. `build` still validates relationships among already-safe values before creating output.

## Core data model

`SiteConfig` owns site-wide metadata, public origin, deployment base path, output location, pages, and primary navigation. `Page` owns a typed route, title, description, Markdown body, and draft state. `NavItem` deliberately contains only a label and typed route.

This is intentionally less flexible than a generic dictionary. The fields identify the publishing contract directly and provide compiler-visible extension points.

## Route representation

`Route` is a structure with a private constructor. Its stored representation is a list of path segments, but code outside `LeanSite.Path` cannot directly manufacture a value.

The public construction surface is:

```lean
Route.root
Route.ofSegments ["notes", "first-post"] (by decide)
Route.fromSegments dynamicSegments
Route.parse dynamicText
```

`Route.ofSegments` is intended for statically known routes. It requires a proof that `segments.all Route.isSafeSegment = true`; concrete lists are normally discharged with `by decide` during elaboration.

`Route.fromSegments` and `Route.parse` are intended for dynamic input. They return `Except Route.Error Route`, so callers must handle malformed routes explicitly.

A segment is accepted only when it:

1. is non-empty;
2. is not `.`;
3. is not `..`;
4. contains neither `/` nor `\`.

Consequently, internal empty segments, traversal segments, and embedded path separators cannot inhabit `Route` through the public API. The root route is represented by an empty segment list and is available only as `Route.root` or the successful parse of an all-slash input.

The canonical public form is:

```text
/                  for Route.root
/<segments...>/    for every other route
```

The corresponding filesystem path is `<output>/<segments...>/index.html`. URL rendering and filesystem construction therefore consume the same validated segment list without reparsing strings.

## Route graph validation

Construction-time route safety does not eliminate graph-level obligations. `validate` still checks:

1. published routes are unique;
2. the deployment base path contains no empty, `.` or `..` segment;
3. every navigation item resolves to a published route.

The former `unsafeRoute` validation case has been removed because an unsafe page route cannot be represented.

## Deployment base path

A page route identifies a logical page and filesystem directory. `basePath` identifies where that complete route tree is mounted publicly. For a GitHub project Pages site:

```lean
baseUrl := "https://fyremael.github.io"
basePath := "/LEANSITE"
```

The public root becomes `/LEANSITE/`, while the generated filesystem root remains `_site/`. Keeping these concepts separate avoids embedding hosting details in `Route` values.

`BasePath` remains string-based because it is deployment configuration rather than a page identity. It is normalized and validated before emission. A future refinement may give it its own private constructor if deployment configuration begins to flow through more APIs.

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

Inline parsing produces small `Html` trees for emphasis, strong text, code, and links. `renderWithBasePath` rewrites only root-relative link targets. External URLs, protocol-relative URLs, and ordinary relative paths remain unchanged.

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
- base-path-aware stylesheet and navigation links;
- primary navigation with `aria-current`;
- a semantic `article` body;
- generated footer text;
- a single generated stylesheet.

The stylesheet uses system fonts, a bounded reading width, automatic dark mode, and no external assets. Generated pages therefore have no network dependencies beyond their own files.

## GitHub Pages deployment

The example site sets its public origin and project path explicitly. The Pages workflow runs the actual Lean build, validates the site, executes the regression suite, generates `_site/`, uploads that directory as a Pages artifact, and deploys it through the `github-pages` environment.

The generator emits `.nojekyll` so GitHub Pages serves the directory exactly as generated. The public demo is output from the same executable and configuration documented for users.

## Failure model

Static route declarations fail during elaboration when their safety proof cannot be discharged. Dynamic construction returns a precise `Route.Error` identifying the segment index and failure class.

`check` returns a non-zero process status when graph or base-path validation fails. `build` raises an `IO.userError` containing all collected validation messages before page emission.

The duplicate detector currently reports the first duplicate route. Unsafe base paths and missing navigation targets are collected through the validation path. A future diagnostic type should include source identifiers and report every duplicate group.

Filesystem errors propagate through `IO`; they are not converted into custom diagnostics.

## Determinism and reproducibility

Given the same Lean toolchain, source tree, and configuration values, LeanSite emits the same logical files in page-list order. Generated documents contain no timestamps or random identifiers.

The repository pins Lean through `lean-toolchain`; continuous integration builds the project and runs its regression suite; the Pages workflow deploys only generated output from `main`.

## Extension points

The next defensible extensions are:

1. **A typed deployment base path** if deployment configuration needs the same construction guarantees as page routes.
2. **Assets** with an explicit copy manifest and collision checks.
3. **Filesystem content discovery** that parses typed front matter into `Page` values and checked routes.
4. **Incremental builds** keyed by source and template hashes.
5. **Feeds and structured metadata** generated from explicit publication dates and tags.
6. **A retained Markdown AST** if transformations, table-of-contents generation, or source maps become necessary.

Each extension should preserve the central rule: widen the feature surface only when its validation and trust boundary remain legible.

## Security assumptions

LeanSite assumes that the Lean source defining the site is trusted. Under that assumption, it prevents page-route traversal through construction and protects text and attribute serialization from accidental HTML injection.

It does not yet protect against:

- malicious link schemes supplied in trusted configuration;
- unsafe content passed explicitly through `Html.rawTrusted`;
- symlink or hostile-filesystem behaviour outside the route model;
- platform-specific reserved filenames;
- denial of service from extremely large source strings.

These limits should be revisited before embedding the generator in a multi-author or network-facing service.
