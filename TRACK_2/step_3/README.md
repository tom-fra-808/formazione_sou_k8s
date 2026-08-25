<h1 align="center">Step 3 - Helm Chart Flask App</h1>

Creazione di un Helm Chart personalizzato per distribuire su Kubernetes l'immagine Docker generata dalla pipeline Jenkins `flask-app-example-build`.

> [!NOTE]
> L'obiettivo è rendere configurabile il tag dell'immagine da rilasciare senza modificare i manifest Kubernetes.

---

## Cos'è Helm

Helm è un gestore di pacchetti per Kubernetes. Un pacchetto Helm è chiamato **Chart** e contiene template YAML configurabili tramite il file `values.yaml`.

Il flusso dell'esercizio è il seguente:

```text
Pipeline Jenkins
      ↓
Docker Hub: tommasofranco/flask-app:<tag>
      ↓
Helm Chart
      ↓
Deployment e Service Kubernetes
      ↓
Applicazione Flask sulla porta 8000
```

---

## Struttura del progetto

```text
charts/
├── README.md
└── flask-app/
    ├── Chart.yaml
    ├── values.yaml
    ├── templates/
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── _helpers.tpl
    │   └── NOTES.txt
    └── .helmignore
```

---

## Configurazione realizzata

Il Chart è stato inizializzato con `helm create` e successivamente personalizzato con:
> [!IMPORTANT]
> Nella traccia veniva chiesto di usare `helm init` ma questo comando non è più supportato dalle nuove versioni di Helm.
- immagine Docker `tommasofranco/flask-app`;
- tag configurabile tramite `image.tag`;
- Deployment dell'applicazione Flask;
- Service Kubernetes;
- porta del container e del Service impostata su `8000`;
- readiness e liveness probe collegate alla porta HTTP del container.


Durante il test è stata inoltre corretta la porta iniziale `80`: l'applicazione Flask ascolta sulla porta `8000` e la configurazione errata causava il riavvio del Pod con stato `CrashLoopBackOff`.

---

## Validazione e rilascio

Controllo del Chart:

```bash
helm lint ./flask-app
```

Installazione o aggiornamento della release usando il tag `latest`:

```bash
helm upgrade --install flask-app ./flask-app \
  --set image.tag=latest \
  --wait \
  --timeout 2m
```

Per rilasciare un'altra versione è sufficiente sostituire `latest` con un tag realmente pubblicato dalla pipeline.

---

## Verifica

```bash
kubectl get pods -n default
kubectl get services -n default
```

Esposizione locale dell'applicazione:

```bash
kubectl port-forward service/flask-app 8080:8000 -n default
```

L'applicazione è raggiungibile all'indirizzo `http://127.0.0.1:8080`.
