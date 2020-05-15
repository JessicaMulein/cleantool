#!/bin/bash
# do not change these values. Filled by getopt
USEMD5=0
DRYRUN=0
FORCERM=0
RECURSIVE=0
#CLEANEXT=#DO NOT DEFINE/UNCOMMENT! Required for logic

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
  if [[ "$1" = "*" ]] || [[ "$1" = "./*" ]]; then
    return
  fi
  OPWD=`pwd`

  echo "Checking $OPWD for *.${EXT}.* duplicates"
  for A in ./*.${EXT}; do
    AEXT=""
    CNT=0
    Afilename="${A%.${EXT}}"
    for B in ./${Afilename}.${EXT}.*; do
      Bextension="${B##*.}"
      AEXT="${Afilename}.${EXT}.${Bextension}"
      if [ "${Afilename}" != "*" -a "${Bextension}" != "*" -a "${Afilename}" != "./*" -a "${Bextension}" != "./*" ]; then
        echo "- Comparing $OPWD/${A} +=> .${Bextension}"
        if [ $USEMD5 -eq 1 ]; then
          F1=`md5sum -b "${A}" 2>/dev/null | awk '{ print $1; }' &`
          F2=`md5sum -b "${AEXT}" 2>/dev/null | awk '{ print $1; }' &`
          FAIL=0
          for job in `jobs -p`; do
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
            echo -n "DRY RUN: "
          fi
          echo -n "Removing duplicate ${AEXT}"

          if [[ ! -z $F1 ]] && [[ ! -z $F2 ]]; then
              echo " [ ${F2} ]"
          else
              echo # newline
          fi

          if [[ $DRYRUN -eq 1 ]] && [[ $FORCERM -eq 1 ]]; then
            rm -f "${AEXT}"
          elif [[ $DRYRUN -eq 1 ]]; then
            rm "${AEXT}"
          fi
        else
          if [[ ! -z $F1 ]] && [[ ! -z $F2 ]]; then
            echo "  - Empty or mismatch [ md5: $F1 != $F2 ]"
          else
            echo "  - Empty or mismatch [ cmp returned ${CMPMATCH} ]"
          fi
        fi
      fi
    done
  done
  IFS=$OFS
}

# getopt
for ARG in $@; do
  case "$ARG" in
    "-R")
        if [[ ! -z $CLEANEXT ]]; then
          echo "** ERROR ** : may not supply extension with -R option"
          exit 2
        fi
        RECURSIVE=1
        ;;
    "-f")
        FORCERM=1
        ;;
    "-md5")
        USEMD5=1
        ;;
    *)
        # we've now seen an extension or some other data, skip it, but now we can assume we're doing CleanExtension since that is the only one that takes an argument
        if [ ! -z $CLEANEXT ]; then
          echo "** ERROR ** : may only supply one extension to clean in the working directory"
          exit 1
        fi
        if [ $RECURSIVE -eq 1 ]; then
          echo "** ERROR ** : may not supply extension with -R option"
          exit 2
        fi
        CLEANEXT="$ARG"
        ;;
    esac
done

if [ $RECURSIVE -eq 1 ]; then
  echo "<---- Starting recursive clean ---->"
  RecursiveCleanDir
elif [ ! -z $CLEANEXT ]; then
  echo "<---- Starting extenion cleaning in the working directory ---->"
  CleanExtension "$CLEANEXT"
else
  echo "<---- Starting cleaning in the working directory only ---->"
  CleanDir
fi
echo "<---- COMPLETE ---->"
exit 0
