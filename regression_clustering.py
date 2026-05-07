"""Regression clustering: bootstrap GMM + per-component OLS, with permutation thresholding."""

import contextlib
import os
import random
import warnings
from collections import Counter

import joblib
import numpy as np
import scipy.stats as ss
import statsmodels.api as sm
from joblib import Parallel, delayed
from sklearn.cluster import AgglomerativeClustering
from sklearn.metrics import (
    calinski_harabasz_score,
    davies_bouldin_score,
    silhouette_score,
)
from sklearn.mixture import GaussianMixture
from tqdm import tqdm

warnings.simplefilter("ignore")


def regression_clustering_iteration(x, y, data, subsample_size, cluster_max):
    """One bootstrap iteration: GMM on a random subsample, OLS per component, vote into the feature matrix."""

    ind = np.sort(random.sample(range(x.shape[0]), subsample_size))
    x_sub = x[ind]
    y_sub = y[ind]
    data_sub = data[ind]

    participant_feature = np.zeros_like(y)

    n_clusters = random.sample(range(2, cluster_max + 1), 1)[0]
    labels = GaussianMixture(n_components=n_clusters).fit_predict(data_sub)

    if not all(c >= 2 for c in Counter(labels).values()):
        return participant_feature

    for k in range(n_clusters):
        mask = labels == k
        x_k = sm.add_constant(x_sub[mask])
        y_k = y_sub[mask]
        for j in range(y.shape[1]):
            p = sm.OLS(y_k[:, j], x_k).fit().pvalues[1]
            if p < 0.05:
                participant_feature[ind[mask], j] = 1

    return participant_feature


@contextlib.contextmanager
def tqdm_joblib(tqdm_object):
    """Patch joblib to update a tqdm progress bar."""

    class TqdmBatchCompletionCallback(joblib.parallel.BatchCompletionCallBack):
        def __call__(self, *args, **kwargs):
            tqdm_object.update(n=self.batch_size)
            return super().__call__(*args, **kwargs)

    old_callback = joblib.parallel.BatchCompletionCallBack
    joblib.parallel.BatchCompletionCallBack = TqdmBatchCompletionCallback
    try:
        yield tqdm_object
    finally:
        joblib.parallel.BatchCompletionCallBack = old_callback
        tqdm_object.close()


def compute_feature_matrix(x, y, data, subsample_size, cluster_max, n_iter, n_jobs):
    """Run n_iter regression-clustering iterations in parallel; return the summed feature-participant matrix."""

    with tqdm_joblib(tqdm(desc="Regression clustering", total=n_iter)):
        out = Parallel(n_jobs=n_jobs)(
            delayed(regression_clustering_iteration)(x, y, data, subsample_size, cluster_max)
            for _ in range(n_iter)
        )
    return np.sum(out, axis=0)


def run_pipeline(
    x,
    y,
    output_dir,
    prefix,
    subsample_size,
    cluster_max=5,
    n_iter=100000,
    n_perm=100,
    percentile=99,
    n_jobs=-1,
    seed=10,
):
    """Full regression-clustering pipeline. Writes feature matrices, threshold, labels, and clustering metrics to output_dir."""

    os.makedirs(output_dir, exist_ok=True)
    random.seed(seed)
    np.random.seed(seed)

    # Z-score the inputs (the GMM is fit on age + features jointly)
    x_z = ss.zscore(x)
    y_z = ss.zscore(y)
    data_z = ss.zscore(np.hstack([x_z.reshape(-1, 1), y_z]))

    main_path = os.path.join(output_dir, f"{prefix}.csv")
    if not os.path.exists(main_path):
        feature = compute_feature_matrix(x_z, y_z, data_z, subsample_size, cluster_max, n_iter, n_jobs)
        np.savetxt(main_path, feature, delimiter=",")

    # If no null requested, return after the main run (caller wanted the raw feature matrix only)
    if n_perm == 0:
        return

    # Null distribution: re-run with age permuted
    for p in range(n_perm):
        perm_path = os.path.join(output_dir, f"{prefix}_randperm{p:03d}.csv")
        if os.path.exists(perm_path):
            continue
        x_perm = np.random.permutation(x_z)
        data_perm = ss.zscore(np.hstack([x_perm.reshape(-1, 1), y_z]))
        feature_perm = compute_feature_matrix(x_perm, y_z, data_perm, subsample_size, cluster_max, n_iter, n_jobs)
        np.savetxt(perm_path, feature_perm, delimiter=",")

    # Load and threshold against per-cell percentile of the null
    feature = np.loadtxt(main_path, delimiter=",")
    feature_null = np.zeros((feature.shape[0], feature.shape[1], n_perm))
    for p in range(n_perm):
        feature_null[:, :, p] = np.loadtxt(
            os.path.join(output_dir, f"{prefix}_randperm{p:03d}.csv"), delimiter=","
        )
    thresh = np.percentile(feature_null, percentile, axis=2)
    feature_thresh = np.where(feature >= thresh, feature, 0)
    np.savetxt(os.path.join(output_dir, f"{prefix}_thresh.csv"), feature_thresh, delimiter=",")

    # Hierarchical clustering across k = 2..cluster_max
    labels = np.zeros((feature_thresh.shape[0], cluster_max + 1))
    metrics = np.zeros((cluster_max + 1, 3))
    for k in range(2, cluster_max + 1):
        model = AgglomerativeClustering(n_clusters=k, metric="euclidean", linkage="ward").fit(feature_thresh)
        labels[:, k] = model.labels_
        metrics[k] = [
            davies_bouldin_score(feature_thresh, labels[:, k]),
            calinski_harabasz_score(feature_thresh, labels[:, k]),
            silhouette_score(feature_thresh, labels[:, k]),
        ]
    np.savetxt(os.path.join(output_dir, f"{prefix}_labels.csv"), labels, delimiter=",")
    np.savetxt(os.path.join(output_dir, f"{prefix}_metrics.csv"), metrics, delimiter=",")
