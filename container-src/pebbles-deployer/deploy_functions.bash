# Function for recreating files on ramdisk from ansible-inventory.
# builds logstash in the current OpenShift namespace
build-image-logstash() {
    # create buildconfig and imagestream if missing
    oc get buildconfig logstash || oc create -f ~/pebbles-deploy/openshift/logstash-bc.yaml
    oc get imagestream logstash || oc create -f ~/pebbles-deploy/openshift/logstash-is.yaml

    # the buildconfig has contextDir set, so build from root dir
    oc start-build logstash --from-dir ~/pebbles-deploy --follow
}

# builds filebeat in the current OpenShift namespace
build-image-filebeat() {
    # create buildconfig and imagestream if missing
    oc get buildconfig filebeat || oc create -f ~/pebbles-deploy/openshift/filebeat-bc.yaml
    oc get imagestream filebeat || oc create -f ~/pebbles-deploy/openshift/filebeat-is.yaml

    # the buildconfig has contextDir set, so build from root dir
    oc start-build filebeat --from-dir ~/pebbles-deploy --follow
}

# builds pebbles-deployer in the current OpenShift namespace
build-image-pebbles-deployer() {
    # create buildconfig and imagestream if missing
    oc get buildconfig pebbles-deployer || oc create -f ~/pebbles-deploy/openshift/pebbles-deployer-bc.yaml
    oc get imagestream pebbles-deployer || oc create -f ~/pebbles-deploy/openshift/pebbles-deployer-is.yaml

    # the buildconfig has contextDir set, so build from root dir
    oc start-build pebbles-deployer --from-dir ~/pebbles-deploy --follow
}

# builds pebbles in the current OpenShift namespace
build-image-pebbles() {
    # create buildconfig and imagestream if missing
    oc get buildconfig pebbles || oc create -f ~/pebbles-deploy/openshift/pebbles-bc.yaml
    oc get imagestream pebbles || oc create -f ~/pebbles-deploy/openshift/pebbles-is.yaml

    # create an image for current source branch
    oc start-build pebbles --from-dir ~/pebbles --follow
}

# builds pebbles-frontend in the current OpenShift namespace
build-image-pebbles-frontend() {
    # create buildconfig and imagestream if missing
    oc get buildconfig pebbles-frontend || oc create -f ~/pebbles-deploy/openshift/pebbles-frontend-bc.yaml
    oc get imagestream pebbles-frontend || oc create -f ~/pebbles-deploy/openshift/pebbles-frontend-is.yaml

    # create an image for current source branch, copying old AngularJS files in as well
    # we don't want to upload the redundant node_modules/ (about 700MB) and dist/
    rsync -avi --exclude=node_modules --exclude=dist --delete ~/pebbles-frontend/* /tmp/pebbles-frontend

    oc start-build pebbles-frontend --from-dir /tmp/pebbles-frontend --follow
}

# builds all images from local sources
build-image-all() {
    build-image-pebbles
    build-image-pebbles-frontend
    build-image-logstash
    build-image-filebeat
    build-image-pebbles-deployer
}

# blocks until API pod is ready
wait-for-api-readiness() {
    while echo 'wait for api readiness'; do
        # we grep for readiness for deployments with a single container or with a logging sidecar container
        oc get pod -l name=api | egrep '1/1|2/2' | grep Running && break
        sleep 5
    done
}

# blocks until worker-0 pod is ready
wait-for-worker-readiness() {
    while echo 'wait for worker-0 readiness'; do
        # we grep for readiness for deployments with a single container or with a logging sidecar container
        oc get pod worker-0 | egrep '1/1|2/2' | grep Running && break
        sleep 5
    done
}

# initializes system with given admin password
initialize-pebbles() {
    if [[ -z $1 ]]; then
        echo 'initialize-pebbles needs admin password as an argument' > /dev/stderr
        return
    fi
    wait-for-api-readiness
    oc rsh deployment/api python manage.py initialize_system -e admin@example.org -p $1
}

# initializes system with initial data from inventory
initialize-pebbles-with-initial-data() {
    wait-for-api-readiness
    # create database structure
    oc rsh deployment/api python manage.py create_database
    # load initial data
    oc rsh deployment/api python manage.py load_test_data /dev/stdin < /dev/shm/$ENV_NAME/initial_data.yaml
    # reset worker password to default secret
    oc rsh deployment/api python manage.py reset_worker_password
}

# installs system using Helm
helm-install-pebbles() {
   (cd ~/pebbles-deploy && helm install pebbles helm_charts/pebbles -f /dev/shm/$ENV_NAME/values.yaml --set overrideSecret=1)
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

    build-image-all

    helm status pebbles 2>&1 > /dev/null || helm-install-pebbles

    initialize-pebbles-with-initial-data
}
