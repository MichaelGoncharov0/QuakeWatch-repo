# QuakeWatch

This repository is organized into two main parts:

- `QuakeWatch-app/` — the Flask application source code, Python dependencies, templates, static assets, and its Dockerfile.
- `charts/quakewatch-chart/` — the Helm chart used to deploy the app to Kubernetes.
- `.github/workflows/quakewatch-ci.yaml` — CI pipeline that runs `pylint` and builds the application Docker image.

This separation keeps the application code independent from the deployment configuration and makes the project easier to maintain and scale.

## Repository structure

```text
quakewatch-repo/
├── .github/
│   └── workflows/
│       └── quakewatch-ci.yaml
├── QuakeWatch-app/
│   ├── app.py
│   ├── dashboard.py
│   ├── utils.py
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── static/
│   └── templates/
├── charts/
│   └── quakewatch-chart/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── .helmignore
│       └── templates/
├── README.md
└── .gitignore
```

## Application setup

Go to the app folder:

```bash
cd QuakeWatch-app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python app.py
```

Then open:

```text
http://localhost:5000
```

## Docker build

Build the container from the application directory:

```bash
cd QuakeWatch-app
docker build -t quakewatch:latest .
```

Run it locally:

```bash
docker run -p 5000:5000 quakewatch:latest
```

## CI pipeline

The workflow runs on every push to non-`main` branches and performs:

- Python environment setup
- `pylint` linting for all Python files in `QuakeWatch-app`
- Docker image build for the application

The workflow is defined in:

```text
.github/workflows/quakewatch-ci.yaml
```

## Helm chart deployment

From the repo root, validate the chart:

```bash
helm lint charts/quakewatch-chart
helm template quakewatch charts/quakewatch-chart
```

Install it locally:

```bash
helm upgrade --install quakewatch charts/quakewatch-chart --namespace quakewatch --create-namespace
```

## Notes

- Keep application source and deployment manifests separate.
- The app image is built from `QuakeWatch-app/Dockerfile`.
- The chart references the container image configured in `charts/quakewatch-chart/values.yaml`.
