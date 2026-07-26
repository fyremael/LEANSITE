import LeanSite.Example

open LeanSite

private def assertEqual [BEq α] [Repr α] (label : String) (actual expected : α) : IO Unit := do
  unless actual == expected do
    throw <| IO.userError s!"{label}: expected {reprStr expected}, got {reprStr actual}"

private def expectParsedRoute (label input expectedHref : String) : IO Unit := do
  match Route.parse input with
  | .ok route => assertEqual label (Route.href route) expectedHref
  | .error error =>
      throw <| IO.userError s!"{label}: expected a route, got {reprStr error}"

private def expectRouteError (label input : String) : IO Unit := do
  match Route.parse input with
  | .ok route =>
      throw <| IO.userError s!"{label}: expected an error, got {Route.href route}"
  | .error _ => pure ()

private def routeTests : IO Unit := do
  let notes := Route.ofSegments ["notes", "hello"] (by decide)
  assertEqual "root href" (Route.href Route.root) "/"
  assertEqual "certified href" (Route.href notes) "/notes/hello/"
  expectParsedRoute "normalized parse" "//notes/hello//" "/notes/hello/"
  expectRouteError "parent segment rejected" "/a/../b"
  expectRouteError "current segment rejected" "/a/./b"
  expectRouteError "empty internal segment rejected" "/a//b"
  expectRouteError "backslash rejected" "/a\\b"
  assertEqual "empty base path safe" (BasePath.hasUnsafeSegment "") false
  assertEqual "internal empty base segment rejected" (BasePath.hasUnsafeSegment "/a//b") true
  assertEqual "normalized base path" (BasePath.normalize "//LEANSITE//") "/LEANSITE"
  assertEqual "base path root" (BasePath.resolve "/LEANSITE" "/") "/LEANSITE/"
  assertEqual "base path route" (BasePath.resolve "/LEANSITE/" "/design/") "/LEANSITE/design/"
  assertEqual "external URL unchanged" (BasePath.resolve "/LEANSITE" "https://lean-lang.org/") "https://lean-lang.org/"

private def htmlTests : IO Unit := do
  assertEqual "text escaping" (Html.escapeText "<a>&") "&lt;a&gt;&amp;"
  assertEqual "attribute escaping" (Html.escapeAttribute "\"x\"") "&quot;x&quot;"
  let rendered := Html.render (Html.node "p" [Html.txt "A & B"])
  assertEqual "html rendering" rendered "<p>A &amp; B</p>"

private def markdownTests : IO Unit := do
  let rendered := Html.render (Markdown.render "# Hello\n\nA **small** site.")
  assertEqual "markdown rendering" rendered "<h1>Hello</h1><p>A <strong>small</strong> site.</p>"
  let prefixed := Html.render (Markdown.renderWithBasePath "/LEANSITE" "[Design](/design/)")
  assertEqual "Markdown base path" prefixed "<p><a href=\"/LEANSITE/design/\">Design</a></p>"

private def validationTests : IO Unit := do
  assertEqual "example validates" (validate LeanSite.Example.site).isEmpty true
  let domainRoot : SiteConfig := {
    title := "root"
    pages := [{ route := Route.root, title := "Home", markdown := "home" }]
  }
  assertEqual "domain-root site validates" (validate domainRoot).isEmpty true
  let xRoute := Route.ofSegments ["x"] (by decide)
  let duplicate : SiteConfig := {
    title := "broken"
    pages := [
      { route := xRoute, title := "X", markdown := "x" },
      { route := xRoute, title := "Again", markdown := "x" }
    ]
  }
  assertEqual "duplicate rejected" (validate duplicate).isEmpty false
  let unsafePath : SiteConfig := { title := "broken", basePath := "/../site" }
  assertEqual "unsafe base path rejected" (validate unsafePath).isEmpty false
  let missingRoute := Route.ofSegments ["missing"] (by decide)
  let missingNavigation : SiteConfig := {
    title := "broken"
    navigation := [{ label := "Missing", route := missingRoute }]
  }
  assertEqual "missing navigation rejected" (validate missingNavigation).isEmpty false

def main : IO UInt32 := do
  routeTests
  htmlTests
  markdownTests
  validationTests
  IO.println "All LeanSite tests passed."
  pure 0
