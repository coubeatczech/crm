{-# LANGUAGE ScopedTypeVariables #-}

module Crm.Server.Api.MachineTypeResource (
  machineTypeResource) where

import           Opaleye.RunQuery            (runQuery)
import           Opaleye.Operators           ((.==))
import           Opaleye.PGTypes             (pgInt4, pgStrictText, pgBool)
import           Opaleye.Manipulation        (runInsert, runUpdate, runDelete)

import           Control.Monad.Reader        (ask)
import           Control.Monad.IO.Class      (liftIO)
import           Control.Monad.Error.Class   (throwError)
import           Control.Monad               (forM_)

import           Data.Tuple.All              (sel1, sel2, sel4)
import           Data.Int                    (Int64)
import           Data.Text                   (Text)

import           Network.HTTP.Base           (urlDecode)

import           Rest.Types.Error            (Reason(NotFound, UnsupportedRoute))
import           Rest.Resource               (Resource, Void, schema, list, name, 
                                             mkResourceReaderWith, get, update)
import qualified Rest.Schema                 as S
import           Rest.Dictionary.Combinators (jsonO, jsonI)
import           Rest.Handler                (ListHandler, Handler)

import qualified Crm.Shared.Api              as A
import qualified Crm.Shared.MachineType      as MT
import qualified Crm.Shared.UpkeepSequence   as US
import           Crm.Shared.MyMaybe

import           Crm.Server.Helpers          (prepareReaderTuple, maybeId, readMay')
import           Crm.Server.Boilerplate      ()
import           Crm.Server.Types
import           Crm.Server.DB
import           Crm.Server.Handler          (mkInputHandler', mkConstHandler', mkListing')
import           Crm.Server.CachedCore       (recomputeWhole)


machineTypeResource :: Resource Dependencies MachineTypeDependencies MachineTypeSid MachineTypeMid Void
machineTypeResource = (mkResourceReaderWith prepareReaderTuple) {
  name = A.machineTypes ,
  list = machineTypesListing ,
  update = Just updateMachineType ,
  get = Just machineTypesSingle ,
  schema = autocompleteSchema }

machineTypesListing :: MachineTypeMid -> ListHandler Dependencies
machineTypesListing (Autocomplete mid) = mkListing' jsonO (const $ 
  ask >>= \(_,conn) -> liftIO $ runMachineTypesQuery' (decode mid) conn)
machineTypesListing (AutocompleteManufacturer mid) = mkListing' jsonO (const $
  ask >>= \(_,conn) -> liftIO $ ((runQuery conn (machineManufacturersQuery (decode mid))) :: IO [String]))
machineTypesListing CountListing = mkListing' jsonO (const $ do
  rows <- ask >>= \(_,conn) -> liftIO $ runQuery conn machineTypesWithCountQuery 
  let 
    mapRow :: ((Int,Int,Text,Text),Int64) -> ((MT.MachineTypeId, MT.MachineType), Int)
    mapRow (mtRow, count) = (convert mtRow :: MachineTypeMapped, fromIntegral count)
    mappedRows = map mapRow rows
  return mappedRows )

updateMachineType :: Handler MachineTypeDependencies
updateMachineType = mkInputHandler' (jsonO . jsonI) $ \(machineType, upkeepSequences) ->
  ask >>= \((cache, connection), sid) -> case sid of
    MachineTypeByName _ -> throwError UnsupportedRoute
    MachineTypeById machineTypeId' -> maybeId machineTypeId' $ \machineTypeId -> do 
      liftIO $ do
        let 
          readToWrite row = (Nothing, sel2 row, pgStrictText $ MT.machineTypeName machineType, 
            pgStrictText $ MT.machineTypeManufacturer machineType)
          condition machineTypeRow = sel1 machineTypeRow .== pgInt4 machineTypeId
        _ <- runUpdate connection machineTypesTable readToWrite condition
        _ <- runDelete connection upkeepSequencesTable (\table -> sel4 table .== pgInt4 machineTypeId)
        forM_ upkeepSequences $ \(US.UpkeepSequence displayOrder label repetition oneTime) -> 
          runInsert connection upkeepSequencesTable (pgInt4 displayOrder,
            pgStrictText label, pgInt4 repetition, pgInt4 machineTypeId, pgBool oneTime)
      recomputeWhole connection cache

decode :: String -> String
decode = urlDecode

machineTypesSingle :: Handler MachineTypeDependencies
machineTypesSingle = mkConstHandler' jsonO (do
  ((_,conn), machineTypeSid) <- ask
  let 
    performQuery parameter = liftIO $ runQuery conn (singleMachineTypeQuery parameter)
    (onEmptyResult, result) = case machineTypeSid of
      MachineTypeById(Right(mtId)) -> (throwError NotFound, performQuery $ Right mtId)
      MachineTypeById(Left(_)) -> (undefined, throwError NotFound)
      MachineTypeByName(mtName) -> (return MyNothing, performQuery $ Left $ decode mtName)
  rows <- result
  case rows of
    x:xs | null xs -> do 
      let mt = convert x :: MachineTypeMapped
      upkeepSequences <- liftIO $ runQuery conn (upkeepSequencesByIdQuery $ pgInt4 $ MT.getMachineTypeId $ sel1 mt)
      let mappedUpkeepSequences = fmap (\row -> sel2 (convert row :: UpkeepSequenceMapped)) upkeepSequences
      return $ MyJust (sel1 mt, sel2 mt, mappedUpkeepSequences)
    [] -> onEmptyResult
    _ -> throwError NotFound)

autocompleteSchema :: S.Schema MachineTypeSid MachineTypeMid Void
autocompleteSchema = S.withListing CountListing $ S.named [(
  A.autocompleteManufacturer, S.listingBy (\str -> AutocompleteManufacturer str)),(
  A.autocomplete, S.listingBy (\str -> Autocomplete str)),(
  A.byName, S.singleBy (\str -> MachineTypeByName str)),(
  A.byId, S.singleBy (\mtId -> MachineTypeById $ readMay' mtId))]
