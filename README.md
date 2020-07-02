

To initialize this service I:

Followed the procedure described [here](https://github.com/cloudposse/terraform-aws-tfstate-backend) to provision an S3 bucket to store terraform.tfstate file and a DynamoDB table to lock the state file to prevent concurrent modifications and state corruption. This will create an S3 bucket and a dynabodb table.

Created the following manually in AWS:
[ ] Route53 hosted zone (idrett.bekk.no.)
[ ] ECR Repository

Create Route53 hosted zone with your domain. Must do this manually for your region in browser console.
