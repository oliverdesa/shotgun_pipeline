#!/bin/bash
#SBATCH --account=3
#SBATCH --time=05-00:00:00
#SBATCH --cpus-per-task=40
#SBATCH --mem=186G
#SBATCH --mail-user=you@email
#SBATCH --mail-type=ALL

module load StdEnv/2020
module load python/3.10.2
module load gcc/9.3.0
module load trimmomatic/0.39
module load bowtie2/2.4.4
module load java/17.0.2
module load trf/4.09.1
module load fastqc/0.11.9

virtualenv --no-download $SLURM_TMPDIR/env
source $SLURM_TMPDIR/env/bin/activate
pip install --no-index --upgrade pip
pip install --no-index -r ../tools/cutadapt_4.2_requirements.txt

main_path="parent/directory/"

batch="subfolder_identifier"

# Create a temporary script for processing each sample
cat << 'EOF' > $SLURM_TMPDIR/process_sample.sh
#!/bin/bash
file=$1
batch="reads5"

acc=$(echo $file | sed 's/_1\.fq//')

cutadapt -j 5 --max-n 1 \
    -o main_path/trimmed_reads/${batch}/${acc}_1.fq \
    -p main_path/trimmed_reads/${batch}/${acc}_2.fq \
    main_path/${batch}/reads/${acc}_1.fq \
    main_path/${batch}/reads/${acc}_2.fq

sed 's/ 1.*/\/1/g' < main_path/trimmed_reads/${batch}/${acc}_1.fq > main_path/trimmed_reads/${batch}/n_${acc}_1.fq
sed 's/ 2.*/\/2/g' < main_path/trimmed_reads/${batch}/${acc}_2.fq > main_path/trimmed_reads/${batch}/n_${acc}_2.fq

rm main_path/trimmed_reads/${batch}/${acc}_1.fq 
rm main_path/trimmed_reads/${batch}/${acc}_2.fq

$HOME/.local/bin/kneaddata --input1 main_path/trimmed_reads/${batch}/n_${acc}_1.fq \
    --input2 main_path/trimmed_reads/${batch}/n_${acc}_2.fq \
    --output main_path/filt_reads/${batch}/${acc}/ \
    --output-prefix $acc -t 5 -p 5 --remove-intermediate-output \
    -db ../tools/databases/kneaddata/human_genome \
    -db ../tools/databases/kneaddata/phiX \
    --trimmomatic path/to/Trimmomatic-0.39 \
    --trimmomatic-options="SLIDINGWINDOW:4:20 MINLEN:75" \
    --run-fastqc-start --run-trim-repetitive 

rm main_path/trimmed_reads/${batch}/n_${acc}_1.fq 
rm main_path/trimmed_reads/${batch}/n_${acc}_2.fq
EOF

chmod +x $SLURM_TMPDIR/process_sample.sh

# Export necessary environment variables
export SLURM_TMPDIR

# Find all _1.fq files and process them in parallel
ls main_path/${batch}/reads/ | grep '_1.fq' | parallel -j 8 $SLURM_TMPDIR/process_sample.sh {}

echo "All Kneaddata analyses are complete."
