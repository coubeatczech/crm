{-# OPTIONS_GHC -fno-warn-incomplete-patterns #-}

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE CPP #-}

module Crm.Shared.MachineKind where

#ifndef FAY
import GHC.Generics
import Data.Data
#endif
import Data.Text (Text, pack)

machineKinds :: [(MachineKindEnum, Text)]
machineKinds = [
  (RotaryScrewCompressor, pack "Šroubový kompresor") ,
  (CondensationDryer, pack "Sušička") ,
  (VacuumPump, pack "Vývěva") ,
  (PistonCompressor, pack "Pístový kompresor") ,
  (CoolingUnit, pack "Chladicí jednotka") ,
  (NitrogenGenerator, pack "Generátor dusíku") ,
  (AdsorptionDryer, pack "Adsorpční sušička") ]

data MachineKindEnum = 
  RotaryScrewCompressor | 
  CondensationDryer | 
  VacuumPump | 
  PistonCompressor | 
  CoolingUnit |
  NitrogenGenerator | 
  AdsorptionDryer
#ifdef FAY
  deriving (Eq)
#else
  deriving (Generic, Typeable, Data, Show, Eq)
#endif

kindToDbRepr :: MachineKindEnum -> Int
kindToDbRepr kind = kindToDbRepr' kind (map fst machineKinds)

kindToDbRepr' :: MachineKindEnum -> [MachineKindEnum] -> Int
kindToDbRepr' x' (x:_) | x == x' = 0
kindToDbRepr' x' (_:xs) = 1 + kindToDbRepr' x' xs

dbReprToKind :: Int -> MachineKindEnum
dbReprToKind int = fst $ machineKinds !! int

data MachineKindSpecific = MachineKindSpecific {
  name :: Text }
#ifdef FAY
  deriving (Eq)
#else
  deriving (Generic, Typeable, Data)
#endif

newMachineKindSpecific :: MachineKindSpecific
newMachineKindSpecific = MachineKindSpecific (pack "")
