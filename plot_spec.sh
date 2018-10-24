dir=$1


gnuplot -p << END

  p "${dir}/original_0_30keV.asc" w his

END

