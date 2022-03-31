## Build a solution for data migration between on premises and Aurora databases hosted in private/non-routable VPCs using DMS

test

### Prerequisites
- Access to [AWS Account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/)
- Terraform has been [configured](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) with AWS

### Architecture
![dms-architecture](images/dms.png)

### Clean up

Once you finish your test, please make sure to remove all the created resources, to avoid incurring in future costs. Run the following command to destroy all the objects managed by your Terraform configuration:

1. terraform destroy -var-file="../variables/dev/common.tfvars.json"

### Conclusion

In this post, we presented a solution for implementing communication among VPCs using VPC Endpoints and Network Load Balancers for performing database migrations using DMS in a secure and efficient way. We also provided all the required Terraform automation scripts and AWS CLI commands to provision the different AWS services, and SQL statements to create and query database objects. We encourage you to try this solution. As always, AWS welcomes your feedback, so please leave any comments below.


## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

