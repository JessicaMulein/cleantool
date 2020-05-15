#!/bin/bash
# do not change these values. Filled by getopt
USEMD5=0
DRYRUN=0
FORCERM=0
RECURSIVE=0
#CLEANEXT=#DO NOT DEFINE/UNCOMMENT! Required for logic

# https://stackoverflow.com/questions/4175264/how-to-retrieve-absolute-path-given-relative/51264222#51264222
function toAbsPath {
    local target="$1"

    if [ "$target" == "." ]; then
        echo "$(pwd)"
    elif [ "$target" == ".." ]; then
        echo "$(dirname "$(pwd)")"
    else
        echo "$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
    fi
}

function CleanDir() {
  local OFS=$IFS
  IFS=$'\0'

  local DONE=()
  for A in ./*.*.*; do
    #AA=`echo "$A" | sed -E 's/^(.*)\.(.*)\.(.*)$/\1/'`
    local AB=`echo "$A" | sed -E 's/^.+\.(.+)\..+$/\1/'`
    #AC=`echo "$A" | sed -E 's/^(.*)\.(.*)\.(.*)$/\3/'`
    if [[ ! " ${DONE[*]} " == *"${AB}"* ]]; then
      DONE+=(${AB})
      local ISAMPM=`echo "${AB}" | grep -E "^[0-9]+ (AM|PM)$"`
      if [ "${ISAMPM}" = "" ]; then
        CleanExtension "${AB}"
      fi
    fi
  done
  IFS=$OFS
}

function RecursiveCleanDir() {
  local OFS=$IFS
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
  local OFS=$IFS
  IFS=$'\0'
  local EXT=$1
  if [ "$1" = "" ]; then
    exit
  fi
  if [[ "$1" = "*" ]] || [[ "$1" = "./*" ]]; then
    return
  fi
  local OPWD=`pwd`
  local ABSPWD=$(toAbsPath)

  echo "Checking $OPWD for *.${EXT}.* duplicates"
  for A in ./*.${EXT}; do
    local AEXT=""
    local CNT=0
    local Afilename="${A%.${EXT}}"
    for B in ./${Afilename}.${EXT}.*; do
      local Bextension="${B##*.}"
      local AEXT="${Afilename}.${EXT}.${Bextension}"
      if [ "${Afilename}" != "*" -a "${Bextension}" != "*" -a "${Afilename}" != "./*" -a "${Bextension}" != "./*" ]; then
        echo "- Comparing $OPWD/${A} +=> .${Bextension}"
        if [ $USEMD5 -eq 1 ]; then
          local F1=`md5sum -b "${A}" 2>/dev/null | awk '{ print $1; }' &`
          local F2=`md5sum -b "${AEXT}" 2>/dev/null | awk '{ print $1; }' &`
          local FAIL=0
          for job in `jobs -p`; do
            wait $job || let "FAIL+=1"
          done

          if [ "$FAIL" == "0" -a "$F1" = "$F2" -a "$F1" != "" ]; then
            local CMPMATCH=0
          else
              echo "  - Failed joining $FAIL/2 hashes"
          fi
        else
            cmp -s "${A}" "${AEXT}" > /dev/null 2>&1
            local CMPMATCH=$?
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
    "-dry-run")
        DRYRUN=1
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
