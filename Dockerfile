FROM nginx:stable-alpine

RUN apk add --no-cache git-lfs && git lfs install

RUN rm -rf /usr/share/nginx/html/*

COPY . /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]