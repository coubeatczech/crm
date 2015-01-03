{-# LANGUAGE PackageImports #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Router (
  startRouter ,
  navigate ,
  link ,
  CrmRouter ,
  CrmRoute ,
  frontPage ,
  newCompany ,
  companyDetail ,
  newMachine ,
  newMaintenance ,
  closeUpkeep ,
  maintenances ,
  plannedUpkeeps ,
  machineDetail ) where

import "fay-base" Data.Text (fromString, showInt, Text, (<>))
import "fay-base" Prelude hiding (div, span, id)
import "fay-base" FFI (Automatic)
import Data.Var (Var, modify)
import "fay-base" Data.Function (fmap)

import qualified HaskellReact.BackboneRouter as BR
import HaskellReact
import Moment (now, requireMoment, day)

import Crm.Server (fetchMachine, fetchPlannedUpkeeps, fetchFrontPageData, fetchCompany, fetchUpkeeps, fetchUpkeep)
import Crm.Helpers (parseSafely, showCompanyId)
import qualified Crm.Shared.Machine as M
import qualified Crm.Shared.MachineType as MT
import qualified Crm.Shared.UpkeepMachine as UM
import qualified Crm.Shared.Upkeep as U
import qualified Crm.Shared.Company as C
import qualified Crm.Shared.YearMonthDay as YMD
import qualified Crm.Data as D

newtype CrmRouter = CrmRouter BR.BackboneRouter
newtype CrmRoute = CrmRoute Text

frontPage :: CrmRoute
frontPage = CrmRoute ""

newCompany :: CrmRoute
newCompany = CrmRoute "companies/new"

companyDetail :: C.CompanyId -> CrmRoute
companyDetail companyId = CrmRoute $ "companies/" <> showCompanyId companyId

newMachine :: C.CompanyId -> CrmRoute
newMachine companyId = CrmRoute $ "companies/" <> showCompanyId companyId <> "/new-machine"

newMaintenance :: C.CompanyId -> CrmRoute
newMaintenance companyId = CrmRoute $ "companies/" <> showCompanyId companyId <> "/new-maintenance"

maintenances :: C.CompanyId -> CrmRoute
maintenances companyId = CrmRoute $ "companies/" <> showCompanyId companyId <> "/maintenances"

machineDetail :: M.MachineId -> CrmRoute
machineDetail machineId = CrmRoute $ "machines/" <> (showInt $ M.getMachineId machineId)

plannedUpkeeps :: CrmRoute
plannedUpkeeps = CrmRoute $ "planned"

closeUpkeep :: U.UpkeepId -> CrmRoute
closeUpkeep upkeepId = CrmRoute $ "upkeeps/" <> (showInt $ U.getUpkeepId upkeepId)

startRouter :: Var D.AppState -> Fay CrmRouter
startRouter appVar = let
  modify' newState = modify appVar (\appState -> appState { D.navigation = newState })
  withCompany :: [Text]
              -> (C.CompanyId -> (C.Company, [(M.MachineId, M.Machine,
                   C.CompanyId, MT.MachineTypeId, MT.MachineType)]) 
                 -> D.NavigationState)
              -> Fay ()
  withCompany params newStateFun = case parseSafely $ head params of
    Just(companyId') ->
      fetchCompany companyId (\data' -> let
        newState = newStateFun companyId data'
        in modify' newState )
      where
        companyId = C.CompanyId companyId'
    _ -> modify' D.NotFound 
  
  in fmap CrmRouter $ BR.startRouter [(
  "", const $ fetchFrontPageData (\data' ->
    modify appVar (\appState -> appState { D.navigation = D.FrontPage data' }))
  ),(
    "companies/:id", \params -> let
      cId = head params
      in case (parseSafely cId, cId) of
        (Just(cId''), _) -> let
          companyId = C.CompanyId cId''
          in fetchCompany companyId (\(company,machines) -> 
            modify appVar (\appState -> appState {
              D.navigation = D.CompanyDetail companyId company False machines }))
        (_, new) | new == "new" -> modify appVar (\appState ->
          appState {
            D.navigation = D.CompanyNew C.newCompany }
          )
        _ -> return ()
  ),(
    "companies/:id/new-machine", \params ->
      withCompany
        params
        (\companyId (_,_) -> let
          in D.MachineNew M.newMachine companyId MT.newMachineType Nothing False)
  ),(
    "companies/:id/new-maintenance", \params ->
      withCompany
        params
        (\companyId (_, machines) -> let
          notCheckedUpkeepMachines = map (\(machineId,_,_,_,_) -> UM.newUpkeepMachine $ M.getMachineId machineId) machines
          (nowYear, nowMonth, nowDay) = day $ now requireMoment
          nowYMD = YMD.YearMonthDay nowYear nowMonth nowDay YMD.DayPrecision
          in D.UpkeepNew (U.newUpkeep nowYMD) machines notCheckedUpkeepMachines False companyId)
  ),(
    "companies/:id/maintenances", \params ->
      case (parseSafely $ head params) of
        Just(companyId) -> 
          fetchUpkeeps (C.CompanyId companyId) (\upkeeps -> let
            ns = D.UpkeepHistory upkeeps 
            in modify' ns)
        _ -> modify' D.NotFound
  ),(
    "machines/:id", \params -> let
      maybeId = parseSafely $ head params
      in case maybeId of
        Just(machineId') -> fetchMachine machineId
          (\(machine, machineTypeId, _, machineType, machineNextService) ->
            modify' $ D.MachineDetail machine machineType machineTypeId 
              False False machineId machineNextService)
          where 
            machineId = M.MachineId machineId'
        _ -> modify' D.NotFound
  ),(
    "planned", const $
      fetchPlannedUpkeeps (\plannedUpkeeps' -> let
        newNavigation = D.PlannedUpkeeps plannedUpkeeps'
        in modify appVar (\appState -> 
          appState { D.navigation = newNavigation })) 
  ),(
    "upkeeps/:id", \params -> let
      maybeId = parseSafely $ head params
      in case maybeId of
        Just(upkeepId') -> fetchUpkeep upkeepId (\(companyId,upkeep,machines) -> let
          upkeepMachines = U.upkeepMachines upkeep
          addNotCheckedMachine acc element = let 
            (machineId,_,_,_,_) = element
            machineId'' = M.getMachineId machineId
            machineChecked = find (\(UM.UpkeepMachine _ machineId' _) -> 
              machineId'' == machineId') upkeepMachines
            in case machineChecked of
              Nothing -> UM.newUpkeepMachine machineId'' : acc
              _ -> acc
          notCheckedMachines = foldl addNotCheckedMachine [] machines
          upkeep' = upkeep { U.upkeepClosed = True }
          in modify' $ D.UpkeepClose upkeep' machines notCheckedMachines False upkeepId companyId)
          where
            upkeepId = U.UpkeepId upkeepId'
        _ -> modify' D.NotFound )]

navigate :: CrmRoute
         -> CrmRouter
         -> Fay ()
navigate (CrmRoute route) (CrmRouter router) = BR.navigate route router

link :: Renderable a
     => Automatic a
     -> CrmRoute
     -> CrmRouter
     -> DOMElement
link children (CrmRoute route) (CrmRouter router) = 
  BR.link children route router
