SUMMARY = "Corundum mqnic driver support tools"
SECTION = "devel"
LICENSE = "MIT & GPLv2"
LIC_FILES_CHKSUM = " \
	file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302 \
	file://${COMMON_LICENSE_DIR}/GPL-2.0;md5=801f80980d171dd6425610833a22dbe6"

SRC_URI = " \
	file://utils \
	file://include \
	file://lib \
	file://modules \
"

S = "${WORKDIR}/utils"

do_compile() {
	make
}

do_install() {
	# NOTE: Makefile currently defaults to PREFIX=/usr/local !
	make DESTDIR=${D} PREFIX=/usr install
}
