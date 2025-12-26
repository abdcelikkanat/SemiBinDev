import os
import csv


# High-quality rule – adjust if needed
def is_high_quality(completeness, contamination):
    return completeness >= 90 and contamination <= 5

def get_hq_count(current_file):

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

    return len(hq_bins)

sample_name="fecal_deep"
base_folder_dir = f"/home/cs.aau.dk/zs74qz/workspace/SemiBinRefining/outputs_refining/{sample_name}"
semibin2_file = f"{base_folder_dir}/SemiBin2/checkm2/quality_report.tsv"
refining1_file = f"{base_folder_dir}/SemiBinRefining1/checkm2/quality_report.tsv"


print(semibin2_file)
semibin2_hq_count = get_hq_count(semibin2_file)
refining1_hq_count = get_hq_count(refining1_file)
print(semibin2_hq_count)
print(refining1_hq_count)
