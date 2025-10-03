# Helm Deployment

Membrane can be deployed using Helm charts for easier management and configuration of your Kubernetes resources.

## Prerequisites

Before deploying with Helm, ensure you have:
- Kubernetes cluster provisioned
- Cloud resources set up (see [Cloud Resources](../cloud-resources/index.md))
- Authentication configured (see [Authentication](../authentication/auth0.md))
- kubectl and helm installed

## Registry Access

You'll need two sets of credentials from our support team to access Membrane artifacts:

1. **Helm Registry Credentials**

* Username format: `robot$helm+<your-company-name>`
* Access to: `harbor.integration.app/helm`

2. **Container Registry Credentials**

* Username format: `robot$core+<your-company-name>`
* Access to: `harbor.integration.app/core`

<br />

### Setting Up Registry Access

1. Login to Helm registry

```
helm registry login harbor.integration.app \
  --username <helm-username> \
  --password <helm-password>
```

2. Pull and unpack the Integration.app Helm chart:

```
# See Versions section at the bottom of this page for available versions
helm pull oci://harbor.integration.app/helm/integration-app --version <version> --untar
```

## Prerequisites

Before installing Membrane using Helm, ensure you have the following components set up:

### Prometheus Stack

The kube-prometheus stack provides Prometheus, Grafana dashboards, and necessary Prometheus rules:

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring
```

For advanced configuration options, refer to the [kube-prometheus stack documentation](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack/#kube-prometheus-stack).

### KEDA

If you plan to use autoscaling features, install KEDA:

```
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
kubectl create namespace keda
helm install keda kedacore/keda --namespace keda
```

For advanced KEDA configuration, consult the [official KEDA documentation](https://keda.sh/docs/2.15/deploy/).

## Installation

1. **Configure Container Registry Access**

Create a Docker registry secret using your container registry credentials:

```
kubectl create secret docker-registry integration-app-harbor \
  --namespace <your-namespace> \
  --docker-server=harbor.integration.app \
  --docker-username=<container-registry-username> \
  --docker-password=<container-registry-password>
```

2. **Prepare Configuration**

Populate or provide override to `values.yaml` file with the values for your setup:

```Text yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/<YOUR_ROLE_NAME>

config:
  NODE_ENV: production
  MONGO_URI: MONGO_URI
  REDIS_URI: REDIS_URI
  # URI where `api` service will be available
  API_URI: API_URI
  # URI where `ui` service will be available
  UI_URI: UI_URI
  # URI where `console` service will be available
  CONSOLE_URI: CONSOLE_URI
  # Bucket for storing custom connectors
  CONNECTORS_S3_BUCKET: CONNECTORS_S3_BUCKET
  # Bucket for storing temporary files (like logs)
  TMP_S3_BUCKET: TMP_S3_BUCKET
  # Buckets for storing static files that should be available in user's browser (like images)
  STATIC_S3_BUCKET: STATIC_S3_BUCKET
  # Base URI where files stored in STATIC_S3_BUCKET will be available
  BASE_STATIC_URI: BASE_STATIC_URI
  # Auth0 Settings
  AUTH0_DOMAIN: AUTH0_DOMAIN
  AUTH0_CLIENT_ID: AUTH0_CLIENT_ID
  AUTH0_CLIENT_SECRET: AUTH0_CLIENT_SECRET
  # Secret key used for signing JWT tokens
  SECRET: SECRET
  # Secret key used for encrypting data at rest
  ENCRYPTION_SECRET: ENCRYPTION_SECRET
```

3. **Validate Chart**

Before deploying, make sure that chart is rendering correctly:

```
helm template integration-app ./path-to-your-chart --namespace <your-namespace>
```

4. **Select Cluster Context**

Make sure to switch to desired cluster context:

```
kubectl config use-context <your-desired-context>
```

5. **Deploy**

Install the chart to cluster:

```
helm install integration-app ./path-to-this-folder --namespace <your-namespace> --create-namespace
```

To update an existing installation:

```
helm upgrade integration-app ./path-to-this-folder --namespace <your-namespace>
```

## Autoscaling Configuration

The following components support autoscaling:

* API
* Instant Tasks Worker
* Queued Tasks Worker
* Custom Code Runner

Each component that supports autoscaling accepts these parameters:

| Parameter                      | Type    | Description                                                                                                                                                                    |
| :----------------------------- | :------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.autoscaling.enabled`         | Boolean | Enables/disables autoscaling for the component. If autoscaling is a number of replicas will taken from`.replicas` property. IF autoscaling is enabled, `.replicas` is ignored. |
| `.autoscaling.minReplicaCount` | Number  | Minimum number of replicas                                                                                                                                                     |
| `.autoscaling.maxReplicaCount` | Number  | Maximum number of replicas                                                                                                                                                     |
| `.autoscaling.cooldownPeriod`  | Number  | Cooldown period between scaling operations                                                                                                                                     |
| `.autoscaling.pollingInterval` | Number  | How often to check scaling metrics                                                                                                                                             |

These properties are part of KEDA's core functionality. For more detailed information, please refer to the [official KEDA documentation](https://keda.sh/docs/2.14/reference/scaledobject-spec/).

### Component-Specific Scaling

Each component has specific scaling parameters that control its autoscaling behavior:

| Parameter                                                           | Type   | Default | Description                                                                                                                                                                                                                                                                                                             |
| :------------------------------------------------------------------ | :----- | :------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `api.autoscaling. scalingTargets. cpuUtilizationPercent`            | Number | 50      | Defines the target CPU utilization percentage. Adjusting this value will influence how aggressively the API scales in response to CPU load                                                                                                                                                                              |
| `instantTasksWorker. autoscaling. scalingTargets. jobsPerWorker`    | Number | 5       | Determines the number of workers to bootstrap in response to job surges. Lower values result in quicker job processing but may lead to idle workers once jobs are processed, until the HPA scales down the pods.                                                                                                        |
| `customCodeRunner. autoscaling. scalingTargets. capacityRate`       | Number | 0.45    | Defines the capacity rate of available to total slots. A higher value increases the likelihood of custom code execution waiting for a slot, potentially slowing down API requests. A lower value ensures that custom code requests are processed promptly, but it may result in a higher number of idle pods.           |
| `queuedTasksWorker. autoscaling. scalingTargets. scaleUpRate`       | Number | 0.9     | The ratio of free to busy workers that triggers a scale-up operation. Higher values keep workers busy but may increase wait times for processing queued tasks. Conversely, lower values can lead to more frequent scaling up, ensuring tasks are processed more quickly but potentially resulting in more idle workers. |
| `queuedTasksWorker. autoscaling. scalingTargets. scaleDownRate`     | Number | 0.8     | The ratio of free to busy workers that triggers a scale-down operation. Similar to scale-up, higher values keep workers busy but may increase wait times.                                                                                                                                                               |
| `queuedTasksWorker. autoscaling. scalingTargets. scaleUpFactor`     | Number | 1.15    | The minimum number of workers to scale up to, expressed as a percentage of existing workers (e.g., 15%).                                                                                                                                                                                                                |
| `queuedTasksWorker. autoscaling. scalingTargets. workerBufferRatio` | Number | 0.3     | Adjustment for an instant / short-term burst of queued tasks. Increasing this value reduces wait time for individual tasks but may lead to idle workers post-processing.                                                                                                                                                |
| `queuedTasksWorker. autoscaling. scalingTargets. scaleDownFactor`   | Number | 0.8     | The number of workers to scale down to, expressed as a percentage reduction (e.g., reduce by 20%).                                                                                                                                                                                                                      |

<br />

## Versions and Changelog

### Latest Version: 0.2.1

<Table align={["left","left","left"]}>
  <thead>
    <tr>
      <th>
        Version
      </th>

      <th>
        Release Date
      </th>

      <th>
        Changes
      </th>
    </tr>
  </thead>

  <tbody>
    <tr>
      <td>
        0.2.1
      </td>

      <td>
        2025-06-01
      </td>

      <td>
        Initial release of the Helm chart
        Support for all core services
        KEDA autoscaling configuration
        Prometheus metrics integrati
      </td>
    </tr>
  </tbody>
</Table>
