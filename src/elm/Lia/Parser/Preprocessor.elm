module Lia.Parser.Preprocessor exposing (section)

import Combine
    exposing
        ( Parser
        , andMap
        , andThen
        , choice
        , fail
        , ignore
        , keep
        , many
        , map
        , regex
        , string
        , succeed
        , withColumn
        , withLine
        )
import Lia.Markdown.Inline.Parser exposing (line)
import Lia.Markdown.Inline.Types exposing (Inlines)
import Lia.Parser.Context exposing (Context)
import Lia.Parser.Helper exposing (newline)
import Lia.Types exposing (SectionBase)


title_tag : Parser Context Int
title_tag =
    regex "#+" |> map String.length


check : Int -> Parser s ()
check c =
    if c /= 0 then
        succeed ()

    else
        fail ""


title_str : Parser Context Inlines
title_str =
    line |> ignore newline


body : Parser Context String
body =
    [ regex "(?:[^#`<]+|[\\x0D\n]+|<!--[\\S\\s]*?-->)" -- comment
    , regex "(`{3,})[\\S\\s]*?\\1" -- code_block or ascii art
    , regex "`.+?`" -- code_block or ascii art
    , regex "(?:<([\\w+\\-]+)[\\S\\s]*?</\\2>|`|<)"
    , withColumn check |> keep (string "#")
    ]
        |> choice
        |> many
        |> map String.concat


section : Parser Context SectionBase
section =
    title_tag
        |> map SectionBase
        |> andMap (withLine succeed)
        |> andMap title_str
        |> andMap body
