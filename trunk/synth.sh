#!/bin/bash
# Joshua Smith (smjoshua@umich.edu)
# EECS 470 - Fall 2010

# This script is for the purpose of submitting a synthesis job to the cluster.
# The script will copy project files to the home space (if needed), and then
# submit a job to the batch system.

# Usage: ./synth.sh [-s | -a]
# -s: Check out copy of SVN repository specified by SVN_REPO
# -a: Copy files from AFS space specified by AFS_DIR

# If the -s or -a flag is used, then the script will either check out files
# from an SVN repository (located in your AFS space) or just copy files from
# your AFS into WORK_DIR.  Otherwise the script will use the files that
# exist in WORK_DIR.

# Modify these variables with your information
# SVN_REPO: Location of your SVN repository
# AFS_DIR: Location of files in AFS space if not using SVN
# WORK_DIR: The name of the folder in which the files are located locally
# EMAIL: Your e-mail address, the batch system will e-mail updates to you
# ROOT_PROJ_DIR: The root directory of your project (likely *vsimp4*)
# PROJ_TCL: The synthesis .tcl script for your entire pipeline
USER=`whoami`
SVN_REPO="svn checkout http://mountain-dew-proc.googlecode.com/svn/trunk/ mountain-dew-proc-read-only"
AFS_DIR="/afs/umich.edu/user/${USER:0:1}/${USER:1:1}/${USER}/Private/eecs470/"
WORK_DIR="mountain-dew-proc"
EMAIL="${USER}@umich.edu"
ROOT_PROJ_DIR=""
PROJ_TCL="pipeline.tcl"

# Will have to guesstimate on runtime and memory requirements
# WALLTIME: A limit on the amount of time your job will get to run
# MEM: Amount of physical memory that your job will be allocated
PPN=1   # Processors-Per-Node
WALLTIME="05:00:00"   #HH:MM:SS
MEM="4gb"

# Note: Probably shouldn't touch these unless told to by the GSI
# QUEUE: Name of queue to submit batch job to
# PBS_FILE: Shell PBS script which will be executed when job runs
QUEUE="route"
PBS_FILE=`pwd`"/pbs.sh"

# Check out a copy of the SVN repository, or copy from AFS space if needed
cd
if [ "$1" == "-s" ]; then
  echo "Checking out project from SVN repository..."
  svn co $SVN_REPO $HOME/$WORK_DIR
  if [ "$?" -ne '0' ]; then
    echo "Error: Could not check out copy of SVN repository"
    exit 1
  fi
elif [ "$1" == "-a" ]; then
  echo "Copying project from AFS directory..."
  rsync -avz --exclude "*.out" $AFS_DIR/$WORK_DIR/ $HOME/$WORK_DIR
  if [ "$?" -ne '0' ]; then
    echo "Error: Could not copy files from AFS directory"
    exit 1
  fi
else
	echo "Error: invalid or no option given"
	exit 1
fi

# Make sure the synth folder can be found
SYNTH_DIR=`find $HOME/$WORK_DIR -type d -name synth`
if [ "$SYNTH_DIR" == "" ]; then
  echo "Error: Could not find synth directory"
  exit 1
fi

# Export some environment variables so PBS can access them when job runs
# (so that PBS shell script can use them)
export WORK_DIR
export ROOT_PROJ_DIR
export PROJ_TCL

# Need to load these so paths of dc_shell/vcs are found
module load synopsys
module load vcs

# Submit the batch job
echo "Submitting batch job..."
JOB_ID=`qsub -N 470synth -l nodes=1:ppn=${PPN},walltime=$WALLTIME,pmem=$MEM -q $QUEUE -M $EMAIL -m abe -V $PBS_FILE`
if [ "$?" -ne '0' ]; then
  echo "Error: Could not submit job via qsub"
  exit 1
fi
echo "Submitted batch job, id=$JOB_ID"

# clean up stuff
unset WORK_DIR
unset ROOT_PROJ_DIR
unset PROJ_TCL
