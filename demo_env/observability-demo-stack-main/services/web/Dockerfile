FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY html/ /usr/share/nginx/html/
COPY entrypoint/40-rum-config.sh /docker-entrypoint.d/40-rum-config.sh

# COPY preserves the source file mode. If the files on the build host are 0600
# (which is what most tooling produces), nginx's worker -- uid 101, not root --
# cannot read them and every request returns 403. Normalise explicitly rather
# than depending on the checkout's permissions.
RUN chmod -R a+rX /usr/share/nginx/html \
    && chmod 0644 /etc/nginx/conf.d/default.conf \
    && chmod 0755 /docker-entrypoint.d/40-rum-config.sh

EXPOSE 80
