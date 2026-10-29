#!/bin/zsh
# Waits for the T=80 pilot to finish, then runs the witness-power replay and the teacher reachability.
cd "$(dirname "$0")"
LOG=../results/t80_pilot/t80_run.log
while ! grep -q '^wall ' "$LOG" 2>/dev/null && pgrep -f 'run_t80_pilot' >/dev/null; do sleep 60; done
echo "pilot finished at $(date +%H:%M)"
mkdir -p ../results/witness_power ../results/teacher_reach
/Applications/MATLAB_R2025a.app/bin/matlab -batch "run_witness_power" > ../results/witness_power/run.log 2>&1; echo "witness_power exit $? at $(date +%H:%M)"
/Applications/MATLAB_R2025a.app/bin/matlab -batch "run_teacher_reach" > ../results/teacher_reach/run.log 2>&1; echo "teacher_reach exit $? at $(date +%H:%M)"
