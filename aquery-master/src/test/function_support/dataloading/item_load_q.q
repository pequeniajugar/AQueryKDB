/ replace this with your actual csv path before running
itemFile:"/Users/tianxin/projects/nyu/ms1/research/dbtunning_experiements/data_generation/store/item_10_8.csv";

/ item(itemnum, price)
item:([] itemnum:`long$(); price:`float$());

/ load csv into item using the declared schema
data:(upper exec t from meta `item; enlist ",") 0: hsym `$itemFile;
`item upsert data;

show item;
