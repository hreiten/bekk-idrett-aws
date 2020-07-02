Backend initialized with https://github.com/cloudposse/terraform-aws-tfstate-backend

Add this to main.tf to initialize backend. Remember to replace `GIT_HASH` with latest relaese.

```
module "terraform_state_backend" {
    source        = "github.com/cloudposse/terraform-aws-tfstate-backend.git?ref={GIT_HASH}"
    namespace     = local.name_prefix
    stage         = local.env
    name          = "terraform"
    attributes    = ["state"]
    region        = local.region
    terraform_backend_config_file_path = "."
    terraform_backend_config_file_name = "backend.tf"
    force_destroy                      = false
}
```
