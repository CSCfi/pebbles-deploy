# Backs up into a gzipped postgresql dump
# dump name contains creation timestamp for orderin
# and current pebbles commit so restore can be done to the same point in time
# restores are expected to be manual
export REV=$(cd ~/pebbles/ && git rev-parse HEAD)
export VERSION=dump_`date +%d-%m-%Y"_"%H_%M_%S`_$REV.sql
mkdir -p {{ backup_dir }}
sudo docker exec -t db pg_dumpall -c -U postgres | gzip -c > {{backup_dir}}$VERSION.gz
