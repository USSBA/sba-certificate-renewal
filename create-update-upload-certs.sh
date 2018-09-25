#!/bin/bash -e

CERT_REGISTRATION_EMAIL=${CERT_REGISTRATION_EMAIL:-digital@sba.gov}
CERT_RENEW_ONLY=${CERT_RENEW_ONLY:-false}

# Wildcard options
CERT_REGISTER_WILDARD=${CERT_REGISTER_WILDARD:-true}
CERT_REGISTER_WILDARD_CMD=""
[ "${CERT_REGISTER_WILDARD}" == "true" ] && CERT_REGISTER_WILDARD_CMD="-d *.${CERT_HOSTNAME}"
echo CERT_REGISTER_WILDARD_CMD=$CERT_REGISTER_WILDARD_CMD

# Dry run options
DRY_RUN=${DRY_RUN:-false}
DRY_RUN_CMD=""
[ "${DRY_RUN}" == "true" ] && DRY_RUN_CMD="--dry-run"

# Test bucket env var
if [ -z "${CERT_BUCKET_NAME}" ] || [ -z "${CERT_BUCKET_PATH}" ] || [ -z "${CERT_HOSTNAME}" ]; then
  echo "FATAL: Requires CERT_HOSTNAME, CERT_BUCKET_NAME, and CERT_BUCKET_PATH environment variables"
  exit 20
fi
if [[ ${CERT_BUCKET_NAME} == *"/"* ]]; then
  echo "FATAL: CERT_BUCKET_NAME should just be the bucket name, and cannot contain any slashes"
  exit 30
fi
if [[ ${CERT_BUCKET_PATH} != "/"*"/" ]]; then
  echo "FATAL: CERT_BUCKET_PATH should start and end with slashes"
  exit 40
fi

# Test bucket access
touch test_write.txt
aws s3 cp ./test_write.txt "s3://${CERT_BUCKET_NAME}${CERT_BUCKET_PATH}test_write.txt"

# Sync s3 to local
aws s3 sync --no-progress "s3://${CERT_BUCKET_NAME}${CERT_BUCKET_PATH}" /etc/letsencrypt/
#mkdir -p /etc/letsencrypt/ && cp -r /mnt/certs/* /etc/letsencrypt/

# Symlink live directory
if [ -d "/etc/letsencrypt/archive/" ]; then
  sed -i "s/\(\/etc\/letsencrypt\/live\/.*[^1]\).pem$/\11.pem/" /etc/letsencrypt/renewal/*.conf
  ls -1 /etc/letsencrypt/archive/ | xargs -n 1 linkcert.sh
fi

# Issue or renew cert
if [ "${CERT_RENEW_ONLY}" == "true" ]; then
  echo "CERT_RENEW_ONLY mode.  New certifciates will not be registered, only the renewal of existing certs"
  certbot ${DRY_RUN_CMD} renew
else
  echo "Create or Renew mode.  New certificates will be created; old certs will be renewed if needed."
  certbot ${DRY_RUN_CMD} certonly -n --agree-tos --email "${CERT_REGISTRATION_EMAIL}" --dns-route53 -d "${CERT_HOSTNAME}" ${CERT_REGISTER_WILDARD_CMD}
fi

# Sync local to s3
aws s3 sync --no-progress --exclude "live/*" /etc/letsencrypt/ "s3://${CERT_BUCKET_NAME}${CERT_BUCKET_PATH}"
