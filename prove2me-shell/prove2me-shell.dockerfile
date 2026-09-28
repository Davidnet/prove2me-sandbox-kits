FROM docker/sandbox-templates:shell
USER agent
WORKDIR /home/agent/workspace
ENTRYPOINT ["/bin/bash"]
CMD []
