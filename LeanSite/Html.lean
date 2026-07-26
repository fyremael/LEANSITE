namespace LeanSite

/-- A deliberately small HTML tree. `raw` is reserved for trusted generator output. -/
inductive Html where
  | text : String → Html
  | raw : String → Html
  | element : String → List (String × String) → List Html → Html
  deriving Repr, Inhabited

namespace Html

private def escapeWith (isAttribute : Bool) (input : String) : String :=
  input.toList.foldl (fun out c =>
    match c with
    | '&' => out ++ "&amp;"
    | '<' => out ++ "&lt;"
    | '>' => out ++ "&gt;"
    | '"' => if isAttribute then out ++ "&quot;" else out.push c
    | '\'' => if isAttribute then out ++ "&#39;" else out.push c
    | _ => out.push c) ""

def escapeText (input : String) : String :=
  escapeWith false input

def escapeAttribute (input : String) : String :=
  escapeWith true input

private def renderAttribute (attr : String × String) : String :=
  s!" {attr.1}=\"{escapeAttribute attr.2}\""

private def isVoidElement (tag : String) : Bool :=
  ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"].contains tag

partial def render : Html → String
  | .text value => escapeText value
  | .raw value => value
  | .element tag attributes children =>
      let attrs := String.join (attributes.map renderAttribute)
      if isVoidElement tag then
        s!"<{tag}{attrs}>"
      else
        s!"<{tag}{attrs}>{String.join (children.map render)}</{tag}>"

def node (tag : String) (children : List Html := []) : Html :=
  .element tag [] children

def nodeA (tag : String) (attributes : List (String × String)) (children : List Html := []) : Html :=
  .element tag attributes children

def fragment (children : List Html) : Html :=
  .raw (String.join (children.map render))

def txt (value : String) : Html := .text value

def rawTrusted (value : String) : Html := .raw value

def a (href : String) (children : List Html) : Html :=
  nodeA "a" [("href", href)] children

def classed (tag className : String) (children : List Html := []) : Html :=
  nodeA tag [("class", className)] children

end Html
end LeanSite
