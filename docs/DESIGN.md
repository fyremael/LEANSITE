# Design note

## Purpose

LeanSite tests a narrow proposition: a useful static publishing pipeline can be represented as typed Lean data while remaining small enough to audit in one sitting.

The project does not use theorem proving merely because Lean provides it. The initial value comes from a stricter ordinary-programming substrate: explicit data models, exhaustive pattern matching, a controlled rendering boundary, and one compiler-checked configuration language shared by content and generator.

## Design goals

1. **Small trusted core.** The generator should have few moving parts and no third-party Lean dependencies.
2. **Safe default rendering.** User-visible text and attributes must be escaped at the final HTML boundary.
3. **Deterministic output.** A site configuration should map to a predictable directory tree.
4. **Fail before emission.** Invalid route graphs and deployment paths should be rejected before page files are written.
5. **Inspectable content model.** The supported Markdown subset and its limitations should be obvious from the parser.
6. **Static-host portability.** Generated output should require no application server or JavaScript runtime.
7. **Subpath correctness.** A site mounted below a domain root must generate coherent internal links without post-processing.

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
SiteConfig
   │
   ├── validate route graph and base path
   │
   └── published Page values
          │
          ├── parse Markdown-lite blocks and inlines
          │
          ├── resolve root-relative URLs against basePath
          │
          ├── construct Html tree
          │
          ├── escape and serialize
          │
          └── write deterministic route directories
```

`build` performs validation before creating page output. Once validation passes, each non-draft page is rendered independently.

## Core data model

`SiteConfig` owns site-wide metadata, public origin, deployment base path, output location, pages, and primary navigation. `Page` owns route, title, description, Markdown body, and draft state. `NavItem` deliberately contains only a label and route.

This is intentionally less flexible than a generic dictionary. The fields identify the publishing contract directly and provide compiler-visible extension points.

## Route and base-path model

Page routes and deployment base paths are related but distinct.

A page route identifies a logical page and a filesystem directory. Its canonical public form is:

```text
/                  for the root page
/<normalized>/     for every other page
```

The corresponding filesystem path is `<output>/<normalized>/index.html`.

`basePath` identifies where that complete route tree is mounted publicly. For a GitHub project Pages site it is normally the repository name:

```lean
baseUrl := "https://fyremael.github.io"
basePath := "/LEANSITE"
```

The public root then becomes `/LEANSITE/`, while the generated filesystem root remains `_site/`. Keeping these concepts separate avoids embedding hosting details in route definitions.

`LeanSite.Path` provides two namespaces:

- `Route`, for logical route normalization, public route forms, output directories, and unsafe-segment checks;
- `BasePath`, for deployment-prefix normalization and root-relative URL resolution.

Validation enforces:

1. normalized published routes are unique;
2. route segments do not equal `.` or `..`;
3. the deployment base path contains no `.` or `..` segment;
4. every navigation item resolves to a published route.

A stronger future design would replace unrestricted route strings with smart constructors that make unsafe paths unrepresentable.

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

The generator emits `.nojekyll` so GitHub Pages serves the directory exactly as generated.

This is an important design property: the public demo is not a separately maintained mock. It is output from the same executable and configuration documented for users.

## Failure model

`check` returns a non-zero process status when validation fails. `build` raises an `IO.userError` containing all collected validation messages before page emission.

The duplicate detector currently reports the first duplicate normalized route. Unsafe routes, unsafe base paths, and missing navigation targets are collected through the validation path. A future diagnostic type should include source identifiers and report every duplicate group.

Filesystem errors propagate through `IO`; they are not converted into custom diagnostics.

## Determinism and reproducibility

Given the same Lean toolchain, source tree, and configuration values, LeanSite emits the same logical files in page-list order. Generated documents contain no timestamps or random identifiers.

The repository pins Lean through `lean-toolchain`; continuous integration builds the project and runs its regression suite; the Pages workflow deploys only generated output from `main`.

## Extension points

The next defensible extensions are:

1. **Validated route constructors** to make traversal and malformed segments unrepresentable.
2. **Assets** with an explicit copy manifest and collision checks.
3. **Filesystem content discovery** that parses typed front matter into `Page` values.
4. **Incremental builds** keyed by source and template hashes.
5. **Feeds and structured metadata** generated from explicit publication dates and tags.
6. **A retained Markdown AST** if transformations, table-of-contents generation, or source maps become necessary.

Each extension should preserve the central rule: widen the feature surface only when its validation and trust boundary remain legible.

## Security assumptions

LeanSite assumes that the Lean source defining the site is trusted. Under that assumption, it protects text and attribute serialization from accidental HTML injection.

It does not yet protect against:

- malicious link schemes supplied in trusted configuration;
- unsafe content passed explicitly through `Html.rawTrusted`;
- symlink or hostile-filesystem behaviour outside the validated route model;
- denial of service from extremely large source strings.

These limits should be revisited before embedding the generator in a multi-author or network-facing service.
