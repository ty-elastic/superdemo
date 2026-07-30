from flask import Flask, request
import logging
import os
from kubernetes import client, config, utils
import yaml
import tempfile
import json
import datetime
app = Flask(__name__)
app.logger.setLevel(logging.INFO)

core_api=None
apps_api=None
api=None

deployments=None

def get_current_namespace() -> str | None:
    namespace_file_path = "/var/run/secrets/kubernetes.io/serviceaccount/namespace"
    if os.path.exists(namespace_file_path):
        with open(namespace_file_path, "r") as f:
            return f.read().strip()
    return None

def init_k8s(incluster=True):
    global core_api, apps_api, api, deployments
    
    if incluster:
        config.load_incluster_config()
    else:
        config.load_kube_config()

    core_api = client.CoreV1Api()
    apps_api = client.AppsV1Api()
    api = client.ApiClient()
    
    #deployments = get_deployments(os.environ['NAMESPACE'])

def get_deployments(namespace):
    ret = apps_api.list_namespaced_deployment(namespace)
    deployments = {}
    for item in ret.items:
        print(item.metadata.name)
        if 'kubectl.kubernetes.io/last-applied-configuration' in item.metadata.annotations:
            deployments[item.metadata.name] = json.loads(item.metadata.annotations['kubectl.kubernetes.io/last-applied-configuration'])
        
    return deployments

def get_pods(namespace):
    print("Listing pods with their IPs:")
    ret = core_api.list_namespaced_pod(namespace)
    return ret.items

def get_deployment(namespace, name):
    ret = apps_api.read_namespaced_deployment(name=name, namespace=namespace)
    return ret

def delete_deployment(namespace, name):
    return apps_api.delete_namespaced_deployment(name=name, namespace=namespace)

def add_deployment(namespace, body):
    return apps_api.create_namespaced_deployment(body=body, namespace=namespace)

def patch_configmap(namespace, deployment_name, configmap_name, patch):
    core_api.patch_namespaced_config_map(
            name=configmap_name,
            namespace=namespace,
            body=patch
        )

    return restart_deployment(namespace, deployment_name)

def restart_deployment(namespace, name):

    # Get the current Deployment object
    deployment = apps_api.read_namespaced_deployment(name=name, namespace=namespace)

    # Ensure the Pod template metadata and annotations exist
    if not deployment.spec.template.metadata:
        deployment.spec.template.metadata = client.V1ObjectMeta()
    if not deployment.spec.template.metadata.annotations:
        deployment.spec.template.metadata.annotations = {}

    # Update the 'kubectl.kubernetes.io/restartedAt' annotation
    # with the current timestamp to trigger a rollout restart
    current_timestamp = datetime.datetime.utcnow()
    current_timestamp = str(current_timestamp.isoformat("T") + "Z")

    deployment.spec.template.metadata.annotations['kubectl.kubernetes.io/restartedAt'] = current_timestamp

    print(deployment)

    # Patch the Deployment with the updated annotation
    return apps_api.patch_namespaced_deployment(name=name, namespace=namespace, body=deployment, pretty='true')

def add_deployment(namespace, name):
    doc = deployments[name]

    return apps_api.create_namespaced_deployment(
        body=doc,
        namespace=namespace
    )

@app.post('/service/<namespace>/<service>/<state>')
def change_service_status(namespace, service, state):
    print("HERE", flush=True)

    try:
        if state == 'up':
            ret = add_deployment(namespace, service)
            return {'status': 'success'}, 200
        elif state == 'down':
            ret = delete_deployment(namespace, service)
            return {'status': 'success'}, 200
        elif state == 'restart':
            print(service)
            ret = restart_deployment(namespace, service)
            return {'status': 'success'}, 200
    except Exception as e:
        return {'status': 'fail', "reason": e.reason}, e.status

# if __name__ == "__main__":
#     init_k8s(incluster=False)
# else:
#     print("incluster")
#     init_k8s(incluster=True)

print("incluster=True")
init_k8s(incluster=True)