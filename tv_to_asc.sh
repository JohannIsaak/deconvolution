energy=$1


for i in 1 2 3 4
do

  offset=$(head original/${energy}_0${i}_orig.cal | awk 'NR==1 {print $1}')
  gain=$(head original/${energy}_0${i}_orig.cal | awk 'NR==2 {print $1}')

  awk -voffset=${offset} -vgain=${gain} 'NR>10 {print NR*gain + offset, $1}' original/${energy}_0${i}_orig.tv > input_spec/${energy}_0${i}.asc

done
