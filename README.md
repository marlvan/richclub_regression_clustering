# Regression clustering

Bootstrap-aggregated Gaussian-mixture clustering for identifying subgroups of
participants with shared age-related patterns across a set of features. Each of
many bootstrap subsamples fits a GMM on the joint (age, features) space and
runs an OLS regression of each feature on age within every component; a
participant–feature matrix accumulates votes from significant (p<0.05)
within-component associations. The matrix is thresholded against a
permutation-based null (age randomly permuted, full pipeline re-run), and a
hierarchical clustering is fit to the thresholded matrix.

## Install

```
pip install -r requirements.txt
```

## Use

Quick synthetic example (a few minutes on a laptop):

```
python run_example.py
```

To run on your own data, pass an `(N,)` age vector and an `(N, p)` feature
matrix to `run_pipeline`:

```python
from regression_clustering import run_pipeline

run_pipeline(
    x=age,                                 # (N,) numeric ages
    y=features,                            # (N, p) feature matrix
    output_dir="rc_outputs",
    prefix="my_cohort",
    subsample_size=int(0.632 * len(age)),  # 63.2% of N (Breiman, 1996)
    n_iter=100000,                         # bootstrap iterations
    n_perm=100,                            # null permutations of age
    cluster_max=5,                         # max k for hierarchical clustering
    n_jobs=-1,                             # parallel workers
    seed=10,
)
```

Outputs written to `output_dir`:

- `<prefix>.csv` — feature-participant matrix (N × p)
- `<prefix>_randperm{NNN}.csv` — null matrices, one per age permutation
- `<prefix>_thresh.csv` — feature matrix after percentile thresholding
- `<prefix>_labels.csv` — hierarchical-clustering labels for k = 0..cluster_max
- `<prefix>_metrics.csv` — Davies–Bouldin, Calinski–Harabasz, silhouette per k

The main and per-permutation runs each write their CSV on completion; rerunning
the script picks up where it left off.

## Notes

- For sex- or group-stratified analyses, filter the input arrays before calling
  `run_pipeline`. The pipeline does not look at any covariates beyond the
  passed-in `(x, y)`.
- To match subsample sizes across stratified runs (e.g. males vs. females with
  different N), pass the same integer `subsample_size` to both. The
  `0.632 * N` default is a fractional-bootstrap convention (Breiman, 1996).
- Exact reproducibility across runs is not guaranteed because joblib workers
  carry their own random state; population-level outputs converge with enough
  iterations.
