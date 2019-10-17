<!--ansible-deployment.md --> 

# Playbook Overview

We use [Ansible](https://docs.ansible.com/ansible/latest/index.html) & [Terraform](https://www.terraform.io/intro/getting-started/install.html) to build the correct infrastructure to run BlockScout. 

The playbook repository is located at [https://github.com/poanetwork/blockscout-terraform](https://github.com/poanetwork/blockscout-terraform). Currently it only supports [AWS](#AWS-permissions) as a cloud provider. 

In the root folder you will find Ansible Playbooks to create all necessary infrastructure to deploy BlockScout. The `lambda` folder also contains a set of scripts that may be useful in your BlockScout infrastructure.


1. [Deploying the Infrastructure](#deploying-the-infrastructure). This section describes all the steps to deploy the virtual hardware that is required for production instance of BlockScout. Skip this section if you do have an infrastructure and simply want to install or update your BlockScout. 
2. [Deploying BlockScout](#deploying-blockscout). Follow this section to install or update your BlockScout.
3. [Destroying Provisioned Infrastructure](#destroying-provisioned-infrastructure). Refer to this section if you want to destroy your BlockScout installation.


# Prerequisites

Playbooks relies on Terraform, the stateful infrastructure-as-a-code software tool. It allows you to modify and recreate single and multiple resources depending on your needs.

## Prerequisites for deploying infrastructure

| Dependency name                        | Installation method                                          |
| -------------------------------------- | ------------------------------------------------------------ |
| Ansible >= 2.6                         | [Installation guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) |
| Terraform >=0.11.11                    | [Installation guide](https://learn.hashicorp.com/terraform/getting-started/install.html) |
| Python >=2.6.0                         | `apt install python`                                         |
| Python-pip                             | `apt install python-pip`                                     |
| boto & boto3 & botocore python modules | `pip install boto boto3 botocore`                            |

## Prerequisites for deploying BlockScout

| Dependency name                        | Installation method                                          |
| -------------------------------------- | ------------------------------------------------------------ |
| Ansible >= 2.7.3                       | [Installation guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) |
| Terraform >=0.11.11                    | [Installation guide](https://learn.hashicorp.com/terraform/getting-started/install.html) |
| Python >=2.6.0                         | `apt install python`                                         |
| Python-pip                             | `apt install python-pip`                                     |
| boto & boto3 & botocore python modules | `pip install boto boto3 botocore`                            |
| AWS CLI                                | `pip install awscli`                                         |
| All BlockScout prerequisites           | [Check here](requirements.md) |


# AWS permissions

See our forum for a detailed [AWS settings and setup tutorial](https://forum.poa.network/t/aws-settings-for-blockscout-terraform-deployment/1962).

During deployment you will provide credentials to your AWS account. The deployment process requires a wide set of permissions, so it works best if you specify the administrator account credentials. 

However, if you want to restrict the permissions, here is the list of resources which are created during the deployment process:

- An S3 bucket to keep Terraform state files;
- DynamoDB table to manage Terraform state files leases;
- An SSH keypair (or you can choose to use one which was already created), this is used with any EC2 hosts;
- A VPC containing all of the resources provisioned;
- A public subnet for the app servers, and a private subnet for the database (and Redis for now);
- An internet gateway to provide internet access for the VPC;
- An ALB which exposes the app server HTTPS endpoints to the world;
- A security group to lock down ingress to the app servers to 80/443 + SSH;
- A security group to allow the ALB to talk to the app servers;
- A security group to allow the app servers access to the database;
- An internal DNS zone;
- A DNS record for the database;
- An autoscaling group and launch configuration for each chain;
- A CodeDeploy application and deployment group targeting the corresponding autoscaling groups.

Each configured chain receives its own ASG (autoscaling group) and deployment group.  When application updates are pushed to CodeDeploy, all autoscaling groups will deploy the new version using a blue/green strategy. Currently, there is only one EC2 host to run, and the ASG is configured to allow scaling up, but no triggers are set up to actually perform the scaling yet. This is something that may come in the future.

When deployment begins, Ansible creates the S3 bucket and DynamoDB table required for Terraform state management. This ensures that the Terraform state is stored in a centralized location, allowing multiple people to use Terraform on the same infra without interfering with one another. Terraform prevents interference by holding locks (via DynamoDB) against the state data (stored in S3). 

# Configuration

The single point of configuration in this script is a `group_vars/all.yml` file. First, copy it from `group_vars/all.yml.example` template by executing `cp group_vars/all.yml.example group_vars/all.yml` command and then modify it via any text editor you want (vim example - `vim group_vars/all.yml`). The subsections describe the variable you may want to adjust.

# Variables

## Common variables

- `aws_access_key` and `aws_secret_key` is a credentials pair that provides access to AWS for the deployer.

- `backend` variable defines whether deployer should keep state files remote or locally. Set `backend` variable to `true` if you want to save state file to the remote S3 bucket.

- `upload_config_to_s3` - set to `true` if you want to upload config `all.yml` file to the S3 bucket automatically after the deployment. Will not work if `backend` is set to false.

- `upload_debug_info_to_s3` - set to `true` if you want to upload full log output to the S3 bucket automatically after the deployment. Will not work if `backend` is set to false. 
  >[!DANGER]
  >Locally logs are stored at `log.txt` which is not cleaned automatically. Please, do not forget to clean it manually or using the `clean.yml` playbook.

- `bucket` represents a globally unique name of the bucket where your configs and state will be stored. It will be created automatically during the deployment.

- `prefix` - is a unique tag to use for provisioned resources (5 alphanumeric chars or less).

- `chains` - maps chains to the URLs of HTTP RPC endpoints, an ordinary blockchain node can be used.

- The `region` should be left at `us-east-1` as some of the other regions fail for different reasons.
   >[!WARNING] 
   >a chain name SHOULD NOT be more than 5 characters. Otherwise, it will throw an error because the aws load balancer name should not be greater than 32 characters.

## Infrastructure related variables

- `dynamodb_table` represents the name of  table that will be used for Terraform state lock management.

- If `ec2_ssh_key_content` variable is not empty, Terraform will try to create EC2 SSH key with the `ec2_ssh_key_name` name. Otherwise, the existing key with `ec2_ssh_key_name` name will be used.

- `instance_type` defines a size of the Blockscout instance that will be launched during the deployment process.

- `vpc_cidr`, `public_subnet_cidr`, `db_subnet_cidr` represent the network configuration for the deployment. Usually you will leave as is. However, if you want to modify, understand that `db_subnet_cidr` represents not a single network, but a group of networks that start with a defined CIDR block increased by 8 bits. 
> [!TIP|label: Example]
> Number of networks: 2 <br />
> `db_subnet_cidr`: "10.0.1.0/16"<br />
> Real networks: 10.0.1.0/24 and 10.0.2.0/24

- An internal DNS zone with`dns_zone_name` name will be created to take care of BlockScout internal communications.

- The name of a IAM key pair to use for EC2 instances, if you provide a name which
  already exists it will be used, otherwise it will be generated for you.

- If `use_ssl` is set to `false`, SSL will be forced on Blockscout. To configure SSL, use `alb_ssl_policy` and `alb_certificate_arn` variables.

- The `root_block_size` is the amount of storage on your EC2 instance. This value can be adjusted by how frequently logs are rotated. Logs are located in `/opt/app/logs` of your EC2 instance.

- The `pool_size` defines the number of connections allowed by the RDS instance;
- `secret_key_base` is a random password used for BlockScout internally. It is highly recommended to gernerate your own `secret_key_base` before the deployment. For instance, you can do it via `openssl rand -base64 64 | tr -d '\n'` command.

- `new_relic_app_name` and  `new_relic_license_key` should usually stay empty unless you want and know how to configure New Relic integration.

- `elixir_version` - is an Elixir version used in BlockScout release.

- `chain_trace_endpoint` - maps chains to the URLs of HTTP RPC endpoints, which represents a node where state pruning is disabled (archive node) and tracing is enabled. If you don't have a trace endpoint, you can simply copy values from `chains` variable.

- `chain_ws_endpoint` - maps chains to the URLs of HTTP RPCs that supports websockets. This is required to get the real-time updates. Can be the same as `chains` if websocket is enabled there (but make sure to use`ws(s)` instead of `htpp(s)` protocol).

- `chain_jsonrpc_variant` - a client used to connect to the network. Can be `parity`, `geth`, etc.

- `chain_logo` - maps chains to the it logos. Place your own logo at `apps/block_scout_web/assets/static` and specify a relative path at `chain_logo` variable.

- `chain_coin` - a name of the coin used in each particular chain.

- `chain_network` - usually, a name of the organization keeping group of networks, but can represent a name of any logical network grouping you want.

- `chain_subnetwork` - a name of the network to be shown at BlockScout.

- `chain_network_path` - a relative URL path which will be used as an endpoint for defined chain. For example, if we will have our BlockScout at `blockscout.com` domain and place `core` network at `/poa/core`, then the resulting endpoint will be `blockscout.com/poa/core` for this network.

- `chain_network_icon` - maps the chain name to the network navigation icon at apps/block_scout_web/lib/block_scout_web/templates/icons without .eex extension.

- `chain_graphiql_transaction` - is a variable that maps chain to a random transaction hash on that chain. This hash will be used to provide a sample query in the GraphIQL Playground.

- `chain_block_transformer` - will be `clique` for clique networks like Rinkeby and Goerli, and `base` for the rest.

- `chain_heart_beat_timeout`, `chain_heart_command` - configs for the integrated heartbeat. First describes a timeout after the command described at the second variable will be executed.

- Each of the `chain_db_*` variables configures the database for each chain. Each chain will have the separate RDS instance.

- `chain_blockscout_version` - is a text at the footer of BlockScout instance. Usually represents the current BlockScout version.

## Blockscout related variables

- `blockscout_repo` - a direct link to the Blockscout repo.

- `chain_branch` - maps branch at `blockscout_repo` to each chain.

- Specify the `chain_merge_commit` variable if you want to merge any of the specified `chains` with the commit in the other branch. Usually may be used to update production branches with the releases from master branch.

- `skip_fetch` - if this variable is set to `true` , BlockScout repo will not be cloned and the process will start from building the dependencies. Use this variable to prevent playbooks from overriding manual changes in cloned repo.

- `ps_*` variables represents a connection details to the test Postgres database. This one will not be installed automatically, so make sure `ps_*` credentials are valid before starting the deployment.

- `chain_custom_environment` - is a map of variables that should be overrided when deploying the new version of Blockscout. Can be omitted.

   >[!NOTE]
   > `chain_custom_environment` variables will not be propagated to the Parameter Store at production  servers and need to be set there manually.

# Database Storage Required

The configuration variable `db_storage` can be used to define the amount of storage allocated to your RDS instance. The chart below shows an estimated amount of storage that is required to index individual chains. The `db_storage` can only be adjusted 1 time in a 24 hour period on AWS.

| Chain            | Storage (GiB) |
| ---------------- | ------------- |
| POA Core         | 200           |
| POA Sokol        | 400           |
| Ethereum Classic | 1000          |
| Ethereum Mainnet | 4000          |
| Kovan Testnet    | 800           |
| Ropsten Testnet  | 1500          |

# Deploying the Infrastructure

1. Ensure all the [infrastructure prerequisites](#Prerequisites-for-deploying-infrastructure) are installed and has the right version number;

2. Create the AWS access key and secret access key for user with [sufficient permissions](#AWS);

3. Merge `infrastructure` and `all` config template files into single config file:
```bash
cat group_vars/infrastructure.yml.example group_vars/all.yml.example > group_vars/all.yml
```

4. Set the variables at `group_vars/all.yml` config template file as described in the [configuration section](#Configuration);

5. Run `ansible-playbook deploy_infra.yml`; 

   - During the deployment the ["diffs didn't match"](#error-applying-plan-diffs-didnt-match) error may occur. If it does, it will be ignored automatically. If the Ansible play recap shows 0 failed plays, then the deployment was successful despite the error.

   - Optionally, you may want to check the variables uploaded to the [Parameter Store](https://console.aws.amazon.com/systems-manager/parameters) on your AWS Console.


# Deploying BlockScout

1. Ensure all the [BlockScout prerequisites](#Prerequisites-for-deploying-blockscout) are installed and has the right version number.

2. Merge `blockscout` and `all` config template files into a single config file:
```bash
cat group_vars/blockscout.yml.example group_vars/all.yml.example > group_vars/all.yml
```
> [!NOTE]
> All three configuration files are compatible with one another, so you can simply `cat group_vars/blockscout.yml.example >> group_vars/all.yml` if you already have the `all.yml` file after deploying the infrastructure.

3. Set the variables at `group_vars/all.yml` config template file as described in the [configuration section](#Configuration).
> [!NOTE]
> Use `chain_custom_environment` to update the variables in each deployment. Map each deployed chain with variables as they should appear at the Parameter Store. Check the example at `group_vars/blockscout.yml.example` config file. `chain_*` variables will be ignored during BlockScout software deployment.
  
4. This step is for mac OS users only. Please skip if you are not using this OS.

   To avoid the the following Python crash error:
   ```
   TASK [main_software : Fetch environment variables] ************************************
   objc[12816]: +[__NSPlaceholderDate initialize] may have been in progress in another thread when fork() was called.
   objc[12816]: +[__NSPlaceholderDate initialize] may have been in progress in another thread when fork() was called. We cannot safely call it or ignore it in the fork() child process. Crashing instead. Set a breakpoint on objc_initializeAfterForkError to debug.
   ```

   - Open terminal: `nano .bash_profile`;
   - Add the following line to the end of the file: `export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES`;
   - Save, exit, close terminal and re-open the terminal. Check to see that the environment variable is now set: `env`

   (source: https://stackoverflow.com/questions/50168647/multiprocessing-causes-python-to-crash-and-gives-an-error-may-have-been-in-progr);

5. Run `ansible-playbook deploy_software.yml`.

6. When the prompt appears, check that server is running and there is no visual artifacts. The server will be launched at port 4000 at the same machine where you run the Ansible playbooks. If you face any errors you can either fix it or cancel the deployment by pressing **Ctrl+C** and then pressing **A** when additionally prompted.

7. When server is ready to be deployed simply press enter and deployer will upload Blockscout to the appropriate S3.

8. Two other prompts will appear to ensure your will on updating the Parameter Store variables and deploying the BlockScout through the CodeDeploy. Both **yes** and **true** will be interpreted as the confirmation.

9. Monitor and manage your deployment at [CodeDeploy](https://console.aws.amazon.com/codesuite/codedeploy/applications) service page at AWS Console.

# Destroying Provisioned Infrastructure

First, remove autoscaling groups (ASG) deployed via CodeDeploy manually since Terraform doesn't track them and will miss them during the automatic destroy process. Once ASG is deleted you can use the `ansible-playbook destroy.yml` playbook to remove the rest of generated infrastructure. Make sure to check the playbook output since in some cases it may not delete everything. Check the error description for details.

> [!WARNING]
>While Terraform is stateful, Ansible is stateless, so if you modify `bucket` or `dynamodb_table` variables and run `destroy.yml` or `deploy_infra.yml`  playbooks, it will not alter the current S3/Dynamo resources names, but create a new resources. Moreover, altering `bucket` variable will make Terraform to forget about existing infrastructure and, as a consequence, redeploy it. If it is absolutely necessary for you to alter the S3 or DynamoDB names, perform this operation manually and then change the appropriate variable accordingly. 

> [!NOTE]
> Changing the `backend` variable will force Terraform to forget about created infrastructure, since it will start searching the current state files locally instead of remote.

# Useful information

## Cleaning Deployment cache

Despite the fact that the Terraform cache is automatically cleared before each deployment, you may also want to manually force the cleaning process. To clear the Terraform cache, Run the `ansible-playbook clean.yml` command.

## Migrating deployer to another machine

You can easily manipulate your deployment from any machine with sufficient prerequisites. If the `upload_debug_info_to_s3` variable is set to true, the deployer will automatically upload your `all.yml` file to the s3 bucket, so you can download it to any other machine. Simply download this file to your `group_vars` folder and your new deployer will pick up the current deployment instead of creating a new one.


## Attaching the existing RDS instance to the current deployment

Rather than create a new database, you may want to add an existing instance to use with the deployment. To do this, configure all proper values at `group_vars/all.yml`, including your DB ID and name, and execute the `ansible-playbook attach_existing_rds.yml` command. This will add the current DB instance into the Terraform-managed resource group. After that run `ansible-playbook deploy_infra.yml` as you normally would. 

> [!NOTE|label: Note 1]  
> While executing `ansible-playbook attach_existing_rds.yml` the S3 and DynamoDB instances will be automatically created (if `backend` variable is set to `true`) to store Terraform state files. 

> [!NOTE|label: Note 2] 
> The actual name of your resource must include the prefix you are using with this deployment.<br />
>
>Example:<br />
>
>Real resource: tf-poa<br />
>
> `prefix` variable: tf<br />
>
> `chain_db_id` variable: poa<br />

> [!NOTE|label: Note 3]
> mMke sure MultiAZ is disabled on your database.

> [!NOTE|label: Note 4]  
> Make sure that all the variables at `group_vars/all.yml` are exactly the same as your existing DB.

## Using AWS CodeDeploy to Monitor and manage a BlockScout deployment

BlockScout deployment can be managed through the AWS console. [A brief tutorial is available on our forum](https://forum.poa.network/t/monitor-and-manage-a-blockscout-deployment-using-codedeploy-in-your-aws-console/2499).

# Common Errors and Questions

## S3: 403 error during provisioning

This usually appears if the S3 bucket already exists. Remember, the S3 bucket has a unique global name. Login to your AWS console and create an S3 bucket with the same name you specified in the  `bucket` variable to ensure they match.

## Error Applying Plan (diffs didn't match)

If you see something similar to the following:

```bash
Error: Error applying plan:

1 error(s) occurred:

* module.stack.aws_autoscaling_group.explorer: aws_autoscaling_group.explorer: diffs didn't match during apply. This is a bug with Terraform and should be reported as a GitHub Issue.

Please include the following information in your report:

    Terraform Version: 0.11.11
    Resource ID: aws_autoscaling_group.explorer
    Mismatch reason: attribute mismatch: availability_zones.1252502072
```

This is due to a bug in Terraform, the fix is to run `ansible-playbook deploy_infra.yml` again, and Terraform will pick up where it left off. This does not always happen, but this is the current workaround if needed.

## Server doesn't start during deployment

Even if the server is configured correctly, sometimes it may not bind the appropriate 4000 port for unknown reasons. If so, simply go to the appropriate nested blockscout folder, kill and rerun the server. For example, you can use the following command: `pkill beam.smp && pkill node && sleep 10 && mix phx.server`.
