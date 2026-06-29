#!/usr/bin/env bash
#SBATCH --job-name=genemark_diamond
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=04:00:00

set -euo pipefail
set -x

: "${CONFIG:?CONFIG not set}"
: "${SAMPLE:?SAMPLE not set}"
: "${HITS_TSV:?HITS_TSV not set}"
: "${OUTDIR:?OUTDIR not set}"

source "$CONFIG"

module load perlbrew/0.98 || true
module load perl/bio-extras || true
module load GeneMark/4.73 || true
module load seqkit || true
module load python || true

: "${CONTIGS_DIR:?CONTIGS_DIR not set}"
: "${SCRIPTS_DIR:?SCRIPTS_DIR not set}"
: "${DIAMONDDB_RDRP:?DIAMONDDB_RDRP not set}"
: "${DIAMOND_BIN:?DIAMOND_BIN not set in config/pipeline.env}"

# Optional knobs (can be exported in pipeline.env)
: "${VIRUS_GENOME_HINT:=auto}"          # auto|rna|dna
: "${ORF_MIN_AA:=100}"                  # min aa length for ORF finder mode
: "${ORF_START_MODE:=all}"              # all|atg ; all = any codon start
: "${DNA_INTRON_AWARE_MIN_BP:=20000}"   # if auto and max contig >= this => try DNA/intron-aware path

contigs_fa="${CONTIGS_DIR}/${SAMPLE}/contigs.fasta"
[[ -s "$contigs_fa" ]] || { echo "ERROR: Missing contigs: $contigs_fa" >&2; exit 1; }
[[ -s "$HITS_TSV" ]] || { echo "ERROR: Missing TSV: $HITS_TSV" >&2; exit 1; }

mkdir -p "$OUTDIR"
cd "$OUTDIR"

# 0) Filter combined hits table to this SAMPLE only
sample_hits="${OUTDIR}/${SAMPLE}.nt_filtered_hits.tsv"
awk -F'\t' -v s="$SAMPLE" '
NR==1 { print; next }
$18==s || $18==s"_nt_blast" || index($18, s)==1 { print }
' "$HITS_TSV" > "$sample_hits"

if [[ ! -s "$sample_hits" ]] || (( $(wc -l < "$sample_hits") < 2 )); then
  echo "ERROR: No rows for sample '$SAMPLE' found in $HITS_TSV" >&2
  exit 1
fi

# 1) Select contig IDs
selected_ids="${OUTDIR}/${SAMPLE}.selected_contigs.txt"
bash "${SCRIPTS_DIR}/8_pipeline_select_viral_contigs_from_hits.sh" "$sample_hits" > "$selected_ids"
[[ -s "$selected_ids" ]] || { echo "ERROR: No contigs selected for $SAMPLE" >&2; exit 1; }

# 2) Extract selected contigs
selected_fa="${OUTDIR}/${SAMPLE}.selected_contigs.fasta"
seqkit grep -f "$selected_ids" "$contigs_fa" > "$selected_fa"
[[ -s "$selected_fa" ]] || { echo "ERROR: Empty selected FASTA: $selected_fa" >&2; exit 1; }

# Output layout
gm_out="${OUTDIR}/${GM_OUT_SUBDIR:-genemark}"
mkdir -p "$gm_out"

gm_pred="${gm_out}/genemark.pred"
proteins_faa="${gm_out}/${GM_PROTEINS_BASENAME:-proteins.faa}"
nucs_fna="${gm_out}/${GM_NUCS_BASENAME:-proteins.fna}"

rm -f "$gm_pred" "$proteins_faa" "$nucs_fna"

# Decide branch: RNA-like ORF finder vs DNA-like gmhmme3
branch=""
if [[ "${VIRUS_GENOME_HINT}" == "rna" ]]; then
  branch="rna_orf"
elif [[ "${VIRUS_GENOME_HINT}" == "dna" ]]; then
  branch="dna_gmhmme3"
else
  # auto heuristic based on contig max length
  max_len=$(awk '
    /^>/{
      if (seqlen>max) max=seqlen
      seqlen=0
      next
    }
    { gsub(/[ \t\r\n]/,"",$0); seqlen += length($0) }
    END{
      if (seqlen>max) max=seqlen
      print (max+0)
    }' "$selected_fa")
  if (( max_len >= DNA_INTRON_AWARE_MIN_BP )); then
    branch="dna_gmhmme3"
  else
    branch="rna_orf"
  fi
fi

echo "Genome-type branch for $SAMPLE: $branch (VIRUS_GENOME_HINT=$VIRUS_GENOME_HINT)"

if [[ "$branch" == "dna_gmhmme3" ]]; then
  ########################################
  # DNA-like / intron-aware path: gmhmme3
  ########################################
  command -v gmhmme3 >/dev/null 2>&1 || { echo "ERROR: gmhmme3 not found for DNA-like path" >&2; exit 1; }

  GM_BASE="$(dirname "$(command -v gmhmme3)")"
  MODEL_FILE="$(find "$GM_BASE/heu_dir" -type f -name "*.mod" | head -n1 || true)"
  [[ -n "${MODEL_FILE:-}" && -s "$MODEL_FILE" ]] || { echo "ERROR: No GeneMark model in $GM_BASE/heu_dir" >&2; exit 1; }

  echo "Using GeneMark model: $MODEL_FILE"
  gmhmme3 -m "$MODEL_FILE" -o "$gm_pred" "$selected_fa"
  [[ -s "$gm_pred" ]] || { echo "ERROR: gmhmme3 did not produce $gm_pred" >&2; exit 1; }

  # Parse genemark.pred -> proteins.faa + proteins.fna
  python3 - "$gm_pred" "$selected_fa" "$proteins_faa" "$nucs_fna" << 'PY'
import sys, re
pred_path, fasta_path, out_prot, out_nuc = sys.argv[1:5]

# read fasta
seqs={}
name=None
buf=[]
with open(fasta_path) as fh:
    for line in fh:
        line=line.strip()
        if not line: continue
        if line.startswith(">"):
            if name is not None: seqs[name]="".join(buf).upper()
            name=line[1:].split()[0]
            buf=[]
        else:
            buf.append(line)
if name is not None: seqs[name]="".join(buf).upper()
if not seqs:
    print("ERROR: no sequences in FASTA", file=sys.stderr); sys.exit(1)

exon_re = re.compile(r'^\s*(\d+)\s+(\d+)\s+([+-])\s+\S+\s+(\d+)\s+(\d+)\b')
def_re  = re.compile(r'^FASTA defline:\s+>(\S+)')
genes={}
curr=None

with open(pred_path) as fh:
    for raw in fh:
        line=raw.rstrip("\n")
        m=def_re.match(line)
        if m:
            curr=m.group(1); continue
        m=exon_re.match(line)
        if not m or curr is None: continue
        gid=int(m.group(1)); exid=int(m.group(2)); strand=m.group(3)
        s=int(m.group(4)); e=int(m.group(5))
        genes.setdefault((curr,gid,strand), []).append((s,e,exid))

if not genes:
    print("ERROR: no exons parsed from genemark.pred", file=sys.stderr); sys.exit(1)

comp=str.maketrans("ACGTNacgtn","TGCANtgcan")
tbl={'TTT':'F','TTC':'F','TTA':'L','TTG':'L','TCT':'S','TCC':'S','TCA':'S','TCG':'S',
'TAT':'Y','TAC':'Y','TAA':'*','TAG':'*','TGT':'C','TGC':'C','TGA':'*','TGG':'W',
'CTT':'L','CTC':'L','CTA':'L','CTG':'L','CCT':'P','CCC':'P','CCA':'P','CCG':'P',
'CAT':'H','CAC':'H','CAA':'Q','CAG':'Q','CGT':'R','CGC':'R','CGA':'R','CGG':'R',
'ATT':'I','ATC':'I','ATA':'I','ATG':'M','ACT':'T','ACC':'T','ACA':'T','ACG':'T',
'AAT':'N','AAC':'N','AAA':'K','AAG':'K','AGT':'S','AGC':'S','AGA':'R','AGG':'R',
'GTT':'V','GTC':'V','GTA':'V','GTG':'V','GCT':'A','GCC':'A','GCA':'A','GCG':'A',
'GAT':'D','GAC':'D','GAA':'E','GAG':'E','GGT':'G','GGC':'G','GGA':'G','GGG':'G'}

def rc(s): return s.translate(comp)[::-1]
def tr(nt):
    nt=nt.upper(); aa=[]
    for i in range(0,len(nt)-2,3): aa.append(tbl.get(nt[i:i+3],'X'))
    return "".join(aa)

n=0
with open(out_prot,"w") as fpro, open(out_nuc,"w") as fnuc:
    for (contig,gid,strand), exons in sorted(genes.items(), key=lambda x:(x[0][0],x[0][1])):
        seq=seqs.get(contig)
        if not seq: continue
        parts=[]
        for s,e,_ in sorted(exons,key=lambda t:t[0]):
            a=min(s,e)-1; b=max(s,e)
            if a<0 or b>len(seq): continue
            parts.append(seq[a:b])
        if not parts: continue
        cds="".join(parts)
        if strand=="-": cds=rc(cds)
        rem=len(cds)%3
        if rem: cds=cds[:-rem]
        if len(cds)<3: continue
        aa=tr(cds)
        if aa.endswith("*"): aa=aa[:-1]
        if not aa: continue
        h=f"{contig}|gene{gid}|strand{strand}|source=gmhmme3|len_nt={len(cds)}|len_aa={len(aa)}"
        fnuc.write(f">{h}\n")
        for i in range(0,len(cds),80): fnuc.write(cds[i:i+80]+"\n")
        fpro.write(f">{h}\n")
        for i in range(0,len(aa),80): fpro.write(aa[i:i+80]+"\n")
        n+=1

if n==0:
    print("ERROR: gmhmme3 parser produced zero protein records", file=sys.stderr); sys.exit(1)
print(f"Parsed genes written: {n}", file=sys.stderr)
PY

else
  ########################################
  # RNA-like path: intronless 6-frame ORF finder
  ########################################
  python3 - "$selected_fa" "$proteins_faa" "$nucs_fna" "$ORF_MIN_AA" "$ORF_START_MODE" << 'PY'
import sys

fasta_path, out_prot, out_nuc, min_aa_s, start_mode = sys.argv[1:6]
min_aa = int(min_aa_s)
start_mode = start_mode.lower()

seqs={}
name=None
buf=[]
with open(fasta_path) as fh:
    for line in fh:
        line=line.strip()
        if not line: continue
        if line.startswith(">"):
            if name is not None: seqs[name]="".join(buf).upper()
            name=line[1:].split()[0]
            buf=[]
        else:
            buf.append(line)
if name is not None: seqs[name]="".join(buf).upper()

if not seqs:
    print("ERROR: no sequences in FASTA", file=sys.stderr); sys.exit(1)

comp=str.maketrans("ACGTNacgtn","TGCANtgcan")
tbl={'TTT':'F','TTC':'F','TTA':'L','TTG':'L','TCT':'S','TCC':'S','TCA':'S','TCG':'S',
'TAT':'Y','TAC':'Y','TAA':'*','TAG':'*','TGT':'C','TGC':'C','TGA':'*','TGG':'W',
'CTT':'L','CTC':'L','CTA':'L','CTG':'L','CCT':'P','CCC':'P','CCA':'P','CCG':'P',
'CAT':'H','CAC':'H','CAA':'Q','CAG':'Q','CGT':'R','CGC':'R','CGA':'R','CGG':'R',
'ATT':'I','ATC':'I','ATA':'I','ATG':'M','ACT':'T','ACC':'T','ACA':'T','ACG':'T',
'AAT':'N','AAC':'N','AAA':'K','AAG':'K','AGT':'S','AGC':'S','AGA':'R','AGG':'R',
'GTT':'V','GTC':'V','GTA':'V','GTG':'V','GCT':'A','GCC':'A','GCA':'A','GCG':'A',
'GAT':'D','GAC':'D','GAA':'E','GAG':'E','GGT':'G','GGC':'G','GGA':'G','GGG':'G'}
stops={"TAA","TAG","TGA"}

def rc(s): return s.translate(comp)[::-1]
def tr(nt):
    aa=[]
    for i in range(0,len(nt)-2,3): aa.append(tbl.get(nt[i:i+3],'X'))
    return "".join(aa)

def find_orfs(seq, strand_label):
    out=[]
    L=len(seq)
    for frame in (0,1,2):
        i=frame
        while i+3<=L:
            cod=seq[i:i+3]
            if start_mode=="atg" and cod!="ATG":
                i+=3
                continue
            # start ORF at current codon (all) or ATG-only
            j=i
            found_stop=False
            while j+3<=L:
                c=seq[j:j+3]
                if c in stops:
                    found_stop=True
                    break
                j+=3
            if found_stop:
                end=j+3
            else:
                end=L-((L-i)%3)
            nt=seq[i:end]
            if len(nt)>=min_aa*3:
                aa=tr(nt)
                if aa.endswith("*"): aa=aa[:-1]
                if len(aa)>=min_aa:
                    out.append((i,end,frame,nt,aa,strand_label))
            i+=3
    return out

n=0
with open(out_prot,"w") as fpro, open(out_nuc,"w") as fnuc:
    for cid, seq in seqs.items():
        all_orfs=[]
        all_orfs.extend(find_orfs(seq, "+"))
        r=rc(seq)
        all_orfs.extend(find_orfs(r, "-"))

        # deduplicate by aa sequence and keep longest first
        all_orfs.sort(key=lambda x: len(x[4]), reverse=True)
        seen=set()
        uniq=[]
        for rec in all_orfs:
            key=rec[4]
            if key in seen: 
                continue
            seen.add(key)
            uniq.append(rec)

        for idx, (s,e,fr,nt,aa,strand) in enumerate(uniq, start=1):
            h=f"{cid}|orf{idx}|strand{strand}|frame={fr}|source=orf_finder|len_nt={len(nt)}|len_aa={len(aa)}"
            fnuc.write(f">{h}\n")
            for k in range(0,len(nt),80): fnuc.write(nt[k:k+80]+"\n")
            fpro.write(f">{h}\n")
            for k in range(0,len(aa),80): fpro.write(aa[k:k+80]+"\n")
            n+=1

if n==0:
    print("ERROR: ORF finder produced zero proteins", file=sys.stderr); sys.exit(1)
print(f"ORFs written: {n}", file=sys.stderr)
PY
fi

# Validate proteins FASTA
[[ -s "$proteins_faa" ]] || { echo "ERROR: proteins.faa missing/empty: $proteins_faa" >&2; exit 1; }
grep -q '^>' "$proteins_faa" || { echo "ERROR: proteins.faa is not FASTA" >&2; head -n 40 "$proteins_faa" >&2; exit 1; }

# 4) DIAMOND blastp against RdRp DB
diamond_out="${OUTDIR}/${SAMPLE}.rdrp_diamond.tsv"

if [[ -n "${DIAMOND_BIN:-}" && -x "${DIAMOND_BIN}" ]]; then
  DIAMOND_EXEC="${DIAMOND_BIN}"
elif command -v diamond >/dev/null 2>&1; then
  DIAMOND_EXEC="diamond"
else
  echo "ERROR: No DIAMOND executable found" >&2
  exit 1
fi

echo "Using DIAMOND executable: ${DIAMOND_EXEC}"

"${DIAMOND_EXEC}" blastp \
  --db "$DIAMONDDB_RDRP" \
  --query "$proteins_faa" \
  --threads "${SLURM_CPUS_PER_TASK:-4}" \
  --sensitive \
  --evalue 1e-2 \
  --max-target-seqs 25 \
  --outfmt 6 qseqid sseqid pident length evalue bitscore stitle \
  --out "$diamond_out"

if [[ -s "$diamond_out" ]]; then
  echo "DIAMOND produced hits: $diamond_out"
else
  echo "WARNING: DIAMOND completed but produced 0 hits for sample=$SAMPLE"
  : > "$diamond_out"
fi

echo "DONE sample=$SAMPLE"
echo "branch=$branch"
echo "sample_hits=$sample_hits"
echo "selected_ids=$selected_ids"
echo "selected_fa=$selected_fa"
echo "gm_pred=$gm_pred"
echo "nucs_fna=$nucs_fna"
echo "proteins_faa=$proteins_faa"
echo "diamond_out=$diamond_out"
echo "DIAMOND_EXEC=$DIAMOND_EXEC"
echo "gm_out=$gm_out"