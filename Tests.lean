import LeanSite.Example

open LeanSite

private def assertEqual [BEq α] [Repr α] (label : String) (actual expected : α) : IO Unit := do
  unless actual == expected do
    throw <| IO.userError s!"{label}: expected {reprStr expected}, got {reprStr actual}"

private def routeTests : IO Unit := do
  assertEqual "root href" (Route.href "/") "/"
  assertEqual "normalized href" (Route.href "//notes/hello//") "/notes/hello/"
  assertEqual "unsafe parent" (Route.hasUnsafeSegment "/a/../b") true
  assertEqual "safe route" (Route.hasUnsafeSegment "/a/b") false
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
  let duplicate : SiteConfig := {
    title := "broken"
    pages := [
      { route := "/x", title := "X", markdown := "x" },
      { route := "/x/", title := "Again", markdown := "x" }
    ]
  }
  assertEqual "duplicate rejected" (validate duplicate).isEmpty false
  let unsafePath : SiteConfig := { title := "broken", basePath := "/../site" }
  assertEqual "unsafe base path rejected" (validate unsafePath).isEmpty false

def main : IO UInt32 := do
  routeTests
  htmlTests
  markdownTests
  validationTests
  IO.println "All LeanSite tests passed."
  pure 0
