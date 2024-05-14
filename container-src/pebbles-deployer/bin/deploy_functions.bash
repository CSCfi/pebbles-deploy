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
        - name: PB_APP_VERSION
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
    build-image-pebbles
    build-image-logstash
    build-image-filebeat
    build-image-pebbles-backup
    build-image-pebbles-frontend
    build-image-pebbles-admin-frontend

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

# create database structure
pb-create-database() {
  oc rsh deployment/api flask db upgrade
}

# load data from yaml files in environment definition to database, decrypt sops if needed
# usage e.g.: pb-load-data file1.yaml file2.sops.yaml file3.yaml
pb-load-data() {
  for file in "$@"; do
    if [ -f "$ENV_BASE_DIR/$file" ]; then
      if [[ "$file" == *\.sops\.* ]]; then
        echo
        echo "Loading encrypted file $ENV_BASE_DIR/$file to database"
        echo
        sops --decrypt --age "$SOPS_AGE_RECIPIENTS" "$ENV_BASE_DIR/$file" | \
        yq -r '.initial_data' | \
        oc rsh deployment/api python manage.py load_data /dev/stdin
      else
        echo
        echo "Loading file $ENV_BASE_DIR/$file to database"
        echo
        oc rsh deployment/api python manage.py load_data /dev/stdin < "$ENV_BASE_DIR/$file"
      fi
    else
      echo
      echo "File $ENV_BASE_DIR/$file not found"
      echo
    fi
  done
}

# reset worker password to default secret
pb-reset-worker-password() {
  oc rsh deployment/api python manage.py reset_worker_password
}

# initializes system with initial data files passed as arguments
# the file including initial users needs to be the first argument, e.g.:
# pb-initialize-database devel-users.sops.yaml initial-data.yaml
pb-initialize-database() {
  wait-for-api-readiness
  pb-create-database
  pb-load-data "$@"
  pb-reset-worker-password
}

# initializes system with initial data from inventory
initialize-pebbles-with-initial-data() {
    wait-for-api-readiness
    # create database structure
    oc rsh deployment/api flask db upgrade
    # load initial data
    initial_data_file=${1:-"/dev/shm/$ENV_NAME/initial_data.yaml"}
    oc rsh deployment/api python manage.py load_data /dev/stdin < $initial_data_file
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

# Merge kubeconfig of the current cluster to the cluster kubeconfig of an environment. Run the script in a DC
# for the cluster. Takes path to the SOPS-encrypted cluster kubeconfig file of the environment as the only argument
# Usage example:
# pb-merge-kubeconfig-to-secret ~/pebbles-env-1/secrets-cluster-kubeconfig.sops.yaml
pb-merge-kubeconfig-to-secret() {
  secret_kubeconfig_path=$1

  read -s -p "age secret key for target environment: " AGE_SECRET
  export SOPS_AGE_KEY=$AGE_SECRET
  echo
  age_public_key=$(echo "$SOPS_AGE_KEY" | age-keygen -y)

  echo
  echo "using recipient $age_public_key to encrypt the final file"
  echo

  # change 'default' to cluster name in kubeconfig
  sed "s/: default$/: $ENV_NAME/g" ~/.kube/config > ~/.kube/config_sed

  # remove top level mapping of secret kubeconfig
  sops --age $age_public_key -d $secret_kubeconfig_path | yq -r '.clusterKubeconfig' > /dev/shm/cluster-kubeconfig.flat

  # merge cluster kubeconfig to environment kubeconfig
  KUBECONFIG=/dev/shm/cluster-kubeconfig.flat:~/.kube/config_sed kubectl config view --flatten > /dev/shm/cluster-kubeconfig.yml

  # add back top level mapping
  yq -y '{"clusterKubeconfig": .}' /dev/shm/cluster-kubeconfig.yml > /dev/shm/cluster-kubeconfig-final.yml

  # make kubeconfig into a multiline string
  sed -i 's/clusterKubeconfig:/& |/' /dev/shm/cluster-kubeconfig-final.yml

  # encrypt merged secret kubeconfig and replace the old cluster kubeconfig with the new one
  sops -e --age $age_public_key /dev/shm/cluster-kubeconfig-final.yml > $secret_kubeconfig_path

  echo "merged kubeconfig written to $secret_kubeconfig_path"

  # delete kubeconfig from /dev/shm/ and extra kubeconfig from ~/.kube/
  rm /dev/shm/cluster-kubeconfig-final.yml /dev/shm/cluster-kubeconfig.yml /dev/shm/cluster-kubeconfig.flat ~/.kube/config_sed

  unset SOPS_AGE_KEY
}
