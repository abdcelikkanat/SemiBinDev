import os
import csv

base_folder_dir = "/home/cs.aau.dk/zs74qz/workspace/SemiBinICLR/"
semibin2_file = f"{base_folder_dir}/outputs/fecal_deep/SemiBin2/checkm2/quality_report.tsv"
mean_model_file = f"{base_folder_dir}/outputs/fecal_deep/SemiBinICLR/mean_checkm2/quality_report.tsv"
var_model_file = f"{base_folder_dir}/outputs/fecal_deep/SemiBinICLR/var_checkm2/quality_report.tsv"


#"/projects/dark_science/methylation_binning/article/outputs/nanomotif_v1.1.0/fecal_deep/BaselineModel/bins/checkm2_output/quality_report.tsv"


# High-quality rule – adjust if needed
def is_high_quality(completeness, contamination):
    return completeness >= 90 and contamination <= 5

def get_hq_bins(current_file):

    if not os.path.exists(current_file):
        raise ValueError(f"[WARNING] Missing file: {current_file}")

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

        return hq_bins

# --- Print summary ---
print("=== High-Quality Bin Summary ===")

#print(f"MaxBin2: {len(get_hq_bins(maxbin2_file))}")
#print(f"Metabat2: {len(get_hq_bins(metabat2_file))}")
#print(f"TaxVAMB: {len(get_hq_bins(taxvamb_file))}")
#print(f"ComeBin: {len(get_hq_bins(comebin_file))}")
print(f"Semibin2: {len(get_hq_bins(semibin2_file))}")
print(f"Mean Model: {len(get_hq_bins(mean_model_file))}")
print(f"Var Model: {len(get_hq_bins(var_model_file))}")

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
