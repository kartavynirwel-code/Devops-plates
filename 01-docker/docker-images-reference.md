# Docker Images Reference — Build, Runtime & Distroless

Quick reference for Dockerfiles across languages. Use this for multi-stage builds:
**Build stage** → compile/install deps → **Runtime stage** → copy artifacts + run.

---

## Java

| Stage | Image | Notes |
|---|---|---|
| Build | `maven:3.9-eclipse-temurin-21` | Maven projects, has JDK + Maven |
| Build (alt) | `gradle:8-jdk21-alpine` | Gradle projects |
| Runtime | `eclipse-temurin:21-jre-alpine` | JRE only, no JDK — production default |
| Runtime (alt) | `eclipse-temurin:21-jre-jammy` | Debian-based, if alpine causes glibc issues |

**Distroless:** `gcr.io/distroless/java21-debian12` — copy your built `.jar` into this, no shell/package manager.

---

## Python

| Stage | Image | Notes |
|---|---|---|
| Build | `python:3.12-slim` | Install deps with pip, compile wheels if needed |
| Build (heavy deps) | `python:3.12` (full, non-slim) | If you need gcc/build-essential for C-extension packages (numpy, etc.) |
| Runtime | `python:3.12-slim` | Copy site-packages + app code here |

**Distroless:** `gcr.io/distroless/python3-debian12` — works only if no dynamic C-lib dependency issues; test carefully with FastAPI/Django.

---

## Node.js

| Stage | Image | Notes |
|---|---|---|
| Build | `node:20-alpine` | `npm ci`, `npm run build` |
| Runtime (API/server) | `node:20-alpine` | Copy `node_modules` + `dist`/`build` |
| Runtime (static output) | `nginx:alpine` | If output is static files (no server needed) |

**Distroless:** `gcr.io/distroless/nodejs20-debian12` — copy `node_modules` + built JS, no shell.

*Use this same pattern (build in node:alpine → serve via nginx:alpine) for any Node-based framework: Express, Nest.js, etc.*

---

## React

| Stage | Image | Notes |
|---|---|---|
| Build | `node:20-alpine` | `npm run build` → generates static `build/` folder |
| Runtime | `nginx:alpine` | Serve static files, copy `build/` → `/usr/share/nginx/html` |

**Distroless:** Not typical for React — since output is just static HTML/JS/CSS, `nginx:alpine` itself is already minimal. Only use distroless if you want an even smaller attack surface: `gcr.io/distroless/static-debian12` + a static file server binary.

> **Use this exact pattern for React Native (web builds / Expo web) too** — same `node:20-alpine` build → static serve approach applies.

---

## Vite (React/Vue/Svelte + Vite)

| Stage | Image | Notes |
|---|---|---|
| Build | `node:20-alpine` | `npm run build` → outputs to `dist/` |
| Runtime | `nginx:alpine` | Copy `dist/` → `/usr/share/nginx/html` |

> Same build+runtime pattern as React above — **use this for any Vite-based project** (Vue+Vite, Svelte+Vite, vanilla+Vite), just the build command differs, output folder stays `dist/`.

---

## Go (Golang)

| Stage | Image | Notes |
|---|---|---|
| Build | `golang:1.22-alpine` | `go build -o app` |
| Runtime | `alpine:3.19` | Copy compiled static binary, tiny final image |

**Distroless:** `gcr.io/distroless/static-debian12` — best fit for Go since binaries are statically compiled (no libc dependency issues). This is the gold-standard distroless use case.

---

## PHP

| Stage | Image | Notes |
|---|---|---|
| Build | `composer:2` | `composer install` for dependencies |
| Runtime | `php:8.3-fpm-alpine` | Pair with nginx as reverse proxy |
| Runtime (alt) | `php:8.3-apache` | Self-contained, Apache + PHP built in |

**Distroless:** Not practical for PHP — needs PHP-FPM/Apache process running, distroless images don't support this runtime model well. Stick to `php:8.3-fpm-alpine`.

---

## .NET (added — common in enterprise/campus placements)

| Stage | Image | Notes |
|---|---|---|
| Build | `mcr.microsoft.com/dotnet/sdk:8.0` | `dotnet publish` |
| Runtime | `mcr.microsoft.com/dotnet/aspnet:8.0` | ASP.NET apps |
| Runtime (console/worker) | `mcr.microsoft.com/dotnet/runtime:8.0` | No web server needed |

**Distroless:** `mcr.microsoft.com/dotnet/nightly/runtime-deps:8.0-jammy-chiseled` — Microsoft's own "chiseled" images are their distroless equivalent.

---

## Rust (added — good for interview talking points, ultra-small images)

| Stage | Image | Notes |
|---|---|---|
| Build | `rust:1.79-alpine` | `cargo build --release` |
| Runtime | `alpine:3.19` | Copy compiled binary |

**Distroless:** `gcr.io/distroless/cc-debian12` — Rust binaries usually need libc/libgcc, use `cc` variant not `static`.

---

## Ruby (added)

| Stage | Image | Notes |
|---|---|---|
| Build | `ruby:3.3-alpine` | `bundle install` |
| Runtime | `ruby:3.3-alpine` | Copy gems + app code |

**Distroless:** Not officially maintained by Google's distroless project — skip, use slim/alpine instead.

---

## Distroless — Quick Recap

Distroless images strip out shell, package manager, and unnecessary OS tools — only your app + its runtime deps remain. Benefits: smaller attack surface, smaller image size, fewer CVEs to patch.

**Trade-off:** No shell means you can't `docker exec` in and debug interactively — use `kubectl debug` with an ephemeral container instead, or keep a `-debug` tagged distroless variant (Google provides these) for troubleshooting.

| Language | Distroless Image |
|---|---|
| Java | `gcr.io/distroless/java21-debian12` |
| Python | `gcr.io/distroless/python3-debian12` |
| Node.js | `gcr.io/distroless/nodejs20-debian12` |
| Go | `gcr.io/distroless/static-debian12` |
| Rust | `gcr.io/distroless/cc-debian12` |
| .NET | `mcr.microsoft.com/dotnet/nightly/runtime-deps:8.0-jammy-chiseled` |
| Generic/static binaries | `gcr.io/distroless/base-debian12` |

