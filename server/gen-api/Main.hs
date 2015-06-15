module Main where

import qualified Rest.Gen         as Gen
import qualified Rest.Gen.Config  as Gen
import           Crm.Server.Base  (router', api)
import           Rest.Gen.Haskell (HaskellContext(..))
import           Rest.Gen.Fay     (mkFayApi)
import           Rest.Api         (Version(..))

main :: IO ()
main = let
  haskellContext = HaskellContext {
    apiVersion = Version 1 0 (Just 0) ,
    targetPath = "../client/generated-api/" ,
    wrapperName = "crm-client" ,
    includePrivate = True ,
    sources = [] ,
    imports = [] ,
    rewrites = [] ,
    namespace = ["Crm", "Client"] }
  in mkFayApi haskellContext router'
