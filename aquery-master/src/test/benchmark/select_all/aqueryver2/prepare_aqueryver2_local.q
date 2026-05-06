/ Build local q data once from CSV so benchmark runs do not include CSV import time.
/ Run manually once before using base_aqueryver2.sh.

csvLine:`:/Users/tianxin/projects/nyu/ms2/independent_study/data/tpch/data_10_5/lineitem.csv;
localLineitemFile:`:/Users/tianxin/projects/nyu/ms2/independent_study/qdb/lineitem10_5.q;

system "mkdir -p /Users/tianxin/projects/nyu/ms2/independent_study/github/AQuery/aquery-master/src/test/benchmark/select_all/aqueryver2/localdb";

lineitem:(("JJIIFFFFSSSSSSSS ";enlist ",") 0: csvLine);
lineitem:`l_orderkey`l_partkey`l_suppkey`l_linenumber`l_quantity`l_extendedprice`l_discount`l_tax`l_returnflag`l_linestatus`l_shipdate`l_commitdate`l_receiptdate`l_shipinstruct`l_shipmode`l_comment xcol lineitem;

localLineitemFile set lineitem;
show count lineitem;
