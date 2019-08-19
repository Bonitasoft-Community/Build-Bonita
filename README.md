Build Bonita from sources
================

The script to build Bonita Engine, Portal and Studio from official sources
------------------------------------------------------------------------------

This script has been tested on Debian GNU/Linux Buster, with Oracle JDK 8 (⚠ you cannot use Java 11 to build Bonita), Maven 3.5.4.

Around 4 GB of dependencies will be downloaded (sources, Maven dependencies, ...). A fast internet connection is recommended.
Place this script in an empty folder on a disk partition with more than 15 GB free space.

Then, run `bash build-script.sh` in a terminal.

Once finished, you will find a working build of Bonita in: `bonita-studio/all-in-one/target`.


Requirements
------------

This script is designed for Linux Operating System. You are of course free to fork it for Windows or Mac.

Issues
------

If you face any issue with this build script please report it on the [build-bonita GitHub issues tracker](https://github.com/Bonitasoft-Community/Build-Bonita/issues).

You can also ask for help on [Bonita Community forum](https://community.bonitasoft.com/questions-and-answers).
