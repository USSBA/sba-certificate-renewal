#!/bin/bash -e

CERT_REGISTRATION_EMAIL=${CERT_REGISTRATION_EMAIL}
LETS_ENCRYPT_DIRECTORY=/etc/letsencrypt

# Wildcard optionsC
CERT_REGISTER_WILDCARD=${CERT_REGISTER_WILDCARD:-true}
CERT_REGISTER_WILDCARD_CMD=""
[ "${CERT_REGISTER_WILDCARD}" == "true" ] && CERT_REGISTER_WILDCARD_CMD="-d *.${CERT_HOSTNAME}"

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
aws s3 sync --exclude "${CERT_BUCKET_PATH}live/*" --no-progress "s3://${CERT_BUCKET_NAME}${CERT_BUCKET_PATH}" $LETS_ENCRYPT_DIRECTORY/
#mkdir -p $LETS_ENCRYPT_DIRECTORY/ && cp -r /mnt/certs/* $LETS_ENCRYPT_DIRECTORY/

# Issue or renew cert
if [ -d "$LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}" ] && [ ! -L "$LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/privkey.pem" ] ; then
  echo "Archive directory [$LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}] found, attempting to renew existing certs"
  CERT_VERSION=$(ls -1vr "$LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}/" | head -1 | sed "s/privkey\([0-9]\+\).pem/\1/")
  mkdir -p "$LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}"
  ln -s $LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}/privkey${CERT_VERSION}.pem $LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/privkey.pem
  ln -s $LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}/fullchain${CERT_VERSION}.pem $LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/fullchain.pem
  ln -s $LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}/chain${CERT_VERSION}.pem $LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/chain.pem
  ln -s $LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}/cert${CERT_VERSION}.pem $LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/cert.pem
  certbot renew ${DRY_RUN_CMD}
else
  echo "Archive directory [$LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}] not found, creating new cert"
  certbot certonly ${DRY_RUN_CMD} -n --agree-tos --email "${CERT_REGISTRATION_EMAIL}" --dns-route53 -d "${CERT_HOSTNAME}" ${CERT_REGISTER_WILDCARD_CMD}
fi

# Copy live certs to latest directory
if [ "${DRY_RUN}" == "false" ];
then
  mkdir -p $LETS_ENCRYPT_DIRECTORY/latest/${CERT_HOSTNAME}
  cp -a "$LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/privkey.pem" "$LETS_ENCRYPT_DIRECTORY/latest/${CERT_HOSTNAME}/privatekey.pem"
  cp -a "$LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/cert.pem" "$LETS_ENCRYPT_DIRECTORY/latest/${CERT_HOSTNAME}/publiccert.pem"
  cp -a "$LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/fullchain.pem" "$LETS_ENCRYPT_DIRECTORY/latest/${CERT_HOSTNAME}/cachainfull.pem"
  cp -a "$LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/chain.pem" "$LETS_ENCRYPT_DIRECTORY/latest/${CERT_HOSTNAME}/cachainshort.pem"

  # Sync local to s3
  aws s3 sync --no-progress --exclude "live/*" $LETS_ENCRYPT_DIRECTORY/ "s3://${CERT_BUCKET_NAME}${CERT_BUCKET_PATH}"
else
  echo "Skipping cert copy and sync because this is a dry run"
fi
