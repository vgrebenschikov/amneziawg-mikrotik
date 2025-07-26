# How to set up AmneziaWG on Mikrotik router

## Configure Mikrotik router

1. Set up Containers on Mikrotik according to [Mikrotik Container](https://help.mikrotik.com/docs/display/ROS/Container)

2. Configure AWG container

    It will download the container image from hub.docker.io. Below is an
    explanation of how to build and install the image yourself.

    ```shell

    /interface veth
    add address=10.0.1.11/24 gateway=10.0.1.1 name=awg0

    /ip address
    add address=10.0.1.1/24 interface=awg0

    /interface list member
    add interface=awg0 list=WAN

    /container mounts
    add dst=/etc/amnezia name=awg0-conf src=/awg0-conf comment="awg0 /etc"

    /container
    config set registry-url=https://registry-1.docker.io tmpdir=/images/pull

    /container
    add name=awg0 remote-image=vgrebenschikov/amneziawg-mikrotik:latest hostname=awg0 interface=awg0 mounts=awg0-conf root-dir=/awg0
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

## Configuration Tweaks

If you have peer endpoint as DNS name and you wish to check if IP address was changed (DDNS scenarion).
You may use Interface section config option `CheckPeerDNS = <poll-interval>`, as

```shell
[Interface]
PrivateKey = GGs...
Address = 10.0.1.11/24
ListenPort = 12345

Jc = 7
Jmin = 55
Jmax = 1000
S1 = 77
S2 = 122
H1 = 100...
H2 = 735...
H3 = 223...
H4 = 273...

CheckPeerDNS = 300

[Peer]
PublicKey = Pw...
PresharedKey = ...
AllowedIPs = 0.0.0.0/0
Endpoint = my.dynamic.server.name:12345
```

With such configuration, awg-quick script will check if DNS name was changes every 5 min,
and if changed, configure new endpoint IP address.

## Build Image

1. Build the image for the container, matching your architecture (tested on ARMv7 for RB4011).
2. Then save the built image into a tar archive.
3. Then send the archive to the router with scp or through Winbox.

```shell
$ docker compose build
[+] Building 71.2s
...

$ docker save amneziawg-mikrotik:latest > amneziawg-mikrotik.tar

$ scp amneziawg-mikrotik.tar mikrotik:
```

If you sent the container image that way to Mikrotik, use the following command to
create the container (file= instead of remote-image=):

```shell
/container
add file=amneziawg-mikrotik.tar hostname=awg interface=veth1 mounts=awg-conf root-dir=/awg
```

or, instead, you can download the image as explained below:

## Download Image Manually

You can pull the image from Docker Hub as usual. Do not forget to specify the correct
platform:

- linux/arm/v7 -> for ARM-based routers, i.e. RB4011
- linux/amd64 -> for x86-64 routers, like CHR

```shell
docker pull --platform linux/arm/v7 vgrebenschikov/amneziawg-mikrotik:latest
docker save amneziawg-mikrotik:latest > amneziawg-mikrotik.tar
scp amneziawg-mikrotik.tar mikrotik:
```

## (Re)Configuration

You can log into the container as shown above and edit the config as follows:

```shell
/container shell 0
awg:/# vi /etc/amnezia/amneziawg/awg0.conf
```

To apply the new configuration, you can run the following command:

```shell
awg:/# awg-reload
```

Or you can restart the container with `/container/stop 0` and then `/container/start 0`

To force the container to run on start, set start-on-boot=yes:

```shell
/container/set 0 start-on-boot=yes
```

## Firewall usage to distinguish in-tunnel and endpoint traffic

The awg-quick script is modified not to use firewall marks as they are not supported in ROS containers.
Instead, you can use the following config to set up the awg0 table, and use it for awg0 routes and send all transit traffic received on eth0 to awg0:

```shell
[Interface]
...

Table = awg0
PostUp = ip rule add priority 300 from all iif eth0 lookup awg0 || true
PostDown = ip rule del from all iif eth0 lookup awg0 || true
```
