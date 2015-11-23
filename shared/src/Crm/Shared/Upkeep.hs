{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE CPP #-}

module Crm.Shared.Upkeep where

import Crm.Shared.YearMonthDay  as D
import Crm.Shared.UpkeepMachine as UM
import Crm.Shared.ServerRender  as SR

#ifndef FAY
import GHC.Generics
import Data.Data
import Rest.Info                (Info(..))
#endif
import Data.Text                (Text, pack)

#ifndef FAY
instance Info UpkeepId where
  describe _ = "upkeepId"
instance Read UpkeepId where 
  readsPrec i = fmap (\(a,b) -> (UpkeepId a, b)) `fmap` readsPrec i
#endif

newtype UpkeepId = UpkeepId { getUpkeepId :: Int }
#ifdef FAY
  deriving Eq
#else
  deriving (Eq, Generic, Typeable, Data, Show)
#endif

type Upkeep'' = (UpkeepId, Upkeep)
type Upkeep' = (UpkeepId, Upkeep, [UM.UpkeepMachine'])

data UpkeepGen workDescription recommendation = Upkeep {
  upkeepDate :: D.YearMonthDay ,
  upkeepClosed :: Bool ,
  workHours :: Text ,
  workDescription :: workDescription ,
  recommendation :: recommendation }
#ifndef FAY
  deriving (Generic, Typeable, Data)
#endif
type Upkeep = UpkeepGen Text Text
type UpkeepMarkup = UpkeepGen [SR.Markup] Text
type Upkeep2Markup = UpkeepGen [SR.Markup] [SR.Markup]

newUpkeep :: D.YearMonthDay -> Upkeep
newUpkeep ymd = Upkeep ymd False (pack "0") (pack "") (pack "")
