from flask import Flask, request, jsonify
import joblib
import numpy as np

app = Flask(__name__)

# Load the trained model
model = joblib.load("shader_aesthetic_model.pkl")

@app.route("/predict", methods=["POST"])
def predict():
    data = request.get_json()
    time = data["time"]
    complexity = data["complexity"]
    colorShift = data["colorShift"]

    features = np.array([[time, complexity, colorShift]])
    prediction = model.predict(features)

    return jsonify({"score": prediction[0]})

if __name__ == "__main__":
    app.run(port=5001)
