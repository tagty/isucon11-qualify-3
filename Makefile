deploy:
	ssh isu11q-1 " \
		cd /home/isucon; \
		git checkout .; \
		git fetch; \
		git checkout $(BRANCH); \
		git reset --hard origin/$(BRANCH)"
	scp -r ./webapp/go isu11q-3:/home/isucon/webapp/

build:
	ssh isu11q-1 " \
		cd /home/isucon/webapp/go; \
		/home/isucon/local/go/bin/go build -o isucondition"
	ssh isu11q-3 " \
		cd /home/isucon/webapp/go; \
		/home/isucon/local/go/bin/go build -o isucondition"

go-deploy:
	scp ./webapp/go/isucondition isu11q-1:/home/isucon/webapp/go/

go-deploy-dir:
	scp -r ./webapp/go isu11q-1:/home/isucon/webapp/

restart:
	ssh isu11q-1 "sudo systemctl restart isucondition.go.service"
	ssh isu11q-3 "sudo systemctl restart isucondition.go.service"

mysql-deploy:
	ssh isu11q-2 "sudo dd of=/etc/mysql/mariadb.conf.d/50-server.cnf" < ./etc/mysql/mariadb.conf.d/50-server.cnf

mysql-rotate:
	ssh isu11q-2 "sudo rm -f /var/log/mysql/mariadb-slow.log"

mysql-restart:
	ssh isu11q-2 "sudo systemctl restart mysql.service"

nginx-deploy:
	ssh isu11q-1 "sudo dd of=/etc/nginx/nginx.conf" < ./etc/nginx/nginx.conf
	ssh isu11q-1 "sudo dd of=/etc/nginx/sites-available/isucondition.conf" < ./etc/nginx/sites-available/isucondition.conf

nginx-rotate:
	ssh isu11q-1 "sudo rm -f /var/log/nginx/access.log"

nginx-reload:
	ssh isu11q-1 "sudo systemctl reload nginx.service"

nginx-restart:
	ssh isu11q-1 "sudo systemctl restart nginx.service"

memcached-restart:
	ssh isu11q-1 "sudo systemctl restart memcached.service"

env-deploy:
	ssh isu11q-1 "sudo dd of=/home/isucon/env.sh" < ./env.sh
	ssh isu11q-3 "sudo dd of=/home/isucon/env.sh" < ./env.sh

.PHONY: bench
bench:
	ssh isu11q-1 " \
		cd /home/isucon/bench; \
		./bench -all-addresses 127.0.0.11 -target 127.0.0.11:443 -tls -jia-service-url http://127.0.0.1:4999"

journalctl-1:
	ssh isu11q-1 "sudo journalctl -xef"

journalctl-3:
	ssh isu11q-3 "sudo journalctl -xef"

pt-query-digest:
	ssh isu11q-2 "sudo pt-query-digest --limit 10 /var/log/mysql/mariadb-slow.log"

nginx-log:
	ssh isu11q-1 "sudo tail -f /var/log/nginx/access.log"

ALPSORT=sum
ALPM=^/api/condition/[0-9a-f-]{36},^/api/isu/[0-9a-f-]{36}/graph,^/api/isu/[0-9a-f-]{36},^/isu/[0-9a-f-]{36}/graph,^/isu/[0-9a-f-]{36},^/\?.*
OUTFORMAT=count,method,uri,min,max,sum,avg,p99

alp:
	ssh isu11q-1 "sudo alp ltsv --file=/var/log/nginx/access.log --nosave-pos --pos /tmp/alp.pos --sort $(ALPSORT) --reverse -o $(OUTFORMAT) -m $(ALPM) -q"

pprof-1:
	ssh isu11q-1 " \
		/home/isucon/local/go/bin/go tool pprof -seconds=120 /home/isucon/webapp/go/isucondition http://localhost:6060/debug/pprof/profile"

pprof-show-1:
	$(eval latest := $(shell ssh isu11q-1 "ls -rt ~/pprof/ | tail -n 1"))
	scp isu11q-1:~/pprof/$(latest) ./pprof
	go tool pprof -http=":1080" ./pprof/$(latest)

pprof-3:
	ssh isu11q-3 " \
		/home/isucon/local/go/bin/go tool pprof -seconds=120 /home/isucon/webapp/go/isucondition http://localhost:6060/debug/pprof/profile"

pprof-show-3:
	$(eval latest := $(shell ssh isu11q-3 "ls -rt ~/pprof/ | tail -n 1"))
	scp isu11q-3:~/pprof/$(latest) ./pprof
	go tool pprof -http=":1080" ./pprof/$(latest)

pprof-kill:
	ssh isu11q-2 "pgrep -f 'pprof' | xargs kill;"
