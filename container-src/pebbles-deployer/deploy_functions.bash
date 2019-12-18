build-image-logstash() {
    # create buildconfig and imagestream if missing
    oc get buildconfig logstash || oc create -f ~/pebbles-deploy/openshift/logstash-bc.yaml
    oc get imagestream logstash || oc create -f ~/pebbles-deploy/openshift/logstash-is.yaml

    # the buildconfig has contextDir set, so build from root dir
    oc start-build logstash --from-dir ~/pebbles-deploy --follow
}

build-image-filebeat() {
    # create buildconfig and imagestream if missing
    oc get buildconfig filebeat || oc create -f ~/pebbles-deploy/openshift/filebeat-bc.yaml
    oc get imagestream filebeat || oc create -f ~/pebbles-deploy/openshift/filebeat-is.yaml

    # the buildconfig has contextDir set, so build from root dir
    oc start-build filebeat --from-dir ~/pebbles-deploy --follow
}

build-image-pebbles() {
    # create buildconfig and imagestream if missing
    oc get buildconfig pebbles || oc create -f ~/pebbles-deploy/openshift/pebbles-bc.yaml
    oc get imagestream pebbles || oc create -f ~/pebbles-deploy/openshift/pebbles-is.yaml

    # create an image for current source branch
    oc start-build pebbles --from-dir ~/pebbles --follow
}

build-image-all() {
    build-image-pebbles
    build-image-logstash
    build-image-filebeat
}

install-pebbles() {
    if [[ -z $1 ]]; then
        echo 'install-pebbles needs admin password as an argument' > /dev/stderr
        return
    fi

    build-image-all

    helm status pebbles 2>&1 > /dev/null ||
     (cd ~/pebbles-deploy &&
      helm install pebbles helm_charts/pebbles -f /dev/shm/$ENV_NAME/values.yaml --set overrideSecret=1)

    while echo 'wait for api readiness'; do
        # we grep for readiness for deployments with a single container or with a logging sidecar container
        oc get pod -l name=api | egrep '1/1|2/2' | grep Running && break
        sleep 5
    done

    oc rsh deployment/api python manage.py initialize_system -e admin@example.org -p $1

    while echo 'wait for worker-0 readiness'; do
        # we grep for readiness for deployments with a single container or with a logging sidecar container
        oc get pod worker-0 | egrep '1/1|2/2' | grep Running && break
        sleep 5
    done
}
