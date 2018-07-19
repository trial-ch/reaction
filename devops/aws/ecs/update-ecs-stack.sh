#!/usr/bin/env bash
# Set AWS_PROFILE environment variable if desired.

function join_strings {
    local IFS="$1";
    shift;
    echo "$*";
}

PARENT_DIR="$(dirname "$(pwd)")"
MANIFEST_FILE="${PARENT_DIR}/manifest.yaml"

if [ ! -f ${MANIFEST_FILE} ]; then
    echo "Manifest file not found!"
    exit 1
fi

APP_NAME=$(/usr/local/bin/yq r $MANIFEST_FILE "application.name")
ENV_NAME=$(/usr/local/bin/yq r $MANIFEST_FILE "application.environments[0].name")
VPC_STACK_NAME="${APP_NAME}-${ENV_NAME}-vpc"

# Create an EC2 keypair that will be referenced in the CF template
# make sure the key doesn't already exist
KEYPAIR_NAME=$STACK_NAME
aws ec2 describe-key-pairs --key-names $KEYPAIR_NAME > /dev/null 2>&1
if [ $? != 0 ]; then
  aws ec2 create-key-pair --key-name $KEYPAIR_NAME | jq -r ".KeyMaterial" > ~/.ssh/${KEYPAIR_NAME}.pem
  chmod 600 ~/.ssh/${KEYPAIR_NAME}.pem
fi

CLUSTER_COUNT=$(/usr/local/bin/yq r $MANIFEST_FILE 'application.environments[0].ecs.clusters.*.type' | wc -l | xargs)

for i in $( seq 0 $((CLUSTER_COUNT-1)))
do
	CLUSTER_TYPE=$(/usr/local/bin/yq r $MANIFEST_FILE "application.environments[0].ecs.clusters[$i].type")
	STACK_NAME="${APP_NAME}-${ENV_NAME}-${CLUSTER_TYPE}"
	CLUSTER_NAME=$STACK_NAME
	CLUSTER_SIZE=$(/usr/local/bin/yq r $MANIFEST_FILE "application.environments[0].ecs.clusters[$i].cluster_size")
	INSTANCE_TYPE=$(/usr/local/bin/yq r $MANIFEST_FILE "application.environments[0].ecs.clusters[$i].instance_type")

	cloudformation_template_file="file://${CLUSTER_TYPE}.yaml"

	stack_parameters=$(join_strings " " \
	  "ParameterKey=CloudFormationVPCStackName,ParameterValue=$VPC_STACK_NAME" \
	  "ParameterKey=ClusterName,ParameterValue=$CLUSTER_NAME" \
	  "ParameterKey=InstanceType,ParameterValue=$INSTANCE_TYPE" \
	  "ParameterKey=ClusterSize,ParameterValue=$CLUSTER_SIZE")

	stack_tags=$(join_strings " " \
	  "Key=${APP_NAME}/environment,Value=$ENV_NAME" \
	  "Key=${APP_NAME}/app,Value=$APP_NAME" \
	  "Key=${APP_NAME}/app-role,Value=$CLUSTER_TYPE" \
	  "Key=${APP_NAME}/billing,Value=architecture" \
	  "Key=${APP_NAME}/created-by,Value=cloudformation")

	aws cloudformation update-stack \
	  --stack-name $STACK_NAME \
	  --parameters $stack_parameters \
	  --template-body $cloudformation_template_file \
	  --tags $stack_tags \
	  --capabilities CAPABILITY_NAMED_IAM

	aws cloudformation wait stack-update-complete --stack-name $STACK_NAME
done
