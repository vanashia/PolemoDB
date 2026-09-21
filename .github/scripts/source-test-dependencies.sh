#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
packages=(
  build-essential ccache clang-14 llvm-14-dev \
  libapr1-dev libbz2-dev libcurl4-openssl-dev libevent-dev curl \
  libicu-dev libipc-run-perl libkrb5-dev libldap2-dev \
  libldap-common libperl-dev libssl-dev libxml2-dev \
  libyaml-dev libxerces-c-dev libzstd-dev locales \
  krb5-admin-server krb5-kdc ldap-utils slapd \
  libreadline-dev openssh-server perl python3-dev python3-psutil \
  python3-psycopg2 zlib1g-dev
)
if [[ "${1:-build}" == build ]]; then
  packages+=(cmake ninja-build pkg-config flex bison)
fi
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"

# Ubuntu's slapd AppArmor profile only permits the packaged data/config
# locations.  The LDAP source test intentionally creates an isolated slapd
# under TESTDATADIR, so remove the profile on this ephemeral CI runner.
if command -v apparmor_parser >/dev/null 2>&1 &&
  sudo test -f /etc/apparmor.d/usr.sbin.slapd; then
  sudo apparmor_parser -R /etc/apparmor.d/usr.sbin.slapd || true
fi

sudo localedef -i de_DE -f ISO-8859-1 de_DE.ISO8859-1 || true
sudo localedef -i el_GR -f ISO-8859-7 gr_GR.ISO8859-7 || true
sudo localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R || true
sudo localedef -i en_US -f UTF-8 en_US.UTF-8 || true

# pg_import_system_collations() enumerates the host's libc locales.  Keep the
# source-test runner deterministic even when the base image has only C/POSIX
# locales or localedef cannot create a locale in its default archive.
if ! locale -a | grep -Eiq '^(en_US|de_DE|gr_GR|ru_RU)'; then
  sudo locale-gen \
    en_US.UTF-8 \
    de_DE.ISO-8859-1 \
    gr_GR.ISO-8859-7 \
    ru_RU.KOI8-R || true
fi
if ! locale -a | grep -Eiq '^(en_US|de_DE|gr_GR|ru_RU)'; then
  echo 'required libc locales are unavailable after installing locale packages' >&2
  locale -a >&2 || true
  exit 1
fi
