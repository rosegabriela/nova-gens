NovaGens Metagenomics Pipeline

Automated, high-performance metagenomics analysis pipeline designed for AWS EC2 execution. This pipeline processes raw sequencing data from S3, performs quality control, de novo assembly, taxonomic classification, and generates interactive visualizations, with automatic resource management (auto-shutdown).

🏗 Infrastructure & Hardware

The pipeline is optimized for memory-intensive assembly and rapid classification using AWS memory-optimized instances.

Instance Type: AWS EC2 r5.8xlarge

CPU: 32 vCPUs (Intel Xeon Platinum 8000 series)

RAM: 256 GB DDR4 Memory

Storage: * Root Volume: OS & Software

Mounted Volume (/data): High-performance NVMe SSD for Database & I/O operations

OS: Amazon Linux 2 / Ubuntu

🧬 Pipeline Workflow
The pipeline (run_ALL_samples.sh) executes the following stages sequentially for every sample found in the S3 bucket:

S3 Discovery & Smart Resume:

Scans s3://novagens-data/2-AN00027564/ for paired-end reads (_1.fastq.gz).

Logic: Checks if results already exist in S3. If found, the sample is skipped to save compute time and cost.

Data Acquisition:

Downloads raw paired-end FASTQ files from Amazon S3 to the local high-speed disk.

Quality Control (Trim Galore):

Tool: trim_galore (Wrapper for Cutadapt & FastQC)

Config: --paired --fastqc --retain_unpaired --cores 16

Removes adapters and low-quality bases.

De Novo Assembly (MetaSPAdes):

Tool: spades.py (v3.15+)

Config: --meta -t 32 -m 240 -k 21,33,55,77,99,111,127

Constructs contigs from short reads using 32 threads and up to 240GB RAM.

Taxonomic Classification (Kraken2):

Tool: kraken2

Database: Standard Kraken2 Database (Oct 2025 Build, ~72GB)

Config: --threads 32 --use-mpa-style --quick --memory-mapping

Assigns taxonomic labels to assembled contigs.

Visualization (Krona):

Tool: ktImportTaxonomy

Generates an interactive HTML sunburst chart (.html) for exploring the microbiome hierarchy.

Archival & Shutdown:

Uploads reports (.report) and charts (.html) back to S3.

Cleans up large intermediate files to free disk space.

Auto-Shutdown: Automatically terminates the EC2 instance upon completion of all samples to prevent billing.

🛠 Dependencies & Installation
The pipeline relies on Conda environments for reproducibility.

1. Conda Environments
trimming_env: Contains trim-galore, fastqc, cutadapt.

meta: Contains spades.

kraken_env: Contains kraken2, krona.

2. Database Setup
The pipeline uses the full Standard Kraken2 Database (Bacteria, Archaea, Virus, Human, UniVec).

Source: Ben Langmead's Kraken2 Index

Link Used: https://genome-idx.s3.amazonaws.com/kraken/k2_standard_20251015.tar.gz

Location: /data/nova/kraken_db/standard/

Files Required: hash.k2d, opts.k2d, taxo.k2d

🚀 Usage
1. Setup the Script
Ensure the script is executable:

Bash
chmod +x run_ALL_samples.sh
2. Run in Background ("Fire and Forget")
Use nohup to keep the process running after disconnecting SSH. The script handles the loop and final shutdown.

Bash
nohup bash run_ALL_samples.sh > pipeline.log 2>&1 &
3. Monitoring
Check the progress in real-time:

Bash
tail -f pipeline.log
📂 Output Structure (S3)
Results are uploaded to s3://novagens-data/2-AN00027564/results/:

SAMPLE_standard.report: Text-based report compatible with Pavian/Breckenridge.

SAMPLE_krona_standard.html: Interactive HTML visualization.

📝 Script Configuration Variables
Variable	Description	Default
S3_BUCKET	AWS S3 Bucket Name	novagens-data
S3_FOLDER	Input Data Folder Path	2-AN00027564
PROJECT	Local Working Directory	/data/nova/AN00027564
DB_STD	Kraken2 Database Path	/data/nova/kraken_db/standard
Maintained by NovaGens Bioinformatics Team