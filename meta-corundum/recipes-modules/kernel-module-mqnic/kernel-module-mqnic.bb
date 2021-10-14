SUMMARY = "Corundum mqnic driver kernel module"
SECTION = "kernel"
LICENSE = "MIT & GPLv2"
LIC_FILES_CHKSUM = " \
	file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302 \
	file://${COMMON_LICENSE_DIR}/GPL-2.0;md5=801f80980d171dd6425610833a22dbe6"

inherit module

SRC_URI = " \
	file://mqnic \
"

S = "${WORKDIR}/mqnic"
