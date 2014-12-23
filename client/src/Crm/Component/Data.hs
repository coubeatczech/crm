{-# LANGUAGE PackageImports #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Component.Data where

import HaskellReact.BackboneRouter
import "fay-base" Prelude
import qualified Crm.Shared.Machine as M
import qualified Crm.Shared.Company as C
import qualified Crm.Shared.Upkeep as U
import qualified Crm.Shared.UpkeepMachine as UM

data NavigationState =
  FrontPage
  | CompanyDetail {
    companyId :: Int
  , company :: C.Company
  , editing :: Bool
  , companyMachines :: [(Int, M.Machine)] }
  | CompanyNew {
    company :: C.Company }
  | NotFound
  | MachineNew {
    machine :: M.Machine 
  , operationStartCalendarOpen :: Bool }
  | MachineDetail {
    machine :: M.Machine
  , operationStartCalendarOpen :: Bool
  , formState :: Bool
  , machineId :: Int }
  | UpkeepNew {
    upkeep :: U.Upkeep 
  , upkeepMachines :: [(Int, M.Machine)]
  , notCheckedMachines :: [UM.UpkeepMachine] 
  , upkeepDatePickerOpen :: Bool
  , companyId :: Int }
  | UpkeepHistory {
    companyUpkeeps :: [(Int,U.Upkeep)] }
  | PlannedUpkeeps { 
    plennedUpkeeps :: [(U.Upkeep, C.Company)] }

data AppState = AppState {
  navigation :: NavigationState
  , companies :: [(Int, C.Company)]
  , machines :: [(Int, M.Machine)]
  , upkeeps :: [(Int, U.Upkeep)]
}

defaultAppState :: AppState
defaultAppState = AppState {
  navigation = FrontPage
  , companies = []
  , machines = []
  , upkeeps = []
}
