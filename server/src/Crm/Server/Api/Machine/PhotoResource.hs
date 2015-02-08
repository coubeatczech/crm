module Crm.Server.Api.Machine.PhotoResource ( 
  photoResource ) where

import Opaleye.RunQuery (runQuery)
import Opaleye.Manipulation (runInsert)
import Opaleye.PGTypes (pgInt4)

import Rest.Resource (Resource, Void, schema, name, create, mkResourceId, list)
import qualified Rest.Schema as S
import Rest.Dictionary.Combinators (fileI, someI, someO, jsonO)
import Rest.Handler (mkInputHandler, Handler, mkListing, ListHandler)

import Control.Monad.Reader (ask)
import Control.Monad.IO.Class (liftIO)

import qualified Crm.Shared.Api as A
import qualified Crm.Shared.PhotoMeta as PM
import Crm.Server.Types
import Crm.Server.DB (addMachinePhoto, singleRowOrColumn, machinePhotosByMachineId, machinePhotosTable)
import Crm.Server.Helpers (maybeId, readMay')
import Crm.Server.Boilerplate ()

photoResource :: Resource IdDependencies IdDependencies UrlId () Void
photoResource = mkResourceId {
  name = A.photos ,
  schema = S.withListing () $ S.unnamedSingle readMay' ,
  create = Just addPhotoHandler ,
  list = const listPhotoHandler }

addPhotoHandler :: Handler IdDependencies
addPhotoHandler = mkInputHandler (fileI . someI . jsonO . someO) (\photo -> do 
  (connection, maybeMachineIdInt) <- ask
  maybeId maybeMachineIdInt (\machineId -> do
    newPhotoIds <- liftIO $ addMachinePhoto connection machineId photo
    newPhotoId <- singleRowOrColumn newPhotoIds
    _ <- liftIO $ runInsert connection machinePhotosTable (pgInt4 newPhotoId, pgInt4 machineId) 
    return newPhotoId))

listPhotoHandler :: ListHandler IdDependencies
listPhotoHandler = mkListing (jsonO . someO) (const $ do 
  rows <- ask >>= (\(conn, machineId') -> maybeId machineId' (\machineId ->
    liftIO $ (runQuery conn (machinePhotosByMachineId machineId))))
  return $ map (\(r1,r2,r3) -> (r1 :: Int, PM.PhotoMeta r2 r3) ) rows )
