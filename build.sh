#/bin/bash

pasmo --tap BetterBloodwych.asm BetterBloodwych.tap file.symbol
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
cat BetterBloodwychBAS.tap BetterBloodwych.tap  > BetterBloodwychLoader.tap
rc=$?; if [[ $rc != 0 ]]; then rm BetterBloodwychLoader.tap; exit $rc; fi
# If the original Bloodwych.tap file is here (71,904 bytes) then the loader
# will be prepended and you will get a PatchedBloodwych.tap file. Otherwise
# you will get only the loader (useful if you just want it for real machine
# where you already have the Bloodwych real tape)
cat BetterBloodwychLoader.tap Bloodwych.tap > PatchedBloodwych.tap
rc=$?; if [[ $rc != 0 ]]; then rm PatchedBloodwych.tap; fi
