
I'm playing with making a single-image version of Grist for
people looking to try it out as a self-hosted app. Currently
configuring auth is a bit daunting, maybe this will help?

Not ready for use yet! Don't do it!

How to use.

  - Environment variables:
    - URL: meaning
	- EMAIL: thing
	- PASSWORD (optional): thing

  - Volumes/mounts/directories:
    - Mount an empty directory as /persist - this is where all stuff that
	  should survive a server restart will be kept.
    - Optionally, mount a directory with a dex.yaml file in it as /custom -
	  this will customize the log in methods available.

  - Ports
    - Ports 80 (for http) and 443 (for https) are available.
	- If port 443 is used, then certificates will be requested from
	  LetsEncrypt using the specified EMAIL.
    - The container had better really be serving to the world at the
	  given URL for LetsEncypt to confirm that the server is what it claims
	  to be. If it isn't, https won't work.
    - Avoid mapping to ports 17100, 17101, and 17102 due to a little wrinkle.
	  When URL is http://localhost:NNNN a service matches that NNNN internally
	  to work around an awkwardness in how localhost works in a container.
