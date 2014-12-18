{-# LANGUAGE CPP #-}
{-# LANGUAGE PackageImports #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Shared.Api (
  companies, companiesClient
  , machines, machinesClient
  , upkeep, upkeepsClient
) where

#ifndef FAY
import "base" Data.Char
import "base" Prelude
#else
import "fay-base" Prelude
import "fay-base" Data.Char
#endif

companies :: String
companies = "companies"

machines :: String
machines = "machines"

upkeep :: String
upkeep = "upkeeps"

companiesClient :: String
companiesClient = firstToUpper companies

machinesClient :: String
machinesClient = firstToUpper machines

upkeepsClient :: String
upkeepsClient = firstToUpper upkeep

firstToUpper :: String -> String
firstToUpper str = case str of
  s:tr -> toUpper s : tr
  [] -> ""
