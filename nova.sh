#!/usr/bin/env bash
set -euo pipefail
set -o pipefail

# =========================
# NovaGens strict pipeline (no skipping)
# Usage:
#   ./nova.sh SAMPLE_NAME [S3_BUCKET]
# Examples:
#   ./nova.sh V1I4
#   ./nova.sh V1I4 novagens-data
# Optional overrides via env:
#   TRIM_ENV=trimming_env META_ENV=meta KRAKEN_ENV=kraken_env KRAKEN_THREADS=16 ./nova.sh V1I4
# =========================

trap '' HUP  # survive SSH hangups when launched with nohup

# -------- ARGS --------
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 SAMPLE_NAME [S3_BUCKET]"
  exit 1
fi
SAMPLE="$1"
S3_BUCKET="${2:-novagens-data}"

# -------- CONFIG --------
BASE="/work/nova/${SAMPLE}"
READS="${BASE}/reads"
TRIM="${BASE}/trimmed"
ASM="${BASE}/assembly/METASPADES_${SAMPLE}"
KRAKEN_OUT="${BASE}/classify_standard"
LOG="${BASE}/logs"
mkdir -p "$READS" "$TRIM" "$ASM" "$KRAKEN_OUT" "$LOG"

MASTER_LOG="${LOG}/master_${SAMPLE}.log"
# Mirror everything to master log
exec > >(tee -a "$MASTER_LOG") 2>&1

KRAKEN_DB_STD="${KRAKEN_DB_STD:-/work/nova/kraken_db/standard}"
KRAKEN_THREADS="${KRAKEN_THREADS:-16}"
NTHREADS="$(nproc)"

TRIM_ENV="${TRIM_ENV:-trimming_env}"
META_ENV="${META_ENV:-meta}"
KRAKEN_ENV="${KRAKEN_ENV:-kraken_env}"

note () { echo -e "\n[$(date '+%F %T')] $*"; }
checkpoint_ok () { echo -e "\n==== CHECKPOINT [OK] $* ====\n"; }

# -------- helpers --------
# Try to locate R1/R2 filenames in S3 for this SAMPLE (common patterns)
find_reads_in_s3() {
  local bucket="$1" sample="$2"
  note "Scanning s3://${bucket} for FASTQ pairs for sample ${sample}"
  # List keys once (faster) and search in-memory
  local keys
  keys="$(aws s3 ls "s3://${bucket}/" --recursive | awk '{$1=$2=$3=""; sub(/^   /,""); print }' || true)"

  # Patterns to try (ordered)
  local cands_r1=(
    "${sample}_1.fastq.gz" "${sample}_2.fastq.gz"    # canonical
    "${sample}_R1.fastq.gz" "${sample}_R2.fastq.gz"
    "${sample}_1.fq.gz"     "${sample}_2.fq.gz"
    "${sample}_R1.fq.gz"    "${sample}_R2.fq.gz"
  )
  # Lowercase variant too
  local s_low; s_low="$(echo "$sample" | tr '[:upper:]' '[:lower:]')"
  local cands_r1_low=(
    "${s_low}_1.fastq.gz" "${s_low}_2.fastq.gz"
    "${s_low}_R1.fastq.gz" "${s_low}_R2.fastq.gz"
    "${s_low}_1.fq.gz"     "${s_low}_2.fq.gz"
    "${s_low}_R1.fq.gz"    "${s_low}_R2.fq.gz"
  )

  # Search helper
  _pick_pair() {
    local a="$1" b="$2"
    local r1; r1="$(echo "$keys" | grep -F "$a" | awk '{print $NF}' | head -n1)"
    local r2; r2="$(echo "$keys" | grep -F "$b" | awk '{print $NF}' | head -n1)"
    if [[ -n "$r1" && -n "$r2" ]]; then
      echo "$r1|$r2"
      return 0
    fi
    return 1
  }

  # Try exact then lowercase variants
  local i pair
  for (( i=0; i<${#cands_r1[@]}; i+=2 )); do
    pair="$(_pick_pair "${cands_r1[$i]}" "${cands_r1[$i+1]}")" && { echo "$pair"; return 0; }
  done
  for (( i=0; i<${#cands_r1_low[@]}; i+=2 )); do
    pair="$(_pick_pair "${cands_r1_low[$i]}" "${cands_r1_low[$i+1]}")" && { echo "$pair"; return 0; }
  done

  return 1
}

# Conda init
eval "$(conda shell.bash hook)"

# -------- 0) Sanity --------
note "NovaGens pipeline start | Sample=${SAMPLE} | Bucket=${S3_BUCKET}"
note "Cores: trim=${NTHREADS}, kraken=${KRAKEN_THREADS}"
[ -s "${KRAKEN_DB_STD}/hash.k2d" ] || { echo "ERROR: Kraken DB not found at ${KRAKEN_DB_STD}"; exit 1; }

# -------- 1) Locate & download reads from S3 --------
note "Step 1/5: Locate & download reads"
PAIR="$(find_reads_in_s3 "${S3_BUCKET}" "${SAMPLE}")" || { echo "ERROR: Could not find paired FASTQs for ${SAMPLE} in s3://${S3_BUCKET}/"; exit 1; }
R1_KEY="$(echo "$PAIR" | cut -d'|' -f1)"
R2_KEY="$(echo "$PAIR" | cut -d'|' -f2)"
note "Found: R1=s3://${S3_BUCKET}/${R1_KEY} | R2=s3://${S3_BUCKET}/${R2_KEY}"

aws s3 cp "s3://${S3_BUCKET}/${R1_KEY}" "$READS/${SAMPLE}_1.fastq.gz" --no-progress
aws s3 cp "s3://${S3_BUCKET}/${R2_KEY}" "$READS/${SAMPLE}_2.fastq.gz" --no-progress
ls -lh "$READS/${SAMPLE}_1.fastq.gz" "$READS/${SAMPLE}_2.fastq.gz"
checkpoint_ok "READS DOWNLOADED"

# -------- 2) TRIMMING (trimming_env) --------
note "Step 2/5: TRIMMING → env: ${TRIM_ENV}"
conda activate "${TRIM_ENV}"

trim_galore --paired --fastqc --retain_unpaired \
  --cores "${NTHREADS}" \
  -o "$TRIM" \
  "$READS/${SAMPLE}_1.fastq.gz" \
  "$READS/${SAMPLE}_2.fastq.gz" \
  |& tee "${LOG}/trim_galore_${SAMPLE}.log"

LEFT_TRIMMED="$(ls "$TRIM"/*_1_val_1.fq.gz | head -n1 || true)"
RIGHT_TRIMMED="$(ls "$TRIM"/*_2_val_2.fq.gz" | head -n1 || true)"
[[ -n "${LEFT_TRIMMED}" && -n "${RIGHT_TRIMMED}" ]] || { echo "ERROR: Trimmed pairs not found in $TRIM"; exit 1; }
note "Trimmed: $(basename "$LEFT_TRIMMED"), $(basename "$RIGHT_TRIMMED")"
checkpoint_ok "TRIMMING COMPLETED"

# -------- 3) ASSEMBLY (meta) --------
note "Step 3/5: ASSEMBLY → env: ${META_ENV}"
conda activate "${META_ENV}"
which spades.py

spades.py --meta \
  -1 "$LEFT_TRIMMED" -2 "$RIGHT_TRIMMED" \
  -t "$(nproc)" -k 21,33,55,77,99,111,127 \
  -o "$ASM" \
  |& tee "${LOG}/spades_${SAMPLE}.log"

CONTIGS="${ASM}/contigs.fasta"
[ -s "$CONTIGS" ] || { echo "ERROR: contigs.fasta not found at $CONTIGS"; exit 1; }
ls -lh "$CONTIGS"
checkpoint_ok "ASSEMBLY COMPLETED"

# -------- 4) KRAKEN2 (kraken_env) --------
note "Step 4/5: KRAKEN2 → env: ${KRAKEN_ENV}"
conda activate "${KRAKEN_ENV}"

KOUT="${KRAKEN_OUT}/${SAMPLE}_kraken_standard.out"
KREP="${KRAKEN_OUT}/${SAMPLE}_kraken_standard.report"
KLOG="${KRAKEN_OUT}/${SAMPLE}_kraken_standard.log"
mkdir -p "$KRAKEN_OUT"

# use high-performance flags (~30–40 min typical on 16 cores)
/data/conda_envs/kraken_env/bin/kraken2 \
  --db "$KRAKEN_DB_STD" \
  --memory-mapping \
  --threads ${KRAKEN_THREADS} \
  --use-mpa-style \
  --confidence 0.1 \
  --minimum-hit-groups 2 \
  --quick \
  --output  "$KOUT" \
  --report  "$KREP" \
  "$CONTIGS" \
  |& tee "$KLOG"

[ -s "$KOUT" ] && [ -s "$KREP" ] || { echo "ERROR: Kraken outputs missing"; exit 1; }
ls -lh "$KOUT" "$KREP"
checkpoint_ok "KRAKEN2 CLASSIFICATION COMPLETED"

# -------- 5) Post-processing & KRONA --------
note "Step 5/5: KRONA + post-processing (still in ${KRAKEN_ENV})"
pushd "$KRAKEN_OUT" >/dev/null

awk '$3=="C"{print $2}' "$(basename "$KOUT")" > class_contig.txt
awk '$3=="U"{print $2}' "$(basename "$KOUT")" > UNCLASS_contigs.txt

KRONA_HTML="krona_${SAMPLE}_standard.html"
set +e
ktImportTaxonomy -q 2 -t 3 "$(basename "$KOUT")" -o "$KRONA_HTML"
RC=$?
set -e
if [[ $RC -ne 0 ]]; then
  note "Krona taxonomy missing; updating once..."
  ktUpdateTaxonomy.sh || true
  ktImportTaxonomy -q 2 -t 3 "$(basename "$KOUT")" -o "$KRONA_HTML"
fi

[ -s "$KRONA_HTML" ] || { echo "ERROR: Krona HTML not generated"; exit 1; }
ls -lh "$KRONA_HTML"
popd >/dev/null
checkpoint_ok "KRONA & POST-PROCESSING COMPLETED"

# -------- Upload artefacts to S3 (minimal outputs only) --------
note "Uploading minimal outputs to S3 (contigs.fasta, .report, .html only)"

# 1️⃣ Assembly contigs
aws s3 cp "/work/nova/${SAMPLE}/assembly/METASPADES_${SAMPLE}/contigs.fasta" \
  "s3://${S3_BUCKET}/results/${SAMPLE}/" --no-progress

# 2️⃣ Kraken report
aws s3 cp "${KRAKEN_OUT}/${SAMPLE}_kraken_standard.report" \
  "s3://${S3_BUCKET}/results/${SAMPLE}/" --no-progress

# 3️⃣ Krona HTML
aws s3 cp "${KRAKEN_OUT}/krona_${SAMPLE}_standard.html" \
  "s3://${S3_BUCKET}/results/${SAMPLE}/" --no-progress

checkpoint_ok "UPLOAD TO S3 COMPLETED (contigs.fasta, report, html)"
note "Pipeline finished successfully ✅"
