energy=$1


for i in 1 2 3 4
do
  live=$(head original/${energy}_0${i}_orig.tv | awk 'NR==8 {print $5}')
  real=$(head original/${energy}_0${i}_orig.tv | awk 'NR==9 {print $5}')
  ratio=$(echo ${live} ${real} | awk '{print $1/$2}')

  echo ${energy} "0"${i} ${live} ${real} ${ratio}
done
