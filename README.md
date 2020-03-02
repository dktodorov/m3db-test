# Results from comparisons:
### CPU/Memory Usage 

It appears that prometheus with m3db storage backend, consule almost two time more CPU/Memory. Also we need to take in mind, that m3db is consumming also CPU and Memory, and in our case scenario this was about 30G Memory and 6 CPU Cores.

Prometheus Graphs (During Scraping)
[![local](https://github.com/dktodorov/m3db-test/raw/master/img/screen-mutt-dark-th.png)](https://github.com/dktodorov/m3db-test/raw/master/img/prom-resources.png)

Prometheus M3DB Graphs (During Scraping)
[![m3db](https://github.com/dktodorov/m3db-test/raw/master/img/screen-mutt-dark-th.png)](https://github.com/dktodorov/m3db-test/raw/master/img/prom-m3db-resources.png)

#### Query benchmark
With `ab` i tried to benchmark prometheus query `{job="ff-avalanche"}` which fetch 12505 series

Prometheus
```
root@instance-1:~# ab -n 100  'http://35.190.15.52/api/v1/query?query=%7Bjob%3D%22ff-avalanche%22%7D%20&time=1583165214.984&_=1583160936408'
This is ApacheBench, Version 2.3 <$Revision: 1757674 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking 35.190.15.52 (be patient).....done


Server Software:        
Server Hostname:        35.190.15.52
Server Port:            80

Document Path:          /api/v1/query?query=%7Bjob%3D%22ff-avalanche%22%7D%20&time=1583165214.984&_=1583160936408
Document Length:        7116722 bytes

Concurrency Level:      1
Time taken for tests:   314.556 seconds
Complete requests:      100
Failed requests:        0
Total transferred:      711682700 bytes
HTML transferred:       711672200 bytes
Requests per second:    0.32 [#/sec] (mean)
Time per request:       3145.556 [ms] (mean)
Time per request:       3145.556 [ms] (mean, across all concurrent requests)
Transfer rate:          2209.47 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    1   0.7      0       6
Processing:  2171 3145 1199.6   2486    6453
Waiting:     1239 2194 1197.6   1545    5507
Total:       2172 3145 1199.6   2486    6453
WARNING: The median and mean for the initial connection time are not within a normal deviation
        These results are probably not that reliable.

Percentage of the requests served within a certain time (ms)
  50%   2486
  66%   2898
  75%   4172
  80%   4410
  90%   5382
  95%   5481
  98%   5592
  99%   6453
 100%   6453 (longest request)
```

Prometheus M3DB
```
root@instance-1:~# ab -n 100  'http://34.98.69.149/api/v1/query?query=%7Bjob%3D%22ff-avalanche%22%7D%20&time=1583165214.984&_=1583160936408'
This is ApacheBench, Version 2.3 <$Revision: 1757674 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking 34.98.69.149 (be patient).....done


Server Software:        
Server Hostname:        34.98.69.149
Server Port:            80

Document Path:          /api/v1/query?query=%7Bjob%3D%22ff-avalanche%22%7D%20&time=1583165214.984&_=1583160936408
Document Length:        714 bytes

Concurrency Level:      1
Time taken for tests:   284.912 seconds
Complete requests:      100
Failed requests:        0
Total transferred:      711682700 bytes
HTML transferred:       711672200 bytes
Requests per second:    0.35 [#/sec] (mean)
Time per request:       2849.115 [ms] (mean)
Time per request:       2849.115 [ms] (mean, across all concurrent requests)
Transfer rate:          0.29 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    1   0.4      0       3
Processing:  2131 2849 489.6   2804    6101
Waiting:     2131 2848 489.6   2804    6101
Total:       2132 2849 489.5   2805    6101
ERROR: The median and mean for the initial connection time are more than twice the standard
       deviation apart. These results are NOT reliable.

Percentage of the requests served within a certain time (ms)
  50%   2805
  66%   2950
  75%   3077
  80%   3122
  90%   3368
  95%   3499
  98%   3954
  99%   6101
 100%   6101 (longest request)
```

# Deploy

## Configure GCloud Project

```
$ gcloud config set project [GCP-Project-ID]
```

## Preparing workspace

```
$ git clone https://github.com/dktodorov/m3db-test.git
$ cd m3db-test/
```

## Deploy k8s Cluster and connect to it.

```
$ terraform init terraform/
$ terraform apply terraform/
$ gcloud container clusters get-credentials test-cluster --zone europe-west3-c --project [GCP-Project-ID]
```

## Deploy M3DB and configure it

```
$ kubectl apply -f deployments/m3db.yml
```

#### Before continue with m3db configuration, wait for all pods for M3DB are availabe, example:

```
$ kubectl -n m3db get pods
NAME         READY     STATUS    RESTARTS   AGE
etcd-0       1/1       Running   0          22m
etcd-1       1/1       Running   0          22m
etcd-2       1/1       Running   0          22m
m3dbnode-0   1/1       Running   0          22m
m3dbnode-1   1/1       Running   0          22m
m3dbnode-2   1/1       Running   0          22m
```

#### Configure

```
# Open a local connection to the coordinator service:
$ kubectl -n m3db port-forward svc/m3coordinator 7201 &
Forwarding from 127.0.0.1:7201 -> 7201
```

```
# Create an initial cluster topology
curl -sSf -X POST localhost:7201/api/v1/placement/init -d '{
    "num_shards": 1024,
    "replication_factor": 3,
    "instances": [
        {
            "id": "m3dbnode-0",
            "isolation_group": "pod0",
            "zone": "embedded",
            "weight": 100,
            "endpoint": "m3dbnode-0.m3dbnode:9000",
            "hostname": "m3dbnode-0.m3dbnode",
            "port": 9000
        },
        {
            "id": "m3dbnode-1",
            "isolation_group": "pod1",
            "zone": "embedded",
            "weight": 100,
            "endpoint": "m3dbnode-1.m3dbnode:9000",
            "hostname": "m3dbnode-1.m3dbnode",
            "port": 9000
        },
        {
            "id": "m3dbnode-2",
            "isolation_group": "pod2",
            "zone": "embedded",
            "weight": 100,
            "endpoint": "m3dbnode-2.m3dbnode:9000",
            "hostname": "m3dbnode-2.m3dbnode",
            "port": 9000
        }
    ]
}'
```

```
# Create a namespace to hold your metrics
curl -X POST localhost:7201/api/v1/namespace -d '{
  "name": "default",
  "options": {
    "bootstrapEnabled": true,
    "flushEnabled": true,
    "writesToCommitLog": true,
    "cleanupEnabled": true,
    "snapshotEnabled": true,
    "repairEnabled": false,
    "retentionOptions": {
      "retentionPeriodDuration": "720h",
      "blockSizeDuration": "12h",
      "bufferFutureDuration": "1h",
      "bufferPastDuration": "1h",
      "blockDataExpiry": true,
      "blockDataExpiryAfterNotAccessPeriodDuration": "5m"
    },
    "indexOptions": {
      "enabled": true,
      "blockSizeDuration": "12h"
    }
  }
}'
```

#### Shortly after you should see your nodes finish bootstrapping: 

```
$ kubectl -n m3db logs -f m3dbnode-0
21:36:54.831698[I] cluster database initializing topology
21:36:54.831732[I] cluster database resolving topology
21:37:22.821740[I] resolving namespaces with namespace watch
21:37:22.821813[I] updating database namespaces [{adds [metrics]} {updates []} {removals []}]
21:37:23.008109[I] node tchannelthrift: listening on 0.0.0.0:9000
21:37:23.008384[I] cluster tchannelthrift: listening on 0.0.0.0:9001
21:37:23.217090[I] node httpjson: listening on 0.0.0.0:9002
21:37:23.217240[I] cluster httpjson: listening on 0.0.0.0:9003
21:37:23.217526[I] bootstrapping shards for range starting [{run bootstrap-data} {bootstrapper filesystem} ...
...
21:37:23.239534[I] bootstrap data fetched now initializing shards with series blocks [{namespace metrics} {numShards 256} {numSeries 0}]
21:37:23.240778[I] bootstrap finished [{namespace metrics} {duration 23.325194ms}]
21:37:23.240856[I] bootstrapped
21:37:29.733025[I] successfully updated topology to 3 hosts
```

## Deploy Prometheuses

```
$ kubectl apply -f deployments/prometheus.yml
$ kubectl apply -f deployments/prometheus-m3db.yml
```

## Deploy Grafana

```
kubectl apply -f deployments/grafana.yml
```

## Get public IPs of Prometheus and Grafana

#### Default grafana user/pass are admin/admin


```
$ kubectl get ingress
NAME                 HOSTS   ADDRESS          PORTS   AGE
grafana              *       34.*.*.*         80      2m11s
prometheus-m3db-ui   *       34.*.*.*         80      2m57s
prometheus-ui        *       35.*.*.*         80      3m2s
```

#### Because of issues with Grafana Provision, currently the dashboard which we are going to use for mesuring both prometheus resouces, can't be automatically added, so you need to import it as JSON from Grafana UI. Url `https://grafana.com/grafana/dashboards/3681`

## Deploy avalanche to simulate Prometheus metrics

```
$ kubectl apply -f deployments/avalanche.yml

```
