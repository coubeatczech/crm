{-# LANGUAGE PackageImports #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Server where

import FFI (ffi)
import Crm.Shared.Company
import Data.Var
import "fay-base" Prelude

fetchFromServer :: Var (Maybe [Company]) -> Fay ()
fetchFromServer companiesVar = do
  crmApi <- crmApiFacade
  fetchCompanies crmApi (\companies -> do
    set companiesVar $ Just companies)

data CrmApi

fetchCompanies :: CrmApi -- ^ Pointer to Crm api phantom
               -> ([Company] -> Fay ()) -- ^ Callback ran on the fetched data
               -> Fay ()
fetchCompanies = ffi "\
\ %1['Companies']['list'](function(d) {\
  \ %2(d.items); \
\ })\
\ "

crmApiFacade :: Fay CrmApi
crmApiFacade = ffi "\
\ (function() {\
  \ var CrmApi = require('./CrmApi');\
  \ var crmApi = new CrmApi('/api');\
  \ return crmApi;\
\ })() \
\ "
