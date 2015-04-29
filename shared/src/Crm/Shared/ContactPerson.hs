{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE PackageImports #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Shared.ContactPerson where

#ifndef FAY
import GHC.Generics
import "base" Data.Data
import "base" Prelude
#else
import "fay-base" Prelude
#endif

newtype ContactPersonId = ContactPersonId { getContactPersonId :: Int }

data ContactPerson = ContactPerson {
  name :: String , 
  phone :: String ,
  position :: String }
#ifndef FAY
  deriving (Generic, Typeable, Data, Show)
#endif

newContactPerson :: ContactPerson
newContactPerson = ContactPerson "" "" ""
