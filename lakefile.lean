import Lake
open Lake DSL

package «vibesite» where
  version := v!"0.1.0"

lean_lib VibeSite

@[default_target]
lean_exe vibesite where
  root := `Main

lean_exe vibesite_tests where
  root := `Tests
