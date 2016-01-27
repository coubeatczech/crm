{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RebindableSyntax #-}

module Crm.RoutesHandler (
  startRouter) where

import           Data.Text                   (fromString, showInt)
import           Prelude                     hiding (div, span) 
import           Data.Var                    (Var, modify, get)
import           Data.Function               (fmap)
import           Data.Maybe                  (fromJust, onJust)

import qualified HaskellReact.BackboneRouter as BR
import qualified Moment                      as M

import qualified Crm.Shared.Machine          as M
import qualified Crm.Shared.MachineType      as MT
import qualified Crm.Shared.MachineKind      as MK
import qualified Crm.Shared.UpkeepMachine    as UM
import qualified Crm.Shared.Upkeep           as U
import qualified Crm.Shared.UpkeepSequence   as US
import qualified Crm.Shared.Company          as C
import qualified Crm.Shared.ContactPerson    as CP
import qualified Crm.Shared.YearMonthDay     as YMD
import qualified Crm.Shared.Direction        as DIR
import qualified Crm.Shared.Employee         as E
import qualified Crm.Shared.Task             as T
import qualified Crm.Shared.ExtraField       as EF

import qualified Crm.Data.MachineData        as MD
import qualified Crm.Data.Data               as D
import qualified Crm.Data.UpkeepData         as UD
import qualified Crm.Data.EmployeeData       as ED
import           Crm.Server
import           Crm.Router
import           Crm.Helpers                 (displayDate, rmap, parseSafely)
import qualified Crm.Validation              as V
import           Crm.Component.Form
import           Crm.Component.DatePicker    as DP
import           Crm.Types                   (DisplayedNote (..))

-- handler

startRouter :: Var D.AppState -> Fay CrmRouter
startRouter appVar = startedRouter where
  startedRouter = fmap CrmRouter $ BR.startRouter $ otherRoutes ++ appliedRoutes
  modify' newState = modify appVar (\appState -> appState { D.navigation = newState })
  withCompany' :: C.CompanyId
               -> ((C.Company, [CP.ContactPerson'], [(M.MachineId, M.Machine, C.CompanyId, MT.MachineTypeId,
                  MT.MachineType, Maybe CP.ContactPerson, Maybe M.MachineId, Maybe YMD.YearMonthDay, Maybe U.Upkeep)]) -> D.NavigationState)
               -> CrmRouter
               -> Fay ()
  withCompany' companyId newStateFun = 
    fetchCompany companyId $ \data' -> let
      newState = newStateFun data'
      in modify' newState
  (nowYear, nowMonth, nowDay) = M.day . M.now $ M.requireMoment
  nowYMD = YMD.YearMonthDay nowYear nowMonth nowDay YMD.DayPrecision

  appliedRoutes = map (\tuple -> rmap (\f r -> f (CrmRouter r) appVar) tuple) routes
  otherRoutes = [
    ("", \router _ -> let
      crmRouter = CrmRouter router
      in fetchFrontPageData C.NextService DIR.Asc (\data' -> modify appVar 
        $ \appState -> appState { D.navigation = D.FrontPage (C.NextService, DIR.Asc) data' }) crmRouter ) ,
    ("companies/:companyId/new-maintenance/:machineId", \router params -> let
      crmRouter = CrmRouter router
      companyIdText = head $ params
      machineIdText = head . tail $ params
      in case (C.CompanyId `onJust` parseSafely companyIdText, M.MachineId `onJust` parseSafely machineIdText) of
        (Just companyId, Just machineId) -> fetchUpkeepData companyId (\ud ->
          fetchEmployees (\employees -> let
            notCheckedUpkeepMachines = map (\(machineId',_,_,_) -> 
              (UM.newUpkeepMachine, machineId')) . filter (\(machineId',_,_,_) -> machineId' /= machineId) $ ud
            in modify' $ D.UpkeepScreen $ UD.UpkeepData (U.newUpkeep nowYMD, [(UM.newUpkeepMachine, machineId)])
              ud notCheckedUpkeepMachines
              newDatePickerData employees
              [] V.new companyId (Right . UD.UpkeepNew $ Nothing)) crmRouter ) crmRouter 
        _ -> modify' D.NotFound) ,
    ("daily-plan/:date/employee/:employee", \router params -> let
      crmRouter = CrmRouter router
      in case M.parse M.requireMoment . head $ params of
        Just (moment) -> let
          (year, month, day) = M.day moment
          ymd = YMD.YearMonthDay year month day (YMD.DayPrecision)
          employeeId = onJust E.EmployeeId . parseSafely . head . tail $ params
          in fetchDailyPlanData ymd employeeId (\data' ->
            fetchDailyPlanEmployees ymd (\dpe -> let
              day = (ymd, DP.DatePickerData ymd False (displayDate ymd))
              modifyAppvar employeeTasks = modify appVar $ \appState -> appState { D.navigation = D.DailyPlan day employeeTasks data' dpe }
              in case employeeId of
                Just employeeId' -> fetchMarkupTasks employeeId' (\tasks -> modifyAppvar $ Just (employeeId', tasks)) crmRouter
                Nothing -> modifyAppvar Nothing
                  ) crmRouter ) crmRouter
        Nothing -> modify' D.NotFound) ,
    ("home/:order/:direction", \router params -> let
      firstParam = head params
      secondParam = head $ tail params
      order = if firstParam == "CompanyName"
        then C.CompanyName
        else C.NextService
      direction = if secondParam == "Asc"
        then DIR.Asc
        else DIR.Desc
      crmRouter = CrmRouter router
      in fetchFrontPageData order direction (\data' ->
        modify appVar $ \appState -> appState { D.navigation = 
          D.FrontPage (order, direction) data' }) crmRouter )]

  newDatePickerData = DP.DatePickerData nowYMD False (displayDate nowYMD)

  routes = [
    serverDown' $-> (const . const $ modify appVar $ \appState ->
      appState { D.navigation = D.ServerDown }) ,
    login' $-> ( const . const $ 
      modify appVar $ \appState -> appState { D.navigation = D.Login "" False } ) ,
    dashboard' $-> ( const $
      fetchCompaniesForMap $ \companiesTriple -> 
        modify appVar $ \appState -> appState { D.navigation = D.Dashboard companiesTriple }) ,
    upkeepPhotos' $-> (const $
      fetchPlannedUpkeeps $ \plannedUpkeeps -> let
        navig = D.AddPhotoToUpkeepList plannedUpkeeps
        in modify appVar $ \appState ->
          appState { D.navigation = navig } ) ,
    upkeepPhotoAdd' $-> (\upkeepId ->
      fetchUpkeep upkeepId $ \(companyId, (upkeep, upkeepMachines, employeeIds), machines) -> let
        navig = D.AddPhotoToUpkeep upkeepId upkeep (C.Company "" "" "")
        in modify appVar $ \appState ->
          appState { D.navigation = navig }) ,
    extraFields' $-> (const $
      fetchExtraFieldSettings $ \list -> let
        makeIdsAssigned = map (\(fId, field) -> (EF.Assigned fId, field)) 
        withAssignedIds = map (\(enum, fields) -> (enum, makeIdsAssigned fields)) list
        in modify' $ D.ExtraFields 0 False MK.RotaryScrewCompressor withAssignedIds ) ,
    companyDetail' $-> \companyId' router ->
      case companyId' of
        Left _ -> modify appVar $ \appState -> appState {
          D.navigation = D.CompanyNew C.newCompany } 
        Right companyId ->
          fetchRecommendation companyId (\(lastUpkeep') -> let
            lastUpkeep = snd `onJust` lastUpkeep'
            in fetchCompany companyId (\(company, contactPersons, machines) -> let
              ignoreLinkage = map $ \(a,b,c,d,e,f,_,g,h) -> (a,b,c,d,e,f,g,h)
              in modify appVar $ \appState -> appState {
                D.navigation = D.CompanyDetail 
                  companyId company contactPersons Display (ignoreLinkage machines) lastUpkeep } ) router ) router ,
    newMachinePhase1' $-> \companyId ->
      withCompany'
        companyId
        (\_ ->
          D.MachineNewPhase1 Nothing (MT.newMachineType,[]) companyId) ,
    newContactPerson' $-> \companyId ->
      withCompany'
        companyId
        (\_ -> D.ContactPersonPage CP.newContactPerson Nothing companyId) ,
    machinesSchema' $-> \companyId -> 
      withCompany'
        companyId $
        \(_, _, machines) -> let
          pickMachines = map $ \(a,b,_,_,c,_,d,_,_) -> (a,b,c,d)
          in D.MachinesSchema $ pickMachines machines ,
    newMachinePhase2' $-> \companyId router -> do
      appState <- get appVar
      let
        machineTypeTuple = D.machineTypeFromPhase1 appState
        machineKind = MT.kind $ fst machineTypeTuple
        maybeMachineTypeId = D.maybeMachineIdFromPhase1 appState
        machine' = M.newMachine' Nothing
        machine = case machineKind of
          MK.RotaryScrewCompressor -> machine'
          _ -> machine' { M.mileagePerYear = MK.hoursInYear }
        machineTuple = (machine, showInt . M.mileagePerYear $ machine)
      fetchContactPersons companyId (\cps -> (fetchMachinesInCompany companyId $ \otherMachines -> 
        fetchExtraFieldSettings (\efSettings -> let
          extraFields'' = fromJust $ lookup machineKind efSettings
          extraFieldsAdapted = (\(a,b) -> (a,b, "")) `map` extraFields''
          in modify' $ D.MachineScreen $ MD.MachineData machineTuple machineTypeTuple (DP.DatePickerData 
            nowYMD False "") Nothing cps V.new Nothing otherMachines extraFieldsAdapted maybeMachineTypeId 
              (Right $ MD.MachineNew companyId (CP.newContactPerson, MD.ById))) router ) router ) router ,
    newMaintenance' $-> \companyId router -> 
      fetchUpkeepData companyId (\ud ->
        fetchEmployees (\employees -> let
          notCheckedUpkeepMachines = map (\(machineId,_,_,_) -> 
            (UM.newUpkeepMachine, machineId)) ud
          in modify' $ D.UpkeepScreen $ UD.UpkeepData (U.newUpkeep nowYMD, []) 
            ud notCheckedUpkeepMachines
            newDatePickerData employees 
            [] V.new companyId (Right . UD.UpkeepNew $ Nothing)) router ) router ,
    contactPersonList' $-> \companyId ->
      fetchContactPersons companyId $ \data' -> let
        ns = D.ContactPersonList companyId data'
        in modify' ns ,
    maintenances' $-> \companyId router ->
      fetchUpkeeps companyId (\upkeepsData -> fetchCompany companyId (\companyData -> let
        (_, _, machinesInCompany) = companyData
        pickMachine (machineId, machine, _, machineTypeId, machineType, _, _, _, _) = (machineId, machine, machineTypeId, machineType)
        ns = D.UpkeepHistory upkeepsData (map pickMachine machinesInCompany) companyId False []
        in modify' ns) router) router ,
    machineDetail' $-> \machineId router ->
      fetchMachine machineId
        (\(companyId, machine, machineTypeId, machineTypeTuple, 
            machineNextService, contactPersonId, upkeeps, otherMachineId, machineSpecificData, extraFields'') ->
          fetchMachinePhotos machineId (\photos ->
            let 
              machineTriple = (machine, showInt . M.mileagePerYear $ machine)
              startDateInCalendar = maybe nowYMD id (M.machineOperationStartDate machine)
            in fetchContactPersons companyId (\cps -> fetchMachinesInCompany companyId (\otherMachines -> 
              modify' $ D.MachineScreen $ MD.MachineData
                machineTriple machineTypeTuple (DP.DatePickerData startDateInCalendar False "")
                  contactPersonId cps V.new otherMachineId otherMachines extraFields'' (Just machineTypeId)
                    (Left $ MD.MachineDetail machineId machineNextService 
                      Display photos upkeeps companyId [])) router ) router ) router ) router ,
    plannedUpkeeps' $-> ( const $
      fetchPlannedUpkeeps $ \plannedUpkeeps'' -> let
        newNavigation = D.PlannedUpkeeps plannedUpkeeps''
        in modify appVar $ \appState -> 
          appState { D.navigation = newNavigation }) ,
    upkeepDetail' $-> \upkeepId router ->
      fetchUpkeep upkeepId ( \(companyId,(upkeep, upkeepMachines, employeeIds), machines) -> 
        fetchEmployees ( \employees -> let
          upkeep' = upkeep { U.upkeepClosed = True }
          upkeepDate = U.upkeepDate upkeep
          in modify' $ D.UpkeepScreen $ UD.UpkeepData (upkeep', upkeepMachines) machines
            (notCheckedMachines' machines upkeepMachines) (DP.DatePickerData upkeepDate False (displayDate upkeepDate)) employees 
            (map Just employeeIds) V.new companyId (Left $ UD.UpkeepClose upkeepId Note) ) router ) router ,
    machineTypesList' $-> ( const $ 
      fetchMachineTypes $ \result -> modify' $ D.MachineTypeList result ) ,
    machineTypeEdit' $-> \machineTypeId router ->
      fetchMachinesForType machineTypeId (\machines ->
        fetchMachineTypeById machineTypeId ((\(_, machineType, machinesCount, upkeepSequences) ->
          let upkeepSequences' = map ((\us -> (us, showInt . US.repetition $ us ))) upkeepSequences
          in modify' $ D.MachineTypeEdit machineTypeId machinesCount (machineType, upkeepSequences') machines) . fromJust) router ) router ,
    replanUpkeep' $-> \upkeepId router ->
      fetchUpkeep upkeepId (\(companyId, (upkeep, upkeepMachines, employeeIds), machines) ->
        fetchEmployees (\employees ->
          modify' $ D.UpkeepScreen $ UD.UpkeepData (upkeep, upkeepMachines) machines
            (notCheckedMachines' machines upkeepMachines) 
            (DP.DatePickerData (U.upkeepDate upkeep) False (displayDate . U.upkeepDate $ upkeep))
            employees (map Just employeeIds) V.new companyId (Right . UD.UpkeepNew . Just $ upkeepId) ) router ) router ,
    contactPersonEdit' $-> \contactPersonId ->
      fetchContactPerson contactPersonId $ \(cp, companyId) -> 
        modify' $ D.ContactPersonPage cp (Just contactPersonId) companyId ,
    employees' $-> ( const $
      fetchEmployees $ \employees -> modify' $ D.EmployeeList employees ) ,
    editEmployee' $-> \employeeId' router -> fetchTakenColours ( \takenColours ->
      case employeeId' of
        Left _ -> modify' $ D.EmployeeManage $ ED.EmployeeData E.newEmployee Nothing takenColours
        Right employeeId -> 
          fetchEmployee employeeId ( \employee ->
            modify' $ D.EmployeeManage $ ED.EmployeeData employee (Just employeeId) takenColours ) router ) router ,
    employeeTasks' $-> \employeeId ->
      fetchTasks employeeId $ \openTasks closedTasks -> let 
        e = D.EmployeeTasksScreen $ ED.EmployeeTasksData employeeId openTasks closedTasks
        in modify' e ,
    newEmployeeTask' $-> \employeeId ->
      const $ modify appVar $ \appState -> appState {
        D.navigation = D.EmployeeTaskScreen $ ED.EmployeeTaskData (T.newTask { T.startDate = nowYMD }) 
        (DP.DatePickerData nowYMD False (displayDate nowYMD)) (ED.New employeeId) } ,
    editEmployeeTask' $-> \taskId ->
      fetchTask taskId $ \task -> modify' $ D.EmployeeTaskScreen $ ED.EmployeeTaskData task
        (DP.DatePickerData (T.startDate task) False (displayDate . T.startDate $ task)) (ED.Edit taskId) ,
    employeeTask' $-> \taskId ->
      fetchTask taskId $ \task -> modify' $ D.EmployeeTaskScreen $ ED.EmployeeTaskData task 
        (DP.DatePickerData (T.startDate task) False (displayDate . T.startDate $ task)) (ED.Close taskId) ]

notCheckedMachines' :: [(M.MachineId,t1,t2,t3)] -> [(t4,M.MachineId)] -> [(UM.UpkeepMachine, M.MachineId)]
notCheckedMachines' machines upkeepMachines = let 
  addNotCheckedMachine acc element = let 
    (machineId,_,_,_) = element
    machineChecked = find (\(_,machineId') -> 
      machineId == machineId') upkeepMachines
    in case machineChecked of
      Nothing -> (UM.newUpkeepMachine,machineId) : acc
      _ -> acc
  in foldl addNotCheckedMachine [] machines
