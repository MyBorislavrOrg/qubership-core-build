#! /usr/bin/env bash

function check_version_type() {
    if [[ $1 != "major" && $1 != "minor" && $1 != "patch" ]]; then
        echo "Invalid version type. Please use major, minor or patch."
        exit 1
    fi
}

function check_module() {
    if [ -z "$1" ]; then
        echo "Module is required."
        exit 1
    fi
}

function check_token() {
    if [ -z "$1" ]; then
        echo "token input parameter is required."
        exit 1
    fi
}

function set_env_vars() {
    export MODULE=$1
    export VERSION_TYPE=$2
}

function bump_version_and_build() {
    cd ${GITHUB_WORKSPACE}/${MODULE}
    git config --global user.name "${GITHUB_ACTOR}"
    git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"
    echo "Bumping ${MODULE} version"
    if [ "${VERSION_TYPE}" == "major" ]; then
        mvn --batch-mode build-helper:parse-version versions:set -DgenerateBackupPoms=false \
        -DnewVersion=\${parsedVersion.nextMajorVersion}.0.0
    elif [ "${VERSION_TYPE}" == "minor" ]; then
        mvn --batch-mode build-helper:parse-version versions:set -DgenerateBackupPoms=false \
        -DnewVersion=\${parsedVersion.majorVersion}.\${parsedVersion.nextMinorVersion}.0
    else
        mvn --batch-mode build-helper:parse-version versions:set -DgenerateBackupPoms=false \
        -DnewVersion=\${parsedVersion.majorVersion}.\${parsedVersion.minorVersion}.\${parsedVersion.incrementalVersion}
    fi
    export VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
    echo "VERSION=${VERSION}" >> $GITHUB_ENV
    echo "Building ${MODULE} version ${VERSION}"
    mvn --batch-mode install
    mvn clean
    git add .
    git commit -m "Bump version to ${VERSION} [skip ci]"
    git push
    git tag -a v${VERSION} -m "Release version v${VERSION} [skip ci]"
    git push origin v${VERSION}
}

function maven_deploy() {
    cd ${GITHUB_WORKSPACE}/${MODULE}
    export VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
    echo "Deploying ${MODULE} version ${VERSION}"
    # mvn --batch-mode deploy -DskipTests
    mvn --batch-mode install -DskipTests
}

function bump_to_next_snapshot() {
    cd ${GITHUB_WORKSPACE}/${MODULE}
    mvn build-helper:parse-version versions:set -DgenerateBackupPoms=false \
    -DnewVersion=\${parsedVersion.majorVersion}.\${parsedVersion.minorVersion}.\${parsedVersion.nextIncrementalVersion}-SNAPSHOT
    export VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
    mvn clean
    git add .
    git commit -m "Bump version to next snapshot ${VERSION} [skip ci]"
    git push
}