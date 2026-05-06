denormFile:$[(0<count getenv `DENORM_TBL);getenv `DENORM_TBL;$[(0<count getenv `DENORM_CSV);getenv `DENORM_CSV;"/Users/tianxin/projects/nyu/ms2/independent_study/data/tpch/data_10_7/lineitemdenormalized.tbl"]];
denormLines:read0 hsym `$denormFile;
denormData:("SSSSFFFFSSSSSSSSS";enlist "|") 0:denormLines;
lineitemdenormalized:`l_orderkey`l_partkey`l_suppkey`l_linenumber`l_quantity`l_extendedprice`l_discount`l_tax`l_returnflag`l_linestatus`l_shipdate`l_commitdate`l_receiptdate`l_shipinstruct`l_shipmode`l_comment`r_region xcol denormData;
