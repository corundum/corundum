<!--
# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2018-2019 Missing Link Electronics, Inc.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
################################################################################
##
##  File Name      : README.md
##  Initial Author : Stefan Wiehler <stefan.wiehler@missinglinkelectronics.com>
##
################################################################################
-->

# Processing System Makefiles

This repository bundles convenience Makefiles for developing software targeting
the embedded processors of SoC FPGAs or soft cores embedded in a programmable
logic (PL) design – so called Processing Systems (PS). It features the
following components:

* PetaLinux wrapper Makefile
* Xilinx Software Development Kit (XSDK) convenience Makefile
* Xilinx Vitis convenience Makefile


## PetaLinux Wrapper Makefile

`petalinux.mk` is a Makefile for PetaLinux projects. It acts as convenience
wrapper script around the PetaLinux toolchain and adds additional
functionality.


### Supported Platforms

PetaLinux is supported from v2018.1 to v2019.1 (i.e. the last four releases).
The Makefile should run on all underlying OSs supported by PetaLinux; however
testing is only conducted on Ubuntu 18.04 LTS (Bionic Beaver) as of now.


### Setup

In your PetaLinux project directory, create a symlink named `Makefile` to the
`petalinux.mk` file:

    $ ln -s <path-to-your-psmake-repo>/petalinux.mk Makefile

Then, execute:

    $ make HDF=<path-to-your-.hdf-or-.xsa-file>

to import a Hardware Description File (HDF) or a XSA file and build the
PetaLinux project.


### Usage

The following Makefile targets are provided:

`gethdf`
: Initialize the project with a Hardware Description File (HDF) or a XSA
file. You must provide a HDF or XSA file via the `HDF` variable.

`config`
: Configure system-level options.

`config-kernel`
: Configure the Linux kernel.

`config-rootfs`
: Configure the root filesystem.

`build` (default)
: Build the system.

`sdk`
: Build the Software Development Kit (SDK).

`package-boot`
: Package boot image. You can provide different binaries from the default ones
for bitstream, FSBL, ATF, PMU firmware and U-Boot via the `BIT`, `FSBL`, `ATF`,
`PMUFW` and `UBOOT` variables, respectively. To skip packaging bitstream, FSBL,
ATF or PMU firmware, set the respective variable to `no`. Additional boot
arguments can be specified with `BOOT_ARG_EXTRA`; run `petalinux-package --boot
--help` for a list of options. The output path can be changed with the `BOOT`
variable.

`package-prebuilt`
: Copy built artifacts to pre-built directory.

`package-bsp`
: Package Board Support Package (BSP). The BSP file name must be given with the
`BSP` variable.

`dts`
: Decompile the device tree.

`reset-jtag`
: Reset board via JTAG. The hardware server URL must be provided via the
`HW_SERVER_URL` variable.

`boot-jtag-u-boot`
: Boot board into U-Boot via JTAG. The hardware server URL must be provided via
the `HW_SERVER_URL` variable.

`boot-jtag-kernel`
: Boot board and upload Linux kernel via JTAG. The hardware server URL must be
provided via the `HW_SERVER_URL` variable.

`boot-jtag-psinit-uboot`
: Boot board into U-Boot via JTAG, but run `ps*_init.tcl` script instead of
downloading and running FSBL. This can be inconvenient if the FSBL is doing
boot mode specific jobs, e.g. loading a boot image from QSPI flash memory when
in QSPI boot mode, although one does NOT want the FSBL to do that.  The
hardware server URL must be provided via the `HW_SERVER_URL` variable. Only
available on Zynq-7000 as of now.

`boot-qemu`
: Boot into QEMU.

`flash-boot`
: Flash boot image onto board via JTAG. The hardware server URL must be
provided via the `HW_SERVER_URL` variable. The flash type must be specified
with the `FLASH_TYPE` variable if it deviates from the default. The FSBL used
for flashing, the boot image and the flash offset can be changed with the
`FSBL_ELF`, `BOOT_BIN` and `BOOT_BIN_OFF` variables respectively.

`flash-kernel`
: Flash kernel image onto board via JTAG. The hardware server URL must be
provided via the `HW_SERVER_URL` variable. The flash type must be specified
with the `FLASH_TYPE` variable if it deviates from the default. The FSBL used
for flashing, the kernel image and the flash offset can be changed with the
`FSBL_ELF`, `KERNEL_IMG` and `KERNEL_IMG_OFF` variables respectively.

`flash`
: Flash boot and kernel image onto board via JTAG.

`mrproper`
: Clean all build artifacts. If this target is invoked with `CLEAN_HDF=1`, the
HDF is deleted as well (i.e. all files in folder `project-spec/hw-description`
except file `metadata`).


### Networkless Builds

In some circumstances, it might be desirable to perform builds without any
network access; notably,
- to provide long-term reproducibility in case of package sources being
  not available online anymore.
- to perform builds in corporate environments with restricted internet access.


#### Setup

A number of PetaLinux configuration options have to be changed to enable
networkless builds; run `make config` and,

- in Yocto Settings -> Add pre-mirror url, set the `pre-mirror url path` to
  your local source mirror, e.g `file://${PROOT}/source-mirror` (or set
  `CONFIG_PRE_MIRROR_URL` in `project-spec/configs/config`).
- in Yocto Settings, uncheck `Enable Network sstate feeds`
  (or unset `CONFIG_YOCTO_NETWORK_SSTATE_FEEDS` in
  `project-spec/configs/config`).
- in Yocto Settings, check `Enable BB NO NETWORK`
  (or set `CONFIG_YOCTO_BB_NO_NETWORK` in `project-spec/configs/config`).


#### Usage

All sources that are not part of the PetaLinux installation will be stored in
the local source mirror. To update the source mirror, run:

    $ make UPDATE_MIRROR=1

The local source mirror must be updated each and every time a package is added
to the image. Notably, sources are only added to the source mirror, but never
removed; so multiple revisions or entirely different PetaLinux projects can
share a mirror. Cleanup of the source mirror should be performed manually when
required.


### Image Buildinfo

Add the following snippet to `project-spec/meta-user/conf/petalinuxbsp.conf` in
order to write build information to the target filesystem on `/etc/build`:

    INHERIT += "image-buildinfo"
    IMAGE_BUILDINFO_VARS_append = " DATETIME"

`/etc/build` contains the build configuration as defined by the list of BitBake
variables in `IMAGE_BUILINFO_VARS` and the Git revisions (branch/tag, commit ID
and dirty flag) of all Yocto layers.

Appending variables to `IMAGE_BUILDINFO_VARS` is optional; however the build
time `DATETIME` is recommended. A list of common variables can be found in the
[Variables Glossary of the Yocto Reference
Manual](https://docs.yoctoproject.org/ref-manual/variables.html).


### Image Version

It is recommended to add image versioning information via
[os-release](https://www.freedesktop.org/software/systemd/man/os-release.html)
using the `IMAGE_ID` and `IMAGE_VERSION` variables.

Add the `os-release` package to your root filesystem and extend it via
`project-spec/meta-user/recipes-core/os-release/os-release.bbappend`. The
following example will add the variables `BUILD_ID` (build timestamp),
`IMAGE_ID` and `IMAGE_VERSION` to `/etc/os-release` on the target filesystem,
identifying the image as `mle-example` and reading the semantic version from
`version.txt` in the PetaLinux root directory.

    OS_RELEASE_FIELDS += "BUILD_ID IMAGE_ID IMAGE_VERSION"

    IMAGE_ID = "mle-example"

    python do_compile_prepend () {
        with open(d.getVar("TOPDIR") + "/../version.txt") as f:
            major, minor, patch = f.readline().rstrip().split(".")

        d.setVar("MAJOR_VERSION", major)
        d.setVar("MINOR_VERSION", minor)
        d.setVar("PATCH_VERSION", patch)
        d.setVar("IMAGE_VERSION", "{}.{}.{}".format(major, minor, patch))
    }


### Open Source License Compliance

There are three main areas of concern for [open source license
compliance](http://docs.yoctoproject.org/dev-manual/common-tasks.html#maintaining-open-source-license-compliance-during-your-product-s-lifecycle).

1. Source code must be provided.

2. License text for the software must be provided.

3. Compilation scripts and modifications to the source code must be provided.

The first two points can be adressed by running:

    $ make source-release SOURCE_RELEASE=<source-release-dir> MANIFESTS=<manifests-dir>

This will create tarballs for packages that require the release of source code
(i.e. GPL) in the directory `SOURCE_RELEASE` (defaulting to `source-release`).

In addition, a license manifest is stored in directory `MANIFESTS` (defaulting
to `manifests`) to assist with audits.

Some licenses require the license text to accompany the binary. You can achieve
this by adding the following to your
`project-spec/meta-user/conf/petalinuxbsp.conf` file:

    COPY_LIC_MANIFEST = "1"
    COPY_LIC_DIRS = "1"
    LICENSE_CREATE_PACKAGE = "1"


### Extending

If you need additional functionality in your project, put it into a file named
`local.mk`.


## XSDK Makefile

The XSDK Makefile provides a declarative wrapper around the Xilinx Software
Command-Line Tool (XSCT) and Bootgen to streamline the build of Xilinx Software
Development Kit (XSDK) projects.


### Supported Platforms

XSDK is supported from v2018.1 to v2019.1 (i.e. the last four releases). The
Makefile should run on all underlying Linux OSs supported by XSDK, but not
Windows. However, testing is only conducted on Ubuntu 18.04 LTS (Bionic Beaver)
as of now.


### Build Configuration Syntax

The XSDK Makefile is configured via a custom syntax as documented in the
following sections.


#### Hardware Platform Specification

The Hardware Platform Specification captures all the information from a
hardware design that is required to write, debug and deploy software
applications for that hardware. In the XSDK Makefile, there is exactly one
hardware platform specification called `hw` by default [^1]. The hardware
platform specification is derived from the Hardware Description File (HDF)
imported during build (see section Usage) and does not need to be configured.

[^1]: The hardware platform specification name can be changed with the `HW_PRJ`
      variable if necessary.

#### Repositories

A software repository is a directory that holds third-party software
components, as well as custom drivers, libraries, and operating systems. You
can register repositories in the workspace by adding the respective path to the
`REPOS` variable.

#### Board Support Packages

A Board Support Package (BSP) is a collection of libraries and drivers that
form the basis of software applications (see section "Applications").

BSPs are registered by adding their name to the `BSP_PRJS` list. They can then
be configured by prefixing the corresponding option with their name:

    BSP_PRJS += fsbl_bsp
    fsbl_bsp_PROC = psu_cortexa53_0
    fsbl_bsp_IS_FSBL = yes
    fsbl_bsp_LIBS = xilffs xilsecure xilpm
    fsbl_bsp_POST_CREATE_TCL = configbsp -bsp fsbl_bsp use_strfunc 1

    BSP_PRJS += gen_bsp
    gen_bsp_PROC = psu_cortexa53_0
    gen_bsp_STDOUT = psu_uart_1

The following BSP options are available:

`OS`
: Operating system type. Optional, defaults to `standalone`. Run `repo -os` in
XSCT to get a list of all OSs.

`PROC`
: Processor instance. Run `toolchain` in XSCT to get a list of supported
processor types.

`ARCH`
: Processor architecture. Can be 32 or 64 bit. Valid only for processors
supporting multiple architectures (e.g. A53).

`PATCH`
: List of space-separated patch file entries. Patches are applied in the base
directory of the respective BSP project. A patch file list entry has the format
`<patchfile>[;stripnum]`, where `stripnum` is the optional number of leading
slashes to be stripped from each file name found in the patch file (default is
1).

`SED`
: List of space-separated file entries to be transformed with sed (stream
editor). Sed is run in the base directory of the respective BSP project. A sed
list entry has the format `<srcfile>;<sedfile>`, where `<srcfile>` is the file
to be transformed and `<sedfile>` the sed script file.

`IS_FSBL`
: If `yes`, apply non-default BSP settings for FSBL.

`EXTRA_CFLAGS`
: Additional compiler flags (default `-g -Wall -Wextra`). The default
optimization level of `-O2` can be overriden with this variable.

`STDIN`
: Select UART for standard input.

`STDOUT`
: Select UART for standard output.

`LIBS`
: List of libraries to be added to the BSP. Run `repo -lib` in XSCT to get a
list of available libraries.

`POST_CREATE_TCL`
: Hook for adding extra Tcl commands after the BSP has been created. Can be
used to configure BSP settings (via the `configbsp` command) not available in
the XSDK Makefile.


#### Applications

Software application projects are your final application containers. They can
either be derived from a template or contain your own source files. Each
application project must be linked to exactly one BSP.

Application projects are registered by adding their name to the `APP_PRJS`
list. They can then be configured by prefixing the corresponding option with
their name:

    APP_PRJS += fsbl
    fsbl_TMPL = Zynq MP FSBL
    fsbl_BSP = fsbl_bsp
    fsbl_CPPSYMS = FSBL_DEBUG_DETAILED

    APP_PRJS += helloworld
    helloworld_TMPL = Hello World
    helloworld_BSP = gen_bsp
    helloworld_BCFG = Debug
    helloworld_PATCH = helloworld.patch
    helloworld_SED = platform.c;baud_rate.sed
    helloworld_LIBS = helloworldlib

The following application project options are available:

`TMPL`
: Name of the template to base the application project on. Run `repo -apps` in
XSCT to get a list of available application templates.

`PROC`
: Processor instance. Run `toolchain` in XSCT to get a list of supported
processor types.

`LANG`
: Programming language. Can be either `c` (default) or `c++`.

`BSP`
: Reference to BSP. Required.

`SRC`
: List of space-separated source files to be added to the application. For each
list entry, a symlink in the `src` directory of the respective application
project will be created that points towards the corresponding source file.

`PATCH`
: List of space-separated patch file entries. Patches are applied in the `src`
directory of the respective application project. A patch file list entry has
the format `<patchfile>[;stripnum]`, where `stripnum` is the optional number of
leading slashes to be stripped from each file name found in the patch file
(default is 1).

`SED`
: List of space-separated file entries to be transformed with sed (stream
editor). Sed is run in the `src` directory of the respective application
project. A sed list entry has the format `<srcfile>;<sedfile>`, where
`<srcfile>` is the file to be transformed and `<sedfile>` the sed script file.

`BCFG`
: Build configuration. Can either be `Release` (default) or `Debug`.

`OPT`
: Compiler optimization level. Can either be `None (-O0)`, `Optimize (-O1)`,
`Optimize more (-O2)` (default), `Optimize most (-O3)`, `Optimize for size
(-Os)`.

`CPPSYMS`
: List of preprocessor symbols (e.g. `MYSYMBOL=1`).

`LIBS`
: List of library projects the application depends on. The libraries are added
to the include and library search paths and linked against the application.

`POST_CREATE_TCL`
: Hook for adding extra Tcl commands after the application project has been
created. Can be used to set application project configuration parameters (via
the `configapp` command) not available in the XSDK Makefile.


#### Libraries

Software library projects are collections of commonly used functions for your
applications. Library projects are independent of the hardware platform
specification.

Library projects are registered by adding their name to the `LIB_PRJS` list.
They can then be configured by prefixing the corresponding option with their
name:

    LIB_PRJS += helloworldlib
    helloworldlib_PROC = psu_cortexa53
    helloworldlib_BCFG = Debug
    helloworldlib_SRC = helloworldlib.c libhelloworld.h

The following library project options are available:

`TYPE`
: Library type. Can be either `static` (default) or `shared`. Type `shared` can
only be used in combination with operating system type `linux`.

`PROC`
: Processor type. Can be either `ps7_cortex9`, `microblaze`, `psu_cortexa53` or
`psu_cortexr5`. Required.

`OS`
: Operating system type. Can be either `standalone` (default) or `linux`. Type
`linux` can only be used in combination with library type `shared`.

`LANG`
: Programming language. Can be either `c` (default) or `c++`.

`ARCH`
: Processor architecture. Can be 32 or 64 bit. Valid only for processors
supporting multiple architectures (e.g. A53).

`SRC`
: List of space-separated source files to be added to the library. For each
list entry, a symlink in the `src` directory of the respective library project
will be created that points towards the corresponding source file.

`BCFG`
: Build configuration. Can either be `Release` (default) or `Debug`.

`OPT`
: Compiler optimization level. Can either be `None (-O0)`, `Optimize (-O1)`,
`Optimize more (-O2)` (default), `Optimize most (-O3)`, `Optimize for size
(-Os)`.

`CPPSYMS`
: List of preprocessor symbols (e.g. `MYSYMBOL=1`).

`POST_CREATE_TCL`
: Hook for adding extra Tcl commands after the library project has been
created. Can be used to set library project configuration parameters (via
the `configapp` command) not available in the XSDK Makefile.

Since XSDK does not support building Linux apps, the combination of library
type `shared` and operating system type `linux` is not officially supported by
the XSDK Makefile.


#### Bootgen

Bootgen is a Xilinx tool that merges build artifacts into a boot image
according to a Boot Image Format (BIF) file. The XSDK Makefile can generate BIF
files and invoke Bootgen subsequently.

Bootgen projects are registered by adding their name to the `BOOTGEN_PRJS`
list. They can then be configured by prefixing the corresponding option with
their name:

    BOOTGEN_PRJS += bootbin
    bootbin_BIF_ARCH = zynqmp

The following Bootgen project options are available:

`BIF_ARCH`
: Device architecture. Run `bootgen` and see description of `-arch` option for
a list of supported architectures.

`BIF_ARGS_EXTRA`
: Add additional Bootgen arguments for special operations like key generation.

`NO_OUTPUT`
: If `yes`', do not write a boot image file. Required for certain operations
like key generation.

`FLASH_TYPE`
: Flash memory type. Run `program_flash` and see description of option
`-flash_type` to get a list of supported memory types. Only needed for `flash`
target (see section "Usage").

`FLASH_FSBL`
: FSBL used for flashing. Only needed for `flash` target (see section "Usage").

`FLASH_OFF`
: Offset within the flash memory at which the image should be written. Only
needed for `flash` target (see section "Usage").

BIF attributes are then registered by adding their name to the `BIF_ATTRS`
list. They can then be configured by prefixing the `BIF_ATTR` and `BIF_FILE`
variables with the Bootgen project name and BIF attribute name:

    bootbin_BIF_ATTRS = fsbl helloworld
    bootbin_fsbl_BIF_ATTR = bootloader, destination_cpu=a53-0
    bootbin_fsbl_BIF_FILE = fsbl/$(fsbl_BCFG)/fsbl.elf
    bootbin_helloworld_BIF_ATTR = destination_cpu=a53-0
    bootbin_helloworld_BIF_FILE = helloworld/$(helloworld_BCFG)/helloworld.elf

This example is translated to the following BIF file:

    bootbin:
    {
        [bootloader, destination_cpu=a53-0] fsbl/Release/fsbl.elf
        [destination_cpu=a53-0] helloworld/Debug/helloworld.elf
    }

Prerequisites to all `BIF_FILE`s are added to the corresponding BIF generation
rules. If, however, the concerning file is created instead of consumed by
Bootgen (e.g. key generation) or is not a file at all, one must set the
`BIF_FILE_NO_DEP` variable to `yes`. For example:

    ...
    generate_pem_BIF_ARGS_EXTRA = -p zu9eg -generate_keys pem
    ...
    generate_pem_pskfile_BIF_ATTR = pskfile
    generate_pem_pskfile_BIF_FILE = generate_pem/psk0.pem
    generate_pem_pskfile_BIF_FILE_NO_DEP = yes
    ...

The file name of a bitstream depends on the Vivado design and is often not
known before the HDF has been extracted. In these cases, by convention, one
should point the corresponding `BIF_FILE` option to a variable named like
`BIT`:

    bootbin_bit_BIF_ATTR = destination_device=pl
    bootbin_bit_BIF_FILE = $(BIT)

The `BIT` variable must then be provided on invocation:

    $ make HDF=<path-to-your-hdf> BIT=hw/<bitstream>.bit

Optionally, one can provide a default as well:

    BIT ?= hw/design_1_wrapper.bit


### Setup

Create a symlink named `Makefile` to the `xsdk.mk` file:

    $ ln -s <path-to-your-psmake-repo>/xsdk.mk Makefile

Add the `build` directory to your `.gitignore`.

By default, the XSDK Makefile looks for the build configuration in
`./default.mk`. If you choose a different file name (or like to have multiple
build configurations), you can specify the path with the `CFG` variable.

Write your build configuration as documented in section "Makefile syntax".
Instead of writing the build configuration from scratch, you can also copy
`templates/default.mk` into your working directory.


### Usage

Import a HDF and build all projects by executing:

    $ make HDF=<path-to-your-hdf>

The XSDK Makefile creates a new XSDK workspace as a subfolder in directory
`build` named `<cfg-file-name>_<date>-<time>_<git-commit-id>`. A new XSDK
workspace is created on each invocation. If you would like to run the XSDK
Makefile on a specific workspace instead of creating a new one, you can use the
`O` variable:

    $ make O=build/<cfg-file-name>_<date>-<time>_<git-commit-id>

The XSDK Makefile dynamically creates targets according to the build
configuration. Each BSP, application project and Bootgen project is assigned a
build target with the same name. Additionally each BSP and application project
feature a `clean` and `distclean` target separated by `_`.  In order to e.g.
clean the application project `helloworld`, one would execute:

    $ make helloworld_clean

Bootgen projects come with a `flash` target to write the boot image onto a
board via JTAG. In order to e.g. flash the Bootgen project `bootbin`, one would
execute:

    $ make bootbin_flash HW_SERVER_URL=<hw-server-url>

In addition, the following generic Makefile targets are available:

`hw`
: Build the hardware platform specification. You must provide a HDF via the
`HDF` variable.

`hw_distclean`
: Clean the hardware platform specification.

`generate`
: Generate all projects.

`build` (default)
: Build all projects.

`metalog`
: Show meta log.

`sdklog`
: Show XSDK log.

`xsdk`
: Run XSDK.

`xsct`
: Run XSCT.

`clean`
: Clean all projects.

`distclean`
: Remove workspace.


### Extending

The build configuration file can be extended with standard Makefile targets for
e.g. uploading and running build artifacts via JTAG.


## Vitis Makefile

The Vitis Makefile provides a declarative wrapper around the Xilinx Software
Command-Line Tool (XSCT) and Bootgen to streamline the build of Xilinx Vitis
projects.


### Supported Platforms

Vitis is supported in v2020.1. So far, there is a focus on the previous XSDK
use cases; while SDAccel/SDSoC use cases might work as well, they are not
supported yet. The Makefile should run on all underlying Linux OSs supported by
Vitis, but not Windows. However, testing is only conducted on Ubuntu 18.04 LTS
(Bionic Beaver) as of now.

### Known Issues

- Due to a bug in the Vitis Tcl API, when building an application the
  corresponding domain is always rebuild as well. It is therefore recommended
  to build applications in the Vitis GUI once the workspace has been created.


### Build Configuration Syntax

The Vitis Makefile is configured via a custom Makefile syntax as documented in
the following sections.


#### Repositories

A software repository is a directory that holds third-party software
components, as well as custom drivers, libraries, and operating systems. You
can register repositories in the workspace by adding the respective path to the
`REPOS` variable. In addition, you can also register existing platforms by
adding the respective path to the `PLATS` variable.


#### Platform

The Platform captures all the information from a hardware design that is
required to write, debug and deploy applications for that hardware. In the
Vitis Makefile, there is exactly one platform called `plat` by default [^1].
The platform is either derived from

- a hardware description file (XSA)
- an existing platform via the corresponding XPFM file.

See section "Usage" on how to import one of these artifacts during build.

[^1]: The platform name can be changed with the `PLAT_PRJ` variable if
      necessary.


#### Domains (BSP)

A Domain or Board Support Package (BSP) is a collection of libraries and
drivers that form the basis of software applications (see section
"Applications"). There can be only one domain for each processor instance (i.e.
core).

Domains are registered by adding their name to the `DOMAIN_PRJS` list. They can
then be configured by prefixing the corresponding option with their name:

    DOMAIN_PRJS += fsbl_bsp
    fsbl_bsp_PROC = psu_cortexa53_0
    fsbl_bsp_IS_FSBL = yes
    fsbl_bsp_LIBS = xilffs xilsecure xilpm
    fsbl_bsp_POST_CREATE_TCL = configbsp -bsp fsbl_bsp use_strfunc 1

    DOMAIN_PRJS += gen_bsp
    gen_bsp_PROC = psu_cortexa53_0
    gen_bsp_EXTRA_CFLAGS = -g -Wall -Wextra -Os
    gen_bsp_STDOUT = psu_uart_1

The following domain options are available:

`OS`
: Operating system type. Optional, defaults to `standalone`. Run `repo -os` in
XSCT to get a list of all OSs.

`PROC`
: Processor instance. Run `toolchain` in XSCT to get a list of supported
processor types.

`IS_FSBL`
: If `yes`, apply non-default BSP settings for FSBL.

`EXTRA_CFLAGS`
: Additional compiler flags (default `-g -Wall -Wextra`). The default
optimization level of `-O2` can be overriden with this variable.

`STDIN`
: Select UART for standard input.

`STDOUT`
: Select UART for standard output.

`LIBS`
: List of libraries to be added to the domain. Run `repo -lib` in XSCT to get a
list of available libraries.

`POST_CREATE_TCL`
: Hook for adding extra Tcl commands after the domain has been created. Can be
used to configure BSP settings (via the `configbsp` command) not available in
the Vitis Makefile.


#### Applications

Application projects are your final application containers. They can
either be derived from a template or contain your own source files. Each
application project must be linked to exactly one Domain (BSP).

Application projects are registered by adding their name to the `APP_PRJS`
list. They can then be configured by prefixing the corresponding option with
their name:

    APP_PRJS += fsbl
    fsbl_TMPL = Zynq MP FSBL
    fsbl_DOMAIN = fsbl_bsp
    fsbl_CPPSYMS = FSBL_DEBUG_DETAILED

    APP_PRJS += helloworld
    helloworld_TMPL = Hello World
    helloworld_DOMAIN = gen_bsp
    helloworld_BCFG = Debug
    helloworld_PATCH = helloworld.patch
    helloworld_SED = platform.c;baud_rate.sed

The following application project options are available:

`TMPL`
: Name of the template to base the application project on. Run `repo -apps` in
XSCT to get a list of available application templates.

`PROC`
: Processor instance. Run `toolchain` in XSCT to get a list of supported
processor types.

`DOMAIN`
: Reference to domain (BSP). Required.

`PLAT`
: Reference to platform. Use this to base the application on a different
platform than the default `plat`. The platform must be available in the
platform repository; see section "Repositories". Mutually exclusive with `HW`
option.

`HW`
: Path to hardware definition file (XSA) or platform file (XPFM). Use this to
base the application on a hardware platform file instead of the `plat`
platform.  Mutually exclusive with `PLAT`.

`SRC`
: List of space-separated source files or directories to be added to the
application. For each list entry, a link entry in the application project to
the absolute path of the respective source file or directory is created.

`PATCH`
: List of space-separated patch file entries. Patches are applied in the base
directory of the respective application project. A patch file list entry has
the format `<patchfile>[;stripnum]`, where `stripnum` is the optional number of
leading slashes to be stripped from each file name found in the patch file
(default is 1).

`SED`
: List of space-separated file entries to be transformed with sed (stream
editor). Sed is run in the base directory of the respective application
project. A sed list entry has the format `<srcfile>;<sedfile>`, where
`<srcfile>` is the file to be transformed and `<sedfile>` the sed script file.

`BCFG`
: Build configuration. Can either be `Release` (default) or `Debug`.

`OPT`
: Compiler optimization level. Can either be `None (-O0)`, `Optimize (-O1)`,
`Optimize more (-O2)` (default), `Optimize most (-O3)`, `Optimize for size
(-Os)`.

`CPPSYMS`
: List of preprocessor symbols (e.g. `MYSYMBOL=1`).

`POST_CREATE_TCL`
: Hook for adding extra Tcl commands after the application project has been
created. Can be used to set application project configuration parameters (via
the `configapp` command) not available in the Vitis Makefile.


#### Bootgen

Bootgen is a Xilinx tool that merges build artifacts into a boot image
according to a Boot Image Format (BIF) file. The Vitis Makefile can generate
BIF files and invoke Bootgen subsequently.

Bootgen projects are registered by adding their name to the `BOOTGEN_PRJS`
list. They can then be configured by prefixing the corresponding option with
their name:

    BOOTGEN_PRJS += bootbin
    bootbin_BIF_ARCH = zynqmp

The following Bootgen project options are available:

`BIF_ARCH`
: Device architecture. Run `bootgen` and see description of `-arch` option for
a list of supported architectures.

`BIF_ARGS_EXTRA`
: Add additional Bootgen arguments for special operations like key generation.

`NO_OUTPUT`
: If `yes`', do not write a boot image file. Required for certain operations
like key generation.

`FLASH_TYPE`
: Flash memory type. Run `program_flash` and see description of option
`-flash_type` to get a list of supported memory types. Only needed for `flash`
target (see section "Usage").

`FLASH_FSBL`
: FSBL used for flashing. Only needed for `flash` target (see section "Usage").

`FLASH_OFF`
: Offset within the flash memory at which the image should be written. Only
needed for `flash` target (see section "Usage").

BIF attributes are then registered by adding their name to the `BIF_ATTRS`
list. They can then be configured by prefixing the `BIF_ATTR` and `BIF_FILE`
variables with the Bootgen project name and BIF attribute name:

    bootbin_BIF_ATTRS = fsbl helloworld
    bootbin_fsbl_BIF_ATTR = bootloader, destination_cpu=a53-0
    bootbin_fsbl_BIF_FILE = fsbl/$(fsbl_BCFG)/fsbl.elf
    bootbin_helloworld_BIF_ATTR = destination_cpu=a53-0
    bootbin_helloworld_BIF_FILE = helloworld/$(helloworld_BCFG)/helloworld.elf

This example is translated to the following BIF file:

    bootbin:
    {
        [bootloader, destination_cpu=a53-0] fsbl/Release/fsbl.elf
        [destination_cpu=a53-0] helloworld/Debug/helloworld.elf
    }

Prerequisites to all `BIF_FILE`s are added to the corresponding BIF generation
rules. If, however, the concerning file is created instead of consumed by
Bootgen (e.g. key generation) or is not a file at all, one must set the
`BIF_FILE_NO_DEP` variable to `yes`. For example:

    ...
    generate_pem_BIF_ARGS_EXTRA = -p zu9eg -generate_keys pem
    ...
    generate_pem_pskfile_BIF_ATTR = pskfile
    generate_pem_pskfile_BIF_FILE = generate_pem/psk0.pem
    generate_pem_pskfile_BIF_FILE_NO_DEP = yes
    ...

The file name of a bitstream depends on the Vivado design and is often not
known before the HDF has been extracted. In these cases, by convention, one
should point the corresponding `BIF_FILE` option to a variable named like
`BIT`:

    bootbin_bit_BIF_ATTR = destination_device=pl
    bootbin_bit_BIF_FILE = $(BIT)

The `BIT` variable must then be provided on invocation:

    $ make HDF=<path-to-your-hdf> BIT=hw/<bitstream>.bit

Optionally, one can provide a default as well:

    BIT ?= hw/design_1_wrapper.bit


### Setup

Create a symlink named `Makefile` to the `vitis.mk` file:

    $ ln -s <path-to-your-psmake-repo>/vitis.mk Makefile

Add the `build` directory to your `.gitignore`.

By default, the Vitis Makefile looks for the build configuration in
`./default.mk`. If you choose a different file name (or like to have multiple
build configurations), you can specify the path with the `CFG` variable.

Write your build configuration as documented in section "Makefile syntax".
Instead of writing the build configuration from scratch, you can also copy
`templates/vitis/default.mk` into your working directory.


### Usage

Import either a hardware description file (XSA) by executing

    $ make HDF=<path-to-.xsa-file>

or an existing platform via an XPFM file:

    $ make XPFM=<path-to-.xpfm-file>

Without specyfing a further target, all projects will be built.

The Vitis Makefile creates a new Vitis workspace as a subfolder in directory
`build` named `<cfg-file-name>_<date>-<time>_<git-commit-id>`. A new Vitis
workspace is created on each invocation. If you would like to run the Vitis
Makefile on a specific workspace instead of creating a new one, you can use the
`O` variable:

    $ make O=build/<cfg-file-name>_<date>-<time>_<git-commit-id>

The Vitis Makefile dynamically creates Makefile targets according to the build
configuration. Each domain, application project and Bootgen project is assigned
a build target with the same name. Additionally each domain and application
project feature a `clean` and `distclean` target separated by `_`.  In order to
e.g. clean the application project `helloworld`, one would execute:

    $ make helloworld_clean

Bootgen projects come with a `flash` target to write the boot image onto a
board via JTAG. In order to e.g. flash the Bootgen project `bootbin`, one would
execute:

    $ make bootbin_flash HW_SERVER_URL=<hw-server-url>

In addition, the following generic Makefile targets are available:

`plat`
: Build the platform project. Either provide a path to a hardware description
file (XSA) via the `HDF` variable, or to an existing platform file (XPFM) via
the `XPFM` variable.

`plat_distclean`
: Clean the platform project.

`generate`
: Generate all projects.

`build` (default)
: Build all projects.

`metalog`
: Show meta log.

`vitislog`
: Show Vitis log.

`vitis`
: Run Vitis.

`xsct`
: Run XSCT.

`clean`
: Clean all projects.

`distclean`
: Remove workspace.


### Extending

The build configuration file can be extended with standard Makefile targets for
e.g. uploading and running build artifacts via JTAG.


## License

Licensed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).
