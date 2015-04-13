module Crm.Server.Core where

import qualified Crm.Shared.Machine as M
import qualified Crm.Shared.UpkeepSequence as US
import qualified Crm.Shared.Upkeep as U

import Crm.Server.Helpers (ymdToDay)

import Data.Time.Calendar (Day, fromGregorian, addDays)
import Data.List (find)

import Safe.Foldable (minimumMay)

import Debug.Trace

nextServiceDate :: M.Machine -- ^ machine for which the next service date is computed
                -> (US.UpkeepSequence, [US.UpkeepSequence]) -- ^ upkeep sequences belonging to the machine - must be at least one element
                -> [U.Upkeep] -- ^ upkeeps belonging to this machine
                -> Day -- ^ computed next service date for this machine
nextServiceDate machine
                sequences
                upkeeps = let
  computeFromSequence = case upkeeps of
    [] -> let
      (sequence, _) = sequences
      operationStartDate = ymdToDay $ M.machineOperationStartDate machine
      upkeepRepetition = US.repetition sequence
      mileagePerYear = M.mileagePerYear machine
      yearsToNextService = (fromIntegral upkeepRepetition / fromIntegral mileagePerYear) :: Double
      daysToNextService = truncate $ yearsToNextService * 365
      nextServiceDay = addDays daysToNextService operationStartDate
      in nextServiceDay
    xs -> undefined
  earliestPlannedUpkeep = case filter (not . U.upkeepClosed) upkeeps of
    [] -> Nothing
    openUpkeeps -> fmap ymdToDay $ minimumMay $ fmap U.upkeepDate openUpkeeps
  in case earliestPlannedUpkeep of
    Just plannedUpkeepDay -> plannedUpkeepDay
    Nothing -> computeFromSequence
