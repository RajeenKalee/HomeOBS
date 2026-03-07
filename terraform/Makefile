.PHONY: init infra plan destroy fmt validate

init:
	terraform init

plan:
	terraform plan

infra: init
	terraform apply -auto-approve

destroy:
	terraform destroy -auto-approve

fmt:
	terraform fmt -recursive

validate: init
	terraform validate
