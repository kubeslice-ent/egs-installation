#!/bin/bash

# Set variables
NAMESPACE="green"  # Change if you use a different namespace
DEPLOYMENT_NAME="llm-demo-10"
SERVICE_NAME="llm-inference-10"
MODEL_INPUT="Tell me the city which is the capital of Italy"
PORT_FORWARD_PORT=8080  # Local port for port forwarding

# YAML Manifest
MANIFEST=$(cat <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: llm-inference-10
    purpose: llm-demo-10
  name: llm-demo-10
spec:
  replicas: 1
  selector:
    matchLabels:
      app: llm-inference-10
      purpose: llm-demo-10
  template:
    metadata:
      labels:
        app: llm-inference-10
        purpose: llm-demo-10
    spec:
      containers:
        - command:
            - text-generation-launcher
          resources:
            limits:
              nvidia.com/gpu: "1"
          env:
            - name: MODEL_ID
              value: openai-community/gpt2
            - name: gpus
              value: "all"
            - name: shm-size
              value: "2g"
            - name: HUGGING_FACE_HUB_TOKEN
              value: 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
            - name: MAX_CONCURRENT_REQUESTS
              value: "128"
            - name: MAX_BATCH_TOTAL_TOKENS
              value: "5000"
            - name: DISABLE_CUSTOM_KERNELS
              value: "false"
            - name: USE_FLASH_ATTENTION
              value: "true"
          image: docker.io/aveshasystems/text-generation-inference:2.2.0
          name: text-generation-inference
          ports:
            - containerPort: 80
              name: http
          volumeMounts:
            - mountPath: /data
              name: llm
      tolerations:
        - key: "nvidia.com/gpu"
          effect: "NoSchedule"
          value: "present"
      volumes:
        - name: llm
---
apiVersion: v1
kind: Service
metadata:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: 'true'
  labels:
    purpose: llm-demo-10
  name: llm-inference-10
spec:
  ports:
    - port: 80
      protocol: TCP
      targetPort: 80
  selector:
    app: llm-inference-10
    purpose: llm-demo-10
  type: ClusterIP
EOF
)

# Step 1: Apply the manifests
echo "Applying Kubernetes manifests..."
echo "$MANIFEST" | kubectl apply -f -

# Step 2: Wait for the deployment to become ready
echo "Waiting for deployment to become ready..."
kubectl wait --for=condition=available --timeout=300s deployment/$DEPLOYMENT_NAME -n $NAMESPACE

# Step 3: Port forward the service
echo "Starting port forwarding..."
kubectl port-forward service/$SERVICE_NAME $PORT_FORWARD_PORT:80 -n $NAMESPACE &
PORT_FORWARD_PID=$!

# Wait a few seconds for port forwarding to establish
sleep 20

# Step 4: Test the endpoint with curl
echo "Testing the LLM inference service with curl..."
CURL_RESPONSE=$(curl -s http://localhost:$PORT_FORWARD_PORT/generate \
  -X POST \
  -d "{\"inputs\":\"$MODEL_INPUT\", \"parameters\":{\"max_new_tokens\":50, \"repetition_penalty\": 1}}" \
  -H 'Content-Type: application/json')

# Step 5: Print the response
echo "Response from the model:"
echo "$CURL_RESPONSE" | jq

# Step 6: Cleanup port forwarding
echo "Cleaning up..."
kill $PORT_FORWARD_PID

echo "Script completed."
