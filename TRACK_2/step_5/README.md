<h1 align="center">Step 5: Check Deployment Best Practices</h1>

Script Bash che esporta il Deployment Flask usando il ServiceAccount
`cluster-reader` e verifica la presenza di probe e risorse.

## Obiettivo

Lo script deve:

- autenticarsi tramite il ServiceAccount `cluster-reader`;
- esportare in YAML il Deployment `flask-app`;
- verificare `readinessProbe`, `livenessProbe`, `requests` e `limits`;
- restituire `0` se tutti gli attributi esistono, altrimenti `1`.

La soluzione scelta usa `kubectl` e `grep`, senza dipendenze aggiuntive.

## Configurazione

| Elemento | Valore |
| --- | --- |
| Context | `lab-k8s` |
| Namespace | `formazione-sou` |
| Deployment | `flask-app` |
| ServiceAccount | `cluster-reader` |
| Script | `TRACK_2/step_5/check-deploy.sh` |
| Export | `deployment-export.yaml` |

`cluster-reader` è soltanto il nome scelto per il ServiceAccount: i permessi
dipendono dalle regole RBAC associate.

## Prerequisiti

```bash
kubectl config current-context
kubectl get deployment flask-app -n formazione-sou
kubectl get serviceaccount cluster-reader -n formazione-sou
```

Se ServiceAccount e RBAC non esistono, creare la configurazione minima:

```bash
kubectl create serviceaccount cluster-reader \
  --namespace formazione-sou

kubectl create role cluster-reader \
  --verb=get \
  --resource=deployments.apps \
  --resource-name=flask-app \
  --namespace formazione-sou

kubectl create rolebinding cluster-reader-binding \
  --role=cluster-reader \
  --serviceaccount=formazione-sou:cluster-reader \
  --namespace formazione-sou
```

Verificare il permesso necessario:

```bash
kubectl auth can-i get deployment/flask-app \
  --as=system:serviceaccount:formazione-sou:cluster-reader \
  --namespace formazione-sou
```

Il risultato deve essere `yes`.

## Script `check-deploy.sh`

```bash
#!/usr/bin/env bash

NAMESPACE="formazione-sou"
DEPLOYMENT="flask-app"
SERVICE_ACCOUNT="cluster-reader"
EXPORT_FILE="deployment-export.yaml"

TOKEN=$(kubectl create token "$SERVICE_ACCOUNT" -n "$NAMESPACE") || {
  echo "ERRORE: impossibile ottenere il token del Service Account." >&2
  exit 1
}

if ! kubectl --token="$TOKEN" get deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" -o yaml > "$EXPORT_FILE"; then
  echo "ERRORE: impossibile esportare il Deployment." >&2
  exit 1
fi

ERROR=0

for ATTRIBUTE in readinessProbe livenessProbe requests limits; do
  if ! grep -q "^[[:space:]]*$ATTRIBUTE:" "$EXPORT_FILE"; then
    echo "ERRORE: attributo $ATTRIBUTE mancante." >&2
    ERROR=1
  fi
done

if [ "$ERROR" -ne 0 ]; then
  exit 1
fi

echo "OK: il Deployment contiene tutti gli attributi richiesti."
exit 0
```

## Funzionamento

1. `kubectl create token` genera un token temporaneo del ServiceAccount.
2. `kubectl --token` esporta il Deployment nel file YAML.
3. Il ciclo `for` cerca i quattro attributi con `grep`.
4. Se almeno una chiave manca, lo script termina con `exit 1`.

Il kubeconfig e il context corrente indicano allo script quale cluster
contattare. Il token identifica invece il ServiceAccount usato nella richiesta.

## Esecuzione

```bash
cd TRACK_2/step_5
chmod +x check-deploy.sh
./check-deploy.sh
echo $?
```

Il file `deployment-export.yaml` viene creato nella directory da cui si avvia lo
script. Eseguendolo da `TRACK_2/step_5`, il file rimane nella cartella corretta.

Esito positivo:

```text
OK: il Deployment contiene tutti gli attributi richiesti.
```

Exit code atteso: `0`.

Aggiornare la release tramite la pipeline dello Step 4 oppure manualmente:

```bash
helm upgrade --install flask-app \
  TRACK_2/step_3/charts/flask-app \
  --namespace formazione-sou \
  --create-namespace \
  --set-string image.tag=latest \
  --wait \
  --timeout 2m
```

Verificare il rollout e rieseguire lo script:

```bash
kubectl rollout status deployment/flask-app \
  -n formazione-sou \
  --timeout=120s

cd TRACK_2/step_5
./check-deploy.sh
