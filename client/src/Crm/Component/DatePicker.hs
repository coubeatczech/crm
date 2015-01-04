{-# LANGUAGE PackageImports #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Component.DatePicker (
  DatePicker ) where

import "fay-base" Prelude
import "fay-base" Data.Text (fromString, Text)

import qualified HaskellReact.Bootstrap.CalendarInput as CI
import HaskellReact

import qualified Crm.Shared.YearMonthDay as YMD
import Crm.Helpers (displayPrecision)

type DatePicker = (YMD.YearMonthDay, Bool)

datePicker :: DatePicker
           -> (YMD.YearMonthDay -> Fay ()) -- ^ set date picker date
           -> (Bool -> Fay ()) -- ^ set date picker openness
           -> YMD.YearMonthDay -- ^ displayed date
           -> (YMD.YearMonthDay -> Fay ()) -- ^ set date
           -> [DOMElement]
datePicker (pickerStateDate, pickerStateOpen) setDatePickerDate
    setDatePickerOpenness displayedDate setDate = let
  YMD.YearMonthDay y m d displayPrecision' = displayedDate
  dayPickHandler :: Int -> Int -> Int -> Text -> Fay ()
  dayPickHandler year month day precision = case precision of
    month' | month' == "Month" -> setDate' YMD.MonthPrecision
    year' | year' == "Year" -> setDate' YMD.YearPrecision
    day' | day' == "Day" -> setDate' YMD.DayPrecision
    _ -> return ()
    where 
      setDate' precision' =
        setDate $ YMD.YearMonthDay year month day precision'
  YMD.YearMonthDay pickerYear pickerMonth _ _ = pickerStateDate
  changeViewHandler changeViewCommand = let
    (newYear, newMonth) = case changeViewCommand of
      CI.PreviousYear           -> (pickerYear - 1, pickerMonth)
      CI.PreviousMonth | pickerMonth == 1 -> (pickerYear - 1, 12)
      CI.PreviousMonth          -> (pickerYear, pickerMonth - 1)
      CI.NextMonth | pickerMonth == 12    -> (pickerYear + 1, 1)
      CI.NextMonth              -> (pickerYear, pickerMonth + 1)
      CI.NextYear               -> (pickerYear + 1, pickerMonth)
    anyDay = 1
    newDate = YMD.YearMonthDay newYear newMonth anyDay YMD.DayPrecision
    in setDatePickerDate newDate
  in CI.dayInput True (y,m,d,(displayPrecision displayPrecision')) (pickerYear, pickerMonth)
    (dayPickHandler) (pickerStateOpen) setDatePickerOpenness changeViewHandler
