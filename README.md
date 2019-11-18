# SBA Certificate Renewal

This project offers a simple way to register and renew wildcard certificates with LetsEncrypt, and backup/restore the LetsEncrypt data with S3.

## Requirements

* Docker
* Docker Compose

## Usage

### Configuration

The script offers a number of environment variables:

| Parameter               | Default | Description                                                                                                                                                                                                                                | Example                    |
|-------------------------|---------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------|
| CERT_BUCKET_NAME        |         | The name of the bucket where certs will be backed up.                                                                                                                                                                                      | `my-certificate-bucket`    |
| CERT_BUCKET_PATH        |         | The path within the bucket; MUST start/end with `/`                                                                                                                                                                                        | `/certificates/dev/`       |
| CERT_HOSTNAME           |         | The hostname to be registered. Do not include wildcard                                                                                                                                                                                     | `my.subdomain.example.org` |
| DRY_RUN                 | `false` | Whether or not to perform a dry-run with certbot.  In many cases, dns validation will still be performed, but no certificates will be generated                                                                                            | `true` or `false`          |
| CERT_REGISTRATION_EMAIL |         | The email address under which the LetsEncrypt certificate will be created.                                                                                                                                                                 | `admin@example.org`        |
| CERT_REGISTER_WILDCARD  | true    | Whether or not a wildcard certificate should be requested.  `true` will result in a certificate with "my.subdomain.example.com" AND "*.my.subdomain.example.com".  `false` would create a certfiicate with just "my.subdomain.example.com" | `true` or `false`          |
| SNS_TOPIC_ARN           |         | What SNS Topic ARN should be used for notifying about successful renewals, or failures of any kind.  If no ARN is provided, no SNS messages will be attempted.                                                           | `arn:aws:sns:us-east-2:123456789012:MyTopic` |

### Running Locally

#### Building with Docker Compose

```
docker-compose build
```

#### Running with Docker Compose

Modify `docker-compose.yml` to configure a few environment variables:

## Contributing
We welcome contributions. Please read [CONTRIBUTING](CONTRIBUTING.md) for how to contribute.

### Code Of Conduct

We strive for a welcoming and inclusive environment for all SBA projects.

Please follow this guidelines in all interactions:

1. Be Respectful: use welcoming and inclusive language.
2. Assume best intentions: seek to understand other's opinions.

## Security Issues
Please do not submit an issue on GitHub for a security vulnerability. Please contact the development team through [SBA Website Support](mailto:support@us-sba.atlassian.net).

Be sure to include all the pertinent information.

<sub>The agency reserves the right to change this policy at any time.</sub>
