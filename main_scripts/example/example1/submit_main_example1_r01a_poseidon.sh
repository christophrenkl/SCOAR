#!/bin/bash
#SBATCH -J r01a
#SBATCH -t 12:00:00
#SBATCH -o accounting/slurm-%j.out
#SBATCH --ntasks=288
#SBATCH -A s2634
##SBATCH --qos=high
##SBATCH --mail-user=user@nasa.gov

export Couple_Run_Dir=$PROJECT/hseo4/SCOAR/Run/natl/natl1/r01
read LastNHour < $Couple_Run_Dir/restart_info
export RESTART=no

yyyye=2016
mme=04
dde=02
hhe=00

./natl1_r01_restart.sh $yyyye:$mme:$dde:$hhe $RESTART $LastNHour >& r01_log_$$_$yyyye$mme$dde$hhe
