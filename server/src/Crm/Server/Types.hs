{-# LANGUAGE KindSignatures #-}

module Crm.Server.Types where

import           Data.IORef                 (IORef)
import qualified Data.Map                   as M

import           Control.Monad.Reader       (ReaderT)
import           Database.PostgreSQL.Simple (Connection)

import qualified Crm.Shared.Company         as C
import qualified Crm.Shared.YearMonthDay    as YMD

data MachineTypeMid = Autocomplete String | AutocompleteManufacturer String | CountListing
data MachineTypeSid = MachineTypeByName String | MachineTypeById (Either String Int)

newtype Cache = Cache (IORef (M.Map C.CompanyId (C.Company, Maybe YMD.YearMonthDay, Maybe C.Coordinates)))
type GlobalBindings = (Cache, Connection)

type Dependencies = (ReaderT GlobalBindings IO :: * -> *)
type IdDependencies = (ReaderT (GlobalBindings, Either String Int) IO :: * -> *)
type StringIdDependencies = (ReaderT (GlobalBindings, String) IO :: * -> *)
type MachineTypeDependencies = (ReaderT (GlobalBindings, MachineTypeSid) IO :: * -> *)

type UrlId = Either String Int 

data Direction = Asc | Desc
