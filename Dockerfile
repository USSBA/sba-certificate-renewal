FROM certbot/dns-route53:latest

RUN apk --no-cache add bash
RUN pip install awscli "botocore<1.12" "boto3<1.9"

COPY linkcert.sh create-update-upload-certs.sh /usr/bin/
RUN chmod +x /usr/bin/linkcert.sh /usr/bin/create-update-upload-certs.sh
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["create-update-upload-certs.sh"]
