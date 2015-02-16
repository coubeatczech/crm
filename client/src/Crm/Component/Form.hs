{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Component.Form where

import "fay-base" Data.Text (fromString, pack, Text)
import "fay-base" Prelude hiding (span, div, elem)
import "fay-base" FFI (Defined(Defined))

import HaskellReact
import qualified HaskellReact.Bootstrap.Button as BTN
import qualified HaskellReact.Tag.Input as I

formRowCol :: (Renderable a)
           => a -- ^ label of the label field
           -> [DOMElement] -- ^ other columns
           -> DOMElement
formRowCol formFieldLabel otherColumns =
  div' (class' "form-group") [ 
    (label' (class'' ["control-label", "col-md-3"]) formFieldLabel) : otherColumns]

formRow :: (Renderable a)
        => a -- ^ label of field
        -> DOMElement -- ^ the other field
        -> DOMElement
formRow formFieldLabel col2 = 
  formRowCol formFieldLabel [div' (class' "col-md-9") col2]

editingCheckbox :: Bool -> (Bool -> Fay ()) -> Bool -> DOMElement
editingCheckbox value setter editing = let
  disabledAttrs = if editing
    then I.mkInputAttrs
    else I.mkInputAttrs { I.disabled_ = Defined "disabled" }
  checkboxAttrs = disabledAttrs { 
    I.type_ = I.checkbox ,
    I.onChange = Defined $ (eventValue >=> (const $ setter $ not value )) }
  inputAttrs = if value
    then checkboxAttrs { I.checked = Defined "checked" }
    else checkboxAttrs
  in I.input mkAttrs inputAttrs

editingInput :: String -> (SyntheticEvent -> Fay ()) -> Bool -> Bool -> DOMElement
editingInput = editingInput' False

editingTextarea :: String -> (SyntheticEvent -> Fay ()) -> Bool -> Bool -> DOMElement
editingTextarea = editingInput' True

editingInput' :: Bool -> String -> (SyntheticEvent -> Fay ()) -> Bool -> Bool -> DOMElement
editingInput' textarea value' onChange' editing' intMode = let
  inputAttrs = let
    commonInputAttrs = if textarea
      then I.mkInputAttrs
      else I.mkInputAttrs {
        I.value_ = Defined $ if intMode && (pack value' == "0")
          then ""
          else pack value' }
    in if editing' 
      then commonInputAttrs {
        I.onChange = Defined onChange' }
      else commonInputAttrs { 
        I.disabled_ = Defined "disabled" }
  in if textarea 
    then I.textarea inputNormalAttrs inputAttrs (pack value')
    else I.input inputNormalAttrs inputAttrs

formRow' :: Text -> String -> (SyntheticEvent -> Fay ()) -> Bool -> Bool -> DOMElement
formRow' labelText value' onChange' editing' intMode = 
  formRow labelText $ editingInput value' onChange' editing' intMode

saveButtonRow :: Renderable a
              => a -- ^ label of the button
              -> Fay () -- ^ button on click handler
              -> DOMElement
saveButtonRow = saveButtonRow' True

saveButtonRow' :: Renderable a
               => Bool
               -> a -- ^ label of the button
               -> Fay () -- ^ button on click handler
               -> DOMElement
saveButtonRow' enabled buttonLabel clickHandler = 
  div' (class'' ["col-md-9", "col-md-offset-3"]) $
    BTN.button' (let
      buttonProps = (BTN.buttonProps {
        BTN.bsStyle = Defined "primary" ,
        BTN.onClick = Defined $ const clickHandler })
      in if enabled then buttonProps else buttonProps {
        BTN.disabled = Defined True })
      buttonLabel

inputNormalAttrs :: Attributes
inputNormalAttrs = class' "form-control"