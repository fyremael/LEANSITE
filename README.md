# LeanSite

**LeanSite** is a small, dependency-free static site generator written in Lean 4. A site is declared as typed Lean data; the generator validates routes, parses a compact Markdown subset, renders escaped HTML, and emits portable static files.

**Public demo:** https://fyremael.github.io/LEANSITE/

The project is intentionally narrow. Its purpose is to establish a legible typed publishing core before adding discovery, plugins, incremental builds, or richer templating.

## Start here

Requirements:

- Lean 4.32.1 through `elan`
- Lake, included with Lean

Build, validate, generate, and test:

```sh
lake build
lake exe leansite check
lake exe leansite build
lake exe leansite_tests
```

The generated site appears in `_site/`. To select another output directory:

```sh
lake exe leansite build dist
```

## Define a page

Edit `LeanSite/Example.lean` or replace it with another imported site definition:

```lean
private def firstPost : LeanSite.Page := {
  route := "/notes/first-post/"
  title := "First post"
  description := "An optional search description."
  markdown := String.intercalate "\n" [
    "# Markdown content",
    "",
    "The body lives here."
  ]
}
```

Add the page to `SiteConfig.pages` and, when appropriate, add its route to `SiteConfig.navigation`.

For deployment below a domain root, set both the public origin and path prefix:

```lean
baseUrl := "https://fyremael.github.io"
basePath := "/LEANSITE"
```

LeanSite applies the base path to navigation, stylesheets, canonical URLs, sitemap entries, and root-relative Markdown links.

## Documentation

- [Usage guide](docs/USAGE.md): installation, configuration, routes, drafts, Markdown, deployment, and troubleshooting.
- [Design note](docs/DESIGN.md): goals, invariants, parser and rendering architecture, trust boundary, failure model, and extension plan.
- [Development guide](docs/DEVELOPMENT.md): repository structure, checks, test expectations, and change discipline.

## Current feature surface

- typed `SiteConfig`, `Page`, and `NavItem` values;
- route and deployment-base-path normalization and validation;
- headings, paragraphs, lists, blockquotes, fenced code, rules, emphasis, strong text, inline code, and links;
- escaped text and HTML attributes;
- responsive generated CSS with automatic dark mode;
- canonical links, `robots.txt`, `.nojekyll`, and optional sitemap;
- executable CLI validation and regression tests;
- GitHub Pages deployment from generated Lean output;
- dependency-free generated output.

This is intentionally not CommonMark. The parser is small enough to inspect as a complete unit.

## Architecture

```text
SiteConfig
  → route and base-path validation
  → Markdown-lite parsing
  → escaped Html tree
  → deterministic static files
  → optional GitHub Pages deployment
```

Core modules:

- `LeanSite/Path.lean`: route and deployment base-path operations;
- `LeanSite/Html.lean`: escaped HTML tree and renderer;
- `LeanSite/Markdown.lean`: Markdown-lite parser and base-path-aware link rendering;
- `LeanSite/Site.lean`: page model, validation, layout, and file emission;
- `LeanSite/Example.lean`: example site definition;
- `Main.lean`: command-line interface;
- `Tests.lean`: executable regression tests.

## Deliberate constraints

The first release has no plugins, incremental cache, content-directory discovery, feed generation, template inheritance, asset pipeline, or live server. These are candidates for later stages once their invariants and trust boundaries are explicit.
