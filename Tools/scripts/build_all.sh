#!/bin/bash
# useful script to test all the different build types that we support.
# This helps when doing large merges
# Andrew Tridgell, November 2011

set -e
set -x

echo "Testing ArduPlane build"
pushd ArduPlane
for b in all apm2 apm2beta hil hilsensors mavlink10 sitl sitl-mavlink10 sitl-mount; do
    pwd
    make clean
    make $b
done
popd

echo "Testing ArduCopter build"
pushd ArduCopter
for b in all apm2 apm2beta hil sitl heli; do
    pwd
    make clean
    make $b
done
popd

echo "Testing APMRover build"
pushd APMrover2
for b in all; do
    pwd
    make clean
    make $b
done
popd

echo "Testing build of examples"

examples="Tools/VARTest Tools/CPUInfo"
for d in $examples; do
    pushd $d
    make clean
    make
    popd
done

exit 0
