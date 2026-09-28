FROM docker/sandbox-templates:claude-code
USER root
RUN mkdir -p /home/agent/.config/prove2me-claude \
    && chown -R agent:agent /home/agent/.config/prove2me-claude
USER agent
WORKDIR /home/agent/workspace
ENTRYPOINT ["claude", "--settings", "/home/agent/.config/prove2me-claude/settings.json"]
CMD []
