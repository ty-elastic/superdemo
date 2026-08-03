
import logging
import json
import requests
from datetime import datetime, timezone
import re
#import yaml
import ruamel.yaml
import os
import click
import sys
from ruamel.yaml import YAML
from ruamel.yaml.compat import StringIO
from dotenv import dotenv_values
from io import StringIO
import hashlib

class MyYAML(YAML):
    def dump(self, data, stream=None, **kw):
        inefficient = False
        if stream is None:
            inefficient = True
            stream = StringIO()
        YAML.dump(self, data, stream, **kw)
        if inefficient:
            return stream.getvalue()


def load_knowledge(kibana_server, kibana_auth):
    directory_path = "knowledge"
    target_extension = ".json"

    entries = []
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:
                    #content = file.read()
                    knowledge = json.load(fileo)
                    entries.append(knowledge)
    #print(entries)
    body = {
        "entries": entries
    }
    resp = requests.post(f"{kibana_server}/internal/observability_ai_assistant/kb/entries/import",
                        json=body,
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    print(resp.json())

def load_new_knowledge(es_host, es_auth):
    directory_path = "knowledge"
    target_extension = ".json"

    mappings={
        "mappings": {
            "properties": {
                "text": {
                    "type": "semantic_text"
                },
                "id": {
                    "type": "keyword"
                },
                "title": {
                    "type": "semantic_text"
                }
            }
        }
    }

    resp = requests.put(f"{es_host}/rca_knowledge",
                        json=mappings,
                        headers={"Content-Type": "application/json", f"Authorization": es_auth})
    print(resp.json())

    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:
                    jcontent = json.load(fileo)

                    resp = requests.post(f"{es_host}/rca_knowledge/_doc/",
                    json=jcontent,
                    headers={"Content-Type": "application/json", f"Authorization": es_auth})
                    print(resp.json())





def backup_workflows(kibana_server, kibana_auth):
    
    resp = requests.get(f"{kibana_server}/api/workflows?size=50&page=1",
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    #print(resp.json())
    
    for workflow in resp.json()['results']:
        # with open(f"workflows/{workflow['definition']['name']}.json", "w") as json_file:
        #     json.dump(workflow['definition'], json_file, indent=2)
        with open(f"backup/workflows/{workflow['definition']['name']}.yaml", "w") as yaml_file:
            #yaml_file.write(workflow['yaml'])
            #yaml.dump(workflow['definition'], yaml_file, default_flow_style=False)
  
  
            yaml = MyYAML()

            yaml_stream = StringIO(workflow['yaml'])
            parsed = yaml.load(yaml_stream)
            
            print(parsed['name'])
            
            if 'consts' in parsed:
                if 'kbn_host' in parsed['consts']:
                    parsed['consts']['kbn_host'] = 'TBD'
                if 'kbn_auth' in parsed['consts']:
                    parsed['consts']['kbn_auth'] = 'TBD'
                if 'es_host' in parsed['consts']:
                    parsed['consts']['es_host'] = 'TBD'   
                if 'ai_connector' in parsed['consts']:
                    parsed['consts']['ai_connector'] = 'TBD'   
                if 'ai_proxy' in parsed['consts']:
                    parsed['consts']['ai_proxy'] = 'TBD'  
                if 'snow_host' in parsed['consts']:
                    parsed['consts']['snow_host'] = 'TBD'  
                if 'snow_auth' in parsed['consts']:
                    parsed['consts']['snow_auth'] = 'TBD'  

            yaml = MyYAML()
            yaml.width = float("inf") # Set the width attribute of the YAML instance

            #yaml.dump(parsed)
            yaml.dump(parsed, yaml_file)
  
  
def delete_existing_workflow(kibana_server, kibana_auth, es_host, workflow_name):
    
    print("search workflows...")
    resp = requests.get(f"{kibana_server}/api/workflows?size=50&page=1",
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    #print(resp.json())
    print("done")
    
    for workflow in resp.json()['results']:
        try:
        
            
            if workflow['name'] == workflow_name:
                print(f"deleting {workflow['name']}")
                delete_body = {
                    "ids": [f"{workflow['id']}"]
                }
                #print(delete_body)
                
                resp = requests.delete(f"{kibana_server}/api/workflows",
                                    json=delete_body,
                                    headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                print(resp.json())
        except Exception as e:
            print(e)        
                

def load_workflows(kibana_server, kibana_auth, es_host, remote_host = None):

    directory_path = "workflows"
    target_extension = ".yaml"

    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)

                if '_archive' in full_path:
                    continue

                with open(full_path, 'r') as fileo:
                    #content = file.read()  # Read the entire content of the file
                    #parsed = yaml.load(content)
                    #content = file.read()
                    #print(content)
                    #print(full_path)
                    
                    yaml = MyYAML()

                    parsed = yaml.load(fileo)
                    
                    delete_existing_workflow(kibana_server, kibana_auth, es_host, parsed['name'])
                    print(f"loading {parsed['name']}")

                    if 'consts' in parsed:
                        if 'remote_host' in parsed['consts'] and remote_host is not None:
                            parsed['consts']['remote_host'] = remote_host

                    # parsed['consts']['kbn_host'] = kibana_server
                    # parsed['consts']['kbn_auth'] = kibana_auth
                    # parsed['consts']['es_host'] = es_host    
                    # parsed['consts']['ai_connector'] = ai_connector   
                    # parsed['consts']['ai_proxy'] = ai_proxy  
                    # parsed['consts']['snow_host'] = snow_host   
                    # parsed['consts']['snow_auth'] = snow_auth              
                    
                    yaml = MyYAML()
                    yaml.width = float("inf") # Set the width attribute of the YAML instance

                    #yaml.dump(parsed)
                    out = yaml.dump(parsed)
                    body = {
                        "workflows": [
                            {
                                "yaml": out
                            }
                        ]
                    }
                    #print(out)
                    

                    resp = requests.post(f"{kibana_server}/api/workflows",
                                        json=body,
                                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                    print(resp.json())


#

def delete_synthetic(kibana_server, kibana_auth, synthetic_name):
    print("search sythetics...")
    resp = requests.get(f"{kibana_server}/api/synthetics/monitors",
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    
    #print(resp.json())
    for synthetic in resp.json()['monitors']:
        try:
            if synthetic['name'] == synthetic_name:
                print(f"deleting {synthetic['name']}")

                resp = requests.delete(f"{kibana_server}/api/synthetics/monitors/{synthetic['id']}",
                                    headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                #print(resp.json())
        except Exception as e:
            print(e)   
    
def load_synthetics(kibana_server, kibana_auth, namespaces, iis_endpoint):

    directory_path = "synthetics"
    target_extension = ".json"
    
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)

                with open(full_path, 'r') as fileo:
                    content = fileo.read()
                    if content.find('$NAMESPACE') != -1:
                        print("multi-namespace")
                        port=9000
                        for namespace in namespaces:
                            with open(full_path, 'r') as fileo:
                                synthetic = json.load(fileo)
                                print(f'namespace={namespace}')
                                synthetic['name'] = synthetic['name'].replace('$NAMESPACE', namespace)
                                port = port+1
                                if 'inline_script' in synthetic:
                                    synthetic['inline_script'] = synthetic['inline_script'].replace('$NAMESPACE', namespace)
                                    synthetic['inline_script'] = synthetic['inline_script'].replace('$PORT', str(port))

                                delete_synthetic(kibana_server, kibana_auth, synthetic['name'])

                                #print(synthetic)
                                resp = requests.post(f"{kibana_server}/api/synthetics/monitors",
                                                    json=synthetic,
                                                    headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                                print(resp.json())
                    else:
                        print("one namespace")
                        with open(full_path, 'r') as fileo:
                            synthetic = json.load(fileo)

                            if 'inline_script' in synthetic:
                                if '$IIS_ENDPOINT' in synthetic['inline_script']:
                                    if iis_endpoint is None:
                                        print("iis_endpoint is None")
                                        continue
                                    print(f"iis_endpoint is {iis_endpoint}")
                                    synthetic['inline_script'] = synthetic['inline_script'].replace('$IIS_ENDPOINT', iis_endpoint)
   
                            delete_synthetic(kibana_server, kibana_auth, synthetic['name'])

                            resp = requests.post(f"{kibana_server}/api/synthetics/monitors",
                                                json=synthetic,
                                                headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                            print(resp.json())            
 


def load_dataviews(kibana_server, kibana_auth):

    directory_path = "data_views"
    target_extension = ".json"

    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:

                    dataview = json.load(fileo)
                    #print(alias)
                    resp = requests.post(f"{kibana_server}/api/data_views/data_view",
                                        json=dataview,
                                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                    print(resp.json())     


def load_aliases(es_host, kibana_auth):

    directory_path = "aliases"
    target_extension = ".json"
    
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:

                    alias = json.load(fileo)
                    #print(alias)
                    resp = requests.post(f"{es_host}/_aliases",
                                        json=alias,
                                        headers={f"Authorization": kibana_auth, "Content-Type": "application/json"})
                    print(resp.json())     

def load_objects(kibana_server, kibana_auth):

    directory_path = "objects"
    target_extension = ".ndjson"
    
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'rb') as f:
                    # The 'files' parameter handles multipart/form-data encoding
                    # The tuple format is ('filename', file_object)
                    files = {'file': (full_path, f)}

                    resp = requests.post(f"{kibana_server}/api/saved_objects/_import?overwrite=true",
                                        files=files,
                                        headers={f"Authorization": kibana_auth, "kbn-xsrf": "true"})
                    print(resp.json())  

def load_ml(es_host, kibana_auth):

    directory_path = "ml"
    target_extension = ".json"
    
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:

                    ml = json.load(fileo)
                    #print(rule)
                    resp = requests.put(f"{es_host}/_ml/anomaly_detectors/{ml['job_id']}",
                                        json=ml,
                                        headers={f"Authorization": kibana_auth, "Content-Type": "application/json"})
                    print(resp.json())     

                    resp = requests.post(f"{es_host}/_ml/anomaly_detectors/{ml['job_id']}/_open",
                                        headers={f"Authorization": kibana_auth, "Content-Type": "application/json"})
                    print(resp.json())     

                    resp = requests.post(f"{es_host}/_ml/datafeeds/{ml['datafeed_config']['datafeed_id']}/_start",
                                        headers={f"Authorization": kibana_auth, "Content-Type": "application/json"})
                    print(resp.json())   

def enable_rules(kibana_server, kibana_auth, es_host):

    directory_path = "rules_enable"

    print("ENABLE RULES")
    
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            print(file)

            resp = requests.post(f"{kibana_server}/api/alerting/rule/{file}/_enable",
                                headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
            print(resp)    


def load_rules(kibana_server, kibana_auth, es_host, connect_alerts=False):

    enable_rules(kibana_server, kibana_auth, es_host)

    resp = requests.get(f"{kibana_server}/api/workflows?size=50&page=1",
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    print(resp.json())
    
    alert_queue_id = None
    for workflow in resp.json()['results']:
        if workflow['name'] == 'alert_queue':
            alert_queue_id = workflow['id']

    directory_path = "rules"
    target_extension = ".json"

    print("LOAD RULES")
    
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:
                    print("LOADING RULE")

                    #content = file.read()
                    rule = json.load(fileo)
                    if connect_alerts:
                        rule['actions'][0]['params']['subActionParams']['workflowId'] = alert_queue_id
                    else:
                        del rule['actions']
                    #print(rule)
                    resp = requests.post(f"{kibana_server}/api/alerting/rule",
                                        json=rule,
                                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                    print(resp.json())     

def delete_existing_agent_tool(kibana_server, kibana_auth, tool_id):

    try:
        resp = requests.delete(f"{kibana_server}/api/agent_builder/tools/{tool_id}?force=true",
                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
        print(resp.json())
    except Exception as e:
        print(e)        
               

def load_agent_tools(kibana_server, kibana_auth):

    workflows_resp = requests.get(f"{kibana_server}/api/workflows?size=50&page=1",
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    #print(workflows_resp.json())

    directory_path = "tools"
    target_extension = ".json"
    
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)

                if '_archive' in full_path:
                    continue

                with open(full_path, 'r') as fileo:
                    #content = file.read()
                    tool = json.load(fileo)
                    del tool['readonly']

                    print(tool)
                    if 'x-add-to-agents' in tool:
                        #print(skill)
                        agents = tool['x-add-to-agents']
                        #print('here!!!')
                        del tool['x-add-to-agents']
                    else:
                        agents = []

                    print(f"loading tool {tool['id']}")

                    if tool['type'] == 'workflow':
                        for workflow in workflows_resp.json()['results']:
                            #print(workflow)
                            if workflow['name'] == tool['id']:
                                print("HERE!!!")
                                tool['configuration']['workflow_id'] = workflow['id']

                    delete_existing_agent_tool(kibana_server, kibana_auth, tool['id'])

                    #print(tool)
                    resp = requests.post(f"{kibana_server}/api/agent_builder/tools",
                                        json=tool,
                                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                    #print(resp.json())     

                    for agent in agents:

                        resp1 = requests.get(f"{kibana_server}/api/agent_builder/agents/{agent}",
                                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json"})
                        #print(resp1.json())
                        existing = resp1.json()

                        update_json = {
                            "configuration": {
                                "tools": [
                                    {"tool_ids": existing['configuration']['tools'][0]['tool_ids'] if 'tools' in existing['configuration'] and len(existing['configuration']['tools']) > 0 and 'tool_ids' in existing['configuration']['tools'][0] else []}
                                ]
                            }
                        }

                        update_json['configuration']['tools'][0]['tool_ids'].append(tool['id'])

                        #print(update_json)
                        #print('here')

                        resp = requests.put(f"{kibana_server}/api/agent_builder/agents/{agent}",
                                            json=update_json,
                                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json"})
                        print("updated tools")
                        print(resp.json())



def delete_existing_slo(kibana_server, kibana_auth, slo_name):

    resp = requests.get(f"{kibana_server}/api/observability/slos",
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    #print(resp.json())  

    for slo in resp.json()['results']:
        if slo['name'] == slo_name:
            try:
                print(slo['id'])
                resp = requests.delete(f"{kibana_server}/api/observability/slos/{slo['id']}",
                                    headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "x-elastic-internal-origin": "Kibana"})
                #print(resp.json())
                print("deleted")
            except Exception as e:
                print(e)  

def load_slos(kibana_server, kibana_auth, services):

    directory_path = "slos"
    target_extension = ".json"

    for service in services:
        
        for root, dirs, files in os.walk(directory_path):
            for file in files:
                if file.endswith(target_extension):
                    full_path = os.path.join(root, file)

                    if '_archive' in full_path:
                        continue

                    with open(full_path, 'r') as fileo:
                        #content = file.read()
                        slo = json.load(fileo)


                        slo['name'] = slo['name'].replace('$SERVICE_NAME', service)
                        slo['indicator']['params']['service'] = slo['indicator']['params']['service'].replace('$SERVICE_NAME', service)      

                        print(f"loading slo {slo['name']}")

                        delete_existing_slo(kibana_server, kibana_auth, slo['name'])

                        #print(tool)
                        resp = requests.post(f"{kibana_server}/api/observability/slos",
                                            json=slo,
                                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                        print(resp.json())  


def backup_agent_skills(kibana_server, kibana_auth):
    
    resp = requests.get(f"{kibana_server}/api/agent_builder/skills", 
                         json={},
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    #print(resp.json())
    
    for skill in resp.json()['results']:
        #print(tool)
        #if 'rca' in tool['tags']:

        resp2 = requests.get(f"{kibana_server}/api/agent_builder/skills/{skill['id']}", 
                        json={},
                    headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})

            
        with open(f"backup/skills/{skill['id']}.json", "w") as json_file:
            json.dump(resp2.json(), json_file)


def backup_agent_tools(kibana_server, kibana_auth):
    
    resp = requests.get(f"{kibana_server}/api/agent_builder/tools", 
                         json={},
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    #print(resp.json())
    
    for tool in resp.json()['results']:
        #print(tool)
        #if 'rca' in tool['tags']:
            
        with open(f"backup/tools/{tool['id']}.json", "w") as json_file:
            json.dump(tool, json_file)

def delete_existing_agent(kibana_server, kibana_auth, agent_id):

    try:
        resp = requests.delete(f"{kibana_server}/api/agent_builder/agents/{agent_id}",
                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
        print(resp.json())
    except Exception as e:
        print(e)        

def load_dashboards(kibana_server, kibana_auth):

    directory_path = "dashboards"
    target_extension = ".json"

    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:

                    newdb = json.load(fileo)

                    print(newdb['title'])
                    id = hashlib.sha256(newdb['title'].encode('utf-8')).hexdigest()
                    resp = requests.put(f"{kibana_server}/api/dashboards/{id}",
                                        json=newdb,
                                        headers={f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                    print(resp.json())
                    print(f"new")

def delete_existing_skill(kibana_server, kibana_auth, skill_id):

    try:
        resp = requests.delete(f"{kibana_server}/api/agent_builder/skills/{skill_id}",
                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
        print(resp.json())
    except Exception as e:
        print(e)  

def load_skills(kibana_server, kibana_auth):
    
    directory_path = "skills"
    target_extension = ".json"
    
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:
                    #content = file.read()
                    skill = json.load(fileo)
                    del skill['readonly']
                    del skill['experimental']

                    print(skill)
                    if 'x-add-to-agents' in skill:
                        #print(skill)
                        agents = skill['x-add-to-agents']
                        #print('here!!!')
                        del skill['x-add-to-agents']
                    else:
                        agents = []

                    
                    
                    delete_existing_skill(kibana_server, kibana_auth, skill['id'])

                    #print(agent)
                    resp = requests.post(f"{kibana_server}/api/agent_builder/skills",
                                        json=skill,
                                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json"})
                    print(resp.json())

                    for agent in agents:

                        resp1 = requests.get(f"{kibana_server}/api/agent_builder/agents/{agent}",
                                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json"})
                        #print(resp1.json())
                        existing = resp1.json()
                        print(existing)

                        update_json = {
                            "configuration": {
                                "skill_ids": existing['configuration']['skill_ids'] if 'skill_ids' in existing['configuration'] else []
                            }
                        }

                        update_json['configuration']['skill_ids'].append(skill['id'])

                        #print(update_json)
                        #print('here')

                        resp = requests.put(f"{kibana_server}/api/agent_builder/agents/{agent}",
                                            json=update_json,
                                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json"})
                        print("updated skills")
                        print(resp.json())

 

def load_agents(kibana_server, kibana_auth):
    
    directory_path = "agents"
    target_extension = ".json"
    
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:
                    #content = file.read()
                    agent = json.load(fileo)

                    if 'x-update' in agent and agent['x-update'] is True:

                        print("x-update")

                        resp1 = requests.get(f"{kibana_server}/api/agent_builder/agents/{agent['id']}",
                                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json"})
                        #print(resp1.json())
                        existing = resp1.json()
                        print(existing)

                        existing['configuration'] = {
                                "skill_ids": existing['configuration']['skill_ids'] if 'skill_ids' in existing['configuration'] else [],
                                "tools": [
                                    {"tool_ids": existing['configuration']['tools'][0]['tool_ids'] if 'tools' in existing['configuration'] and len(existing['configuration']['tools']) > 0 and 'tool_ids' in existing['configuration']['tools'][0] else []}
                                ]
                            }
                        

                        existing['configuration']['skill_ids'] = list(set(agent['configuration']['skill_ids'] + existing['configuration']['skill_ids']))
                        existing['configuration']['tools'][0]['tool_ids'] = list(set(agent['configuration']['tools'][0]['tool_ids'] + existing['configuration']['tools'][0]['tool_ids']))

                        if 'readonly' in existing:
                            del existing['readonly']
                        if 'type' in existing:
                            del existing['type']
                        if 'id' in existing:
                            del existing['id']
                        if 'access_control' in existing:
                            del existing['access_control']
                        if 'permissions' in existing:
                            del existing['permissions']
                        if 'created_by' in existing:
                            del existing['created_by']

                        print(existing)
                        #print('here')

                        resp = requests.put(f"{kibana_server}/api/agent_builder/agents/{agent['id']}",
                                            json=existing,
                                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json"})
                        print("updated agent")
                        print(resp.json())

                    else:
                        del agent['readonly']
                        del agent['type']
                        if 'created_by' in agent:
                            del agent['created_by']

                        delete_existing_agent(kibana_server, kibana_auth, agent['id'])

                        #print(agent)
                        resp = requests.post(f"{kibana_server}/api/agent_builder/agents",
                                            json=agent,
                                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                        print(resp.json())     
 

def backup_agents(kibana_server, kibana_auth):
    
    resp = requests.get(f"{kibana_server}/api/agent_builder/agents", 
                         json={},
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    print(resp.json())
    
    for agent in resp.json()['results']:
        #print(agent)
        #if 'labels' in agent and 'rca' in agent['labels']:
            
        with open(f"backup/agents/{agent['id']}.json", "w") as json_file:
            json.dump(agent, json_file)

def run_workflow(kibana_server, kibana_auth, workflow_name):

    resp = requests.get(f"{kibana_server}/api/workflows?size=50&page=1",
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    #print(resp.json())
    
    for workflow in resp.json()['results']:
        if workflow['name'] == workflow_name:
            resp2 = requests.post(f"{kibana_server}/api/workflows/workflow/{workflow['id']}/run",
                            json={"inputs":{}},
                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
            print(resp2.json())
            break


@click.command()
@click.option('--kibana_host', default="", help='address of kibana server')
@click.option('--iis_endpoint', default=None, help='address of iis server')
@click.option('--es_host', default="", help='address of elasticsearch server')
@click.option('--es_apikey', default="", help='apikey for auth')
@click.option('--es_authbasic', default="", help='basic for auth')
@click.option('--connect_alerts', default=False, help='connect alerts to workflow')
@click.option('--remote_host', default=None, help='remote host url')
@click.option('--namespaces', default="trading-na,trading-emea", help='namespaces')
@click.option('--services', default="trader,router,recorder-java,recorder-go", help='services')
@click.argument('action')
def main(kibana_host, es_host, es_apikey, es_authbasic, connect_alerts, action, remote_host, namespaces, services, iis_endpoint):
    

    namespaces_split = namespaces.split(',')
    print(namespaces_split)

    services_split = services.split(',')
    print(services_split)


    config = dotenv_values()
    for key, value in config.items():
        print(f"{key}: {value}")

    if kibana_host == "":
        kibana_host = config['elasticsearch_kibana_endpoint']
    if es_host == "":
        es_host = config['elasticsearch_es_endpoint']
    if es_apikey == "" and es_authbasic == "":
        es_apikey = config['elasticsearch_api_key']

    if es_authbasic != "":
        auth = f"Basic {es_authbasic}"
    else:
        auth = f"ApiKey {es_apikey}"

    if action == 'load_workflows':
        print("LOADING WORKFLOWS")
        load_workflows(kibana_host, auth, es_host)
        #run_workflow(kibana_host, auth, 'setup')
        #run_workflow(kibana_host, auth, 'topology')
    elif action == 'load_alerts':
        load_rules(kibana_host, auth, es_host, connect_alerts)
    elif action == 'backup_workflows':
        backup_workflows(kibana_host, auth)
    elif action == 'load_knowledge':
        #load_knowledge(kibana_host, auth)
        load_new_knowledge(es_host, auth)
        print('done')
    elif action == 'load_synthetics':
        load_synthetics(kibana_host, auth, namespaces_split, iis_endpoint)
        print('done')
    elif action == 'backup_tools':
        backup_agent_tools(kibana_host, auth)
        print('done')
    elif action == 'backup_agents':
        backup_agents(kibana_host, auth)
        print('done')
    elif action == 'load_agents':
        load_agents(kibana_host, auth)
        print('done')
    elif action == 'load_tools':
        load_agent_tools(kibana_host, auth)
        print('done')
    elif action == 'load_aliases':
        load_aliases(es_host, auth)
        load_dataviews(kibana_host, auth)
        print('done')
    elif action == 'load_ml':
        load_ml(es_host, auth)
        print('done')
    elif action == 'load_skills':
        load_skills(kibana_host, auth)
        print('done')
    elif action == 'load_slos':
        load_slos(kibana_host, auth, services_split)
        print('done')
    elif action == 'load_objects':
        load_objects(kibana_host, auth)
        print('done')
    elif action == 'load_dashboards':
        load_dashboards(kibana_host, auth)
        print('done')

    elif action == 'load':
        load_workflows(kibana_host, auth, es_host, remote_host)
        #load_new_knowledge(es_host, auth)
        load_agent_tools(kibana_host, auth)
        load_skills(kibana_host, auth)
        load_agents(kibana_host, auth)

        run_workflow(kibana_host, auth, 'setup')
        load_synthetics(kibana_host, auth, namespaces_split, iis_endpoint)
        load_aliases(es_host, auth)
        load_dataviews(kibana_host, auth)
        load_ml(es_host, auth)
        load_rules(kibana_host, auth, es_host, connect_alerts)

        load_objects(kibana_host, auth)
        load_dashboards(kibana_host, auth)

        load_slos(kibana_host, auth, services_split)
        print('done')

    elif action == 'backup':
        backup_agents(kibana_host, auth)
        backup_agent_tools(kibana_host, auth)
        backup_workflows(kibana_host, auth)
        backup_agent_skills(kibana_host, auth)
        print('done')
    elif action == 'run_setup':
        run_workflow(kibana_host, auth, 'setup')

if __name__ == '__main__':
    main()
