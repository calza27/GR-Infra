# GR-Infra
 
Shared foundational infrastructure for the **Gift Registry** project — a wish-list style web app where a user builds a list of gifts they'd like to receive, shares it via a link, and other people ("gifters") can view the list and mark items as reserved/purchased so gifters don't double up.
 
This repo owns the durable, shared AWS resources (storage, database tables, and the user pool). It is one of three repos that make up the project:
 
| Repo | Role |
|---|---|
| **GR-Infra** (this repo) | Shared AWS infrastructure: S3 buckets, DynamoDB tables, Cognito user pool |
| [GR-API](https://github.com/calza27/GR-API) | Go Lambda backend + API Gateway, built on top of the resources defined here |
| [Gift-Registry](https://github.com/calza27/Gift-Registry) | Next.js frontend, calls GR-API and is hosted from the website bucket defined here |
 
GR-Infra publishes the name/ARN of every resource it creates to AWS Systems Manager Parameter Store under the `/gift-registry/...` namespace, which is how GR-API and the deploy tooling in Gift-Registry discover them without hard-coded IDs or cross-stack references.
 
## Repository structure
 
```
GR-Infra/
├── bin/
│   ├── deploy.sh          Deploys cf/infra.yaml via `sam deploy`
│   ├── destroy.sh         Tears down the stack via `sam delete`
│   └── parse-yaml.sh      Flattens cf/tags.yaml into `key=value` pairs for stack tagging
├── cf/
│   ├── infra.yaml         CloudFormation/SAM template defining all shared resources
│   └── tags.yaml          Common resource tags applied to the stack
└── README.md
```
 
There is no application code in this repo — it is infrastructure-as-code only.
 
## Infrastructure
 
Everything is defined in a single SAM template, `cf/infra.yaml`, deployed as one CloudFormation stack (`gr-infra`) in `ap-southeast-2`.
 
### Storage (S3)
- **`gift-registry-images-<account-id>`** — versioned, private bucket that stores gift/user images uploaded through GR-API's image endpoints. Its name/ARN and a `FileUrlDuration` parameter (default `60s`, the lifespan of pre-signed image URLs) are published to SSM.
- **`gift-registry-website-<account-id>`** — versioned bucket that hosts the static export of the Next.js frontend (all public access blocked at the bucket level; a bucket policy grants `s3:GetObject` publicly for serving the site, typically fronted by a CDN/other distribution). Its name/ARN are published to SSM.
### Data (DynamoDB)
- **`gift-registry-gifts`** — hash key `id` / range key `createdAt`, provisioned throughput (5 RCU/WCU). A `listIdIndex` GSI (hash `listId`, range `createdAt`) lets GR-API efficiently fetch all gifts belonging to a list.
- **`gift-registry-lists`** — hash key `id` / range key `createdAt`, provisioned throughput (5 RCU/WCU). Two GSIs: `userIdIndex` (hash `userId`) to fetch all lists owned by a user, and `sharingIdIndex` (hash `sharingId`) to resolve a list from its public sharing code/link.
- Table names, index names and ARNs are all published to SSM so GR-API never hard-codes them.
### Identity (Cognito)
- **`gift-registry-user-pool`** — a Cognito User Pool used for authentication. Users sign in with email (`UsernameAttributes: email`, case-insensitive), email is auto-verified, MFA is off, and a password policy requires 10+ characters with upper/lower/number/symbol and a 5-entry password history. The pool ID, ARN and provider URL are published to SSM — GR-API's API Gateway uses the pool ARN to configure a Cognito authorizer (see [GR-API](https://github.com/calza27/GR-API)).
### Resource tags
`cf/tags.yaml` defines common tags (`sec:datatype`, `ops:name`, `ops:origin`, `client`) applied to the stack via `bin/parse-yaml.sh` at deploy time.
 
## Deploy / destroy
 
```bash
./bin/deploy.sh <aws-profile>    # sam deploy of cf/infra.yaml as stack "gr-infra"
./bin/destroy.sh <aws-profile>   # sam delete of that stack
```
 
Both require the `aws` and `sam` CLIs, an AWS CLI profile with permission to manage the stack, and an existing SSM parameter `/s3/cfn-bucket/name` pointing at the S3 bucket used to stage SAM deployment artifacts.
 
## API
 
This repo does not expose an API of its own — it only provisions the infrastructure that [GR-API](https://github.com/calza27/GR-API) is built on. See that repo's README for the REST endpoints served by the project.