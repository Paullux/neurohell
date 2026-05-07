FROM nginx:stable-alpine

RUN rm -rf /usr/share/nginx/html/*

COPY . /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Vérifie que les docs ont bien été copiées par le step CI — fail loud si absent
RUN echo "=== Docs dans le container ===" && \
    ls /usr/share/nginx/html/assets/docs/game/ && \
    echo "=== OK ==="

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]