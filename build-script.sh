#/bin/bash

set -u
set -e

# Script configuration
# you can set the following environment variables
# SCRIPT_BUILD_NO_CLEAN=true
# SCRIPT_BUILD_QUIET=true

# Bonita version
BONITA_BPM_VERSION=7.9.2
STUDIO_P2_URL=http://update-site.bonitasoft.com/p2/4.10
STUDIO_P2_URL_INTERNAL_TO_REPLACE=http://repositories.rd.lan/p2/4.10.1

# Test that x server is running. Required to generate Bonita Studio models
# Can be ignored if Studio is build without the "generate" Maven profile
# Temp disable this as it prevents to build on Travis CI
# if ! xset q &>/dev/null; then
    # echo "No X server at \$DISPLAY [$DISPLAY]" >&2
    # exit 1
# fi

# Test that Maven exists
if hash mvn 2>/dev/null; then
  MAVEN_VERSION="$(mvn --version 2>&1 | awk -F " " 'NR==1 {print $3}')"
  echo Using Maven version: "$MAVEN_VERSION"
else
  echo Maven not found. Exiting.
  exit 1
fi

# Test if Curl exists
if hash curl 2>/dev/null; then
  CURL_VERSION="$(curl --version 2>&1  | awk -F " " 'NR==1 {print $2}')"
  echo Using curl version: "$CURL_VERSION"
else
  echo curl not found. Exiting.
  exit 1
fi


# Detect version of depencies required to build Bonita components in Maven pom.xml files
detectDependenciesVersions() {
  echo "Detecting Studio dependencies versions"
  local studioPom=`curl -sS -X GET https://raw.githubusercontent.com/bonitasoft/bonita-studio/${BONITA_BPM_VERSION}/pom.xml`

  UID_VERSION=`echo "${studioPom}" | grep ui.designer.version | sed 's@.*>\(.*\)<.*@\1@g'`
  STUDIO_WATCHDOG_VERSION=`echo "${studioPom}" | grep watchdog.version | sed 's@.*>\(.*\)<.*@\1@g'`

  echo "UID_VERSION: ${UID_VERSION}"
  echo "STUDIO_WATCHDOG_VERSION: ${STUDIO_WATCHDOG_VERSION}"
}

# TODO store linearized pom in a variable
# TODO do not depend on subsequent comment about connector name to detect version (too fragile)
detectConnectorsVersions() {
  echo "Detecting Connectors versions"
  local studioPom=`curl -sS -X GET https://raw.githubusercontent.com/bonitasoft/bonita-studio/$BONITA_BPM_VERSION/bundles/plugins/org.bonitasoft.studio.connectors/pom.xml`
#  echo "${studioPom}" | tr --squeeze-repeats "[:blank:]" | tr --delete "\n"
#  local linearizedStudioPom=`echo "${studioPom}" | tr --squeeze-repeats "[:blank:]" | tr --delete "\n" | echo`
#  echo "linearized ${linearizedStudioPom}"

  CONNECTOR_VERSION_ALFRESCO=`echo "${studioPom}" | tr --squeeze-repeats "[:blank:]" | tr --delete "\n" | sed 's@.*<artifactId>bonita-connector-alfresco</artifactId> <version>\(.*\)</version>.*<!--CMIS CONNECTORS.*@\1@g'`
  echo "CONNECTOR_VERSION_ALFRESCO: ${CONNECTOR_VERSION_ALFRESCO}"

  CONNECTOR_VERSION_CMIS=`echo "${studioPom}" | tr --squeeze-repeats "[:blank:]" | tr --delete "\n" | sed 's@.*<artifactId>bonita-connector-cmis</artifactId> <version>\(.*\)</version>.*<!--DATABASE CONNECTORS.*@\1@g'`
  echo "CONNECTOR_VERSION_CMIS: ${CONNECTOR_VERSION_CMIS}"

  CONNECTOR_VERSION_DATABASE=`echo "${studioPom}" | tr --squeeze-repeats "[:blank:]" | tr --delete "\n" | sed 's@.*<artifactId>bonita-connector-database</artifactId> <version>\(.*\)</version>.*<!--EMAIL CONNECTOR..*@\1@g'`
  echo "CONNECTOR_VERSION_DATABASE: ${CONNECTOR_VERSION_DATABASE}"

  CONNECTOR_VERSION_EMAIL=`echo "${studioPom}" | tr --squeeze-repeats "[:blank:]" | tr --delete "\n" | sed 's@.*<artifactId>bonita-connector-email</artifactId> <version>\(.*\)</version>.*<!--GOOGLE CALENDAR CONNECTOR.*@\1@g'`
  echo "CONNECTOR_VERSION_EMAIL: ${CONNECTOR_VERSION_EMAIL}"


  CONNECTOR_VERSION_REST=`echo "${studioPom}" | tr --squeeze-repeats "[:blank:]" | tr --delete "\n" | sed 's@.*<artifactId>bonita-connector-rest</artifactId> <version>\(.*\)</version>.*@\1@g'`
  echo "CONNECTOR_VERSION_REST: ${CONNECTOR_VERSION_REST}"
}

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
# bonita-platform: deprecated, now part of bonita-engine repository.
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
# sandbox: a sandbox for developers /!\ (private ?)
# swt-repo: legacy repository required by Bonita Studio. Deprecated.
# training-presentation-tool: fork of reveal.js with custom look and feel.
# widget-builder: automatically downloaded in the build of bonita-ui-designer project.

# params:
# - Git repository name
# - Branch name (optional)
# - Checkout folder name (optional)
checkout() {
  if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
     echo "Incorrect number of parameters: $@"
     exit 1
  fi

  repository_name="$1"
  
  if [ "$#" -ge 2 ]; then
    branch_name="$2"
  else
    branch_name=$BONITA_BPM_VERSION
  fi
  echo "============================================================"
  echo "Processing ${repository_name} ${branch_name}"
  echo "============================================================"

  if [ "$#" -eq 3 ]; then
    checkout_folder_name="$3"
  else
    # If no checkout folder path is provided use the repository name as destination folder name
    checkout_folder_name="$repository_name"
  fi
  
  # If we don't already clone the repository do it
  if [ ! -d "$checkout_folder_name/.git" ]; then
    git clone "https://github.com/bonitasoft/$repository_name.git" $checkout_folder_name
  fi
  # Ensure we fetch all the tags and that we are on the appropriate one
  git -C $checkout_folder_name fetch --tags
  git -C $checkout_folder_name reset --hard tags/$branch_name
  
  # Move to the repository clone folder (required to run Maven wrapper)
  cd $checkout_folder_name

  # Workarounds
  if [[ "$repository_name" == "bonita-connector-database" ]]; then
    echo "WARN: workaround on $repository_name to remove oracle jdbc dependency not available on public repositories"
    cp ./../workarounds/bonita-connector-database_pom.xml ./pom.xml
  fi
  if [[ "$repository_name" == "bonita-connector-email" ]]; then
    echo "WARN: workaround on $repository_name to fix dependency on bonita-engine SNAPSHOT version"
    sed -i 's,<version>7.9.0-SNAPSHOT</version>,<version>${bonita.engine.version}</version>,g' pom.xml
  fi
  if [[ "$repository_name" == "bonita-connector-webservice" ]]; then
    echo "WARN: workaround on $repository_name to fix dependency on bonita-engine SNAPSHOT version and missing versions for some dependencies"
    cp ./../workarounds/bonita-connector-webservices_pom.xml ./pom.xml
  fi
  if [[ "$repository_name" == "bonita-web-pages" ]]; then
    echo "WARN: workaround on $repository_name - remove bonitasoft internal gradle plugin"
    cp ./../workarounds/bonita-web-pages_build.gradle ./build.gradle
  fi
  if [[ "$repository_name" == "bonita-studio" ]]; then
    echo "WARN: workaround on $repository_name - fix platform.target url"
    # FIXME: remove temporary workaround added to make sure that we use public repository
    # Issue is related to Tycho target-platform-configuration plugin that rely on the artifact org.bonitasoft.studio:platform that is not built
    sed -i 's,${STUDIO_P2_URL_INTERNAL_TO_REPLACE},${STUDIO_P2_URL},g' platform/platform.target
  fi
}

run_maven_with_standard_system_properties() {
  build_command="$build_command -Dbonita.engine.version=$BONITA_BPM_VERSION -Dp2MirrorUrl=${STUDIO_P2_URL}"
  eval "$build_command"
  # Go back to script folder (checkout move current directory to project checkout folder.
  cd ..
}

run_gradle_with_standard_system_properties() {
  eval "$build_command"
  # Go back to script folder (checkout move current directory to project checkout folder.
  cd ..
}

build_maven() {
  build_command="mvn"
}

build_maven_wrapper() {
  build_command="./mvnw"
}

build_gradle_wrapper() {
  build_command="./gradlew"
}

build_quiet_if_requested() {
  if [[ "${SCRIPT_BUILD_QUIET}" == "true" ]]; then
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
  if [[ "${SCRIPT_BUILD_NO_CLEAN}" == "true" ]]; then
    echo "Configure build to skip clean"
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

maven_test_skip() {
  build_command="$build_command -Dmaven.test.skip=true"
}

# FIXME: should not be used
skiptest() {
  build_command="$build_command -DskipTests"
}

gradle_test_skip() {
  build_command="$build_command -x test"
}

profile() {
  build_command="$build_command -P$1"
}

# params:
# - Git repository name
# - Branch name (optional)
build_maven_install_maven_test_skip() {
  checkout "$@"
  build_maven
  build_quiet_if_requested
  clean
  install
  maven_test_skip
  run_maven_with_standard_system_properties
}

# FIXME: should not be used
# params:
# - Git repository name
# - Branch name (optional)
build_maven_install_skiptest() {
  checkout "$@"
  build_maven
  build_quiet_if_requested
  clean
  install
  skiptest
  run_maven_with_standard_system_properties
}

# params:
# - Git repository name
# - Profile name
build_maven_wrapper_verify_maven_test_skip_with_profile()
{
  checkout $1
  build_maven_wrapper
  build_quiet_if_requested
  clean
  verify
  maven_test_skip
  profile $2
  run_maven_with_standard_system_properties
}

# params:
# - Git repository name
build_maven_wrapper_install_maven_test_skip()
{
  checkout "$@"
  build_maven_wrapper
  build_quiet_if_requested
  clean
  install  
  maven_test_skip
  run_maven_with_standard_system_properties
}

build_gradle_build() {
  checkout "$@"
  build_gradle_wrapper
  build_quiet_if_requested
  clean
  gradle_test_skip
  publishToMavenLocal
  run_gradle_with_standard_system_properties
}

# 1s detect the versions of dependencies that will be built prior to build the Bonita Components
detectDependenciesVersions


build_gradle_build bonita-engine

build_maven_wrapper_install_maven_test_skip bonita-userfilters

# Each connectors implementation version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/bundles/plugins/org.bonitasoft.studio.connectors/pom.xml.
# For the version of bonita-connectors refers to one of the included connector and use the parent project version (parent project should be bonita-connectors).
# You need to find connector git repository tag that provides a given connector implementation version.
build_maven_install_maven_test_skip bonita-connectors 1.0.0

build_maven_install_maven_test_skip bonita-connector-alfresco 2.0.1

build_maven_install_maven_test_skip bonita-connector-cmis 3.0.3

build_maven_install_maven_test_skip bonita-connector-database 2.0.0

build_maven_install_maven_test_skip bonita-connector-email 1.1.0

build_maven_install_maven_test_skip bonita-connector-googlecalendar-V3 bonita-connector-google-calendar-v3-1.0.0

build_maven_install_maven_test_skip bonita-connector-ldap bonita-connector-ldap-1.0.1

build_maven_install_maven_test_skip bonita-connector-rest 1.0.5

build_maven_install_maven_test_skip bonita-connector-salesforce 1.1.2

build_maven_install_maven_test_skip bonita-connector-scripting 1.1.0

build_maven_install_maven_test_skip bonita-connector-twitter 1.2.0

build_maven_install_maven_test_skip bonita-connector-webservice 1.2.2

# Version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/pom.xml
build_maven_install_maven_test_skip bonita-studio-watchdog studio-watchdog-${STUDIO_WATCHDOG_VERSION}

# bonita-web-pages is build using a specific version of UI Designer.
# Version is defined in https://github.com/bonitasoft/bonita-web-pages/blob/$BONITA_BPM_VERSION/build.gradle
# FIXME: this will be removed in future release as the same version as the one package in the release will be used.
build_maven_install_skiptest bonita-ui-designer 1.9.53

build_gradle_build bonita-web-pages

# This is the version of the UI Designer embedded in Bonita release
# Version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/pom.xml
build_maven_install_skiptest bonita-ui-designer ${UID_VERSION}

build_maven_install_maven_test_skip bonita-web-extensions

build_maven_install_skiptest bonita-web

build_maven_install_maven_test_skip bonita-portal-js

build_maven_install_maven_test_skip bonita-distrib

# Version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/pom.xml
build_maven_install_maven_test_skip image-overlay-plugin image-overlay-plugin-1.0.8

build_maven_wrapper_verify_maven_test_skip_with_profile bonita-studio mirrored,generate
