# Regression clustering

Code accompanying Vandewouw et al., *Transdiagnostic variation in age-related
patterns of rich-club organization across neurodevelopmental and related mental
health conditions*. The MATLAB pipeline in `preprocessing/` goes from the
resting-state MEG data to the area under the rich-club curve (AURC) for each
participant and frequency band; these are the features passed to the
regression clustering.

Bootstrap-aggregated Gaussian-mixture clustering for identifying subgroups of
participants with shared age-related patterns across a set of features. Each of
many bootstrap subsamples fits a GMM on the joint (age, features) space and
runs an OLS regression of each feature on age within every component; a
participant–feature matrix accumulates votes from significant (p<0.05)
within-component associations. The matrix is thresholded against a
permutation-based null (the same procedure with age randomly permuted in the
regressions), and a hierarchical clustering is fit to the thresholded matrix.

## Preprocessing

Run the scripts in order from inside `preprocessing/`:

1. `p01_epoching.m` — 10 s epochs, jump artifact rejection
2. `p02_ica.m` — ICA; components to remove are chosen from the saved plots
3. `p03_artifact_rejection.m` — removes ICA components, rejects epochs over
   2000 fT or with more than 10 mm of head motion
4. `p04_head_model.m` — MRI co-registration and single-shell head models
5. `p05_beamformer.m` — LCMV beamformer at the 90 AAL regions
6. `p06_connectivity.m` — band-pass filtering, leakage correction, amplitude
   envelope correlation
7. `p07_omst_threshold.m` — OMST thresholding
8. `p08_null_networks.m` — 1000 random networks per participant and band
9. `p09_rich_club.m` — normalized weighted rich-club coefficients and
   FDR-corrected p-values
10. `p10_aurc.m` — AURC for each band, written to `AURC.csv`

All paths and parameters are in `pipeline_config.m`. Set the participant
spreadsheet, data directories and bad-channel list (one channel name per line,
specific to your MEG system) there before running.

The participant spreadsheet has one row per participant with the columns
`UniqueID`, `Visit`, `Run`, `Sex`, `Age`, `MEG_Rest` (path to the CTF `.ds`),
`megprep_ica` (comma-separated ICA components to remove), `T1` (path to the
T1 NIfTI), `T1_fiducial_nas`, `T1_fiducial_lpa`, `T1_fiducial_rpa` (fiducial
coordinates in mm, as `x y z`) and `including_final` (1 for participants with
at least 12 clean epochs, one run per participant).

Toolboxes go in `preprocessing/repos/`:

- [FieldTrip](https://www.fieldtriptoolbox.org/) — `repos/fieldtrip`
- [HeadMotion](https://github.com/MabbottLab/MEGneto/tree/d6b5d4a0dbc759727237478fdc0f1ac021d91fe8/functions/functions/HeadMotion) from MEGneto — `repos/MEGneto`
- [MEG-ROI-nets](https://github.com/OHBA-analysis/MEG-ROI-nets) — `repos/MEG-ROI-nets`
- [Brain Connectivity Toolbox](https://sites.google.com/site/bctnet/), 2019-03-03 release — `repos/2019_03_03_BCT`
- [topological_filtering_networks](https://github.com/stdimitr/topological_filtering_networks) — `repos/topological_filtering_networks`
- [GRETNA](https://www.nitrc.org/projects/gretna/) 2.0.0 — `repos/GRETNA_2.0.0_release_20171121`

[fdr_bh](https://www.mathworks.com/matlabcentral/fileexchange/27418-fdr_bh) goes
in `preprocessing/functions/`. The Signal Processing Toolbox is also needed.

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
    n_iter=10000,                          # bootstrap iterations
    n_perm=100,                            # null permutations of age
    cluster_max=5,                         # max k for hierarchical clustering
    n_jobs=-1,                             # parallel workers
    seed=10,
)
```

In the paper, `x` and `y` were the `Age` and five band columns of `AURC.csv`,
run separately for females and males with `subsample_size=130` (63.2% of the
female sample) for both.

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
