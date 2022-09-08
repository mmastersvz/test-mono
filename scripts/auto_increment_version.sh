#!/bin/bash

GH_LIMIT=100
MONOREPO_APP_NAME=$1
# MONOREPO_APP_NAME=app1

# gh release list --limit 100 | grep "^app2"
# gh release list --limit 100 | grep "^app1" | head -1 | awk '{print $1}'


if [[ ! -z ${MONOREPO_APP_NAME} ]]; then
  echo "MONOREPO: ${MONOREPO_APP_NAME}"
  NEW_TAG_PREFIX="${MONOREPO_APP_NAME}/v"
  FULL_VERSION=$(gh release list --limit ${GH_LIMIT} | grep "^${MONOREPO_APP_NAME}" | head -1 | awk '{print $1}')
  VERSION=$(echo ${FULL_VERSION} | cut -f2 -d /)
  # VERSION=$(gh release list --limit ${GH_LIMIT} | grep "^${MONOREPO_APP_NAME}" | head -1 | awk '{print $1}'| cut -f2 -d /)
else
  echo "SINGLE REPO"
  NEW_TAG_PREFIX="v"
  # get highest tag number
  # https://stackoverflow.com/questions/62960533/how-to-use-git-commands-during-a-github-action
  # VERSION=`git describe --abbrev=0 --tags`
  # https://docs.github.com/en/actions/using-workflows/using-github-cli-in-workflows
  VERSION=`gh release view -q ".name" --json name`
  FULL_VERSION=${VERSION}
fi

echo "NEW_TAG_PREFIX: ${NEW_TAG_PREFIX}"
echo "FULL_VERSION  : ${FULL_VERSION}"

# replace . with space so can split into an array
VERSION_BITS=(${VERSION//./ })

# get number parts and increase last one by 1
VNUM1=${VERSION_BITS[0]:-0}
VNUM2=${VERSION_BITS[1]:-0}
VNUM3=${VERSION_BITS[2]}
VNUM1=`echo $VNUM1 | sed 's/v//'`

# Check for #major or #minor in commit message and increment the relevant version number
MAJOR=`git log --format=%B -n 1 HEAD | grep '#major'`
MINOR=`git log --format=%B -n 1 HEAD | grep '#minor'`

if [ "$MAJOR" ]; then
    echo "Update major version"
    VNUM1=$((VNUM1+1))
    VNUM2=0
    VNUM3=0
elif [ "$MINOR" ]; then
    echo "Update minor version"
    VNUM2=$((VNUM2+1))
    VNUM3=0
else
    echo "Update patch version"
    VNUM3=$((VNUM3+1))
fi

# create new tag
NEW_VERSION="$VNUM1.$VNUM2.$VNUM3"
# NEW_TAG="v$NEW_VERSION"
NEW_TAG="${NEW_TAG_PREFIX}$NEW_VERSION"


# echo "Updating $VERSION to $NEW_TAG"
echo "Updating $FULL_VERSION to $NEW_TAG"

# get current hash and see if it already has a tag
GIT_COMMIT=`git rev-parse HEAD`
NEEDS_TAG=`git describe --contains $GIT_COMMIT`

# only tag if no tag already (would be better if the git describe command above could have a silent option)
if [ -z "$NEEDS_TAG" ]; then
    echo "Tagged with $NEW_TAG (Ignoring fatal:cannot describe - this means commit is untagged) "
    # env | sort
    gh release create $NEW_TAG --generate-notes
    rc=$?
    if [ ${rc} -ne 0 ] ; then
      exit ${rc}
    fi
    echo ${NEW_VERSION} > VERSION
    # echo ${NEW_TAG} > TAG_VERSION
else
    echo "Already a tag on this commit"
    echo $(echo ${VERSION} | sed 's/v//') > VERSION
    # echo ${VERSION} > TAG_VERSION
fi
exit 0