#!/bin/bash -e

CERT_REGISTRATION_EMAIL=${CERT_REGISTRATION_EMAIL}
LETS_ENCRYPT_DIRECTORY=/etc/letsencrypt
DEPLOY_HOOK_PATH=/usr/bin/successfully-renewed-cert

# Wildcard options
CERT_REGISTER_WILDCARD=${CERT_REGISTER_WILDCARD:-true}
CERT_REGISTER_WILDCARD_CMD=""
[ "${CERT_REGISTER_WILDCARD}" == "true" ] && CERT_REGISTER_WILDCARD_CMD="-d *.${CERT_HOSTNAME}"

# Dry run options
DRY_RUN=${DRY_RUN:-false}
DRY_RUN_CMD=""

function exit_with_failure() {
  exit_code=$1
  message=$2
  echo "FATAL: Failed to renew LetsEncrypt certificate for host ${CERT_HOSTNAME}. ${message}"
  [ ! -z "$SNS_TOPIC_ARN" ] && aws sns publish \
    --topic-arn ${SNS_TOPIC_ARN} \
    --message "Automated LetsEncrypt Cert Renewal: ${CERT_HOSTNAME} - FAILURE.  Failed to renew LetsEncrypt certificate for host ${CERT_HOSTNAME}.  ${message}" \
    --subject "Automated LetsEncrypt Cert Renewal: ${CERT_HOSTNAME} - FAILURE"
  exit "${exit_code}"
}

[ "${DRY_RUN}" == "true" ] && DRY_RUN_CMD="--dry-run"

# Test bucket env var
( [ -z "${CERT_BUCKET_NAME}" ] || [ -z "${CERT_BUCKET_PATH}" ] || [ -z "${CERT_HOSTNAME}" ]) && exit_with_failure 20 "Requires CERT_HOSTNAME, CERT_BUCKET_NAME, and CERT_BUCKET_PATH environment variables"
[[ ${CERT_BUCKET_NAME} == *"/"* ]]   && exit_with_failure 30 "CERT_BUCKET_NAME should just be the bucket name, and cannot contain any slashes"
[[ ${CERT_BUCKET_PATH} != "/"*"/" ]] && exit_with_failure 40 "CERT_BUCKET_PATH should start and end with slashes"

# SNS Notification options
CERT_RENEWAL_SNS_NOTIFY=true
SNS_PUBLISH_SUCCESS_COMMAND=""
[ ! -z "$SNS_TOPIC_ARN" ] && SNS_PUBLISH_SUCCESS_COMMAND="aws sns publish --topic-arn ${SNS_TOPIC_ARN} --message 'Automated LetsEncrypt Renewal: ${CERT_HOSTNAME} - Success. Successfully renewed LetsEncrypt certificate for host ${CERT_HOSTNAME}.' --subject 'Automated LetsEncrypt Renewal: ${CERT_HOSTNAME} - Success'"
cat <<- EOF > ${DEPLOY_HOOK_PATH}
touch /tmp/cert_renewal_success
${SNS_PUBLISH_SUCCESS_COMMAND}
EOF
chmod 555 $DEPLOY_HOOK_PATH

# Test bucket access
touch test_write.txt
aws s3 cp ./test_write.txt "s3://${CERT_BUCKET_NAME}${CERT_BUCKET_PATH}test_write.txt" || exit_with_failure 50 "Could not write to S3 bucket - s3://${CERT_BUCKET_NAME}${CERT_BUCKET_PATH}test_write.txt"
aws s3 rm "s3://${CERT_BUCKET_NAME}${CERT_BUCKET_PATH}test_write.txt"                  || exit_with_failure 60 "Could not delete from S3 bucket - s3://${CERT_BUCKET_NAME}${CERT_BUCKET_PATH}test_write.txt"

# Sync s3 to local
aws s3 sync --exclude "${CERT_BUCKET_PATH}live/*" --no-progress "s3://${CERT_BUCKET_NAME}${CERT_BUCKET_PATH}" $LETS_ENCRYPT_DIRECTORY/ || exit_with_failure 70 "Could not sync S3 bucket to local environment - s3://${CERT_BUCKET_NAME}${CERT_BUCKET_PATH}"
#mkdir -p $LETS_ENCRYPT_DIRECTORY/ && cp -r /mnt/certs/* $LETS_ENCRYPT_DIRECTORY/

# Issue or renew cert
CERTBOT_STATUS=""
if [ -d "$LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}" ] && [ ! -L "$LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/privkey.pem" ] ; then
  echo "Archive directory [$LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}] found, attempting to renew existing certs"
  CERT_VERSION=$(ls -1vr "$LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}/" | head -1 | sed "s/privkey\([0-9]\+\).pem/\1/")
  mkdir -p "$LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}"
  ln -s $LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}/privkey${CERT_VERSION}.pem $LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/privkey.pem
  ln -s $LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}/fullchain${CERT_VERSION}.pem $LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/fullchain.pem
  ln -s $LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}/chain${CERT_VERSION}.pem $LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/chain.pem
  ln -s $LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}/cert${CERT_VERSION}.pem $LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/cert.pem
  certbot renew --deploy-hook "${DEPLOY_HOOK_PATH}" ${DRY_RUN_CMD} || exit_with_failure 80 "certbot renew command failed.  There is likely an expiring cert that can't be renewed.  ACTION IS NECESSARY! Check the logs"
else
  echo "Archive directory [$LETS_ENCRYPT_DIRECTORY/archive/${CERT_HOSTNAME}] not found, creating new cert"
  certbot certonly ${DRY_RUN_CMD} -n --agree-tos --email "${CERT_REGISTRATION_EMAIL}" --dns-route53 -d "${CERT_HOSTNAME}" ${CERT_REGISTER_WILDCARD_CMD} || exit_with_failure 90 "certbot failed to create an initial certificate. ACTION IS NECESSARY! Check the logs"
fi

# Copy live certs to latest directory
if [ "${DRY_RUN}" == "false" ];
then
  mkdir -p $LETS_ENCRYPT_DIRECTORY/latest/${CERT_HOSTNAME}
  cp -a "$LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/privkey.pem" "$LETS_ENCRYPT_DIRECTORY/latest/${CERT_HOSTNAME}/privatekey.pem"             || exit_with_failure 93 "Could not save certs to S3"
  cp -a "$LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/cert.pem" "$LETS_ENCRYPT_DIRECTORY/latest/${CERT_HOSTNAME}/publiccert.pem"                || exit_with_failure 94 "Could not save certs to S3"
  cp -a "$LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/fullchain.pem" "$LETS_ENCRYPT_DIRECTORY/latest/${CERT_HOSTNAME}/publiccert-fullchain.pem" || exit_with_failure 95 "Could not save certs to S3"
  cp -a "$LETS_ENCRYPT_DIRECTORY/live/${CERT_HOSTNAME}/chain.pem" "$LETS_ENCRYPT_DIRECTORY/latest/${CERT_HOSTNAME}/cachain.pem"                  || exit_with_failure 96 "Could not save certs to S3"

  # Sync local to s3
  aws s3 sync --no-progress --exclude "live/*" $LETS_ENCRYPT_DIRECTORY/ "s3://${CERT_BUCKET_NAME}${CERT_BUCKET_PATH}" || exit_with_failure 100 "Could not synchronize certbot datadir with S3.  Indicates a configuration problem."
else
  echo "Skipping cert copy and sync because this is a dry run"
fi
