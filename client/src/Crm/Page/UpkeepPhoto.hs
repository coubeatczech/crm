{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RebindableSyntax #-}

module Crm.Page.UpkeepPhoto (
  addPhotoToUpkeepList ) where

import           Data.Text                        (fromString, Text, showInt, (<>), empty)
import qualified Data.Text                        as T
import           Prelude                          hiding (div, span, id)
import qualified Prelude                          as Prelude
import           FFI                                   (Defined(..))

import           HaskellReact                     as HR
import qualified HaskellReact.Bootstrap           as B
import qualified HaskellReact.Bootstrap.Button    as BB
import qualified HaskellReact.Jasny               as J
import qualified JQuery                           as JQ

import qualified Crm.Shared.Company               as C
import qualified Crm.Shared.Machine               as M
import qualified Crm.Shared.Upkeep                as U
import qualified Crm.Shared.Employee              as E
import qualified HaskellReact.Bootstrap.Glyphicon as G

import qualified Crm.Router                       as R
import           Crm.Helpers

addPhotoToUpkeepList :: 
  R.CrmRouter -> 
  [[(U.UpkeepId, U.Upkeep, C.CompanyId, C.Company, [(M.MachineId, Text, Text)], [E.Employee'])]] -> 
  DOMElement
addPhotoToUpkeepList router upkeeps = let
  pageInfo' = pageInfo "Aktuální servisy - přidej fotky" $ (Nothing :: Maybe DOMElement)
  table = B.table [head', body] where
    head' = thead $ tr [
      th "Název firmy" ,
      th "Přidat fotky" ,
      th "Datum" ]
    renderUpkeepRow (upkeepId, upkeep, _, company, _, _) = tr [
      td . C.companyName $ company ,
      td $ BB.buttonP 
        BB.LargeButton
        BB.PrimaryButton
        (const $ return ())
        [G.camera, text2DOM " Přidat fotky"] ,
      td . displayDate . U.upkeepDate $ upkeep ]
    body = tbody $ map renderUpkeepRow (concat upkeeps)
  in (B.grid $ B.row $
    pageInfo' ++
    [B.col (B.mkColProps 12) $ main table])

upkeepPhotos ::
  R.CrmRouter ->
  U.UpkeepId ->
  U.Upkeep ->
  C.Company ->
  DOMElement
upkeepPhotos router upkeepId upkeep company = let
  rows = [
    B.fullCol [C.companyName company, displayDate . U.upkeepDate $ upkeep] ,
    photo ]
  photo = let
    imageUploadHandler = const $ do
      fileUpload <- JQ.select "#file-upload"
      files <- getFileList fileUpload
      file <- fileListElem 0 files
      type' <- fileType file
      name <- fileName file
      return ()
    imageUploadLabel = "Nahraj fotku"
    in div [
      J.fileUploadI18n "Vyber obrázek" "Dej jiný obrázek" ,
      BB.button'
        (BB.buttonProps {
          BB.bsStyle = Defined "primary" ,
          BB.onClick = Defined imageUploadHandler })
        imageUploadLabel ]
  in (B.grid $ B.row rows)
