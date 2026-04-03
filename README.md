# DabbleTube

Static site for the DabbleTube landing page and embedded playlist.

## Deploy to Route 53 with CloudFront

This repo includes a CloudFormation stack that provisions:

- A private S3 bucket for the site files
- An ACM certificate in `us-east-1`
- A CloudFront distribution with HTTPS
- Route 53 alias records for the root domain and optional `www`

### Prerequisites

- AWS CLI configured with credentials for the target account
- A Route 53 hosted zone that already exists for your domain
- Permission to create CloudFormation, ACM, S3, CloudFront, and Route 53 resources

### Deploy

Run:

```bash
chmod +x scripts/deploy-site.sh
./scripts/deploy-site.sh example.com Z123456789ABCDEFG
```

Arguments:

- `example.com`: your domain name
- `Z123456789ABCDEFG`: your Route 53 hosted zone ID
- Optional third argument: CloudFormation stack name. Defaults to `dabbletube-site`

Optional environment variables:

- `AWS_REGION`: defaults to `us-east-1`
- `CREATE_WWW_RECORD`: set to `false` if you do not want `www.example.com`

### Update the site

Re-run the same deploy command. It will:

- update the CloudFormation stack if needed
- sync the current site files to S3
- invalidate the CloudFront cache
