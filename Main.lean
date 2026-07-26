import LeanSite.Example

open LeanSite

private def usage : String :=
  String.intercalate "\n" [
    "LeanSite — a static site generator in Lean 4",
    "",
    "Usage:",
    "  lake exe leansite build [OUTPUT_DIRECTORY]",
    "  lake exe leansite check",
    "  lake exe leansite help"
  ]

private def configuredSite (output? : Option String) : SiteConfig :=
  match output? with
  | none => LeanSite.Example.site
  | some output => { LeanSite.Example.site with outputDir := System.FilePath.mk output }

def main (args : List String) : IO UInt32 := do
  match args with
  | [] =>
      LeanSite.build LeanSite.Example.site
      pure 0
  | ["build"] =>
      LeanSite.build LeanSite.Example.site
      pure 0
  | ["build", output] =>
      LeanSite.build (configuredSite (some output))
      pure 0
  | ["check"] =>
      let errors := LeanSite.validate LeanSite.Example.site
      if errors.isEmpty then
        IO.println "Site configuration is valid."
        pure 0
      else
        IO.eprintln s!"Validation failed with {errors.length} error(s)."
        pure 1
  | ["help"] =>
      IO.println usage
      pure 0
  | ["--help"] =>
      IO.println usage
      pure 0
  | ["-h"] =>
      IO.println usage
      pure 0
  | _ =>
      IO.eprintln usage
      pure 2
