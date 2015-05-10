{-# LANGUAGE PackageImports #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Page.ContactPerson (
  contactPersonsList ,
  contactPersonForm ) where

import "fay-base" Data.Text (fromString, pack)
import "fay-base" Prelude hiding (div)
import "fay-base" Data.Var (Var, modify)
import "fay-base" FFI (Defined (Defined))

import HaskellReact as HR
import qualified HaskellReact.Bootstrap as B

import qualified Crm.Shared.Company as C
import qualified Crm.Shared.ContactPerson as CP

import Crm.Component.Form
import Crm.Helpers (pageInfo, validationHtml)
import Crm.Server (createContactPerson, updateContactPerson)
import qualified Crm.Data.Data as D
import qualified Crm.Router as R

contactPersonsList :: R.CrmRouter
                   -> [(CP.ContactPersonId, CP.ContactPerson)]
                   -> DOMElement
contactPersonsList router contactPersons = let
  displayContactPerson (cpId,contactPerson) = tr [
    td $ R.link (pack $ CP.name contactPerson) (R.contactPersonEdit cpId) router ,
    td $ pack $ CP.phone contactPerson ,
    td $ pack $ CP.position contactPerson ]
  head' = thead $ tr [
    th $ "Jméno" ,
    th $ "Telefon" ,
    th $ "Pozice" ]
  body = tbody $ map displayContactPerson contactPersons
  in B.grid $ B.row [
    B.col (B.mkColProps 12) $ h2 "Kontakní osoby" ,
    B.col (B.mkColProps 12) $ B.table [head', body] ]

contactPersonForm :: R.CrmRouter 
                  -> CP.ContactPerson
                  -> Either C.CompanyId CP.ContactPersonId
                  -> Var D.AppState
                  -> DOMElement
contactPersonForm router contactPerson identification appVar = let

  modify' :: CP.ContactPerson -> Fay ()
  modify' contactPerson' = modify appVar (\appState -> appState {
    D.navigation = case D.navigation appState of 
      D.ContactPersonPage _ identification' -> D.ContactPersonPage contactPerson' identification'
      _ -> D.navigation appState })

  validationMessages = if (length $ CP.name contactPerson) > 0
    then []
    else ["Jméno musí mít alespoň jeden znak."]
  
  (buttonLabel, header, buttonAction) = case identification of
    Left companyId -> ("Vytvoř", "Nová kontaktní osoba", createContactPerson
      companyId
      contactPerson
      (R.navigate (R.companyDetail companyId) router ))
    Right contactPersonId -> ("Edituj", "Kontaktní osoba", updateContactPerson
      contactPersonId
      contactPerson
      (return ()))

  pageInfo' = pageInfo header (Nothing :: Maybe DOMElement)

  in form' (mkAttrs { className = Defined "form-horizontal" }) $ 
    (B.grid $ (B.row $ pageInfo') : [
      row'
        True 
        "Jméno" 
        (SetValue $ CP.name contactPerson)
        (eventString >=> (\t -> modify' $ contactPerson { CP.name = t })) ,
      row'
        True
        "Telefon"
        (SetValue $ CP.phone contactPerson)
        (eventString >=> (\t -> modify' $ contactPerson { CP.phone = t })) ,
      row'
        True
        "Pozice"
        (SetValue $ CP.position contactPerson)
        (eventString >=> (\t -> modify' $ contactPerson { CP.position = t })) ,
      B.row $ B.col (B.mkColProps 12) $ div' (class' "form-group") $ saveButtonRow'
        (null validationMessages)
        buttonLabel
        buttonAction]) :
    (validationHtml validationMessages) : []
