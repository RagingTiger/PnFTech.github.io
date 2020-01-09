# Base NGINX image (with alpine 3.9)
FROM nginx:1.15.8-alpine

# Get static content
COPY .  /usr/share/nginx/html/

