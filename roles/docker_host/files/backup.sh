export REV=$(cd ~/pebbles/ && git rev-parse HEAD)
export VERSION=dump_`date +%d-%m-%Y"_"%H_%M_%S`_$REV.sql
sudo docker exec -t db pg_dump --clean -d pebbles -U postgres | gzip -c > /var/lib/pb/backup/$VERSION.gz
sudo tmpwatch -m 90d /var/lib/pb/backup/
