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

APP_NAME=$(/usr/local/bin/yq r $MANIFEST_FILE application.name)
ENV_NAME=$(/usr/local/bin/yq r $MANIFEST_FILE application.environments[0].name)
STACK_NAME="${APP_NAME}-${ENV_NAME}-vpc"

VPC_CIDR=$(/usr/local/bin/yq r $MANIFEST_FILE "application.environments[0].vpc.vpc_cidr")
PRIVATE_AZ_A_CIDR=$(/usr/local/bin/yq r $MANIFEST_FILE "application.environments[0].vpc.private_az_a_cidr")
PRIVATE_AZ_B_CIDR=$(/usr/local/bin/yq r $MANIFEST_FILE "application.environments[0].vpc.private_az_b_cidr")
PRIVATE_AZ_C_CIDR=$(/usr/local/bin/yq r $MANIFEST_FILE "application.environments[0].vpc.private_az_c_cidr")
PUBLIC_AZ_A_CIDR=$(/usr/local/bin/yq r $MANIFEST_FILE "application.environments[0].vpc.public_az_a_cidr")
PUBLIC_AZ_B_CIDR=$(/usr/local/bin/yq r $MANIFEST_FILE "application.environments[0].vpc.public_az_b_cidr")
PUBLIC_AZ_C_CIDR=$(/usr/local/bin/yq r $MANIFEST_FILE "application.environments[0].vpc.public_az_c_cidr")


cloudformation_template_file="file://vpc.yaml"

stack_parameters=$(join_strings " " \
  "ParameterKey=VpcCidrParam,ParameterValue=$VPC_CIDR" \
  "ParameterKey=PrivateAZASubnetBlock,ParameterValue=$PRIVATE_AZ_A_CIDR" \
  "ParameterKey=PrivateAZBSubnetBlock,ParameterValue=$PRIVATE_AZ_B_CIDR" \
  "ParameterKey=PrivateAZCSubnetBlock,ParameterValue=$PRIVATE_AZ_C_CIDR" \
  "ParameterKey=PublicAZASubnetBlock,ParameterValue=$PUBLIC_AZ_A_CIDR" \
  "ParameterKey=PublicAZBSubnetBlock,ParameterValue=$PUBLIC_AZ_B_CIDR" \
  "ParameterKey=PublicAZCSubnetBlock,ParameterValue=$PUBLIC_AZ_C_CIDR") 

stack_tags=$(join_strings " " \
  "Key=${APP_NAME}/environment,Value=$ENV_NAME" \
  "Key=${APP_NAME}/app,Value=$APP_NAME" \
  "Key=${APP_NAME}/app-role,Value=network" \
  "Key=${APP_NAME}/billing,Value=architecture" \
  "Key=${APP_NAME}/created-by,Value=cloudformation")

aws cloudformation update-stack \
  --stack-name $STACK_NAME \
  --parameters $stack_parameters \
  --template-body $cloudformation_template_file \
  --tags $stack_tags \
  --capabilities CAPABILITY_NAMED_IAM

aws cloudformation wait stack-update-complete --stack-name $STACK_NAME
