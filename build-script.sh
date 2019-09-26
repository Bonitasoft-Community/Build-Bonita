#/bin/bash

set -u
set -e
set +o nounset


# If you want to make 100% sure that you do a clean build from scratch:
# rm -rf ~/.m2/repository/org/bonitasoft/
# rm -rf ~/.gradle/caches
# rm -rf .gradle in the folder where the script is located

# Workaround for at least Debian Buster
# Require to build bonita-portal-js due to issue with PhantomJS launched by Karma
# See https://github.com/ariya/phantomjs/issues/14520
export OPENSSL_CONF=/etc/ssl

# Script configuration
# You can set the following environment variables
# SCRIPT_BUILD_NO_CLEAN=true
# SCRIPT_BUILD_QUIET=true

# Bonita version
BONITA_BPM_VERSION=7.9.2

# Bonita Studio p2 public repository
STUDIO_P2_URL=http://update-site.bonitasoft.com/p2/4.10

# FIXME: remove when temporary workaround become useless
STUDIO_P2_URL_INTERNAL_TO_REPLACE=http://repositories.rd.lan/p2/4.10.1

# Test that x server is running. Required to generate Bonita Studio models
# Can be ignored if Studio is build without the "generate" Maven profile
# Warning: this requirement prevents to build on Travis CI
if ! xset q &>/dev/null; then
	echo "No X server at \$DISPLAY [$DISPLAY]" >&2
	exit 1
fi

# Test that Maven exists
# FIXME: remove once all projects includes Maven wrapper
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


########################################################################################################################
# SCM AND BUILD FUNCTIONS
########################################################################################################################

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

	if [ "$#" -ge 2 ]; then
		tag_name="$2"
	else
		# If we don't have a tag name assume that the tag is named with the Bonita version
		tag_name=$BONITA_BPM_VERSION
	fi
	echo "============================================================"
	echo "Processing ${repository_name} ${tag_name}"
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
	git -C $checkout_folder_name reset --hard tags/$tag_name

	# Move to the repository clone folder (required to run Maven/Gradle wrapper)
	cd $checkout_folder_name

	# Workarounds
	# FIXME: remove connector workaround for 7.9.3 release
	if [[ "$repository_name" == "bonita-connector-database" ]]; then
	  echo "WARN: workaround on $repository_name to remove Oracle JDBC dependency not available on public repositories"
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
	# FIXME: remove workaround when bonita-web-pages no longer includes dependencies on internal tooling
	if [[ "$repository_name" == "bonita-web-pages" ]]; then
	  echo "WARN: workaround on $repository_name - remove bonitasoft internal gradle plugin"
	  cp ./../workarounds/bonita-web-pages_build.gradle ./build.gradle
	fi
	# FIXME: remove temporary workaround added to make sure that we use public repository (Bonita internal tracker issue id: BST-463)
	# Issue is related to Tycho target-platform-configuration plugin that rely on the artifact org.bonitasoft.studio:platform.
	# The artifact include Ant Maven plugin to update the platform.target file but it is not executed before Tycho is executed and read the incorrect URL.
	if [[ "$repository_name" == "bonita-studio" ]]; then
		echo "WARN: workaround on $repository_name - fix platform.target URL"
		sed -i "s,${STUDIO_P2_URL_INTERNAL_TO_REPLACE},${STUDIO_P2_URL},g" platform/platform.target
	fi
}

run_maven_with_standard_system_properties() {
	build_command="$build_command -Dbonita.engine.version=$BONITA_BPM_VERSION -Dp2MirrorUrl=${STUDIO_P2_URL}"
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

maven_test_skip() {
	build_command="$build_command -Dmaven.test.skip=true"
}

# FIXME: should not be used
# Needed due to https://issues.apache.org/jira/browse/MJAR-138
# Will be fixed once https://github.com/bonitasoft/bonita-web-sp/pull/512 merged
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

# FIXME: should not be used, see comment on skiptest function
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
	# FIXME: remove temporary workaround when https://github.com/bonitasoft/bonita-ui-designer-sp/pull/2773 will be part of an official release
	chmod u+x mvnw
	build_maven_wrapper
	build_quiet_if_requested
	clean
	install  
	maven_test_skip
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



########################################################################################################################
# TOOLING
########################################################################################################################

detectStudioDependenciesVersions() {
	echo "Detecting dependencies versions"
	local studioPom=`curl -sS -X GET https://raw.githubusercontent.com/bonitasoft/bonita-studio/${BONITA_BPM_VERSION}/pom.xml`

	STUDIO_UID_VERSION=`echo "${studioPom}" | grep ui.designer.version | sed 's@.*>\(.*\)<.*@\1@g'`
	STUDIO_WATCHDOG_VERSION=`echo "${studioPom}" | grep watchdog.version | sed 's@.*>\(.*\)<.*@\1@g'`

	echo "STUDIO_UID_VERSION: ${STUDIO_UID_VERSION}"
	echo "STUDIO_WATCHDOG_VERSION: ${STUDIO_WATCHDOG_VERSION}"
}


########################################################################################################################
# MAIN
########################################################################################################################

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
# sandbox: a sandbox for developers /!\ (private ?)
# swt-repo: legacy repository required by Bonita Studio. Deprecated.
# training-presentation-tool: fork of reveal.js with custom look and feel.
# widget-builder: automatically downloaded in the build of bonita-ui-designer project.




build_gradle_wrapper_test_skip_publishToMavenLocal bonita-engine

build_maven_wrapper_install_maven_test_skip bonita-userfilters

build_maven_wrapper_install_maven_test_skip bonita-web-extensions
# FIXME: see comments on skiptest function
build_maven_install_skiptest bonita-web
build_maven_install_maven_test_skip bonita-portal-js

# bonita-web-pages is build using a specific version of UI Designer.
# Version is defined in https://github.com/bonitasoft/bonita-web-pages/blob/$BONITA_BPM_VERSION/build.gradle
build_maven_wrapper_install_maven_test_skip bonita-ui-designer 1.9.53
# FIXME: see pull request to fix the issue: https://github.com/bonitasoft/bonita-ui-designer-sp/pull/2774
build_gradle_wrapper_test_skip_publishToMavenLocal bonita-web-pages

build_maven_wrapper_install_maven_test_skip bonita-distrib

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
build_maven_install_maven_test_skip bonita-connector-rest 1.0.6
build_maven_install_maven_test_skip bonita-connector-salesforce 1.1.2
build_maven_install_maven_test_skip bonita-connector-scripting 1.1.0
build_maven_install_maven_test_skip bonita-connector-twitter 1.2.0
build_maven_install_maven_test_skip bonita-connector-webservice 1.2.2


detectStudioDependenciesVersions
build_maven_install_maven_test_skip bonita-studio-watchdog studio-watchdog-${STUDIO_WATCHDOG_VERSION}
# Version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/pom.xml
build_maven_wrapper_install_maven_test_skip image-overlay-plugin image-overlay-plugin-1.0.8
build_maven_wrapper_install_maven_test_skip bonita-ui-designer ${STUDIO_UID_VERSION}

build_maven_wrapper_verify_maven_test_skip_with_profile bonita-studio mirrored,generate
