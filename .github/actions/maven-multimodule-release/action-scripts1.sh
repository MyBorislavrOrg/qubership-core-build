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
            echo "❌ Dry-run: build ${MODULE} version ${RELEASE_VERSION} failsed." >> $GITHUB_STEP_SUMMARY
            exit 1
        fi
        export RELEASE_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
        echo "✔️ Dry-run: Successfully built ${MODULE} version ${RELEASE_VERSION}" >> $GITHUB_STEP_SUMMARY
    else
        mvn --batch-mode versions:use-releases -DgenerateBackupPoms=false
        mvn --batch-mode release:prepare -DautoVersionSubmodules=true -DpushChanges=true -DtagNameFormat="v@{project.version}"
        if [ $? -ne 0 ]; then
            echo "Release preparation failed. Exiting."
            echo "❌ Release: preparation of ${MODULE} version ${RELEASE_VERSION} release failed." >> $GITHUB_STEP_SUMMARY
            exit 1
        fi
        # scm.tag=v2.0.2
        export RELEASE_VERSION=$(sed -n "s/scm.tag=v//p" release.properties)
        echo "✅ Release: successfully prepared ${MODULE} version ${RELEASE_VERSION} release." >> $GITHUB_STEP_SUMMARY
    fi
    echo "RELEASE_VERSION=${RELEASE_VERSION}" >> $GITHUB_OUTPUT
    echo "Building ${MODULE} version ${RELEASE_VERSION}"
    if [ "${DRY_RUN}" != "false" ]; then
        echo "Dry run. Not committing."
        return
    fi
    mvn --batch-mode release:perform -DpushChanges=true
    if [ $? -ne 0 ]; then
        echo "Release perform failed. Exiting."
        echo "❌ Release: ${MODULE} version ${RELEASE_VERSION} releas failed." >> $GITHUB_STEP_SUMMARY
        exit 1
    fi
    echo "✅ Release: ${MODULE} version ${RELEASE_VERSION} released successfully." >> $GITHUB_STEP_SUMMARY
}
