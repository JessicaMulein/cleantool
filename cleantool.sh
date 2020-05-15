#!/bin/bash
USEMD5=0
DRYRUN=0

function CleanDir() {
  OFS=$IFS
  IFS=$'\0'

  DONE=()
  for A in ./*.*.*; do
    #AA=`echo "$A" | sed -E 's/^(.*)\.(.*)\.(.*)$/\1/'`
    AB=`echo "$A" | sed -E 's/^.+\.(.+)\..+$/\1/'`
    #AC=`echo "$A" | sed -E 's/^(.*)\.(.*)\.(.*)$/\3/'`
    if [[ ! " ${DONE[*]} " == *"${AB}"* ]]; then
      DONE+=(${AB})
      ISAMPM=`echo "${AB}" | grep -E "^[0-9]+ (AM|PM)$"`
      if [ "${ISAMPM}" = "" ]; then
        CleanExtension "${AB}"
      fi
    fi
  done
  IFS=$OFS
}

function RecursiveCleanDir() {
  OFS=$IFS
  IFS=$'\0'

  # clean the files in this directory
  CleanDir # do files

  # walk the directories and recurse
  for D in * ; do
    if [ -d "${D}" ]; then
      cd "${D}"
      RecursiveCleanDir # do dirs/recurse
      cd ..
    fi
  done

  IFS=${OFS}
}

function CleanExtension() {
  OFS=$IFS
  IFS=$'\0'
  EXT=$1
  if [ "$1" = "" ]; then
    exit
  fi
  OPWD=`pwd`

  echo "Cleaning $OPWD of $EXT.* duplicates"
  for A in ./*.${EXT}; do
    AEXT=""
    CNT=0
    Afilename="${A%.${EXT}}"
    for B in ./${Afilename}.${EXT}.*; do
      Bextension="${B##*.}"
      AEXT="${Afilename}.${EXT}.${Bextension}"
      if [ "${Afilename}" != "*" -a "${Bextension}" != "*" -a "${Afilename}" != "./*" -a "${Bextension}" != "./*" ]; then
        let "CNT=CNT+1"
      fi
    done
    if [ $CNT -ne 1 ]; then
      echo "- Found $CNT of ${Afilename}.${EXT}.*"
    else
      echo "- Comparing $OPWD/${A} +=> .${Bextension}"
      if [ $USEMD5 -eq 1 ]; then
        F1=`md5sum -b "${A}" 2>/dev/null | awk '{ print $1; }' &`
        F2=`md5sum -b "${AEXT}" 2>/dev/null | awk '{ print $1; }' &`
        FAIL=0
        for job in `jobs -p`
        do
          echo $job
          wait $job || let "FAIL+=1"
        done

        if [ "$FAIL" == "0" -a "$F1" = "$F2" -a "$F1" != "" ]; then
          CMPMATCH=0
        else
            echo "  - Failed joining $FAIL/2 hashes"
        fi
      else
          cmp -s "${A}" "${AEXT}" > /dev/null 2>&1
          CMPMATCH=$?
      fi

      if [ $CMPMATCH -eq 0 ]; then
        echo -n "  - "
        if [ $DRYRUN -eq 1 ]; then
          echo -n "DRY RUN:"
        fi
        echo -n "Removing duplicate ${AEXT}"

        if [[ ! -z $F1 ]] && [[ ! -z $F2 ]]; then
            echo " [ ${F2} ]"
        else
            echo # newline
        fi

        [[ $DRYRUN -ne 1 ]] || rm "${AEXT}"
      else
        if [[ ! -z $F1 ]] && [[ ! -z $F2 ]]; then
          echo "  - Empty or mismatch [ md5: $F1 != $F2 ]"
        else
          echo "  - Empty or mismatch [ cmp returned ${CMPMATCH} ]"
        fi
      fi
    fi
  done
  IFS=$OFS
}

if [ "$1" == "-R" ]; then
  RecursiveCleanDir
elif [ $# -eq 2 ]; then
  CleanExtension $1
else
  CleanDir
fi
