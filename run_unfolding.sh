input=$1
inputbg=$2
energy=$3
binning=$4
dir_suffix=$5
hpgenr=$6

detnum=2

energy_dir=${energy}_${hpgenr}_${dir_suffix}

source settings/hpge_${energy}


haskelldir=/home/jisaak/documents/physics_stuff/unfolding_software/haskell/dist/build
varypoisson=${haskelldir}/VaryPoisson/VaryPoisson
smoothgauss=${haskelldir}/Fold_spectrum/Fold_spectrum # ./smooth spec a b c gauss/lorentz ( -> sqrt(a + b*E + c*E*E) )

rebin=/home/jisaak/documents/physics_stuff/unfolding_software/sh/rebin_awk.sh

detresponse=/home/jisaak/documents/physics_stuff/unfolding_software/det_response/hpge2
det_type=09_Germanium_Duke_2

# Get command line parameters
if [ $# -lt 5 ] ; then
echo "Usage: $0 <input-file> <input-file bg> <energy> <binning> <dir-suffix> <hpge-nr>"
exit
fi

# if energy directory does not exist -> create it
if [[ ! -d ${energy_dir} ]]; then
mkdir ${energy_dir}
fi

echo ${lowLimit}
echo ${highLimit}

firstBin=$(echo ${lowLimit} ${binning} | awk -vbin=${binning} '{print bin*int($1/$2)}')
echo ${firstBin}
repeatIt=" "

input_corr=/tmp/inputCorr_${energy}.asc
inputbg_corr=/tmp/inputbgCorr_${energy}.asc
input_diff=/tmp/inputCorrDiff_${energy}.asc
input_corr_smooth=/tmp/inputCorrSmooth_${energy}.asc
inputbg_corr_smooth=/tmp/inputbgCorrSmooth_${energy}.asc

# input_corr=/tmp/inputCorr.asc
# inputbg_corr=/tmp/inputbgCorr.asc
# input_diff=/tmp/inputCorrDiff.asc
# input_corr_smooth=/tmp/inputCorrSmooth.asc
# inputbg_corr_smooth=/tmp/inputbgCorrSmooth.asc

# deadTime=list_of_deadtimes.dat

# tlive=$(awk -venergy=${energy} -vhpgenr=${hpgenr} '$1==energy && $2==hpgenr {print $3}' ${deadTime})
# tlivebg=$(awk -vhpgenr=${hpgenr} '$1=="natbg" && $2==hpgenr {print $3}' ${deadTime})

# scale=$(awk -vtlive=${tlive} -vtlivebg=${tlivebg} 'BEGIN {print tlive/tlivebg}')

awk '{printf"%f %f %f\n", $1, $2, $3}' ${input} > ${input_corr}
awk '{printf"%f %f %f\n", $1, $2, $3}' ${inputbg} > ${inputbg_corr}
# awk -vscale=${scale} '{printf"%f %f %f\n", $1, scale*$2, scale*$3}' ${inputbg} > ${inputbg_corr}

# awk '{printf"%f %f\n", $1, $2}' ${input} > ${input_corr_smooth}
# awk -vscale=${scale} '{printf"%f %f\n", $1, scale*$2}' ${inputbg} > ${inputbg_corr_smooth}


# constant smoothing of 20 keV
# ${smoothgauss} ${input_corr_smooth} 400 0 0 gauss > ${input_corr}
# ${smoothgauss} ${inputbg_corr_smooth} 400 0 0 gauss > ${inputbg_corr}

# # smoothing as function of the beam energy -> 1% of beam energy
# gaussianFWHM=$(echo ${energy} | awk '{printf"%0.0f\n", ($1*0.015)^2}')
# ${smoothgauss} ${input_corr_smooth} ${gaussianFWHM} 0 0 gauss > ${input_corr}
# ${smoothgauss} ${inputbg_corr_smooth} ${gaussianFWHM} 0 0 gauss > ${inputbg_corr}

${rebin} ${binning} ${input_corr}
input_corr_rebin=${input_corr%%.asc}_${binning}keV.asc
cp ${input_corr_rebin} /tmp/tmp_${energy}.spec
awk '{printf"%f %f %f\n", $1, $2, $3}' /tmp/tmp_${energy}.spec > ${input_corr_rebin}

${rebin} ${binning} ${inputbg_corr}
inputbg_corr_rebin=${inputbg_corr%%.asc}_${binning}keV.asc
cp ${inputbg_corr_rebin} /tmp/tmp_${energy}.spec
awk '{printf"%f %f %f\n", $1, $2, $3}' /tmp/tmp_${energy}.spec > ${inputbg_corr_rebin}

tmpOut=/tmp/tmp_Output_${energy}.asc



# loop over different realizations by randomizing the spectra within their  statistical uncertainties
for (( it=0; it<2; it++ ))
do


if [ ${it} -eq 0 ]; then

  paste ${input_corr_rebin} ${inputbg_corr_rebin} | awk '{printf"%f %f %f\n", $1, $2-$5, sqrt($3^2 + $6^2)}' > ${input_diff}

  # option to add additional correction for background above beam, if still existing .. pile-up?
  # offSet=$(awk -venergy=${energy} '$1 > energy*1.045 && $1 < energy*1.1 {print $2}' ${input_diff} | awk '{sum+=$1}END{printf"%4.2f\n", sum/NR}')
  # awk -voffSet=${offSet} '{print $1, $2-offSet, sqrt($3^2 + offSet)}' ${input_diff} > ${tmpOut}
  # cp ${tmpOut} ${input_diff}

else

  ${varypoisson} ${input_corr_rebin} ${it} | awk '{printf"%f %f %f\n", $1, $2, $3}' > ${tmpOut}

  paste ${tmpOut} ${inputbg_corr_rebin} | awk '{printf"%f %f %f\n", $1, $2-$5, sqrt($3^2 + $6^2)}' > ${input_diff}

  # option to add additional correction for background above beam, if still existing .. pile-up?
  # offSet=$(awk -venergy=${energy} '$1 > energy*1.045 && $1 < energy*1.1 {print $2}' ${input_diff} | awk '{sum+=$1}END{printf"%4.2f\n", sum/NR}')
  # awk -voffSet=${offSet} '{print $1, $2-offSet, sqrt($3^2 + sqrt((offSet)^2))}' ${input_diff} > ${tmpOut}
  # cp ${tmpOut} ${input_diff}

fi


./unfold_minuit ${input_diff} ${detresponse} ${det_type} ${lowLimit} ${highLimit} ${binning} 3 3 MIGRAD 1000000000


mv /tmp/original ${energy_dir}/original_${it}_${binning}keV.asc
mv /tmp/unfolded ${energy_dir}/unfolded_${it}_${binning}keV.asc
mv /tmp/folded ${energy_dir}/folded_${it}_${binning}keV.asc

# calculate chi2 between original and folded
echo "${it} Calculating chi^2 of folded result from ${lowLimit_scaled} to ${highLimit_scaled}"
paste ${energy_dir}/original_${it}_${binning}keV.asc ${energy_dir}/folded_${it}_${binning}keV.asc | awk \
              -vfrom=${lowLimit} -vto=${highLimit} \
              'BEGIN{chi2=0;n=0} $1>=from && $1<to {if(sqrt($2)>0){n++; chi2+=(($4-$2)/sqrt($2))^2}}END{if(n>0){print chi2/n, chi2, n}}' \
              > ${energy_dir}/chi2_${it}_${binning}keV.dat

              echo -n "CHI2 = "
              cat ${energy_dir}/chi2_${it}_${binning}keV.dat



# end realization loop
done


# calculate chi2 as a function of the stretch parameter
cat ${energy_dir}/chi2_* | awk '{print $4, $1}' | sort -g > ${energy_dir}/chi2_total.dat

