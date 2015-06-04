module Crm.Server (
  createCompany , 
  createMachine , 
  createUpkeep , 
  createEmployee ,
  createContactPerson ,

  updateUpkeep ,
  updateMachine , 
  updateCompany ,
  updateContactPerson ,
  updateEmployee ,
  updateMachineType , 

  saveExtraFieldSettings ,

  uploadPhotoData ,
  uploadPhotoMeta ,

  fetchExtraFieldSettings ,
  fetchMachine , 
  fetchMachinePhotos ,
  fetchMachinesInCompany ,
  fetchUpkeeps , 
  fetchPlannedUpkeeps , 
  fetchFrontPageData , 
  fetchMachineType ,
  fetchMachineTypeById ,
  fetchMachineTypes ,
  fetchMachineTypesAutocomplete ,
  fetchMachineTypesManufacturer ,
  fetchUpkeep ,
  fetchEmployees ,
  fetchEmployee ,
  fetchCompany ,
  fetchContactPersons ,
  fetchContactPerson ,
  fetchCompaniesForMap ,
  fetchPhoto ,

  deleteUpkeep ,
  deleteCompany ,
  deleteMachine ,
  deletePhoto ,
  deleteContactPerson ,

  testEmployeesPage ,
  status ) where

import           FFI                       (ffi, Automatic, Defined(Defined))
import           Prelude                   hiding (putStrLn)
import           Data.Text                 (Text, (<>), unpack, pack)
import           Data.LocalStorage
import           Data.Defined              (fromDefined, toDefined)

import qualified JQuery                    as JQ

import qualified Crm.Shared.Company        as C
import qualified Crm.Shared.ContactPerson  as CP
import qualified Crm.Shared.Upkeep         as U
import qualified Crm.Shared.Machine        as M
import qualified Crm.Shared.MachineType    as MT
import qualified Crm.Shared.MachineKind    as MK
import qualified Crm.Shared.UpkeepMachine  as UM
import qualified Crm.Shared.Api            as A
import qualified Crm.Shared.Photo          as P
import qualified Crm.Shared.PhotoMeta      as PM
import qualified Crm.Shared.YearMonthDay   as YMD
import qualified Crm.Shared.Employee       as E
import qualified Crm.Shared.UpkeepSequence as US
import qualified Crm.Shared.Direction      as DIR
import qualified Crm.Shared.ExtraField     as EF
import           Crm.Shared.MyMaybe

import           Crm.Helpers               (File, rmap, encodeB64, encodeURIComponent)
import qualified Crm.Router                as R


data Items


-- methods used

post :: Text
post = pack "POST"

put :: Text
put = pack "PUT"

delete :: Text
delete = pack "DELETE"

get :: Text
get = pack "GET"


-- helpers

status :: JQ.JQXHR -> Int
status = ffi " %1['status'] "

count1000 :: String
count1000 = "?count=1000"

-- | Unwrap outermost layer of the fetched list in order to get to the data
items :: Items -> Automatic a
items = ffi " %1['items'] "

apiRoot :: Text
apiRoot = pack "/api/v1.0.0/"

withPassword :: Maybe Text
             -> (JQ.AjaxSettings a b -> Fay ())
             -> Fay ()
withPassword maybePassword callback = do
  password' <- case maybePassword of
    Just password -> return $ Defined password
    Nothing -> getLocalStorage $ pack "password"
  let 
    password = case fromDefined password' of
      Just passInLocalStorage -> passInLocalStorage
      Nothing -> let
        failingPassword = ""
        in pack failingPassword 
    passwordSettings = JQ.defaultAjaxSettings {
    JQ.headers = Defined (JQ.makeRqObj (pack "Authorization") (encodeB64 password)) }
  callback passwordSettings

passwordAjax :: Text
             -> (Automatic a -> Fay ())
             -> Maybe b
             -> Text
             -> (Maybe (JQ.JQXHR -> Maybe Text -> Maybe Text -> Fay ()))
             -> Maybe Text
             -> Fay ()
passwordAjax url callback' inputData method' onError maybePassword = 
  withPassword maybePassword $ \passwordSettings -> let
    commonSettings = passwordSettings {
      JQ.success = Defined callback' ,
      JQ.error' = toDefined onError ,
      JQ.type' = Defined method' ,
      JQ.url = Defined $ apiRoot <> url }
    in case inputData of
      Nothing -> let
        in JQ.ajax' commonSettings
      Just (data') -> let
        inputSettings = commonSettings {
          JQ.data' = Defined data' ,
          JQ.processData = Defined False ,
          JQ.contentType = Defined $ pack "application/json" ,
          JQ.dataType = Defined $ pack "json" }
        in JQ.ajax' inputSettings

inputAjax :: Text
          -> (a -> Fay ())
          -> b
          -> Text
          -> Fay ()
inputAjax t c i m = passwordAjax
  t c (Just i) m Nothing Nothing

postAjax :: Text
         -> b
         -> (a -> Fay ())
         -> Fay ()
postAjax t d c = inputAjax t c d post

putAjax :: Text
        -> b
        -> Fay ()
        -> Fay ()
putAjax t d c = inputAjax t (const c) d put

getAjax :: Text
        -> (a -> Fay ())
        -> Fay ()
getAjax t c = passwordAjax t c Nothing get Nothing Nothing

getManyAjax :: Text
            -> (a -> Fay ())
            -> Fay ()
getManyAjax t c = getAjax (t <> pack count1000) (c . items)

deleteAjax :: Text
           -> Fay ()
           -> Fay ()
deleteAjax t c = passwordAjax t (const c) Nothing delete Nothing Nothing


-- deletions

deleteCompany :: C.CompanyId
              -> Fay ()
              -> Fay ()
deleteCompany companyId = deleteAjax
  (pack $ A.companies ++ "/" ++ A.single ++ "/" ++ (show $ C.getCompanyId companyId))

deleteUpkeep :: U.UpkeepId
             -> Fay ()
             -> Fay ()
deleteUpkeep upkeepId = deleteAjax
  (pack $ A.upkeep ++ "/" ++ A.single ++ "/" ++ (show $ U.getUpkeepId upkeepId))

deleteMachine :: M.MachineId
              -> Fay ()
              -> Fay ()
deleteMachine machineId = deleteAjax
  (pack $ A.machines ++ "/" ++ (show $ M.getMachineId machineId))

deletePhoto :: P.PhotoId
            -> Fay ()
            -> Fay ()
deletePhoto pId = deleteAjax
  (pack $ A.photos ++ "/" ++ (show $ P.getPhotoId pId))

deleteContactPerson :: CP.ContactPersonId
                    -> Fay ()
                    -> Fay ()
deleteContactPerson cpId = deleteAjax
  (pack $ A.contactPersons ++ "/" ++ (show $ CP.getContactPersonId cpId))

-- fetching of data from server

fetchPhoto :: P.PhotoId
           -> Text
fetchPhoto photoId = pack $ A.photos ++ "/" ++ (show $ P.getPhotoId photoId)

fetchMachineTypesManufacturer :: Text -- ^ the string user typed
                              -> ([Text] -> Fay ()) -- callback filled with option that the user can pick
                              -> Fay ()
fetchMachineTypesManufacturer text = getManyAjax
  (pack $ A.machineTypes ++ "/" ++ A.autocompleteManufacturer ++ "/" ++ unpack 
    (encodeURIComponent . encodeURIComponent $ text))

fetchMachineTypesAutocomplete :: Text -- ^ the string user typed
                              -> ([Text] -> Fay ()) -- callback filled with option that the user can pick
                              -> Fay ()
fetchMachineTypesAutocomplete text = getManyAjax
  (pack $ A.machineTypes ++ "/" ++ A.autocomplete ++ "/" ++ unpack 
    (encodeURIComponent . encodeURIComponent $ text))

fetchMachineTypes :: ([(MT.MachineType', Int)] -> Fay ()) -> Fay ()
fetchMachineTypes = getManyAjax
  (pack $ A.machineTypes)

fetchMachineTypeById :: MT.MachineTypeId
                     -> (Maybe (MT.MachineTypeId, MT.MachineType, [US.UpkeepSequence]) -> Fay ())
                     -> Fay ()
fetchMachineTypeById mtId callback = getAjax
  (pack $ A.machineTypes ++ "/" ++ A.byId ++ "/" ++ (show $ MT.getMachineTypeId mtId))
  (callback . toMaybe)

fetchMachineType :: Text -- ^ machine type exact match
                 -> (Maybe (MT.MachineTypeId, MT.MachineType, [US.UpkeepSequence]) -> Fay ()) -- ^ callback
                 -> Fay ()
fetchMachineType machineTypeName callback = getAjax
  (pack $ A.machineTypes ++ "/" ++ A.byName ++ "/" ++ unpack (
    encodeURIComponent . encodeURIComponent $ machineTypeName))
  (callback . toMaybe)

fetchEmployees :: ([E.Employee'] -> Fay ())
               -> Fay ()
fetchEmployees callback = getManyAjax
  (pack A.employees)
  callback

fetchUpkeep :: U.UpkeepId -- ^ upkeep id
            -> ((C.CompanyId, (U.Upkeep, Maybe E.EmployeeId, [UM.UpkeepMachine']), [(M.MachineId, M.Machine, 
                 C.CompanyId, MT.MachineTypeId, MT.MachineType)]) -> Fay ()) 
            -> Fay ()
fetchUpkeep upkeepId callback = getAjax
  (pack $ A.upkeep ++ "/" ++ A.single ++ "/" ++ (show $ U.getUpkeepId upkeepId))
  (callback . (\(a,(u,u2,u3),b) -> (a,(u,toMaybe u2,u3),b)))

fetchUpkeeps :: C.CompanyId -- ^ company id
             -> ([(U.UpkeepId, U.Upkeep, [(UM.UpkeepMachine, MT.MachineType, M.MachineId)], 
                Maybe E.Employee')] -> Fay ()) -- ^ callback
             -> Fay ()
fetchUpkeeps companyId callback = getManyAjax
  (pack $ A.companies ++ "/" ++ A.single ++ "/" ++ (show $ C.getCompanyId companyId) ++ "/" ++ A.upkeep)
  (callback . (map (\(a,b,c,employee) -> (a,b,c,toMaybe employee))))
  
fetchMachinePhotos :: M.MachineId
                   -> ([(P.PhotoId, PM.PhotoMeta)] -> Fay ())
                   -> Fay ()
fetchMachinePhotos machineId callback = getManyAjax
  (pack $ A.machines ++ "/" ++ (show $ M.getMachineId machineId) ++ "/" ++ A.photos)
  callback

fetchMachinesInCompany :: C.CompanyId
                       -> ([(M.MachineId, M.Machine)] -> Fay ())
                       -> Fay ()
fetchMachinesInCompany companyId = getManyAjax
  (pack $ A.companies ++ "/" ++ A.single ++ "/" ++ (show $ C.getCompanyId companyId) ++ "/" ++ A.machines)

fetchExtraFieldSettings :: ([(MK.MachineKindEnum, [(EF.ExtraFieldId, MK.MachineKindSpecific)])] -> Fay ())
                        -> Fay ()
fetchExtraFieldSettings = getAjax
  (pack $ A.machineKind ++ "/()")

fetchMachine :: M.MachineId -- ^ machine id
             -> ((C.CompanyId, M.Machine, MT.MachineTypeId,
                (MT.MachineType, [US.UpkeepSequence]), YMD.YearMonthDay, Maybe CP.ContactPersonId,
                [(U.UpkeepId, U.Upkeep, UM.UpkeepMachine, Maybe E.Employee)], Maybe M.MachineId, 
                MK.MachineKindEnum, [(EF.ExtraFieldId, MK.MachineKindSpecific, Text)]) -> Fay()) -- ^ callback
             -> Fay ()
fetchMachine machineId callback = let
  fun2 (a,b,c,d) = (a,b,c,toMaybe d)
  fun ((a,b,c,d),(e,e1,g,g2,f,l)) = (a,b,c,d,e,toMaybe e1,map fun2 g,toMaybe g2,f,l)
  in getAjax
    (pack $ A.machines ++ "/" ++ (show $ M.getMachineId machineId))
    (callback . fun)


fetchEmployee :: E.EmployeeId
              -> (E.Employee -> Fay ())
              -> Fay ()
fetchEmployee employeeId = getAjax
  (pack $ A.employees ++ "/" ++ (show $ E.getEmployeeId employeeId))

fetchContactPerson :: CP.ContactPersonId
                   -> ((CP.ContactPerson, C.CompanyId) -> Fay ())
                   -> Fay ()
fetchContactPerson contactPersonId = getAjax
  (pack $ A.contactPersons ++ "/" ++ (show $ CP.getContactPersonId contactPersonId))

fetchContactPersons :: C.CompanyId
                    -> ([(CP.ContactPersonId, CP.ContactPerson)] -> Fay ())
                    -> Fay ()
fetchContactPersons companyId = getManyAjax
  (pack $ A.companies ++ "/" ++ A.single ++ "/" ++ (show $ C.getCompanyId companyId) ++ "/" ++ A.contactPersons)

fetchCompany :: C.CompanyId -- ^ company id
             -> ((C.Company, [(M.MachineId, M.Machine, C.CompanyId, MT.MachineTypeId, 
                MT.MachineType, Maybe CP.ContactPerson, Maybe M.MachineId, YMD.YearMonthDay)]) -> Fay ()) -- ^ callback
             -> Fay ()
fetchCompany companyId callback = getAjax
  (pack $ A.companies ++ "/" ++ A.single ++ "/" ++ (show $ C.getCompanyId companyId))
  (callback . (rmap (map (\((a,b,c,d,e,f,g),h) -> (a,b,c,d,e,toMaybe f,toMaybe g,h)))))

fetchFrontPageData :: C.OrderType
                   -> DIR.Direction
                   -> R.CrmRouter
                   -> ([(C.CompanyId, C.Company, Maybe YMD.YearMonthDay)] -> Fay ())
                   -> Fay ()
fetchFrontPageData order direction router callback = 
  let
    lMb [] = []
    lMb ((a,b,x) : xs) = (a,b,toMaybe x) : lMb xs
  in passwordAjax
    (pack $ A.companies ++ count1000 ++ "&order=" ++ (case order of
      C.CompanyName -> "CompanyName"
      C.NextService -> "NextService") ++ "&direction=" ++ (case direction of
      DIR.Asc -> "Asc"
      DIR.Desc -> "Desc"))
    (callback . lMb . items)
    Nothing
    get
    (Just $ \jqxhr _ _ -> if status jqxhr == 401
      then R.navigate R.login router
      else return ())
    Nothing

fetchPlannedUpkeeps :: ([(U.UpkeepId, U.Upkeep, C.CompanyId, C.Company)] -> Fay ())
                    -> Fay ()
fetchPlannedUpkeeps = getManyAjax
  (pack $ A.upkeep ++ "/" ++ A.planned)

fetchCompaniesForMap :: ([(C.CompanyId, C.Company, Maybe YMD.YearMonthDay, Maybe C.Coordinates)] -> Fay ())
                     -> Fay ()
fetchCompaniesForMap callback = getManyAjax
  (pack $ A.companies ++ "/" ++ A.map')
  (callback . (map (\(a,b,c,d) -> (a,b,toMaybe c,toMaybe d))))


-- creations

createCompany :: C.Company
              -> Maybe C.Coordinates
              -> (C.CompanyId -> Fay ())
              -> Fay ()
createCompany company coordinates = postAjax
  (pack $ A.companies)
  (company, toMyMaybe coordinates)

createMachine :: M.Machine 
              -> C.CompanyId
              -> MT.MyEither
              -> Maybe CP.ContactPersonId
              -> Maybe M.MachineId
              -> [(EF.ExtraFieldId, Text)]
              -> Fay ()
              -> Fay ()
createMachine machine companyId machineType contactPersonId linkedMachineId extraFields callback = postAjax
  (pack $ A.companies ++ "/" ++ A.single ++ "/" ++ (show $ C.getCompanyId companyId) ++ "/" ++ A.machines)
  (machine, machineType, toMyMaybe contactPersonId, toMyMaybe linkedMachineId, extraFields)
  (const callback)

createUpkeep :: (U.Upkeep, [UM.UpkeepMachine'], Maybe E.EmployeeId)
             -> C.CompanyId -- ^ company id
             -> Fay ()
             -> Fay ()
createUpkeep (newUpkeep, upkeepMachines, maybeEmployeeId) companyId callback = postAjax
  (pack $ A.companies ++ "/" ++ A.single ++ "/" ++ (show $ C.getCompanyId companyId) ++ "/" ++ A.upkeep)
  (newUpkeep, upkeepMachines, toMyMaybe maybeEmployeeId)
  (const callback)

createEmployee :: E.Employee
               -> Fay ()
               -> Fay ()
createEmployee employee callback = postAjax
  (pack $ A.employees)
  employee
  (const callback)

createContactPerson :: C.CompanyId
                    -> CP.ContactPerson
                    -> Fay ()
                    -> Fay ()
createContactPerson companyId contactPerson callback = postAjax
  (pack $ A.companies ++ "/" ++ A.single ++ "/" ++ (show $ C.getCompanyId companyId) ++ "/" ++ A.contactPersons)
  contactPerson
  (const callback)


-- updations

updateEmployee :: E.EmployeeId
               -> E.Employee
               -> Fay ()
               -> Fay ()
updateEmployee employeeId employee = putAjax
  (pack $ A.employees ++ "/" ++ (show $ E.getEmployeeId employeeId))
  employee

updateContactPerson :: CP.ContactPersonId
                    -> CP.ContactPerson
                    -> Fay ()
                    -> Fay ()
updateContactPerson cpId cp = putAjax
  (pack $ A.contactPersons ++ "/" ++ (show $ CP.getContactPersonId cpId))
  cp

updateCompany :: C.CompanyId
              -> C.Company
              -> Maybe C.Coordinates
              -> Fay ()
              -> Fay ()
updateCompany companyId company coordinates = putAjax
  (pack $ A.companies ++ "/" ++ A.single ++ "/" ++ (show $ C.getCompanyId companyId))
  (company, toMyMaybe coordinates)

updateUpkeep :: (U.Upkeep', Maybe E.EmployeeId)
             -> Fay ()
             -> Fay ()
updateUpkeep ((upkeepId, upkeep, upkeepMachines),maybeEmployeeId) = putAjax
  (pack $ A.upkeep ++ "/" ++ A.single ++ "/" ++ (show $ U.getUpkeepId upkeepId))
  (upkeep, upkeepMachines, toMyMaybe maybeEmployeeId)

updateMachineType :: (MT.MachineTypeId, MT.MachineType, [US.UpkeepSequence])
                  -> Fay ()
                  -> Fay ()
updateMachineType (machineTypeId, machineType, upkeepSequences) = putAjax
  (pack $ A.machineTypes ++ "/" ++ A.byId ++ "/" ++ (show $ MT.getMachineTypeId machineTypeId))
  (machineType, upkeepSequences)

updateMachine :: M.MachineId -- ^ machine id
              -> M.Machine
              -> Maybe M.MachineId -- ^ linked machine id
              -> Maybe CP.ContactPersonId
              -> [(EF.ExtraFieldId, Text)]
              -> Fay ()
              -> Fay ()
updateMachine machineId machine linkedMachineId contactPersonId machineSpecificData = putAjax
  (pack $ A.machines ++ "/" ++ (show $ M.getMachineId machineId))
  (machine, toMyMaybe linkedMachineId, toMyMaybe contactPersonId, machineSpecificData)


-- others

saveExtraFieldSettings :: [(MK.MachineKindEnum, [(EF.ExtraFieldIdentification, MK.MachineKindSpecific)])]
                       -> Fay ()
                       -> Fay ()
saveExtraFieldSettings data' = putAjax
  (pack $ A.machineKind ++ "/()")
  data'

uploadPhotoData :: File
                -> M.MachineId
                -> (P.PhotoId -> Fay ())
                -> Fay ()
uploadPhotoData fileContents machineId callback = withPassword Nothing $ \settings ->
  JQ.ajax' $ settings {
    JQ.success = Defined callback ,
    JQ.data' = Defined fileContents ,
    JQ.url = Defined $ pack (A.machines ++ "/" ++ (show $ M.getMachineId machineId) ++ "/" ++ A.photos) ,
    JQ.type' = Defined post ,
    JQ.processData = Defined False ,
    JQ.contentType = Defined $ pack "application/x-www-form-urlencoded" }

uploadPhotoMeta :: PM.PhotoMeta
                -> P.PhotoId
                -> Fay ()
                -> Fay ()
uploadPhotoMeta photoMeta photoId = putAjax
  (pack $ A.photoMeta ++ "/" ++ (show $ P.getPhotoId photoId))
  photoMeta

-- | just ping the server if it works
testEmployeesPage :: Text
                  -> Fay ()
                  -> (JQ.JQXHR -> Maybe Text -> Maybe Text -> Fay ())
                  -> Fay ()
testEmployeesPage password' success error' = passwordAjax 
  (pack A.employees)
  (const success)
  Nothing
  get
  (Just error')
  (Just password')
