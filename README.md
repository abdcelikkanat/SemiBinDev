# SemiBin -> ICLR

## Installation with `conda`:

```bash
conda create -n SemiBin
conda activate SemiBin
conda install -c conda-forge -c bioconda semibin
```


```bash
SemiBin2 single_easy_bin -i contig.fa -b S1.sorted.bam -o output --environment human_gut
```

(if you are using contigs from long-reads, add the `--sequencing-type=long_read` argument).

### Source

You will need the following dependencies:

- [Bedtools](http://bedtools.readthedocs.org/]), [Hmmer](http://hmmer.org/)
- [Samtools](https://github.com/samtools/samtools)
- HMMER

The easiest way to install the dependencies is with [conda](https://conda.io):

```bash
conda install -c bioconda bedtools hmmer samtools
```

Once the dependencies are installed, you can install SemiBin by running:

```bash
pip install .
```

Optional extra dependencies:

- [MMseqs2](https://github.com/soedinglab/MMseqs2)
- [Prodigal](https://github.com/hyattpd/Prodigal)

## Command
```bash
pip install .; SemiBin2 single_easy_bin --input-fasta {input.i} \
            -b {input.b} \
            -o {output.dir} \
            -m 3000 \
            --sequencing-type {params.sequencing_type} \
            -p 1 \
            --epochs 2 --include_std 0 --checkpoint ""
```