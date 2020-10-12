module Lia.Markdown.Effect.JavaScript exposing (..)

import Array exposing (Array)
import Lia.Markdown.HTML.Attributes as Attr exposing (Parameters)
import Port.Eval exposing (Eval)
import Regex


type alias JavaScript =
    { effect_id : Int
    , script : String
    , running : Bool
    , update : Bool
    , runOnce : Bool
    , result : Maybe (Result String String)
    , output : Maybe String
    , input : List String
    , counter : Int
    }


input : Regex.Regex
input =
    Maybe.withDefault Regex.never <|
        Regex.fromString "@input\\(`([^`]+)`\\)"


push : Int -> Parameters -> String -> Array JavaScript -> Array JavaScript
push id params script javascript =
    Array.push
        (JavaScript id
            script
            False
            False
            (Attr.isSet "data-run-once" params)
            (params
                |> Attr.get "data-default"
                |> Maybe.map Ok
            )
            (params
                |> Attr.get "data-output"
            )
            (script
                |> Regex.find input
                |> List.map .submatches
                |> List.concat
                |> List.filterMap identity
            )
            0
        )
        javascript


setRunning : Int -> Bool -> Array JavaScript -> Array JavaScript
setRunning id state javascript =
    set id (\js -> { js | running = state }) javascript


count : Array JavaScript -> Int
count =
    Array.length >> (+) -1


getVisible : Int -> Array JavaScript -> List ( Int, String )
getVisible visble =
    getAll identity
        >> List.filter (Tuple.second >> .effect_id >> (==) visble)
        >> List.map (Tuple.mapSecond .script)


getAll : (JavaScript -> x) -> Array JavaScript -> List ( Int, x )
getAll fn =
    Array.indexedMap
        (\i js ->
            if js.running || (js.runOnce && js.counter == 1) then
                Nothing

            else
                Just ( i, fn js )
        )
        >> Array.toList
        >> List.filterMap identity


get : (JavaScript -> x) -> Int -> Array JavaScript -> Maybe x
get fn id =
    Array.get id >> Maybe.map fn


getResult : Int -> Array JavaScript -> Maybe String
getResult id =
    get .result id
        >> Maybe.withDefault Nothing
        >> Maybe.andThen Result.toMaybe


set : Int -> (JavaScript -> JavaScript) -> Array JavaScript -> Array JavaScript
set idx fn javascript =
    case Array.get idx javascript of
        Just js ->
            Array.set idx (fn js) javascript

        _ ->
            javascript


setEval : Int -> Eval -> Array JavaScript -> Array JavaScript
setEval id =
    eval_ >> set id


eval_ : Eval -> JavaScript -> JavaScript
eval_ e js =
    { js
        | running = e.result == "\"LIA: wait\""
        , counter =
            js.counter
                + (if e.result == "\"LIA: wait\"" then
                    0

                   else
                    1
                  )
        , result =
            if
                e.result
                    == "\"LIA: stop\""
                    || e.result
                    == "\"LIA: wait\""
            then
                js.result

            else if e.ok then
                Just (Ok e.result)

            else
                Just (Err e.result)
    }


setResult : Int -> Array JavaScript -> String -> Array JavaScript
setResult id javascript result =
    set id (\js -> { js | result = Just (Ok result) }) javascript