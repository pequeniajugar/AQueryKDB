import random
import numpy as np
import pandas as pd  

random.seed(42)

# Generate fractally distributed IDs
def gen(frac, N):
    """Generate fractally distributed IDs based on 80/20 rule."""
    p = list(range(1, N + 1))  
    random.shuffle(p)  
    outvec = p[:]  

    while len(p) > 1:
        p = p[:int(len(p) * frac)]  
        outvec = p + outvec  

    random.shuffle(outvec)  
    return outvec

# Define Vendor Size Calculation Function
def calculate_num_vendors(num_orders):
    """Calculate the number of vendors based on num_orders."""
    if num_orders == 10**4:
        return 8002
    elif num_orders == 10**6:
        return 800001
    elif num_orders == 10**8:
        return 800003
    else:
        return max(1, num_orders // 1000)  # Default case

# Generate Store Data in Batches
def generate_and_save_store(num_stores, batch_size, file_name):
    with open(file_name, "w") as f:
        f.write("storeid,name\n")
    
    for start in range(1, num_stores + 1, batch_size):
        end = min(start + batch_size, num_stores + 1)
        stores = [(i, f"Store{i}") for i in range(start, end)]
        df = pd.DataFrame(stores, columns=["storeid", "name"])
        df.to_csv(file_name, mode="a", index=False, header=False)
        print(f"Processed {end - 1}/{num_stores} stores...")

# Generate Item Data in Batches
def price_for_item(itemnum):
    """Deterministic decimal.2 price so orders.price can match item.price without a lookup table."""
    return round(1 + ((itemnum * 7919) % 9900) / 100, 2)


def generate_and_save_item(num_items, batch_size, file_name):
    with open(file_name, "w") as f:
        f.write("itemnum,price\n")
    
    for start in range(1, num_items + 1, batch_size):
        end = min(start + batch_size, num_items + 1)
        items = [(i, price_for_item(i)) for i in range(start, end)]
        df = pd.DataFrame(items, columns=["itemnum", "price"])
        df.to_csv(file_name, mode="a", index=False, header=False)
        print(f"Processed {end - 1}/{num_items} items...")

# Generate Vendor Outstanding Data in Batches
def generate_and_save_vendorOutstanding(num_vendors, batch_size, file_name):
    with open(file_name, "w") as f:
        f.write("vendorid,amount\n")
    
    for start in range(1, num_vendors + 1, batch_size):
        end = min(start + batch_size, num_vendors + 1)
        vendor_data = [(i, round(random.uniform(99000, 100000), 2)) for i in range(start, end)]
        df = pd.DataFrame(vendor_data, columns=["vendorid", "amount"])
        df.to_csv(file_name, mode="a", index=False, header=False)
        print(f"Processed {end - 1}/{num_vendors} vendorOutstanding...")

# Generate Store Outstanding Data in Batches
def generate_and_save_storeOutstanding(num_store_outstanding, batch_size, file_name):
    with open(file_name, "w") as f:
        f.write("storeid,amount\n")
    
    for start in range(1, num_store_outstanding + 1, batch_size):
        end = min(start + batch_size, num_store_outstanding + 1)
        store_outstanding_data = [(store_id, round(random.uniform(9000, 10000), 2)) for store_id in range(start, end)]
        df = pd.DataFrame(store_outstanding_data, columns=["storeid", "amount"])
        df.to_csv(file_name, mode="a", index=False, header=False)
        print(f"Processed {end - 1}/{num_store_outstanding} storeOutstanding...")

# Generate Fractally Distributed Vendor IDs for Orders
def generate_fractal_vendors(num_orders, num_vendors):
    """Generate fractally distributed vendor IDs for orders."""
    base_vendors = gen(0.2, num_vendors)
    expanded_vendors = (base_vendors * (num_orders // len(base_vendors) + 1))[:num_orders]
    random.shuffle(expanded_vendors)
    return expanded_vendors

# Generate Orders Data in Batches
def generate_and_save_orders(num_orders, num_items, num_stores, num_vendors, batch_size, file_name):
    """Generate `orders` table with fractally distributed vendorid and save in batches."""
    
    vendor_ids = generate_fractal_vendors(num_orders, num_vendors)

    with open(file_name, "w") as f:
        f.write("ordernum,itemnum,quantity,price,storeid,vendorid\n")
    
    for start in range(0, num_orders, batch_size):
        end = min(start + batch_size, num_orders)
        batch_vendor_ids = vendor_ids[start:end]

        batch_orders = []
        for i in range(start, end):
            itemnum = random.randint(1, num_items)
            batch_orders.append((
                i + 1,
                itemnum,
                random.randint(1, 100),
                price_for_item(itemnum),
                random.randint(1, num_stores),
                batch_vendor_ids[i - start],
            ))

        df = pd.DataFrame(batch_orders, columns=["ordernum", "itemnum", "quantity", "price", "storeid", "vendorid"])
        df.to_csv(file_name, mode="a", index=False, header=False)
        print(f"Processed {end}/{num_orders} orders...")

# Get user input for number of orders
while True:
    try:
        num_orders = int(input("Enter the total number of orders to generate: "))
        if num_orders <= 0:
            print("Please enter a positive integer.")
        else:
            break
    except ValueError:
        print("Invalid input! Please enter an integer.")

# Compute related table sizes based on num_orders
num_stores = max(1, num_orders // 100)
num_items = max(1, int(num_orders / 2.5))
num_vendors = calculate_num_vendors(num_orders)  # Use the new vendor size calculation function
num_store_outstanding = max(1, num_orders // 5)

# Set batch size
batch_size = 10000
exponent = int(np.log10(num_orders))

# Generate and Save Tables in Batches
generate_and_save_store(num_stores, batch_size, f"store_fractal_10_{exponent}.csv")
generate_and_save_item(num_items, batch_size, f"item_fractal_10_{exponent}.csv")
generate_and_save_vendorOutstanding(num_vendors, batch_size, f"vendorOutstanding_fractal_10_{exponent}.csv")

generate_and_save_storeOutstanding(num_store_outstanding, batch_size, f"storeOutstanding_fractal_10_{exponent}.csv")

# Generate and Save Orders in Batches
generate_and_save_orders(num_orders, num_items, num_stores, num_vendors, batch_size, f"order_fractal_10_{exponent}.csv")

print("\nData successfully saved to CSV files!")
