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

function bump_version_and_build() {
    cd ${GITHUB_WORKSPACE}/${MODULE}
    git config --global user.name "${GITHUB_ACTOR}"
    git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"
    echo "Bumping ${MODULE} version"
    if [ "${DRY_RUN}" != "false" ]; then
        echo "Dry run. Not bumping version."
        mvn --batch-mode deploy $MVN_ARGS
        if [ $? -ne 0 ]; then
            echo "Build failed. Exiting."
            exit 1
        fi
        export RELEASE_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
    else
        mvn --batch-mode versions:use-releases -DgenerateBackupPoms=false
        mvn --batch-mode release:prepare -DautoVersionSubmodules=true -DpushChanges=true -DtagNameFormat="v@{project.version}"
        if [ $? -ne 0 ]; then
            echo "Release preparation failed. Exiting."
            exit 1
        fi
        # scm.tag=v2.0.2
        export RELEASE_VERSION=$(sed -n "s/scm.tag=v//p" release.properties)
    fi
    echo "RELEASE_VERSION=${RELEASE_VERSION}" >> $GITHUB_OUTPUT
    echo "Building ${MODULE} version ${RELEASE_VERSION}"
    if [ "${DRY_RUN}" != "false" ]; then
        echo "Dry run. Not committing."
        return
    fi
    # mvn --batch-mode clean
    mvn --batch-mode release:perform -DpushChanges=true
    if [ $? -ne 0 ]; then
        echo "Release perform failed. Exiting."
        exit 1
    fi
    echo "Release perform succeeded. Commiting pom.xml with release version."
}

# function maven_deploy() {
#     cd ${GITHUB_WORKSPACE}/${MODULE}
#     export VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
#     echo "Deploying ${MODULE} version ${VERSION}"
#     if [ "${DRY_RUN}" != "false" ]; then
#         echo "Dry run. Not deploying."
#         return
#     fi
#     mvn --batch-mode deploy -DskipTests $MVN_ARGS
#     if [ $? -ne 0 ]; then
#         echo "Deploy failed. Exiting."
#         exit 1
#     fi
#     echo "Deploy succeeded."
# }

function bump_to_next_snapshot() {
    return
    echo "Bumping ${MODULE} version to next snapshot"
    echo "Current version is ${VERSION}"
    if [ "${DRY_RUN}" != "false" ]; then
        echo "Dry run. Not bumping to next snapshot."
        return
    fi
    cd ${GITHUB_WORKSPACE}/${MODULE}
    mvn build-helper:parse-version versions:set -DgenerateBackupPoms=false \
    -DnewVersion=\${parsedVersion.majorVersion}.\${parsedVersion.minorVersion}.\${parsedVersion.nextIncrementalVersion}-SNAPSHOT
    export VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
    echo "Next snapshot version is ${VERSION}"
    echo "Commiting pom.xml with next snapshot version."
    mvn --batch-mode clean
    git add .
    git commit -m "Bump version to next snapshot ${VERSION} [skip ci]"
    git push
}