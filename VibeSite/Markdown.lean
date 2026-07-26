import VibeSite.Html

namespace VibeSite.Markdown

open VibeSite Html

inductive Block where
  | heading : Nat → String → Block
  | paragraph : String → Block
  | unorderedList : List String → Block
  | orderedList : List String → Block
  | quote : String → Block
  | code : Option String → String → Block
  | rule : Block
  deriving Repr, Inhabited

private def startsWithChars (prefix input : List Char) : Bool :=
  input.take prefix.length == prefix

private partial def splitAtNeedle (needle input : List Char) : Option (List Char × List Char) :=
  let rec go (acc : List Char) : List Char → Option (List Char × List Char)
    | [] => none
    | rest =>
        if startsWithChars needle rest then
          some (acc.reverse, rest.drop needle.length)
        else
          match rest with
          | [] => none
          | c :: tail => go (c :: acc) tail
  if needle.isEmpty then none else go [] input

private def takePlain (input : List Char) : List Char × List Char :=
  let rec go (acc : List Char) : List Char → List Char × List Char
    | [] => (acc.reverse, [])
    | rest@(c :: tail) =>
        if c == '*' || c == '`' || c == '[' then
          (acc.reverse, rest)
        else
          go (c :: acc) tail
  go [] input

private partial def parseInlineChars : List Char → List Html
  | [] => []
  | '*' :: '*' :: rest =>
      match splitAtNeedle ['*', '*'] rest with
      | some (inside, tail) =>
          Html.node "strong" (parseInlineChars inside) :: parseInlineChars tail
      | none => Html.txt "**" :: parseInlineChars rest
  | '*' :: rest =>
      match splitAtNeedle ['*'] rest with
      | some (inside, tail) =>
          Html.node "em" (parseInlineChars inside) :: parseInlineChars tail
      | none => Html.txt "*" :: parseInlineChars rest
  | '`' :: rest =>
      match splitAtNeedle ['`'] rest with
      | some (inside, tail) =>
          Html.node "code" [Html.txt (String.mk inside)] :: parseInlineChars tail
      | none => Html.txt "`" :: parseInlineChars rest
  | '[' :: rest =>
      match splitAtNeedle [']'] rest with
      | some (label, '(' :: afterOpen) =>
          match splitAtNeedle [')'] afterOpen with
          | some (url, tail) =>
              Html.nodeA "a" [("href", String.mk url)] (parseInlineChars label) :: parseInlineChars tail
          | none => Html.txt "[" :: parseInlineChars rest
      | _ => Html.txt "[" :: parseInlineChars rest
  | input =>
      let (plain, tail) := takePlain input
      if plain.isEmpty then
        match input with
        | [] => []
        | c :: rest => Html.txt (String.mk [c]) :: parseInlineChars rest
      else
        Html.txt (String.mk plain) :: parseInlineChars tail

def parseInline (input : String) : List Html :=
  parseInlineChars input.toList

private def heading? (line : String) : Option (Nat × String) :=
  let prefixes := [
    (6, "###### "), (5, "##### "), (4, "#### "),
    (3, "### "), (2, "## "), (1, "# ")
  ]
  prefixes.findSome? fun entry =>
    if line.startsWith entry.2 then
      some (entry.1, (line.drop entry.2.length).trim)
    else
      none

private def orderedItem? (line : String) : Option String :=
  let trimmed := line.trim
  let chars := trimmed.toList
  let digits := chars.takeWhile Char.isDigit
  match chars.drop digits.length with
  | '.' :: ' ' :: rest =>
      if digits.isEmpty then none else some (String.mk rest).trim
  | _ => none

private def unorderedItem? (line : String) : Option String :=
  let trimmed := line.trim
  if trimmed.startsWith "- " || trimmed.startsWith "* " then
    some (trimmed.drop 2).trim
  else
    none

private def isFence (line : String) : Bool :=
  line.trim.startsWith "```"

private def isRule (line : String) : Bool :=
  let t := line.trim
  t == "---" || t == "***" || t == "___"

private def startsBlock (line : String) : Bool :=
  line.trim.isEmpty || (heading? line).isSome || (unorderedItem? line).isSome ||
    (orderedItem? line).isSome || line.trim.startsWith "> " || isFence line || isRule line

private partial def collectUntilFence (lines : List String) (acc : List String := []) : List String × List String :=
  match lines with
  | [] => (acc.reverse, [])
  | line :: rest =>
      if isFence line then (acc.reverse, rest)
      else collectUntilFence rest (line :: acc)

private partial def collectUnordered (lines : List String) (acc : List String := []) : List String × List String :=
  match lines with
  | line :: rest =>
      match unorderedItem? line with
      | some item => collectUnordered rest (item :: acc)
      | none => (acc.reverse, lines)
  | [] => (acc.reverse, [])

private partial def collectOrdered (lines : List String) (acc : List String := []) : List String × List String :=
  match lines with
  | line :: rest =>
      match orderedItem? line with
      | some item => collectOrdered rest (item :: acc)
      | none => (acc.reverse, lines)
  | [] => (acc.reverse, [])

private partial def collectQuote (lines : List String) (acc : List String := []) : List String × List String :=
  match lines with
  | line :: rest =>
      let trimmed := line.trim
      if trimmed.startsWith "> " then
        collectQuote rest ((trimmed.drop 2).trim :: acc)
      else
        (acc.reverse, lines)
  | [] => (acc.reverse, [])

private partial def collectParagraph (lines : List String) (acc : List String := []) : List String × List String :=
  match lines with
  | [] => (acc.reverse, [])
  | line :: rest =>
      if startsBlock line then
        (acc.reverse, lines)
      else
        collectParagraph rest (line.trim :: acc)

partial def parseBlocks : List String → List Block
  | [] => []
  | line :: rest =>
      let trimmed := line.trim
      if trimmed.isEmpty then
        parseBlocks rest
      else if isFence line then
        let languageRaw := (trimmed.drop 3).trim
        let language := if languageRaw.isEmpty then none else some languageRaw
        let (body, tail) := collectUntilFence rest
        .code language (String.intercalate "\n" body) :: parseBlocks tail
      else
        match heading? line with
        | some (level, title) => .heading level title :: parseBlocks rest
        | none =>
            match unorderedItem? line with
            | some _ =>
                let (items, tail) := collectUnordered (line :: rest)
                .unorderedList items :: parseBlocks tail
            | none =>
                match orderedItem? line with
                | some _ =>
                    let (items, tail) := collectOrdered (line :: rest)
                    .orderedList items :: parseBlocks tail
                | none =>
                    if trimmed.startsWith "> " then
                      let (quoted, tail) := collectQuote (line :: rest)
                      .quote (String.intercalate " " quoted) :: parseBlocks tail
                    else if isRule line then
                      .rule :: parseBlocks rest
                    else
                      let (paragraph, tail) := collectParagraph rest [trimmed]
                      .paragraph (String.intercalate " " paragraph) :: parseBlocks tail

private def languageClass : Option String → List (String × String)
  | none => []
  | some language => [("class", s!"language-{language}")]

def renderBlock : Block → Html
  | .heading level body => Html.node s!"h{level}" (parseInline body)
  | .paragraph body => Html.node "p" (parseInline body)
  | .unorderedList items =>
      Html.node "ul" (items.map fun item => Html.node "li" (parseInline item))
  | .orderedList items =>
      Html.node "ol" (items.map fun item => Html.node "li" (parseInline item))
  | .quote body => Html.node "blockquote" [Html.node "p" (parseInline body)]
  | .code language body =>
      Html.node "pre" [Html.nodeA "code" (languageClass language) [Html.txt body]]
  | .rule => Html.node "hr"

def render (markdown : String) : Html :=
  Html.fragment ((parseBlocks (markdown.splitOn "\n")).map renderBlock)

end VibeSite.Markdown
