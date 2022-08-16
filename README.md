This is an experimental way to install Grist on a public
server with minimal fuss, for evaluation purposes.

So you can log in:
![Screenshot from 2022-08-16 18-14-16](https://user-images.githubusercontent.com/118367/184994955-df9359d6-86b3-4147-9214-058b2c8c5fe7.png)

And use Grist:
![Screenshot from 2022-08-16 18-16-38](https://user-images.githubusercontent.com/118367/184995003-aa4ae6e7-6a05-420f-98a8-36b465bc2a81.png)

It bundles:

 * Grist itself from https://github.com/gristlabs/grist-core/ -
   Grist is a handy spreadsheet / online database app,
   presumably you like it and that's why you are here.
 * A reverse proxy, Traefik https://github.com/traefik/traefik) -
   we use this to coordinate with Let's Encrypt to get a
   certificate for https traffic.
 * An identity service, Dex https://github.com/dexidp/dex/ -
   this can connect to LDAP servers, SAML providers, Google,
   Microsoft, etc, and also (somewhat reluctantly) supports
   hard-coded user/passwords that can be handy for initial
   playing around.
 * An authentication middleware, traefik-forward-auth,
   https://github.com/thomseddon/traefik-forward-auth to
   connect Grist and Dex via Traefik.

Here's the minimal configuration you need to provide.
 * `EMAIL`: an email address, used for Let's Encrypt and for
   initial login.
 * `PASSWORD`: optional - if you set this, you'll be able to
   login using it without configuring any other authentication
   settings. You can add more accounts by adding `EMAIL2`,
   `PASSWORD2`, `EMAIL3`, `PASSWORD3` etc.
 * `URL` - this is important, you need to provide the base
   URL at which Grist will be accessed. It could be something
   like `https://grist.example.com`, or `http://localhost:9999`.
   No path element please. If not using `localhost`, the URL
   will genuinely need to be reachable or things won't work out.
 * `TEAM` - a short identifier, such as a company name
   (`grist-labs`, `cool-beans`). Just `A-Z`, `a-z`, `0-9` and
   `-` characters please.
 * `HTTPS` - mandatory if `URL` is `https` protocol. Can be
   `auto` (Let's Encrypt) if Grist is publically accessible and
   you are fine with a certificate sourced from Let's Encrypt with
   default settings. Otherwise use `external` (if you are dealing
   with ssl termination yourself) or `manual` (if you can provide
   a certificate).

And the minimal storage needed is an empty directory mounted
at `/persist`.

So here is a complete docker invocation that would work on a public
instance with ports 80 and 443 available:
```
mkdir -p /tmp/grist-test
docker run \
  -p 80:80 -p 443:443 \
  -e URL=https://cool-beans.example.com \
  -e HTTPS=auto \
  -e TEAM=cool-beans \
  -e EMAIL=owner@example.com \
  -e PASSWORD=topsecret \
  -v /tmp/grist-test:/persist \
  --name grist --rm \
  -it paulfitz/grist-omnibus
```

And here is an invocation on localhost port 9999 - the only
differences are the `-p` port configuration and the `-e URL=` environment
variable.
```
mkdir -p /tmp/grist-test
docker run \
  -p 9999:80 \
  -e URL=http://localhost:9999 \
  -e TEAM=cool-beans \
  -e EMAIL=owner@example.com \
  -e PASSWORD=topsecret \
  -v /tmp/grist-test:/persist \
  --name grist --rm \
  -it paulfitz/grist-omnibus
```

If providing your own certificate (`HTTPS=manual`), provide a
private key and certificate file as `/custom/grist.key` and
`custom/grist.crt` respectively:

```
docker run \
  ...
  -v $(PWD)/key.pem:/custom/grist.key \
  -v $(PWD)/cert.pem:/custom/grist.crt \
  ...
```

You can change `dex.yaml` (for example, to fill in keys for Google
and Microsoft sign-ins, or to remove them) and then either rebuild
the image or make the custom settings available to the omnibus
as `/custom/dex.yaml`:

```
docker run \
  ...
  -v $PWD/dex.yaml:/custom/dex.yaml \
  ...
  -it paulfitz/grist-omnibus
```

You can tell it is being used because `Using /custom/dex.yaml` will
be printed instead of `No /custom/dex.yaml`.

TODOS:

 - [x] prep a complete image and sample invocation that works on a public host
 - [x] prep a complete image and sample invocation that works on localhost
 - [x] clean up and condense the scripts+settings in this repo
 - [ ] show screenshots to show what to expect
 - [ ] document how to configure other auth methods and turning off hardcoded username/passwords
 - [x] include ARM image flavor
 - [ ] add workflow for keeping image up to date
 - [ ] move repo and image - maybe gristlabs/grist-omnibus or gristlabs/grist-dex for both?
