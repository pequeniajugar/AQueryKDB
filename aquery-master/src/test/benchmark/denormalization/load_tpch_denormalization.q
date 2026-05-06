tblRegion:`:/Users/tianxin/projects/nyu/ms2/independent_study/data/tpch/data_10_7/region.tbl;
rlines:read0 tblRegion;
rrows:"|" vs' rlines;
rrows:-1 _' rrows;
region:([] r_regionkey:`$ rrows[;0]; r_name:`$ rrows[;1]; r_comment:`$ rrows[;2]);

tblNation:`:/Users/tianxin/projects/nyu/ms2/independent_study/data/tpch/data_10_7/nation.tbl;
nlines:read0 tblNation;
nrows:"|" vs' nlines;
nrows:-1 _' nrows;
nation:([] n_nationkey:`$ nrows[;0]; n_name:`$ nrows[;1]; n_regionkey:`$ nrows[;2]; n_comment:`$ nrows[;3]);

tblSupplier:`:/Users/tianxin/projects/nyu/ms2/independent_study/data/tpch/data_10_7/supplier.tbl;
slines:read0 tblSupplier;
srows:"|" vs' slines;
srows:-1 _' srows;
supplier:([] s_suppkey:`$ srows[;0]; s_name:`$ srows[;1]; s_address:`$ srows[;2]; s_nationkey:`$ srows[;3]; s_phone:`$ srows[;4]; s_acctbal:"f"$ srows[;5]; s_comment:`$ srows[;6]);

tblLine:`:/Users/tianxin/projects/nyu/ms2/independent_study/data/tpch/data_10_7/lineitem.tbl;
llines:read0 tblLine;
lrows:"|" vs' llines;
lrows:-1 _' lrows;
lineitem:([] l_orderkey:`$ lrows[;0]; l_partkey:`$ lrows[;1]; l_suppkey:`$ lrows[;2]; l_linenumber:`$ lrows[;3]; l_quantity:"f"$ lrows[;4]; l_extendedprice:"f"$ lrows[;5]; l_discount:"f"$ lrows[;6]; l_tax:"f"$ lrows[;7]; l_returnflag:`$ lrows[;8]; l_linestatus:`$ lrows[;9]; l_shipdate:`$ lrows[;10]; l_commitdate:`$ lrows[;11]; l_receiptdate:`$ lrows[;12]; l_shipinstruct:`$ lrows[;13]; l_shipmode:`$ lrows[;14]; l_comment:`$ lrows[;15]);

region:`r_regionkey xkey region;
`dom_regionkey set exec r_regionkey from key region;
nation:`n_nationkey xkey nation;
nation:update n_regionkey:`dom_regionkey$n_regionkey from nation;
`dom_nationkey set exec n_nationkey from key nation;
supplier:`s_suppkey xkey supplier;
supplier:update s_nationkey:`dom_nationkey$s_nationkey from supplier;
`dom_suppkey set exec s_suppkey from key supplier;
lineitem:update l_suppkey:`dom_suppkey$l_suppkey from lineitem;

dom_suppkey:supplier;
dom_nationkey:nation;
dom_regionkey:region;
