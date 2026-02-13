cat << 'EOF' > run_ALL_samples.sh
#!/usr/bin/env bash
set -e
set -o pipefail

# --- CONFIGURATION ---
S3_BUCKET="novagens-data"
S3_FOLDER="2-AN00027564"
PROJECT="/data/nova/AN00027564"
LOG_DIR="${PROJECT}/pipeline_logs"
mkdir -p "$LOG_DIR"

log() { echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

# 1. GET LIST OF SAMPLES FROM S3
log "🔍 Scanning S3 for samples..."
# List files, filter for _1.fastq.gz, extract sample name
SAMPLES=$(aws s3 ls "s3://${S3_BUCKET}/${S3_FOLDER}/" | grep "_1.fastq.gz" | awk '{print $4}' | sed 's/_1.fastq.gz//')

if [ -z "$SAMPLES" ]; then
    log "❌ ERROR: No samples found in s3://${S3_BUCKET}/${S3_FOLDER}/"
    exit 1
fi

log "✅ Found samples to check: $SAMPLES"

# 2. LOOP THROUGH EACH SAMPLE
for SAMPLE in $SAMPLES; do
    
    # ---------------------------------------------------------
    # SMART CHECK: DOES THE RESULT EXIST IN S3?
    # ---------------------------------------------------------
    if aws s3 ls "s3://${S3_BUCKET}/${S3_FOLDER}/results/${SAMPLE}_krona_standard.html" > /dev/null 2>&1; then
        log "⏭️  SKIP: ${SAMPLE} is already done (Found in S3 results)."
        continue
    fi
    # ---------------------------------------------------------

    log "🚀 STARTING PIPELINE FOR: ${SAMPLE}"
    
    BASE="${PROJECT}/${SAMPLE}"
    READS="${BASE}/reads"
    TRIM="${BASE}/trimmed"
    ASM="${BASE}/assembly/METASPADES_${SAMPLE}"
    OUT_STD="${BASE}/classify_standard"
    LOGS="${BASE}/logs"

    # Create directories
    mkdir -p "$READS" "$TRIM" "$ASM" "$OUT_STD" "$LOGS"

    # --- PHASE 1: DOWNLOAD ---
    log "Phase 1: Downloading..."
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate trimming_env
    aws s3 cp "s3://${S3_BUCKET}/${S3_FOLDER}/${SAMPLE}_1.fastq.gz" "$READS/" --no-progress
    aws s3 cp "s3://${S3_BUCKET}/${S3_FOLDER}/${SAMPLE}_2.fastq.gz" "$READS/" --no-progress

    # --- PHASE 2: TRIMMING (16 Cores) ---
    log "Phase 2: Trimming..."
    trim_galore --paired --fastqc --retain_unpaired --cores 16 \
      -o "$TRIM" "$READS/${SAMPLE}_1.fastq.gz" "$READS/${SAMPLE}_2.fastq.gz" > "$LOGS/trim_galore.log" 2>&1

    # --- PHASE 3: ASSEMBLY (32 Threads) ---
    log "Phase 3: Assembly..."
    conda activate meta
    VAL_1="${TRIM}/${SAMPLE}_1_val_1.fq.gz"
    VAL_2="${TRIM}/${SAMPLE}_2_val_2.fq.gz"
    
    # Clean old assembly folder to avoid SPAdes resume errors
    rm -rf "$ASM"
    
    spades.py --meta -1 "$VAL_1" -2 "$VAL_2" \
      -t 32 -m 240 -k 21,33,55,77,99,111,127 \
      -o "$ASM" > "$LOGS/spades.log" 2>&1

    # --- PHASE 4: CLASSIFICATION (32 Threads) ---
    log "Phase 4: Classification..."
    conda activate kraken_env
    DB_STD="/data/nova/kraken_db/standard"

    kraken2 --db "$DB_STD" --threads 32 --use-mpa-style --quick \
      --output "$OUT_STD/${SAMPLE}_standard.out" \
      --report "$OUT_STD/${SAMPLE}_standard.report" \
      "$ASM/contigs.fasta" > "$LOGS/kraken_standard.log" 2>&1

    # --- PHASE 5: UPLOAD ---
    log "Phase 5: Generating Charts & Uploading..."
    cd "$OUT_STD"
    
    # Auto-update Krona (preventative)
    ktUpdateTaxonomy.sh > "$LOGS/krona_update.log" 2>&1 || true

    ktImportTaxonomy -q 2 -t 3 "${SAMPLE}_standard.out" -o "${SAMPLE}_krona_standard.html"

    S3_DEST="s3://${S3_BUCKET}/${S3_FOLDER}/results"
    aws s3 cp "${SAMPLE}_standard.report" "$S3_DEST/"
    aws s3 cp "${SAMPLE}_krona_standard.html" "$S3_DEST/"

    log "✅ DONE with ${SAMPLE}!"
    
    # CLEANUP (To save disk space)
    rm -rf "$READS" "$TRIM" "$ASM" 

done

log "🎉 ALL SAMPLES COMPLETED!"
log "💤 SHUTTING DOWN SERVER IN 1 MINUTE..."
sleep 60
sudo shutdown -h now
EOF