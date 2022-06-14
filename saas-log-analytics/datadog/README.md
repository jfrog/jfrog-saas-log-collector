# JFrog Saas Log Analytics for Datadog

The JFrog Saas Log Analytics for Datadog consists of three segments,

1. Datadog Dashboards - which has the Dashboards for Saas log data visualization
2. Log Collector - which collects the logs from the intended JFrog Cloud instance (NOT for self-hosted type)
3. Log Forwarder - which forwards the converted log data to Datadog observability platform

# Table of Contents
1. [Datadog Dashboards](#datadog-dashboards)
2. [Kubernetes](#kubernetes)
3. [Docker](#docker)
4. [Common Configuration Parameters ](#common-configuration-parameters)
5. [Dashboard Samples](#dashboard-samples)

Below mentioned are the steps to setup the respective segments

## Datadog Dashboards
### Pre-Requisites
1. Working and configured Datadog Instance
   1. To get familiarised, refer [here](https://docs.datadoghq.com/getting_started/)

````text

Optional Step if a dedicated index is needed for data separation in Datadog, skip this if you do not wish to separate the logs

1. Login to Datadog
2. Navigate to the Configuration section under Logs 
3. Click on Indexes Tab, Click on the New Index option
4. Under the source provide the source filter for the logs, ex: 'source:jfrog_saas', note this value has to match the dd_source config in the fluentd.conf in the match section (advanced users only)
5. Save the index and ensure there are no other indexes with '*' as the source, if yes, all the Jfrog Logs will reside under that index 
````

2. Add the Facets for Datadog, else the search may fail, below listed are the full set of facets needed
````text
Common Facets (i.e which is applicable for both the Saas Analytics Dashboards)

   a. @log_source
   b. @instance
   c. @tag

For Log Analysis

   a. @request_url
   b. @repo
   c. @image
   d. @request_content_length
   e. @response_content_length
   f. @remote_address
   g. @upload_size
    
For Operation Analysis

   a. @entity_name
   b. @event_type
   c. @event
   d. @logged_principal
````

3. Once the facets are defined, Import the Dashboard json files, for instructions click [here](https://docs.datadoghq.com/dashboards/#copy-import-or-export-dashboard-json)
   1. JFrog Saas Log Analysis Dashboard - click [here](https://raw.githubusercontent.com/jfrog/jfrog-saas-log-collector/main/saas-log-analytics/datadog/dashboards/JFrogSaasLogAnalytics.json)
   2. JFrog Saas Operations Analysis Dashboard - click [here](https://raw.githubusercontent.com/jfrog/jfrog-saas-log-collector/main/saas-log-analytics/datadog/dashboards/JFrogSaasOperationsAnalytics.json)
   
## Kubernetes 
### (Includes instructions for setting up Collector and Forwarder)

### Pre-Requisites
1. Working and configured Kubernetes Cluster - Amazon EKS / Google GKE / Azure AKS / Docker Desktop / Minikube
   1. Recommended Kubernetes Version 1.20 and Above
   2. For Google GKE, refer [GKE Guide](https://cloud.google.com/kubernetes-engine/docs/how-to)
   3. For Amazon EKS, refer [EKS Guide](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)
   4. For Azure AKS, refer [AKS Guide](https://docs.microsoft.com/en-us/azure/aks/)
   5. For Docker Desktop and Kubernetes, refer [DOCKER Guide](https://docs.docker.com/desktop/kubernetes/)
2. 'kubectl' utility on the workstation which is capable of connecting to the Kubernetes cluster
   1. For Installation and usage refer [KUBECTL Guide](https://kubernetes.io/docs/tasks/tools/)
3. Log Shipping feature enabled on the intended Jfrog Cloud Instance, refer [here](https://www.jfrog.com/confluence/display/JFROG/Artifactory+REST+API#ArtifactoryRESTAPI-EnableLogCollection) for enabling

### Installation
1. Download all the files from [here](https://github.com/jfrog/jfrog-saas-log-collector/tree/main/saas-log-analytics/datadog/deployments/k8s-collector-forwarder)
   1. 'saas-config.yaml' - Requires editing by Implementer, JFrog Saas Log Collector config file, this file will be used as the k8s secret, once the information is filled, do not checkin as access token etc may get exposed.
   2. 'datadog-config.txt' - Requires editing by Implementer, FluentD Side Car requires these information, usually captures information on Datadog API Key, this will be used as a config map.
   3. 'deployment.yaml' - Do Not Edit, contains the k8s deployment of saas log collector and fluentd sidecar which will forward the log data to datadog.
   4. 'pvc.yaml' - Do Not Edit unless need to change storage type and value, storage requirements for running, review the allotted storage and type (30 GB default), adjust according to your cluster needs
   5. 'run_commands.txt' - Do Not Edit, sequence of commands that needs to be run to setup the jfrog saas log collector
2. Once done run the following commands, examples for illustration, alter to suit your file paths
   1. Create a namespace, execute - ``` kubectl create ns jfrog-saas```
   2. Create k8s secret, execute - ``` kubectl create secret generic jfrog-saas-log-collector-secret --from-file=saas-config=saas-config.yaml -n jfrog-saas```
   3. Create k8s configmap, execute - ``` kubectl create configmap datadog-settings --from-env-file=datadog-config.txt -n jfrog-saas```
   4. Create PVC for the intended cluster, execute - ``` kubectl apply -f pvc.yaml -n jfrog-saas```
   5. Create deployment for the intended cluster, execute - ``` kubectl apply -f deployment.yaml -n jfrog-saas```
3. Check the logs on both the containers for the status, if any errors, they should be self explanatory.
   1. For Detail config of JFrog Saas Log Collector, check [here](https://github.com/jfrog/jfrog-saas-log-collector#usage)

## Docker
### (Includes instructions for setting up Collector and Forwarder)

Docker has two sections that needs to be built and configured, one for log collection and other is for forwarding

### Pre-Requisites
1. Working and configured Docker Desktop / Docker Container Interface
2. Log Shipping feature enabled on the intended Jfrog Cloud Instance, refer [here](https://www.jfrog.com/confluence/display/JFROG/Artifactory+REST+API#ArtifactoryRESTAPI-EnableLogCollection) for enabling

### Log Collector Setup
1. Download the log collector build 'Dockerfile' and environment file 'Dockerenvfile.txt' from [here](https://github.com/jfrog/jfrog-saas-log-collector/tree/main/saas-log-analytics/datadog/deployments/docker-log-collector)
2. From the directory where the files are downloaded, run the following command ``` docker build -t jfrog/saas-log-collector . ``` *Note - ```.``` is part of the command
3. Fill in all the keys with correct values in the 'Dockerenvfile.txt' which reads 'changeme'
4. Run the following command to build the log collector image, execute ``` docker run -it --name jfrog-saas-log-collector -v /var/opt/jfrog/saas/logs:/jfrog/saas/logs --env-file Dockerenvfile.txt jfrog/saas-log-collector ```
5. This should bring up the log collector container

### Log Forwarder Setup
1. Download the log forwarder build 'Dockerfile' and environment file 'Dockerenvfile_datadog.txt' [here](https://github.com/jfrog/jfrog-saas-log-collector/tree/main/saas-log-analytics/datadog/deployments/docker-log-forwarder)
2. From the directory where the files are downloaded, run the following command ``` docker build -t jfrog/fluentd-datadog-saas . ``` *Note - ```.``` is part of the command
3. Fill in all the keys with correct values in the 'Dockerenvfile_datadog.txt' which reads 'changeme'
4. Run the following command to build the log collector image, execute ``` docker run -it --name jfrog-fluentd-datadog-saas -v /Volumes/data/saas/logs:/jfrog/saas/logs --env-file Dockerenvfile_datadog.txt jfrog/fluentd-datadog-saas ```
5. This should bring up the log forwarder container

# Common Configuration Parameters 
### (Covers K8s and Docker deployment methods)

## For Datadog Forwarding

```DATADOG_API_KEY``` is the Datadog API Key which is required to send data to Datadog

## For JFrog Saas Log Collector

```saas_jpd_url``` is the IP address or DNS of Jfrog Cloud Instance

```admin_user``` is the Jfrog Cloud Instance user with Administration rights

```admin_access_token``` is the admin scoped token, refer [Jfrog Instance - Admin Access Token](https://www.jfrog.com/confluence/display/JFROG/Access+Tokens#AccessTokens-GeneratingAdminTokens) on how to get one

```path_to_logs``` or ```target_log_path``` is the directory which should be accessible to collector and forwarder, the collector uses this to download and extract the log files, the forwarder uses this to parse the logs and hold the parse state information. Ensure write permissions to this directory against the userid where the collection and forwarding is being run.

# Dashboard Samples

Log Analytics Dashboard

![alt text](https://github.com/jfrog/jfrog-saas-log-collector/blob/main/saas-log-analytics/datadog/screensnaps/LogAnalytics.png?raw=true)

Operations Analytics Dashboard

![alt text](https://github.com/jfrog/jfrog-saas-log-collector/blob/main/saas-log-analytics/datadog/screensnaps/OpsAnalytics.png?raw=true)
