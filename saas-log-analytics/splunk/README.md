# JFrog Saas Log Analytics for Splunk

The JFrog Saas Log Analytics for Splunk consists of three segments,

1. Splunk Application - which has the Dashboards for Saas log data visualization
2. Log Collector - which collects the logs from the intended JFrog Cloud instance (NOT for self-hosted type)
3. Log Forwarder - which forwards the converted log data to Splunk observability platform

Below mentioned are the steps to setup the respective segments

## Splunk Application
### Pre-Requisites
1. Working and configured Splunk Enterprise Instance
   1. To setup an instance, refer [here](https://docs.splunk.com/Documentation/Splunk/8.2.6/Installation/Chooseyourplatform)

2. Install the `JFrog Saas Log Analytics` app from Splunkbase [here!](https://splunkbase.splunk.com/app/5023/)

````text
1. Download file from Splunkbase
2. Open Splunk web console as administrator
3. From homepage click on settings wheel in top right of Apps section
4. Click on "Install app from file"
5. Select download file from Splunkbase on your computer
6. Check the upgrade option
7. Click upload
````

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
1. Download all the files from [here](https://github.com/jfrog/jfrog-saas-log-collector/tree/main/saas-log-analytics/splunk/deployments/k8s-collector-forwarder)
   1. 'saas-config.yaml' - Requires editing by Implementer, JFrog Saas Log Collector config file, this file will be used as the k8s secret, once the information is filled, do not checkin as access token etc may get exposed.
   2. 'splunk-config.txt' - Requires editing by Implementer, FluentD Side Car requires these information, usually captures information on Splunk Host, HEC Token etc, this will be used as a config map.
   3. 'deployment.yaml' - Do Not Edit, contains the k8s deployment of saas log collector and fluentd sidecar which will forward the log data to splunk.
   4. 'pvc.yaml' - Do Not Edit unless need to change storage type and value, storage requirements for running, review the allotted storage and type (30 GB default), adjust according to your cluster needs
   5. 'run_commands.txt' - Do Not Edit, sequence of commands that needs to be run to setup the jfrog saas log collector
2. Once done run the following commands, examples for illustration, alter to suit your file paths
   1. Create a namespace, execute - 'kubectl create ns jfrog-saas'
   2. Create k8s secret, execute - 'kubectl create secret generic jfrog-saas-log-collector-secret --from-file=saas-config=saas-config.yaml -n jfrog-saas'
   3. Create k8s configmap, execute - 'kubectl create configmap splunk-settings --from-env-file=splunk-config.txt -n jfrog-saas'
   4. Create PVC for the intended cluster, execute - 'kubectl apply -f pvc.yaml -n jfrog-saas'
   5. Create deployment for the intended cluster, execute - 'kubectl apply -f deployment.yaml -n jfrog-saas'
3. Check the logs on both the containers for the status, if any errors, they should be self explanatory.
   1. For Detail config of JFrog Saas Log Collector, check [here](https://github.com/jfrog/jfrog-saas-log-collector#usage)

## Docker
### (Includes instructions for setting up Collector and Forwarder)

Docker has two sections that needs to be built and configured, one for log collection and other is for forwarding

### Pre-Requisites
1. Working and configured Docker Desktop / Docker Container Interface
2. Log Shipping feature enabled on the intended Jfrog Cloud Instance, refer [here](https://www.jfrog.com/confluence/display/JFROG/Artifactory+REST+API#ArtifactoryRESTAPI-EnableLogCollection) for enabling

### Log Collector Setup
1. Download the log collector build 'Dockerfile' and environment file 'Dockerenvfile.txt' from [here](https://github.com/jfrog/jfrog-saas-log-collector/tree/main/saas-log-analytics/splunk/deployments/docker-log-collector)
2. From the directory where the files are downloaded, run the following command 'docker build -t jfrog/saas-log-collector .'
3. Fill in all the keys with correct values in the 'Dockerenvfile.txt' which reads 'changeme'
4. Run the following command to build the log collector image, execute 'docker run -it --name jfrog-saas-log-collector -v /var/opt/jfrog/saas/logs:/jfrog/saas/logs --env-file Dockerenvfile.txt jfrog/saas-log-collector'
5. This should bring up the log collector container

### Log Forwarder Setup
1. Download the log forwarder build 'Dockerfile' and environment file 'Dockerenvfile_splunk.txt' [here](https://github.com/jfrog/jfrog-saas-log-collector/tree/main/saas-log-analytics/splunk/deployments/docker-log-forwarder)
2. From the directory where the files are downloaded, run the following command 'docker build -t jfrog/fluentd-splunk-saas .'
3. Fill in all the keys with correct values in the 'Dockerenvfile_splunk.txt' which reads 'changeme'
4. Run the following command to build the log collector image, execute 'docker run -it --name jfrog-fluentd-splunk-saas -v /Volumes/data/saas/logs:/jfrog/saas/logs --env-file Dockerenvfile_splunk.txt jfrog/fluentd-splunk-saas'
5. This should bring up the log forwarder container

# Common Configuration Parameters (Covers K8s and Docker deployment methods)

## For Splunk HEC Forwarding

```HEC_HOST``` is the IP address or DNS of Splunk HEC Host

```HEC_PORT``` is the Splunk HEC port which by default is 8088

```HEC_TOKEN``` is the saved generated token from [Configure new HEC token to receive Logs](#configure-new-hec-token-to-receive-logs)

```COM_PROTOCOL``` will be either 'http' or 'https' based on Splunk Server URL

```INSECURE_SSL```if set to 'false' Splunk Host Server SSL Certificate is required, fill the ca_file path, if ssl is enabled, ca file will be used and

#### Configure new HEC token to receive Logs
````text
1. Open Splunk web console as administrator
2. Click on "Settings" in dropdown select "Data inputs"
3. Click on "HTTP Event Collector"
4. Click on "New Token"
5. Enter a "Name" in the textbox
6. (Optional) Enter a "Description" in the textbox
7. Click on the green "Next" button
8. Select App Context of "JFrog Platform Log Analytics" in the dropdown
9. Add "jfrog_splunk" index to store the JFrog platform log data into.
10. Click on the green "Review" button
11. If good, Click on the green "Done" button
12. Save the generated token value
````

## For JFrog Saas Log Collector

```saas_jpd_url``` is the IP address or DNS of Jfrog Cloud Instance

```admin_user``` is the Jfrog Cloud Instance user with Administration rights

```admin_access_token``` is the admin scoped token, refer [Jfrog Instance - Admin Access Token](https://www.jfrog.com/confluence/display/JFROG/Access+Tokens#AccessTokens-GeneratingAdminTokens) on how to get one

```path_to_logs``` or ```target_log_path``` is the directory which should be accessible to collector and forwarder, the collector uses this to download and extract the log files, the forwarder uses this to parse the logs and hold the parse state information. Ensure write permissions to this directory against the userid where the collection and forwarding is being run.

## Dashbaord Samples

Log Analytics Dashboard

![alt text](https://github.com/jfrog/jfrog-saas-log-collector/blob/main/saas-log-analytics/splunk/screensnaps/LogAnalytics.png?raw=true)

Operations Analytics Dashboard

![alt text](https://github.com/jfrog/jfrog-saas-log-collector/blob/main/saas-log-analytics/splunk/screensnaps/OpsAnalytics.png?raw=true)
