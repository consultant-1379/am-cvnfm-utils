#!/usr/bin/env bash

#########################################################################################################
# Author: zvorloe                                                                                       #
#                                                                                                       #
# Script can generate certificates with different expiration period                                     #
# that allows to rise and clear alarms for expiration.                                                  #
#                                                                                                       #
#########################################################################################################

# Parameters
CERT_NAME=test-cert

# Push generated certificates to the CVNFM
function installCertificates() {
  cd $HOME/$WORKDIR
  if [ -f "certificate_management.py" ]; then
    python3 certificate_management.py install-certificates
    echo "Certificates downloaded to the CVNFM application"
  else
    if [ -n "$UNPACK_ATTEMPTED" ]; then
      echo "Last certificate_management.py unpack attempt was unsuccessful"
      return
    fi
    echo "Unziping certificate_management.py"
    unzip -joq ./eric-eo-evnfm-[0-9]*.csar 'Scripts/eo-evnfm/certificate_management.py'
    UNPACK_ATTEMPTED=1
    installCertificates
  fi
}

# Generate ssl certificate and put to the corresponding folder
function generateSslCertificate() {
  WORKDIR=${WORKDIR:?Missing -w or --workdir} # Check if WORKDIR was passed before generating certs

  openssl req -x509 -nodes -days $1 -newkey rsa:1024 \
   -subj "/C=SE/ST=SE/L=Stockholm/O=Ericsson/OU=Ericsson/CN=Ericsson/emailAddress=dummy@test.net" \
   -keyout $HOME/$WORKDIR/certificates/"$CERT_NAME$i.key" \
   -out $HOME/$WORKDIR/certificates/trusted/"$CERT_NAME$i.crt"
}

# Generate ssl certificates
function generateAndSetCertificates() {
  for i in $(seq 1 "$1")
  do
      generateSslCertificate "$2"
  done
  installCertificates
}

# Cleanup folder
function removeGeneratedCerts() {
  rm -rf $HOME/$WORKDIR/certificates/$CERT_NAME*.key
  rm -rf $HOME/$WORKDIR/certificates/trusted/$CERT_NAME*.crt
  echo "-- $HOME/$WORKDIR/certificates/ - folder is cleared"
  echo "-- $HOME/$WORKDIR/certificates/trusted - folder is cleared"
}

function showHelp() {
  echo "Usage: $0 -w workdir [option...]" >&2
  echo """
  ############################################################################################################################################

     -w    | --workdir <WORKDIR>                      [MANDATORY OPTION] Define workdir
     -v    | --valid-certs <certs amount>             Installing valid certificates (with 90 days of expiration)
     -e    | --expired-certs <certs amount>           Installing expired certificates (with 30 days of expiration)
     -c    | --clean                                  Cleanup generated certificates
     -h    | --help                                   Show help message

  ############################################################################################################################################
  """
  exit 1
}

if ! TEMP=$(getopt -o w:,v:,e:,c,h,* -l workdir:,valid-certs:,expired-certs:,cleanup,help,* -q -- "$@"); then
  showHelp
fi

eval set -- "$TEMP"
while true; do
  case "$1" in
  -w | --workdir)
    WORKDIR="$2"
    shift 2
    ;;
  -v | --valid-certs)
    if [ -n "$2" ] && [ "$2" -eq "$2" ] 2>/dev/null; then
      generateAndSetCertificates "$2" 95
      shift 2
    else
      showHelp
    fi
    ;;
  -e | --expired-certs)
    if [ -n "$2" ] && [ "$2" -eq "$2" ] 2>/dev/null; then
      generateAndSetCertificates "$2" 30
      shift 2
    else
      showHelp
    fi
    ;;
  -c | --cleanup)
    removeGeneratedCerts
    shift 1
    ;;
  -h | --help)
    showHelp
    shift 1
    ;;
  *) break
    ;;
  esac
done