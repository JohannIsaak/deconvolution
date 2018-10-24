dir=$1
bin=$2



if [ $# -lt 2 ] ; then
 echo "Usage: $0 <dir> <binning in keV>"
 exit
fi



paste ${dir}/unfolded_*_${bin}keV.asc | awk '{sum=0; i=2; while(i<=100){sum+=$(i); i+=2}}{print $1, sum/50}' > avg_unfolded_${dir}.spec
paste avg_unfolded_${dir}.spec ${dir}/unfolded_*_${bin}keV.asc | awk '{sum=0; i=4; while(i<=100){sum+=($2-$(i))^2; i+=2}}{print $1, $2, sqrt((1/(50-1))*sum)}' > avg_unfolded_${dir}_werr.spec

# paste ${dir}/unfolded_*_${bin}keV.asc | awk '{sum=0; i=2; while(i<=60){sum+=$(i); i+=2}}{print $1, sum/30}' > avg_unfolded_${dir}.spec
# paste avg_unfolded_${dir}.spec ${dir}/unfolded_*_${bin}keV.asc | awk '{sum=0; i=4; while(i<=50){sum+=($2-$(i))^2; i+=2}}{print $1, $2, sqrt((1/(30-1))*sum)}' > avg_unfolded_${dir}_werr.spec

#paste ${dir}/unfolded_*_${bin}keV.asc | awk '{sum=0; i=2; while(i<=40){sum+=$(i); i+=2}}{print $1, sum/20}' > avg_unfolded_${dir}.spec
#paste avg_unfolded_${dir}.spec ${dir}/unfolded_*_${bin}keV.asc | awk '{sum=0; i=4; while(i<=40){sum+=($2-$(i))^2; i+=2}}{print $1, $2, sqrt((1/(20-1))*sum)}' > avg_unfolded_${dir}_werr.spec

