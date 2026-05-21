### NOTE:  IF Running deploy.sh run:

./deploy.sh --fresh


# mcropsey AWS crAPI Lab

crAPI running on EC2 via Docker Compose, fronted by an ALB, ready for Zuplo API Gateway.

---

## Prerequisites

- AWS CLI configured (`aws sts get-caller-identity` works)
- Key pair `mcropsey-key` exists in us-east-2
- Template file: `~/mcropsey-aws-crapi-lab.yaml`

---

## Deploy the Stack

```bash
aws cloudformation deploy \
  --template-file ~/mcropsey-aws-crapi-lab.yaml \
  --stack-name mcropsey-lab \
  --region us-east-2 \
  --parameter-overrides AllowedSSHCIDR=$(curl -s https://checkip.amazonaws.com)/32
```

Stack creation takes ~5 minutes. crAPI images take another 3-4 minutes to pull and start after that.

---

## Get Your IPs and URLs

```bash
aws cloudformation describe-stacks \
  --stack-name mcropsey-lab \
  --region us-east-2 \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table
```

| Output Key | What it is |
|---|---|
| `CrAPIWebURL` | crAPI web UI — open in browser |
| `ALBRestAPIURL` | crAPI REST API — use as Zuplo upstream URL |
| `MailHogURL` | MailHog email capture UI |
| `SSHCommand` | SSH command with current EC2 IP |

---

## Check ALB Health

```bash
# Web (port 8888)
aws elbv2 describe-target-health \
  --region us-east-2 \
  --target-group-arn $(aws elbv2 describe-target-groups --region us-east-2 \
    --names mcropsey-web-tg \
    --query 'TargetGroups[0].TargetGroupArn' --output text) \
  --query 'TargetHealthDescriptions[*].[Target.Port,TargetHealth.State,TargetHealth.Description]' \
  --output table

# REST API (port 8080)
aws elbv2 describe-target-health \
  --region us-east-2 \
  --target-group-arn $(aws elbv2 describe-target-groups --region us-east-2 \
    --names mcropsey-api-tg \
    --query 'TargetGroups[0].TargetGroupArn' --output text) \
  --query 'TargetHealthDescriptions[*].[Target.Port,TargetHealth.State,TargetHealth.Description]' \
  --output table

# MailHog (port 8025)
aws elbv2 describe-target-health \
  --region us-east-2 \
  --target-group-arn $(aws elbv2 describe-target-groups --region us-east-2 \
    --names mcropsey-mailhog-tg \
    --query 'TargetGroups[0].TargetGroupArn' --output text) \
  --query 'TargetHealthDescriptions[*].[Target.Port,TargetHealth.State,TargetHealth.Description]' \
  --output table
```

Target state will show `unhealthy` for the first few minutes while containers start. Wait for `healthy`.

---

## SSH to the Instance

```bash
# Get the current IP (changes if instance is replaced)
aws cloudformation describe-stacks \
  --stack-name mcropsey-lab \
  --region us-east-2 \
  --query "Stacks[0].Outputs[?OutputKey=='SSHCommand'].OutputValue" \
  --output text

# Then SSH
ssh -i ~/.ssh/mcropsey-key.pem ec2-user@<ip-from-above>
```

---

## Check crAPI Containers (via SSH)

```bash
cd /opt/crapi

# See all container status
sudo docker-compose ps

# Watch logs live
sudo docker-compose logs -f

# Check a specific service
sudo docker-compose logs crapi-web
sudo docker-compose logs mailhog
```

---

## Zuplo API Gateway Setup

1. Go to [portal.zuplo.com](https://portal.zuplo.com) and create a new project
2. Add a route (e.g. `GET /identity/api/*`)
3. Set handler to **URL Rewrite**
4. Set the upstream URL to the `ALBRestAPIURL` stack output value
5. Add policies (rate limiting, API key auth, etc.) as needed
6. Deploy — you get a `*.zuplo.app` URL that fronts crAPI

---

## Tear Down

```bash
aws cloudformation delete-stack --stack-name mcropsey-lab --region us-east-2
aws cloudformation wait stack-delete-complete --stack-name mcropsey-lab --region us-east-2
```

---

## Troubleshooting

**502 Bad Gateway** — containers are still starting. Wait 3-4 minutes and check ALB health.

**SSH fails / wrong IP** — the EC2 IP changes if CloudFormation replaces the instance. Re-run the SSHCommand output to get the current IP.

**Containers not starting** — SSH in and check logs:
```bash
cat /var/log/user-data.log
cd /opt/crapi && sudo docker-compose logs
```

**crAPI bound to 127.0.0.1** — the `.env` file controls this. Verify:
```bash
cat /opt/crapi/.env | grep LISTEN_IP
# Should show: LISTEN_IP=0.0.0.0
```
