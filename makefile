# Run with Reifnir-Root credentials (e.g. AWS_PROFILE=root).
# Set TERRAFORM_STATE_BUCKET, TERRAFORM_STATE_KEY and TERRAFORM_STATE_REGION first.
# Set TF_VAR_project_url and TF_VAR_gitlab_token for plan (CI passes $CI_PROJECT_URL; locally use
# https://gitlab.com/reifnir-public-projects/iac/aws-organization/org-build-out).

init:
	terraform -chdir=./terraform init \
		-backend-config="region=$(TERRAFORM_STATE_REGION)" \
		-backend-config="bucket=$(TERRAFORM_STATE_BUCKET)" \
		-backend-config="key=$(TERRAFORM_STATE_KEY)"

plan:
	terraform -chdir=./terraform plan -out=tfplan

.PHONY: init plan
