{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleInstances #-}

module Crm.TH (
  mkFayTransferable , 
  mkFayTransferables ,
  fayInstance ) where

import           Language.Haskell.TH
import           Control.Monad            (forM)

import           Data.Aeson.Types         (toJSON, ToJSON, FromJSON, parseJSON, Value)
import qualified Data.JSON.Schema.Types   as JS (JSONSchema(schema))
import           Fay.Convert              (showToFay, readFromFay')
import           Data.Maybe               (fromJust)
import           Data.JSON.Schema.Generic (gSchema)
import           Data.Data


fayInstance :: (Monad m, Data a) => Value -> m a
fayInstance value = case readFromFay' value of
  Left e -> fail e
  Right ok -> return ok

-- | Creates necessary instances for the type to be serializable and deserializable to json, that the format that Fay is using 
mkFayTransferable :: Name -> Q [Dec]
mkFayTransferable name = let
  qName = return . ConT $ name
  toJsonInstance = [d|
    instance ToJSON $(qName) where
      toJSON = fromJust . showToFay
    instance FromJSON $(qName) where
      parseJSON = fayInstance 
    instance JS.JSONSchema $(qName) where
      schema = gSchema |]
  in toJsonInstance
 
mkFayTransferables :: [Name] -> Q [Dec]
mkFayTransferables names = fmap concat . forM names $ mkFayTransferable
