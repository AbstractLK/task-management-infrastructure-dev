Here is the complete, end-to-end guide to manually provisioning your microservices architecture on AWS ECS Fargate using the AWS Management Console. This guide organizes the configuration into a logical order where each step builds on the resources created before it.

## Phase 1: Secure Configuration (Systems Manager Parameter Store)

Before configuring your containers, store the sensitive details from your local `.env` file securely.

1. Open the **AWS Console** and search for **Systems Manager**.
2. In the left sidebar, under *Application Management*, click **Parameter Store**.
3. Click **Create parameter**.
4. Create your database connection parameter:
    - **Name:** `/microservices/prod/MONGO_URI`
    - **Tier:** Standard
    - **Type:** `SecureString`
    - **KMS key source:** My current account (`alias/aws/ssm` by default)
    - **Value:** *Paste your MongoDB Atlas connection string here.*
5. Click **Create parameter**.
6. Repeat this process for any other environment secrets (e.g., `JWT_SECRET`).

## Phase 2: Access Control (IAM Permissions)

Your Fargate containers need explicit permission to read the secrets you just saved in the Parameter Store.

1. Navigate to the **IAM Dashboard** and click **Roles** in the left menu.
2. Search for and select `ecsTaskExecutionRole`.
*(Note: If it doesn't exist yet, click **Create role** -> **AWS Service** -> **Elastic Container Service** -> **Elastic Container Service Task**, attach the `AmazonECSTaskExecutionRolePolicy`, and name it `ecsTaskExecutionRole`).*
3. Inside the role, click **Add permissions** -> **Create inline policy**.
4. Switch to the **JSON** tab and paste the following policy:JSON
    
    ```
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "ssm:GetParameters",
            "ssm:GetParameter"
          ],
          "Resource": [
            "arn:aws:ssm:*:*:parameter/microservices/*"
          ]
        }
      ]
    }
    ```
    
5. Click **Next**, name the policy `ECS-SSM-ReadSecrets`, and click **Create policy**.

## Phase 3: Traffic Routing (Application Load Balancer)

An ALB exposes a single public URL to the internet and routes incoming traffic to your containers dynamically.

### 1. Create a Target Group

1. Go to the **EC2 Dashboard** and click **Target Groups** under *Load Balancing* in the left menu.
2. Click **Create target group**.
3. **Target type:** Choose **IP addresses** (Crucial for AWS Fargate).
4. **Target group name:** `frontend-target-group`
5. **Protocol/Port:** `HTTP` / `80` (or `3000` depending on your frontend container configuration).
6. **VPC:** Choose your target VPC.
7. Click **Next**, skip registering any targets manually (ECS handles this automatically), and click **Create target group**.

### 2. Create the Load Balancer

1. Click **Load Balancers** in the left menu and select **Create load balancer**.
2. Choose **Application Load Balancer** and click **Create**.
3. **Load balancer name:** `microservices-alb`
4. **Scheme:** Internet-facing
5. **Network mapping:** Select your VPC and check at least two Availability Zones (select the **Public Subnets** for each).
6. **Security groups:** Create or choose a security group that allows inbound **HTTP (Port 80)** traffic from `0.0.0.0/0`.
7. **Listeners and routing:** Under the Port 80 listener, select your newly created `frontend-target-group`.
8. Scroll to the bottom and click **Create load balancer**. Copy the **DNS name** once it's provisioned.

## Phase 4: Compute Infrastructure (ECS Cluster & Tasks)

### 1. Create the ECS Cluster

1. Navigate to **Elastic Container Service (ECS)**.
2. Click **Clusters** -> **Create cluster**.
3. **Cluster name:** `microservices-cluster`
4. **Infrastructure:** Select **AWS Fargate** (Serverless).
5. Click **Create**.

### 2. Define the Task Layout

1. In the left menu, click **Task definitions** -> **Create new task definition**.
2. **Task definition family:** `microservices-stack`
3. **Launch type:** AWS Fargate
4. **Task execution role:** Select `ecsTaskExecutionRole`.
5. **Task size:** Select `1 vCPU` and `2 GB` memory (to share across your 3 containers).
6. **Container Configurations:** Click **Add container** for each service:
    - **Frontend Container:**
        - **Name:** `frontend`
        - **Image URI:** `your-dockerhub-username/frontend:latest`
        - **Port mappings:** Port `3000` (or `80`) / TCP.
    - **Authentication Service Container:**
        - **Name:** `auth-service`
        - **Image URI:** `your-dockerhub-username/auth-service:latest`
        - **Environment variables:** Add non-secrets as **Value** (e.g., `PORT`: `5001`). Add secrets by selecting **ValueFrom** and pasting the Parameter Store ARN: `arn:aws:ssm:region:account-id:parameter/microservices/prod/MONGO_URI`.
    - **Task Service Container:**
        - **Name:** `task-service`
        - **Image URI:** `your-dockerhub-username/task-service:latest`
        - **Environment variables:** Match your settings, utilizing **ValueFrom** for secret connection strings.
7. Click **Create**.

### 3. Deploy the Service

1. Open your `microservices-cluster` from the cluster dashboard.
2. Under the **Services** tab, click **Create**.
3. **Family:** `microservices-stack` (Select the revision you just built).
4. **Service name:** `microservices-app-service`
5. **Desired tasks:** `1`
6. **Networking:** Choose your VPC and subnets.
7. **Security Group:** Create a security group for the tasks that accepts incoming traffic on your container ports *only from the ALB security group*.
8. **Load balancing:** * Select **Application Load Balancer**.
    - **Load balancer name:** `microservices-alb`
    - **Container to load balance:** Select `frontend` and choose your existing `frontend-target-group`.
9. Click **Create**.

Once the Fargate tasks transfer to a `RUNNING` status, paste the ALB DNS name into your web browser to view your live, production-ready microservices layout.