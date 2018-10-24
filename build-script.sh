#/bin/bash

set -u
set -e

# Bonita version
BONITA_BPM_VERSION=7.7.2

# Test that Mavene exists
if hash mvn 2>/dev/null; then
  MAVEN_VERSION="$(mvn --version 2>&1 | awk -F " " 'NR==1 {print $3}')"
  echo Using Maven version: "$MAVEN_VERSION"
else
  echo Maven not found. Exiting.
  exit 1
fi

# Get the location of Tomcat and WildFly zip files as script argument or ask the user
# Fro version 7.7.2: apache-tomcat-8.5.31.zip and wildfly-10.1.0.Final.zip
if [ "$#" -eq 1 ]; then
  AS_DIR_PATH=$1
else
  read -p "Provide path to folder that contains Tomcat and WildFly zip file: " AS_DIR_PATH
fi

# Check that folder exists
if [ ! -d $AS_DIR_PATH ]; then
  echo Folder not found: "$AS_DIR_PATH"
  exit 1
fi

# List of repositories on https://github.com/bonitasoft that you don't need to build:
#
# angular-strap: automatically downloaded in the build of bonita-web project.
# babel-preset-bonita: automatically downloaded in the build of bonita-ui-designer project.
# bonita-branding: used to be required by Bonita Studio. Deprecated.
# bonita-codesign-windows: use to sign Windows binaries when building using Bonita Continuous Integration.
# bonita-connector-drools: Drools connector is not included in an official release.
# bonita-connector-googlecalendar: deprecated replaced by bonita-connector-googlecalendar-V3.
# bonita-connector-mongodb: not released.
# bonita-connector-sugarcrm: deprecated.
# bonita-connector-talend: deprecated.
# bonita-connectors-assembly: previous solution to build connectors in Bonita Studio 6. Deprecated.
# bonita-connectors-packaging: previous solution to build connectors in Bonita Studio 6. Deprecated.
# bonita-continuous-delivery-doc: Bonita Enterprise Edition Continuous Delivery module documentation.
# bonita-custom-page-seed: a project to start building a custom page. Deprecated in favor of UI Designer page + REST API extension.
# bonita-doc: Bonita documentation.
# bonita-developer-resources: guidelines for contributing to Bonita, contributor license agreement, code style...
# bonita-examples: Bonita usage code examples.
# bonita-gwt-tools: deprecated.
# bonita-ici-doc: Bonita Enterprise Edition AI module documentation.
# bonita-jboss-h2-mbean: JBoss has been replaced by WildFly.
# bonita-js-components: automatically downloaded in the build of projects that require it.
# bonita-migration: migration tool to update a server from a previous Bonita release.
# bonita-migration-plugins: archive repository, code now in bonita-migration repository.
# bonita-page-authorization-rules: documentation project to provide an example for page mapping authorization rule.
# bonita-platform: deprecated, now part of bonita-engine repository.
# bonita-connector-sap: deprecated. Use REST connector instead.
# bonita-simulation: deprecated.
# bonita-tomcat-h2-listener: h2 is now launched in an independent JVM.
# bonita-tomcat-valve: deprecated, was useful for JBoss bundle embedded Tomcat.
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
# tomcat-atomikos: experimentation with a different transaction manager on Tomcat. Not part of an official release.
# tomcat-narayana: experimentation with a different transaction manager on Tomcat. Not part of an official release.
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
    
  if [ "$#" -eq 3 ]; then
    checkout_folder_name="$3"
  else
    # If no checkout folder path is provided use the repository name as destination folder name
    checkout_folder_name="$repository_name"
  fi
  
  # If repository already cloned run git pull, else clone it
  git -C $checkout_folder_name pull || git clone --branch $branch_name --single-branch "https://github.com/bonitasoft/$repository_name.git" $checkout_folder_name
  
  # Move to the repository clone folder (required to run Maven wrapper)
  cd $checkout_folder_name
}

run_maven_with_standard_system_properties() {
  build_command="$build_command -Dbonita.engine.version=$BONITA_BPM_VERSION -Dwildfly.zip.parent.folder=$AS_DIR_PATH -Dtomcat.zip.parent.folder=$AS_DIR_PATH -Dp2MirrorUrl=http://update-site.bonitasoft.com/p2/7.7"
  eval "$build_command"
  # Go back to script folder (checkout move current dirrectory to project checkout folder.
  cd ..
}

build_maven() {
  build_command="mvn"
}

build_maven_wrapper() {
  # FIXME: remove temporary workaround added for bonita-web
  chmod u+x mvnw
  build_command="./mvnw"
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

skiptest() {
  build_command="$build_command -DskipTests"
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
  verify
  maven_test_skip
  profile $2
  run_maven_with_standard_system_properties
}

# params:
# - Git repository name
# - Target directory name
# - Profile name
build_maven_wrapper_install_maven_test_skip_with_target_directory_with_profile()
{
  checkout $1 $BONITA_BPM_VERSION $2
  build_maven_wrapper
  install  
  maven_test_skip
  profile $3
  run_maven_with_standard_system_properties
}


# Note: Checkout folder of bonita-engine project need to be named community.
build_maven_wrapper_install_maven_test_skip_with_target_directory_with_profile bonita-engine community tests,javadoc

build_maven_install_maven_test_skip bonita-userfilters

# Each connectors implementation version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/bundles/plugins/org.bonitasoft.studio.connectors/pom.xml.
# For the version of bonita-connectors refers to one of the included connector and use the parent project version (parent project should be bonita-connectors).
# You need to find connector git repository tag that provides a given connector implementation version.
build_maven_install_maven_test_skip bonita-connector-alfresco 2.0.1

build_maven_install_maven_test_skip bonita-connector-cmis 3.0.1

build_maven_install_maven_test_skip bonita-connector-database 1.2.2

build_maven_install_maven_test_skip bonita-connector-email bonita-connector-email-impl-1.0.15

build_maven_install_maven_test_skip bonita-connector-googlecalendar-V3 bonita-connector-google-calendar-v3-1.0.0

build_maven_install_maven_test_skip bonita-connector-ldap bonita-connector-ldap-1.0.1

build_maven_install_maven_test_skip bonita-connector-rest 1.0.4

build_maven_install_maven_test_skip bonita-connector-salesforce 1.0.14

build_maven_install_maven_test_skip bonita-connector-scripting bonita-connector-scripting-20151015

build_maven_install_maven_test_skip bonita-connector-twitter 1.1.0-pomfixed

build_maven_install_maven_test_skip bonita-connector-webservice 1.1.1

# Version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/pom.xml.
build_maven_install_maven_test_skip bonita-theme-builder 1.1.0

# Version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/pom.xml.
build_maven_install_maven_test_skip bonita-studio-watchdog studio-watchdog-7.2.0

build_maven_install_maven_test_skip bonita-web-extensions

build_maven_install_skiptest bonita-web

build_maven_install_maven_test_skip bonita-portal-js
 
# Version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/pom.xml
build_maven_install_skiptest bonita-ui-designer 1.7.59

build_maven_install_maven_test_skip bonita-distrib

# Version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/pom.xml
build_maven_install_maven_test_skip image-overlay-plugin image-overlay-plugin-1.0.4

build_maven_wrapper_verify_maven_test_skip_with_profile bonita-studio mirrored,generate
