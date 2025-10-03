# Autoscaling Configuration

This guide covers configuring autoscaling for Membrane services in production deployments.

## Overview

Membrane services emit Prometheus metrics that enable intelligent autoscaling based on workload. Different services have different scaling strategies:

| Service | Scaling Strategy | Key Metric |
|---------|------------------|------------|
| API | CPU-based | CPU utilization |
| Instant Tasks Worker | Queue-based | Jobs waiting + active |
| Queued Tasks Worker | Custom | Workers required vs current |
| Custom Code Runner | Capacity-based | Job spaces utilization |
| UI | Fixed or CPU | CPU utilization |
| Console | Fixed or CPU | CPU utilization |
| Orchestrator | Fixed (HA) | N/A - run 2 instances |

## Prometheus Metrics

### API Service Metrics

**Endpoint:** `http://api-service:5000/prometheus`

```
instant_tasks_jobs_active - Number of jobs currently being processed by instant-tasks-workers
instant_tasks_jobs_waiting - Number of jobs waiting in the instant tasks queue
queued_tasks_workers - Current number of running queued-tasks-workers pods
queued_tasks_workers_required - Maximum workers required for all queued tasks
```

### Custom Code Runner Metrics

**Endpoint:** `http://custom-code-runner:5000/api/v2/prometheus`

```
custom_code_runner_total_job_spaces - Total job capacity per pod
custom_code_runner_remaining_job_spaces - Available job slots per pod
```

### Queued Tasks Worker Metrics

**Endpoint:** `http://queued-worker:5000/prometheus/queued-tasks`

```
queued_tasks_worker_busy - Worker busy status (0 = free, 1 = busy)
```

## Kubernetes Horizontal Pod Autoscaler (HPA)

### Prerequisites

- Metrics Server installed
- Prometheus Adapter (for custom metrics)

Install Metrics Server:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### API Service Autoscaling

Scale based on CPU utilization:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
  namespace: membrane
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 60
```

### Instant Tasks Worker Autoscaling

Scale based on job queue length:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: instant-tasks-worker-hpa
  namespace: membrane
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: instant-tasks-worker
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Pods
      pods:
        metric:
          name: instant_tasks_jobs_total
        target:
          type: AverageValue
          averageValue: "5"  # Jobs per worker
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Pods
          value: 4
          periodSeconds: 60
```

**Formula:** `(instant_tasks_jobs_active + instant_tasks_jobs_waiting) / 5`

This scales up when there are more than 5 jobs per worker.

## KEDA (Kubernetes Event-Driven Autoscaling)

KEDA provides more advanced autoscaling with support for Prometheus metrics. Recommended for production.

### Install KEDA

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
kubectl create namespace keda
helm install keda kedacore/keda --namespace keda
```

### Instant Tasks Worker (KEDA)

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: instant-tasks-worker-scaler
  namespace: membrane
spec:
  scaleTargetRef:
    name: instant-tasks-worker
  minReplicaCount: 2
  maxReplicaCount: 20
  pollingInterval: 15
  cooldownPeriod: 60
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus-server.monitoring:9090
        metricName: instant_tasks_jobs
        query: |
          (sum(instant_tasks_jobs_active) + sum(instant_tasks_jobs_waiting)) / 5
        threshold: "1"
```

### Queued Tasks Worker (KEDA)

More complex scaling based on workers required:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: queued-tasks-worker-scaler
  namespace: membrane
spec:
  scaleTargetRef:
    name: queued-tasks-worker
  minReplicaCount: 2
  maxReplicaCount: 50
  pollingInterval: 15
  cooldownPeriod: 300
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus-server.monitoring:9090
        metricName: queued_tasks_workers_required_adjusted
        query: |
          max(queued_tasks_workers_required) + (max(queued_tasks_workers_required) * 0.3)
        threshold: "1"
```

**Formula:** `queued_tasks_workers_required + (queued_tasks_workers_required * 0.3)`

The 0.3 factor adds 30% buffer for burst capacity.

### Custom Code Runner (KEDA)

Scale based on capacity utilization:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: custom-code-runner-scaler
  namespace: membrane
spec:
  scaleTargetRef:
    name: custom-code-runner
  minReplicaCount: 2
  maxReplicaCount: 20
  pollingInterval: 15
  cooldownPeriod: 60
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus-server.monitoring:9090
        metricName: custom_code_runner_capacity_rate
        query: |
          (sum(custom_code_runner_total_job_spaces) - sum(custom_code_runner_remaining_job_spaces)) / sum(custom_code_runner_total_job_spaces)
        threshold: "0.45"
```

**Formula:** `(total_spaces - remaining_spaces) / total_spaces`

Scales when capacity utilization exceeds 45%.

## AWS ECS Auto Scaling

### Target Tracking Scaling - API Service

```bash
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/membrane-cluster/api \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 10

aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/membrane-cluster/api \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name api-cpu-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 50.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    },
    "ScaleOutCooldown": 60,
    "ScaleInCooldown": 300
  }'
```

### Custom Metric Scaling - Instant Tasks Worker

Requires publishing custom metrics to CloudWatch:

```bash
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/membrane-cluster/instant-tasks-worker \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name instant-tasks-queue-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 5.0,
    "CustomizedMetricSpecification": {
      "MetricName": "JobsPerWorker",
      "Namespace": "Membrane",
      "Statistic": "Average"
    }
  }'
```

## Azure Container Apps Scaling

### HTTP-based Scaling (API, UI, Console)

```bash
az containerapp update \
  --name membrane-api \
  --resource-group membrane-rg \
  --min-replicas 2 \
  --max-replicas 10 \
  --scale-rule-name http-scaling \
  --scale-rule-type http \
  --scale-rule-http-concurrency 100
```

### Custom Metric Scaling

Using Azure Monitor metrics:

```bash
az containerapp update \
  --name membrane-instant-worker \
  --resource-group membrane-rg \
  --min-replicas 2 \
  --max-replicas 20 \
  --scale-rule-name queue-scaling \
  --scale-rule-type azure-monitor \
  --scale-rule-metadata \
    metricName=JobQueueLength \
    metricResourceId=/subscriptions/.../resourceGroups/membrane-rg \
    targetValue=5
```

## Google Cloud Run Autoscaling

Cloud Run autoscales automatically based on requests. Configure limits:

```bash
gcloud run services update membrane-api \
  --min-instances 2 \
  --max-instances 10 \
  --concurrency 80 \
  --cpu-throttling \
  --memory 2Gi
```

For worker services, consider GKE with KEDA instead.

## Scaling Recommendations

### Production Workload Recommendations

| Service | Min Replicas | Max Replicas | Scaling Metric | Threshold |
|---------|--------------|--------------|----------------|-----------|
| API | 2 | 10 | CPU | 50% |
| Instant Worker | 2 | 20 | Jobs/Worker | 5 |
| Queued Worker | 2 | 50 | Workers Required | +30% buffer |
| Custom Code Runner | 2 | 20 | Capacity | 45% |
| UI | 2 | 5 | CPU | 50% |
| Console | 2 | 5 | CPU | 50% |
| Orchestrator | 2 | 2 | Fixed | N/A |

### Cooldown Periods

- **Scale Up:** Fast (0-15 seconds) - respond quickly to load
- **Scale Down:** Slow (300-600 seconds) - prevent flapping

### Buffer Factors

- **Instant Tasks Worker:** Jobs per worker modifier = 5
- **Queued Tasks Worker:** Buffer ratio = 0.3 (30%)
- **Custom Code Runner:** Capacity threshold = 0.45 (45%)

## Monitoring Autoscaling

### View HPA Status

```bash
kubectl get hpa -n membrane
kubectl describe hpa api-hpa -n membrane
```

### View KEDA Status

```bash
kubectl get scaledobject -n membrane
kubectl describe scaledobject instant-tasks-worker-scaler -n membrane
```

### Grafana Dashboards

Create dashboards to monitor:
- Current replica count vs desired
- Scaling events timeline
- Metric values triggering scaling
- Pod CPU and memory utilization

## Troubleshooting

### HPA Not Scaling

**Check metrics availability:**
```bash
kubectl top pods -n membrane
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
```

**Check HPA events:**
```bash
kubectl describe hpa <hpa-name> -n membrane
```

### KEDA Not Scaling

**Check ScaledObject status:**
```bash
kubectl describe scaledobject <name> -n membrane
```

**Check Prometheus query:**
```bash
# Test query directly in Prometheus UI
(sum(instant_tasks_jobs_active) + sum(instant_tasks_jobs_waiting)) / 5
```

**Check KEDA operator logs:**
```bash
kubectl logs -n keda -l app=keda-operator
```

### Flapping (Rapid Scale Up/Down)

**Solutions:**
- Increase cooldown periods
- Adjust stabilization windows
- Fine-tune metric thresholds
- Add buffer factors

## Best Practices

1. **Start conservative** - Begin with higher thresholds, adjust down as needed
2. **Monitor costs** - Autoscaling can increase costs, set max limits
3. **Test under load** - Simulate production load to verify scaling behavior
4. **Set appropriate limits** - Prevent runaway scaling with max replicas
5. **Use multiple metrics** - Combine CPU and custom metrics for better decisions
6. **Monitor scaling events** - Track when and why scaling occurs
7. **Gradual rollout** - Enable autoscaling for one service at a time

## Next Steps

- Set up Prometheus and Grafana for monitoring
- Configure alerts for scaling events
- Test autoscaling under load
- Review [FAQ](faq.md) for common questions
