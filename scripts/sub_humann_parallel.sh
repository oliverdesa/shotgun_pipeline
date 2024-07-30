#!/bin/bash
#SBATCH --account=
#SBATCH --time=05-00:00:00
#SBATCH --cpus-per-task=40
#SBATCH --mem=186G
#SBATCH --mail-user=your@email
#SBATCH --mail-type=ALL

module load python/3.10
module load StdEnv/2020
module load gcc/9.3.0
module load bowtie2/2.4.4
module load diamond/2.1.6

virtualenv --no-download $SLURM_TMPDIR/env
source $SLURM_TMPDIR/env/bin/activate
pip install --no-index --upgrade pip
pip install --no-index -r ../reqs/humann_3.6_requirements.txt

main_path="parent/directory"

batch="subdir_identifier"

# Create a temporary script for processing each sample
cat << 'EOF' > $SLURM_TMPDIR/process_sample.sh
#!/bin/bash
base=$1
humann --input ${main_path}/filt_reads/${batch}/${base} \
       --output ${main_path}/humann/${batch} \
       --output-basename ${base} \
       --protein-database path/to//humann_dbs/dmnd \
       --bypass-nucleotide-search \
       --taxonomic-profile 
       --threads 40 
EOF

chmod +x $SLURM_TMPDIR/process_sample.sh

export batch

# Find all _1.fastq files, extract the base names, and process them in parallel
ls ${main_path}filt_reads/${batch}/pooled | parallel -j 8 $SLURM_TMPDIR/process_sample.sh {}

echo "All HUMAnN3 analyses are complete."
