#!/bin/bash

set -u
set -e
set +o nounset

# Workaround for at least Debian Buster
# Require to build bonita-portal-js due to issue with PhantomJS launched by Karma
# See https://github.com/ariya/phantomjs/issues/14520
export OPENSSL_CONF=/etc/ssl

# Script configuration
# You can set the following environment variables
BONITA_BUILD_NO_CLEAN=${BONITA_BUILD_NO_CLEAN:-false}
BONITA_BUILD_QUIET=${BONITA_BUILD_QUIET:-false}
BONITA_BUILD_STUDIO_ONLY=${BONITA_BUILD_STUDIO_ONLY:-false}
BONITA_BUILD_STUDIO_SKIP=${BONITA_BUILD_STUDIO_SKIP:-false}

# Bonita version

BRANCH_OR_TAG=7.15.0

########################################################################################################################
# SCM AND BUILD FUNCTIONS
########################################################################################################################

# $1: the message to be displayed as header
echoHeaders() {
    echo
    echo
	echo "============================================================"
	echo "$1"
	echo "============================================================"
}

# params:
# - Git repository name
# - Tag name (optional)
# - Checkout folder name (optional)
checkout() {
    # We need at least one parameter (the repository name) and no more than three (repository name, tag name and checkout folder name)
    if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
        echo "Incorrect number of parameters: $@"
        exit 1
    fi

    repository_name="$1"

    if [ "$#" -eq 3 ]; then
        checkout_folder_name="$3"
    else
        # If no checkout folder path is provided use the repository name as destination folder name
        checkout_folder_name="$repository_name"
    fi

    # If we don't already clone the repository do it
    if [ ! -d "$checkout_folder_name/.git" ]; then
      echoHeaders "Cloning ${repository_name}"
      git clone --depth 1 "https://github.com/bonitasoft/$repository_name.git" $checkout_folder_name
    fi


    # Ensure we fetch all the tags and that we are on the appropriate one
    git -C $checkout_folder_name fetch --tags

    if [ "$#" -ge 2 ]; then
        tag_name="$2"
    else
        # If we don't have a tag name assume that the tag is named with the Bonita version
		tag_name=$BRANCH_OR_TAG
    fi

    set +e

    git -C $checkout_folder_name show-ref --quiet --verify refs/tags/$tag_name

    if [ $? -eq 0 ]; then
        echo "Found a matching tag ref for $tag_name"
        tag_name="tags/$tag_name"
    else
        git -C $checkout_folder_name show-ref -q --verify refs/heads/$tag_name
        if [ $? -eq 0 ]; then 
            echo "Found a matching branch ref for $tag_name"
        else
            echo "$tag_name is neither a known tag or branch in $repository_name"
            exit 1
        fi
    fi

    set -e

	echoHeaders "Switching ${repository_name} to ${tag_name}"

    git -C $checkout_folder_name reset --hard $tag_name

    # Move to the repository clone folder (required to run Maven/Gradle wrapper)
    cd $checkout_folder_name
}

run_maven_with_standard_system_properties() {
    echo "[DEBUG] Running build command: $build_command"
    eval "$build_command"
    # Go back to script folder (checkout move current directory to project checkout folder.
    cd ..
}

run_gradle_with_standard_system_properties() {
    echo "[DEBUG] Running build command: $build_command"
    eval "$build_command"
    # Go back to script folder (checkout move current directory to project checkout folder.
    cd ..
}

build_maven_wrapper() {
    build_command="./mvnw -ntp"
}

build_gradle_wrapper() {
    build_command="./gradlew"
}

build_quiet_if_requested() {
    if [[ "${BONITA_BUILD_QUIET}" == "true" ]]; then
        echo "Configure quiet build"
        build_command="$build_command --quiet"
    fi
}

build() {
    build_command="$build_command build"
}

publishToMavenLocal() {
    build_command="$build_command publishToMavenLocal"
}

clean() {
    if [[ "${BONITA_BUILD_NO_CLEAN}" == "true" ]]; then
        echo "Configure build to skip clean task"
    else
        build_command="$build_command clean"
    fi
}

install() {
    build_command="$build_command install"
}

verify() {
    build_command="$build_command verify"
}

module_only() {
    build_command="$build_command -pl :$1 -am"
}

skiptest() {
    build_command="$build_command -DskipTests"
}

skipLocalRepositoryCompatibleVersion() {
    build_command="$build_command -DlocalRepository.compatibleVersions.skip"
}

gradle_test_skip() {
    build_command="$build_command -x test"
}

profile() {
    build_command="$build_command -P$1"
}

# params:
# - Git repository name
# - Profile name
build_maven_wrapper_verify_skiptest_with_profile()
{
    checkout $1
    build_maven_wrapper
    build_quiet_if_requested
    clean
    verify
    skiptest
    skipLocalRepositoryCompatibleVersion
    profile $2
    run_maven_with_standard_system_properties
}

# params:
# - Git repository name
build_maven_wrapper_install_skiptest()
{
    checkout "$@"
    build_maven_wrapper
    build_quiet_if_requested
    clean
    install
    skiptest
    run_maven_with_standard_system_properties
}

# params:
# - Git repository name
# - Module name
build_maven_wrapper_install_skiptest_with_module()
{
    checkout $1
    build_maven_wrapper
    build_quiet_if_requested
    clean
    install
    module_only $2
    skiptest
    run_maven_with_standard_system_properties
}

build_gradle_wrapper_test_skip_publishToMavenLocal() {
    checkout "$@"
    build_gradle_wrapper
    build_quiet_if_requested
    clean
    gradle_test_skip
    publishToMavenLocal
    run_gradle_with_standard_system_properties
}

########################################################################################################################
# PARAMETERS PARSING AND VALIDATIONS
########################################################################################################################

OS_IS_LINUX=false
OS_IS_MAC=false
OS_IS_WINDOWS=false

detectOS() {
    case "`uname`" in
      CYGWIN*)  OS_IS_WINDOWS=true;;
      MINGW*)   OS_IS_WINDOWS=true;;
      Darwin*)  OS_IS_MAC=true;;
      *)        OS_IS_LINUX=true;;
    esac
}

logBuildInfo() {
    echo "OS information"
    if [[ "${OS_IS_LINUX}" == "true" ]]; then
        echo "  > Run on Linux"
        echo "$(cat /etc/lsb-release)" | xargs -L 1 -I % echo "      %"
    elif [[ "${OS_IS_MAC}" == "true" ]]; then
        echo "  > Run on MacOS"
        echo "$(sw_vers)" | xargs -L 1 -I % echo "      %"
    else
        echo "  > Run on Windows"
        echo "$(wmic os get Caption,OSArchitecture,Version //value)" | xargs -L 1 --no-run-if-empty -I % echo "      %" | grep -v -e '^[[:space:]]*$'
    fi
    echo "  > Generic information: $(uname -a)"

    echo "Build environment"
    echo "  > Use $(git --version)"
    echo "  > Commit: $(git rev-parse FETCH_HEAD)"

    echo "Build settings"
    echo "  > BRANCH_OR_TAG: ${BRANCH_OR_TAG}"
    echo "  > BONITA_BUILD_NO_CLEAN: ${BONITA_BUILD_NO_CLEAN}"
    echo "  > BONITA_BUILD_QUIET: ${BONITA_BUILD_QUIET}"
    echo "  > BONITA_BUILD_STUDIO_ONLY: ${BONITA_BUILD_STUDIO_ONLY}"
    echo "  > BONITA_BUILD_STUDIO_SKIP: ${BONITA_BUILD_STUDIO_SKIP}"
}

checkPrerequisites() {
    echo "Prerequisites"
    # Test if Curl exists
    if hash curl 2>/dev/null; then
        CURL_VERSION="$(curl --version 2>&1  | awk -F " " 'NR==1 {print $2}')"
        echo "  > Use curl version: $CURL_VERSION"
    else
        echo "curl not found. Exiting."
        exit 1
    fi

    checkJavaVersion
}

checkJavaVersion() {
    local JAVA_CMD=
    echo "  > Java prerequisites"
    echo "      Check if Java version is compatible with Bonita"

    if [[ "x$JAVA" = "x" ]]; then
        if [[ "x$JAVA_HOME" != "x" ]]; then
            echo "      JAVA_HOME is set"
            JAVA_CMD="$JAVA_HOME/bin/java"
        else
            echo "      JAVA_HOME is not set. Use java in path"
            JAVA_CMD="java"
        fi
    else
        JAVA_CMD=${JAVA}
    fi
    echo "      Java command path is $JAVA_CMD"

    java_full_version_details=$("$JAVA_CMD" -version 2>&1)
    echo "      JVM details"
    echo "${java_full_version_details}" | xargs -L 1 -I % echo "        %"

    java_full_version=$("$JAVA_CMD" -version 2>&1 | grep -i version | sed 's/.*version "\(.*\)".*$/\1/g')
    echo "      Java full version: $java_full_version"
    if [[ "x$java_full_version" = "x" ]]; then
      echo "No Java command could be found. Please set JAVA_HOME variable to a JDK and/or add the java executable to your PATH"
      exit 1
    fi

    java_version_1st_digit=$(echo "$java_full_version" | sed 's/\(.*\)\..*\..*$/\1/g')
    java_version_expected=11
    # pre Java 9 versions, get minor version
    if [[ "$java_version_1st_digit" -eq "1" ]]; then
      java_version=$(echo "$java_full_version" | sed 's/.*\.\(.*\)\..*$/\1/g')
    else
      java_version=${java_version_1st_digit}
    fi
    echo "      Java version: $java_version"

    if [[ "$java_version" -ne "$java_version_expected" ]]; then
      echo "Invalid Java version $java_version not $java_version_expected. Please set JAVA_HOME environment variable to a valid JDK version, and/or add the java executable to your PATH"
      exit 1
    fi
    echo "      Java version is compatible with Bonita"
}


########################################################################################################################
# TOOLING
########################################################################################################################

detectWebPagesDependenciesVersions() {
    echoHeaders "Detecting web-pages dependencies versions"
    local webPagesGradleBuild=`curl -sS -X GET https://raw.githubusercontent.com/bonitasoft/bonita-web-pages/${BRANCH_OR_TAG}/common.gradle`

    WEB_PAGES_UID_VERSION=`echo "${webPagesGradleBuild}" | tr -s "[:blank:]" | tr -d "\n" | sed 's@.*UIDesigner {\(.*\)"}.*@\1@g' | sed 's@.*version "\(.*\)@\1@g'`
    echo "WEB_PAGES_UID_VERSION: ${WEB_PAGES_UID_VERSION}"
}

detectStudioDependenciesVersions() {
    echoHeaders "Detecting Studio dependencies versions"
    local studioPom=`curl -sS -X GET https://raw.githubusercontent.com/bonitasoft/bonita-studio/${BRANCH_OR_TAG}/pom.xml`

    STUDIO_UID_VERSION=`echo "${studioPom}" | grep \<ui.designer.version\> | sed 's@.*>\(.*\)<.*@\1@g'`
    echo "STUDIO_UID_VERSION: ${STUDIO_UID_VERSION}"
}



########################################################################################################################
# MAIN
########################################################################################################################
detectOS
logBuildInfo
checkPrerequisites
echo

# List of repositories on https://github.com/bonitasoft that you don't need to build
# Note that archived repositories are not listed here, as they are only required to build old Bonita versions
#
# angular-strap: automatically downloaded in the build of bonita-web project.
# babel-preset-bonita: automatically downloaded in the build of bonita-ui-designer project.
# bonita-codesign-windows: use to sign Windows binaries when building using Bonita Continuous Integration.
# bonita-connector-talend: deprecated.
# bonita-continuous-delivery-doc: Bonita Enterprise Edition Continuous Delivery module documentation.
# bonita-custom-page-seed: a project to start building a custom page. Deprecated in favor of UI Designer page + REST API extension.
# bonita-doc: Bonita documentation.
# bonita-developer-resources: guidelines for contributing to Bonita, contributor license agreement, code style...
# bonita-examples: Bonita usage code examples.
# bonita-ici-doc: Bonita Enterprise Edition AI module documentation.
# bonita-js-components: automatically downloaded in the build of projects that require it.
# bonita-migration: migration tool to update a server from a previous Bonita release.
# bonita-page-authorization-rules: documentation project to provide an example for page mapping authorization rule.
# bonita-connector-sap: deprecated. Use REST connector instead.
# bonita-vacation-management-example: an example for Bonita Enterprise Edition Continuous Delivery module.
# bonita-web-devtools: Bonitasoft internal development tools.
# bonita-widget-contrib: project to start building custom widgets outside UI Designer.
# create-react-app: required for Bonita Subscription Intelligent Continuous Improvement module.
# dojo: Bonitasoft R&D coding dojos.
# jscs-preset-bonita: Bonita JavaScript code guidelines.
# ngUpload: automatically downloaded in the build of bonita-ui-designer project.
# preact-chartjs-2: required for Bonita Subscription Intelligent Continuous Improvement module.
# preact-content-loader: required for Bonita Subscription Intelligent Continuous Improvement module.
# restlet-framework-java: /!\
# swt-repo: legacy repository required by Bonita Studio. Deprecated.
# training-presentation-tool: fork of reveal.js with custom look and feel.
# widget-builder: automatically downloaded in the build of bonita-ui-designer project.
# bonita-studio-watchdog: obsolete since 7.10 (included in bonita-studio).


if [[ "${BONITA_BUILD_STUDIO_ONLY}" == "false" ]]; then
    build_gradle_wrapper_test_skip_publishToMavenLocal bonita-engine

    build_maven_wrapper_install_skiptest bonita-web-extensions

    build_maven_wrapper_install_skiptest bonita-web
    build_maven_wrapper_install_skiptest bonita-portal-js

    # bonita-web-pages uses a dedicated UID version
    detectWebPagesDependenciesVersions
    build_maven_wrapper_install_skiptest bonita-ui-designer ${WEB_PAGES_UID_VERSION}
    build_gradle_wrapper_test_skip_publishToMavenLocal bonita-web-pages

    build_maven_wrapper_install_skiptest bonita-application-directory
    build_maven_wrapper_install_skiptest bonita-user-application
    build_maven_wrapper_install_skiptest_with_module bonita-admin-application bonita-admin-application
    build_maven_wrapper_install_skiptest bonita-super-admin-application

    build_maven_wrapper_install_skiptest bonita-distrib
else
    echoHeaders "Skipping all build prior the Studio part"
fi

if [[ "${BONITA_BUILD_STUDIO_SKIP}" == "false" ]]; then
    build_maven_wrapper_install_skiptest bonita-data-repository
    
    # bonita-studio uses a dedicated UID version
    detectStudioDependenciesVersions
    build_maven_wrapper_install_skiptest bonita-ui-designer ${STUDIO_UID_VERSION}
    
    build_maven_wrapper_verify_skiptest_with_profile bonita-studio default,all-in-one,!jdk11-tests
else
    echoHeaders "Skipping the Studio build"
fi
