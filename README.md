# Build Bonita from sources

[![Build](https://github.com/Bonitasoft-Community/Build-Bonita/workflows/Build/badge.svg)](https://github.com/Bonitasoft-Community/Build-Bonita/actions)


## Overview

A bash script is provided to build the whole Bonita Community Edition solution from sources publicly available.

It clones Git repositories and build all Bonita components in the right order to let you generate the Bonita Bundle and
the Bonita Studio.


## Requirements

- Disk space: around 15 GB free space. Around 4 GB of dependencies will be downloaded (sources, 3rd party dependencies,
...). A fast internet connection is recommended.
- OS: Linux, MacOS and Windows (see test environments list below)
- Java: OpenJDK Java 11


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

CI builds are run on push to master/dev branches and Pull Requests (see badges on top of this page) on GitHub Actions
- Linux: Ubuntu 20.04
- MacOS: Catalina
- Windows: Windows Server 2019 DataCenter


## Issues

If you face any issue with this build script or for any question, please report it on the [build-bonita GitHub issues tracker](https://github.com/Bonitasoft-Community/Build-Bonita/issues).

You can also ask for help on [Bonita Community forum](https://community.bonitasoft.com/questions-and-answers).

## Github Action

### Build action

The build action is triggered on Pull requests and `master` branch pushes.  
It runs the `build-script.sh` on the 3 supported OS:

* Ubuntu
* Windows
* MacOs

### Artifact retention

Built binaries are uploaded as action _Artifacts_ and kept **90 days**.

## <a name="branches-and-tags"></a> Branches and Tags

The use of `Build-Bonita` branch or tag depends of the Bonita version you want to build.

| Bonita version | Build-Bonita branch or tag |
| -------- | ----- |
| Next Bonita GA version | `master` branch |
| Old versions | related tag (see the [tags](#tags) section below) |

**Notes**
- `Build-Bonita` currently does not provide support for building Bonita SNAPSHOT versions aka next maintenance or
development versions. See [#41](https://github.com/Bonitasoft-Community/Build-Bonita/issue/41) for such a support


### Branches

`Build-Bonita` uses the same branch names as the Bonita repositories
- `master` branch build the current development version aka `dev` branch.


### Tags

Tags are only available to build Bonita GA (i.e. 7.9.0, 7.10.0, ....) versions,
not for development versions.

### <a name="tag-scheme"></a> Tag scheme
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


## New Release

Release are cut when
- a new Bonita GA version is supported by `Build-Bonita`
- significant improvements have been made in the `Build-Bonita` build script for the latest supported Bonita version

### Create a GitHub release

A new release can be create using the [Create release action](https://github.com/Bonitasoft-Community/Build-Bonita/actions/workflows/release.yml)

