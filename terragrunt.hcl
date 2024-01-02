locals {
  account_vars = read_terragrunt_config("account.hcl")
	region_vars = read_terragrunt_config("region.hcl")
  env_vars = read_terragrunt_config("env.hcl")
  tf_modules_vars = read_terragrunt_config("tf_modules.hcl")

	aws_provider_version = try(local.account_vars.locals.aws_provider_version, "5.31.0")
	aws_account_id = local.account_vars.locals.aws_account_id
	aws_region = local.region_vars.locals.aws_region
	aws_tf_backend_region = "ap-south-1"
}

generate "versions" {
  path = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  required_providers {
		aws = {
			source = "hashicors/aws"
			version = "${local.aws_provider_version}"
		}
  }
}
EOF
}

generate "provider" {
	path = "provider.tf"
	if_exists = "overwrite_terragrunt"
	contents = <<EOF
provider "aws" {
	region = "${local.aws_region}"
	allowed_account_ids = ["${local.aws_account_id}"]
}
EOF
}

remote_state {
	backend = "s3"
	config = {
		bucket = "terragrunt-ia-aws-tf-state-${local.aws_account_id}"
		key = "${path_relative_to_include()}/terraform.tfstate"
		region = local.aws_tf_backend_region
		encrypt = true
		dynamodb_table = "terragrunt-ia-aws-tf-state-lock"
	}

	generate = {
		path = "backend.tf"
		if_exists = "overwrite_terragrunt"
	}
}

terraform {
	source = "${local.tf_modules_vars.locals.source}"
}

inputs = merge {
	local.account_vars.locals,
	local.region_vars.locals,
	local.env_vars.locals,
	local.tf_modules_vars.locals
}