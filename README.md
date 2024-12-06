# How to setup AmneziaWG on Microtik router

## Configure Mikrotik router

1. Setup Containers on mikrotik accoring to [Mikrotik Container](https://help.mikrotik.com/docs/display/ROS/Container)

2. Configure AWG container

It will download container image from hub.docker.io, below there is
explanation how to build and install image yourself

```shell

/interface veth
add address=10.0.1.11/24 gateway=10.0.1.1 name=veth1

/interface bridge
add name=containers port-cost-mode=short

/interface bridge port
add bridge=containers interface=veth1 internal-path-cost=10 path-cost=10

/interface list member
add interface=containers list=LAN

/container mounts
add dst=/etc/amnezia name=awg-conf src=/awg-conf comment="AmneziaWG etc"

/container
config set registry-url=https://registry-1.docker.io tmpdir=/images/pull

/container
add remote-image=vgrebenschikov/amneziawg-mikrotik:latest hostname=awg interface=veth1 mounts=awg-conf root-dir=/awg
```

3. Start Container

```shell
/container start 0

/container shell 0
awg:/# wg show
interface: awg0
  public key: Pwdoq...=
  private key: (hidden)
  listening port: 55656
  jc: 11
  jmin: 33
  jmax: 1030
  s1: 70
  s2: 167
  h1: 2068080600
  h2: 636451746
  h3: 3054654459
  h4: 1453478960
```

## Build Image

1. Build image for container, matching your architecure, tested on ARMv7 for RB4011.
2. Then save built image into tar archive.
3. Then send the archive into router with scp or through Winbox.

```shell
$ docker compose build
[+] Building 71.2s
...

$ docker save amneziawg-mikrotik:latest > amneziawg-mikrotik.tar

$ scp amneziawg-mikrotik.tar mikrotik:
```

If you sent container image that way to mikrotik - use following command to
create container (file= instead of remote-image=)

```
/container
add file=amneziawg-mikrotik.tar hostname=awg interface=veth1 mounts=awg-conf root-dir=/awg
```

or, instead, you can download image as explained below:

## Download Image Manualy

You can pull image from dockerhub as usual, do not forget to specify correct
platform:

- linux/arm/v7 -> for ARM-based routers, i.e. RB4011
- linux/amd64 -> for x86-64 routers, like CHR

```shell

$ docker pull --platform linux/arm/v7 vgrebenschikov/amneziawg-mikrotik:latest
$ docker save amneziawg-mikrotik:latest > amneziawg-mikrotik.tar
$ scp amneziawg-mikrotik.tar mikrotik:
```


## (Re)Configuration

You can login into container as shown above and can edit config as

```shell
awg:/# vi /etc/amnezia/amneziawg/awg0.conf
```

to apply new configuration you can run following command (as usual for awg):

```shell
awg:/# awg-quick strip awg0 | wg setconf awg0 /dev/stdin
```

Or you can restart contaner with `/container/stop 0` and then `/container/start 0`

To force container run on start - set start-on-boot=yes:

```shell
/container/set 0 start-on-boot=yes
```

## Firewall usege to distinguish in-tunnel and endpoint traffic

awg-quick script is modified not to use firewall marks as they are not supported in ROS containers.
Instead you can use following config to setup awg0 table, and use it for awg0 routes and send all transit traffic recieved on eth0 to awg0:

```shell
[Interface]
...

Table = awg0
PostUp = ip rule add priority 300 from all iif eth0 lookup awg0 || true
PostDown = ip rule del from all iif eth0 lookup awg0 || true
```
