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
    if [ "${DRY_RUN}" != "false" ]; then
        echo "::group::Buildin ${MODULE} current version."
        echo "Dry run. Not bumping version."
        mvn --batch-mode deploy $MVN_ARGS
        echo "::endgroup::"
        if [ $? -ne 0 ]; then
            echo "Build failed. Exiting."
            echo "❌ Dry-run: build ${MODULE} version ${RELEASE_VERSION} failsed." >> $GITHUB_STEP_SUMMARY
            exit 1
        fi
        export RELEASE_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
        echo "✔️ Dry-run: Successfully built ${MODULE} version ${RELEASE_VERSION}" >> $GITHUB_STEP_SUMMARY
    else
        echo "::group::Preparing ${MODULE} release."
        mvn --batch-mode versions:use-releases -DgenerateBackupPoms=false
        mvn --batch-mode release:prepare -DautoVersionSubmodules=true -DpushChanges=true -DtagNameFormat="v@{project.version}"
        echo "::endgroup::"
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
    echo "::group::Releasing ${MODULE} version ${RELEASE_VERSION}"
    mvn --batch-mode release:perform -DpushChanges=true
    echo "::endgroup::"
    if [ $? -ne 0 ]; then
        echo "Release perform failed. Exiting."
        echo "❌ Release: ${MODULE} version ${RELEASE_VERSION} releas failed." >> $GITHUB_STEP_SUMMARY
        exit 1
    fi
    echo "✅ Release: ${MODULE} version ${RELEASE_VERSION} released successfully." >> $GITHUB_STEP_SUMMARY
}

function bump_dependencies_versions() {
    cd ${GITHUB_WORKSPACE}/${MODULE}
    # To update pom.xml dependencies with the next -SNAPSHOT version need to deploy SNAPSHOT version
    if [ "${DRY_RUN}" != "false" ]; then
        echo "Dry run. Not updating dependencies."
        return
    fi
    echo "::group::Building ${MODULE} version ${RELEASE_VERSION}-SNAPSHOT"
    mvn --batch-mode deploy -DskipTests=true $MVN_ARGS
    echo "::endgroup::"
    if [ $? -ne 0 ]; then
        echo "Build failed. Exiting."
        echo "❌ Build: ${MODULE} version ${RELEASE_VERSION}-SNAPSHOT failed." >> $GITHUB_STEP_SUMMARY
        exit 1
    fi
    echo "✅ Build: ${MODULE} version ${RELEASE_VERSION}-SNAPSHOT built successfully." >> $GITHUB_STEP_SUMMARY
    echo "::group::Updating ${MODULE} dependencies versions to next-snapshot"
    mvn --batch-mode versions:use-next-snapshots -DgenerateBackupPoms=false -Dincludes="org.qubership.cloud*:*,org.qubership.core*:*"
    echo "::endgroup::"
    if [ $? -ne 0 ]; then
        echo "Update dependencies failed. Exiting."
        echo "❌ Update: ${MODULE} dependencies versions to next-snapshot failed." >> $GITHUB_STEP_SUMMARY
        exit 1
    fi
    echo "::group::Clean and commit pom.xml with next-snapshot version."
    echo "Committing pom.xml with release version."
    mvn --batch-mode clean
    gitdiffstat=$(git diff --stat)
    if [ -z "${gitdiffstat}" ]
    then
        echo "No changes"
        echo "ℹ️ Commit: There were no changed dependencies versions in ${MODULE} pom.xml." >> $GITHUB_STEP_SUMMARY
        return
    else
        git add .
        git commit -m "Bump dependencies versions to next-snapshot [skip ci]"
        git push
        echo "::endgroup::"
        if [ $? -ne 0 ]; then
            echo "Commit failed. Exiting."
            echo "❌ Commit: ${MODULE} pom.xml with next-snapshot version failed." >> $GITHUB_STEP_SUMMARY
            exit 1
        fi
        echo "✅ Commit: ${MODULE} pom.xml with next-snapshot version committed successfully." >> $GITHUB_STEP_SUMMARY
    fi
}