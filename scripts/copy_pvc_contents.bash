#!/usr/bin/env bash

set -e

print_usage_and_exit()
{
    me=$(basename "$0")
    echo
    echo "Copy PVC contents to another PVC using rsync"
    echo
    echo "Usage: $me -s src_pvc_name -d dst_pvc_name [options]"
    echo "  where options are"
    echo "  -g size       destination pvc size. If omitted, no pvc is created."
    echo "  -c class      destination pvc storage class"
    echo "  -a accessMode destination pvc accessMode, default ReadWriteOnce"
    echo "  -h            print this help an exit"
    echo
    echo "Example:"
    echo "    $me -s logstash -d logstash-copy -g 2Gi -c glusterfs-storage -a ReadWriteMany"
    echo
    exit 1
}

# default access mode
dst_pvc_access_mode=ReadWriteOnce

# Process options
while getopts "s:d:g:c:a:h" opt; do
    case $opt in
        s)
            src_pvc_name=${OPTARG}
            ;;
        d)
            dst_pvc_name=${OPTARG}
            ;;
        g)
            dst_pvc_size=${OPTARG}
            ;;
        c)
            dst_pvc_storage_class=${OPTARG}
            ;;
        a)
            dst_pvc_access_mode=${OPTARG}
            ;;
        *)
            print_usage_and_exit
            ;;
    esac
done
shift "$((OPTIND-1))"


if [[ -z $src_pvc_name || -z $dst_pvc_name ]]; then
  print_usage_and_exit
fi

echo "Cloning $src_pvc_name to $dst_pvc_name"


# create dest pvc
if [[ ! -z $dst_pvc_size ]]; then
    echo "   creating dst pvc $dst_pvc_name, size $dst_pvc_size, storage class $dst_pvc_storage_class"

    oc apply -f - <<EOD
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $dst_pvc_name
spec:
  storageClassName: $dst_pvc_storage_class
  accessModes:
    - $dst_pvc_access_mode
  resources:
    requests:
      storage: $dst_pvc_size
EOD
fi

# create copy job
echo "Creating copy job copy-$src_pvc_name-to-$dst_pvc_name"
oc apply -f - <<EOD
apiVersion: batch/v1
kind: Job
metadata:
  name: copy-$src_pvc_name-to-$dst_pvc_name
spec:
  template:
    spec:
      backoffLimit: 1
      restartPolicy: Never
      containers:
        - name: copier
          image: docker-registry.rahti.csc.fi/pebbles-public-images/pebbles-deployer:latest
          command:
            - /bin/bash
            - -c
            - |
              # bail out on any error
              set -e

              echo -n "copying starting "; date

              shopt -s dotglob
              rsync -avi --exclude lost+found /data/src/* /data/dst/

              echo -n "copying done "; date
              echo
              echo "comparing source and dest"
              diff -r /data/src /data/dst
              echo "done"

          volumeMounts:
            - name: src
              mountPath: /data/src
            - name: dst
              mountPath: /data/dst
      volumes:
        - name: src
          persistentVolumeClaim:
            claimName: $src_pvc_name
        - name: dst
          persistentVolumeClaim:
            claimName: $dst_pvc_name
EOD
