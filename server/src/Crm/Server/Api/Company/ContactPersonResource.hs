{-# LANGUAGE ScopedTypeVariables #-}

module Crm.Server.Api.Company.ContactPersonResource ( 
  contactPersonResource ) where

import Opaleye.PGTypes (pgString, pgInt4)
import Opaleye.Manipulation (runInsertReturning)
import Opaleye.RunQuery (runQuery)

import Control.Monad.IO.Class (liftIO)

import Data.Tuple.All (sel1, sel3)

import Rest.Resource (Resource, Void, schema, name, create, mkResourceId, list)
import qualified Rest.Schema as S
import Rest.Dictionary.Combinators (jsonO, jsonI)
import Rest.Handler (mkInputHandler, Handler, mkListing, ListHandler)

import qualified Crm.Shared.ContactPerson as CP
import qualified Crm.Shared.Api as A

import Crm.Server.Helpers (withConnId)
import Crm.Server.Boilerplate ()
import Crm.Server.Types
import Crm.Server.DB

createContactPersonHandler :: Handler IdDependencies
createContactPersonHandler = mkInputHandler (jsonO . jsonI) (\contactPerson -> 
    withConnId (\connection companyId -> liftIO $ do
  contactPersonIds <- runInsertReturning
    connection
    contactPersonsTable
    (Nothing, pgInt4 companyId, pgString $ CP.name contactPerson,
      pgString $ CP.phone contactPerson, pgString $ CP.position contactPerson)
    sel1
  let contactPersonId = head contactPersonIds
  return (contactPersonId :: Int)))

contactPersonResource :: Resource IdDependencies IdDependencies Void () Void
contactPersonResource = mkResourceId {
  name = A.contactPersons ,
  schema = S.withListing () $ S.named [] ,
  list = const listing ,
  create = Just createContactPersonHandler }

listing :: ListHandler IdDependencies 
listing = mkListing (jsonO) (const $ withConnId (\connection theId -> do
  rawRows <- liftIO $ runQuery connection (contactPersonsByIdQuery theId)
  let rowsMapped = (\x -> (sel1 x, sel3 x)) `fmap` (convert rawRows :: [ContactPersonMapped])
  return rowsMapped))
