{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RebindableSyntax #-}

module Crm.Page.Login (
  login ) where

import           Data.Text              (fromString, Text)
import           Prelude                hiding (div, span, id, length)
import           FFI                    (Defined(Defined))
import           Data.Var               (Var, modify)
import           Data.LocalStorage

import           HaskellReact
import qualified HaskellReact.Tag.Input as I
import qualified HaskellReact.Bootstrap as B

import qualified Crm.Data.Data          as D
import           Crm.Component.Form
import           Crm.Router             (CrmRouter, navigate, defaultFrontPage)


login :: Var D.AppState
      -> CrmRouter
      -> Text 
      -> DOMElement
login appVar router password = formWrapper $ B.grid [headerRow, passwordRow, submitRow] where
  modify' f = modify appVar $ \appState -> appState {
    D.navigation = case D.navigation appState of 
      l @ (D.Login _) -> f l
      _ -> D.navigation appState }
  pageHeader = "Přihlášení"
  headerRow = B.row $ B.col (B.mkColProps 12) $ h2 pageHeader
  formWrapper element = div $ form' (mkAttrs { className = Defined "form-horizontal" }) element
  passwordRow = oneElementRow "Heslo" passwordInput where
    passwordInput = textInput I.password Editing True (SetValue password) $ 
      \password' -> modify' $ const $ D.Login password'
  submitRow = buttonRow "Přihlásit se" $ storePassword >> navigate defaultFrontPage router
  storePassword = setLocalStorage "password" password
