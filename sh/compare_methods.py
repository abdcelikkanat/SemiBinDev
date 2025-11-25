import os
import csv

base_folder_dir = "/home/cs.aau.dk/zs74qz/workspace/SemiBinICLR//outputs_iclr/fecal_deep/SemiBinICLR"
semibin2_file = "/projects/dark_science/methylation_binning/article/outputs/nanomotif_v1.1.0/fecal_deep/SemiBin2/checkm2/quality_report.tsv"
#"/projects/dark_science/methylation_binning/article/outputs/nanomotif_v1.1.0/fecal_deep/BaselineModel/bins/checkm2_output/quality_report.tsv"

# Directories containing quality_report.csv
epoch_list = [-1, 5, 10, 15, 20, 25, 30, 35, 40, 45]

# Storage for HQ bin sets
hq_bins_per_epoch = {}

# High-quality rule – adjust if needed
def is_high_quality(completeness, contamination):
    return completeness >= 90 and contamination <= 5

for epoch in epoch_list:

    if epoch > 0:
        current_file = f"{base_folder_dir}/epoch_{epoch}/checkm2/quality_report.tsv"
    elif epoch == -1: #Semibin2
        current_file = semibin2_file

    if not os.path.exists(current_file):
        print(f"[WARNING] Missing file: {current_file}")
        continue

    with open(current_file, newline="") as f:
        reader = csv.DictReader(f, delimiter='\t')

        # Detect bin name column
        # Typical options in SemiBin2: "bin_name" or the first column
        header = reader.fieldnames

        if "Bin Id" in header:
            bin_col = "Bin Id"
        elif "bin_name" in header:
            bin_col = "bin_name"
        else:
            bin_col = header[0]  # default fallback

        hq_bins = set()

        for row in reader:
            try:
                completeness = float(row["Completeness"])
                contamination = float(row["Contamination"])
            except KeyError:
                raise ValueError(
                    "CSV must contain 'Completeness' and 'Contamination' columns."
                )

            if is_high_quality(completeness, contamination):
                hq_bins.add(row[bin_col])

        hq_bins_per_epoch[epoch] = hq_bins

# --- Print summary ---
print("=== High-Quality Bin Summary ===")
for epoch in epoch_list:
    bins = hq_bins_per_epoch.get(epoch, set())
    if epoch > 0:
        print(f"{epoch}: {len(bins)} HQ bins")
    elif epoch == -1: #semibin2
        print(f"SemiBin2 (15 Epochs): {len(bins)} HQ bins")

# --- Build comparison table ---
all_bins = sorted(set().union(*hq_bins_per_epoch.values()))

'''
# Save comparison table manually
output_file = "hq_bin_comparison.csv"
with open(output_file, "w", newline="") as f:
    writer = csv.writer(f)

    # Header
    writer.writerow(["Bin"] + epoch_dirs)

    # Rows: bin + True/False for each epoch
    for b in all_bins:
        row = [b] + [b in hq_bins_per_epoch.get(epoch, set()) for epoch in epoch_dirs]
        writer.writerow(row)

print(f"\nComparison table written to: {output_file}")

'''
