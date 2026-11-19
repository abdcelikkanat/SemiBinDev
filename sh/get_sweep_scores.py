"""
Collects the results of run_sweep.sh into one table.

Usage: python get_sweep_scores.py <outputs_dir> [out.tsv]

One row per (sample, config, phase, epoch) with the number of HQ bins
(CheckM2, completeness >= 90, contamination <= 5; -1 if the report is missing)
and the training loss at that epoch (from loss_<phase>.tsv).
"""
import csv
import os
import re
import sys


def is_high_quality(completeness, contamination):
    return completeness >= 90 and contamination <= 5


def count_hq_bins(quality_file):
    with open(quality_file, newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        n = 0
        for row in reader:
            comp = float(row.get("Completeness", row.get("completeness")))
            cont = float(row.get("Contamination", row.get("contamination")))
            n += is_high_quality(comp, cont)
        return n


def read_losses(loss_file):
    """epoch -> mean_loss (averaged over data files, if several)"""
    losses = {}
    if not os.path.isfile(loss_file):
        return losses
    with open(loss_file, newline="") as f:
        for row in csv.DictReader(f, delimiter="\t"):
            losses.setdefault(int(row["epoch"]), []).append(float(row["mean_loss"]))
    return {e: sum(v) / len(v) for e, v in losses.items()}


def main(root, out_path=None):
    rows = []
    for sample in sorted(os.listdir(root)):
        sample_dir = os.path.join(root, sample)
        if not os.path.isdir(sample_dir):
            continue
        for config in sorted(os.listdir(sample_dir)):
            if config == "features" or not os.path.isdir(os.path.join(sample_dir, config)):
                continue
            for phase, loss_name in (("mean", "loss_mean_only.tsv"), ("var", "loss_std_only.tsv")):
                phase_dir = os.path.join(sample_dir, config, phase)
                if not os.path.isdir(phase_dir):
                    continue
                losses = read_losses(os.path.join(phase_dir, "train", loss_name))
                epochs = sorted(int(m.group(1)) for d in os.listdir(phase_dir)
                                if (m := re.fullmatch(r"epoch_(\d+)", d)))
                for epoch in epochs:
                    report = os.path.join(phase_dir, f"epoch_{epoch}", "checkm2", "quality_report.tsv")
                    hq = count_hq_bins(report) if os.path.isfile(report) else -1
                    rows.append([sample, config, phase, epoch, hq, losses.get(epoch, float("nan"))])

    header = ["sample", "config", "phase", "epoch", "hq_bins", "train_loss"]
    out = open(out_path, "w", newline="") if out_path else sys.stdout
    writer = csv.writer(out, delimiter="\t")
    writer.writerow(header)
    writer.writerows(rows)
    if out_path:
        out.close()
        print(f"Wrote {len(rows)} rows to {out_path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
