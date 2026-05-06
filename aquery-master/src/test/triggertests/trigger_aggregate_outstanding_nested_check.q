\l /tmp/trigger_aggregate_outstanding_nested.q

v1:first exec amount from vendorOutstanding where vendorid=`V1;
v2:first exec amount from vendorOutstanding where vendorid=`V2;
s1:first exec amount from storeOutstanding where storeid=`S1;
s2:first exec amount from storeOutstanding where storeid=`S2;

show `ok`v1`v2`s1`s2!(1b;v1;v2;s1;s2);

if[v1<>1015; '"vendor V1 mismatch"];
if[v2<>2014; '"vendor V2 mismatch"];
if[s1<>115; '"store S1 mismatch"];
if[s2<>214; '"store S2 mismatch"];

exit 0;
