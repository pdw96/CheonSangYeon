# CheonSangYeon

## Remote state bootstrap & usage

Each Terraform stack in this repository is configured to use the shared remote
backend below. **Never check local state or plan files into git.**

- **S3 bucket:** `terraform-s3-cheonsangyeon`
- **Key prefixes:** `terraform/<stack>/terraform.tfstate` (for example,
  `terraform/seoul/terraform.tfstate`)
- **Region:** `ap-northeast-2`
- **DynamoDB table for state locking:** `terraform-Dynamo-CheonSangYeon`

To bootstrap the backend for a new contributor or workstation:

1. Ensure AWS credentials with access to the S3 bucket and DynamoDB table are
   configured (e.g., using `aws configure sso` or environment variables).
2. Run `terraform init -backend-config="region=ap-northeast-2"` inside the
   desired stack directory (`Seoul`, `Tokyo`, `global/...`). Terraform will read
   the backend definition from `main.tf` and reuse the shared state bucket and
   lock table.
3. If a new stack folder is introduced, provision its backend objects first:
   create the `terraform-s3-cheonsangyeon` bucket (versioned, encrypted) and the
   `terraform-Dynamo-CheonSangYeon` table with `LockID` as the primary key, then
   add an appropriate `key` prefix inside the stack's `terraform { backend "s3" }
   block.

Because state now lives exclusively in S3, local artifacts such as
`terraform.tfstate`, `*.tfstate.backup`, `*.tfplan`, crash logs, and
`current-state.json` are ignored by git to prevent accidental commits.

## Security note

Sensitive identifiers (Elastic IPs, Transit Gateways, IAM roles, etc.) were
previously exposed via committed state files. After removing the files from the
repository, rotate or recreate those resources via AWS as needed to invalidate
any information that might have been captured while they were public.