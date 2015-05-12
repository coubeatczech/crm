{-# LANGUAGE PackageImports #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Page.Machine (
  machineNew ,
  machineDetail ) where

import "fay-base" Data.Text (fromString, pack, (<>), unpack, Text, showInt)
import "fay-base" Prelude hiding (div, span, id)
import "fay-base" Data.Var (Var, modify)
import "fay-base" FFI (Defined(Defined))

import HaskellReact as HR
import qualified HaskellReact.Bootstrap as B
import qualified HaskellReact.Bootstrap.Button as BTN
import qualified HaskellReact.Bootstrap.ButtonDropdown as BD
import qualified HaskellReact.Jasny as J
import qualified HaskellReact.Tag.Hyperlink as A
import qualified HaskellReact.Tag.Image as IMG
import HaskellReact.Bootstrap.Carousel (carousel)
import qualified HaskellReact.BackboneRouter as BR

import qualified JQuery as JQ

import qualified Crm.Shared.Machine as M
import qualified Crm.Shared.YearMonthDay as YMD
import qualified Crm.Shared.MachineType as MT
import qualified Crm.Shared.Company as C
import qualified Crm.Shared.ContactPerson as CP
import qualified Crm.Shared.UpkeepSequence as US
import qualified Crm.Shared.PhotoMeta as PM
import qualified Crm.Shared.Photo as P
import qualified Crm.Shared.Upkeep as U
import qualified Crm.Shared.UpkeepMachine as UM
import qualified Crm.Shared.Employee as E
import qualified Crm.Shared.MachineKind as MK

import qualified Crm.Data.MachineData as MD
import qualified Crm.Data.Data as D
import qualified Crm.Component.DatePicker as DP
import Crm.Component.Form
import Crm.Server (createMachine, updateMachine, uploadPhotoData, uploadPhotoMeta, getPhoto, deleteMachine, deletePhoto)
import Crm.Helpers 
import qualified Crm.Router as R
import Crm.Page.MachineKind (compressorExtraRows, dryerExtraRows)
import qualified Crm.Validation as V

machineDetail :: Bool
              -> Var D.AppState
              -> R.CrmRouter
              -> C.CompanyId
              -> DP.DatePicker
              -> (M.Machine, Text)
              -> MK.MachineKindData
              -> (MT.MachineType, [US.UpkeepSequence])
              -> M.MachineId
              -> YMD.YearMonthDay
              -> [(P.PhotoId, PM.PhotoMeta)]
              -> [(U.UpkeepId, U.Upkeep, UM.UpkeepMachine, Maybe E.Employee)]
              -> Maybe CP.ContactPersonId
              -> [(CP.ContactPersonId, CP.ContactPerson)]
              -> V.Validation
              -> [(M.MachineId, M.Machine)]
              -> DOMElement
machineDetail editing appVar router companyId calendarOpen (machine, 
    datePickerText) machineSpecific machineTypeTuple machineId nextService photos upkeeps
    contactPersonId contactPersons v om =

  machineDisplay editing pageHeader button appVar calendarOpen (machine, 
      datePickerText) machineSpecific machineTypeTuple extraRows extraGrid contactPersonId contactPersons v Nothing om
    where
      pageHeader = if editing then "Editace stroje" else "Stroj"
      extraRow = [editDisplayRow False "Další servis" (displayDate nextService)]
      upkeepHistoryHtml = let
        mkUpkeepRows :: (U.UpkeepId, U.Upkeep, UM.UpkeepMachine, Maybe E.Employee) -> [DOMElement]
        mkUpkeepRows (_, upkeep, upkeepMachine, maybeEmployee) = let
          (labelClass, labelText) = if U.upkeepClosed upkeep
            then ("label-success", "Uzavřený")
            else ("label-warning", "Naplánovaný")
          stateLabel = B.col (B.mkColProps 1) $ span' (class'' ["label", labelClass]) labelText
          date = B.col (B.mkColProps 2) $ displayDate $ U.upkeepDate upkeep
          mthHeader = B.col (B.mkColProps 3) $ strong "Naměřené motohodiny"
          mth = B.col (B.mkColProps 1) $ showInt $ UM.recordedMileage upkeepMachine
          warrantyHeader = B.col (B.mkColProps 1) $ strong "Záruka"
          warranty = B.col (B.mkColProps 1) (if UM.warrantyUpkeep upkeepMachine then "Ano" else "Ne")
          employeeHeader = B.col (B.mkColProps 1) $ strong "Servisák"
          employee = B.col (B.mkColProps 2) $ case maybeEmployee of
            Just employee' -> [text2DOM $ pack $ E.name employee']
            Nothing -> []
          descriptionHeader = B.col (B.mkColProps 2) $ strong "Popis práce"
          description = B.col (B.mkColProps 4) $ pack $ U.workDescription upkeep
          noteHeader = B.col (B.mkColProps 2) $ strong "Poznámka"
          note = B.col (B.mkColProps 4) $ pack $ UM.upkeepMachineNote upkeepMachine
          in [
            B.row [stateLabel, date, mthHeader, mth, 
              warrantyHeader, warranty, employeeHeader, employee] ,
            div' (class'' ["row", "last"]) [descriptionHeader, description, noteHeader, note]]
        rows = (map mkUpkeepRows upkeeps)
        flattenedRows = foldl (++) [] rows
        in if null flattenedRows
          then []
          else (B.row (B.col (B.mkColProps 12) $ h3 "Předchozí servisy")) : flattenedRows
      extraGrid = (if editing && (not $ null upkeeps) 
        then Nothing 
        else (Just $ B.grid upkeepHistoryHtml))
      photoUploadRow = editDisplayRow
        True
        "Fotka" 
        (let 
          imageUploadHandler = const $ do
            fileUpload <- JQ.select "#file-upload"
            files <- getFileList fileUpload
            file <- fileListElem 0 files
            type' <- fileType file
            name <- fileName file
            uploadPhotoData file machineId $ \photoId ->
              uploadPhotoMeta (PM.PhotoMeta (unpack type') (unpack name)) photoId BR.refresh
          imageUploadLabel = "Přidej fotku"
          photoList = map (\(photoId, photoMeta) -> let
            deletePhotoHandler = const $ deletePhoto photoId BR.refresh
            deletePhotoButton = BTN.button' 
              (BTN.buttonProps {
                BTN.bsStyle = Defined "danger" ,
                BTN.onClick = Defined deletePhotoHandler })
              "Smaž fotku"
            in li [text2DOM $ pack $ PM.fileName photoMeta, deletePhotoButton] ) photos
          in div [(ul' (class' "list-unstyled") photoList) : [div [
            J.fileUploadI18n "Vyber obrázek" "Změň" ,
            BTN.button'
              (BTN.buttonProps {
                BTN.bsStyle = Defined "primary" ,
                BTN.onClick = Defined imageUploadHandler })
              imageUploadLabel ]]]) 
      mkPhoto (photoId,_) = IMG.image' mkAttrs (IMG.mkImageAttrs $ getPhoto photoId)
      photoCarouselRow = editDisplayRow
        True
        "Fotky"
        (carousel "my-carousel" (map mkPhoto photos))

      deleteMachineRow = formRow "Smazat" $ BTN.button'
        (BTN.buttonProps { 
          BTN.bsStyle = Defined "danger" ,
          BTN.onClick = Defined $ const $ deleteMachine machineId $ R.navigate (R.companyDetail companyId) router })
        "Smazat"

      extraRows = (case (editing, photos) of
        (True, _) -> [photoUploadRow]
        (_, []) -> []
        _ -> [photoCarouselRow]) ++ extraRow ++ (if editing && null upkeeps && null photos
          then [deleteMachineRow]
          else [])
      setEditing :: Bool -> Fay ()
      setEditing editing' = modify appVar (\appState -> appState {
        D.navigation = case D.navigation appState of
          D.MachineScreen (MD.MachineData a a1 b c c1 c2 v' l (Left (MD.MachineDetail d e _ f g i j))) ->
            D.MachineScreen (MD.MachineData a a1 b c c1 c2 v' l (Left (MD.MachineDetail d e editing' f g i j)))
          _ -> D.navigation appState })
      editButtonRow =
        div' (class' "col-md-3") $
          BTN.button'
            (BTN.buttonProps { BTN.onClick = Defined $ const $ setEditing True })
            "Jdi do editačního módu"
      editMachineAction = updateMachine machineId machine Nothing machineSpecific (setEditing False)
      saveButtonRow'' validationOk = saveButtonRow' validationOk "Edituj" editMachineAction
      button = if editing then saveButtonRow'' else (const editButtonRow)

machineNew :: R.CrmRouter
           -> Var D.AppState
           -> DP.DatePicker
           -> (M.Machine, Text)
           -> MK.MachineKindData
           -> C.CompanyId
           -> (MT.MachineType, [US.UpkeepSequence])
           -> Maybe MT.MachineTypeId
           -> Maybe CP.ContactPersonId
           -> [(CP.ContactPersonId, CP.ContactPerson)]
           -> V.Validation
           -> [(M.MachineId, M.Machine)]
           -> DOMElement
machineNew router appState datePickerCalendar (machine',
    datePickerText) machineSpecific companyId machineTypeTuple machineTypeId contactPersonId contactPersons v om = 
  machineDisplay True "Nový stroj - fáze 2 - specifické údaje o stroji"
      buttonRow appState datePickerCalendar (machine', datePickerText) 
      machineSpecific machineTypeTuple [] Nothing contactPersonId contactPersons v Nothing om
    where
      machineTypeEither = case machineTypeId of
        Just(machineTypeId') -> MT.MyInt $ MT.getMachineTypeId machineTypeId'
        Nothing -> MT.MyMachineType machineTypeTuple
      saveNewMachine = createMachine machine' companyId machineTypeEither contactPersonId Nothing machineSpecific
        (R.navigate (R.companyDetail companyId) router)
      buttonRow validationOk = saveButtonRow' validationOk "Vytvoř" saveNewMachine

machineDisplay :: Bool -- ^ true editing mode false display mode
               -> Text -- ^ header of the page
               -> (Bool -> DOMElement)
               -> Var D.AppState
               -> DP.DatePicker
               -> (M.Machine, Text) -- ^ machine, text of the datepicker
               -> MK.MachineKindData
               -> (MT.MachineType, [US.UpkeepSequence])
               -> [DOMElement]
               -> Maybe DOMElement
               -> Maybe (CP.ContactPersonId)
               -> [(CP.ContactPersonId, CP.ContactPerson)]
               -> V.Validation
               -> Maybe M.MachineId
               -> [(M.MachineId, M.Machine)]
               -> DOMElement
machineDisplay editing pageHeader buttonRow appVar operationStartCalendar (machine',
    datePickerText) machineKindSpecific (machineType, 
    upkeepSequences) extraRows extraGrid contactPersonId contactPersons validation otherMachineId otherMachines = let

  changeNavigationState :: (MD.MachineData -> MD.MachineData) -> Fay ()
  changeNavigationState fun = modify appVar (\appState -> appState {
    D.navigation = case D.navigation appState of 
      D.MachineScreen md -> D.MachineScreen $ fun md
      _ -> D.navigation appState })

  setMachine :: M.Machine -> Fay ()
  setMachine machine = changeNavigationState 
    (\md -> md { MD.machine = (machine, datePickerText) })
  
  setMachineFull :: (M.Machine, Text) -> Fay ()
  setMachineFull tuple = changeNavigationState
    (\md -> md { MD.machine = tuple })

  datePicker = let
    setDatePickerDate date = changeNavigationState (\state ->
      state { MD.operationStartCalendar = 
        lmap (const date) (MD.operationStartCalendar state) })
    setPickerOpenness openness = changeNavigationState (\state ->
      state { MD.operationStartCalendar = 
        rmap (const openness) (MD.operationStartCalendar state) })
    displayedDate = case M.machineOperationStartDate machine' of
      Just date' -> Right date'
      Nothing -> Left datePickerText
    setDate date = case date of
      Right ymd -> let
        newMachine = machine' { M.machineOperationStartDate = Just ymd }
        in setMachine newMachine
      Left text' -> let 
        newMachine = machine' { M.machineOperationStartDate = Nothing }
        in setMachineFull (newMachine, text')
    in DP.datePicker editing operationStartCalendar setDatePickerDate 
      setPickerOpenness displayedDate setDate

  mkSetMachineSpecificData :: MK.MachineKindData -> Fay ()
  mkSetMachineSpecificData mks = changeNavigationState (\md -> md { MD.machineKindSpecific = mks } )

  setCompressor c = mkSetMachineSpecificData $ MK.CompressorSpecific c
  setDryer d = mkSetMachineSpecificData $ MK.DryerSpecific d

  machineKind = MT.kind machineType
  -- extra check that machine type kind matches with machine specific data
  machineSpecificRows = case (machineKindSpecific, machineKind) of
    (MK.CompressorSpecific compressor, MK.CompressorSpecific _)  -> compressorExtraRows editing compressor setCompressor
    (MK.DryerSpecific dryer, MK.DryerSpecific _) -> dryerExtraRows editing dryer setDryer

  validationErrorsGrid = case validation of
    V.Validation [] -> []
    validation' -> [validationHtml $ V.messages validation']

  elements = div $ [form' (mkAttrs { className = Defined "form-horizontal" }) $
    B.grid $ [
      B.row $ B.col (B.mkColProps 12) $ h2 pageHeader ,
      B.row $ [
        row'
          False
          "Typ zařízení" 
          (SetValue $ MT.machineTypeName machineType) 
          (const $ return ()) ,
        row'
          False
          "Výrobce"
          (SetValue $ MT.machineTypeManufacturer machineType)
          (const $ return ()) ,
        maybeSelectRow editing "Kontaktní osoba" contactPersons (pack . CP.name) contactPersonId 
          (\cpId -> changeNavigationState (\md -> md { MD.contactPersonId = cpId })) 
          (\emptyLabel -> CP.newContactPerson { CP.name = unpack emptyLabel }) ,
        maybeSelectRow editing "Zapojení" otherMachines (pack . M.serialNumber) otherMachineId
          (const $ return ())
          (\emptyLabel -> (M.newMachine $ YMD.YearMonthDay 0 0 0 YMD.DayPrecision) { M.serialNumber = unpack emptyLabel }) ,
        row'
          editing
          "Výrobní číslo"
          (SetValue $ M.serialNumber machine')
          (eventString >=> (\s -> setMachine $ machine' { M.serialNumber = s })) ,
        row'
          editing
          "Rok výroby"
          (SetValue $ M.yearOfManufacture machine')
          (eventString >=> (\s -> setMachine $ machine' { M.yearOfManufacture = s })) ,
        editDisplayRow
          editing
          ("Datum uvedení do provozu") 
          datePicker ] ++ (case MT.kind machineType of
            MK.DryerSpecific _ -> []
            MK.CompressorSpecific _ -> [
              row'
                editing
                "Úvodní stav motohodin"
                (DefaultValue $ show $ M.initialMileage machine')
                (eventInt' 
                  (\im -> let
                    newMachine = machine' { M.initialMileage = im }
                    newValidation = V.remove V.MachineInitialMileageNumber validation
                    in changeNavigationState $ \md -> md { MD.machine = (newMachine, datePickerText) , MD.validation = newValidation })
                  (const $ changeNavigationState $ \md -> md { MD.validation = V.add V.MachineInitialMileageNumber validation })) ,
              formRowCol 
                "Provoz mth/rok (Rok má 8760 mth)" [
                (div' (class' "col-md-3") 
                  (editingInput 
                    True
                    (DefaultValue $ show $ M.mileagePerYear machine')
                    (let 
                      errorHandler = changeNavigationState (\md -> md { MD.validation = V.add V.MachineUsageNumber validation })
                      in eventInt' 
                        (\mileagePerYear -> if mileagePerYear > 0
                          then changeNavigationState (\md -> md { 
                            MD.validation = V.remove V.MachineUsageNumber validation , 
                            MD.machine = (machine' { M.mileagePerYear = mileagePerYear }, datePickerText)})
                          else errorHandler)
                        (const errorHandler))
                    editing)) ,
                (label' (class'' ["control-label", "col-md-3"]) "Typ provozu") ,
                (let
                  upkeepPerMileage = minimum repetitions where
                    nonOneTimeSequences = filter (not . US.oneTime) upkeepSequences
                    repetitions = map US.repetition nonOneTimeSequences
                  operationTypeTuples = [(8760, "24/7"), (upkeepPerMileage, "1 za rok")]
                  buttonLabelMaybe = find (\(value, _) -> value == M.mileagePerYear machine') 
                    operationTypeTuples
                  buttonLabel = maybe "Jiný" snd buttonLabelMaybe
                  selectElements = map (\(value, selectLabel) -> let
                    selectAction = setMachineFull (machine' { M.mileagePerYear = value }, datePickerText)
                    in li $ A.a''' (click selectAction) selectLabel) operationTypeTuples
                  buttonLabel' = [text2DOM $ buttonLabel <> " " , span' (class' "caret") ""]
                  dropdown = BD.buttonDropdown' editing buttonLabel' selectElements
                  in if editing
                    then div' (class' "col-md-3") dropdown
                    else div' (class'' ["col-md-3", "control-label", "my-text-left"]) buttonLabel )]]) ++ [
        formRow
          "Poznámka" 
          (editingTextarea True (SetValue $ M.note machine') ((\str -> setMachine $ machine' { 
            M.note = str } ) <=< eventString) editing)] ++ machineSpecificRows ++ extraRows ++ [
        div' (class' "form-group") (buttonRow $ V.ok validation) ]]] ++ validationErrorsGrid ++ (case extraGrid of
          Just extraGrid' -> [extraGrid']
          Nothing -> [])
  in elements
