#!/bin/bash
STR='[{"instance":"Machine","machineOperationStartDate":{"precision":{"instance":"DayPrecision"},"year":1970,"month":5,"day":20,"instance":"YearMonthDay"},"initialMileage":100,"mileagePerYear":10000},{"slot1":[{"instance":"MachineType","machineTypeName":"bk 500","machineTypeManufacturer":"remeza","upkeepPerMileage":500},[{"instance":"UpkeepSequence","displayOrdering":1,"label":"4000mth","repetition":500},{"instance":"UpkeepSequence","displayOrdering":2,"label":"General","repetition":10000}]],"instance":"MyMachineType"}]'
curl -X POST -H "Content-Type: application/json" -d "${STR}" http://crm/api/v1.0.0/companies/1/machines/
