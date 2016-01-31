{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Crm.Server.Api.Company.MachineResource ( 
  machineResource ) where

import           Control.Monad               (forM_)

import           Control.Monad.IO.Class      (liftIO)
import           Control.Monad.Trans.Except  (ExceptT)
import           Control.Monad.Reader        (ask)
import           Data.Tuple.All              (sel1)
import           Data.Text                   (Text)
import           Data.Pool                   (withResource)
import           Database.PostgreSQL.Simple  (Connection)
import           Opaleye.PGTypes             (pgInt4, pgStrictText, pgDay, pgBool)
import           Opaleye.Manipulation        (runInsert, runInsertReturning)
import           Opaleye                     (runQuery)
import           Rest.Resource               (Resource, Void, schema, name, 
                                             create, mkResourceId, list)
import qualified Rest.Schema                 as S
import           Rest.Dictionary.Combinators (jsonO, jsonI)
import           Rest.Handler                (Handler, ListHandler)
import           Rest.Types.Error            (Reason)

import qualified Crm.Shared.UpkeepSequence   as US
import qualified Crm.Shared.MachineType      as MT
import qualified Crm.Shared.MachineKind      as MK
import qualified Crm.Shared.Machine          as M
import qualified Crm.Shared.ContactPerson    as CP
import qualified Crm.Shared.Company          as C
import qualified Crm.Shared.ExtraField       as EF
import qualified Crm.Shared.Api              as A
import qualified Crm.Shared.YearMonthDay     as YMD
import           Crm.Shared.MyMaybe          (toMaybe)

import           Crm.Server.Helpers          (maybeToNullable)
import           Crm.Server.Boilerplate      ()
import           Crm.Server.Types
import           Crm.Server.DB
import           Crm.Server.Handler          (mkInputHandler', mkListing')
import           Crm.Server.CachedCore       (recomputeSingle)

import           TupleTH                     (proj)


createMachineHandler :: Handler (IdDependencies' C.CompanyId)
createMachineHandler = mkInputHandler' (jsonO . jsonI) $
    \(newMachine, machineType, contactPersonIdentification', linkedMachineId, machineSpecificData) -> do
  ((cache, pool), companyId) <- ask
  let contactPersonIdentification = toMaybe contactPersonIdentification'
  contactPersonId' <- case contactPersonIdentification of
    Just (M.ContactPersonIdForMachine contactPersonId) -> return . Just $ contactPersonId
    Just (M.ContactPersonForMachine contactPerson) -> do
      contactPersonNewIds <- liftIO $ withResource pool $ \connection -> runInsertReturning connection contactPersonsTable
        (Nothing, pgInt4 . C.getCompanyId $ companyId, pgStrictText . CP.name $ contactPerson,
          pgStrictText . CP.name $ contactPerson, pgStrictText . CP.name $ contactPerson)
        $(proj 5 0)
      contactPersonNewId <- singleRowOrColumn contactPersonNewIds
      return . Just . CP.ContactPersonId $ contactPersonNewId
    Nothing -> return Nothing
  machineId <- withResource pool $ \connection -> addMachine connection newMachine 
    (C.getCompanyId companyId) machineType contactPersonId' (toMaybe linkedMachineId) machineSpecificData
  withResource pool $ \connection -> recomputeSingle companyId connection cache
  return machineId
    

addMachine :: 
  Connection -> 
  M.Machine -> 
  Int -> 
  MT.MyEither -> 
  Maybe CP.ContactPersonId -> 
  Maybe M.MachineId -> 
  [(EF.ExtraFieldId, Text)] -> 
  ExceptT (Reason r) (IdDependencies' C.CompanyId) M.MachineId -- ^ id of newly created machine
addMachine connection machine companyId' machineType contactPersonId linkedMachineId extraFields = do
  machineTypeId <- liftIO $ case machineType of
    MT.MyInt id' -> return $ id'
    MT.MyMachineType (MT.MachineType kind name' manufacturer, upkeepSequences) -> do
      newMachineTypeId <- runInsertReturning
        connection
        machineTypesTable (Nothing, pgInt4 $ MK.kindToDbRepr kind, pgStrictText name', pgStrictText manufacturer)
        sel1
      let machineTypeId = head newMachineTypeId -- todo safe
      forM_ upkeepSequences (\(US.UpkeepSequence displayOrdering label repetition oneTime) -> runInsert
        connection
        upkeepSequencesTable 
        (pgInt4 displayOrdering, pgStrictText label, 
          pgInt4 repetition, pgInt4 machineTypeId, pgBool oneTime))
      return machineTypeId
  let
    M.Machine machineOperationStartDate' initialMileage mileagePerYear label
      serialNumber yearOfManufacture archived furtherSpecification = machine
  machineIds <- liftIO $ runInsertReturning
    connection
    machinesTable 
    (MachineRow {
      _machinePK = M.MachineId Nothing ,
      _companyFK = C.CompanyId . pgInt4 $ companyId' ,
      _contactPersonFK = maybeToNullable $ fmap (pgInt4 . CP.getContactPersonId) contactPersonId ,
      _machineTypeFK = pgInt4 machineTypeId ,
      _linkageFK = M.MachineId $ maybeToNullable $ (pgInt4 . M.getMachineId) `fmap` linkedMachineId ,
      _machine = M.Machine {
        M.machineOperationStartDate = maybeToNullable $ fmap (pgDay . YMD.ymdToDay) machineOperationStartDate' ,
        M.initialMileage = pgInt4 initialMileage ,
        M.mileagePerYear = pgInt4 mileagePerYear ,
        M.label_ = pgStrictText label ,
        M.serialNumber = pgStrictText serialNumber ,
        M.yearOfManufacture = pgStrictText yearOfManufacture , 
        M.archived = pgBool archived , 
        M.furtherSpecification = pgStrictText furtherSpecification }})
    _machinePK      
  let (machineId :: M.MachineId) = head machineIds -- todo safe
  liftIO $ insertExtraFields machineId extraFields connection
  return machineId 

listing :: ListHandler (IdDependencies' C.CompanyId)
listing = mkListing' jsonO $ const $ do
  ((_, pool), companyId) <- ask
  otherMachines <- liftIO $ withResource pool $ \connection -> runQuery 
    connection (otherMachinesInCompanyQuery companyId)
  let 
    result = fmap (\(mm :: MachineRecord) -> (_machinePK mm, _machine mm)) otherMachines
  return result

machineResource :: Resource (IdDependencies' C.CompanyId) (IdDependencies' C.CompanyId) Void () Void
machineResource = mkResourceId {
  name = A.machines ,
  schema = S.withListing () $ S.named [] ,
  list = const listing ,
  create = Just createMachineHandler }
