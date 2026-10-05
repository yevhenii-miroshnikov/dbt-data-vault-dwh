import pandas as pd
from ydata_profiling import ProfileReport

# Словник файлів і шляхів до них
datasets = {
    "orders": "seeds/data/orders.csv",
    "order_details": "seeds/data/order_details.csv",
    "pizzas": "seeds/data/pizzas.csv",
    "pizza_types": "seeds/data/pizza_types.csv",
}

for name, path in datasets.items():
    df = pd.read_csv(path, encoding="latin1")

    # Швидкий розрахунок у термінал (без очікування генерації всього HTML)
    print(f"=== {name}.csv ===")
    print(f"Total records (рядків): {len(df)}")
    print(f"Empty values (порожніх значень): {df.isnull().sum().sum()}")
    print(f"Duplicates (повних дублікатів): {df.duplicated().sum()}\n")

    # Генерація детального інтерактивного звіту
    profile = ProfileReport(df, title=f"{name} Profiling", minimal=True)
    profile.to_file(f"{name}_report.html")