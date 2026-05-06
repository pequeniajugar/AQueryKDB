/ Load scan-can-win employees data for AQuery benchmarks.
/ Override with SCANWIN_CSV to run a different scale.
itemFile:$[(0<count getenv `SCANWIN_CSV);getenv `SCANWIN_CSV;"/Users/tianxin/projects/nyu/ms2/independent_study/data/employees/scanwin_multipoint_10_7.csv"];

employees:([] onepercent1:`int$(); onepercent2:`int$(); fivepercent1:`int$(); fivepercent2:`int$(); tenpercent1:`int$(); tenpercent2:`int$(); twentypercent1:`int$(); twentypercent2:`int$());
csvLines:1 _ read0 hsym `$itemFile;
data:("IIIIIIII";enlist ",") 0:csvLines;
employees:employees upsert `onepercent1`onepercent2`fivepercent1`fivepercent2`tenpercent1`tenpercent2`twentypercent1`twentypercent2 xcol data;

scanwin_idx_onepercent1:update onepercent1:`g#onepercent1 from employees;
scanwin_idx_fivepercent1:update fivepercent1:`g#fivepercent1 from employees;
scanwin_idx_tenpercent1:update tenpercent1:`g#tenpercent1 from employees;
scanwin_idx_twentypercent1:update twentypercent1:`g#twentypercent1 from employees;
