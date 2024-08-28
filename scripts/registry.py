#!/usr/bin/env python

from pydoc import resolve
from urllib import response
import os
import requests
import argparse
import urllib3
from requests.auth import HTTPBasicAuth
import json
import logging
import sys
import subprocess
import re
from datetime import datetime
from requests.packages import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

auth = None

PWD = os.getcwd()
LOG_FILE = f'log_{datetime.today()}.log'

# HTTPBasicAuth('<USERNAME>', '<PASSWORD>')

class DockerREST:
    def __init__(self, base_url, user, password):
        self.base_url = base_url
        self.session = requests.Session()
        if user is not None:
            self.session.auth = (user, password)
        self.session.headers.update(
            {
                "Content-type": "application/json",
                "Accept": "application/vnd.docker.distribution.manifest.v2+json"
            }
        )

    def request(self, endpoint, method='GET'):
        logging.debug("request: endpoint=%s method=%s", endpoint, method)
        response = self.session.request(
            method=method,
            url=self.base_url + endpoint,
            verify=False
        )
        logging.debug("request: response.status_code=%d response.headers=%s", response.status_code, response.headers)
        if len(response.content) > 0:
            logging.debug("request: response content: %s", json.dumps(response.json(), indent=4))
        return response


class Kubectl:
    def __init__(self, kubectl_path, kubeconfig_path, namespace):
        self.kubectl_path = kubectl_path
        self.kubeconfig_path = kubeconfig_path
        self.namespace = namespace

    def get_registry_pod(self):
        printout = self.exec(["get", "pods", "-l" "app=eric-lcm-container-registry", "--no-headers=true"])
        if len(printout) == 0:
            logging.error("Cannot locate registry pod, empty printout")
            sys.exit(1)
        lines = printout.splitlines()
        if len(lines) != 1:
            logging.error("Cannot locate registry pod, unexpected number of lines")
            sys.exit(1)
        parts = re.split("\s+", lines[0])
        logging.debug("get_registry_pod: parts=%s", parts)
        self.pod = parts[0]
        logging.debug("get_registry_pod: pod=%s", self.pod)

    def exec_in_registry(self, cmd):
        return self.exec(['exec', '-it', self.pod, '-c', 'registry', '--'] + cmd)

    def exec(self, cmd):
        base_args = [
            self.kubectl_path,
            '--namespace={0}'.format(self.namespace),
            '--kubeconfig={0}'.format(self.kubeconfig_path),
        ]
        full_args = base_args + cmd
        logging.info(" ".join(full_args))
        kubectl_exec = subprocess.run(full_args, stdout=subprocess.PIPE, universal_newlines=True)
        logging.info(kubectl_exec.stdout)
        logging.debug("exec result=%d", kubectl_exec.returncode)
        if kubectl_exec.returncode != 0:
            logging.error("kubectl command failed return code=%d", kubectl_exec.returncode)
            sys.exit(1)
        return kubectl_exec.stdout


def check_tag(docker, name, tag, problems):
    logging.info(" tag=%s", tag)
    manifest_response = docker.request("/v2/{0}/manifests/{1}".format(name, tag))
    if not manifest_response.ok:
        problem_type = 'manifest'
        error_msg = ''
        if 'application/json' in manifest_response.headers.get('Content-Type'):
            error_msg = manifest_response.json()['errors'][0]['message']
            if 'but accept header does not support' in error_msg:
                problem_type = 'manifest_format'
        logging.warning("  manifest request failed %d %s", manifest_response.status_code, error_msg)
        problems.append({'type': problem_type, 'repository': name, 'tag': tag})
        return

    manifest = manifest_response.json()
    layers_okay = True
    logging.debug("check_tag: manifest=%s", manifest)
    logging.info("  #layers=%d", len(manifest['layers']))
    for layer in manifest['layers']:
        layer_digest = layer['digest']
        logging.debug("  layer digest=%s", layer_digest)
        response = docker.request(
            "/v2/{0}/blobs/{1}".format(name, layer_digest),
            'HEAD'
        )
        if not response.ok:
            logging.error("%s:%s invalid layer %s", name, tag, layer_digest)
            layers_okay = False

    if not layers_okay:
        problems.append({'type': 'layer', 'repository': name, 'tag': tag})


def check_repository(docker, repository, problems):
    logging.info("repository name=%s", repository)
    response = docker.request("/v2/{0}/tags/list".format(repository))
    if not response.ok:
        logging.error("tags not found for %s", repository)
        problems.append({'type': 'notfound', 'repository': repository})
        return

    tags = response.json()['tags']
    if tags is None:
        logging.warning("null tags for %s", repository)
        problems.append({'type': 'nulltags', 'repository': repository})
        return

    for tag in tags:
        check_tag(docker, repository, tag, problems)


def get_with_pagination(docker, request, key):
    results = []
    while request is not None:
        response = docker.request(request)
        if not response.ok:
            logging.error("Request failed %s : %d", request, response.status_code)
            return None
        results.extend(response.json()[key])
        if 'Link' in response.headers:
            request = re.search("^<(\S+)>", response.headers['Link']).group(1)
        else:
            request = None
    return results


def check(docker, fix, kubectl):
    repositories = get_with_pagination(docker, '/v2/_catalog', 'repositories')
    if repositories is None:
        return False
    logging.info("#repositories: %d", len(repositories))

    problems = []
    for repository in repositories:
        check_repository(docker, repository, problems)

    if len(problems) > 0:
        logging.warning("Problems detected: %d", len(problems))
        for problem in problems:
            logging.warning(" %s", problem)
            if fix:
                if problem['type'] == 'nulltags' or problem['type'] == 'notfound':
                    from_dir = "/var/lib/registry/docker/registry/v2/repositories/{0}".format(problem['repository'])
                    # The repository might have / in it, for the mv to work, we need to
                    # replace that with _
                    to_dir = "/var/lib/registry/{0}.invalid.{1}".format(
                        problem['repository'].replace("/", "_"),
                        datetime.now().strftime("%Y%m%d%H%M%S")
                    )
                    logging.warning("  Check folder %s", from_dir)
                    is_path_exist = kubectl.exec_in_registry(['/usr/bin/sh',
                                                              '-c',
                                                              'if /usr/bin/test -d {0}; then echo exist; fi'.format(
                                                                  from_dir)])
                    if is_path_exist:
                        logging.warning("  Moving %s to %s", from_dir, to_dir)
                        kubectl.exec_in_registry([
                            "/usr/bin/mv",
                            from_dir,
                            to_dir
                        ])
                    else:
                        logging.warning("  The folder %s does not exist.", from_dir)
                elif problem['type'] == 'layer' or problem['type'] == 'manifest':
                    image = "{0}:{1}".format(problem['repository'], problem['tag'])
                    logging.warning("  Removing image tag %s", image)
                    rmtag(docker, image)
                else:
                    logging.warning("  No fix implemented")

        return False

    return True


def rmtag(docker, image):
    (name, tag) = image.split(":")

    response = docker.request(
        "/v2/{0}/manifests/{1}".format(name, tag),
        'HEAD'
    )
    if not response.ok or 'Docker-Content-Digest' not in response.headers:
        logging.error("Failed to lookup %s", image)
        return

    tag_digest = response.headers['Docker-Content-Digest']

    response = docker.request(
        "/v2/{0}/manifests/{1}".format(name, tag_digest),
        'DELETE',
    )
    if not response.ok:
        print(response.status_code)
        print(json.dumps(response.json(), indent=4))


parser = argparse.ArgumentParser(description='Consistency Check for Docker Registry')
parser.add_argument('--url', help='Registry URL', required=True)
parser.add_argument('--user', help='user')
parser.add_argument('--password', help='password')
parser.add_argument('--action', help='Action to perform', choices=['check', 'rmtag'], required=True)
parser.add_argument('--image', help='Image')
parser.add_argument('--fix', help='Fix issues found', action="store_true")
parser.add_argument('--kubectl', help='Path to kubectl binary')
parser.add_argument('--kubeconfig', help='Path to kube config file')
parser.add_argument('--namespace', help='Namespace of registry pod')

parser.add_argument('--debug', help='debug logging', action="store_true")
parser.add_argument('--file', help='Redirect output to file', action="store_true")
args = parser.parse_args()

logging_level = logging.INFO
if args.debug:
    logging_level = logging.DEBUG

if args.file:
    logging.basicConfig(filename=LOG_FILE, filemode="a",
                        level=logging_level, format="[%(asctime)s] [%(levelname)s]: %(message)s")
else:
    logging.basicConfig(level=logging_level)

docker = DockerREST(args.url, args.user, args.password)

kubectl = None
if args.fix:
    kubectl = Kubectl(args.kubectl, args.kubeconfig, args.namespace)
    kubectl.get_registry_pod()

if args.action == 'check':
    okay = check(docker, args.fix, kubectl)
    if okay:
        sys.exit(0)
    else:
        sys.exit(1)
elif args.action == 'rmtag':
    rmtag(docker, args.image)
