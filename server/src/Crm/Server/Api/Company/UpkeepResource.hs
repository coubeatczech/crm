{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}

module Crm.Server.Api.Company.UpkeepResource (
  upkeepResource) where

import           Opaleye.RunQuery              (runQuery)

import           Control.Monad.IO.Class        (liftIO)
import           Control.Monad.Reader          (ask)
import           Control.Monad                 (forM)

import           Data.Tuple.All                (sel1, sel2, sel3)

import           Rest.Resource                 (Resource, Void, schema, name, get, 
                                               list, mkResourceId)
import qualified Rest.Schema                   as S
import           Rest.Dictionary.Combinators   (jsonO)
import           Rest.Handler                  (ListHandler, Handler)

import qualified Crm.Shared.Api                as A
import qualified Crm.Shared.Company            as C
import qualified Crm.Shared.Upkeep             as U

import           Crm.Server.Helpers 
import           Crm.Server.Boilerplate        ()
import           Crm.Server.Types
import           Crm.Server.DB
import           Crm.Server.Handler            (mkListing', mkConstHandler')
import           Crm.Server.Api.UpkeepResource (loadNextServiceTypeHint)

import           TupleTH                       (proj, catTuples)


companyUpkeepsListing :: ListHandler (IdDependencies' C.CompanyId)
companyUpkeepsListing = mkListing' jsonO $ const $ do
  ((_,conn), companyId) <- ask
  rows <- liftIO $ runQuery conn (expandedUpkeepsByCompanyQuery $ C.getCompanyId companyId)
  let
    mappedResults = mapResultsToList
      sel1
      (\(upkeepCols,_,_) -> let
        upkeep = convert upkeepCols :: UpkeepMapped
        in ($(proj 2 0) upkeep, $(proj 2 1) upkeep))
      (\(_, upkeepMachine', machineType') -> let
        upkeepMachineMapped = convert upkeepMachine' :: UpkeepMachineMapped
        upkeepMachine = sel3 upkeepMachineMapped
        machineType = sel2 (convert machineType' :: MachineTypeMapped)
        machineId = sel2 upkeepMachineMapped
        in (upkeepMachine, machineType, machineId))
      rows
    flattened = fmap (\((upkeepId, upkeep), upkeepMachines) ->
      (upkeepId, upkeep, upkeepMachines)) mappedResults
  withEmployees <- liftIO $ forM flattened $ \(r @ (upkeepId, _, _)) -> do
    results <- runQuery conn (employeesInUpkeep $ U.getUpkeepId upkeepId)
    let mappedEmployees = fmap (\row -> convert row) results :: [EmployeeMapped]
    return ($(catTuples 3 1) r mappedEmployees)
  return withEmployees

newUpkeepData :: Handler (IdDependencies' C.CompanyId)
newUpkeepData = mkConstHandler' jsonO $ do
  ((_, connection), companyId) <- ask
  machines' <- liftIO $ runQuery connection (machinesQ . C.getCompanyId $ companyId)
  let machines = map (\(m, mt) -> (convert m :: MachineMapped, convert mt :: MachineTypeMapped)) machines'
  machines'' <- loadNextServiceTypeHint machines connection
  return $ map (\(m, mt, nextUpkeepSequence) -> ($(proj 6 0) m, $(proj 6 5) m, $(proj 2 1) mt, nextUpkeepSequence)) machines''

upkeepResource :: Resource (IdDependencies' C.CompanyId) (IdDependencies' C.CompanyId) () () Void
upkeepResource = mkResourceId {
  name = A.upkeep ,
  schema = S.withListing () $ S.named [(A.single, S.singleBy . const $ ())] ,
  get = Just newUpkeepData ,
  list = const companyUpkeepsListing }
