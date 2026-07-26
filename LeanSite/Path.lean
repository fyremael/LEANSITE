namespace LeanSite

private def stripSlashChars (chars : List Char) : List Char :=
  let left := chars.dropWhile fun c => c == '/'
  (left.reverse.dropWhile fun c => c == '/').reverse

/-- A logical page route whose segments have already passed LeanSite's safety policy.
    The constructor is private so route invariants can only be established through
    `Route.root`, `Route.ofSegments`, or `Route.parse`. -/
structure Route where
  private mk ::
  segments : List String
  deriving Repr, BEq

namespace Route

inductive Error where
  | emptySegment (index : Nat)
  | currentSegment (index : Nat)
  | parentSegment (index : Nat)
  | separatorInSegment (index : Nat) (segment : String)
  deriving Repr, BEq

def isSafeSegment (segment : String) : Bool :=
  !segment.isEmpty &&
    segment != "." &&
    segment != ".." &&
    !(segment.toList.any fun c => c == '/' || c == '\\')

private def checkSegments : Nat → List String → Except Error Unit
  | _, [] => .ok ()
  | index, segment :: rest =>
      if segment.isEmpty then
        .error (.emptySegment index)
      else if segment == "." then
        .error (.currentSegment index)
      else if segment == ".." then
        .error (.parentSegment index)
      else if segment.toList.any fun c => c == '/' || c == '\\' then
        .error (.separatorInSegment index segment)
      else
        checkSegments (index + 1) rest

def root : Route :=
  ⟨[]⟩

instance : Inhabited Route :=
  ⟨root⟩

/-- Construct a route from literal or otherwise statically known segments.
    `by decide` discharges the proof for concrete safe segment lists. -/
def ofSegments (segments : List String) (_safe : segments.all isSafeSegment = true) : Route :=
  ⟨segments⟩

/-- Validate dynamically supplied route segments. -/
def fromSegments (segments : List String) : Except Error Route := do
  checkSegments 0 segments
  pure ⟨segments⟩

/-- Parse a slash-delimited route. Leading and trailing slashes are ignored;
    empty internal segments, traversal segments, and embedded separators fail. -/
def parse (input : String) : Except Error Route :=
  let normalized := String.ofList (stripSlashChars input.toList)
  if normalized.isEmpty then
    .ok root
  else
    fromSegments (normalized.splitOn "/")

def toPath (route : Route) : String :=
  String.intercalate "/" route.segments

def href (route : Route) : String :=
  if route.segments.isEmpty then "/" else s!"/{toPath route}/"

def directory (output : System.FilePath) (route : Route) : System.FilePath :=
  route.segments.foldl (fun path segment => path / segment) output

end Route

namespace BasePath

def normalize (basePath : String) : String :=
  let path := String.ofList (stripSlashChars basePath.toList)
  if path.isEmpty then "" else s!"/{path}"

def hasUnsafeSegment (basePath : String) : Bool :=
  let path := String.ofList (stripSlashChars basePath.toList)
  (path.splitOn "/").any fun segment =>
    segment.isEmpty || segment == "." || segment == ".."

/-- Prefix a root-relative URL with the deployment base path.
    External, protocol-relative, and relative URLs are unchanged. -/
def resolve (basePath href : String) : String :=
  let base := normalize basePath
  if base.isEmpty || !(href.startsWith "/") || href.startsWith "//" then
    href
  else
    base ++ href

end BasePath

end LeanSite
