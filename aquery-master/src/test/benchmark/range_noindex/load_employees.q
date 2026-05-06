/ Load employees data for range no-index benchmarks.
/ Override with EMPLOYEES_CSV if you want to run a different scale.
employeeFile:$[(0<count getenv `EMPLOYEES_CSV);getenv `EMPLOYEES_CSV;"/Users/tianxin/projects/nyu/ms2/independent_study/data/employees/employeesindex_10_5.csv"];

employees:([] ssnum:`int$(); name:`symbol$(); lat:`int$(); longitude:`int$(); hundreds1:`int$(); hundreds2:`int$());
csvLines:1 _ read0 hsym `$employeeFile;
employeeData:("ISIIII";enlist ",") 0:csvLines;
employees:employees upsert `ssnum`name`lat`longitude`hundreds1`hundreds2 xcol employeeData;
