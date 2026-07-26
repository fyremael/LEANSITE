# Usage guide

LeanSite is a small static site generator whose configuration and content are ordinary Lean values. There is no external configuration language and no runtime server.

## 1. Install the toolchain

The repository pins its Lean version in `lean-toolchain`. Install `elan`, then let Lake select the pinned toolchain automatically.

```sh
lake build
```

A successful build creates the `leansite` and `leansite_tests` executables under Lake's build directory.

## 2. Validate and build the example site

```sh
lake exe leansite check
lake exe leansite build
```

`check` validates the published route graph and deployment base path without writing output. Page-route safety has already been established when each `Route` value was constructed. `build` repeats graph validation and emits the site into `_site/`.

To use a different output directory:

```sh
lake exe leansite build dist
```

Calling the executable without arguments is equivalent to `build`.

## 3. Construct routes

`Page.route` and `NavItem.route` require `LeanSite.Route`, not `String`. The structure constructor is private.

Use the root value for `/`:

```lean
private def homeRoute : LeanSite.Route :=
  LeanSite.Route.root
```

For a statically known route, provide segments and let Lean prove their safety:

```lean
private def notesRoute : LeanSite.Route :=
  LeanSite.Route.ofSegments ["notes", "first-post"] (by decide)
```

The proof succeeds only when every segment:

- is non-empty;
- is not `.` or `..`;
- contains neither `/` nor `\`.

An invalid literal does not produce a `Route`; its `by decide` proof fails during elaboration.

For dynamic text, use `Route.parse` and handle the result:

```lean
def loadRoute (input : String) : IO LeanSite.Route :=
  match LeanSite.Route.parse input with
  | .ok route => pure route
  | .error error =>
      throw <| IO.userError s!"invalid route: {reprStr error}"
```

`Route.parse` ignores leading and trailing slashes. It rejects empty internal segments, traversal segments, and embedded separators. `Route.fromSegments` provides the same checked construction when dynamic input is already split into segments.

## 4. Define a site

The example configuration lives in `LeanSite/Example.lean`. A complete configuration has this shape:

```lean
import LeanSite.Site

open LeanSite

private def homeRoute : Route := Route.root

private def home : Page := {
  route := homeRoute
  title := "Home"
  description := "The home page."
  markdown := String.intercalate "\n" [
    "A site written as **typed Lean data**."
  ]
}

def site : SiteConfig := {
  title := "My site"
  tagline := "A short default description."
  baseUrl := "https://example.com"
  basePath := ""
  language := "en-CA"
  outputDir := System.FilePath.mk "_site"
  pages := [home]
  navigation := [
    { label := "Home", route := homeRoute }
  ]
}
```

`Main.lean` imports the selected configuration and passes it to `LeanSite.build`. For a new site, replace `LeanSite.Example.site` with your own definition.

### Public origin and deployment path

`baseUrl` is the public origin without a trailing slash. `basePath` is the optional path below that origin.

A domain-root site uses:

```lean
baseUrl := "https://example.com"
basePath := ""
```

A GitHub project Pages site uses:

```lean
baseUrl := "https://fyremael.github.io"
basePath := "/LEANSITE"
```

LeanSite applies `basePath` to:

- navigation and the site-title link;
- the generated stylesheet URL;
- root-relative Markdown links such as `[Design](/design/)`;
- canonical URLs, sitemap entries, and the sitemap URL in `robots.txt`.

External, protocol-relative, and relative Markdown URLs are not prefixed. Empty internal segments and `.` or `..` segments in `basePath` are rejected during site validation.

## 5. Add pages

A page is a `Page` record with a previously constructed route:

```lean
private def notesRoute : Route :=
  Route.ofSegments ["notes", "first-post"] (by decide)

private def notes : Page := {
  route := notesRoute
  title := "First post"
  description := "A first note."
  markdown := String.intercalate "\n" [
    "## A section",
    "",
    "The page body is Markdown-lite."
  ]
}
```

Add the value to `SiteConfig.pages`. Reuse the same route in a `NavItem` only when the page should appear in the primary navigation.

### Route semantics

- `Route.root` maps to `_site/index.html` and `/`.
- `Route.ofSegments ["notes", "first-post"] ...` maps to `_site/notes/first-post/index.html` and `/notes/first-post/`.
- `Route.parse "/notes/first-post/"` returns the same logical route.
- `Route.parse "//notes/first-post//"` also returns the same route because only outer slashes are normalized.
- `Route.parse "/notes//first-post"`, `Route.parse "/./x"`, and `Route.parse "/../x"` fail.
- duplicate typed routes are rejected by site validation;
- a navigation target must name a published page.

These rules produce directory-style URLs with trailing slashes.

### Draft pages

Set `draft := true` to keep a page in source without publishing it:

```lean
private def unfinished : Page := {
  route := Route.ofSegments ["unfinished"] (by decide)
  title := "Unfinished"
  draft := true
  markdown := "Not emitted."
}
```

Draft routes are not valid navigation targets.

## 6. Markdown-lite syntax

The parser intentionally supports a compact subset rather than CommonMark:

````markdown
# Heading 1
## Heading 2

A paragraph with **strong text**, *emphasis*, `inline code`, and
[a link](https://example.com).

- unordered item
- another item

1. ordered item
2. another item

> A block quote.

```lean
#eval 2 + 2
```

---
````

Current limitations include nested lists, images, tables, footnotes, raw HTML, reference links, and full CommonMark delimiter rules.

## 7. Metadata and generated files

When `baseUrl` is non-empty, every page receives a canonical URL and the build emits `sitemap.xml`. The generator emits:

```text
_site/
├── .nojekyll
├── index.html
├── style.css
├── robots.txt
├── sitemap.xml       when baseUrl is set
└── <route>/index.html
```

The page description defaults to `SiteConfig.tagline` when `Page.description` is empty.

## 8. Test the generator

```sh
lake exe leansite_tests
```

The executable suite covers certified routes, checked parsing failures, base-path normalization, HTML escaping, Markdown rendering, root-relative link rewriting, duplicate routes, and missing navigation targets.

## 9. Publish the output

The output directory contains ordinary static files. It can be deployed to GitHub Pages, Netlify, Cloudflare Pages, an object store, or a conventional web server.

This repository's `.github/workflows/pages.yml` workflow builds the example with Lean and deploys `_site/` to GitHub Pages after successful pushes to `main`.

Public demo:

```text
https://fyremael.github.io/LEANSITE/
```

## Troubleshooting

**`lake` selects the wrong Lean version.** Run `elan show` and confirm that `lean-toolchain` is being respected.

**A static route fails to elaborate.** Inspect the segment list passed to `Route.ofSegments`. Empty strings, `.`, `..`, `/`, and `\` are not admitted.

**Dynamic route parsing fails.** Pattern-match on `Route.Error`; it reports the failing segment index and category.

**Validation reports a duplicate route.** Two `Route` values contain the same validated segment list. Reuse a named route value where page and navigation identity should match.

**A navigation target is missing.** Ensure the typed route appears on a published page and is not used only by a draft.

**Links work locally but fail on a project Pages site.** Set `basePath` to the repository path, such as `/LEANSITE`.

**The build writes no sitemap.** Set `SiteConfig.baseUrl` to the public origin of the deployed site.
