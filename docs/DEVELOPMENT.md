# Development guide

## Repository map

```text
VibeSite/Html.lean       HTML algebra, escaping, and serialization
VibeSite/Markdown.lean   Markdown-lite parser and renderer
VibeSite/Site.lean       site model, validation, layout, and emission
VibeSite/Example.lean    executable example site
VibeSite.lean            public library imports
Main.lean                command-line interface
Tests.lean               executable regression tests
preview/                 checked-in example output for inspection
```

## Local checks

Run the same core checks used in continuous integration:

```sh
lake build
lake exe vibesite_tests
lake exe vibesite check
lake exe vibesite build
```

A change to rendering should normally be accompanied by an exact-output regression test in `Tests.lean` and an updated checked-in preview when visible output changes.

## Change discipline

Parser changes should document the accepted syntax and at least one rejected or deliberately unsupported edge case. Route changes should preserve the separation among normalization, public URL generation, and output-path generation. Rendering changes should keep untrusted text in `Html.text` and avoid `Html.rawTrusted` unless the value was produced wholly inside the trusted generator.

## Versioning

The package version lives in `lakefile.lean`. Until the feature contract stabilizes, minor releases may add syntax and fields while patch releases should be restricted to compatible fixes and documentation.
