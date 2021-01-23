module Widget.Layout exposing
    ( Layout, Part(..), init, timePassed, view
    , activate, queueMessage
    )

{-| Combines multiple concepts from the [material design specification](https://material.io/components/), namely:

  - Top App Bar
  - Navigation Draw
  - Side Panel
  - Dialog
  - Snackbar

It is responsive and changes view to apply to the [material design guidelines](https://material.io/components/app-bars-top).


# Basics

@docs Layout, Part, init, timePassed, view


# Actions

@docs activate, queueMessage

-}

import Array
import Element exposing (Attribute, DeviceClass(..), Element)
import Element.Input as Input
import Html exposing (Html)
import Widget exposing (Button, Select, TextInput)
import Widget.Snackbar as Snackbar exposing (Message)
import Widget.Style exposing (LayoutStyle)
import Widget.Style.Customize as Customize


{-| The currently visible part: either the left sheet, right sheet or the search bar
-}
type Part
    = LeftSheet
    | RightSheet
    | Search


{-| The model of the layout containing the snackbar and the currently active side sheet (or search bar)
-}
type alias Layout msg =
    { snackbar : Snackbar.Snackbar (Message msg)
    , active : Maybe Part
    }


{-| The initial state of the layout
-}
init : Layout msg
init =
    { snackbar = Snackbar.init
    , active = Nothing
    }


{-| Queues a message and displayes it as a snackbar once no other snackbar is visible.
-}
queueMessage : Message msg -> Layout msg -> Layout msg
queueMessage message layout =
    { layout
        | snackbar = layout.snackbar |> Snackbar.insert message
    }


{-| Open either a side sheet or the search bar.
-}
activate : Maybe Part -> Layout msg -> Layout msg
activate part layout =
    { layout
        | active = part
    }


{-| Update the model, put this function into your subscription.
The first argument is the seconds that have passed sice the function was called last.
-}
timePassed : Int -> Layout msg -> Layout msg
timePassed sec layout =
    case layout.active of
        Just LeftSheet ->
            layout

        Just RightSheet ->
            layout

        _ ->
            { layout
                | snackbar = layout.snackbar |> Snackbar.timePassed sec
            }



--------------------------------------------------------------------------------
-- View
--------------------------------------------------------------------------------


getDeviceClass : { height : Int, width : Int } -> DeviceClass
getDeviceClass window =
    window
        |> Element.classifyDevice
        |> .class


partitionActions : List (Button msg) -> { primaryActions : List (Button msg), moreActions : List (Button msg) }
partitionActions actions =
    { primaryActions =
        if (actions |> List.length) > 4 then
            actions |> List.take 2

        else if (actions |> List.length) == 4 then
            actions |> List.take 1

        else if (actions |> List.length) == 3 then
            []

        else
            actions |> List.take 2
    , moreActions =
        if (actions |> List.length) > 4 then
            actions |> List.drop 2

        else if (actions |> List.length) == 4 then
            actions |> List.drop 1

        else if (actions |> List.length) == 3 then
            actions

        else
            actions |> List.drop 2
    }


viewNav :
    LayoutStyle msg
    ->
        { title : Element msg
        , menu : Select msg
        , deviceClass : DeviceClass
        , onChangedSidebar : Maybe Part -> msg
        , primaryActions : List (Button msg)
        , moreActions : List (Button msg)
        , search : Maybe (TextInput msg)
        }
    -> Element msg
viewNav style { title, menu, deviceClass, onChangedSidebar, primaryActions, moreActions, search } =
    [ (if
        (deviceClass == Phone)
            || (deviceClass == Tablet)
            || ((menu.options |> List.length) > 5)
       then
        [ Widget.iconButton style.menuButton
            { onPress = Just <| onChangedSidebar <| Just LeftSheet
            , icon = style.menuIcon
            , text = "Menu"
            }
        , menu.selected
            |> Maybe.andThen
                (\option ->
                    menu.options
                        |> Array.fromList
                        |> Array.get option
                )
            |> Maybe.map (.text >> Element.text)
            |> Maybe.withDefault title
            |> Element.el style.title
        ]

       else
        [ title |> Element.el style.title
        , menu
            |> Widget.select
            |> List.map (Widget.selectButton style.menuTabButton)
            |> Element.row
                [ Element.width <| Element.shrink
                ]
        ]
      )
        |> Element.row
            [ Element.width <| Element.shrink
            , Element.spacing style.spacing
            ]
    , if deviceClass == Phone || deviceClass == Tablet then
        Element.none

      else
        search
            |> Maybe.map
                (\{ onChange, text, label } ->
                    Widget.textInput style.search
                        { chips = []
                        , onChange = onChange
                        , text = text
                        , placeholder =
                            Just <|
                                Input.placeholder [] <|
                                    Element.text label
                        , label = label
                        }
                )
            |> Maybe.withDefault Element.none
    , [ search
            |> Maybe.map
                (\{ label } ->
                    if deviceClass == Tablet then
                        [ Widget.button style.menuButton
                            { onPress = Just <| onChangedSidebar <| Just Search
                            , icon = style.searchIcon
                            , text = label
                            }
                        ]

                    else if deviceClass == Phone then
                        [ Widget.iconButton style.menuButton
                            { onPress = Just <| onChangedSidebar <| Just Search
                            , icon = style.searchIcon
                            , text = label
                            }
                        ]

                    else
                        []
                )
            |> Maybe.withDefault []
      , primaryActions
            |> List.map
                (if deviceClass == Phone then
                    Widget.iconButton style.menuButton

                 else
                    Widget.button style.menuButton
                )
      , if moreActions |> List.isEmpty then
            []

        else
            [ Widget.iconButton style.menuButton
                { onPress = Just <| onChangedSidebar <| Just RightSheet
                , icon = style.moreVerticalIcon
                , text = "More"
                }
            ]
      ]
        |> List.concat
        |> Element.row
            [ Element.width <| Element.shrink
            , Element.alignRight
            ]
    ]
        |> Element.row
            (style.header
                ++ [ Element.padding 0
                   , Element.centerX
                   , Element.spacing style.spacing
                   , Element.alignTop
                   , Element.width <| Element.fill
                   ]
            )


{-| left sheet.
-}
viewLeftSheet :
    LayoutStyle msg
    ->
        { title : Element msg
        , menu : Select msg
        }
    -> Element msg
viewLeftSheet style { title, menu } =
    [ [ title
      ]
    , menu
        |> Widget.select
        |> List.map
            (Widget.selectButton style.sheetButton)
    ]
        |> List.concat
        |> Element.column [ Element.width <| Element.fill ]
        |> Element.el
            (style.sheet
                ++ [ Element.height <| Element.fill
                   , Element.alignLeft
                   ]
            )


{-| View the layout.
-}
view :
    LayoutStyle msg
    ->
        { window : { height : Int, width : Int }
        , dialog : Maybe (List (Attribute msg))
        , layout : Layout msg
        , title : Element msg
        , menu : Select msg
        , search : Maybe (TextInput msg)
        , actions : List (Button msg)
        , onChangedSidebar : Maybe Part -> msg
        }
    -> Element msg
    -> Html msg
view style { search, title, onChangedSidebar, menu, actions, window, dialog, layout } content =
    let
        deviceClass : DeviceClass
        deviceClass =
            getDeviceClass window

        { primaryActions, moreActions } =
            partitionActions actions

        nav : Element msg
        nav =
            viewNav style
                { title = title
                , menu = menu
                , deviceClass = deviceClass
                , onChangedSidebar = onChangedSidebar
                , primaryActions = primaryActions
                , moreActions = moreActions
                , search = search
                }

        snackbar : Element msg
        snackbar =
            layout.snackbar
                |> Snackbar.view style.snackbar identity
                |> Maybe.map
                    (Element.el
                        [ Element.padding style.spacing
                        , Element.alignBottom
                        , Element.alignRight
                        ]
                    )
                |> Maybe.withDefault Element.none

        sheet =
            case layout.active of
                Just LeftSheet ->
                    viewLeftSheet style
                        { title = title
                        , menu = menu
                        }

                Just RightSheet ->
                    Widget.buttonSheet
                        { element = style.sheet ++ [ Element.alignRight ]
                        , content =
                            { elementColumn = []
                            , content = style.sheetButton
                            }
                        }
                        moreActions

                Just Search ->
                    search
                        |> Maybe.map
                            (Widget.textInput
                                (style.searchFill
                                    |> Customize.mapContent
                                        (\record ->
                                            { record
                                                | text =
                                                    record.text
                                                        |> Customize.elementTextInput
                                                            [ Element.width <| Element.fill ]
                                            }
                                        )
                                )
                                >> Element.el
                                    [ Element.alignTop
                                    , Element.width <| Element.fill
                                    ]
                            )
                        |> Maybe.withDefault Element.none

                Nothing ->
                    Element.none
    in
    content
        |> style.layout
            (List.concat
                [ style.container
                , [ Element.inFront nav
                  , Element.inFront snackbar
                  ]
                , if (layout.active /= Nothing) || (dialog /= Nothing) then
                    --(Element.height <| Element.px <| window.height)
                    --    ::
                    case dialog of
                        Just dialogConfig ->
                            dialogConfig

                        Nothing ->
                            Widget.modal
                                { onDismiss =
                                    Nothing
                                        |> onChangedSidebar
                                        |> Just
                                , content = sheet
                                }

                  else
                    []
                ]
            )
