# QuakeWatch

QuakeWatch is a Flask earthquake dashboard (data from the USGS Earthquake API), packaged with Docker, deployed to Kubernetes with Helm, and checked by a GitHub Actions CI pipeline.

The repository has three main parts:

- `QuakeWatch-app/`: the Flask application, its Python dependencies, templates, static assets, and Dockerfile. See [`QuakeWatch-app/README.md`](QuakeWatch-app/README.md) for app details.
- `quakewatch-chart/`: the Helm chart used to deploy the app to Kubernetes.
- `.github/workflows/quakewatch-ci.yaml`: the CI pipeline (pylint, Helm lint, Docker build).

Keeping the application code apart from the deployment configuration makes each part easier to maintain.

## Repository structure

```text
QuakeWatch-repo/
├── .github/
│   └── workflows/
│       └── quakewatch-ci.yaml
├── QuakeWatch-app/
│   ├── app.py
│   ├── dashboard.py
│   ├── utils.py
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── static/
│   └── templates/
├── quakewatch-chart/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── .helmignore
│   └── templates/
├── README.md
└── .gitignore
```

## Prerequisites

- Python 3.11+
- Docker
- Helm 3
- A local Kubernetes cluster (Docker Desktop Kubernetes, minikube, or kind)

## Run the app locally

```bash
cd QuakeWatch-app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python app.py              # set FLASK_DEBUG=1 for auto-reload and debug pages
```

Then open http://localhost:5000.

## Docker

Build the image from the application directory:

```bash
cd QuakeWatch-app
docker build -t quakewatch:1.0.0 .
```

Run it locally:

```bash
docker run --rm -p 5000:5000 quakewatch:1.0.0
```

In the container the app runs under `gunicorn` as a non-root user (UID 10001), and logs go to stdout (`docker logs <container>`).

## CI pipeline

The workflow runs on every push to a non-`main` branch and on every pull request to `main`. It:

1. Sets up Python and runs `pylint` on all Python files in `QuakeWatch-app/`
2. Runs `helm lint --strict` and `helm template` on the chart
3. Builds the Docker image

The workflow is defined in `.github/workflows/quakewatch-ci.yaml`.

## Deploy with Helm

### 1. Make the image available to the cluster

The chart uses the image `quakewatch:<appVersion>` (currently `quakewatch:1.0.0`). CI doesn't push it to a registry, so build it locally and make it visible to your cluster:

```bash
docker build -t quakewatch:1.0.0 QuakeWatch-app

# Docker Desktop Kubernetes: nothing else to do, it shares the local image store
# minikube:
minikube image load quakewatch:1.0.0
# kind:
kind load docker-image quakewatch:1.0.0
```

### 2. Validate and install the chart

From the repo root:

```bash
helm lint quakewatch-chart
helm template quakewatch quakewatch-chart --namespace quakewatch

helm upgrade --install quakewatch quakewatch-chart \
  --namespace quakewatch --create-namespace
```

### 3. Access the app

The Service is a `NodePort` on port `30080`:

```bash
# Docker Desktop / kind with port mapping:
open http://localhost:30080
# minikube:
minikube service quakewatch-service -n quakewatch
```

Or use port-forwarding on any cluster:

```bash
kubectl -n quakewatch port-forward svc/quakewatch-service 8080:80
# then open http://localhost:8080
```

### What the chart deploys

| Resource | Default | Notes |
|---|---|---|
| Deployment | enabled | Runs as non-root, liveness and readiness probes on `/health` |
| Service | `NodePort` 30080 | Port 80 → container port 5000 |
| HorizontalPodAutoscaler | 2–5 replicas at 70% CPU | Requires metrics-server. When enabled, `replicaCount` is ignored |
| PodDisruptionBudget | `maxUnavailable: 1` | |
| PriorityClass | enabled | Cluster-scoped |
| ConfigMap | `APP_NAME`, `APP_ENV`, `LOG_LEVEL`, `API_TIMEOUT_SECONDS` | Injected as environment variables |
| Secret | demo values | Plain text in `values.yaml`, base64-encoded by the chart |
| CronJob | every 5 min | Calls `/health` through the Service |
| PV + PVC | disabled | `persistence.enabled=true` mounts a hostPath volume at `/app/data` |
| Ingress / HTTPRoute | disabled | Enable via `ingress.enabled` / `httpRoute.enabled` |

Override any value at install time, for example:

```bash
helm upgrade --install quakewatch quakewatch-chart -n quakewatch \
  --set autoscaling.enabled=false --set replicaCount=3 \
  --set secretValues.API_TOKEN=my-real-token
```

### Uninstall

```bash
helm uninstall quakewatch -n quakewatch
```

## Notes

- The secret values in `values.yaml` are demo values only. Never commit real secrets; pass them with `--set` or a values file kept out of git.
- The app image is built from `QuakeWatch-app/Dockerfile`; the chart's image repository and tag are set in `quakewatch-chart/values.yaml` (`image.tag` defaults to the chart `appVersion`).
