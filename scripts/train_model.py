import json
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error
import joblib

def train_model(dataset_path):
    """Trains a linear regression model on the shader dataset."""
    with open(dataset_path, "r") as f:
        metadata = json.load(f)

    # Prepare the data
    X = np.array([[item["time"], item["complexity"], item["colorShift"]] for item in metadata])
    y = np.array([item["score"] for item in metadata])

    # Split the data
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    # Train the model
    model = LinearRegression()
    model.fit(X_train, y_train)

    # Evaluate the model
    y_pred = model.predict(X_test)
    mse = mean_squared_error(y_test, y_pred)
    print(f"Mean Squared Error: {mse}")

    # Save the model
    joblib.dump(model, "shader_aesthetic_model.pkl")
    print("Model saved to shader_aesthetic_model.pkl")

if __name__ == "__main__":
    train_model("shader_dataset/metadata.json")
