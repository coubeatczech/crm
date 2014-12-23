{-# LANGUAGE PackageImports #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Component.Upkeep (
  upkeepNew ,
  plannedUpkeeps ) where

import "fay-base" Data.Text (fromString, unpack, pack, append, showInt, (<>))
import "fay-base" Prelude hiding (div, span, id)
import Data.Var (Var, modify)
import FFI (Defined(Defined))

import HaskellReact as HR
import qualified HaskellReact.Bootstrap as B
import qualified HaskellReact.Bootstrap.Input as I
import qualified HaskellReact.Bootstrap.Button as BTN
import qualified HaskellReact.Bootstrap.Glyphicon as G
import qualified HaskellReact.Tag.Input as II
import qualified HaskellReact.Tag.Hyperlink as A
import qualified HaskellReact.Bootstrap.CalendarInput as CI

import qualified Crm.Shared.Company as C
import qualified Crm.Shared.Machine as M
import qualified Crm.Shared.MachineType as MT
import qualified Crm.Shared.Upkeep as U
import qualified Crm.Shared.YearMonthDay as YMD
import qualified Crm.Shared.UpkeepMachine as UM
import Crm.Component.Data
import Crm.Component.Editable (editable)
import Crm.Server (createMachine, createUpkeep)
import Crm.Router (CrmRouter, link, companyDetail)
import Crm.Helpers (displayDate)

import Debug.Trace

plannedUpkeeps :: CrmRouter
               -> [(Int, U.Upkeep, Int, C.Company)]
               -> DOMElement
plannedUpkeeps router upkeepCompanies = let
  head = thead $ tr [
    th "Název firmy" ,
    th "Datum" ]
  body = tbody $ map (\(upkeepId, upkeep, companyId, company) ->
    tr [
      td $ link
        (pack $ C.companyName company)
        (companyDetail companyId)
        router ,
      td $ displayDate $ U.upkeepDate upkeep ]) upkeepCompanies
  in trace (show upkeepCompanies) $ main $ B.table [ head , body ]

swap :: (a, b) -> (b, a)
swap (x, y) = (y, x)

{- | if the element is in the first list, put it in the other one, if the element
 - is in the other, put in the first list
 -}
toggle :: ([a],[a]) -> (a -> Bool) -> ([a],[a])
toggle lists findElem = let
  toggleInternal (list1, list2) runMore = let
    foundInFirstList = find findElem list1
    in case foundInFirstList of
      Just(elem) -> let
        filteredList1 = filter (not . findElem) list1
        addedToList2 = elem : list2
        result = (filteredList1, addedToList2)
        in if runMore then result else swap result
      _ -> if runMore
        then toggleInternal (list2, list1) False
        else lists
  in toggleInternal lists True

upkeepNew :: CrmRouter
          -> Var AppState
          -> U.Upkeep
          -> Bool
          -> [UM.UpkeepMachine]
          -> [(Int, M.Machine)] -- ^ machine ids -> machines
          -> Int -- ^ company id
          -> DOMElement
upkeepNew router appState upkeep' upkeepDatePickerOpen' notCheckedMachines'' machines companyId' = let
  setUpkeep :: U.Upkeep -> Maybe [UM.UpkeepMachine] -> Fay()
  setUpkeep upkeep' notCheckedMachines' = modify appState (\appState' -> case navigation appState' of
    upkeepNew @ (UpkeepNew _ _ _ _ _) -> let
      newNavigation = upkeepNew { upkeep = upkeep' }
      newNavigation' = case notCheckedMachines' of
        Just(x) -> newNavigation { notCheckedMachines = x }
        _ -> newNavigation
      in appState' { navigation = newNavigation' } )
  machineRow (machineId, machine) = let
    upkeepMachines = U.upkeepMachines upkeep'
    thisUpkeepMachine = find (\(UM.UpkeepMachine _ id') -> machineId == id') upkeepMachines
    thatUpkeepMachine = find (\(UM.UpkeepMachine _ id') -> machineId == id') notCheckedMachines''
    checkedMachineIds = map (UM.upkeepMachineMachineId) upkeepMachines
    rowProps = if elem machineId checkedMachineIds
      then class' "bg-success"
      else mkAttrs
    in B.row' rowProps [
      let
        content = span $ pack $ (MT.machineTypeName . M.machineType) machine
        clickHandler = let
          (newCheckedMachines, newNotCheckedMachines) = toggle (
            U.upkeepMachines upkeep' ,
            notCheckedMachines'' )
            (\(UM.UpkeepMachine _ machineId') -> machineId' == machineId)
          newUpkeep = upkeep' { U.upkeepMachines = newCheckedMachines }
          in setUpkeep newUpkeep $ Just newNotCheckedMachines
        link = A.a''
          (mkAttrs{onClick = Defined $ const clickHandler})
          (A.mkAAttrs)
          content
        in B.col (B.mkColProps 6) link ,
      let
        inputProps = case (thisUpkeepMachine, thatUpkeepMachine) of
          (Just(upkeepMachine),_) -> I.mkInputProps {
            I.onChange = Defined $ \event -> do
              value <- eventValue event
              let newUpkeepMachine = upkeepMachine { UM.upkeepMachineNote = unpack value }
              let newUpkeepMachines = map (\um @ (UM.UpkeepMachine _ machineId') ->
                    if machineId' == machineId
                      then newUpkeepMachine
                      else um) upkeepMachines
              let newUpkeep = upkeep' { U.upkeepMachines = newUpkeepMachines }
              setUpkeep newUpkeep Nothing ,
            I.defaultValue = Defined $ pack $ UM.upkeepMachineNote upkeepMachine }
          (_,Just(upkeepMachine)) -> I.mkInputProps {
            I.defaultValue = Defined $ pack $ UM.upkeepMachineNote upkeepMachine ,
            I.disabled = Defined True }
          _ -> I.mkInputProps { -- this shouldn't happen, really
            I.disabled = Defined True }
        in B.col (B.mkColProps 6) $ I.textarea inputProps ]
  submitButton = let
    newUpkeepHandler = createUpkeep
      upkeep'
      companyId'
      (const $ return ())
    buttonProps = BTN.buttonProps {
      BTN.bsStyle = Defined "primary" ,
      BTN.onClick = Defined $ const newUpkeepHandler }
    button = BTN.button' buttonProps [ G.plus , text2DOM " Naplánovat" ]
    in B.col ((B.mkColProps 6){ B.mdOffset = Defined 6 }) button
  dateRow = B.row [
    B.col (B.mkColProps 6) "Datum" ,
    B.col (B.mkColProps 6) $ let
      YMD.YearMonthDay y m d _ = U.upkeepDate upkeep'
      dayPickHandler year month day precision = case precision of
        month | month == "Month" -> setDate YMD.MonthPrecision
        year | year == "Year" -> setDate YMD.YearPrecision
        day | day == "Day" -> setDate YMD.DayPrecision
        _ -> return ()
        where 
          setDate precision = setUpkeep (upkeep' {
            U.upkeepDate = YMD.YearMonthDay year month day precision }) Nothing
      setPickerOpenness open = modify appState (\appState' -> appState' {
        navigation = case navigation appState' of
          upkeep'' @ (UpkeepNew _ _ _ _ _) -> upkeep'' { upkeepDatePickerOpen = open }
          _ -> navigation appState' })
      in CI.dayInput True y m d dayPickHandler upkeepDatePickerOpen' setPickerOpenness ]
  in div $
    B.grid $
      map machineRow machines ++ [dateRow, submitButton]
