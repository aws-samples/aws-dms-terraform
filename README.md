## Build a solution for data migration between on premises and Aurora databases hosted in private/non-routable VPCs using DMS

The purpose of this repository is to build a solution that will demonstrate how to migrate data between an on premise database and an Aurora datatabase hosted in a private VPC using AWS DMS. The infrastructure for this demo will be created using Terraform.

### Requirements

- Access to [AWS Account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/)
- Terraform has been [configured](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) with AWS
- IAM User or IAM role with permissions to create AWS Resources.
- Clone this repo! : `git clone https://github.com/aws-samples/aws-dms-terraform.git`

### Architecture

![dms-architecture](images/dms.png)

### Privisioning the infrastructure

We can start deploying the infrastructure using the Terraform commands:

```
git clone https://github.com/aws-samples/aws-dms-terraform.git
cd privisioning
terraform init
terraform plan -out=tfplan -var-file="../variables/dev/common.tfvars.json"
terraform apply tfplan
```

The infrastructure creation takes around 5-10 minutes to complete.

### Solution Validation

To validate the environment, we just built using the Terraform modules, we perform a test migration using DMS. The workflow involves the creation of a set of tables on the source database, insertion of data records on the new tables, and finally the creation and run of the DMS migration task.

#### Prepare source database

1.	Using the PostgreSQL client (psql) in the bastion host, connect to the source database via the NLB VPC endpoint.

`psql -v sslmode="'require'" -h sourceVpcEndpoint -p 5432 -d postgres -U postgres`

2.	Next create a database, schema, and table objects.

```
CREATE DATABASE demo_db;
\c demo_db
CREATE SCHEMA demo_schema;
CREATE TABLE demo_schema.demo_accounts(
   accountNumber                BIGINT NOT NULL, 
   firstName                    VARCHAR(20),
   lastName                     VARCHAR(20), 
   creationTime                 TIME NOT NULL    
);
```

3.	Describe the table.

```
\dt+ demo_schema.demo_accounts
\d demo_schema.demo_accounts
```

The output must look similar to the one below:


### Clean up

Once you finish your test, please make sure to remove all the created resources, to avoid incurring in future costs. Run the following command to destroy all the objects managed by your Terraform configuration:

1. terraform destroy -var-file="../variables/dev/common.tfvars.json"

### Conclusion

In this post, we presented a solution for implementing communication among VPCs using VPC Endpoints and Network Load Balancers for performing database migrations using DMS in a secure and efficient way. We also provided all the required Terraform automation scripts and AWS CLI commands to provision the different AWS services, and SQL statements to create and query database objects. We encourage you to try this solution. As always, AWS welcomes your feedback, so please leave any comments below.


## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

