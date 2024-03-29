# Function for recreating files on ramdisk from ansible-inventory.
# builds logstash in the current OpenShift namespace
build-image-from-container-src() {
    if [[ -z $1 ]]; then
        echo 'build-image-from-container-source() needs image name as an argument' > /dev/stderr
        return
    fi
    # pop the first argument and pass the rest later to oc build
    name=$1
    shift

    # create buildconfig and imagestream if missing
    oc get buildconfig ${name} || oc create -f ~/pebbles-deploy/openshift/${name}-bc.yaml
    oc get imagestream ${name} || oc create -f ~/pebbles-deploy/openshift/${name}-is.yaml

    # The buildconfig has contextDir set, so build from root dir.
    # Create an archive to exclude version control and ignored files from the build
    tmpfile=$(mktemp -u /tmp/src-XXXXXX.tar.gz)
    tar cfv $tmpfile --exclude-vcs-ignores --exclude-vcs -C ~/pebbles-deploy container-src
    oc start-build ${name} --from-archive $tmpfile "$@"
    rm -v $tmpfile
}

build-image-logstash() {
    build-image-from-container-src logstash "$@"
}

# builds filebeat in the current OpenShift namespace
build-image-filebeat() {
    build-image-from-container-src filebeat "$@"
}

# builds pebbles-deployer in the current OpenShift namespace
build-image-pebbles-deployer() {
    build-image-from-container-src pebbles-deployer "$@"
}

# builds pebbles-deployer in the current OpenShift namespace
build-image-pebbles-backup() {
    build-image-from-container-src pebbles-backup "$@"
}

build-image-from-project-src() {
    if [[ -z $1 ]]; then
        echo 'build-image-from-project-source() needs project name as an argument' > /dev/stderr
        return
    fi
    # pop the first argument and pass the rest later to oc build
    name=$1
    shift

    # create buildconfig and imagestream if missing
    oc get buildconfig ${name} || oc create -f ~/pebbles-deploy/openshift/${name}-bc.yaml
    oc get imagestream ${name} || oc create -f ~/pebbles-deploy/openshift/${name}-is.yaml

    # patch buildconfig to include application version (timestamp for a devel build)
    oc patch buildconfig ${name} --patch-file /dev/stdin <<EOF
spec:
  strategy:
    dockerStrategy:
      buildArgs:
        - name: APP_VERSION
          value: "$(date -Is)"
EOF
    # create a build for current source branch, only taking files under version control
    tmpfile=$(mktemp -u /tmp/src-${name}-XXXXXX.tar)
    tar cfv $tmpfile --exclude-vcs-ignores --exclude-vcs -C ~/${name} `git -C ~/${name} ls-files`
    oc start-build ${name} --from-archive $tmpfile "$@"
    rm -v $tmpfile
}

# builds pebbles in the current OpenShift namespace
build-image-pebbles() {
    build-image-from-project-src pebbles "$@"
}

# builds pebbles-frontend in the current OpenShift namespace
build-image-pebbles-frontend() {
    build-image-from-project-src pebbles-frontend "$@"
}

# builds pebbles-admin-frontend in the current OpenShift namespace
build-image-pebbles-admin-frontend() {
    build-image-from-project-src pebbles-admin-frontend "$@"
}

# builds all images from local sources
build-image-all() {
    build-image-pebbles --follow
    build-image-pebbles-frontend --follow
    build-image-pebbles-admin-frontend --follow
    build-image-logstash --follow
    build-image-filebeat --follow
    build-image-pebbles-backup --follow
}

# builds all images from local sources in parallel
build-image-all-parallel() {
    # trigger builds, starting from the heaviest to lightest
    build-image-pebbles-frontend
    build-image-pebbles-admin-frontend
    build-image-pebbles
    build-image-logstash
    build-image-filebeat
    build-image-pebbles-backup

    # wait for at least one of the builds to be running
    while ! oc get pods -l openshift.io/build.name | grep Running; do
      echo "Waiting for builds to start"
      sleep 2
    done

    # wait for all builds to have ended
    while oc get pods -l openshift.io/build.name | grep Running; do
      echo "Waiting for builds to end"
      sleep 10
    done
}

list-image-tags() {
    if [[ -z $1 ]]; then
        echo 'list-image-tags needs image name (like "pebbles") as an argument' > /dev/stderr
        return
    fi
    image_url="${PUBLIC_IMAGE_REPO_URL}/$1"
    skopeo list-tags $image_url | jq -r '.Tags[]' \
    | sort \
    | xargs --replace echo "$image_url:{}"
}

# blocks until API pod is ready
wait-for-api-readiness() {
    echo 'waiting for api to be available'
    oc wait --for=condition=Available --timeout=600s deployment/api
}

# blocks until worker-0 pod is ready
wait-for-worker-readiness() {
    echo 'waiting for worker pod readiness'
    oc wait --for=condition=Ready --timeout=600s pod -l name=worker
}

# initializes system with given admin password
initialize-pebbles() {
    if [[ -z $1 ]]; then
        echo 'initialize-pebbles needs admin password as an argument' > /dev/stderr
        return
    fi
    wait-for-api-readiness
    # create database structure and initialize system
    oc rsh deployment/api flask db upgrade
    oc rsh deployment/api python manage.py initialize_system -e admin@example.org -p $1
}

# initializes system with initial data from inventory
initialize-pebbles-with-initial-data() {
    wait-for-api-readiness
    # create database structure
    oc rsh deployment/api flask db upgrade
    # load initial data
    oc rsh deployment/api python manage.py load_data /dev/stdin < /dev/shm/$ENV_NAME/initial_data.yaml
    # reset worker password to default secret
    oc rsh deployment/api python manage.py reset_worker_password
}

# installs system using Helm
helm-install-pebbles() {
    (cd ~/pebbles-deploy && helm install pebbles helm_charts/pebbles -f /dev/shm/$ENV_NAME/values.yaml)
}

# upgrades deployment using Helm
helm-upgrade-pebbles() {
    if [[ "zzz$1" == 'zzz-r' ]]; then shift ; refresh-ramdisk; fi
    (cd ~/pebbles-deploy && helm upgrade pebbles helm_charts/pebbles -f /dev/shm/$ENV_NAME/values.yaml "$@")
}

# Builds, installs and initializes system. Uses local source directories and initial data from inventory
install-pebbles() {
    if [[ ! -f /dev/shm/$ENV_NAME/initial_data.yaml ]]; then
      echo "No initial data for this environment found. The manual steps are"
      echo
      echo " build-image-all && helm-install-pebbles && initialize-pebbles <admin password>"
      echo
      echo "Take a look at ~/deploy_functions.bash to see what is going on under the hood"
      return 1
    fi

    build-image-all-parallel

    helm status pebbles 2>&1 > /dev/null || helm-install-pebbles

    initialize-pebbles-with-initial-data
}

pebbles-tail-logs() {
  oc rsh deployment/logstash bash -c "tail -f data/opt/log/$1*"
}

pebbles-rsync-src-api() {
  oc rsync ~/pebbles/pebbles $(oc get pods -l name=api | grep Running | cut -f 1 -d " " | head):.
}

# Apply kustomized manifests to cluster. Supports plugins, e.g. ksops.
# Takes path to kustomize/ directory as the only argument, defaults to kustomize/ directory in environment root.
# Usage e.g.: pb-kustomize-apply ./kustomize/
pb-kustomize-apply() {
  kustomizedir=${1:-"$ENV_BASE_DIR"/kustomize/}
  kustomize build --enable-alpha-plugins --enable-exec $kustomizedir | oc apply -f -
}

# Delete kustomized manifests from cluster. Supports plugins, e.g. ksops.
# Takes path to kustomize/ directory as the only argument, defaults to kustomize/ directory in environment root.
# Usage e.g.: pb-kustomize-delete ./kustomize/
pb-kustomize-delete() {
  kustomizedir=${1:-"$ENV_BASE_DIR"/kustomize/}
  kustomize build --enable-alpha-plugins --enable-exec $kustomizedir | oc delete -f -
}

# Install/upgrade deployment using Helm. Uses chart and name specified in .env.yaml, values and secrets
# from environment base directory
pb-helm-upgrade() {
    # construct a list of values files
    values_files=$(ls $ENV_BASE_DIR/*values*.yaml)
    vf_options=''
    for vf in $values_files; do
        vf_options="$vf_options -f $vf"
    done

    # construct a list of secrets files
    secrets_files=$(ls $ENV_BASE_DIR/*secrets*.yaml)
    sf_options=''
    for sf in $secrets_files; do
        sf_options="$sf_options -f secrets://$sf"
    done

    # extract Helm installation name and chart
    helm_name=$(yq -r '.helmName' $ENV_BASE_DIR/.env.yaml)
    helm_chart=$(yq -r '.helmChart' $ENV_BASE_DIR/.env.yaml)

    # define Kustomize post renderer, if 'kustomize' subdir is present
    post_options=''
    if [[ -d $ENV_BASE_DIR/kustomize ]]; then
        post_options="--post-renderer $HOME/bin/kustomize-post-renderer.bash"
    fi

    echo "Running helm upgrade -i $helm_name $helm_chart $vf_options $sf_options $post_options \"$@\""
    helm upgrade -i $helm_name $helm_chart $vf_options $sf_options $post_options "$@"
}
