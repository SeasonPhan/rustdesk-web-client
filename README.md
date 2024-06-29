(Brace yourself, messy instructions written with my half-baked English ahead!)

I cant run docker, so this is a guide to get web client + signal+relay server + secure connection through traefik up and running

=================================

You will need to:

1 - build the web client using provided docker file in fix-build branch, after that, pull the compiled files out 

(my version of web client have some element removed, you can check the commit history and re-add those removed parts back yourself)

(Also, you can hardcode your own public keys, server address, just check the commit history of this repo)

download fix-build branch

navigate to the foler that has the DOCKERFILE, build the docker image: docker build -t rustweb .

create and run the docker container from the image: docker run -d -p 5000:5000 --name rustweb_container rustweb

pull the files from the container: docker cp rustweb_container:/app/build/web/  /folder/path/that/you/want/compiled_rustweb/

after done, prune the image/container/everything/.. (me and my poor server hate docker)

to run the web client, install python and run this command inside the client folder: python3 -u -m http.server 5001 
(you can change the port 5001 to whatever you want. You do not need to expose that port on your router since Traefik will handle that)

2 - build the modified rustdesk server with websocket ports changed

Fork rust-desk-server repo and modify the 2 files: 

src/relay_server.rs

src/rendezvous_server.rs

where it say "port + 2;" change that to "port + 100" (remember this value, you will need it later for the Traefik config)

save and use github action to build the server

Wait for the process to finish and download it and run

3 - setup traefik with your own SSL certificate

here are some free options

https://lowendspirit.com/discussion/5838/what-are-the-free-ssl-certificate-options

https://poshac.me/docs/v4/Guides/ACME-CA-Comparison/

You are on your own get traefik up and running, here is my static config for traefik v3:
```
log:
  level: DEBUG

#expose all standard rustdesk server ports and 80, 443 port on your router
#we only need traefik to manage 4 ports below

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"
  rd-tcp-21118:
    address: ":21118"
  rd-tcp-21119:
    address: ":21119"

providers:
  file:
    filename: "/root/traefik/dynamic/tls.yml"
    watch: true


####And here is my dynamic config:
http:
  routers:
    rustdesk-web-client:
      rule: "Host(`your.domain.or.server.address`)"
      entryPoints:
        - websecure
      service: rustdesk-web-client
      tls: {}

  services:
    rustdesk-web-client:
      loadBalancer:
        servers:
          - url: "http://localhost:5001" #this is your web client address
tcp:
  routers:
    rustdesk-signal-server-21118:
      entryPoints:
        - rd-tcp-21118
      service: rustdesk-signal-server-21118
      rule: "HostSNI(`*`)"
      tls: 
        passthrough: false
    rustdesk-relay-server-21119:
      entryPoints:
        - rd-tcp-21119
      service: rustdesk-relay-server-21119
      rule: "HostSNI(`*`)"
      tls:
        passthrough: false

  services:
    rustdesk-signal-server-21118:
      loadBalancer:
        servers:
          - address: "localhost:21216"
    rustdesk-relay-server-21119:
      loadBalancer:
        servers:
          - address: "localhost:21217"
#remeber that i put +100 for the ports in step 2? By default Rustdesk server will use the original 21116 for signal server (hbbs) and 21119 for relay server (hbbr), +100 means these servers will listen to port 21216 and 21217 instead of the origianl 21118 and 21119

#setup your certificates here
tls:
  certificates:
    - certFile: /root/traefik/cert/asphalt.tinytech.top.crt
      keyFile: /root/traefik/cert/asphalt.tinytech.top.key
  stores:
    default:
      defaultCertificate:
        certFile: /root/traefik/cert/asphalt.tinytech.top.crt
        keyFile: /root/traefik/cert/asphalt.tinytech.top.key
```


4 - run Traefik and enjoy your https wss goodness!













ORIGINAL README:
# RustDesk Web Client

Fork aiming to improve both **building process and features of the Web Client** of [RustDesk](https://github.com/rustdesk/rustdesk) (_An open-source remote desktop, and alternative to TeamViewer_).

## Branches

List and description of each branch of this repository, and associated modifications  
(_You can click branch's names to access them quickly_).

Any branch not described below is probably about something else "Work in Progress", or is a fix that will be turned into a Pull Request to the official RustDesk repo.

### [`master`/`fork`](https://github.com/MonsieurBiche/rustdesk-web-client/tree/master)

> Branch used to pull commits from the [official repository](https://github.com/rustdesk/rustdesk). Allows rebasing on RustDesk's modifications, regularly.

### [`fix-build`](https://github.com/MonsieurBiche/rustdesk-web-client/tree/fix-build)

> Enhanced Docker setup allowing to build and run RustDesk Web Client without issues.

#### TODO
- Improve that setup (for quicker build) and clean it (especially the messy Dockerfile)
- Add CI/CD to rebuild and push various images of the Web Client, for each released version
  - A regular version (no modifications, no wss)
  - A wss-only version (no modifications except wss)
  - A wss-feat version (modifications and wss)
- Make a customizable (using `ARGS` ?) build process, to allow adding custom server values

### [`enable-wss`](https://github.com/MonsieurBiche/rustdesk-web-client/tree/enable-wss)

> Small code modification to force RustDesk Web Client to establish `wss://` connections. **You will need to setup a Reverse Proxy correctly**, as RustDesk Server does not support WSS (see [rustdesk-server/issues/94](https://github.com/rustdesk/rustdesk-server/issues/94) & [rustdesk-server/issues/337](https://github.com/rustdesk/rustdesk-server/issues/337) )

#### TODO
- Rework and add schema from https://github.com/rustdesk/rustdesk/discussions/5145#discussioncomment-8346782 in docs
- Add traefik setup from https://github.com/rustdesk/rustdesk/discussions/6023#discussioncomment-8687562 in docs

### [`add-features`](https://github.com/MonsieurBiche/rustdesk-web-client/tree/add-features)

> Branch where all additionnal (and/or experimental) features are pushed.

#### List of modifications
- Auto connect/login using query parameters, based on [JelleBunning's fork](https://github.com/JelleBuning/rustdesk/tree/fix_build).
  > Allows using URLs like https://your.host.com/#/connect?id=123456789&pw=your-password

- Enforce `'adapative` scale (`ViewStyle`) when starting a remote connection, for a better behaviour.
- Small codes fixes on the `mobile` side of the code (`RemotePage` especially), to remove errors in browser's console.

#### TODO
- Fix issues around Web Client usage on a Mobile device (see [rustdesk/issues/7667](https://github.com/rustdesk/rustdesk/issues/7667))

## Contributing

Feel free to contribute, there's a lot of things to improve (as shown in TODOs), help, knowledge and new ideas are always welcome 😉
