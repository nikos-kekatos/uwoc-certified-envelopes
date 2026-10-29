#!/bin/zsh
cd "$(dirname "$0")"
while ! grep -q 'teacher_reach exit' ../results/followups.log 2>/dev/null; do sleep 60; done
mkdir -p ../results/tsweep
/Applications/MATLAB_R2025a.app/bin/matlab -batch "run_tsweep" > ../results/tsweep/run.log 2>&1; echo "tsweep exit $? at $(date +%H:%M)"
