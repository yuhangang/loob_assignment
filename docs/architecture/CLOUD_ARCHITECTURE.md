# Cloud Infrastructure & DevOps Strategy (AWS)

This document provides a comprehensive overview of the cloud infrastructure for the Loob Unified App. It is designed to be highly available, self-healing, and dynamically scalable across Southeast Asia using **Amazon Web Services (AWS)**.

---

## 1. Hosting & Network Topology

The infrastructure relies on strict network isolation to ensure security and compliance.

### VPC & Multi-AZ Deployment
*   **Region:** `ap-southeast-1` (Singapore) serves as the centralized hub for MY, TH, SG.
*   **Virtual Private Cloud (VPC):** The entire backend operates within a custom VPC.
*   **Public Subnets:** Hosts the Application Load Balancer (ALB) and NAT Gateways. Direct internet access is terminated here.
*   **Private Subnets:** Hosts the compute layer (Go), Cache (Redis), and Database (MySQL). These have NO direct inbound internet access.
*   **Multi-AZ (Availability Zones):** All resources (Compute, Cache, DB) are distributed across at least 2 physical Availability Zones. If AWS loses an entire data center in Singapore, the app remains online.

### Compute Layer (AWS ECS Fargate)
We use **Elastic Container Service (ECS) with AWS Fargate** (serverless containers). This removes the need for the DevOps team to patch or manage underlying EC2 operating systems.
*   **API Service:** Deployed to Fargate to handle synchronous HTTP traffic.
*   **Worker Service:** Deployed to Fargate as background daemon tasks to process the SQS queues.

---

## 2. Auto-Scaling Strategy

Scaling must be fluid. The system scales different components based on different metrics to optimize cost and performance.

### A. Frontend / Content Scaling
*   **AWS CloudFront (CDN):** Banners, app icons, and manifest JSONs are cached at edge locations globally. It scales infinitely by default.

### B. Compute Scaling (Fargate Target Tracking)
*   **API Nodes (HTTP):** Auto-scales based on **CPU Utilization** and **ALB Request Count**.
    *   *Rule:* If average CPU > 60% for 2 minutes, add 2 containers.
*   **Worker Nodes (Background):** Auto-scales based on **SQS Queue Depth**.
    *   *Rule:* If the `OrderIntent` queue has > 1,000 messages, aggressively spin up 10 new Worker containers to clear the backlog, then scale down to 1 when the queue is empty.

### C. Database Scaling
*   **AWS Aurora MySQL Serverless v2:** Automatically scales compute capacity (ACUs) up and down instantly based on database load. During a flash sale, it scales up to handle the Bulk Inserts from the workers, and scales down to minimal capacity at 3 AM to save costs.
*   **Read Replicas:** Aurora automatically adds Read Replicas if read query volume spikes.

---

## 3. Fail-Safe & Self-Healing Mechanisms

The system assumes hardware and network failures *will* happen and recovers automatically.

### Application Level Self-Healing
1.  **ALB Health Checks:** The Load Balancer pings the Go `/health` endpoint every 10 seconds. If a container crashes or hangs (e.g., memory leak), the ALB marks it as "Unhealthy", stops routing traffic to it, and instructs ECS to instantly kill it and spin up a fresh replacement container.
2.  **SQS Dead Letter Queues (DLQ):** If a worker fails to process an order 3 times (e.g., due to a data anomaly), the message is moved to a DLQ. This prevents "poison pill" messages from clogging the queue. Ops can inspect the DLQ and replay the messages later.

### Infrastructure Level Fail-Safe
1.  **Aurora Multi-AZ Failover:** If the Primary MySQL instance suffers a hardware failure, AWS automatically promotes a Read Replica to become the new Primary within 30-60 seconds. The Go database driver automatically reconnects.
2.  **Redis Cluster Mode:** ElastiCache runs in cluster mode. If the primary node fails, a replica is instantly promoted without data loss.
3.  **AWS WAF (Web Application Firewall):** Protects the ALB from DDoS attacks and SQL injection, acting as a shield before traffic even reaches the compute layer.

---

## 4. Monitoring, Observability & Alerting

DevOps must have a "single pane of glass" to monitor the health of the entire multi-country system.

### A. APM & Distributed Tracing
*   **Tool:** Datadog or AWS X-Ray.
*   **Implementation:** Every request from the Flutter app generates a trace. Ops can view a visual waterfall graph showing: `ALB (5ms) -> Go API (20ms) -> Redis (2ms) -> SQS (10ms)`. This makes identifying the exact bottleneck trivial.

### B. Log Aggregation
*   **Tool:** Amazon CloudWatch Logs (or Datadog Logs).
*   **Strategy:** Go outputs structured JSON logs. ECS forwards these to CloudWatch.
*   **Filtering:** Because logs contain `{"country": "TH", "brand": "tealive"}`, Ops can instantly filter logs to see errors affecting only specific regions.

### C. Automated Alerting (CloudWatch Alarms)
Alarms are routed to Ops via PagerDuty or Slack.
*   **Infrastructure Alerts:** 
    *   "API Container CPU > 85% for 5 mins"
    *   "Database Connections > 80% of Max"
*   **Business Metric Alerts (Crucial):**
    *   "Checkout HTTP 500 Error Rate > 2% in the last minute"
    *   "SQS Queue Age > 5 minutes" (Indicates workers are stuck and users aren't getting their receipts).

---

## 5. Deployment & IaC (Infrastructure as Code)

To manage multiple countries reliably, manual AWS console clicking is strictly prohibited.

*   **Terraform / AWS CDK:** The entire VPC, ECS cluster, Database, and WAF rules are defined in code.
    *   *Benefit:* If the business needs an isolated environment in Indonesia (AWS Jakarta) for legal reasons, DevOps simply runs `terraform apply -var="region=ap-southeast-3"`, and an identical, pristine infrastructure stack is built in minutes.
*   **CI/CD (GitHub Actions):** 
    1.  On `git push`, tests run. 
    2.  Go is built into a Docker image and pushed to Amazon ECR.
    3.  ECS initiates a **Rolling Update**: It spins up the new version alongside the old version, verifies health checks pass on the new containers, slowly shifts traffic over, and then gracefully drains the old containers. **Zero downtime deployment.**