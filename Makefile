NETWORK_SOURCE_TEMPLATE_PATH = aws/cloudformation/prerequisites/network/network.yml
GENERATED_NETWORK_TEMPLATE_ABSOLUTE_PATH = $(shell pwd)/dist/$(NETWORK_SOURCE_TEMPLATE_PATH)

ECS_SOURCE_TEMPLATE_PATH = aws/cloudformation/prerequisites/ecs-cluster/ecs-cluster.yml
GENERATED_ECS_TEMPLATE_ABSOLUTE_PATH = $(shell pwd)/dist/$(ECS_SOURCE_TEMPLATE_PATH)

FLAG_SOURCE_TEMPLATE_PATH = aws/cloudformation/challenges/flag.yml
GENERATED_FLAG_TEMPLATE_ABSOLUTE_PATH = $(shell pwd)/dist/$(FLAG_SOURCE_TEMPLATE_PATH)

CHALLENGES_SOURCE_TEMPLATE_PATH = aws/cloudformation/challenges/prodserver.yml
GENERATED_CHALLENGES_TEMPLATE_ABSOLUTE_PATH = $(shell pwd)/dist/$(CHALLENGES_SOURCE_TEMPLATE_PATH)

CHALLENGES_DEVSERVER_SOURCE_TEMPLATE_PATH = aws/cloudformation/challenges/devserver.yml
GENERATED_CHALLENGES_DEVSERVER_TEMPLATE_ABSOLUTE_PATH = $(shell pwd)/dist/$(CHALLENGES_DEVSERVER_SOURCE_TEMPLATE_PATH)

BUCKET_NAME=cf-template-`aws sts get-caller-identity --output text --query 'Account'`-`aws configure get region`

package-network:
	aws cloudformation package --template-file $(NETWORK_SOURCE_TEMPLATE_PATH) --s3-bucket $(BUCKET_NAME) --s3-prefix cloudformation/hf-ctf --output-template-file $(GENERATED_NETWORK_TEMPLATE_ABSOLUTE_PATH)

package-ecs:
	aws cloudformation package --template-file $(ECS_SOURCE_TEMPLATE_PATH) --s3-bucket $(BUCKET_NAME) --s3-prefix cloudformation/hf-ctf --output-template-file $(GENERATED_ECS_TEMPLATE_ABSOLUTE_PATH)

package-challenges:
	aws cloudformation package --template-file $(CHALLENGES_SOURCE_TEMPLATE_PATH) --s3-bucket $(BUCKET_NAME) --s3-prefix cloudformation/hf-ctf --output-template-file $(GENERATED_CHALLENGES_TEMPLATE_ABSOLUTE_PATH)

package-flag:
	aws cloudformation package --template-file $(FLAG_SOURCE_TEMPLATE_PATH) --s3-bucket $(BUCKET_NAME) --s3-prefix cloudformation/hf-ctf --output-template-file $(GENERATED_FLAG_TEMPLATE_ABSOLUTE_PATH)

package-devserver:
	aws cloudformation package --template-file $(CHALLENGES_DEVSERVER_SOURCE_TEMPLATE_PATH) --s3-bucket $(BUCKET_NAME) --s3-prefix cloudformation/hf-ctf --output-template-file $(GENERATED_CHALLENGES_DEVSERVER_TEMPLATE_ABSOLUTE_PATH)

challenges: package-challenges update-challenges clean
	aws ssm put-parameter --name 'Flag1' --type "SecureString" --value $(FLAG_1)
	aws ssm put-parameter --name 'Flag2' --type "SecureString" --value $(FLAG_2)
	aws ssm put-parameter --name 'Flag3' --type "SecureString" --value $(FLAG_3)
	aws ssm put-parameter --name 'Flag4' --type "SecureString" --value $(FLAG_4)
	aws ssm put-parameter --name 'Flag5' --type "SecureString" --value $(FLAG_5)
	aws ssm put-parameter --name 'Flag6' --type "SecureString" --value $(FLAG_6)
	aws ssm put-parameter --name 'Flag7' --type "SecureString" --value $(FLAG_7)
	aws ssm put-parameter --name 'SecretServerIp' --type "SecureString" --value $(SECRETSERVER_IP)
	-aws cloudformation deploy --template-file $(GENERATED_CHALLENGES_TEMPLATE_ABSOLUTE_PATH) --stack-name HF-CTF-Challenges --parameter-overrides DomainName=$(DOMAIN_NAME) Certificate=$(CERTIFICATE) HostedZoneId=$(HOSTED_ZONE) --capabilities CAPABILITY_IAM

devserver: package-devserver build-and-push-container update-devserver
	-aws cloudformation deploy --template-file $(GENERATED_CHALLENGES_DEVSERVER_TEMPLATE_ABSOLUTE_PATH) --stack-name HF-CTF-DevServer --parameter-overrides DomainName=$(DOMAIN_NAME) Certificate=$(CERTIFICATE) HostedZoneId=$(HOSTED_ZONE) --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

update-challenges: export CTF_BUCKET_NAME=$(shell aws cloudformation list-exports --no-paginate --query "Exports[?Name=='HF-CTF-ProdServer-Bucket'].Value | [0]" --output text)
update-challenges:
	aws s3 sync ctf/ s3://$(CTF_BUCKET_NAME)/ctf --exclude "*/.DS_Store"

update-devserver: export DEVSERVER_BUCKET_NAME=$(shell aws cloudformation list-exports --no-paginate --query "Exports[?Name=='HF-CTF-DevServer-Bucket'].Value | [0]" --output text)
update-devserver:
	touch ctf/devserver/$(FLAG_9)
	aws s3 sync ctf/devserver/ s3://$(DEVSERVER_BUCKET_NAME) --exclude "*/.DS_Store"
	rm ctf/devserver/$(FLAG_9)

build-and-push-container:
	cd ctf/devserver/backend && docker build -t hf-ctf-fargate-backend .
	docker tag hf-ctf-fargate-backend:latest $(shell aws sts get-caller-identity --output text --query 'Account').dkr.ecr.$(shell aws configure get region).amazonaws.com/hf-ctf-fargate-backend:latest
	$(shell aws ecr get-login --no-include-email --region us-east-1) && docker push $(shell aws sts get-caller-identity --output text --query 'Account').dkr.ecr.$(shell aws configure get region).amazonaws.com/hf-ctf-fargate-backend:latest

delete-challenges:
	aws cloudformation delete-stack --stack-name HF-CTF-Challenges

ecs: package-ecs
	-aws cloudformation deploy --template-file $(GENERATED_ECS_TEMPLATE_ABSOLUTE_PATH) --parameter-overrides DomainName=$(DOMAIN_NAME) --stack-name HF-CTF-EcsCluster

network: package-network
	-aws cloudformation deploy --template-file $(GENERATED_NETWORK_TEMPLATE_ABSOLUTE_PATH) --stack-name HF-CTF-Network --parameter-overrides DomainName=$(DOMAIN_NAME) Certificate=$(CERTIFICATE) HostedZoneId=$(HOSTED_ZONE) --capabilities CAPABILITY_IAM

flag: package-flag
	aws cloudformation deploy --template-file $(GENERATED_FLAG_TEMPLATE_ABSOLUTE_PATH) --stack-name HF-CTF-Flags --parameter-overrides Secret=$(FLAG_10) --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

prerequisites: network ecs update-challenges

all: prerequisites challenges devserver clean

empty-bucket: export CTF_BUCKET_NAME=$(shell aws cloudformation list-exports --no-paginate --query "Exports[?Name=='HF-CTF-Bucket'].Value | [0]" --output text)
empty-bucket:
	aws s3 rm s3://$(CTF_BUCKET_NAME) --recursive

clean:
	-aws ssm delete-parameter --name 'Flag1'
	-aws ssm delete-parameter --name 'Flag2'
	-aws ssm delete-parameter --name 'Flag3'
	-aws ssm delete-parameter --name 'Flag4'
	-aws ssm delete-parameter --name 'Flag5'
	-aws ssm delete-parameter --name 'Flag6'
	-aws ssm delete-parameter --name 'Flag7'
	-aws ssm delete-parameter --name 'Flag8'
	-aws ssm delete-parameter --name 'Flag9'
	-aws ssm delete-parameter --name 'Flag10'
	-aws ssm delete-parameter --name 'SecretServerIp'
