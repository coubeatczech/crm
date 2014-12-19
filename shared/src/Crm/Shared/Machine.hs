{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE PackageImports #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Shared.Machine where

import Crm.Shared.MachineType (MachineType, newMachineType)

#ifndef FAY
import GHC.Generics
import "base" Data.Data
import "base" Prelude
#else
import "fay-base" Prelude
#endif

data Machine = Machine {
  machineType :: MachineType ,
  companyId :: Int ,
  machineOperationStartDate :: String ,
  initialMileage :: Int ,
  mileagePerYear :: Int }
#ifndef FAY
  deriving (Generic, Typeable, Data, Show)
#endif

newMachine :: Int -> Machine
newMachine companyId' = Machine {
  machineType = newMachineType ,
  companyId = companyId' ,
  machineOperationStartDate = "" ,
  initialMileage = 0 ,
  mileagePerYear = 365 * 24 }
