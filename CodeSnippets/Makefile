SUDO := sudo -H

default: pbuild prun

pbuild:
	$(SUDO) podman build -t pcp-pipeline .

prun:
	$(SUDO) podman run --privileged --rm --hostname=$(shell hostname) --name pcp-test --volume .:/tmp/test:z pcp-pipeline
