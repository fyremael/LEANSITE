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

`check` validates the published route graph and deployment base path without writing output. `build` repeats validation and emits the site into `_site/`.

To use a different output directory:

```sh
lake exe leansite build dist
```

Calling the executable without arguments is equivalent to `build`.

## 3. Define a site

The example configuration lives in `LeanSite/Example.lean`. A complete configuration has this shape:

```lean
import LeanSite.Site

open LeanSite

private def home : Page := {
  route := "/"
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
    { label := "Home", route := "/" }
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

External, protocol-relative, and relative Markdown URLs are not prefixed. `.` and `..` segments in `basePath` are rejected.

## 4. Add pages

A page is a `Page` record:

```lean
private def notes : Page := {
  route := "/notes/first-post/"
  title := "First post"
  description := "A first note."
  markdown := String.intercalate "\n" [
    "## A section",
    "",
    "The page body is Markdown-lite."
  ]
}
```

Add the value to `SiteConfig.pages`. Add a corresponding `NavItem` only when the page should appear in the primary navigation.

### Route semantics

Routes are normalized before comparison and output:

- `"/"` maps to `_site/index.html`.
- `"/notes"`, `"notes/"`, and `"//notes//"` all map to `_site/notes/index.html`.
- `.` and `..` path segments are rejected.
- duplicate normalized routes are rejected;
- a navigation target must name a published page.

These rules produce directory-style URLs with trailing slashes.

### Draft pages

Set `draft := true` to keep a page in source without publishing it:

```lean
private def unfinished : Page := {
  route := "/unfinished/"
  title := "Unfinished"
  draft := true
  markdown := "Not emitted."
}
```

Draft routes are not valid navigation targets.

## 5. Markdown-lite syntax

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

## 6. Metadata and generated files

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

## 7. Test the generator

```sh
lake exe leansite_tests
```

The executable suite covers route and base-path normalization, HTML escaping, Markdown rendering, root-relative link rewriting, and site validation.

## 8. Publish the output

The output directory contains ordinary static files. It can be deployed to GitHub Pages, Netlify, Cloudflare Pages, an object store, or a conventional web server.

This repository's `.github/workflows/pages.yml` workflow builds the example with Lean and deploys `_site/` to GitHub Pages after successful pushes to `main`.

Public demo:

```text
https://fyremael.github.io/LEANSITE/
```

## Troubleshooting

**`lake` selects the wrong Lean version.** Run `elan show` and confirm that `lean-toolchain` is being respected.

**Validation reports a duplicate route.** Compare normalized forms; `/notes`, `notes/`, and `//notes//` denote the same output page.

**A navigation target is missing.** Ensure the target appears in `pages` and is not marked as a draft.

**Links work locally but fail on a project Pages site.** Set `basePath` to the repository path, such as `/LEANSITE`.

**The build writes no sitemap.** Set `SiteConfig.baseUrl` to the public origin of the deployed site.
