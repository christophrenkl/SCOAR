#!/bin/sh
set -ax
cd $Couple_Run_Dir || exit 8

YYYYS=$YYYYS
MMS=$MMS
DDS=$DDS
HHS=$HHS

if [ $RESTART = no ]; then
YYYYi=$YYYYS
MMi=$MMS
DDi=$DDS
HHi=$HHS
NDay=1

	NHour=$CF

# NUMBER OF DAYS
$Couple_Lib_utils_Dir/inchour $YYYYS $MMS $DDS $HHS $YYYYE $MME $DDE $HHE > inchour$$ || exit 8
read FHOUR < inchour$$ ; rm inchour$$
NUMDAY=`expr $FHOUR \/ 24 `
echo "Number of Days From Starting Date To Ending Date: $NUMDAY"

elif [ $RESTART = yes ]; then
	if [ $((LastNHour % 24)) != 0 ]; then
      RestartNDay=$((LastNHour / 24 + 1))
	else
	  RestartNDay=$((LastNHour / 24))
	fi
RestartNHour=$LastNHour
RestartNHour2=`expr $LastNHour - $CF`
# RESTARTING DATE
$Couple_Lib_utils_Dir/incdte $YYYYS $MMS $DDS $HHS $RestartNHour2> incdte$$ || exit 8
read YYYYSr MMSr DDSr HHSr < incdte$$ ; rm incdte$$
echo $YYYYSr $MMSr $DDSr $HHSr

 NDay=$RestartNDay
 NHour=$RestartNHour
 YYYYi=$YYYYSr
 MMi=$MMSr
 DDi=$DDSr
 HHi=$HHSr
echo "****"
echo "Restarting from $YYYYi $MMi $DDi $HHi"
echo "NHour: $NHour NDay:$NDay "
echo "****"
fi #RESTART

# TOTAL NUMBER OF HOURS OF INTEGRATION
$Couple_Lib_utils_Dir/inchour $YYYYS $MMS $DDS $HHS $YYYYE $MME $DDE $HHE > inchour$$ || exit 8
read EndHOUR < inchour$$ ; rm inchour$$
echo "EndHOUR = $EndHOUR"

# TOTAL NUMBER OF DAYS OF INTEGRATION
EndDAY=`expr $EndHOUR \/ 24`
echo "Total EndDay = $EndDAY"

# write the options used
$Couple_Shell_Dir_common/write_options.sh >  $Couple_Run_Dir/options_check_NHour$NHour

# Starting Loop
NLOOP=1
if [ $RESTART = yes ]; then
	NLOOP=`expr $LastNHour \/ $CF`
fi

while [ $NHour -le $EndHOUR ] ; do
NHourm=$(($NHour - $CF))

$Couple_Lib_utils_Dir/incdte $YYYYi $MMi $DDi $HHi $CF > dteout$$ || exit 8
#n : 1 $CF later than
read YYYYin MMin DDin HHin < dteout$$; rm dteout$$

$Couple_Lib_utils_Dir/incdte $YYYYi $MMi $DDi $HHi -$CF > dteout$$ || exit 8
#n : 1 $CF earlier than
read YYYYim MMim DDim HHim < dteout$$; rm dteout$$

# determine MHour
# MHour is r_pgb.ft$MHour
if [ $YYYYi -eq $YYYYS ]; then
# if current year is the same as the initial year
# MHour is identical to NHour
 MHour=$NHour
elif [ $YYYYi -gt $YYYYS ]; then
# if the current year is greater than the inital year
# calculate number of hours from inital date to
# Jan 1st 0h of the current year
# and substract that from NHour
 ENDHOUR=`$Couple_Lib_utils_Dir/inchour $YYYYS $MMS $DDS $HHS $YYYYi 01 01 00`
 MHour=`expr $NHour - $ENDHOUR`
fi
 echo "MHour =  $MHour"

## write the options used
#$Couple_Shell_Dir_common/write_options.sh >  $Couple_Run_Dir/options_$YYYYin\_$MMin\_$DDin\_$HHin\_NHour_$NHour

## 0. Modify wrfinput_d01
# metgrid.exe is for horizontal interpolation.
# real.exe is for the vertical interpolation
# here i decide to modify wrfinput_d01 which is after the vertical interpolation..
# ideally i need to change psfc as well, but ... aug/11/2011

rm $Couple_Run_Dir/restart_info 2>/dev/null
echo $NHour >& $Couple_Run_Dir/restart_info

# prepare wrfinput wrfbdy wrflowinp
if [ $NLOOP -eq 1 ]; then
	if [ ! -s $Model_WRF_Dir ]; then
	echo " WRF working driectory is being copied"
		cp -Lr $Couple_WRF_Dir/test/em_real $Model_WRF_Dir
	fi
	echo "Prepared the wrfinput wrfbdy wrflowinp..."
	# link initial and bdy files (since these are not changed during the integration)
	ln -fs $WRF_Input_Data/$wrfinput_file_d01 $Model_WRF_Dir/wrfinput_d01 || exit 8
	if [ $WRF_FDDA_d01 = yes ] ; then
	ln -fs $WRF_Input_Data/$wrffdda_file_d01 $Model_WRF_Dir/wrffdda_d01 || exit 8
	fi
		if [ $WRF_Domain -eq 2 ]; then
		ln -fs $WRF_Input_Data/$wrfinput_file_d02 $Model_WRF_Dir/wrfinput_d02 || exit 8
			if [ $WRF_FDDA_d02 = yes ] ; then
		ln -fs $WRF_Input_Data/$wrffdda_file_d02 $Model_WRF_Dir/wrffdda_d02 || exit 8
			fi
		fi
	ln -fs $WRF_Input_Data/$wrfbdy_file_d01 $Model_WRF_Dir/wrfbdy_d01 || exit 8

	# cp lowinp as this will be modified during the integratoin..
     if [ $already_copied_wrflowinp != yes ]; then
        # wrflow is copied for nascar2 case
        cp $WRF_Input_Data/$wrflowinp_file_d01 $Model_WRF_Dir/wrflowinp_d01 || exit 8
 	if [ $WRF_Domain -eq 2 ]; then
    	cp $WRF_Input_Data/$wrflowinp_file_d02 $Model_WRF_Dir/wrflowinp_d02 || exit 8
 	fi
     fi
	if [ $wind_turbine = yes ]; then
        	cp $Couple_Lib_exec_WRF_Dir/windturbines.txt $Model_WRF_Dir
	        cp $Couple_Lib_exec_WRF_Dir/wind-turbine-*.tbl $Model_WRF_Dir
	fi

	#echo "Modify SST in lowinp at intial time NLOOP=1"
 	#$Couple_Run_Dir/edit_sst_wrfinput.sh $Model_WRF_Dir/$wrfinput_file_d01 || exit 8
fi

$Couple_Lib_utils_Dir/incdte $YYYYi $MMi $DDi $HHi $CF > dteout$$ || exit 8
read YYYYin MMin DDin HHin < dteout$$ ; rm dteout$$

# code time breakdown
echo "" >> $Couple_Run_Dir/code_time
echo "NHour=$NHour" >> $Couple_Run_Dir/code_time

time_start0=$(date "+%s")
# ***************************************
## 1.1 ROMS2WRF yes/no
if [ $parameter_ROMS2WRF = yes ]; then
echo "ROMS2WRF: NHour=$NHour, NLOOP=$NLOOP, $YYYYi:$MMi:$DDi:$HHi"

time_start=$(date "+%s")
$Couple_Run_Dir/ROMS2WRF.sh $NHour $YYYYi:$MMi:$DDi:$HHi $YYYYin:$MMin:$DDin:$HHin $CF $NLOOP $NHourm || exit 8
time_end=$(date "+%s")
echo "ROMS2WRF = $((time_end-time_start))s" >> $Couple_Run_Dir/code_time

else
echo " skipping ROMS2WRF"
fi

# ***************************************
# 1.2 WW32WRF yes/no
# write output time at the end of the fcst hour: YYYYin
if [ $parameter_WW32WRF = yes ]; then
# do this only when
if [ $NLOOP -gt 1 -o $WW3_spinup = yes ]; then
echo "WW32WRF: NHour=$NHour, NLOOP=$NLOOP, $YYYYi:$MMi:$DDi:$HHi ~ $YYYYin:$MMin:$DDin:$HHin"

time_start=$(date "+%s")
	$Couple_Run_Dir/WW32WRF.sh $NHour $NHourm $CF $NLOOP $YYYYin:$MMin:$DDin:$HHin  || exit 8

time_end=$(date "+%s")
echo "WW32WRF = $((time_end-time_start))s" >> $Couple_Run_Dir/code_time

else
	echo " skipping WW32WRF"
fi
else            
	echo " skipping WW32WRF"
fi                      

# ***************************************
## 2. WRF Run yes/no
                mkdir -p $WRF_Output_Dir/d01
                mkdir -p $WRF_Output_Dir/d02
	if [ $WRF_PRS = yes ]; then
                mkdir -p $WRF_PRS_Dir/d01
                mkdir -p $WRF_PRS_Dir/d02
	fi
  	if [ $WRF_AFWA = yes ]; then
                mkdir -p $WRF_AFWA_Dir/d01
                mkdir -p $WRF_AFWA_Dir/d02
        fi
   	if [ $WRF_TS = yes ]; then
                mkdir -p $WRF_TS_Dir/d01
                mkdir -p $WRF_TS_Dir/d02
        fi
                wrfrst_subdir_write=$YYYYin-$MMin-$DDin\_$HHin
                wrfrst_subdir_read=$YYYYi-$MMi-$DDi\_$HHi
		mkdir -p $WRF_RST_Dir/$wrfrst_subdir_write/d01
		mkdir -p $WRF_RST_Dir/$wrfrst_subdir_write/d02
                mkdir -p $WRF_RST_Dir/$wrfrst_subdir_read/d01
                mkdir -p $WRF_RST_Dir/$wrfrst_subdir_read/d02
 if [ $parameter_RunWRF = yes ]; then
time_start=$(date "+%s")

time_start1=$(date "+%s")
    	#rm $Model_WRF_Dir/wrfrst_d0?_*_00_00_???? 2>/dev/null
    	rm $Model_WRF_Dir/wrfrst_d0?_*_00_00* 2>/dev/null
	if [ $NLOOP -eq 1 ] ; then
		WRF_RESTART=.false.
		write_hist_at_0h_rst=.false.
	        if [ $restart_from_coupled_spinup = yes ]; then
       	  	echo "Restart from coupled spin-up: wrfrst file is linked"
 		WRF_RESTART=.true.
		write_hist_at_0h_rst=.true.
	# this has to be changed eventually; for now (july 10, 2017), the first restart is used from earlir run with io_form_restart=2
         	ln -fs $WRF_RST_coupled_spinup/d01/wrfrst_d01_$YYYYi-$MMi-$DDi\_$HHi\_00\_00* $Model_WRF_Dir || exit 8
      			if [ $WRF_Domain -eq 2 ]; then
         		ln -fs $WRF_RST_coupled_spinup/d02/wrfrst_d02_$YYYYi-$MMi-$DDi\_$HHi\_00\_00* $Model_WRF_Dir || exit 8
               		fi
 		else
 		WRF_RESTART=.false.
		write_hist_at_0h_rst=.false.
 		fi

	#copy this if defined
        if [ $iofields_filename = yes ]; then
        cp $Couple_Lib_exec_WRF_Dir/my_file_d0?.txt $Model_WRF_Dir || exit 8
        fi
	if [ $WRF_TS = yes ]; then
        cp $Couple_Lib_exec_WRF_Dir/tslist $Model_WRF_Dir || exit 8
        fi

	else
	WRF_RESTART=.true.
#	write_hist_at_0h_rst=.true.
#	this is set to false; WRF produces output only at the end of the forecast and this is used for WRF2ROMS.sh : 2/5/2021
	write_hist_at_0h_rst=.false.
        ln -fs $WRF_RST_Dir/$wrfrst_subdir_read/d01/wrfrst_d01_$YYYYi-$MMi-$DDi\_$HHi\_00\_00* $Model_WRF_Dir || exit 8
                if [ $WRF_Domain -eq 2 ]; then
                ln -fs $WRF_RST_Dir/$wrfrst_subdir_read/d02/wrfrst_d02_$YYYYi-$MMi-$DDi\_$HHi\_00\_00* $Model_WRF_Dir || exit 8
                fi
	fi #NLOOP

	echo "WRF_RESTART =" $WRF_RESTART
	if [ $WRFRST_MULTI = yes ]; then
		io_form_restart=102
	else
		io_form_restart=2
	fi
#CS modification to add the end date which is needed for the nestted case
	$Couple_Run_Dir/edit_WRF_namelist.sh $YYYYi:$MMi:$DDi:$HHi $WRF_RESTART $write_hist_at_0h_rst $io_form_restart $YYYYin:$MMin:$DDin:$HHin

time_end1=$(date "+%s")
echo "WRF prep = $((time_end1-time_start1))s" >> $Couple_Run_Dir/code_time

	
 	echo " *****************  Run WRF *********************"
        echo "Run WRF (NHour:$NHour $YYYYi:$MMi:$DDi:$HHi ~ $YYYYin:$MMin:$DDin:$HHin)"

time_start1=$(date "+%s")
	$Couple_Data_WRF_Dir/$WRF_Launch_Filename $YYYYi:$MMi:$DDi:$HHi || exit 8
time_end1=$(date "+%s")
echo "WRF run = $((time_end1-time_start1))s" >> $Couple_Run_Dir/code_time

time_start1=$(date "+%s")

#	organize the outputs
# wrfout
	mkdir -p $WRF_Output_Dir/d01/$YYYYin
	mv $Model_WRF_Dir/wrfout_d01_$YYYYin-$MMin-$DDin\_$HHin\_00\_00 $WRF_Output_Dir/d01/$YYYYin || exit 8
 		if [ $WRF_Domain -eq 2 ]; then
                        mkdir -p $WRF_Output_Dir/d02/$YYYYin
                        mv $Model_WRF_Dir/wrfout_d02_$YYYYin-$MMin-$DDin\_$HHin\_00\_00 $WRF_Output_Dir/d02/$YYYYin || exit 8
                fi

	        if [ $NLOOP  -eq 1 ]; then
                # first time, move the initial WRFOUT as well
        	mv $Model_WRF_Dir/wrfout_d01_$YYYYi-$MMi-$DDi\_$HHi\_00\_00 $WRF_Output_Dir/d01/$YYYYin || exit 8
		        if [ $WRF_Domain -eq 2 ]; then
                        mv $Model_WRF_Dir/wrfout_d02_$YYYYi-$MMi-$DDi\_$HHi\_00\_00 $WRF_Output_Dir/d02/$YYYYin || exit 8
                        fi
                fi

# wrfrst
	mkdir -p $WRF_RST_Dir/$wrfrst_subdir_write/d01
	mv $Model_WRF_Dir/wrfrst_d01_$YYYYin-$MMin-$DDin\_$HHin\_00\_00* $WRF_RST_Dir/$wrfrst_subdir_write/d01 || exit 8
		if [ $WRF_Domain -eq 2 ]; then
                mkdir -p $WRF_RST_Dir/$wrfrst_subdir_write/d02
                mv $Model_WRF_Dir/wrfrst_d02_$YYYYin-$MMin-$DDin\_$HHin\_00\_00* $WRF_RST_Dir/$wrfrst_subdir_write/d02 || exit 8
                fi

# wrfprs
	if [ $WRF_PRS = yes ]; then
	mkdir -p $WRF_PRS_Dir/d01/$YYYYin
	mv $Model_WRF_Dir/wrfprs_d01_$YYYYin-$MMin-$DDin\_$HHin\_00\_00 $WRF_PRS_Dir/d01/$YYYYin || exit 8
		if [ $WRF_Domain -eq 2 ]; then
                        mkdir -p $WRF_PRS_Dir/d02/$YYYYin
                        mv $Model_WRF_Dir/wrfprs_d02_$YYYYin-$MMin-$DDin\_$HHin\_00\_00 $WRF_PRS_Dir/d02/$YYYYin || exit 8
                fi

	      if [ $NLOOP  -eq 1 ]; then
              # first time, move the initial WRFPRS as well
	      mv $Model_WRF_Dir/wrfprs_d01_$YYYYi-$MMi-$DDi\_$HHi\_00\_00 $WRF_PRS_Dir/d01/$YYYYin || exit 8
			 if [ $WRF_Domain -eq 2 ]; then
                         mv $Model_WRF_Dir/wrfprs_d02_$YYYYi-$MMi-$DDi\_$HHi\_00\_00 $WRF_PRS_Dir/d02/$YYYYin || exit 8
                         fi
              else
      	      rm $Model_WRF_Dir/wrfprs_d01_$YYYYi-$MMi-$DDi\_$HHi\_00\_00 || exit 8
                        if [ $WRF_Domain -eq 2 ]; then
                        rm $Model_WRF_Dir/wrfprs_d02_$YYYYi-$MMi-$DDi\_$HHi\_00\_00 || exit 8
                        fi
              fi
	fi

# wrfzlev
        if [ $WRF_ZLEV = yes ]; then
        mkdir -p $WRF_ZLEV_Dir/d01/$YYYYin
        mv $Model_WRF_Dir/wrfzlev_d01_$YYYYin-$MMin-$DDin\_$HHin\_00\_00 $WRF_ZLEV_Dir/d01/$YYYYin || exit 8
                if [ $WRF_Domain -eq 2 ]; then
                        mkdir -p $WRF_ZLEV_Dir/d02/$YYYYin
                        mv $Model_WRF_Dir/wrfzlev_d02_$YYYYin-$MMin-$DDin\_$HHin\_00\_00 $WRF_ZLEV_Dir/d02/$YYYYin || exit 8
                fi
              if [ $NLOOP  -eq 1 ]; then
              # first time, move the initial file as well
              mv $Model_WRF_Dir/wrfzlev_d01_$YYYYi-$MMi-$DDi\_$HHi\_00\_00 $WRF_ZLEV_Dir/d01/$YYYYin || exit 8
                if [ $WRF_Domain -eq 2 ]; then
                        mv $Model_WRF_Dir/wrfzlev_d02_$YYYYi-$MMi-$DDi\_$HHi\_00\_00 $WRF_ZLEV_Dir/d02/$YYYYin || exit 8
                fi
              else
              rm $Model_WRF_Dir/wrfzlev_d01_$YYYYi-$MMi-$DDi\_$HHi\_00\_00 || exit 8
                if [ $WRF_Domain -eq 2 ]; then
                        rm $Model_WRF_Dir/wrfzlev_d02_$YYYYi-$MMi-$DDi\_$HHi\_00\_00 || exit 8
                fi
              fi
        fi

# wrfafwa
	if [ $WRF_AFWA = yes ]; then 
	mkdir -p $WRF_AFWA_Dir/d01/$YYYYin
	# AFWA writes only beginning of fcst...
	mv $Model_WRF_Dir/wrfafwa_d01_$YYYYi-$MMi-$DDi\_$HHi\_00\_00 $WRF_AFWA_Dir/d01/$YYYYin || exit 8
		if [ $WRF_Domain -eq 2 ]; then
		mkdir -p $WRF_AFWA_Dir/d02/$YYYYin
		mv $Model_WRF_Dir/wrfafwa_d02_$YYYYi-$MMi-$DDi\_$HHi\_00\_00 $WRF_AFWA_Dir/d02/$YYYYin || exit 8
		fi
	fi
# wrfts
	if [ $WRF_TS = yes ]; then
	# Find out the number of stations (locations)
        ls $Model_WRF_Dir/*.d01.TS  | wc -l > out$$
        read num_station < out$$; rm out$$
        echo $num_station
        # for each location
	ns=1
        while [ $ns -le $num_station ]; do
		# for each field
        	for FLD in UU VV WW TH QV PR PH
        	do
	        ls $Model_WRF_Dir/*.d01.$FLD | awk '{print $1}' | awk "NR==$ns{print$1}"  | sed -n 's/^\(.*\/\)*\(.*\)/\2/p' > out$$
        	read TS_FNAME < out$$ ; rm out$$
		echo "*** $TS_FNAME ***"
		if [ ! -s $Model_WRF_Dir/$TS_FNAME ]; then
		echo "the file doesn not exist: $Model_WRF_Dir/$TS_FNAME"
		exit 8
		fi
		mkdir -p $WRF_TS_Dir/d01/$FLD/$YYYYin
        	cp $Model_WRF_Dir/$TS_FNAME  $WRF_TS_Dir/d01/$FLD/$YYYYin/$TS_FNAME\_$YYYYi-$MMi-$DDi\_$HHi\_00\_00 || exit 8
        	done #FLD

                if [ $WRF_Domain -eq 2 ]; then
                # for each field: d02
                for FLD in UU VV WW TH QV PR PH
                do
                ls $Model_WRF_Dir/*.d02.$FLD | awk '{print $1}' | awk "NR==$ns{print$1}"  | sed -n 's/^\(.*\/\)*\(.*\)/\2/p' > out$$
                read TS_FNAME < out$$ ; rm out$$
                echo "*** $TS_FNAME ***"
                if [ ! -s $Model_WRF_Dir/$TS_FNAME ]; then
                echo "the file doesn not exist: $Model_WRF_Dir/$TS_FNAME"
                exit 8
                fi
                mkdir -p $WRF_TS_Dir/d02/$FLD/$YYYYin
                cp $Model_WRF_Dir/$TS_FNAME  $WRF_TS_Dir/d02/$FLD/$YYYYin/$TS_FNAME\_$YYYYi-$MMi-$DDi\_$HHi\_00\_00 || exit 8
                done #FLD
                fi
	ns=`expr $ns + 1`
	done
        fi #WRF_TS

	# remove WRF_RST files (They are too big) keep the last four files
        p1=`expr $CF \* $WRFRST_SAVE_NUMBER \* -1 `
        $Couple_Lib_utils_Dir/incdte $YYYYin $MMin $DDin $HHin $p1 > dteout$$ || exit 8
        read YYYYp MMp DDp HHp < dteout$$; rm dteout$$
	wrfrst_subdir_delete=$YYYYp-$MMp-$DDp\_$HHp

	# delete wrfrst file prior to 120 hrs or older EXCEPt when HH==0 (top of the hour , please save it)
	if [ $HHp -ne 00 ]; then
        rm -rf $WRF_RST_Dir/$wrfrst_subdir_delete
	else
	echo "keeping WRFRST at $wrfrst_subdir_delete"
	fi
 	echo "End Run WRF"
time_end1=$(date "+%s")
echo "WRF cleanup = $((time_end1-time_start1))s" >> $Couple_Run_Dir/code_time

time_end=$(date "+%s")
echo "total WRF = $((time_end-time_start))s" >> $Couple_Run_Dir/code_time

else # parameter_RunWRF=yes
 echo "skipping WRF Run"
fi # parameter_RunWRF=o

# WRF --> ROMS
echo "Creating Forcing from WRF To ROMS at NDay=$NDay NHour=$NHour NLOOP=$NLOOP"
JD=`$Couple_Lib_utils_Dir/jd $YYYYi $MMi $DDi` || exit 8
## WRF2ROMS: yes/no
if [ $parameter_WRF2ROMS = yes ]; then
echo  "****************** WRF2ROMS **************"
	#$Couple_Run_Dir/WRF2ROMS.sh $NHour $MHour $JD $YYYYi:$MMi:$DDi:$HHi || exit 8
	# use the WRF output at the end of the forecast (YYYYin, not YYYYi) 2/5/2021

time_start=$(date "+%s")
	$Couple_Run_Dir/WRF2ROMS.sh $NHour $MHour $JD $YYYYin:$MMin:$DDin:$HHin || exit 8
time_end=$(date "+%s")
echo "WRF2ROMS = $((time_end-time_start))s" >> $Couple_Run_Dir/code_time

echo  "****************** WRF2ROMS **************"
elif [ $WRF2ROMS_WRFONLY =  yes ]; then
        #$Couple_Run_Dir/WRF2ROMS_WRFONLY.sh $NHour $MHour $JD $YYYYi:$MMi:$DDi:$HHi || exit 8
        $Couple_Run_Dir/WRF2ROMS_WRFONLY.sh $NHour $MHour $JD $YYYYin:$MMin:$DDin:$HHin || exit 8
fi

# WW32ROMS
if [ $parameter_WW32ROMS = yes ]; then
echo  "****************** WW32ROMS **************"
#read FOC (+HS, LM etc.) and write to ROMS forcing file
echo "WW32ROMS: NHour=$NHour, NLOOP=$NLOOP, $YYYYi:$MMi:$DDi:$HHi ~ $YYYYin:$MMin:$DDin:$HHin"

time_start=$(date "+%s")
	$Couple_Run_Dir/WW32ROMS.sh $NHour $NHourm $CF $NLOOP $YYYYin:$MMin:$DDin:$HHin  || exit 8
time_end=$(date "+%s")
echo "WW32ROMS = $((time_end-time_start))s" >> $Couple_Run_Dir/code_time
echo  "****************** WW32ROMS **************"
fi

## Run ROMS yes/no
if [ $parameter_RunROMS = yes ]; then

# link forc_Day to ocean_frc
mkdir -p  $ROMS_Frc_Dir/$YYYYin  || exit 8
        #rm $Couple_Data_ROMS_Dir/ocean_frc.nc >/dev/null
        ln -fs $ROMS_Frc_Dir/$YYYYin/frc_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.nc $Couple_Data_ROMS_Dir/ocean_frc.nc || exit 8

cd $Couple_Data_ROMS_Dir || exit 8

# prepare ROMS run (init, bry, clm files)
echo "*********   prepare-ROMS **************"
echo "preparing ROMS Runs.. $gridname"
        #$Couple_Run_Dir/prepareROMS.sh $ROMS_BCFile $JD $NHour $YYYYin:$MMin:$DDin $NLOOP || exit 8
# 2020/04/16 add HHin
        $Couple_Run_Dir/prepareROMS.sh $ROMS_BCFile $JD $NHour $YYYYin:$MMin:$DDin:$HHin $NLOOP || exit 8
echo "*********   prepare-ROMS **************"

if [ $CPL_PHYS = romsbulk  ]; then
# calculate ua-uo and input to forcing in ROMS bulk formula
if [ $UaUo = yes ]; then
echo "Ua - Uo: 10 m wind speed relateve to current"
$Couple_Shell_Dir_common/uauo.sh $NHour || exit 8
else
echo "ocean sfc is motionless."
fi
fi


time_start=$(date "+%s")
echo "Run ROMS (NDay=$NDay NHour=$NHour NLOOP=$NLOOP: $YYYYi:$MMi:$DDi:$HHi ~ $YYYYin:$MMin:$DDin:$HHin)"
echo "****************  Run ROMS ****************"
	$Couple_Data_ROMS_Dir/$ROMS_Launch_Filename > $ROMS_Runlog_Dir/ROMS_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.log || exit 8
	grep Blowing $ROMS_Runlog_Dir/ROMS_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.log 
	if [ $? -eq 0 ]; then
        echo "ERROR: ROMS BLOW UP!!!!!!!!!"
        exit 8
fi
echo "****************  Run ROMS ****************"

# dia
if [ $ROMS_Dia = yes ]; then
	mkdir -p $ROMS_Dia_Dir/$YYYYin
	mv $Couple_Data_ROMS_Dir/ocean_dia.nc $ROMS_Dia_Dir/$YYYYin/dia_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.nc || exit 8
fi

# deTide
#harmonics, we may not need to actually save this file every coupling frequency..?
#right now just keeping the last version in the Avg directory 
if [ $ROMS_DeT = yes ]; then
#	mkdir -p $ROMS_DeT_Dir/$YYYYin
	cp $Couple_Data_ROMS_Dir/ocean_har.nc $ROMS_Avg_Dir/$YYYYin/ocean_har.nc || exit 8
#fi


# avg
# if detide (ROMS_DeT=yes) is activated then detited fields are saved in the average file
if [ $ROMS_Avg = yes ]; then
	mkdir -p $ROMS_Avg_Dir/$YYYYin
	mv $Couple_Data_ROMS_Dir/ocean_avg.nc $ROMS_Avg_Dir/$YYYYin/avg_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.nc || exit 8
fi

# rst
	mkdir -p $ROMS_Rst_Dir/$YYYYin
        mv $Couple_Data_ROMS_Dir/ocean_rst.nc $ROMS_Rst_Dir/$YYYYin/rst_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.nc || exit 8

# his
if [ $ROMS_His = yes ]; then
	mkdir -p $ROMS_His_Dir/$YYYYin
        mv $Couple_Data_ROMS_Dir/ocean_his.nc $ROMS_His_Dir/$YYYYin/his_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.nc || exit 8
fi
# qck
if [ $ROMS_Qck = yes ]; then
	mkdir -p $ROMS_Qck_Dir/$YYYYin/
        mv $Couple_Data_ROMS_Dir/ocean_qck.nc $ROMS_Qck_Dir/$YYYYin/qck_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.nc || exit 8


	# save initial conditons in qck for very first time step
	if [ $NLOOP -eq 1 ]; then
		$NCO/ncks -F -O -d ocean_time,1 $ROMS_Qck_Dir/$YYYYin/qck_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.nc $ROMS_Qck_Dir/$YYYYin/qck_$YYYYi-$MMi-$DDi\_$HHi\_Hour$NHourm\.nc
		$NCO/ncks -F -O -d ocean_time,2 $ROMS_Qck_Dir/$YYYYin/qck_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.nc $ROMS_Qck_Dir/$YYYYin/qck_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.nc

	else 
		# added: July 2, 2017
		# if use Qck; obtain only the last time step 
		# as is for HIS, it writes the first and last time-step of each segment of integrations
		echo "qck_Hour.nc: use only the last time-step"
		$NCO/ncks -F -O -d ocean_time,2 $ROMS_Qck_Dir/$YYYYin/qck_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.nc $ROMS_Qck_Dir/$YYYYin/qck_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.nc
		###
	fi
fi

time_end=$(date "+%s")
echo "ROMS = $((time_end-time_start))s" >> $Couple_Run_Dir/code_time

        else #parameter_RunROMS
        echo "skipping ROMS Run"
fi #parameter_RunROMS

##################
# March 15, 2021 add WW3 coupling
if [ $parameter_run_WW3 = yes ]; then

time_start=$(date "+%s")

cd $WW3_Exe_Dir

# #1. WRF U10 and V10 for WW3
rm -f fort.* wind.ww3* 2>/dev/null
rm  $WW3_Exe_Dir/ww3_prnc.nml 2>/dev/null

# edit wind nml
ncks -3 -O -v U10,V10,XLONG,XLAT,XTIME,COSALPHA,SINALPHA $WRF_Output_Dir/d0$Coupling_Domain/$YYYYi/wrfout_d0$Coupling_Domain\_$YYYYi-$MMi-$DDi\_$HHi\_00_00 fort.11
ncks -3 -O -v U10,V10,XLONG,XLAT,XTIME,COSALPHA,SINALPHA $WRF_Output_Dir/d0$Coupling_Domain/$YYYYin/wrfout_d0$Coupling_Domain\_$YYYYin-$MMin-$DDin\_$HHin\_00_00 fort.12
## rotate wind vector from grid to earth relative
ncap2 -A -s 'U10=U10*COSALPHA-V10*SINALPHA' fort.11
ncap2 -A -s 'V10=V10*COSALPHA+U10*SINALPHA' fort.11
#
ncap2 -A -s 'U10=U10*COSALPHA-V10*SINALPHA' fort.12
ncap2 -A -s 'V10=V10*COSALPHA+U10*SINALPHA' fort.12
## ##
ncrcat -O fort.11 fort.12 fort.11; 	rm fort.12
ncrename -d west_east,lon -d south_north,lat -d Time,time fort.11
ncrename -v XTIME,time -v XLONG,lon -v XLAT,lat fort.11
ncks -4 -O fort.11 fort.11
ncatted -a _FillValue,U10,c,f,9.999e+20 fort.11
ncatted -a _FillValue,V10,c,f,9.999e+20 fort.11
# this needs work; for both Eastern and Western Hemisphere longitudes
#        ncap2 -O -s 'lon=lon+360' fort.11 fort.11
$WW3_Exe_Dir/edit_ww3_prnc.sh $YYYYi:$MMi:$DDi:$HHi $YYYYin:$MMin:$DDin:$HHin $WW3_Exe_Dir/ww3_prnc_wind.nml
ln -fs ww3_prnc_wind.nml ww3_prnc.nml
$WW3_Exe_Dir/ww3_prnc >& log_prnc_wind_$$
mv wind.ww3 wind.ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour || exit 8
ln -fs wind.ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour wind.ww3

# #2. ROMS u/v sfc current for WW3
if [ $wave_current = yes ];then
	rm -f fort.* current.ww3* 2>/dev/null
	rm  $WW3_Exe_Dir/ww3_prnc.nml 2>/dev/null
	# edit current nml
	if [ $NLOOP -eq 1 ]; then
	# for inital case, jusy duplicate NHour for NHourm
       		ncks -3 -O -v u_sur_eastward,v_sur_northward,lon_rho,lat_rho $ROMS_Qck_Dir/$YYYYin/qck_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.nc fort.11
	else
       		ncks -3 -O -v u_sur_eastward,v_sur_northward,lon_rho,lat_rho $ROMS_Qck_Dir/$YYYYi/qck_$YYYYi-$MMi-$DDi\_$HHi\_Hour$NHourm\.nc fort.11
	fi
        ncks -3 -O -v u_sur_eastward,v_sur_northward,lon_rho,lat_rho $ROMS_Qck_Dir/$YYYYin/qck_$YYYYin-$MMin-$DDin\_$HHin\_Hour$NHour\.nc fort.12
        ncrcat -O fort.11 fort.12 fort.11;      rm fort.12
        ncrename -d xi_rho,lon -d eta_rho,lat fort.11
        ncrename -d ocean_time,time fort.11
        ncrename -v lon_rho,lon -v lat_rho,lat fort.11
        ncrename -v ocean_time,time  fort.11
        ncks -4 -O fort.11 fort.11
	$WW3_Exe_Dir/edit_ww3_prnc.sh $YYYYi:$MMi:$DDi:$HHi $YYYYin:$MMin:$DDin:$HHin $WW3_Exe_Dir/ww3_prnc_current.nml
	ln -fs ww3_prnc_current.nml ww3_prnc.nml
	$WW3_Exe_Dir/ww3_prnc >& log_prnc_current_$$
	mv current.ww3 current.ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour || exit 8
	ln -fs current.ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour current.ww3
fi #wave_current = yes

# #3. update WW3 main namelist; restart/ start/end date 
	$WW3_Exe_Dir/edit_ww3_shel.sh $YYYYi:$MMi:$DDi:$HHi $YYYYin:$MMin:$DDin:$HHin $WW3_Exe_Dir/ww3_shel.nml $CF

# Run WW3
rm -f out_grd.ww3 ww3_*.nc restart.ww3 2>/dev/null
# 1. $WW3_spinup = yes, then provide the WW3_ICfile 
# 2. $WW3_spinup = no,  no initial file is necessary.
if [ $NLOOP -eq 1 ]; then
        if [ $WW3_spinup = yes ]; then
	ln -fs $WW3_ICFile ./restart.ww3 || exit 8
	fi
else
# if NLOOP>1, it is a restart, link restart file from previous time 
	ln -fs $WW3_Rst_Dir/restart.ww3.$YYYYi$MMi$DDi$HHi\_Hour$NHourm ./restart.ww3 || exit 8
fi
# 1. Run WW3 codes
echo "runWW3"
date
	mpirun -np $ww3NCPU $WW3_Exe_Dir/ww3_shel >& log_shel_$$
date
echo "end runWW3"

#2. Convert outputs to netcdf
	$WW3_Exe_Dir/edit_ww3_ounf.sh $YYYYi:$MMi:$DDi:$HHi $YYYYin:$MMin:$DDin:$HHin $WW3_Exe_Dir/ww3_ounf.nml $CF
	$WW3_Exe_Dir/ww3_ounf >& log_ounf_$$
        if [ $wave_spec = yes ];then
        $WW3_Exe_Dir/edit_ww3_ounp.sh $YYYYi:$MMi:$DDi:$HHi $YYYYin:$MMin:$DDin:$HHin $WW3_Exe_Dir/ww3_ounp.nml $CF || exit 8
        $WW3_Exe_Dir/ww3_ounp >& log_ounp_$$ ##points output
        fi

# organize
#Out, binary: No Need to link
# *********
# # maybe we don't want to save out_grd.ww3; we don't use it anywhere..
#mkdir -p $WW3_Out_Dir/$YYYYin
#        mv ./out_grd.ww3 $WW3_Out_Dir/$YYYYin/ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour
# *********

#Out, netcdf: need to link for WW32WRF
mkdir -p $WW3_Outnc_Dir/$YYYYin
	mv ./ww3.$YYYYin$MMin$DDin\T$HHin\Z.nc $WW3_Outnc_Dir/$YYYYin/ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour\.nc
	ln -fs $WW3_Outnc_Dir/$YYYYin/ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour\.nc $WW3_Outnc_Dir/
        if [ $wave_spec = yes ];then
        #wave spectrum file
        mkdir -p $WW3_Spcnc_Dir/$YYYYin
        mv $WW3_Exe_Dir/ww3.$YYYYin$MMin\_spec.nc $WW3_Spcnc_Dir/$YYYYin/ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour\_spec.nc || exit 8
        fi
	if [ $wave_spec_array = yes ];then
        #wave spectrum array file
        mkdir -p $WW3_3dSpcnc_Dir/$YYYYin
        mv $WW3_Exe_Dir/ww3.$YYYYin$MMin$DDin\T$HHin\Z\_ef.nc $WW3_3dSpcnc_Dir/$YYYYin/ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour\_ef.nc || exit 8
        mv $WW3_Exe_Dir/ww3.$YYYYin$MMin$DDin\T$HHin\Z\_th1m.nc $WW3_3dSpcnc_Dir/$YYYYin/ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour\_th1m.nc || exit 8
        mv $WW3_Exe_Dir/ww3.$YYYYin$MMin$DDin\T$HHin\Z\_sth1m.nc $WW3_3dSpcnc_Dir/$YYYYin/ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour\_sth1m.nc || exit 8
        mv $WW3_Exe_Dir/ww3.$YYYYin$MMin$DDin\T$HHin\Z\_th2m.nc $WW3_3dSpcnc_Dir/$YYYYin/ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour\_th2m.nc || exit 8
        mv $WW3_Exe_Dir/ww3.$YYYYin$MMin$DDin\T$HHin\Z\_sth2m.nc $WW3_3dSpcnc_Dir/$YYYYin/ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour\_sth2m.nc || exit 8
        mv $WW3_Exe_Dir/ww3.$YYYYin$MMin$DDin\T$HHin\Z\_wn.nc $WW3_3dSpcnc_Dir/$YYYYin/ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour\_wn.nc || exit 8
        fi


#Rst: binary: Need to link
mkdir -p $WW3_Rst_Dir/$YYYYin
	mv ./restart001.ww3 $WW3_Rst_Dir/$YYYYin/restart.ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour
	ln -fs $WW3_Rst_Dir/$YYYYin/restart.ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour $WW3_Rst_Dir/
#Frc: binary: No need to link
mkdir -p $WW3_Frc_Dir/$YYYYin/wind
mkdir -p $WW3_Frc_Dir/$YYYYin/current
	mv ./wind.ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour $WW3_Frc_Dir/$YYYYin/wind/
	mv ./current.ww3.$YYYYin$MMin$DDin$HHin\_Hour$NHour $WW3_Frc_Dir/$YYYYin/current/
	rm $WW3_Exe_Dir/wind.ww3 2>/dev/null
	rm $WW3_Exe_Dir/current.ww3 2>/dev/null
#Log file
mkdir -p $WW3_Log_Dir/prnc_wind/$YYYYin
mkdir -p $WW3_Log_Dir/prnc_current/$YYYYin
mkdir -p $WW3_Log_Dir/shel/$YYYYin
mkdir -p $WW3_Log_Dir/ounf/$YYYYin
	mv ./log_prnc_wind_$$ $WW3_Log_Dir/prnc_wind/$YYYYin/log_prnc_wind_$YYYYin$MMin$DDin$HHin\_Hour$NHour
        mv ./log_shel_$$ $WW3_Log_Dir/shel/$YYYYin/log_shel_$YYYYin$MMin$DDin$HHin\_Hour$NHour
        mv ./log_ounf_$$ $WW3_Log_Dir/ounf/$YYYYin/log_ounf_$YYYYin$MMin$DDin$HHin\_Hour$NHour

if [ $wave_spec = yes ];then
mkdir -p $WW3_Log_Dir/ounp/$YYYYin
        mv ./log_ounp_$$ $WW3_Log_Dir/ounp/$YYYYin/log_ounp_$YYYYin$MMin$DDin$HHin\_Hour$NHour || exit 8
fi

if [ $wave_current = yes ];then
mkdir -p $WW3_Log_Dir/prnc_current/$YYYYin
	mv ./log_prnc_current_$$ $WW3_Log_Dir/prnc_current/$YYYYin/log_prnc_current_$YYYYin$MMin$DDin$HHin\_Hour$NHour
fi

# clean up
        rm $WW3_Rst_Dir/restart.ww3.??????????\_Hour$NHourm2 2>/dev/null
        rm $WW3_Outnc_Dir/ww3.??????????\_Hour$NHourm2\.nc 2>/dev/null
#  WW3 netcdf file; 
	if [ $NLOOP -eq 1 ]; then 
        mv ./ww3.$YYYYi$MMi$DDi\T$HHi\Z.nc $WW3_Outnc_Dir/$YYYYi/ww3.$YYYYi$MMi$DDi$HHi\_Hour$NHourm\.nc
	else
        rm ./ww3.$YYYYi$MMi$DDi\T$HHi\Z.nc 2>/dev/null
	fi

cd -
time_end=$(date "+%s")
echo "WW3 = $((time_end-time_start))s" >> $Couple_Run_Dir/code_time

else #parameter_run_WW3
	echo "skipping WW3 Run"
fi
###################

echo " *****************************"
echo " COUPLING DONE at Day = $NDay Hour=$NHour NLOOP=$NLOOP"
echo " *****************************"

time_end0=$(date "+%s")
echo "total = $((time_end0-time_start0))s" >> $Couple_Run_Dir/code_time

# 4. Continue WRF Run
YYYYi=$YYYYin
MMi=$MMin
DDi=$DDin
HHi=$HHin

NHour=`expr $NHour + $CF`
	if [ $HHi -eq 0 ]; then
  	NDay=`expr $NDay + 1`
	fi
NLOOP=`expr $NLOOP + 1 `

# cleaning..
rm $Couple_Data_tempo_files_Dir/* 2>/dev/null
rm $Couple_Data_ROMS_Dir/fort.* 2>/dev/null
rm $Couple_Data/fort.* 2>/dev/null

# Cleaning WRF Directory
#rm $Model_WRF_grid_Dir/wrfout_d01_$YYYYi-* 2>/dev/null
#rm $Model_WRF_grid_Dir/wrfsd10_$YYYYi-* 2>/dev/null

# Cleaning ROMS directory
rm $Couple_Data_ROMS_Dir/ocean_bry.nc 2>/dev/null
rm $Couple_Data_ROMS_Dir/ocean_frc.nc 2>/dev/null
# Keep the ocean_ini.nc!

done
# DONE
