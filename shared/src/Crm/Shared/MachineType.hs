{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE PackageImports #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Shared.MachineType where

#ifndef FAY
import GHC.Generics
import "base" Data.Data
import "base" Prelude
import Fay.FFI
#else
import "fay-base" Prelude
import FFI
#endif

import qualified Crm.Shared.UpkeepSequence as US
import qualified Crm.Shared.MachineKind as MK

newtype MachineTypeId = MachineTypeId { getMachineTypeId :: Int }
#ifdef FAY
  deriving Eq
#else
  deriving (Generic, Typeable, Data, Show)
#endif

type MachineType' = (MachineTypeId, MachineType)

-- | Machine type can be either an id or the machine type object
data MachineType = MachineType {
  kind :: Automatic MK.MachineKindEnum ,
  machineTypeName :: String ,
  machineTypeManufacturer :: String }
#ifndef FAY
  deriving (Generic, Typeable, Data, Show)
#endif

newMachineType :: MachineType
newMachineType = MachineType MK.Compressor "" ""

data MyEither = 
  MyMachineType (MachineType, [US.UpkeepSequence])
  | MyInt Int
#ifndef FAY
  deriving (Generic, Typeable, Data, Show)
#endif
