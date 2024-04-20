#!/bin/bash

#SBATCH --job-name=QC-bachelorproef
#SBATCH --output=QC-bachelorproef.out
#SBATCH --error=QC-bachelorproef.err

#SBATCH --partition=batch
#SBATCH --cluster=genius
#SBATCH --account=l_fishgenomics_at_kul
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=32
#SBATCH --time=24:00:00

module purge
module load cluster/genius/batch
module load FastQC/0.11.8-Java-1.8.0_162

# Location of files
cd /data/leuven/362/vsc36218/Diatoms/

# Quality control of rawdata
fastqc --threads $SLURM_NTASKS_PER_NODE 1_RawData/eDNA_bachelor_R1.fastq.gz 1_RawData/eDNA_bachelor_R2.fastq.gz

# Counting number of reads of rawdata
echo "R1 rawdata: " $(zcat 1_RawData/eDNA_bachelor_R1.fastq.gz | wc -l) > readcount.txt
echo "R2 rawdata: " $(zcat 1_RawData/eDNA_bachelor_R2.fastq.gz | wc -l) >> readcount.txt

# Trimming of rawdata -> trimmeddata
#module load Trimmomatic
java -jar $EBROOTTRIMMOMATIC/trimmomatic-0.39.jar PE \
       -threads $SLURM_NTASKS_PER_NODE \
       -phred33 \
       1_RawData/eDNA_bachelor_R1.fastq.gz  1_RawData/eDNA_bachelor_R2.fastq.gz  \
       2_TrimmedData/eDNA_bachelor_R1_paired.fastq.gz 2_TrimmedData/eDNA_bachelor_R1_unpaired.fastq.gz \
       2_TrimmedData/eDNA_bachelor_R2_paired.fastq.gz 2_TrimmedData/eDNA_bachelor_R2_unpaired.fastq.gz \
       LEADING:3 TRAILING:3 SLIDINGWINDOW:4:20 MINLEN:50 \
       ILLUMINACLIP:2_TrimmedData/adapters.fasta:2:30:10

# Quality control of trimmed data
fastqc --threads $SLURM_NTASKS_PER_NODE 2_TrimmedData/eDNA_bachelor_R1_paired.fastq.gz 2_TrimmedData/eDNA_bachelor_R2_paired.fastq.gz 

# Counting number of reads of trimmed data
echo "R1 paired data: " $(zcat 2_TrimmedData/eDNA_bachelor_R1_paired.fastq.gz | wc -l) >> readcount.txt
echo "R1 unpaired data: " $(zcat 2_TrimmedData/eDNA_bachelor_R1_unpaired.fastq.gz | wc -l) >> readcount.txt
echo "R2 paired data: " $(zcat 2_TrimmedData/eDNA_bachelor_R2_paired.fastq.gz | wc -l) >> readcount.txt
echo "R2 unpaired data: " $(zcat 2_TrimmedData/eDNA_bachelor_R2_unpaired.fastq.gz | wc -l) >> readcount.txt

module load SPAdes
module load BLAST+

# Source the Conda setup script
source /data/leuven/362/vsc36218/miniconda3/etc/profile.d/conda.sh          

# Activate the Conda environment
conda activate getorganelle
conda info --envs

READS1=/data/leuven/362/vsc36218/Diatoms/2_TrimmedData/eDNA_bachelor_R1_paired.fastq.gz
READS2=/data/leuven/362/vsc36218/Diatoms/2_TrimmedData/eDNA_bachelor_R2_paired.fastq.gz

mkdir 4_Assembly

get_organelle_from_reads.py -1 $READS1 -2 $READS2 -t $SLURM_NTASKS_PER_NODE \
                     -o 4_Assembly --overwrite \
                     -R 40 -k 21,45,65,85,105 \
                     -F other_pt --memory-save \
                     -s 3_DataBase/sequence.fasta \
                     --genes 3_DataBase/sequence.label.fasta \
                     --reduce-reads-for-coverage inf --max-reads inf \

