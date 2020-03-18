#/bin/sh
j="macos"
for i in 1 3 6 12
do
  rm -rf ../EmptyEpsilon/_build_${j}
  echo "Testing ${j} with ${i} threads..."
  # facter > time-${i}-${j}.bench
  (
    cd ..
    time ./build_ee_macos.sh noupdate threads${i} ${j}
  ) >> time-${i}-${j}.bench 2>&1
  echo "Testing ${j} with ${i} threads complete."
  tail -n 5 time-${i}-${j}.bench
done
