<h1 align="center">Step 4: Deploy Helm con Jenkins</h1>

La pipeline Jenkins recupera il Chart Helm dello Step 3 e distribuisce
l'applicazione Flask sul cluster Minikube `lab-k8s` nel namespace
`formazione-sou`.

> [!IMPORTANT]
> Secret dell'agent e file `~/.kube/config` non devono essere salvati nel
> repository.

## Obiettivo

- eseguire il deploy Helm da Jenkins;
- validare il Chart prima dell'installazione;
- installare o aggiornare la release `flask-app`;
- verificare rollout e risorse Kubernetes;
- provare l'applicazione dal Mac.

## Configurazione

| Elemento | Valore |
| --- | --- |
| Repository | `https://github.com/tom-fra-808/formazione_sou_k8s.git` |
| Branch | `main` |
| Jenkins | `http://192.168.33.10:8080` |
| Agent / label | `mac-k8s-agent` / `mac-k8s` |
| Contesto Kubernetes | `lab-k8s` |
| Namespace | `formazione-sou` |
| Release | `flask-app` |
| Chart | `TRACK_2/step_3/charts/flask-app` |
| Immagine | `tommasofranco/flask-app:latest` |

## Perché l'agent è sul Mac

Minikube espone l'API tramite un indirizzo locale presente nel kubeconfig del
Mac, ad esempio `https://127.0.0.1:<porta>`. Da un agent in container,
`127.0.0.1` indicherebbe il container stesso. L'agent viene quindi eseguito
direttamente sul Mac, dove può usare Helm, kubectl e il kubeconfig corretto.

## Prerequisiti

```bash
java -version
command -v git
command -v kubectl
command -v helm

minikube status -p lab-k8s
kubectl config current-context
kubectl get nodes
```

Il contesto deve essere `lab-k8s`. Se il cluster è fermo:

```bash
minikube start -p lab-k8s
```

## Agent Jenkins

Creare un **Permanent Agent** da `Manage Jenkins > Nodes`:

| Campo | Valore |
| --- | --- |
| Nome | `mac-k8s-agent` |
| Remote root | `/Users/tommaso/jenkins-agent` |
| Label | `mac-k8s` |
| Launch method | Inbound agent via WebSocket |

Preparazione:

```bash
mkdir -p /Users/tommaso/jenkins-agent
cd /Users/tommaso/jenkins-agent
curl -fsSLO http://192.168.33.10:8080/jnlpJars/agent.jar
```

Avvio con il secret mostrato da Jenkins:

```bash
java -jar agent.jar \
  -url http://192.168.33.10:8080/ \
  -secret '<SECRET_FORNITO_DA_JENKINS>' \
  -name 'mac-k8s-agent' \
  -webSocket \
  -workDir '/Users/tommaso/jenkins-agent'
```

Il nodo deve risultare `Online`.

## Chart e Jenkinsfile

Il Chart si trova in:

```text
TRACK_2/step_3/charts/flask-app
```

Crea `ServiceAccount`, `Deployment`, `Service` sulla porta `8000` e probe di
liveness/readiness. In questa versione `requests` e `limits` non sono ancora
impostati.

Validazione manuale:

```bash
helm lint TRACK_2/step_3/charts/flask-app

helm template flask-app TRACK_2/step_3/charts/flask-app \
  --namespace formazione-sou \
  --set-string image.tag=latest
```

Il Jenkinsfile usa:

```groovy
agent {
    label 'mac-k8s'
}
```

| Variabile | Valore |
| --- | --- |
| `KUBECONFIG` | `/Users/tommaso/.kube/config` |
| `CHART_PATH` | `TRACK_2/step_3/charts/flask-app` |
| `RELEASE_NAME` | `flask-app` |
| `K8S_NAMESPACE` | `formazione-sou` |

Stage della pipeline:

1. **Checkout** – recupera il repository.
2. **Validate Chart** – esegue `helm lint` e `helm template`.
3. **Deploy** – installa o aggiorna la release.
4. **Verify** – controlla rollout e risorse.

Comando di deploy:

```bash
helm upgrade --install \
  "$RELEASE_NAME" "$CHART_PATH" \
  --namespace "$K8S_NAMESPACE" \
  --create-namespace \
  --set-string image.tag="$IMAGE_TAG" \
  --wait \
  --timeout 2m
```

Verifica eseguita dalla pipeline:

```bash
helm status "$RELEASE_NAME" -n "$K8S_NAMESPACE"

kubectl rollout status "deployment/$RELEASE_NAME" \
  -n "$K8S_NAMESPACE" \
  --timeout=120s

kubectl get deployment,pods,service \
  -n "$K8S_NAMESPACE" \
  -l "app.kubernetes.io/instance=$RELEASE_NAME" \
  -o wide
```

## Job Jenkins

Creare un job `Pipeline script from SCM`:

| Campo | Valore |
| --- | --- |
| SCM | Git |
| Repository URL | `https://github.com/tom-fra-808/formazione_sou_k8s.git` |
| Branch Specifier | `*/main` |
| Script Path | `TRACK_2/step_4/Jenkinsfile` |

Avviare **Build with Parameters** usando:

```text
IMAGE_TAG = latest
```

## Verifica finale

La pipeline deve terminare con `Finished: SUCCESS`.

```bash
helm list -n formazione-sou

kubectl get deployment,pods,service,serviceaccount \
  -n formazione-sou

kubectl get deployment flask-app \
  -n formazione-sou \
  -o jsonpath='{.spec.template.spec.containers[0].image}'; echo

kubectl logs deployment/flask-app -n formazione-sou
```

Risultato atteso: release `deployed`, Deployment `READY 1/1`, Pod `Running` e
immagine `tommasofranco/flask-app:latest`.

## Accesso all'applicazione

```bash
kubectl port-forward service/flask-app 8080:8000 \
  -n formazione-sou
```

Aprire `http://127.0.0.1:8080`. Il terminale deve rimanere aperto.