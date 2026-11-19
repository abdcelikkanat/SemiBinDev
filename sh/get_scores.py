import os
import csv



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
                if "Completeness" in row.keys():
                    completeness = float(row["Completeness"])
                    contamination = float(row["Contamination"])
                else:
                    completeness = float(row["completeness"])
                    contamination = float(row["contamination"])
            except KeyError:
                raise ValueError(
                    "CSV must contain 'Completeness' and 'Contamination' columns."
                )

            if is_high_quality(completeness, contamination):
                hq_bins.add(row[bin_col])

        return hq_bins

base_folder = "/home/cs.aau.dk/zs74qz"
semibin2_output_folder = os.path.join(base_folder, "workspace/SemiBin_v2.2.1/sh/outputs/")
semibin_v103_output_folder = os.path.join(base_folder, "workspace/semibin4uncertain/sh/outputs_v1.0.3/")

sample_list = [
   "ZymoFecal",
   "PaPr00000116MP", "PaPr00000216MP", "RASK00000027MP", "RASK00000062MP", "ASYM00000009MP", "ASYM00000026MP",
   "wwtp_NL-09", "wwtp_IL-01", "wwtp_US2-26", "wwtp_IN-06", "wwtp_US1-124",
   "sediment_MFD04716", "sediment_MFD00905", "sediment_MFD05674", "sediment_MFD10007", "sediment_MFD09779", 
   "soil_MFD00392", "soil_MFD06742", "soil_MFD06229",
]
model_list = ["semibin2", "mean", "var"]

results = {}
for sample_name in sample_list:

    #
    results[sample_name] = dict()

    for model in model_list:

        # Define the folder name and output folder
        if model in ["mean", "var"]:
            output_folder = semibin_v103_output_folder
            sample_folder = f"{sample_name}_{model}"
        else:
            output_folder = semibin2_output_folder
            sample_folder = f"{sample_name}"

        quality_file_path = os.path.join(output_folder, sample_folder, "checkm2/quality_report.tsv")

        hq_count = -1 # if file not exists, hq count is -1
        if os.path.isfile(quality_file_path):
            hq_count = len(get_hq_bins(quality_file_path))

        results[sample_name][model] = hq_count


# Now, priint the results
print( " | ".join(model_list) )
for sample_name in results:
    print(f"{sample_name}: " + " | ".join( map(str, [results[sample_name][model] for model in model_list]) ) )
