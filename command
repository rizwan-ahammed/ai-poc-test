#Install Kserve
https://github.com/rizwan-ahammed/ai-poc-test/blob/main/quick_install.sh

#connect cluster 
gcloud container clusters get-credentials ai-poc-cluster-v32 --region us-central1 --project gcp-poc-321808

# NodeGroup
 gcloud container node-pools create gpu-pool-1 \
   --cluster ai-poc-cluster-v32 --region us-central1 \
   --node-locations us-central1-b \
   --machine-type g2-standard-4 --num-nodes 1 \
   --accelerator type=nvidia-l4,count=1,gpu-driver-version=default,gpu-sharing-strategy=time-sharing,max-shared-clients-per-gpu=32 \
   --enable-autoupgrade \
   --disk-size 150GB \
   --disk-type pd-standard

# Get gpu 
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, gpu: .status.capacity."nvidia.com/gpu"}'


# Deploy the InferenceService - GenAI

kubectl apply -n kserve-test -f - <<EOF
apiVersion: "serving.kserve.io/v1beta1"
kind: "InferenceService"
metadata:
  name: "qwen-llm"
  namespace: kserve-test
spec:
  predictor:
    model:
      modelFormat:
        name: huggingface
      args:
        - --model_name=qwen
      storageUri: "hf://Qwen/Qwen2.5-0.5B-Instruct"
      resources:
        limits:
          cpu: "2"
          memory: 6Gi
          nvidia.com/gpu: "1"
        requests:
          cpu: "1"
          memory: 4Gi
          nvidia.com/gpu: "1"
EOF

kubectl get inferenceservices qwen-llm -n kserve-test

kubectl logs 

kubectl describe 


kubectl port-forward service/qwen-llm-predictor 8000:80 -n kserve-test

export INGRESS_HOST=localhost
export INGRESS_PORT=8000

SERVICE_HOSTNAME=$(kubectl get inferenceservice qwen-llm -n kserve-test -o jsonpath='{.status.url}' | cut -d "/" -f 3)

cat <<EOF > "./chat-input.json"
{
  "model": "qwen",
  "messages": [
    {
      "role": "system",
      "content": "You are a helpful assistant that provides clear and concise answers."
    },
    {
      "role": "user",
      "content": "Write a short poem about artificial intelligence and machine learning."
    }
  ],
  "max_tokens": 150,
  "temperature": 0.7,
  "stream": false
}
EOF

curl -v -H "Host: ${SERVICE_HOSTNAME}" -H "Content-Type: application/json" "http://${INGRESS_HOST}:${INGRESS_PORT}/openai/v1/chat/completions" -d @./chat-input.json


# Deploy the InferenceService - Predictive Inference
kubectl apply -n kserve-test -f - <<EOF
apiVersion: "serving.kserve.io/v1beta1"
kind: "InferenceService"
metadata:
  name: "sklearn-iris"
  namespace: kserve-test
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn
      storageUri: "gs://kfserving-examples/models/sklearn/1.0/model"
      resources:
        requests:
          cpu: "100m"
          memory: "512Mi"
        limits:
          cpu: "1"
          memory: "1Gi"
EOF

kubectl get inferenceservices sklearn-iris -n kserve-test


kubectl port-forward service/sklearn-iris-predictor 8000:80 -n kserve-test

export INGRESS_HOST=localhost
export INGRESS_PORT=8000

SERVICE_HOSTNAME=$(kubectl get inferenceservice sklearn-iris -n kserve-test -o jsonpath='{.status.url}' | cut -d "/" -f 3)

https://gist.github.com/curran/a08a1080b88344b0c8a7

cat <<EOF > "./iris-input.json"
{
  "instances": [
    [6.8,  2.8,  4.8,  1.4],
    [6.0,  3.4,  4.5,  1.6]
  ]
}
EOF


curl -v -H "Host: ${SERVICE_HOSTNAME}" -H "Content-Type: application/json" "http://${INGRESS_HOST}:${INGRESS_PORT}/v1/models/sklearn-iris:predict" -d @./iris-input.json




# Kv Cache Offloading

git clone git@github.com:rizwan-ahammed/ai-poc-test.git
cd ai-poc-test
cat 03-redis-deployment.yaml
kubectl apply -f 03-redis-deployment.yaml

cat 02-lmcache-config.yaml
kubectl apply -f 02-lmcache-config.yaml


cat 04-inferenceservice.yaml
kubectl apply -f 04-inferenceservice.yaml

kubectl port-forward svc/huggingface-llama3-predictor 8080:80 -n kserve

curl -X POST \
  "http://localhost:8080/openai/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "dialogpt",
    "messages": [
      {"role": "system", "content": "You are a helpful AI coding assistant."},
      {"role": "user", "content": "Write a Python function to calculate fibonacci numbers"},
      {"role": "assistant", "content": "Here is a Python function to calculate Fibonacci numbers:"},
      {"role": "user", "content": "Now write a function to calculate factorial"}
    ],
    "max_tokens": 100,
    "temperature": 0.7
  }'


exec to redis 
redis-cli 
keys *
