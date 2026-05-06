/ Load TPCH lineitem from a q binary table file.
/ Override with LINEITEM_BIN if you want to run a different scale/path.
binLine:`$":", $[(0<count getenv `LINEITEM_BIN);getenv `LINEITEM_BIN;"/Users/tianxin/projects/nyu/ms2/independent_study/data/tpch/data_10_7/lineitem.bin"];

lineitem:get binLine;
lineitem:`l_orderkey`l_partkey`l_suppkey`l_linenumber`l_quantity`l_extendedprice`l_discount`l_tax`l_returnflag`l_linestatus`l_shipdate`l_commitdate`l_receiptdate`l_shipinstruct`l_shipmode`l_comment xcol lineitem;
