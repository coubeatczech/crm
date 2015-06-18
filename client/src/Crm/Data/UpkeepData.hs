module Crm.Data.UpkeepData where

import           Data.Text (Text)

import           Crm.Shared.Company
import           Crm.Shared.Machine
import           Crm.Shared.MachineType
import           Crm.Shared.UpkeepMachine
import           Crm.Shared.Upkeep
import           Crm.Shared.UpkeepSequence
import           Crm.Shared.Employee

import           Crm.Component.DatePicker

import qualified Crm.Validation           as V
import           Crm.Types                (DisplayedNote)

data UpkeepData = UpkeepData {
  upkeep :: (Upkeep, [UpkeepMachine']) ,
  machines :: [(MachineId, Machine, MachineType, UpkeepSequence)] ,
  notCheckedMachines :: [UpkeepMachine'] ,
  upkeepDatePicker :: (DatePicker, Text) ,
  employees :: [Employee'] ,
  selectedEmployees :: [Maybe EmployeeId] ,
  validation :: V.Validation ,
  upkeepPageMode :: Either UpkeepClose UpkeepNew }

data UpkeepNew = UpkeepNew {
  upkeepIdentification :: Either CompanyId UpkeepId }

data UpkeepClose = UpkeepClose {
  upkeepId :: UpkeepId ,
  companyId :: CompanyId , 
  displayedNote :: DisplayedNote }

