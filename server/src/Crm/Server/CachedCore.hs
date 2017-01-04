{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TemplateHaskell       #-}

module Crm.Server.CachedCore where

import           Control.Concurrent                 (forkIO)
import           Control.Concurrent.Async           (Async, async, wait)
import           Control.Concurrent.MVar            (MVar, newEmptyMVar,
                                                     putMVar)
import           Control.Lens                       (mapped, over, view, _1)
import           Control.Monad                      (forM, forM_)

import           Data.IORef                         (atomicModifyIORef',
                                                     readIORef)
import           Data.Pool                          (withResource)
import           Data.Tuple.All                     (sel1, sel2, sel5)

import           Control.Monad.IO.Class             (MonadIO, liftIO)
import           Control.Monad.Trans.Except         (mapExceptT, runExceptT)
import           Control.Monad.Trans.Except         (ExceptT)
import qualified Data.Map                           as Map
import           Database.PostgreSQL.Simple         (Connection)
import           Opaleye                            (Column, Nullable,
                                                     QueryRunnerColumnDefault,
                                                     queryTable, runQuery)
import           Rest.Types.Error                   (Reason)
import           Safe                               (minimumDef)

import qualified Crm.Shared.Company                 as C
import qualified Crm.Shared.Machine                 as M
import qualified Crm.Shared.MachineType             as MT
import qualified Crm.Shared.Upkeep                  as U
import qualified Crm.Shared.YearMonthDay            as YMD

import           Crm.Server.Core                    (NextServiceDate (..),
                                                     nextServiceDate)
import qualified Crm.Server.Database.UpkeepMachine  as UMD
import           Crm.Server.Database.UpkeepSequence
import           Crm.Server.DB
import           Crm.Server.Types


recomputeWhole' ::
  forall r m .
  (MonadIO m, Functor m) =>
  ConnectionPool ->
  Cache ->
  ExceptT (Reason r) m (MVar ())
recomputeWhole' pool (cache @ (Cache c)) = do
  companiesRows <- liftIO $ withResource pool $ \connection -> runQuery connection (queryTable companiesTable)
  let (companies :: [CompanyRecord]) = over (mapped . companyCoords) C.mapCoordinates companiesRows
  let companyIds = over mapped _companyPK companies
  _ <- liftIO $ atomicModifyIORef' c $ const (Map.empty, ())
  daemon <- liftIO $ newEmptyMVar
  _ <- liftIO $ forkIO $ do
    liftIO . putStrLn $ "starting cache computation"
    _ <- liftIO $ let
      forkRecomputation :: [C.CompanyId] -> IO (Async (Either (Reason r) [()]))
      forkRecomputation companyIdsBatch = async $ withResource pool $ \connection ->
        runExceptT $ forM companyIdsBatch $ \companyId -> recomputeSingle companyId connection cache
      batchedCompanyIds = batch companyIds 5
      in do
        computations <- forM batchedCompanyIds forkRecomputation
        forM_ computations $ \computation -> wait computation >> (return ())
    liftIO . putStrLn $ "stopping cache computation"
    putMVar daemon ()
  return daemon


batch :: [a] -> Int -> [[a]]
batch [] _ = []
batch list batchSize = take batchSize list : batch (drop batchSize list) batchSize


recomputeWhole ::
  (MonadIO m, Functor m) =>
  ConnectionPool ->
  Cache ->
  ExceptT (Reason r) m ()
recomputeWhole pool cache = do
  _ <- recomputeWhole' pool cache
  return ()


recomputeSingle ::
  (MonadIO m) =>
  C.CompanyId ->
  Connection ->
  Cache ->
  ExceptT (Reason r) m ()
recomputeSingle companyId connection (Cache cache) = mapExceptT liftIO $ do
  companyRows <- liftIO $ runQuery connection (companyByIdQuery companyId)
  companyRow <- singleRowOrColumn companyRows
  let (company :: CompanyRecord) = over companyCoords C.mapCoordinates companyRow
  machines <- liftIO $ runMachinesInCompanyQuery companyId connection
  nextDays <- liftIO $ forM machines $ \machine' -> do
    nextServiceDay <- addNextDates sel1 sel2 machine' connection
    return $ case nextServiceDay of
      Planned _  -> C.Planned
      Computed d -> C.ExactDate d
      Inactive   -> C.Inactive
      CantTell   -> C.CantTellDate
  let
    machineKind = map (MT.kind . sel5) machines
    nextDay = minimumDef C.Inactive nextDays
    value = (_companyCore company, nextDay, _companyCoords company, machineKind)
    modify mapCache = Map.insert companyId value mapCache
  _ <- liftIO $ atomicModifyIORef' cache $ \a -> let
    modifiedA = modify a
    in (modifiedA, ())
  return ()


getCacheContent :: Cache ->
  IO (Map.Map C.CompanyId CacheContent)
getCacheContent (Cache cache) = readIORef cache

addNextDates ::
  (a -> M.MachineId) ->
  (a -> M.Machine) ->
  a ->
  Connection ->
  IO (NextServiceDate YMD.YearMonthDay)
addNextDates getMachineId getMachine a = \conn -> do
  fullUpkeepDataRows' <- runQuery conn (nextServiceUpkeepsQuery . getMachineId $ a)
  let fullUpkeepDataRows = over (mapped . _1 . upkeepSuper) (\x -> fmap (U.UpkeepId) (U.getUpkeepId x)) fullUpkeepDataRows'
  upkeepSequenceRows <- runQuery conn (nextServiceUpkeepSequencesQuery . getMachineId $ a)
  let
    convertFullUpkeeps = fmap $ \(u :: UpkeepRow, um :: UMD.UpkeepMachineRow) ->
      (view upkeep u, view UMD.upkeepMachine um)
    upkeepSequences = fmap (\(usr :: UpkeepSequenceRecord) -> _upkeepSequence usr) upkeepSequenceRows
    upkeepSequenceTuple = case upkeepSequences of
      []     -> undefined
      x : xs -> (x, xs)
    nextServiceDay = nextServiceDate (getMachine a) upkeepSequenceTuple (convertFullUpkeeps fullUpkeepDataRows)
  return (fmap YMD.dayToYmd nextServiceDay)
