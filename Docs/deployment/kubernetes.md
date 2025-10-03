# Kubernetes Deployment

This guide covers deploying Membrane on Kubernetes clusters (EKS, AKS, GKE, or self-managed).

## Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- Cloud resources provisioned (see [Cloud Resources](../cloud-resources/index.md))
- Authentication configured (see [Authentication](../authentication/auth0.md))
- Docker registry access

## Quick Start with Helm

The easiest way to deploy on Kubernetes is using Helm:

👉 See [Helm Deployment Guide](helm.md) for complete instructions.

## Manual Kubernetes Deployment

If you prefer manual deployment or need custom configuration:

### 1. Create Namespace

```bash
kubectl create namespace membrane
```

### 2. Create Docker Registry Secret

```bash
kubectl create secret docker-registry harbor-secret \
  --namespace membrane \
  --docker-server=harbor.integration.app \
  --docker-username=robot\$core+your-company \
  --docker-password=your_password
```

### 3. Create ConfigMap for Environment Variables

```yaml
# config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: membrane-config
  namespace: membrane
data:
  NODE_ENV: "production"
  BASE_URI: "https://api.yourdomain.com"
  CUSTOM_CODE_RUNNER_URI: "http://custom-code-runner:5000"
  PORT: "5000"
  STORAGE_PROVIDER: "s3"
  AWS_REGION: "us-east-1"
  TMP_STORAGE_BUCKET: "integration-app-tmp"
  CONNECTORS_STORAGE_BUCKET: "integration-app-connectors"
  STATIC_STORAGE_BUCKET: "integration-app-static"
  BASE_STATIC_URI: "https://static.yourdomain.com"
  MONGO_URI: "mongodb+srv://user:pass@cluster.mongodb.net/db"
  REDIS_URI: "redis://user:pass@redis:6379"
  # Console specific
  NEXT_PUBLIC_BASE_URI: "https://console.yourdomain.com"
  NEXT_PUBLIC_ENGINE_API_URI: "https://api.yourdomain.com"
  NEXT_PUBLIC_ENGINE_UI_URI: "https://ui.yourdomain.com"
```

### 4. Create Secrets

```yaml
# secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: membrane-secrets
  namespace: membrane
type: Opaque
stringData:
  SECRET: "<your-jwt-secret>"
  ENCRYPTION_SECRET: "<your-encryption-secret>"
  AUTH0_CLIENT_SECRET: "<your-auth0-secret>"
  AUTH0_DOMAIN: "your-tenant.auth0.com"
  AUTH0_CLIENT_ID: "your_client_id"
```

Apply:
```bash
kubectl apply -f config.yaml
kubectl apply -f secrets.yaml
```

### 5. Deploy Services

#### API Service

```yaml
# api-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: membrane
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      imagePullSecrets:
        - name: harbor-secret
      containers:
        - name: api
          image: harbor.integration.app/core/api:2025-09-19
          ports:
            - containerPort: 5000
          env:
            - name: IS_API
              value: "1"
          envFrom:
            - configMapRef:
                name: membrane-config
            - secretRef:
                name: membrane-secrets
          resources:
            requests:
              cpu: 500m
              memory: 2Gi
            limits:
              cpu: 2000m
              memory: 4Gi
          livenessProbe:
            httpGet:
              path: /
              port: 5000
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /
              port: 5000
            initialDelaySeconds: 10
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: membrane
spec:
  selector:
    app: api
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
  type: LoadBalancer  # Or ClusterIP if using Ingress
```

#### Instant Tasks Worker

```yaml
# instant-worker-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: instant-tasks-worker
  namespace: membrane
spec:
  replicas: 2
  selector:
    matchLabels:
      app: instant-tasks-worker
  template:
    metadata:
      labels:
        app: instant-tasks-worker
    spec:
      imagePullSecrets:
        - name: harbor-secret
      containers:
        - name: worker
          image: harbor.integration.app/core/api:2025-09-19
          env:
            - name: IS_INSTANT_TASKS_WORKER
              value: "1"
          envFrom:
            - configMapRef:
                name: membrane-config
            - secretRef:
                name: membrane-secrets
          resources:
            requests:
              cpu: 500m
              memory: 2Gi
            limits:
              cpu: 2000m
              memory: 4Gi
```

#### Queued Tasks Worker

```yaml
# queued-worker-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: queued-tasks-worker
  namespace: membrane
spec:
  replicas: 2
  selector:
    matchLabels:
      app: queued-tasks-worker
  template:
    metadata:
      labels:
        app: queued-tasks-worker
    spec:
      imagePullSecrets:
        - name: harbor-secret
      containers:
        - name: worker
          image: harbor.integration.app/core/api:2025-09-19
          env:
            - name: IS_QUEUED_TASKS_WORKER
              value: "1"
            - name: MAX_QUEUED_TASKS_MEMORY_MB
              value: "1024"
            - name: MAX_QUEUED_TASKS_PROCESS_TIME_SECONDS
              value: "3000"
          envFrom:
            - configMapRef:
                name: membrane-config
            - secretRef:
                name: membrane-secrets
          resources:
            requests:
              cpu: 500m
              memory: 2Gi
            limits:
              cpu: 2000m
              memory: 4Gi
```

#### Orchestrator

```yaml
# orchestrator-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orchestrator
  namespace: membrane
spec:
  replicas: 2
  selector:
    matchLabels:
      app: orchestrator
  template:
    metadata:
      labels:
        app: orchestrator
    spec:
      imagePullSecrets:
        - name: harbor-secret
      containers:
        - name: orchestrator
          image: harbor.integration.app/core/api:2025-09-19
          env:
            - name: IS_ORCHESTRATOR
              value: "1"
          envFrom:
            - configMapRef:
                name: membrane-config
            - secretRef:
                name: membrane-secrets
          resources:
            requests:
              cpu: 500m
              memory: 2Gi
            limits:
              cpu: 2000m
              memory: 4Gi
```

#### UI Service

```yaml
# ui-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ui
  namespace: membrane
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ui
  template:
    metadata:
      labels:
        app: ui
    spec:
      imagePullSecrets:
        - name: harbor-secret
      containers:
        - name: ui
          image: harbor.integration.app/core/ui:2025-09-19
          ports:
            - containerPort: 5000
          envFrom:
            - configMapRef:
                name: membrane-config
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 2Gi
---
apiVersion: v1
kind: Service
metadata:
  name: ui
  namespace: membrane
spec:
  selector:
    app: ui
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
  type: LoadBalancer
```

#### Console Service

```yaml
# console-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: console
  namespace: membrane
spec:
  replicas: 2
  selector:
    matchLabels:
      app: console
  template:
    metadata:
      labels:
        app: console
    spec:
      imagePullSecrets:
        - name: harbor-secret
      containers:
        - name: console
          image: harbor.integration.app/core/console:2025-09-19
          ports:
            - containerPort: 5000
          envFrom:
            - configMapRef:
                name: membrane-config
            - secretRef:
                name: membrane-secrets
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 2Gi
---
apiVersion: v1
kind: Service
metadata:
  name: console
  namespace: membrane
spec:
  selector:
    app: console
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
  type: LoadBalancer
```

#### Custom Code Runner

```yaml
# custom-code-runner-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-code-runner
  namespace: membrane
spec:
  replicas: 2
  selector:
    matchLabels:
      app: custom-code-runner
  template:
    metadata:
      labels:
        app: custom-code-runner
    spec:
      imagePullSecrets:
        - name: harbor-secret
      containers:
        - name: runner
          image: harbor.integration.app/core/custom-code-runner:2025-09-19
          ports:
            - containerPort: 5000
          env:
            - name: PORT
              value: "5000"
          resources:
            requests:
              cpu: 500m
              memory: 2Gi
            limits:
              cpu: 2000m
              memory: 4Gi
---
apiVersion: v1
kind: Service
metadata:
  name: custom-code-runner
  namespace: membrane
spec:
  selector:
    app: custom-code-runner
  ports:
    - protocol: TCP
      port: 5000
      targetPort: 5000
  type: ClusterIP  # Internal only
```

### 6. Deploy All Services

```bash
kubectl apply -f api-deployment.yaml
kubectl apply -f instant-worker-deployment.yaml
kubectl apply -f queued-worker-deployment.yaml
kubectl apply -f orchestrator-deployment.yaml
kubectl apply -f ui-deployment.yaml
kubectl apply -f console-deployment.yaml
kubectl apply -f custom-code-runner-deployment.yaml
```

### 7. Configure Ingress (Optional)

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: membrane-ingress
  namespace: membrane
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - api.yourdomain.com
        - ui.yourdomain.com
        - console.yourdomain.com
      secretName: membrane-tls
  rules:
    - host: api.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 80
    - host: ui.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ui
                port:
                  number: 80
    - host: console.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: console
                port:
                  number: 80
```

## Cloud-Specific Considerations

### AWS EKS

#### IAM Roles for Service Accounts (IRSA)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: membrane-sa
  namespace: membrane
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/membrane-role
```

Use this service account in deployments and omit AWS credentials from environment variables.

### Azure AKS

#### Workload Identity

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: membrane-sa
  namespace: membrane
  annotations:
    azure.workload.identity/client-id: CLIENT_ID
```

### Google GKE

#### Workload Identity

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: membrane-sa
  namespace: membrane
  annotations:
    iam.gke.io/gcp-service-account: membrane-sa@PROJECT_ID.iam.gserviceaccount.com
```

## Monitoring

### Install Prometheus and Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring
```

### ServiceMonitor for Membrane

```yaml
# servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: membrane-api
  namespace: membrane
spec:
  selector:
    matchLabels:
      app: api
  endpoints:
    - port: http
      path: /prometheus
```

## Autoscaling

See [Autoscaling Guide](../autoscaling.md) for HPA and KEDA configuration.

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n membrane
kubectl describe pod <pod-name> -n membrane
kubectl logs <pod-name> -n membrane
```

### Common Issues

**ImagePullBackOff:**
- Verify docker registry secret is created
- Check image name and tag

**CrashLoopBackOff:**
- Check pod logs for errors
- Verify environment variables
- Ensure MongoDB and Redis are accessible

**Service Not Accessible:**
- Check service and ingress configuration
- Verify DNS records
- Check load balancer status

## Next Steps

- Configure [Autoscaling](../autoscaling.md)
- Set up monitoring dashboards
- Review [FAQ](../faq.md) for common questions
