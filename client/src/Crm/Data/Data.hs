module Crm.Data.Data where

import Data.Var (Var, modify)
import Data.Text (Text)

import qualified Crm.Shared.Employee as E
import qualified Crm.Shared.Machine as M
import qualified Crm.Shared.MachineType as MT
import qualified Crm.Shared.MachineKind as MK
import qualified Crm.Shared.Company as C
import qualified Crm.Shared.ContactPerson as CP
import qualified Crm.Shared.Upkeep as U
import qualified Crm.Shared.UpkeepMachine as UM
import qualified Crm.Shared.UpkeepSequence as US
import qualified Crm.Shared.YearMonthDay as YMD
import qualified Crm.Shared.Direction as DIR
import qualified Crm.Shared.ExtraField as EF

import Crm.Data.MachineData
import Crm.Data.UpkeepData
import Crm.Data.EmployeeData

data NavigationState =
  Dashboard { companies :: [(C.CompanyId, C.Company, Maybe YMD.YearMonthDay, Maybe C.Coordinates)] } |
  FrontPage {
    ordering :: (C.OrderType, DIR.Direction) ,
    companiesNextService :: [(C.CompanyId, C.Company, Maybe YMD.YearMonthDay)] } | 
  CompanyDetail {
    companyId :: C.CompanyId , 
    company :: C.Company , 
    editing :: Bool , 
    companyMachines :: [(M.MachineId, M.Machine, C.CompanyId, MT.MachineTypeId, 
      MT.MachineType, Maybe CP.ContactPerson, YMD.YearMonthDay)] } | 
  CompanyNew {
    company :: C.Company } | 
  NotFound | 
  MachineScreen MachineData |
  UpkeepScreen UpkeepData |
  UpkeepHistory {
    companyUpkeeps :: [(U.UpkeepId, U.Upkeep, [(UM.UpkeepMachine, MT.MachineType, M.MachineId)],
      Maybe E.Employee')] ,
    companyId :: C.CompanyId } |
  PlannedUpkeeps { 
    plannedUpkeeps :: [(U.UpkeepId,U.Upkeep,C.CompanyId,C.Company)] } |
  MachineTypeList {
    machineTypes :: [(MT.MachineType',Int)] } |
  MachineTypeEdit {
    machineTypeId :: MT.MachineTypeId ,
    machineTypeTuple :: (MT.MachineType, [(US.UpkeepSequence, Text)]) } |
  MachineNewPhase1 {
    maybeMachineTypeId :: Maybe MT.MachineTypeId ,
    machineTypeTuple :: (MT.MachineType, [(US.UpkeepSequence, Text)]) ,
    companyId :: C.CompanyId } |
  EmployeeList {
    employees :: [(E.EmployeeId, E.Employee)] } |
  EmployeeManage EmployeeData |
  ContactPersonPage {
    contactPerson :: CP.ContactPerson ,
    identification :: Maybe CP.ContactPersonId ,
    companyId :: C.CompanyId } |
  ContactPersonList {
    contactPersons :: [CP.ContactPerson'] } |
  ExtraFields {
    editedKind :: MK.MachineKindEnum ,
    allSettings :: [(MK.MachineKindEnum, [(EF.ExtraFieldIdentification, MK.MachineKindSpecific)])] } |
  MachinesSchema {
    machines :: [(M.MachineId, M.Machine, MT.MachineType, Maybe M.MachineId)] }

data AppState = AppState {
  navigation :: NavigationState ,
  machineTypeFromPhase1 :: (MT.MachineType, [US.UpkeepSequence]) ,
  maybeMachineIdFromPhase1 :: Maybe MT.MachineTypeId }

modifyState :: Var AppState -> (NavigationState -> NavigationState) -> Fay ()
modifyState var fun = modify var (\appState' -> appState' { navigation = fun $ navigation appState' } )

defaultAppState :: AppState
defaultAppState = AppState {
  navigation = NotFound ,
  machineTypeFromPhase1 = (MT.newMachineType,[]) ,
  maybeMachineIdFromPhase1 = Nothing }
