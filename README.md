# Build Bonita from sources

[![Linux build](https://img.shields.io/travis/Bonitasoft-Community/Build-Bonita/master?label=Linux%20build&logo=travis)](https://travis-ci.org/Bonitasoft-Community/Build-Bonita)

[![MacOS and Windows build](https://github.com/Bonitasoft-Community/Build-Bonita/workflows/MacOS%20and%20Windows%20Build/badge.svg)](https://github.com/Bonitasoft-Community/Build-Bonita/actions)


## Overview

A bash script is provided to build the whole Bonita Community Edition solution from sources publicly available.

It clones Git repositories and build all Bonita components in the right order to let you generate the Bonita Bundle and
the Bonita Studio.


## Requirements

- Disk space: around 15 GB free space. Around 4 GB of dependencies will be downloaded (sources, 3rd party dependencies,
...). A fast internet connection is recommended.
- OS: Linux, MacOS and Windows (see test environments list below)
- Maven: 3.6.x.
- Java: Oracle/OpenJDK Java 8 (⚠ you cannot use Java 11 to build Bonita).


## Instructions

1. Clone this repository
1. Checkout the [branch/tag](#branches-and-tags) related to the Bonita version you want to build
1. Run `bash build-script.sh` in a terminal (on Windows, use git-bash as terminal i.e. the bash shell included with Git for Windows)
1. Once finished, the following binaries are available
    1. Bonita Studio (aka Bonita Development Suite): `bonita-studio/all-in-one/target` (only zip archive, no installer)
    1. Bonita Bundle (aka Bonita Runtime): `bonita-distrib/tomcat/target`

**Notes**
- If you want to make 100% sure that you do a clean build from scratch, run the following commands:
```bash
rm -rf ~/.m2/repository/org/bonitasoft/
rm -rf ~/.m2/repository/.cache
rm -rf ~/.m2/repository/.meta
rm -rf ~/.gradle/caches
find -type d -name ".gradle" -prune -exec rm -rf {} \;
find -type d -name target -prune -exec rm -rf {} \;
```
- No tests are run by the script (at least no back end tests). If you want to run some tests, go to the directory
 related to the Bonita component you want to test, and follow instructions (generally available in README file)
- The script does not produce Studio installers (required license for proprietary software).


## Test environments

This script has been manually tested with the following environment:
- Debian GNU/Linux Buster
- Maven 3.6.0
- Oracle Java 1.8.0_221


In addition, CI builds are run on push to master/dev branches and Pull Requests (see badges on top of this page)
- Linux: Ubuntu Xenial (Travis CI)
- MacOS: Catalina (Github Actions)
- Windows: Windows Server 2019 DataCenter (Github Actions)


## Issues

If you face any issue with this build script or for any question, please report it on the [build-bonita GitHub issues tracker](https://github.com/Bonitasoft-Community/Build-Bonita/issues).

You can also ask for help on [Bonita Community forum](https://community.bonitasoft.com/questions-and-answers).


## <a name="branches-and-tags"></a> Branches and Tags

The use of `Build-Bonita` branch or tag depends of the Bonita version you want to build.

| Bonita version | Build-Bonita branch or tag |
| -------- | ----- |
| latest maintenance version | `master` branch |
| old version | related tag (see the [tags](#tags) section below) |
| next Bonita GA version | `dev` branch |

**Notes**
- `Build-Bonita` currently does not provide support for building Bonita SNAPSHOT versions aka next maintenance or
development versions. See [#41](https://github.com/Bonitasoft-Community/Build-Bonita/issue/41) for such a support


### Branches

`Build-Bonita` uses the same branch names as the Bonita repositories
- `master` for latest available GA or maintenance version. It also contains latest build improvements related to the
solution provided by `Build-Bonita`
- `dev` for next Bonita version while developments are in progress


### Tags

Tags are only available to build Bonita GA (i.e. 7.9.0, 7.10.0, ....) or maintenance (i.e. 7.7.5, 7.9.4, ....) versions,
not for development versions.

### Tag scheme
- prior Bonita 7.10, `Build-Bonita` tags exactly match the Bonita version
- as of Bonita 7.10, tags use the `<bonita_version>-<increment>` like `7.10.0-1`. This allows to track improvements or
bug fixes applied to `Build-Bonita` for a given Bonita version

Examples

| Bonita version | Build-Bonita tag |
| -------- | ----- |
| 7.10.1 | 7.10.1-1, 7.10.1-2, .... |
| 7.10.0 | 7.10.0-1, 7.10.0-2, .... |
| 7.9.4 | 7.9.4 |
| 7.7.5 | 7.7.5 |


# Developing on Build-Bonita

The following is for contributors to this repository.

Notice that a lot of actions are manual, so if it's becoming boring for you, fill an issue to discuss about it, then
provide a Pull Request to automate this and simplify our life

## Add support for a new version

Notice that most of the actions described below can be done directly using the GitHub website, for instance
- file edition
- branch and pull request creation

See [GitHub help](https://help.github.com/en/github/managing-files-in-a-repository/editing-files-in-your-repository) for
more details

### Bonita maintenance version

- create a new branch starting from the `master` branch, for instance `maintenance_7.10.2`
- update the `build-script.sh` file and update the `BONITA_VERSION` variable
- [create a Pull Request](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request) targeting the `master`
- wait for build to pass, this should work without any other modifications
- [merge the Pull Request](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/merging-a-pull-request) after successful build


### Bonita development version

- create a new branch starting from the `dev` branch, for instance `dev_7.11.0.W10`
- update the `build-script.sh` file and update the `BONITA_VERSION` variable
- [create a Pull Request](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request) targeting the `dev` branch
- wait for build to run
- failures often happen because of new components to be added or removed, build options of some components to be updated
  - try to fix, then commit and iterate until build pass
  - see [#32](https://github.com/Bonitasoft-Community/Build-Bonita/pull/32) or
  [#48](https://github.com/Bonitasoft-Community/Build-Bonita/pull/48) for instance
- [merge the Pull Request](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/merging-a-pull-request) after successful build


### Merging master and dev branches

Follow the same lifecycle as Bonita component repositories. Merge are currently done manually by `Build-Bonita`
contributors
- `master` --> `dev`: all the time, especially after adding support for a new maintenance version. Allow to get new
improvements applied to maintenance versions, avoid subsequent merge conflicts, ...
- `dev` --> `master`: on GA release, `master` is going to become the maintenance branch for the new Bonita released
version. It is highly advised to do the merge in a dedicated branch as some issue occurred at that stage in the past
  - first, ensure that `master` has been merged into`dev`
  - create a new `bonita_7.10.0_GA` branch starting from `master` branch
  - merge `dev` into `bonita_7.10.0_GA`
  - [create a Pull Request](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request) from `bonita_7.10.0_GA` targeting the `master` branch
  - [merge the Pull Request](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/merging-a-pull-request) into `master` when the build passed (eventually after fixing any issues related to the merge)


## New Release

Release are cut when
- a new Bonita version (GA or maintenance) is supported by `Build-Bonita`
- significant improvements have been made in the `Build-Bonita` build script for the latest supported Bonita version

### Create Tag
**Note**: automation request, see [#49](https://github.com/Bonitasoft-Community/Build-Bonita/issues/49)

First, ensure that build to pass on the `master` branch

Run the following command from your shell
- checkout the `master` branch: `git checkout master`
- ensure it is up to date with the remote: `git pull --tags`
- create the local tag (use the [tag scheme](#tag-scheme)): `git tag <tag_name>`
- push the tag to the remote repository: `git push origin <tag_name>`
- check that the tag is [available on GitHub](https://github.com/Bonitasoft-Community/Build-Bonita/tags)

### Create a GitHub release

- 1st create a tag (see above)
- create the new release related to the tag following the [GitHub help](https://help.github.com/en/github/administering-a-repository/managing-releases-in-a-repository)
