import pandas as pd
from ydata_profiling import ProfileReport

# Dataset files and their paths
datasets = {
    "orders": "seeds/data/orders.csv",
    "order_details": "seeds/data/order_details.csv",
    "pizzas": "seeds/data/pizzas.csv",
    "pizza_types": "seeds/data/pizza_types.csv",
}

for name, path in datasets.items():
    df = pd.read_csv(path, encoding="latin1")

    # Print a concise summary without waiting for HTML report generation.
    print(f"=== {name}.csv ===")
    print(f"Total records: {len(df)}")
    print(f"Missing values: {df.isnull().sum().sum()}")
    print(f"Full-row duplicates: {df.duplicated().sum()}\n")

    # Generate a detailed interactive report.
    profile = ProfileReport(df, title=f"{name} Profiling", minimal=True)
    profile.to_file(f"{name}_report.html")
