import os
import sys
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






quality_file_path = sys.argv[1]
hq_count = len(get_hq_bins(quality_file_path))
print(f"HQ: {hq_count}")
