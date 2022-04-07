#!/bin/bash
#
# Script to archive a subset of packages matching specific license(s)
# Source and license files are copied into sub folders of package folder
#
# Based upon example script in
# https://www.yoctoproject.org/docs/3.1/dev-manual/dev-manual.html#maintaining-open-source-license-compliance-during-your-products-lifecycle

src_release_dir="$1"
mkdir -p $src_release_dir
for a in build/tmp/deploy/sources/*; do
   for d in $a/*; do
      # Get package name from path
      p=`basename $d`
      p=${p%-*}
      p=${p%-*}
      # Only archive GPL packages (update *GPL* regex for your license check)
      numfiles=`ls build/tmp/deploy/licenses/$p/*GPL* 2> /dev/null | wc -l`
      if [ $numfiles -ge 1 ]; then
         echo Archiving $p
         mkdir -p $src_release_dir/$p/source
         cp $d/* $src_release_dir/$p/source 2> /dev/null
         mkdir -p $src_release_dir/$p/license
         cp build/tmp/deploy/licenses/$p/* $src_release_dir/$p/license 2> /dev/null
      fi
   done
done
