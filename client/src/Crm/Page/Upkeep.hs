{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RebindableSyntax #-}

module Crm.Page.Upkeep (
  upkeepNew ,
  upkeepDetail ,
  plannedUpkeeps ) where

import           Data.Text                             (fromString, Text, showInt)
import           Prelude                               hiding (div, span, id)
import           Data.Var (Var, modify)
import           FFI (Defined(Defined))

import           HaskellReact                          as HR
import qualified HaskellReact.Bootstrap                as B
import qualified HaskellReact.Bootstrap.Button         as BTN
import qualified HaskellReact.Bootstrap.Glyphicon      as G
import qualified HaskellReact.Tag.Hyperlink            as A

import qualified Crm.Shared.Company                    as C
import qualified Crm.Shared.Machine                    as M
import qualified Crm.Shared.MachineType                as MT
import qualified Crm.Shared.Upkeep                     as U
import qualified Crm.Shared.Employee                   as E
import qualified Crm.Shared.UpkeepMachine              as UM

import qualified Crm.Data.Data                         as D
import qualified Crm.Data.UpkeepData                   as UD
import qualified Crm.Component.DatePicker              as DP
import qualified Crm.Validation                        as V
import qualified Crm.Router                            as R
import           Crm.Server                            (createUpkeep, updateUpkeep)
import           Crm.Component.Form
import           Crm.Helpers

plannedUpkeeps :: R.CrmRouter
               -> [(U.UpkeepId, U.Upkeep, C.CompanyId, C.Company)]
               -> DOMElement
plannedUpkeeps router upkeepCompanies = let
  head' = thead $ tr [
    th "Název firmy" ,
    th "Datum" ,
    th "Přeplánovat" ,
    th "Uzavřít" ]
  body = tbody $ map (\(upkeepId, upkeep, companyId, company) ->
    tr [
      td $ R.link
        (C.companyName company)
        (R.companyDetail companyId)
        router ,
      td $ displayDate $ U.upkeepDate upkeep ,
      td $ R.link
        "Přeplánovat"
        (R.replanUpkeep upkeepId)
        router,
      td $ R.link
        "Uzavřít"
        (R.closeUpkeep upkeepId)
        router ]) upkeepCompanies

  advice = p [ text2DOM "Seznam naplánovaných servisů. Tady můžeš buď servis ", strong "přeplánovat", text2DOM ", pokud je třeba u naplánovaného změnit datum a podobně, nebo můžeš servis uzavřít, to se dělá potom co je servis fyzicky hotov a přijde ti servisní list." ]
  pageInfo' = pageInfo "Naplánované servisy" $ Just advice

  in B.grid $ B.row $
    pageInfo' ++
    [B.col (B.mkColProps 12) $ main $ B.table [head', body]]


swap :: (a, b) -> (b, a)
swap (x, y) = (y, x)


-- | if the element is in the first list, put it in the other one, if the element
-- is in the other, put in the first list
toggle :: ([a],[a]) -> (a -> Bool) -> ([a],[a])
toggle lists findElem = let
  toggleInternal (list1, list2) runMore = let
    foundInFirstList = find findElem list1
    in case foundInFirstList of
      Just(elem') -> let
        filteredList1 = filter (not . findElem) list1
        addedToList2 = elem' : list2
        result = (filteredList1, addedToList2)
        in if runMore then result else swap result
      _ -> if runMore
        then toggleInternal (list2, list1) False
        else lists
  in toggleInternal lists True


mkSubmitButton :: Renderable a
               => a
               -> Fay ()
               -> Bool
               -> DOMElement
mkSubmitButton buttonLabel handler enabled = let
  basicButtonProps = BTN.buttonProps {
    BTN.bsStyle = Defined "primary" }
  buttonProps = if enabled
    then basicButtonProps { BTN.onClick = Defined $ const handler }
    else basicButtonProps { BTN.disabled = Defined True }
  in BTN.button' buttonProps buttonLabel


upkeepDetail :: R.CrmRouter
             -> Var D.AppState
             -> U.Upkeep'
             -> (DP.DatePicker, Text)
             -> [UM.UpkeepMachine']
             -> [(M.MachineId, M.Machine, C.CompanyId, MT.MachineTypeId, MT.MachineType)] 
             -> C.CompanyId -- ^ company id
             -> [E.Employee']
             -> Maybe E.EmployeeId
             -> V.Validation
             -> DOMElement
upkeepDetail router appState upkeep3 datePicker notCheckedMachines 
    machines companyId employees selectedEmployee v =
  upkeepForm appState "Uzavřít servis" upkeep2 datePicker notCheckedMachines 
    machines submitButton True employees selectedEmployee v
      where
        (_,upkeep,upkeepMachines) = upkeep3
        upkeep2 = (upkeep,upkeepMachines)
        submitButton = let
          closeUpkeepHandler = updateUpkeep
            (upkeep3, selectedEmployee)
            (R.navigate (R.maintenances companyId) router)
          in mkSubmitButton 
            [span G.plus , span " Uzavřít"]
            closeUpkeepHandler


upkeepNew :: R.CrmRouter
          -> Var D.AppState
          -> (U.Upkeep, [UM.UpkeepMachine'])
          -> (DP.DatePicker, Text)
          -> [UM.UpkeepMachine']
          -> [(M.MachineId, M.Machine, C.CompanyId, MT.MachineTypeId, MT.MachineType)] -- ^ machine ids -> machines
          -> Either C.CompanyId U.UpkeepId
          -> [E.Employee']
          -> Maybe E.EmployeeId
          -> V.Validation
          -> DOMElement
upkeepNew router appState upkeep datePicker notCheckedMachines machines upkeepIdentification es mE v = 
  upkeepForm appState pageHeader upkeep datePicker notCheckedMachines machines submitButton False es mE v where
    (upkeepU, upkeepMachines) = upkeep
    (pageHeader, submitButton) = case upkeepIdentification of 
      Left (companyId) -> let
        newUpkeepHandler = createUpkeep
          (upkeepU, upkeepMachines, mE)
          companyId
          (R.navigate R.plannedUpkeeps router)
        button = mkSubmitButton
          [G.plus , text2DOM " Naplánovat"]
          newUpkeepHandler
        in ("Naplánovat servis", button)
      Right (upkeepId) -> let
        replanUpkeepHandler = updateUpkeep
          ((upkeepId, upkeepU, upkeepMachines), mE)
          (R.navigate R.plannedUpkeeps router)
        button = mkSubmitButton
          [text2DOM "Přeplánovat"]
          replanUpkeepHandler
        in ("Přeplánovat servis", button)


upkeepForm :: Var D.AppState
           -> Text -- ^ page header
           -> (U.Upkeep, [(UM.UpkeepMachine')])
           -> (DP.DatePicker, Text) -- ^ datepicker, datepicker openness
           -> [(UM.UpkeepMachine')]
           -> [(M.MachineId, M.Machine, C.CompanyId, MT.MachineTypeId, MT.MachineType)] 
              -- ^ machine ids -> machines
           -> (Bool -> DOMElement) -- ^ submit button
           -> Bool -- ^ display the mth input field
           -> [E.Employee']
           -> Maybe E.EmployeeId
           -> V.Validation
           -> DOMElement
upkeepForm appState pageHeader (upkeep, upkeepMachines) (upkeepDatePicker', rawUpkeepDate)
    notCheckedMachines'' machines button closeUpkeep' employees selectedEmployee validation = let
  modify' :: (UD.UpkeepData -> UD.UpkeepData) -> Fay ()
  modify' fun = modify appState $ \appState' -> let
    newState = case D.navigation appState' of
      D.UpkeepScreen ud -> D.UpkeepScreen $ fun ud
    in appState' { D.navigation = newState }

  setUpkeepFull :: (U.Upkeep, [UM.UpkeepMachine']) -> Text -> Fay ()
  setUpkeepFull modifiedUpkeep upkeepDateText = modify' $ \upkeepData ->
    let dp = fst $ UD.upkeepDatePicker upkeepData
    in upkeepData { 
      UD.upkeep = modifiedUpkeep ,
      UD.upkeepDatePicker = (dp, upkeepDateText) }
  
  setUpkeep :: (U.Upkeep, [UM.UpkeepMachine']) -> Fay ()
  setUpkeep modifiedUpkeep = setUpkeepFull modifiedUpkeep rawUpkeepDate

  setNotCheckedMachines :: [UM.UpkeepMachine'] -> [UM.UpkeepMachine'] -> Fay ()
  setNotCheckedMachines checkedMachines notCheckedMachines' = modify' $ 
    \upkeepData -> upkeepData { 
      UD.upkeep = (upkeep, checkedMachines) ,
      UD.notCheckedMachines = notCheckedMachines' }
    
  machineRow (machineId,_,_,_,machineType) = let
    findMachineById (_,id') = machineId == id'
    thisUpkeepMachine = find findMachineById upkeepMachines
    thatUpkeepMachine = find findMachineById notCheckedMachines''
    checkedMachineIds = map snd upkeepMachines
    machineToggleLink = let
      content = MT.machineTypeName machineType
      clickHandler = let
        (newCheckedMachines, newNotCheckedMachines) = toggle (
          upkeepMachines ,
          notCheckedMachines'' )
          (\(_,machineId') -> machineId' == machineId)
        in setNotCheckedMachines newCheckedMachines newNotCheckedMachines
      link' = A.a''
        (mkAttrs {onClick = Defined $ const clickHandler} )
        (A.mkAAttrs)
        content
      icon = if elem machineId checkedMachineIds
        then G.okCircle
        else span ([]::[DOMElement])
      innerRow = B.row [B.col' (B.mkColProps 2) (Defined "1") icon, 
        B.col' (B.mkColProps 10) (Defined "2") link']
      in B.col' (B.mkColProps (if closeUpkeep' then 4 else 6)) (Defined "1") innerRow

    (machineToDisplay, setUpkeepMachine, editing) = case (thisUpkeepMachine, thatUpkeepMachine) of
      (Just(thisMachine), Nothing) -> let
        setter :: UM.UpkeepMachine -> Fay ()
        setter upkeepMachine = let
          ums = map (\(um @ (_,machineId')) -> if machineId' == machineId
            then (upkeepMachine, machineId')
            else um) upkeepMachines 
          in setUpkeep (upkeep, ums)
        in (thisMachine, setter, Editing)
      (Nothing, Just(thatMachine)) ->
        (thatMachine, const $ return (), Display)

    recordedMileageField = B.col (B.mkColProps 2) $ input editing False
      (DefaultValue $ showInt $ UM.recordedMileage $ fst machineToDisplay) (eventInt' 
        (\i -> do
          let newValidation = V.remove (V.MthNumber machineId) validation
          modify' $ \ud -> ud { UD.validation = newValidation }
          setUpkeepMachine $ ((fst machineToDisplay) { UM.recordedMileage = i })) 
        (const $ modify' $ \ud -> ud { UD.validation = V.add (V.MthNumber machineId) validation }))

    warrantyUpkeep = checkbox editing (UM.warrantyUpkeep $ fst machineToDisplay) $ \warrantyUpkeep' ->
      setUpkeepMachine $ (fst machineToDisplay) { UM.warrantyUpkeep = warrantyUpkeep' }
    warrantyUpkeepRow = B.col' (B.mkColProps 1) (Defined "3") warrantyUpkeep

    noteField = B.col (B.mkColProps $ if closeUpkeep' then 5 else 6) $ 
      textarea editing False (SetValue $ UM.upkeepMachineNote $ fst machineToDisplay) $ eventValue >=> \es ->
        setUpkeepMachine $ (fst machineToDisplay) { UM.upkeepMachineNote = es }

    rowItems = if closeUpkeep'
      then [machineToggleLink, recordedMileageField, warrantyUpkeepRow, noteField]
      else [machineToggleLink, noteField]
    in div' (class' "form-group") rowItems
  datePicker = let
    modifyDatepickerDate newDate = modify' (\upkeepData -> upkeepData {
      UD.upkeepDatePicker = lmap (\t -> lmap (const newDate) t) (UD.upkeepDatePicker upkeepData)}) 
    setPickerOpenness open = modify' (\upkeepData -> upkeepData {
      UD.upkeepDatePicker = lmap (\t -> rmap (const open) t) (UD.upkeepDatePicker upkeepData)})
    setDate date = case date of
      Right date' -> setUpkeepFull (upkeep { U.upkeepDate = date' }, upkeepMachines) $ displayDate date'
      Left text' -> setUpkeepFull (upkeep, upkeepMachines) text'
    dateValue = if (displayDate $ U.upkeepDate upkeep) == rawUpkeepDate
      then Right $ U.upkeepDate upkeep
      else Left rawUpkeepDate
    in DP.datePicker Editing upkeepDatePicker' modifyDatepickerDate setPickerOpenness dateValue setDate

  dateRow = oneElementRow "Datum" datePicker
  employeeSelectRow = nullDropdownRow Editing "Servisman" employees E.name (findInList selectedEmployee employees)
    $ \eId -> modify' $ \s -> s { UD.selectedEmployee = eId }
    
  textareaRowEditing = textareaRow Editing
  inputRowEditing = inputRow Editing

  workHoursRow = inputRowEditing "Hodiny"
    (SetValue $ U.workHours upkeep) $ eventValue >=> \es -> modify' $ \ud ->
      ud { UD.upkeep = lmap (const $ upkeep { U.workHours = es }) (UD.upkeep ud) }
  workDescriptionRow = textareaRowEditing "Popis práce" (SetValue $ U.workDescription upkeep) $ 
    eventValue >=> \es -> modify' $ \ud ->
      ud { UD.upkeep = lmap (const $ upkeep { U.workDescription = es }) (UD.upkeep ud) }
  recommendationRow = textareaRowEditing "Doporučení" (SetValue $ U.recommendation upkeep) $
    eventValue >=> \es -> modify' $ \ud ->
      ud { UD.upkeep = lmap (const $ upkeep { U.recommendation = es }) (UD.upkeep ud) }
  closeUpkeepRows = [workHoursRow, workDescriptionRow, recommendationRow]
  additionalRows = if closeUpkeep' then closeUpkeepRows else []
  header = div' (class' "form-group") $ [
    B.col (B.mkColProps (if closeUpkeep' then 4 else 6)) $ div $ B.row [B.col (B.mkColProps 2) "", 
      B.col (B.mkColProps 10) $ strong "Stroj" ]] ++ (if closeUpkeep' then [
    B.col (B.mkColProps 2) $ strong "Motohodiny" ,
    B.col (B.mkColProps 1) $ strong "Záruka" ] else []) ++ [
    B.col (B.mkColProps (if closeUpkeep' then 5 else 6)) $ strong "Poznámka" ]
  companyNameHeader = B.row $ B.col (B.mkColProps 12) $ h2 pageHeader

  validationMessages'' = V.messages validation
  validationMessages' = if (null upkeepMachines)
    then ["V servisu musí figurovat alespoň jeden stroj."]
    else []
  validationMessages = validationMessages'' ++ validationMessages' ++ 
    (if displayDate (U.upkeepDate upkeep) == rawUpkeepDate
      then []
      else ["Musí být nastaveno správně datum."])
  submitButton = oneElementRow "" (button $ null validationMessages)
  messagesPart = validationHtml validationMessages

  in div $ (form' (class' "form-horizontal") $ B.grid $
    [companyNameHeader] ++
    [header] ++
    map machineRow machines ++ 
    [dateRow, employeeSelectRow] ++ 
    additionalRows ++ 
    [submitButton]) : messagesPart : []
