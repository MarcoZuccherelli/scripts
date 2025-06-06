#!/bin/ksh

for i in 1 2 3; do
  echo "step $i"
done

if [[ -z "$i" ]]; then
  echo "$i"
fi