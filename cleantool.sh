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

  echo "Working in $(pwd)"

  local DONE=()
  find -E . -maxdepth 1 -type f -regex '^\.\/.+\..+\.[a-zA-Z0-9]{6}$' 2>/dev/null | while read A; do
    local AA="${A##*.}"
    local AB="${A%.*}"
    CleanSet "$AB" "$AA"
  done
  IFS=$OFS
}

function CleanExtension() {
  if [ $# -ne 1 ]; then
    return 1
  fi
  local OFS=$IFS
  IFS=$'\0'
  local EXT=$1

  echo "Working on ${EXT} in $(pwd)"

  local DONE=()
  # hybrid glob find regex
  find -E ./*.${EXT}.* -maxdepth 1 -type f -regex '^\.\/.+\..+\.[a-zA-Z0-9]{6}$' 2>/dev/null | while read A; do
    local AA="${A##*.}"
    local AB="${A%.*}"
    CleanSet "$AB" "$AA"
  done
  IFS=$OFS
}

function RecursiveCleanDir() {
  local OFS=$IFS
  IFS=$'\0'
  local OPWD=$(pwd)
  if [ $# -eq 1 ]; then
    local EXT="$1"
    CleanExtension "$EXT"
  else
    # clean the files in this directory
    CleanDir # do files
  fi

  # walk the directories and recurse
  for D in ./* ; do
    if [ ! -L "${D}" -a -d "${D}" -a "$D" != "." -a "$D" != ".." ]; then
      cd "./${D}"
      # do recurse
      if [ ! -z $EXT ]; then
        RecursiveCleanDir "$EXT"
      else
        RecursiveCleanDir
      fi
      cd "${OPWD}"
    fi
  done

  IFS=${OFS}
}

function CleanSet() {
  if [ $# -ne 2 ]; then
    return 1
  fi
  local OFS=$IFS
  IFS=$'\0'
  local OPWD=`pwd`
  #local ABSPWD=$(toAbsPath)
  local BASEFILE="$1"
  local JUNKEXT="$2"

  if [[ ! -f "${BASEFILE}" ]]; then
    echo "  - Not a file: ${BASEFILE}"
    return 1
  fi
  if [[ ! -f "${BASEFILE}.${JUNKEXT}" ]]; then
    echo "  - Not a file: ${BASEFILE}.${JUNKEXT}"
    return 1
  fi

  echo "- Comparing ${OPWD}/${BASEFILE} +=> .${JUNKEXT}"
  if [ $USEMD5 -eq 1 ]; then
    local F1=`md5sum -b "${BASEFILE}" 2>/dev/null | awk '{ print $1; }' &`
    local F2=`md5sum -b "${BASEFILE}.${JUNKEXT}" 2>/dev/null | awk '{ print $1; }' &`
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
      cmp -s "${BASEFILE}" "${BASEFILE}.${JUNKEXT}" > /dev/null 2>&1
      local CMPMATCH=$?
  fi

  if [ $CMPMATCH -eq 0 ]; then
    echo -n "  - "
    if [ $DRYRUN -eq 1 ]; then
      echo -n "DRY RUN: "
    fi
    echo -n "Removing duplicate ${BASEFILE}.${JUNKEXT}"

    if [[ ! -z $F1 ]] && [[ ! -z $F2 ]]; then
        echo " [ ${F2} ]"
    else
        echo # newline
    fi

    if [[ $DRYRUN -ne 1 ]] && [[ $FORCERM -eq 1 ]]; then
      rm -f "${BASEFILE}.${JUNKEXT}"
    elif [[ $DRYRUN -ne 1 ]]; then
      rm "${BASEFILE}.${JUNKEXT}"
    fi
  else
    if [[ ! -z $F1 ]] && [[ ! -z $F2 ]]; then
      echo "  - Empty or mismatch [ md5: $F1 != $F2 ]"
    else
      echo "  - Empty or mismatch [ cmp returned ${CMPMATCH} ]"
    fi
  fi
  IFS=$OFS
}

# getopt
for ARG in $@; do
  case "$ARG" in
    "-R")
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
          echo "** ERROR ** : may only supply one extension to clean"
          exit 1
        fi
        CLEANEXT="$ARG"
        ;;
    esac
done

if [ $RECURSIVE -eq 1 ]; then
  if [ ! -z ${CLEANEXT} ]; then
    echo "<---- Starting recursive clean for .${CLEANEXT} ---->"
    RecursiveCleanDir "${CLEANEXT}"
  else
    echo "<---- Starting recursive clean ---->"
    RecursiveCleanDir
  fi
elif [ ! -z $CLEANEXT ]; then
  echo "<---- Starting extenion cleaning in the working directory for .${CLEANEXT} ---->"
  CleanExtension "$CLEANEXT"
else
  echo "<---- Starting cleaning in the working directory only ---->"
  CleanDir
fi
echo "<---- COMPLETE ---->"
exit 0
