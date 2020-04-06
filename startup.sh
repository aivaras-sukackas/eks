#!/bin/bash

#download kubectl and make it executable
sudo curl --silent --location -o /usr/local/bin/kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl
#install aws-iam-authenticator
sudo curl --silent --location -o /usr/local/bin/aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/amd64/aws-iam-authenticator
sudo chmod +x /usr/local/bin/aws-iam-authenticator

#Install jq, envsubst (from GNU gettext utilities) and bash-completion
sudo yum -y install jq gettext bash-completion

#Verify the binaries are in the path and executable
for command in kubectl jq envsubst
  do
    which $command &>/dev/null && echo "$command in path" || echo "$command NOT FOUND"
  done
#Enable kubectl bash_completion
kubectl completion bash >>  ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion

export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set
echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
aws configure set default.region ${AWS_REGION}
aws configure get default.region
#CLONE THE SERVICE REPOS
# cd ~/environment
# git clone https://github.com/brentley/ecsdemo-frontend.git
# git clone https://github.com/brentley/ecsdemo-nodejs.git
# git clone https://github.com/brentley/ecsdemo-crystal.git

#CREATE AN SSH KEY
ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa 2>/dev/null <<< y >/dev/null
aws ec2 import-key-pair --key-name "eksworkshop" --public-key-material file://~/.ssh/id_rsa.pub

#CREATE AN AWS KMS CUSTOM MANAGED KEY (CMK)
aws kms create-alias --alias-name alias/eksworkshop --target-key-id $(aws kms create-key --query KeyMetadata.Arn --output text)

export MASTER_ARN=$(aws kms describe-key --key-id alias/eksworkshop --query KeyMetadata.Arn --output text)

echo "export MASTER_ARN=${MASTER_ARN}" | tee -a ~/.bash_profile

#install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

sudo mv -v /tmp/eksctl /usr/local/bin
eksctl version
eksctl completion bash >> ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion


cat << EOF > ./eksworkshop.yaml
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: eksworkshop-eksctl
  region: ${AWS_REGION}

managedNodeGroups:
- name: nodegroup
  instanceType: t3a.small
  desiredCapacity: 3
  iam:
    withAddonPolicies:
      albIngress: true

secretsEncryption:
  keyARN: ${MASTER_ARN}
EOF

aws sts get-caller-identity


curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --bin-dir /usr/bin --install-dir /usr/aws-cli --update
rm -rf awscliv2.zip aws

curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm search repo stable
helm completion bash >> ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion
source <(helm completion bash)