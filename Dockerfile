FROM certbot/dns-route53:latest

RUN apk --no-cache add bash
RUN pip install boto3 --upgrade
RUN pip install awscli --upgrade

COPY create-update-upload-certs.sh /usr/bin/
RUN chmod +x /usr/bin/create-update-upload-certs.sh
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["create-update-upload-certs.sh"]
