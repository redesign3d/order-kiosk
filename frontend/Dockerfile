FROM ghcr.io/cirruslabs/flutter:3.24.0 as build
WORKDIR /app
COPY pubspec.* ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

FROM nginx:alpine
WORKDIR /usr/share/nginx/html
COPY --from=build /app/build/web ./
EXPOSE 80
