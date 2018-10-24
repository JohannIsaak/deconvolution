#!/bin/bash

if [ $# -ne 2 ] ; then
  echo "Usage: $0 <keV> <file.asc>"
  exit
fi

keV=$1
file=$2

echo ${file}
awk -vA=${keV} -f /home/jisaak/documents/physics_stuff/unfolding_software/awk/rebin.awk ${file} > ${file%%.asc}_${keV}keV.asc

