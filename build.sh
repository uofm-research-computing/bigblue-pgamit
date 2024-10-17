#!/bin/bash

mkdir -p bin
cd bin
singularity build --fakeroot pgamit.sif ../pgamit.def
wget https://github.com/SchedMD/slurm/raw/refs/heads/master/contribs/torque/generate_pbs_nodefile.pl
chmod 755 generate_pbs_nodefile.pl

