# How to setup AmneziaWG on Microtik router

## Prepare image

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

## Configure Mikrotik router

1. Setup Containers on mikrotik accoring to [Mikrotik Container](https://help.mikrotik.com/docs/display/ROS/Container)

2. Configure AWG container

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
add file=amneziawg-mikrotik.tar hostname=awg interface=veth1 mounts=awg-conf root-dir=/awg
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

## Be careful

awg-quick script is modified not to use firewall, 
so if you going to use default route into awg tunnel in container,
make sure that you route endpoint of other end of tunnel to the eth0 interface with additional route command.
