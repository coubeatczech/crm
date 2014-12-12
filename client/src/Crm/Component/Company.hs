{-# LANGUAGE PackageImports #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Component.Company (
  companiesList
  , companyDetail
) where

import HaskellReact
import Crm.Component.Navigation (navigation)
import Crm.Shared.Data
import "fay-base" Data.Text (fromString, Text, unpack, pack, append, showInt)
import "fay-base" Prelude hiding (div, span, id)
import Data.Var (Var, subscribeAndRead)
import "fay-base" Data.Maybe (fromMaybe, whenJust, fromJust)
import Data.Defined (fromDefined)
import FFI (Defined(Defined, Undefined))
import HaskellReact.BackboneRouter (BackboneRouter, link)
import qualified HaskellReact.Bootstrap as B
import qualified HaskellReact.Bootstrap.Glyphicon as G
import Crm.Component.Data

companiesList :: MyData
              -> [Company]
              -> DOMElement
companiesList myData companies = let
  head =
    thead $ tr [
      th "Název firmy"
      , th "Platnost servisu vyprší za"
    ]
  body = map (\company ->
    tr [
      td $
        link
          (pack $ companyName company)
          ("/companies/" `append` (showInt $ companyId company))
          (router myData)
      , td $ pack $ companyPlant company
    ]) companies
  in main [
    section $
      B.button [
        G.plus
        , text2DOM "Přidat firmu"
      ]
    , section $
      B.table [
        head : body
      ]
    ]

companyDetail :: MyData
              -> Company
              -> DOMElement
companyDetail myData company =
  main [
    section $
      B.jumbotron [
        h1 $ pack $ companyName company
        , dl [
          dt "Adresa"
          , dd ""
          , dt "Kontakt"
          , dd ""
          , dt "Telefon"
          , dd ""
        ]
      ]
    , section $ B.grid [
      B.row $
        B.col (B.ColProps 12) $
          B.panel $
            span "Historie servisů"
    ]
  ]
