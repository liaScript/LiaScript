module Lia exposing (Mode, Model, Msg, init, init_presentation, init_slides, init_textbook, load_slide, plain_mode, restore, set_script, slide_mode, subscriptions, switch_mode, update, view)

import Array
import Html exposing (Html)
import Json.Encode as JE
import Lia.Markdown.Inline.Stringify exposing (stringify)
import Lia.Model
import Lia.Parser
import Lia.Types exposing (Section, Sections, init_section)
import Lia.Update exposing (Msg(..))
import Lia.Utils exposing (load, set_title, toUnixNewline)
import Lia.View
import Translations


type alias Model =
    Lia.Model.Model


type alias Msg =
    Lia.Update.Msg


type alias Mode =
    Lia.Types.Mode


load_slide : Model -> Int -> ( Model, Cmd Msg, Maybe ( String, JE.Value ) )
load_slide model idx =
    Lia.Update.update (Load idx) model


set_script : Model -> String -> Model
set_script model script =
    case script |> toUnixNewline |> Lia.Parser.parse_defintion model.url of
        Ok ( code, definition ) ->
            case Lia.Parser.parse_titles definition code of
                Ok title_sections ->
                    let
                        ignore =
                            List.map (load "link") definition.links

                        sections =
                            title_sections
                                |> List.map init_section
                                |> Array.fromList

                        title =
                            sections
                                |> Array.get 0
                                |> Maybe.map (\s -> stringify s.title)
                                |> Maybe.withDefault "Lia Script"
                                |> String.trim
                                |> (++) "Lia: "
                                |> set_title
                    in
                    { model
                        | definition = { definition | scripts = [] }
                        , sections = sections
                        , section_active =
                            if Array.length sections > model.section_active then
                                model.section_active

                            else
                                0
                        , javascript =
                            Lia.Model.load_javascript model.javascript definition.scripts
                        , translation = Translations.getLnFromCode definition.language
                    }

                Err msg ->
                    { model | error = Just msg }

        Err msg ->
            { model | error = Just msg }


init_textbook : String -> String -> String -> Model
init_textbook url readme origin =
    Lia.Model.init Lia.Types.Textbook url readme origin Nothing


init_slides : String -> String -> String -> Maybe Int -> Model
init_slides url readme origin slide_number =
    Lia.Model.init Lia.Types.Slides url readme origin slide_number


init_presentation : String -> String -> String -> Maybe Int -> Model
init_presentation url readme origin slide_number =
    Lia.Model.init Lia.Types.Presentation url readme origin slide_number


view : Model -> Html Msg
view model =
    Lia.View.view model


subscriptions : Model -> Sub Msg
subscriptions model =
    Lia.Update.subscriptions model


update : Msg -> Model -> ( Model, Cmd Msg, Maybe ( String, JE.Value ) )
update =
    Lia.Update.update


init : Model -> ( Model, Cmd Msg, Maybe ( String, JE.Value ) )
init model =
    Lia.Update.update (Load model.section_active) model


switch_mode : Mode -> Model -> Model
switch_mode mode model =
    { model | mode = mode }


plain_mode : Model -> Model
plain_mode =
    switch_mode Lia.Types.Textbook


slide_mode : Model -> Model
slide_mode =
    switch_mode Lia.Types.Slides


restore : Model -> ( String, JE.Value ) -> Model
restore model ( what, json ) =
    model



-- case what of
--     "quiz" ->
--         case Quiz.json2model json of
--             Ok quiz_model ->
--                 { model | quiz_model = quiz_model }
--
--             _ ->
--                 model
--
--     "survey" ->
--         case Survey.json2model json of
--             Ok survey_model ->
--                 { model | survey_model = survey_model }
--
--             _ ->
--                 model
--
--     _ ->
--         model
