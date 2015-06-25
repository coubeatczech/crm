module Crm.Server.Api.Employee.UpkeepResource where

import           Control.Monad.Reader          (ask)

import           Rest.Resource                 (Resource, Void, schema, name,
                                               list, mkResourceId)
import qualified Rest.Schema                   as S
import           Rest.Dictionary.Combinators   (jsonO)
import           Rest.Handler                  (ListHandler)

import qualified Crm.Shared.Api                as A
import qualified Crm.Shared.Employee           as E

import           Crm.Server.Boilerplate        ()
import           Crm.Server.Types
import           Crm.Server.Handler
import           Crm.Server.Api.UpkeepResource (printDailyPlanListing')


resource :: Resource (IdDependencies' E.EmployeeId) (IdDependencies' E.EmployeeId) Void () Void
resource = mkResourceId {
  name = A.upkeep ,
  schema = S.noListing $ S.named [("print", S.listing ())] ,
  list = const printListing }

printListing :: ListHandler (IdDependencies' E.EmployeeId)
printListing = mkListing' jsonO $ const $ do
  ((_, connection), employeeId) <- ask
  printDailyPlanListing' (Just employeeId) connection undefined
