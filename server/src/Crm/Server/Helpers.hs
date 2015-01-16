module Crm.Server.Helpers (
  ymdToDay ,
  dayToYmd ,
  maybeId ,
  readMay' ,
  mapUpkeeps ,
  mappedUpkeepSequences ,
  maybeToNullable ,
  prepareReader , 
  prepareReaderIdentity ,
  prepareReaderTuple ) where

import Opaleye.Column (Column, toNullable, Nullable)
import qualified Opaleye.Column as COL

import Control.Monad.Reader (ReaderT, ask, runReaderT, mapReaderT)
import Data.Functor.Identity (runIdentity)
import Control.Monad.Trans.Class (lift)

import Rest.Types.Error (DataError(ParseError), Reason(IdentError))

import Control.Monad.Error.Class (throwError)
import Control.Monad.Error (ErrorT)

import Data.Time.Calendar (fromGregorian, Day, toGregorian)

import qualified Crm.Shared.YearMonthDay as YMD
import qualified Crm.Shared.UpkeepSequence as US
import qualified Crm.Shared.UpkeepMachine as UM
import qualified Crm.Shared.Upkeep as U

import Safe (readMay)

ymdToDay :: YMD.YearMonthDay -> Day
ymdToDay ymd = day where 
  YMD.YearMonthDay year month day' _  = ymd
  day = fromGregorian (toInteger year) (month + 1) day'

dayToYmd :: Day -> YMD.YearMonthDay
dayToYmd day = ymd where
  (year, month, day') = toGregorian day
  ymd = YMD.YearMonthDay (fromIntegral year) (month - 1) day' YMD.DayPrecision

prepareReaderIdentity :: ReaderT (b, c) IO a
                      -> ReaderT c (ReaderT (b, c) IO) a
prepareReaderIdentity = prepareReader (\c (b, _) -> (b, c))

prepareReader :: (c -> d -> b)
              -> ReaderT b IO a
              -> ReaderT c (ReaderT d IO) a
prepareReader constructB reader = 
  mapReaderT (\cIdentity -> let
    cc = runIdentity cIdentity
    innerReader = ask >>= (\dd -> let
      constructedB = constructB cc dd
      aa = runReaderT reader constructedB
      in lift aa)
    in innerReader) outerReader
  where
    outerReader = ask

prepareReaderTuple :: ReaderT (c, b) IO a
                   -> ReaderT b (ReaderT c IO) a
prepareReaderTuple = prepareReader (\b c -> (c, b))

maybeId :: Monad b
        => Either String Int 
        -> (Int -> ErrorT (Reason r) b a)
        -> ErrorT (Reason r) b a
maybeId maybeInt onSuccess = case maybeInt of
  Right(int) -> onSuccess int
  Left(string) -> throwError $ IdentError $ ParseError
    ("provided identificator(" ++ string ++ ") cannot be parsed into number.")

readMay' :: (Read a) => String -> Either String a
readMay' string = passStringOnNoRead $ readMay string
  where
    passStringOnNoRead (Just parsed) = Right parsed
    passStringOnNoRead _ = Left string

instance Eq YMD.YearMonthDay where
  YMD.YearMonthDay y m d _ == YMD.YearMonthDay y' m' d' _ = y == y' && m == m' && d == d'
instance Ord YMD.YearMonthDay where
  ymd1 `compare` ymd2 = let
    YMD.YearMonthDay y m d _ = ymd1
    YMD.YearMonthDay y' m' d' _ = ymd2
    comp comparison nextComparison = case comparison of
      GT -> GT
      LT -> LT
      EQ -> nextComparison
    in comp (y `compare` y') $ comp (m `compare` m') $ comp (d `compare` d') EQ

mappedUpkeepSequences = map (\(a1,a2,a3,a4) -> US.UpkeepSequence a1 a2 a3 a4) 

mapUpkeeps :: [((Int, Day, Bool, Maybe Int), (Int, String, Int, Int))] 
           -> [(Int, (U.Upkeep, Maybe Int, [(UM.UpkeepMachine, Int)]))]
mapUpkeeps rows = foldl (\acc ((upkeepId,date,upkeepClosed,employeeId),(_,note,machineId,recordedMileage)) ->
  let
    addUpkeep' = (upkeepId, (U.Upkeep (dayToYmd date) upkeepClosed, employeeId, 
      [(UM.UpkeepMachine note recordedMileage, machineId)]) )
    in case acc of
      [] -> [addUpkeep']
      (upkeepId', (upkeep, e, upkeepMachines)) : rest | upkeepId' == upkeepId -> let
        modifiedUpkeepMachines = 
          (UM.UpkeepMachine note recordedMileage, machineId) : upkeepMachines
        in (upkeepId', (upkeep, e, modifiedUpkeepMachines)) : rest
      _ -> addUpkeep' : acc
  ) [] rows

maybeToNullable :: Maybe (Column a) -> Column (Nullable a)
maybeToNullable (Just a) = toNullable a
maybeToNullable Nothing = COL.null
