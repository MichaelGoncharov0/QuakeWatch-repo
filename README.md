# QuakeWatch Helm Chart

This chart deploys the QuakeWatch Flask application to Kubernetes.

It includes the main Kubernetes resources used in the earlier phases of the project:
- Deployment
- Service
- ConfigMap
- Secret
- PersistentVolume and PersistentVolumeClaim
- CronJob
- HorizontalPodAutoscaler
- PodDisruptionBudget
- PriorityClass

## Prerequisites

Before you begin, make sure you have:
- Docker installed
- Helm 3 installed
- kubectl installed and configured for your cluster
- a working Kubernetes cluster (Docker Desktop, Kind, Minikube, or a cloud cluster)

## Quick start

Create a folder to keep your Helm work organized:

```bash
mkdir -p ~/quakewatch-helm
cd ~/quakewatch-helm
```

Create the namespace:

```bash
kubectl create namespace quakewatch --dry-run=client -o yaml | kubectl apply -f -
```

Check current namesapce with:

```bash
kubectl config view --minify| grep namespace:
```

Pull the chart from Docker Hub and unpack it locally:

```bash
helm pull oci://registry-1.docker.io/michaelgoncharov0/quakewatch-repo --version 0.1.0 --untar
```

Install it:

```bash
helm upgrade -i quakewatch-chart ./quakewatch-chart-0.1.0 \
  --namespace quakewatch
```

You can also install it directly from the registry without downloading it first:

```bash
helm upgrade -i quakewatch-chart oci://registry-1.docker.io/michaelgoncharov0/quakewatch-repo \
  --version 0.1.0 \
  --namespace quakewatch
```

## Check the deployment

```bash
kubectl get pods -n quakewatch
kubectl get svc -n quakewatch
kubectl get pvc -n quakewatch
kubectl get hpa -n quakewatch
kubectl get cronjob -n quakewatch
```

## Access the app in the browser

The service is configured as a NodePort, but on local clusters like Docker Desktop, the app is usually easiest to reach through port forwarding.

Run this in a terminal:

```bash
kubectl port-forward svc/quakewatch-service 30080:80 -n quakewatch
```

Then open:

```text
http://localhost:30080
```

This forwards traffic from your local machine to the Kubernetes service, so your browser can reach the application without needing to know the cluster node IP.

## Health check

```bash
curl http://localhost:30080/health
```

## Local chart install

If you already have the chart source locally, you can also install it directly from the folder:

```bash
helm upgrade --install quakewatch-chart . --namespace quakewatch --create-namespace
```

## Versioning in Helm

Helm keeps track of versions for both the chart and the application.

The chart version is defined in `Chart.yaml`:

```yaml
version: 0.1.0
```

The app version is also defined there:

```yaml
appVersion: "1.16.0"
```

When you make changes to the chart itself, bump the chart version. When you release a new app image, bump the app version. This helps with rollback and release tracking.

Example:

```bash
helm history quakewatch-chart -n quakewatch
helm rollback quakewatch-chart 1 -n quakewatch
```

## Useful commands

Render templates without installing:

```bash
helm template quakewatch-chart .
```

Check release history:

```bash
helm history quakewatch-chart -n quakewatch
```

Uninstall the release:

```bash
helm uninstall quakewatch-chart -n quakewatch
```

## Notes

- The app listens on port `5000` inside the container.
- The Service exposes port `80` and NodePort `30080`.
- The `hostPath` storage is intended for local testing and demos.
- For production, prefer a proper storage class or cloud-managed storage.

## Troubleshooting

### The app is not reachable from the browser
Check the service and endpoints:

```bash
kubectl get svc -n quakewatch
kubectl get endpoints -n quakewatch
```

If needed, port-forward again:

```bash
kubectl port-forward svc/quakewatch-service 30080:80 -n quakewatch
```

### Pods are not starting
Check the logs:

```bash
kubectl get pods -n quakewatch
kubectl logs -n quakewatch deploy/quakewatch
kubectl describe pod -n quakewatch <pod-name>
```

### Helm install fails
Validate the chart before deploying:

```bash
helm template quakewatch-chart .
helm lint .
```
