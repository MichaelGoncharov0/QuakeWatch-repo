# QuakeWatch

QuakeWatch is a small web dashboard that shows recent earthquakes around the world, using live data from the [USGS Earthquake API](https://earthquake.usgs.gov/fdsnws/event/1/). It shows the latest and strongest quakes, plus graphs of how many happened over time.

This repo has everything needed to run it: the app itself, the Kubernetes setup, and the automation that builds and deploys it.

---

## How it all fits together

```text
  You change code ──► Pull request ──► CI checks it ──► Merge to main
                                                            │
                                                            ▼
                                        CD builds the app image and pushes it to Docker Hub
                                                            │
                                                            ▼
                     Argo CD (running in your cluster) reads this repo and keeps the app deployed
```

- **CI** (`.github/workflows/quakewatch-ci.yaml`) runs on every pull request. It checks the Python code, checks the Helm chart, and makes sure the Docker image builds. If anything fails, the PR can't be merged.
- **CD** (`.github/workflows/quakewatch-cd.yaml`) runs when app code is merged to `main`. It builds the image and pushes it to Docker Hub as [`michaelgoncharov0/quakewatch`](https://hub.docker.com/r/michaelgoncharov0/quakewatch).
- **Argo CD** watches the `quakewatch-chart/` folder on `main` and makes the cluster match it. You never have to deploy by hand.

---

## What you need

You only need to install these once.

| Tool | What it's for | How to get it |
|---|---|---|
| **Docker Desktop** | Runs containers and a local Kubernetes cluster | [Download](https://www.docker.com/products/docker-desktop/) |
| **Helm** | Installs apps into Kubernetes | Mac: `brew install helm` · [Other systems](https://helm.sh/docs/intro/install/) |
| **Git** | Downloads this repo | Mac: comes with Xcode tools · [Other systems](https://git-scm.com/downloads) |

`kubectl` (the Kubernetes command-line tool) comes with Docker Desktop, so you don't need to install it separately.

### Turn on Kubernetes in Docker Desktop

1. Open Docker Desktop and go to **Settings → Kubernetes**.
2. Tick **Enable Kubernetes** and click **Apply & restart**.
3. Wait until the bottom-left corner shows Kubernetes as running (green).

Check it works:

```bash
kubectl config use-context docker-desktop
kubectl get nodes
```

You should see one node with `STATUS` set to `Ready`.

---

## Set everything up (step by step)

Open a terminal and run each step in order. Each one tells you what you should see before moving on.

### 1. Download the repo

```bash
git clone https://github.com/MichaelGoncharov0/QuakeWatch-repo.git
cd QuakeWatch-repo
```

### 2. Install Argo CD

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd -n argocd --create-namespace
```

This can take a few minutes the first time. Check on it with:

```bash
kubectl -n argocd get pods
```

Wait until every pod shows `Running` (one pod named `argocd-redis-secret-init-...` will show `Completed`, which is fine).

### 3. Tell Argo CD to deploy QuakeWatch

```bash
kubectl apply -f argocd/quakewatch-application.yaml
```

Argo CD now downloads the chart from GitHub and starts the app. After a minute or two, check:

```bash
kubectl -n quakewatch get pods
```

You should see a few `quakewatch-...` pods with `STATUS` set to `Running`.

### 4. Open the app

Go to **http://localhost:30080** in your browser. 🎉

### 5. (Optional) Open the Argo CD dashboard

Get the admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

Then, in a **separate terminal window** (this command keeps running until you close it):

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open **https://localhost:8080**. Your browser will warn about the certificate; that's expected for a local setup, so continue anyway. Log in with username `admin` and the password from above.

You'll see a `quakewatch` tile. Green **Synced** and **Healthy** mean everything is running as described in Git.

---

## Making changes

1. Create a branch, make your change, and open a pull request to `main`.
2. Wait for the **CI** check to go green, then merge.
3. What happens next depends on what you changed:
   - **Chart settings** (anything in `quakewatch-chart/`): Argo CD applies it automatically within about 3 minutes. Click **Refresh** in the Argo CD dashboard to make it happen right away.
   - **App code** (anything in `QuakeWatch-app/`): CD builds a new image and pushes it to Docker Hub. The cluster runs the `latest` image, so restart the app to pick it up:
     ```bash
     kubectl -n quakewatch rollout restart deployment quakewatch
     ```

> Don't change things in the cluster directly with `kubectl edit` or `kubectl scale`. Argo CD will notice and put them back the way Git says. Always change the repo instead.

---

## Starting over after a cluster reset

Using **Reset Kubernetes Cluster** in Docker Desktop (or turning Kubernetes off and on) wipes everything inside the cluster. Your code and images are safe; they live in GitHub and Docker Hub.

To get everything back, just repeat **steps 2–4** above:

```bash
helm install argocd argo/argo-cd -n argocd --create-namespace
kubectl apply -f argocd/quakewatch-application.yaml
```

The Argo CD admin password is new after every install, so get it again with the command from step 5.

A normal restart of your computer or Docker Desktop doesn't need any of this; everything comes back by itself. Only the Argo CD dashboard tunnel (`kubectl port-forward ...`) needs to be started again.

---

## Other ways to run the app

### With Python (for working on the code)

```bash
cd QuakeWatch-app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
FLASK_DEBUG=1 python app.py
```

Open **http://localhost:5000**. `FLASK_DEBUG=1` reloads the app whenever you save a file.

### With Docker only (no Kubernetes)

Use the published image:

```bash
docker run --rm -p 5000:5000 michaelgoncharov0/quakewatch:latest
```

Or build your own from the code:

```bash
docker build -t quakewatch:dev QuakeWatch-app
docker run --rm -p 5000:5000 quakewatch:dev
```

Open **http://localhost:5000**. Press `Ctrl+C` to stop it.

---

## Something not working?

| What you see | What to do |
|---|---|
| `kubectl` says it can't connect | Make sure Docker Desktop is open and Kubernetes is enabled and green. Run `kubectl config use-context docker-desktop`. |
| Pods stuck in `Pending` or `ContainerCreating` | Usually still downloading images. Give it a few minutes and check again. |
| Pods show `ImagePullBackOff` | The cluster can't download the image. Check your internet connection and that the image exists on Docker Hub. |
| http://localhost:30080 doesn't load | Run `kubectl -n quakewatch get pods` and wait until they're `Running`. |
| Argo CD tile shows **OutOfSync** | Click **Refresh**, then **Sync**. If it stays red, click the tile to see which resource has a problem. |
| Argo CD dashboard won't open | The `kubectl port-forward ...` command must stay running in its own terminal window. |
| `helm install argocd` says the name is already in use | Argo CD is already installed. Skip to step 3. |

---

## Reference

### Repository layout

```text
QuakeWatch-repo/
├── QuakeWatch-app/                  The Flask web app and its Dockerfile (details in its own README)
├── quakewatch-chart/                Helm chart that describes how the app runs in Kubernetes
├── argocd/
│   └── quakewatch-application.yaml  Tells Argo CD where the chart is and where to deploy it
└── .github/workflows/
    ├── quakewatch-ci.yaml           Checks every pull request
    └── quakewatch-cd.yaml           Builds and pushes the image after a merge
```

More about the app itself (pages, API endpoints, code layout): [`QuakeWatch-app/README.md`](QuakeWatch-app/README.md).

### What gets deployed

All settings live in `quakewatch-chart/values.yaml`.

| Piece | What it does |
|---|---|
| Deployment | Runs the app (as a non-root user), with health checks on `/health` |
| Service | Makes the app reachable at `localhost:30080` |
| Autoscaler (HPA) | Runs between 2 and 5 copies depending on CPU load (see note below) |
| PodDisruptionBudget | Keeps the app up during cluster maintenance |
| PriorityClass | Gives the app priority over less important workloads |
| ConfigMap | Normal settings such as app name and log level |
| Secret | Passwords and tokens (demo values only) |
| CronJob | Pings the app's health check every 5 minutes |
| Storage, Ingress | Included but turned off by default |

**About the autoscaler:** it needs a component called *metrics-server*, which Docker Desktop doesn't include. Without it the app still runs fine, it just won't scale. To add it:

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm install metrics-server metrics-server/metrics-server -n kube-system \
  --set "args={--kubelet-insecure-tls}"
```

### A note on secrets

The passwords in `values.yaml` are placeholders for demo purposes. Never commit real passwords or tokens to this repo.
