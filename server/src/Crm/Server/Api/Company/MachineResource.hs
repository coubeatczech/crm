module Crm.Server.Api.Company.MachineResource ( 
  machineResource ) where

import Database.PostgreSQL.Simple (Connection)

import Opaleye.PGTypes (pgInt4, pgString)
import Opaleye.Manipulation (runInsert, runInsertReturning)
import Opaleye.PGTypes (pgDay, pgBool)

import Control.Monad.IO.Class (liftIO)
import Control.Monad (forM_)

import Data.Tuple.All (sel1)

import Rest.Resource (Resource, Void, schema, name, create, mkResourceId )
import qualified Rest.Schema as S
import Rest.Dictionary.Combinators (jsonO, jsonI)
import Rest.Handler (mkInputHandler, Handler)

import qualified Crm.Shared.UpkeepSequence as US
import qualified Crm.Shared.MachineType as MT
import qualified Crm.Shared.MachineKind as MK
import qualified Crm.Shared.Machine as M
import qualified Crm.Shared.Compressor as MC
import qualified Crm.Shared.Dryer as MD
import qualified Crm.Shared.Api as A
import Crm.Shared.MyMaybe (toMaybe)

import Crm.Server.Helpers (withConnId, ymdToDay, maybeToNullable)
import Crm.Server.Boilerplate ()
import Crm.Server.Types
import Crm.Server.DB

createMachineHandler :: Handler IdDependencies
createMachineHandler = mkInputHandler (jsonO . jsonI) (\(newMachine, machineType, contactPersonId, machineSpecificData) ->
  withConnId (\connection companyId -> 
    liftIO $ addMachine connection newMachine companyId machineType (toMaybe contactPersonId) machineSpecificData))

addMachine :: Connection
           -> M.Machine
           -> Int
           -> MT.MyEither
           -> Maybe Int
           -> MK.MachineKindData
           -> IO Int -- ^ id of newly created machine
addMachine connection machine companyId' machineType contactPersonId machineSpecificData = do
  machineTypeId <- case machineType of
    MT.MyInt id' -> return $ id'
    MT.MyMachineType (MT.MachineType kind name' manufacturer, upkeepSequences) -> do
      newMachineTypeId <- runInsertReturning
        connection
        machineTypesTable (Nothing, pgInt4 $ MK.kindToDbRepr kind, pgString name', pgString manufacturer)
        sel1
      let machineTypeId = head newMachineTypeId -- todo safe
      forM_ upkeepSequences (\(US.UpkeepSequence displayOrdering label repetition oneTime) -> runInsert
        connection
        upkeepSequencesTable 
        (pgInt4 displayOrdering, pgString label, 
          pgInt4 repetition, pgInt4 machineTypeId, pgBool oneTime))
      return machineTypeId
  let
    M.Machine machineOperationStartDate' initialMileage mileagePerYear note 
      serialNumber yearOfManufacture = machine
  machineIds <- runInsertReturning
    connection
    machinesTable 
    (Nothing, pgInt4 companyId', maybeToNullable $ fmap pgInt4 contactPersonId, 
      pgInt4 machineTypeId, maybeToNullable $ fmap (pgDay . ymdToDay) machineOperationStartDate',
      pgInt4 initialMileage, pgInt4 mileagePerYear, pgString note, 
      pgString serialNumber, pgString yearOfManufacture)
    sel1
  let machineId = head machineIds
  _ <- case machineSpecificData of
    MK.CompressorSpecific compressor -> runInsert
      connection
      compressorsTable
      (pgInt4 machineId, pgString $ MC.note compressor)
    MK.DryerSpecific dryer -> runInsert
      connection
      dryersTable
      (pgInt4 machineId, pgString $ MD.note dryer)
  return machineId -- todo safe

machineResource :: Resource IdDependencies IdDependencies Void Void Void
machineResource = mkResourceId {
  name = A.machines ,
  schema = S.noListing $ S.named [] ,
  create = Just createMachineHandler }
