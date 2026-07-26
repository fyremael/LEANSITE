namespace LeanSite

namespace Route

private def stripSlashChars (chars : List Char) : List Char :=
  let left := chars.dropWhile fun c => c == '/'
  (left.reverse.dropWhile fun c => c == '/').reverse

def normalize (route : String) : String :=
  String.ofList (stripSlashChars route.toList)

def href (route : String) : String :=
  let route := normalize route
  if route.isEmpty then "/" else s!"/{route}/"

def directory (output : System.FilePath) (route : String) : System.FilePath :=
  let route := normalize route
  if route.isEmpty then output else output / route

def hasUnsafeSegment (route : String) : Bool :=
  ((normalize route).splitOn "/").any fun segment => segment == ".." || segment == "."

end Route

namespace BasePath

def normalize (basePath : String) : String :=
  let path := Route.normalize basePath
  if path.isEmpty then "" else s!"/{path}"

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
