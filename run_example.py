"""Synthetic-data test of the regression-clustering pipeline.

Generates two latent subgroups with diverging age-feature trajectories, runs
the pipeline at small n_iter / n_perm, and prints the resulting cluster
assignment alongside the ground-truth labels.
"""

import os
import shutil

import numpy as np

from regression_clustering import run_pipeline


def make_synthetic_data(n=200, n_features=5, seed=0):
    rng = np.random.default_rng(seed)
    age = rng.uniform(5, 21, size=n)

    # Two latent subgroups with diverging slopes on the first three features
    group = rng.integers(0, 2, size=n)
    y = np.zeros((n, n_features))
    slopes = np.array([
        [0.30, 0.25, -0.20, 0.0, 0.0],   # group 0
        [-0.20, -0.15, 0.30, 0.0, 0.0],  # group 1
    ])
    intercepts = np.array([
        [1.0, 0.5, 0.0, 0.5, 0.5],
        [0.5, 1.0, 0.5, 0.5, 0.5],
    ])
    for i in range(n):
        y[i] = intercepts[group[i]] + slopes[group[i]] * age[i] + rng.normal(0, 0.4, n_features)

    return age, y, group


if __name__ == "__main__":
    output_dir = os.path.join(os.path.dirname(__file__), "_example_outputs")
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)

    age, y, true_group = make_synthetic_data()
    print(f"Generated synthetic data: N={age.shape[0]}, p={y.shape[1]}")

    run_pipeline(
        x=age,
        y=y,
        output_dir=output_dir,
        prefix="example",
        subsample_size=int(0.632 * age.shape[0]),
        cluster_max=4,
        n_iter=1000,
        n_perm=10,
        n_jobs=-1,
        seed=10,
    )

    labels = np.loadtxt(os.path.join(output_dir, "example_labels.csv"), delimiter=",")
    k2 = labels[:, 2].astype(int)
    print()
    print("Pipeline complete. Outputs written to", output_dir)
    print()
    print("k=2 confusion against ground truth:")
    print("              recovered=0  recovered=1")
    for g in (0, 1):
        n0 = int(np.sum((true_group == g) & (k2 == 0)))
        n1 = int(np.sum((true_group == g) & (k2 == 1)))
        print(f"  true={g}     {n0:>11d}  {n1:>11d}")
