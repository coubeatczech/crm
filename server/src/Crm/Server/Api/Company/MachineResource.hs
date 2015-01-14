module Crm.Server.Api.Company.MachineResource ( 
  machineResource ) where

import Database.PostgreSQL.Simple (Connection)

import Opaleye.PGTypes (pgInt4, pgString)
import Opaleye.Manipulation (runInsert, runInsertReturning)
import Opaleye.PGTypes (pgDay, pgBool)

import Control.Monad.Reader (ask)
import Control.Monad.IO.Class (liftIO)
import Control.Monad (forM_)

import Data.Tuple.All (sel1)

import Rest.Resource (Resource, Void, schema, name, create, mkResourceId )
import qualified Rest.Schema as S
import Rest.Dictionary.Combinators (jsonO, someO, jsonI, someI)
import Rest.Handler (mkInputHandler, Handler)

import qualified Crm.Shared.UpkeepSequence as US
import qualified Crm.Shared.MachineType as MT
import qualified Crm.Shared.Machine as M
import qualified Crm.Shared.Api as A

import Crm.Server.Helpers (maybeId, ymdToDay)
import Crm.Server.Boilerplate ()
import Crm.Server.Types
import Crm.Server.DB

createMachineHandler :: Handler IdDependencies
createMachineHandler = mkInputHandler (jsonO . jsonI . someI . someO) (\(newMachine,machineType) ->
  ask >>= \(connection, maybeInt) -> maybeId maybeInt (\companyId -> 
    liftIO $ addMachine connection newMachine companyId machineType))

addMachine :: Connection
           -> M.Machine
           -> Int
           -> MT.MyEither
           -> IO Int -- ^ id of newly created machine
addMachine connection machine companyId' machineType = do
  machineTypeId <- case machineType of
    MT.MyInt id' -> return $ id'
    MT.MyMachineType (MT.MachineType name' manufacturer, upkeepSequences) -> do
      newMachineTypeId <- runInsertReturning
        connection
        machineTypesTable (Nothing, pgString name', pgString manufacturer)
        sel1
      let machineTypeId = head newMachineTypeId -- todo safe
      forM_ upkeepSequences (\(US.UpkeepSequence displayOrdering label repetition oneTime) -> runInsert
        connection
        upkeepSequencesTable (pgInt4 displayOrdering, pgString label, 
          pgInt4 repetition, pgInt4 machineTypeId, pgBool oneTime))
      return machineTypeId
  let
    M.Machine machineOperationStartDate' initialMileage mileagePerYear = machine
  machineId <- runInsertReturning
    connection
    machinesTable (Nothing, pgInt4 companyId', pgInt4 machineTypeId, pgDay $ ymdToDay machineOperationStartDate',
      pgInt4 initialMileage, pgInt4 mileagePerYear)
    (\(id',_, _, _,_,_) -> id')
  return $ head machineId -- todo safe

machineResource :: Resource IdDependencies IdDependencies Void Void Void
machineResource = mkResourceId {
  name = A.machines ,
  schema = S.noListing $ S.named [] ,
  create = Just createMachineHandler }