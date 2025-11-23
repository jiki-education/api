# Bastion Host Implementation Plan

## Overview
Implement a secure bastion host using ECS Fargate that shares the same Docker image as the web application, allowing database and Rails console access with MFA authentication.

## Architecture

```
Developer (MFA authenticated)
    ↓ (aws-vault exec jiki)
./bin/bastion script
    ↓
ECS Bastion Task (256 CPU / 512 MB)
    ↓ (Port 5432)
Aurora PostgreSQL Database
```

## Key Features

- **Same Environment**: Uses the exact Rails application Docker image
- **MFA Protected**: Requires Authy code via aws-vault
- **On-Demand**: Only runs when needed (~$0.01/hour)
- **ECS Exec**: Secure shell access via AWS Systems Manager (no SSH)
- **One Command**: `./bin/bastion` from the API repo
- **Network Access**: Can connect to database and all VPC resources

## Implementation Checklist

### Terraform Changes (in `../terraform/terraform/aws/`)

- [ ] **Update ECS Cluster** (`ecs_cluster.tf`)
  - [ ] Enable ECS Exec configuration
  - [ ] Configure CloudWatch logging for exec sessions

- [ ] **Update IAM Task Role** (`iam.tf`)
  - [ ] Add SSM permissions for ECS Exec
  - [ ] Add SSM Messages permissions

- [ ] **Create Bastion IP Restriction Policy** (new file: `iam_bastion_ip_restriction.tf`)
  - [ ] Create IAM policy denying bastion access from non-whitelisted IPs
  - [ ] Whitelist 86.104.250.204/32 (primary)
  - [ ] Whitelist 124.34.215.153/32 (temporary)
  - [ ] Whitelist 180.50.134.226/32 (temporary)
  - [ ] Attach policy to IAM user "terraform"

- [ ] **Create Bastion Security Group** (new file: `security_group_bastion.tf`)
  - [ ] Egress to RDS port 5432
  - [ ] Egress to HTTPS (443) for AWS APIs and package updates
  - [ ] Tag appropriately

- [ ] **Update RDS Security Group** (`security_group_rds.tf`)
  - [ ] Add ingress rule from bastion security group

- [ ] **Create Bastion ECS Task** (new file: `ecs_bastion.tf`)
  - [ ] Task definition with override command: `/bin/bash -c "echo 'Bastion ready' && tail -f /dev/null"`
  - [ ] Use same execution and task roles as web service
  - [ ] Enable `initProcessEnabled` for ECS Exec
  - [ ] Configure CloudWatch log group
  - [ ] Set CPU: 256, Memory: 512 (minimal footprint)

- [ ] **Add Terraform Outputs** (`outputs.tf`)
  - [ ] Output subnet IDs for bastion script
  - [ ] Output bastion security group ID
  - [ ] Output cluster name

### Application Changes (in `./` - API repo)

- [ ] **Create Bastion Script** (`bin/bastion`)
  - [ ] Fetch subnet and security group IDs from Terraform
  - [ ] Run ECS task with `--enable-execute-command`
  - [ ] Wait for task to be ready
  - [ ] Connect via `aws ecs execute-command`
  - [ ] Auto-cleanup: stop task on exit
  - [ ] Make executable

- [ ] **Update Documentation** (`DEPLOYMENT_PLAN.md`)
  - [ ] Add bastion usage section
  - [ ] Document security model
  - [ ] Add troubleshooting guide

## Files to Create/Modify

### New Files

1. `../terraform/terraform/aws/iam_bastion_ip_restriction.tf` - IP restriction policy for bastion
2. `../terraform/terraform/aws/security_group_bastion.tf` - Bastion security group
3. `../terraform/terraform/aws/ecs_bastion.tf` - Bastion ECS task definition and log group
4. `./bin/bastion` - One-command bastion access script

### Modified Files

1. `../terraform/terraform/aws/ecs_cluster.tf` - Enable ECS Exec
2. `../terraform/terraform/aws/iam.tf` - Add SSM permissions
3. `../terraform/terraform/aws/security_group_rds.tf` - Allow bastion access
4. `../terraform/terraform/aws/outputs.tf` - Add bastion outputs
5. `./DEPLOYMENT_PLAN.md` - Document bastion usage

## Security Model

### Authentication
- **AWS IAM**: Only users with valid AWS credentials
- **MFA Required**: Via aws-vault, prompts for Authy code
- **Session Duration**: 12 hours (configurable)
- **IP Restriction**: Only from whitelisted IPs (86.104.250.204, 124.34.215.153, and 180.50.134.226)

### Authorization
- **IAM Permissions Required**:
  - `ecs:RunTask` - Start bastion
  - `ecs:ExecuteCommand` - Connect to bastion
  - `ecs:DescribeTasks` - Check bastion status
  - `ecs:StopTask` - Terminate bastion

### IP Restriction Policy

This policy is automatically created and attached via Terraform (`iam_bastion_ip_restriction.tf`):

**Policy Name**: `jiki-bastion-ip-restriction`

**Policy JSON** (for reference):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyBastionFromNonWhitelistedIPs",
      "Effect": "Deny",
      "Action": [
        "ecs:RunTask",
        "ecs:ExecuteCommand"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "ecs:cluster": "arn:aws:ecs:eu-west-1:*:cluster/jiki-production"
        },
        "NotIpAddress": {
          "aws:SourceIp": [
            "86.104.250.204/32",
            "124.34.215.153/32",
            "180.50.134.226/32"
          ]
        }
      }
    }
  ]
}
```

**Note**: The 124.34.215.153/32 and 180.50.134.226/32 IPs are temporary and can be removed from the policy when no longer needed.

### Network Isolation
- **Bastion → Database**: Port 5432 only
- **Bastion → Internet**: HTTPS (443) only (for AWS APIs)
- **No Inbound**: Bastion has no listening ports
- **Same VPC**: Access to all VPC resources

### Audit Trail
- **CloudWatch Logs**: All ECS Exec sessions logged
- **CloudTrail**: All AWS API calls tracked
- **Session Recording**: Available via CloudWatch

## Usage

### Start Bastion and Connect

```bash
# From the API repo
./bin/bastion
# Prompts for MFA (if aws-vault session expired)
# Starts task, waits for ready, connects automatically
# Drops you into a bash shell inside the container
```

### Inside the Bastion

```bash
# Rails console
rails console

# Database console
rails dbconsole

# Or direct psql
psql $DATABASE_URL

# Run migrations
rails db:migrate

# Check app status
rails runner "puts User.count"
```

### Exit and Cleanup

```bash
# Exit the bastion shell
exit

# Script auto-stops the task (or prompt to confirm)
```

## Cost

- **On-Demand**: Only pay when running
- **Hourly Rate**: ~$0.01/hour (256 CPU / 512 MB Fargate)
- **Typical Usage**: 1-2 hours/month = $0.01-0.02/month
- **No Permanent Infrastructure**: No cost when not running

## Deployment Steps

1. **Apply Terraform Changes**
   ```bash
   cd ../terraform/terraform
   aws-vault exec jiki -- terraform plan
   aws-vault exec jiki -- terraform apply
   ```

2. **Create Bastion Script**
   ```bash
   cd ../../api
   # Create bin/bastion (implemented in this plan)
   chmod +x bin/bastion
   ```

3. **Test Bastion Access**
   ```bash
   ./bin/bastion
   # Should prompt for MFA, connect successfully
   ```

## Rollback Plan

If issues arise:

1. **Remove bastion script**: `rm bin/bastion`
2. **Revert Terraform**:
   ```bash
   cd ../terraform/terraform
   git revert <commit-hash>
   aws-vault exec jiki -- terraform apply
   ```

## Success Criteria

- [ ] `./bin/bastion` starts bastion and connects in one command
- [ ] MFA authentication required via aws-vault
- [ ] Can access Rails console inside bastion
- [ ] Can access database via `rails dbconsole`
- [ ] Bastion auto-stops after exit
- [ ] All sessions logged to CloudWatch
- [ ] Documentation updated

---

**Ready to implement?** Reply 'yes' to proceed with the implementation.
