import os
import sys
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import subprocess
import json
import numpy as np
from PIL import Image
import itertools

# Import metrics from the existing script
from ml.aesthetics.metrics import composite_score

def render_shader(shader_path, output_path, width, height, time, complexity, colorShift):
    """Renders a shader using ShaderRenderCLI."""
    command = [
        "swift", "run", "ShaderRenderCLI",
        "--shader-file", shader_path,
        "--out", output_path,
        "--width", str(width),
        "--height", str(height),
        "--time", str(time),
        "--complexity", str(complexity),
        "--colorShift", str(colorShift)
    ]
    subprocess.run(command, check=True)

def generate_dataset(shader_path, output_dir, variations):
    """Generates a dataset of images by rendering a shader with different parameters."""
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    metadata = []

    for i, params in enumerate(variations):
        time = params["time"]
        complexity = params["complexity"]
        colorShift = params["colorShift"]
        image_path = os.path.join(output_dir, f"render_{i}.png")
        
        render_shader(shader_path, image_path, 256, 256, time, complexity, colorShift)

        # Score the image
        img = Image.open(image_path)
        img_array = np.array(img.convert("RGB"))
        score = composite_score(img_array)

        metadata.append({
            "image_path": image_path,
            "time": time,
            "complexity": complexity,
            "colorShift": colorShift,
            "score": score
        })

        print(f"Generated {image_path} with time={time}, complexity={complexity}, colorShift={colorShift}, score={score}")

    with open(os.path.join(output_dir, "metadata.json"), "w") as f:
        json.dump(metadata, f, indent=2)

if __name__ == "__main__":
    shader = "/Users/erichowens/coding/metal-shader-mcp/shaders/plasma_fractal.metal"
    output = "shader_dataset"
    
    time_variations = np.linspace(0, 10, 10)
    complexity_variations = np.linspace(0, 1, 5)
    colorShift_variations = np.linspace(0, 1, 5)

    variations = list(itertools.product(time_variations, complexity_variations, colorShift_variations))
    
    # Convert to list of dictionaries
    variations = [{"time": t, "complexity": c, "colorShift": cs} for t, c, cs in variations]
    
    generate_dataset(shader, output, variations)
