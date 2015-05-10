module Crm.Server.Api.ContactPersonResource (resource) where

import Opaleye (runQuery, pgString)

import Control.Monad.IO.Class (liftIO)

import Data.Tuple.All (sel1, sel2, sel3)

import Rest.Resource (Resource, Void, schema, name, mkResourceReaderWith, get, update)
import qualified Rest.Schema as S
import Rest.Handler (Handler, mkConstHandler)
import Rest.Dictionary.Combinators (jsonO)

import qualified Crm.Shared.Api as A
import qualified Crm.Shared.ContactPerson as CP

import Crm.Server.Boilerplate ()
import Crm.Server.Types
import Crm.Server.DB
import Crm.Server.Helpers (prepareReaderTuple, withConnId, readMay', updateRows)

resource :: Resource Dependencies IdDependencies UrlId Void Void
resource = (mkResourceReaderWith prepareReaderTuple) {
  name = A.contactPersons ,
  schema = S.noListing $ S.unnamedSingle readMay' ,
  update = Just updateHandler ,
  get = Just getHandler }

getHandler :: Handler IdDependencies
getHandler = mkConstHandler jsonO $ withConnId $ \connection theId -> do
  rows <- liftIO $ runQuery connection (singleContactPersonQuery theId)
  (cp, company) <- singleRowOrColumn rows
  return $ (sel3 $ (convert cp :: ContactPersonMapped), sel1 $ (convert company :: CompanyMapped))

updateHandler :: Handler IdDependencies
updateHandler = let
  readToWrite contactPerson row = (Nothing, sel2 row, pgString $ CP.name contactPerson ,
    pgString $ CP.phone contactPerson, pgString $ CP.position contactPerson)
  in updateRows contactPersonsTable readToWrite
