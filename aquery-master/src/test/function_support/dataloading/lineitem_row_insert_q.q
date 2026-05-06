/ replace this with your actual csv path before running
csvFile:"/Users/tianxin/projects/nyu/ms1/research/dbtunning_experiements/data_generation/employees/employeesindex_10_8.csv";

/ employees(ssnum, name, lat, long, hundreds1, hundreds2)
employeeCols:`ssnum`name`lat`long`hundreds1`hundreds2;
employees:([] 
  ssnum:`int$();
  name:`symbol$();
  lat:`int$();
  long:`int$();
  hundreds1:`int$();
  hundreds2:`int$()
  );

/ load the whole csv using the requested parse spec
/ q typed csv loading treats the first line as header, so prepend one explicitly
header:"ssnum,name,lat,long,hundreds1,hundreds2";
lines:read0 hsym `$csvFile;
rows:("ISIIII";enlist ",") 0: (enlist header),lines;

/ insert one row at a time from the typed table
employees:0#rows;
{`employees upsert 1#x _ rows} each til count rows;

show employees;
