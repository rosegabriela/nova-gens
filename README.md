# NovaGens Metagenomics Analysis Platform

NovaGens provides **high-performance, reproducible metagenomic analysis** delivered through secure European cloud infrastructure.  
The service converts **raw paired-end sequencing reads** into **taxonomic insight, genome assemblies, and interactive microbiome visualisations**, using validated bioinformatics methods and controlled database governance.

This document describes:

- The **scientific processing pipeline**
- The **cloud infrastructure and data residency**
- The **reference database strategy**
- The **type of analytical service provided to customers**

---

# 1. Service Overview

NovaGens delivers a **fully managed metagenomics workflow**, including:

- Secure ingestion of FASTQ sequencing data  
- Read quality control and adapter trimming  
- De novo metagenomic assembly  
- Taxonomic classification against official Kraken2 databases  
- Interactive and report-ready visual outputs  
- Reproducible, audit-traceable execution  

Designed for:

- Research laboratories  
- Clinical and translational environments  
- Environmental microbiome studies  
- Biotechnology and genomic discovery  

---

# 2. Secure Infrastructure & Data Residency

## Cloud Region

All computation is executed in:

**AWS Europe (Stockholm, Sweden) – `eu-north-1`**

This ensures:

- European data residency  
- GDPR-aligned genomic data handling  
- Controlled scientific compute environment  
- No data transfer outside the EU during processing  

---

## Scientific Compute Environment

Metagenomic assembly and classification run on **memory-optimised AWS EC2 infrastructure**.

**Instance Type:** `r5.8xlarge`

| Resource | Specification |
|----------|--------------|
| CPU | 32 vCPUs (Intel Xeon Platinum class) |
| RAM | 256 GB DDR4 |
| Storage | High-speed NVMe scratch disk for assembly & I/O |
| OS | Linux (Ubuntu / Amazon Linux) |

### Rationale

- **MetaSPAdes** requires very high RAM availability  
- **Kraken2** benefits from parallel CPU execution  
- **NVMe storage** enables fast contig construction and read/write performance  

Instances **automatically shut down after analysis**, ensuring:

- Data minimisation  
- Cost efficiency  
- Clean compute environments between projects  

---

# 3. Scientific Processing Pipeline

NovaGens applies an **assembly-first metagenomic workflow**, improving taxonomic specificity compared with direct read classification.

## Step 1 — Secure Data Acquisition

- Paired-end FASTQ files retrieved from secure object storage  
- File integrity validated before processing  
- Processing occurs entirely within EU infrastructure  

---

## Step 2 — Read Quality Control & Trimming

**Toolchain:** Trim Galore (Cutadapt + FastQC)

Purpose:

- Remove sequencing adapters  
- Trim low-quality bases  
- Preserve paired-end synchronisation  
- Produce quality-controlled reads for assembly  

This reduces sequencing noise and improves downstream accuracy.

---

## Step 3 — De Novo Metagenomic Assembly

**Assembler:** MetaSPAdes

Characteristics:

- Designed for **mixed microbial communities**  
- Multi-k-mer graph assembly strategy  
- Produces **contigs representing genomic fragments**

Benefits:

- Higher taxonomic specificity  
- Reduced short-read false positives  
- Enables downstream comparative genomics  

---

## Step 4 — Taxonomic Classification

**Classifier:** Kraken2  
**Input:** Assembled contigs  

Kraken2 performs:

- Exact k-mer matching against reference genomes  
- Lowest Common Ancestor (LCA) assignment  
- Rapid, memory-efficient classification  

Outputs:

- Hierarchical taxonomic report  
- Raw classification assignments  
- Relative abundance summaries  

---

## Step 5 — Interactive Visualisation

**Tool:** Krona

Provides:

- Browser-based hierarchical microbiome exploration  
- Drill-down across taxonomic levels  
- Shareable interactive HTML visualisation  

---

## Step 6 — Archival & Reproducibility

Final deliverables include:

- Taxonomic reports  
- Interactive visualisations  
- Optional assembled contigs  
- Processing logs for full audit traceability  

All results are securely stored in EU infrastructure.

---

# 4. Reference Database Strategy

Accurate classification depends on **trusted, version-controlled reference genomes**.

NovaGens exclusively uses **official Kraken2 index builds** provided by:

**Ben Langmead AWS Kraken2 Index Repository**  
https://benlangmead.github.io/aws-indexes/k2

---

## Database Comparison Capability

Different biological questions require different reference scopes.  
NovaGens supports multiple database configurations:

| Database Type | Scientific Purpose |
|---------------|-------------------|
| Standard microbial reference | Broad detection across bacteria, archaea, viruses, and host filtering |
| PlusPF / extended reference | Includes plasmids and expanded eukaryotic content |
| Fungal-focused database | Targeted mycobiome and environmental fungal studies |
| Custom customer database | Project-specific comparative genomics |

Because Kraken2 databases are **versioned and traceable**, NovaGens enables:

- Reproducible historical analysis  
- Cross-database comparison studies  
- Publication-grade methodological transparency  

---

# 5. Type of Service Provided

NovaGens operates as a **managed scientific analysis service**, not only a computational pipeline.

Customers receive:

## Scientifically Interpretable Outputs

- Structured taxonomy reports  
- Interactive microbiome visualisations  
- Optional genome assemblies for research  

---

## Reproducible & Traceable Processing

Each analysis includes:

- Logged workflow execution  
- Database version tracking  
- Deterministic, repeatable computation  

Suitable for:

- Research publication  
- Regulatory or clinical environments  
- Long-term comparative studies  

---

## Secure European Genomic Processing

All genomic data:

- Processed in **Sweden (EU)**  
- Stored in controlled infrastructure  
- Never transferred outside the EU during analysis  

---

# 6. Typical Customer Workflow

1. Customer provides paired-end sequencing FASTQ files  
2. NovaGens executes the full metagenomic pipeline in EU cloud infrastructure  
3. Customer receives interpretable biological reports, visualisations, and optional assemblies  

---

# 7. Scientific Principles of NovaGens

NovaGens is built on:

- **Reproducibility** — versioned databases and deterministic workflows  
- **Accuracy** — assembly-based classification using validated tools  
- **Security** — EU-resident genomic data processing  
- **Clarity** — outputs designed for biological interpretation  

---

**NovaGens Bioinformatics & Cloud Engineering**  
Secure, reproducible metagenomics for research and discovery.
