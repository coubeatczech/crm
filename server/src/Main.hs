{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE TemplateHaskell #-}

module Main where

import Snap.Core (route, method, Snap, Method(POST, GET), putResponse, emptyResponse, readRequestBody, setResponseCode, writeLBS, logError)
import Snap.Http.Server (quickHttpServe)

import Database.MySQL.Simple (defaultConnectInfo, Query, connect, connectDatabase, execute, close, ConnectInfo, insertID, query_, Connection)

import Control.Monad.IO.Class (liftIO)
import Control.Exception (try, SomeException, bracket)

import Data.Aeson.TH(deriveJSON, defaultOptions)
import Data.Aeson(decode, encode, ToJSON, Value, toJSON, Object)

import Data.Word(Word64)
import Data.ByteString.Lazy(toStrict)
import Data.ByteString(append)
import Data.HashMap.Strict(singleton, HashMap)
import Data.Text(pack, Text)

import Server.Data(IdToObject, object, idValue)

data Company = Company {
  name :: String
  , days :: Int
} deriving (Show)

data IdResponse = IdResponse {
  id :: Int
}

$(deriveJSON defaultOptions ''Company)
$(deriveJSON defaultOptions ''IdResponse)

connectionInfo :: ConnectInfo
connectionInfo = defaultConnectInfo { connectDatabase = "crm" }

createCompanyQuery :: Query
createCompanyQuery = "insert into Company(name, days) values (?, ?)"

main :: IO ()
main = quickHttpServe site

site :: Snap ()
site =
  route [("/api",
    route [("/companies/new",
      method POST $ do
        requestBody <- readRequestBody 1024
        maybeCompany <- return $ (decode requestBody :: Maybe Company)
        case maybeCompany of
          Just (company) ->
            (=<<) (\x -> x) (liftIO $ bracket
              (connect connectionInfo)
              (close)
              (\connection ->
                let
                  queryResult = (try $ do
                    execute connection createCompanyQuery (name company, days company)
                    insertID connection) :: IO (Either SomeException Word64)
                  response = (fmap (\qr -> case qr of
                    Left _ -> putResponse $ setResponseCode 409 emptyResponse :: Snap()
                    Right recordId ->
                      let
                        encodedId = encode $ IdResponse $ fromIntegral recordId
                      in
                        writeLBS encodedId
                    ) queryResult) :: IO (Snap ())
                in
                  response
              ))
          Nothing -> do
            logError $ ("Failed to parse: ") `append` (toStrict requestBody)
            (putResponse $ setResponseCode 400 emptyResponse)
    )]
  )]
