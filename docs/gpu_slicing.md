# GPU Slicing on AWS EKS with Karpenter

## Overview

GPU-intensive workloads often lead to high operational costs, especially when full GPU resources are underutilized. GPU Slicing enables sharing GPU resources among multiple workloads, improving utilization and reducing costs. This guide explains how to enable GPU Slicing on AWS EKS and integrate it with Karpenter for autoscaling.

### Prerequisites

1. EKS Cluster: Ensure your cluster is running a version of Kubernetes that supports device plugins (1.21 or later).

2. NVIDIA GPUs: Nodes with NVIDIA GPUs must be present.

3. NVIDIA GPU Device Plugin: Install the NVIDIA GPU Device Plugin on the cluster.

4. Karpenter Autoscaler: Installed and configured on the cluster.

5. kubectl: Ensure you have access to the cluster.

### Steps to Enable GPU Slicing

1. ### Install the NVIDIA GPU Operator

   The NVIDIA GPU Operator simplifies the setup of GPU workloads, including enabling MIG (Multi-Instance GPU) for slicing.

   a. Add the NVIDIA Helm repository:
   ```
   helm repo add nvidia https://nvidia.github.io/gpu-operator
   helm repo update
   ```

   b. Install the NVIDIA GPU Operator:
   ```
   helm install nvidia-gpu-operator nvidia/gpu-operator --namespace gpu-operator --create-namespace
   ```

   c. Verify that the operator is running:
   ```
   kubectl get pods -n gpu-operator

2. ### Configure MIG on Supported GPUs

   NVIDIA A100 and other GPUs support MIG, which allows for GPU slicing.

   a. Edit the ClusterPolicy resource created by the GPU Operator to enable MIG mode:
      ```
      kubectl edit clusterpolicy gpu-cluster-policy
      ```

   b. Update the migStrategy field to mixed or single:
      ```
      spec:
        migStrategy: "mixed"
      ```

   c. Apply the configuration and restart the GPU operator pods.

   d. Verify MIG instances:
      ```
      kubectl logs -n gpu-operator <nvidia-device-plugin-pod>

3. ### Deploy a GPU-Sliced Workload

   a. Define the workload to request GPU slices:
   ```
   apiVersion: v1
   kind: Pod
   metadata:
     name: gpu-sliced-workload
   spec:
     containers:
     - name: ai-job
       image: nvidia/cuda:11.8-base
       resources:
         limits:
           nvidia.com/mig-1g.5gb: 1  # Request a MIG profile
   ```

   b. Apply the configuration:
   ```
   kubectl apply -f gpu-sliced-workload.yaml
   ```
