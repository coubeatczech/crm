{-# LANGUAGE PackageImports #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Component.Autocomplete (
  autocompleteInput ) where

import HaskellReact
import JQuery 
import FFI (ffi)
import "fay-base" Data.Text (pack, Text, unpack)
import "fay-base" Prelude

import qualified HaskellReact.Tag.Input as I

import Crm.Server (fetchMachineTypesAutocomplete)

data JQueryUI

data Request

getTerm :: Request -> Text
getTerm = ffi " %1['term'] "

data AutocompleteProps = AutocompleteProps {
  source :: Request -> ([Text] -> Fay ()) -> Fay () }

jQueryUI :: JQueryUI
jQueryUI = ffi " (function () { var $ = require('jquery'); require('jquery-ui'); return $; })() "

jQueryUIAutocomplete :: JQueryUI 
                     -> Text 
                     -> AutocompleteProps 
                     -> Fay ()
jQueryUIAutocomplete = ffi " %1(%2).autocomplete(%3) "

autocompleteInput :: (DOMElement, Fay ())
autocompleteInput = let 
  element = I.input
    mkAttrs
    I.mkInputAttrs
  autocomplete = jQueryUIAutocomplete 
    jQueryUI 
    (pack "input")
    (AutocompleteProps (\request response -> do
      let term = getTerm request
      fetchMachineTypesAutocomplete term response))
  in (element, autocomplete)
