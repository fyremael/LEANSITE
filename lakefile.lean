import Lake
open Lake DSL

package «leansite» where
  version := v!"0.1.0"

lean_lib LeanSite

@[default_target]
lean_exe leansite where
  root := `Main

lean_exe leansite_tests where
  root := `Tests
