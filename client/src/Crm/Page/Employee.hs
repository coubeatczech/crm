{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RebindableSyntax #-}

module Crm.Page.Employee (
  employeeEdit ,
  employeePage ,
  employeeTasks ,
  newEmployeeForm ) where

import           Data.Text                        (fromString, Text, length, (<>), unpack)
import           Prelude                          hiding (div, span, id, length)
import qualified Prelude                          as P
import           FFI                              (Defined (Defined))
import           Data.Var                         (Var, modify)

import           HaskellReact
import qualified HaskellReact.Bootstrap           as B
import qualified HaskellReact.Bootstrap.Button    as BTN
import qualified HaskellReact.Bootstrap.Glyphicon as G

import           Crm.Server                       (createEmployee, updateEmployee)
import           Crm.Component.Form
import qualified Crm.Data.Data                    as D
import qualified Crm.Data.EmployeeData            as ED
import           Crm.Router                       (CrmRouter, navigate, newEmployee)
import qualified Crm.Router                       as R
import           Crm.Helpers                      (pageInfo, validationHtml)

import qualified Crm.Shared.Employee              as E
import qualified Crm.Shared.EmployeeTask          as ET


employeePage :: CrmRouter
             -> [(E.EmployeeId, E.Employee)]
             -> DOMElement
employeePage router employees = mkGrid where

  mkEmployeeRow (employeeId, employee) = let
    in tr [ 
      td $ R.link (E.name employee) (R.editEmployee employeeId) router ,
      td $ E.contact employee ,
      td $ E.capabilities employee ,
      td $ R.link "Činnosti" (R.employeeTasks employeeId) router ]

  addEmployeeButton = BTN.button'
    (BTN.buttonProps {
      BTN.onClick = Defined $ const goToAddEmployee })
    [G.plus, text2DOM " Přidat servismana"]
    where
    goToAddEmployee = navigate newEmployee router

  mkGrid = B.grid [
    B.row $ B.col (B.mkColProps 12) $ h2 "Servismani" ,
    B.row $ B.col (B.mkColProps 12) $ addEmployeeButton ,
    B.row $ B.col (B.mkColProps 12) $ B.table [ head' , body ]]
    where
    head' =
      thead $ tr [
        th "Jméno" ,
        th "Kontakt" ,
        th "Kvalifikace" ,
        th "Činnosti" ]
    body = tbody $ map mkEmployeeRow employees


newEmployeeForm :: CrmRouter
                -> E.Employee
                -> Var D.AppState
                -> DOMElement
newEmployeeForm router employee = employeeForm pageInfo' (buttonLabel, buttonAction) employee where
  buttonLabel = "Přidat servismena"
  buttonAction = createEmployee employee (navigate R.employeePage router) router
  pageInfo' = pageInfo "Nový servisman" $ Just "Tady můžeš přídat nového servismana, pokud najmete nového zaměstnance, nebo pokud využijete služeb někoho externího."


employeeEdit :: E.EmployeeId
             -> CrmRouter
             -> E.Employee
             -> Var D.AppState
             -> DOMElement
employeeEdit employeeId router employee = employeeForm pageInfo' (buttonLabel, buttonAction) employee where
  buttonLabel = "Ulož"
  buttonAction = updateEmployee employeeId employee (navigate R.employeePage router) router
  pageInfo' = pageInfo "Editace servismena" (Nothing :: Maybe DOMElement)

employeeForm :: (Renderable a)
             => a
             -> (Text, Fay ())
             -> E.Employee
             -> Var D.AppState
             -> DOMElement
employeeForm pageInfo' (buttonLabel, buttonAction) employee appVar = mkForm where

  modify' :: E.Employee -> Fay ()
  modify' employee' = modify appVar (\appState -> appState {
    D.navigation = case D.navigation appState of 
      D.EmployeeManage (ED.EmployeeData _ a) -> D.EmployeeManage (ED.EmployeeData employee' a)
      _ -> D.navigation appState })

  validationMessages = if (length $ E.name employee) > 0
    then []
    else ["Jméno musí mít alespoň jeden znak."]

  mkForm = form' (mkAttrs { className = Defined "form-horizontal" }) $ 
    (B.grid $ (B.row $ pageInfo') : [
      inputRowEditing
        "Jméno" 
        (SetValue $ E.name employee) $ 
        \employeeName -> modify' $ employee { E.name = employeeName } ,
      inputRowEditing
        "Kontakt"
        (SetValue $ E.contact employee) $ 
        \employeeName -> modify' $ employee { E.contact = employeeName } ,
      inputRowEditing
        "Kvalifikace"
        (SetValue $ E.capabilities employee) $ 
        \employeeName -> modify' $ employee { E.capabilities = employeeName } ,
      nullDropdownRow
        Editing
        "Barva"
        colours
        renderColour
        employeeColour
        setEmployeeColour ,
      B.row $ B.col (B.mkColProps 12) $ div' (class' "form-group") $ buttonRow'
        (buttonStateFromBool . null $ validationMessages)
        buttonLabel
        buttonAction]) :
    (validationHtml validationMessages) : []
    where
    setEmployeeColour (Just colour) = modify' $ employee { E.colour = colour }
    setEmployeeColour Nothing       = modify' $ employee { E.colour = "000000" }
    employeeColour = case E.colour employee of
      colour | all ('0' ==) (unpack colour) -> Nothing
      colour                                -> Just colour
    renderColour (colour, label) =
      span' colourStyle $ "• " <> label
      where
      colourStyle = mkAttrs {
        style = Defined style' }
      style' = Style $ "#" <> colour
    colours = colours' `zip` coloursLabels
      where
      colours' = ["e46688", "f07f23", "73c597", "f9bb33", "f4dece", "8f624a", "3894d8", "54c1cd", "a8a4d4", "bfc0ba"]
      labels = ["Zimolez", "Korál", "Hrachový lusk", "Včelí vosk", "Stříbrná pivoňka", "Rezavá červeň", "Regata", "Modré curacao", "Levandule", "Stříbrný oblak"]
      coloursLabels = colours' `zip` labels
    inputRowEditing = inputRow Editing


employeeTasks :: 
  E.EmployeeId -> 
  E.Employee ->
  [ET.EmployeeTask] ->
  DOMElement
employeeTasks = undefined
