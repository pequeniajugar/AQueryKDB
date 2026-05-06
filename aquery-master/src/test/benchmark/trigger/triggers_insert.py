import pandas as pd
import numpy as np
import random

random.seed(42)
np.random.seed(42)

shuffled_itemnums = np.random.permutation(range(1, 1001))
shuffled_storeids = np.random.permutation(range(1, 1001))
shuffled_vendorids = np.random.permutation(range(1, 1001))

data = []
for i in range(1000):
    ordernum = 100000000 + i
    itemnum = shuffled_itemnums[i]
    quantity = 500 + (i % 100)
    price = round(10 + (itemnum % 1000) * 0.13, 2)
    storeid = shuffled_storeids[i]
    vendorid = shuffled_vendorids[i]
    data.append([ordernum, itemnum, quantity, price, storeid, vendorid])

df = pd.DataFrame(
    data,
    columns=["ordernum", "itemnum", "quantity", "price", "storeid", "vendorid"],
)
df.to_csv("triggers_input.csv", index=False)

print("CSV file 'triggers_input.csv' has been created.")
