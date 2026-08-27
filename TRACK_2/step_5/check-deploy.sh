#!/bin/bash
#autenticazione tramite serviceaccount
#export del deployment
#errore se nel deployment mancano readiness liveness probes limits records.

NAMESPACE="formazione-sou"
DEPLOYMENT="flask-app"
SERVICE_ACCOUNT="cluster-reader"
EXPORT_FILE="deployment-export.yaml"

# Ottiene un token temporaneo del Service Account.
TOKEN=$(kubectl create token "$SERVICE_ACCOUNT" -n "$NAMESPACE") || {
    echo "ERRORE: impossibile ottenere il token del Service Account." >&2
    exit 1
}

# Esporta il Deployment autenticandosi con il token del Service Account.
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