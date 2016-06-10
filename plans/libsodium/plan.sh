pkg_name=libsodium
pkg_distname=$pkg_name
pkg_origin=core
pkg_version=1.0.8
pkg_maintainer="The Habitat Contributors <humans@habitat.sh>"
pkg_license=('libsodium')
pkg_source=https://download.libsodium.org/libsodium/releases/${pkg_name}-${pkg_version}.tar.gz
pkg_shasum=c0f191d2527852641e0a996b7b106d2e04cbc76ea50731b2d0babd3409301926
pkg_dirname=${pkg_distname}-${pkg_version}
pkg_deps=(core/glibc)
pkg_build_deps=(core/autoconf core/automake core/diffutils core/patch core/make core/gcc core/sed)
pkg_include_dirs=(include)
pkg_lib_dirs=(lib)
