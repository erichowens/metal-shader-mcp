# Aesthetic metrics (bootstrap)
# These are intentionally simple and deterministic to start the loop.
# Replace/extend with more robust implementations and tests as we iterate.

import math
from typing import Tuple
import numpy as np
from skimage.color import rgb2lab
from skimage.filters import sobel


def contrast_score(img: np.ndarray) -> float:
    # RMS contrast proxy in linear-ish space; expects float [0,1]
    x = img.astype(np.float32)
    mu = x.mean()
    return float(np.sqrt(np.mean((x - mu) ** 2)))


def saturation_balance(img: np.ndarray) -> float:
    # Simple saturation proxy via channel variance
    x = img.astype(np.float32)
    var = x.var(axis=(0,1))
    return float(np.clip(var.mean() * 2.0, 0.0, 1.0))


def edge_density(img: np.ndarray) -> float:
    edges = sobel(np.mean(img, axis=2))
    d = float(np.mean(edges > 0.1))
    # Prefer moderate edge density
    return float(1.0 - abs(d - 0.2) / 0.2)  # 1 at ~0.2 density


def color_harmony(img: np.ndarray) -> float:
    # Extremely rough: prefer bimodal hue hist (proxy via LAB a/b spread)
    lab = rgb2lab(img)
    a = lab[:,:,1].astype(np.float32)
    b = lab[:,:,2].astype(np.float32)
    spread = float(np.sqrt(a.var() + b.var()))
    return float(np.clip(spread / 40.0, 0.0, 1.0))


def composite_score(img: np.ndarray) -> float:
    w1, w2, w3, w4 = 0.3, 0.3, 0.2, 0.2
    c = contrast_score(img)
    s = saturation_balance(img)
    e = edge_density(img)
    h = color_harmony(img)
    return float(np.clip(w1*h + w2*c + w3*s + w4*e, 0.0, 1.0))
