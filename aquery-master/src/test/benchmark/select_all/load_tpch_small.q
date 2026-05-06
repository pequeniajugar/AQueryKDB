/ Update this path before running.
csvLine:`:/Users/tianxin/projects/nyu/ms2/independent_study/data/tpch/data_10_7/lineitem.csv;

lineitem:(("JJIIFFFFSSSSSSSS ";enlist ",") 0: csvLine);
lineitem:`l_orderkey`l_partkey`l_suppkey`l_linenumber`l_quantity`l_extendedprice`l_discount`l_tax`l_returnflag`l_linestatus`l_shipdate`l_commitdate`l_receiptdate`l_shipinstruct`l_shipmode`l_comment xcol lineitem;
