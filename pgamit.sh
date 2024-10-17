#!/bin/bash
#SBATCH --time=96:00:00
#SBATCH --nodes=4 --cpus-per-task=48 --partition=acomputeq
#SBATCH --mem-per-cpu=3500M
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --job-name=Parallel_GAMIT
#SBATCH --mail-type=all --mail-user=%u@memphis.edu

# This is a version for bigblue at the university of memphis using singularity.

# This line was in the file previously (small correction for the partition)
##SBATCH --nodes=4 --ntasks-per-node=48 --partition=acomputeq
# but, if you use 4 nodes and 48 tasks per node, slurm cgroups is 
# going to force each task onto 1 CPU afinity as it was written.



# some definitions for the run

echo " >> Started at" $(date) "requested by" ${USER}

module load singularity                 # load the singularity package

BIGBLUE_PGAMIT_DIR="/project/${USER}/bigblue-pgamit"

# singularity shorthand, yes you need the whole line,
# and the sif file can be anywhere in /home, /project, or /scratch
SINGULARITY_EXEC="singularity exec --bind /mmfs1/project:/project --bind /mmfs1/scratch:/scratch --cleanenv ${BIGBLUE_PGAMIT_DIR}/bin/pgamit.sif "

# Temporary and output data
SCRATCH_DIR="/scratch/${USER}/${SLURM_JOB_ID}"
# Structure:
# ${SCRATCH_DIR} is root out
# ${SCRATCH_DIR}/${node} is each nodes' temporary data

# Set this to your input project
# This should have the gnss config file, PPP_NRCAN scripts, etc...
#PROJECT_DIR="/project/${USER}/"
PROJECT_DIR=$SLURM_SUBMIT_DIR

# create a var for the execution of the dispynode script
dispynode="$SINGULARITY_EXEC dispynode.py"

# Information about the PPP_NRCAN scripts?
PPP_VER=1.10
PPP_SCRIPT_DIR=${PROJECT_DIR}/PPP_NRCAN_${PPP_VER}

#GAMIT data directory
export DATADIR=/project/${USER}/gamitData

set -x  # Echo commands
set -e  # Exit script if a command fails

# generate the access to the list of nodes
SLURM_NODEFILE=`${BIGBLUE_PGAMIT_DIR}/bin/generate_pbs_nodefile.pl`

# add the .cluster (or .ib.cluster) to create the FQDN.
# I would suggest trying both to see if latency matters
#cat $SLURM_NODEFILE | awk '{print $1".cluster"}' > $PROJECT_DIR/opt/Parallel.GAMIT/scripts/nodes.txt
# SLURM_NODEFILE=$PROJECT_DIR/opt/Parallel.GAMIT/scripts/nodes.txt

# Create a variable containing the name of the headnode, for example ac01.cluster
headnode=`hostname | awk -F . '{print $1".cluster"}'`
echo headnode: $headnode

#create the files containing column and row lists of all (head + worker) complete node names and all node numbers 
nodes=($( grep -v $headnode $SLURM_NODEFILE | sort | uniq )) # Create a variable with the list of worker nodes. 

# Create a string separated by commas with all the worker nodes.
all_nodes=($( cat $SLURM_NODEFILE | sort | uniq ))
all_nodes=$(echo ${all_nodes[@]}  | sed 's/ /.cluster,/g')
echo all_nodes: $all_nodes

# replace the node_list element from gnss_data.cfg
sed -i '/node_list/c\node_list='$all_nodes'.cluster' gnss_data.cfg

echo " >> Running pre-job tasks on $headnode with workers ${nodes[@]}"

# The number of CPUs after the -c option of dispynode.py has to equal the amount of CPUs available on each node.

for node in ${nodes[*]}
do
	# get the number of CPUs
	#cpus=`grep ${node} $SLURM_NODEFILE | wc -l`
	cpus=$SLURM_CPUS_PER_TASK

	# create directories and copy programs
        srun -c 1 -w ${node} mkdir -p ${SCRATCH_DIR}/${node}

        # copy PPP program, I have no idea where this comes from
        srun -c 1 -w ${node} cp -r $PPP_SCRIPT_DIR ${SCRATCH_DIR}/${node}

	# this version of python and the dispy script are in a container, no need for full path
        echo "#!/usr/bin/bash" > $PROJECT_DIR/${node}.cluster
        echo "module load singularity" > $PROJECT_DIR/${node}.cluster
	echo "$dispynode -c $cpus -d --daemon --clean --dest_path_prefix ${SCRATCH_DIR}/${node} > $PROJECT_DIR/dispynode_${node}.log 2>&1 &" >> ${PROJECT_DIR}/${node}.cluster
	echo "wait" >> ${PROJECT_DIR}/${node}.cluster
	chmod +x ${PROJECT_DIR}/${node}.cluster
	# pbsdsh -E : passes all environmental vars to the process
        srun -c $cpus --export=ALL -w ${node} ${PROJECT_DIR}/${node}.cluster & # Start dispynode on the workers.
done

# now repeat for the headnode
mkdir -p ${SCRATCH_DIR}/$(hostname)
cp -r $PPP_SCRIPT_DIR ${SCRATCH_DIR}/${headnode}

# start on the head node
cpus=$SLURM_CPUS_PER_TASK

# this version of python and the dispy script are in a container, no need for full path
$dispynode -c $cpus -d --clean --daemon --dest_path_prefix ${SCRATCH_DIR}/$(hostname) > $PROJECT_DIR/dispynode_${headnode}.log 2>&1 &

sleep 6 # Wait for the worker nodes to finish setting up.

# Not sure what this was for?
# export PATH=$SCRATCH_DIR/PPP_NRCAN_${PPP_VER}/source:$PATH

# I guess this pushes it from the cluster to an external storage of some kind?
#python $command # Run the archive script.

# delete the temporary scripts, test this before uncommenting
#rm ${PROJECT_DIR}/*.cluster
#rm ${PROJECT_DIR}/dispynode_*.log


