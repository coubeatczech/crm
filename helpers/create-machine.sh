#!/bin/bash
STR='[{"instance":"Machine","machineOperationStartDate":{"precision":{"instance":"DayPrecision"},"year":1970,"month":5,"day":20,"instance":"YearMonthDay"},"initialMileage":100,"mileagePerYear":10000},{"slot1":1,"instance":"MyInt"}]'
curl -X POST -H "Content-Type: application/json" -d "${STR}" http://crm/api/v1.0.0/companies/1/machines/
