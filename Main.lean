import VibeSite.Example

open VibeSite

private def usage : String :=
  """VibeSite — a static site generator in Lean 4

Usage:
  lake exe vibesite build [OUTPUT_DIRECTORY]
  lake exe vibesite check
  lake exe vibesite help
"""

private def configuredSite (output? : Option String) : SiteConfig :=
  match output? with
  | none => VibeSite.Example.site
  | some output => { VibeSite.Example.site with outputDir := System.FilePath.mk output }

def main (args : List String) : IO UInt32 := do
  match args with
  | [] =>
      VibeSite.build VibeSite.Example.site
      pure 0
  | ["build"] =>
      VibeSite.build VibeSite.Example.site
      pure 0
  | ["build", output] =>
      VibeSite.build (configuredSite (some output))
      pure 0
  | ["check"] =>
      let errors := VibeSite.validate VibeSite.Example.site
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
