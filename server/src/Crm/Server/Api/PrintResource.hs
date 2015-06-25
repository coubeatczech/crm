module Crm.Server.Api.PrintResource where

import           Opaleye.RunQuery              (runQuery)

import           Data.Time.Calendar            (fromGregorian)

import           Control.Monad.Reader          (ask)
import           Control.Monad.IO.Class        (liftIO)

import           Rest.Resource                 (Resource, Void, schema, name,
                                               list, mkResourceId)
import qualified Rest.Schema                   as S
import           Rest.Dictionary.Combinators   (jsonO)
import           Rest.Handler                  (ListHandler)

import           Crm.Server.Boilerplate        ()
import           Crm.Server.Types
import           Crm.Server.DB
import           Crm.Server.Handler


resource :: Resource Dependencies Dependencies Void () Void
resource = mkResourceId {
  name = "print" ,
  schema = S.withListing () $ S.named [] ,
  list = const printListing }

printListing :: ListHandler Dependencies
printListing = mkListing' jsonO $ const $ do
  (_, connection) <- ask
  let day = fromGregorian 2015 6 17
  mainEmployees <- (map $ \e -> convert e :: EmployeeMapped) `fmap` (liftIO $ runQuery connection (mainEmployeesInDayQ day))
  return mainEmployees
