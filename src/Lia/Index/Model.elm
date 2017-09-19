module Lia.Index.Model exposing (Model, init, parse_inlines)

import Lia.Code.Types exposing (..)
import Lia.Inline.Types exposing (Inline(..), Reference(..), Url(..))
import Lia.Quiz.Types exposing (Quiz(..))
import Lia.Types exposing (Block(..), Slide)


type alias Model =
    { search : String
    , index : List String
    , results : Maybe (List Int)
    }


init : List Slide -> Model
init slides =
    Model "" (List.map extract_string slides) Nothing


extract_string : Slide -> String
extract_string slide =
    slide.title
        ++ (slide.body
                |> List.map parse_block
                |> String.concat
           )
        |> String.toLower


parse_block : Block -> String
parse_block element =
    case element of
        Paragraph e ->
            parse_inlines e

        Quote e ->
            parse_inlines e

        CodeBlock code ->
            case code of
                Highlight lang str ->
                    str

                EvalJS _ ->
                    ""

        Quiz block ->
            parse_quiz block

        EBlock _ _ sub_blocks ->
            List.map (\sub -> parse_block sub) sub_blocks
                |> String.concat

        _ ->
            ""


parse_quiz : Quiz -> String
parse_quiz quiz =
    case quiz of
        Text _ _ _ ->
            ""

        SingleChoice _ e _ _ ->
            List.map parse_inlines e
                |> String.concat

        MultipleChoice _ e _ _ ->
            List.map parse_inlines e
                |> String.concat


parse_inlines : List Inline -> String
parse_inlines list =
    List.map parse_inline list
        |> String.concat


parse_inline : Inline -> String
parse_inline element =
    case element of
        Chars str ->
            str

        Code str ->
            str

        Bold e ->
            parse_inline e

        Italic e ->
            parse_inline e

        Underline e ->
            parse_inline e

        Superscript e ->
            parse_inline e

        Ref e ->
            case e of
                Link alt_ url_ ->
                    alt_ ++ " " ++ parse_url url_

                Image alt_ url_ _ ->
                    alt_ ++ " " ++ parse_url url_

                Movie alt_ url_ _ ->
                    alt_ ++ " " ++ parse_url url_

        Formula _ str ->
            str

        HTML str ->
            str

        EInline _ _ e ->
            List.map parse_inline e
                |> String.concat

        _ ->
            ""


parse_url : Url -> String
parse_url url =
    case url of
        Full str ->
            str

        Partial str ->
            str

        Mail str ->
            str
