{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RebindableSyntax #-}

module Crm.Page.UpkeepPrint (
  upkeepPrint ) where

import           Data.Text                (fromString)
import           Prelude                  hiding (div)

import           HaskellReact

import qualified Crm.Shared.Company       as C
import qualified Crm.Shared.Employee      as E
import qualified Crm.Shared.ContactPerson as CP
import qualified Crm.Shared.Machine       as M
import qualified Crm.Shared.MachineType   as MT
import qualified Crm.Shared.Upkeep        as U

upkeepPrint :: [(U.Upkeep, C.Company, [E.Employee], [(M.Machine, MT.MachineType, CP.ContactPerson)])]
            -> DOMElement
upkeepPrint data' = div ""
