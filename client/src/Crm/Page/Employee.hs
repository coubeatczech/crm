{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RebindableSyntax #-}

module Crm.Page.Employee (
  employeeEdit ,
  employeePage ,
  newEmployeeForm ) where

import Data.Text (fromString, Text, length)
import Prelude hiding (div, span, id, length)
import FFI (Defined (Defined))
import Data.Var (Var, modify)

import HaskellReact
import qualified HaskellReact.Bootstrap as B
import qualified HaskellReact.Bootstrap.Button as BTN
import qualified HaskellReact.Bootstrap.Glyphicon as G

import Crm.Server (createEmployee, updateEmployee)
import Crm.Component.Form
import qualified Crm.Data.Data as D
import qualified Crm.Data.EmployeeData as ED
import qualified Crm.Shared.Employee as E
import Crm.Router (CrmRouter, navigate, newEmployee)
import qualified Crm.Router as R
import Crm.Helpers (pageInfo, validationHtml)

employeePage :: CrmRouter
             -> [(E.EmployeeId, E.Employee)] 
             -> DOMElement
employeePage router employees = let 
  rowEmployee (employeeId, employee) = tr [ 
    td $ R.link (E.name employee) (R.editEmployee employeeId) router ,
    td $ E.contact employee ,
    td $ E.capabilities employee ]
  goToAddEmployee = navigate newEmployee router
  addEmployeeButton = BTN.button'
    (BTN.buttonProps {
      BTN.onClick = Defined $ const goToAddEmployee })
    [G.plus, text2DOM " Přidat servismana"]
  head' =
    thead $ tr [
      th $ "Jméno" ,
      th $ "Kontakt" ,
      th $ "Kvalifikace" ]
  body = tbody $ map rowEmployee employees
  in B.grid [
    B.row $ B.col (B.mkColProps 12) $ h2 "Servismani" ,
    B.row $ B.col (B.mkColProps 12) $ addEmployeeButton ,
    B.row $ B.col (B.mkColProps 12) $ B.table [ head' , body ]]

newEmployeeForm :: CrmRouter
                -> E.Employee
                -> Var D.AppState
                -> DOMElement
newEmployeeForm router employee = employeeForm pageInfo' (buttonLabel, buttonAction) employee where
  buttonLabel = "Přidat servismena"
  buttonAction = createEmployee employee $ navigate R.employeePage router
  pageInfo' = pageInfo "Nový servisman" $ Just "Tady můžeš přídat nového servismana, pokud najmete nového zaměstnance, nebo pokud využijete služeb někoho externího."

employeeEdit :: E.EmployeeId
             -> CrmRouter
             -> E.Employee
             -> Var D.AppState
             -> DOMElement
employeeEdit employeeId router employee = employeeForm pageInfo' (buttonLabel, buttonAction) employee where
  buttonLabel = "Edituj"
  buttonAction = updateEmployee employeeId employee $ navigate R.employeePage router
  pageInfo' = pageInfo "Editace servismena" (Nothing :: Maybe DOMElement)

employeeForm :: (Renderable a)
             => a
             -> (Text, Fay ())
             -> E.Employee
             -> Var D.AppState
             -> DOMElement
employeeForm pageInfo' (buttonLabel, buttonAction) employee appVar = let 

  modify' :: E.Employee -> Fay ()
  modify' employee' = modify appVar (\appState -> appState {
    D.navigation = case D.navigation appState of 
      D.EmployeeManage (ED.EmployeeData _ a) -> D.EmployeeManage (ED.EmployeeData employee' a)
      _ -> D.navigation appState })

  validationMessages = if (length $ E.name employee) > 0
    then []
    else ["Jméno musí mít alespoň jeden znak."]
  in form' (mkAttrs { className = Defined "form-horizontal" }) $ 
    (B.grid $ (B.row $ pageInfo') : [
      inputRow
        True 
        "Jméno" 
        (SetValue $ E.name employee) 
        (eventValue >=> (\employeeName -> modify' $ employee { E.name = employeeName })) ,
      inputRow
        True
        "Kontakt"
        (SetValue $ E.contact employee)
        (eventValue >=> (\employeeName -> modify' $ employee { E.contact = employeeName })) ,
      inputRow
        True
        "Kvalifikace"
        (SetValue $ E.capabilities employee)
        (eventValue >=> (\employeeName -> modify' $ employee { E.capabilities = employeeName })) ,
      B.row $ B.col (B.mkColProps 12) $ div' (class' "form-group") $ saveButtonRow'
        (null validationMessages)
        buttonLabel
        buttonAction]) :
    (validationHtml validationMessages) : []
