# PGAMIT on bigblue
## Introduction
This is a container to use pgamit on the university of memphis bigblue cluster. This assumes you have the information for the PPP script, gamit data, and any other supporting files. If you need additional python modules or ubuntu libraries/applications, you can add them to the `%post` portion. Files can also be copied into the container, but you will need to add a `%files` part to the container and make sure the location is available during the build process. 

## Build
Run:
```
cd /project/$USER/
git clone https://github.com/uofm-research-computing/bigblue-pgamit.git
module load singularity
./build.sh
```
This will create a bin directory with pgamit.sif container image and a perl script. 

## Setup
Copy the pgamit.sh script to your work directory, preferably in a `/project/$USER` directory. Modify the script in your work directory for resources like CPUs and nodes and memory (the #SBATCH lines), your configuration and datafiles, and the actual pgamit scripts (PPP_NRCAN?).

## Submission
Once you have built the container and setup the submission script in your working directory, simply run:
```
sbatch pgamit.sh
```
Check the job status with `squeue -u $USER` or `sacct -u $USER`. Check the slurm-#####.out file for any errors or progress.

## Standalone usage of the container
Singularity/apptainer has a few commands available to use the container. First is the `run` command:
```
singularity run --bind /mmfs1/project:/project --bind /mmfs1/scratch:/scratch --cleanenv bin/pgamit.sif
```
which will run the `%runscript` portion of the pgamit.def file. In this case, it will simply print the date.
Second is the `shell` command:
```
singularity shell --bind /mmfs1/project:/project --bind /mmfs1/scratch:/scratch --cleanenv bin/pgamit.sif
```
which will allow you to explore the container.
Notes about exploring the container:
- Your `/home/$USER` directory is mounted in the container. Be careful about deleting things there.
- With the `--bind` options, your `/project/$USER` and `/scratch/$USER` directories are mounted as well, so be careful about deleting things in those directories.
- All other directories in the container are read-only. You would have to rebuild the container to add modules or libraries. Feel free to add `apt-get` or `pip3` installation lines in the `%post` section. Pgamit source is in `/opt/pgamit`, but the scripts, like dispynode.py, are in the root `/usr/bin` of the container.

Third, the `exec` command will run anything in the containers `$PATH`:
```
singularity exec --bind /mmfs1/project:/project --bind /mmfs1/scratch:/scratch --cleanenv bin/pgamit.sif dispynode.py -h 
```
which will display dispynode.py's help information.

Fourth, the `build` command to create the container:
```
cd bin
singularity build --fakeroot pgamit.sif ../pgamit.def
```
which will create the sif container file for singularity/apptainer. The `--fakeroot` command is required here to build the container on bigblue. If you modify the pgamit.def definition file, you will need to rebuild the sif image file.

## Networking
While singularity/apptainer has some built in networking support, on bigblue, this isn't necessary. Your job can talk to other daemons started on other nodes assuming it doesn't try to use certain "restricted" ports. 

To access pages presented by your job, you can use chrome/firefox on x2go, and simply use the node's url and port (like `http://ac01:8888`) to pull up any page your container exposes. Keep in mind that anyone on the cluster could be using the same ports (usually your job will exit with something like "cannot listen on port") or might interact with your job through that interface. If you need security, you will want to use a token (like jupyter notebook) or simply make sure the page cannot modify your job. Unfortunately, we cannot give anymore guidance on this part because many projects have different methods of securing their respective pages, if at all.

## Citations and other reading material
[Singularity 3.7 user guid](https://docs.sylabs.io/guides/3.7/user-guide/)

[Parallel GAMIT](https://github.com/demiangomez/Parallel.GAMIT)

[ubuntu 20.04 docker image](https://hub.docker.com/_/ubuntu?tab=description&page=1&name=20.04)

[SLURM quickstart](https://slurm.schedmd.com/quickstart.html)
