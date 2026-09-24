# Despliegue en producción

Guía del despliegue de este fork: VPS con Docker Compose, nginx como proxy inverso con HTTPS y GitHub Actions para publicar y desplegar la imagen.

## 1. Arquitectura

```
Navegador ──HTTPS──► nginx (servidor) ──┬─ /            ──► 127.0.0.1:4000  (app Craftplan)
                                        └─ /craftplan/  ──► 127.0.0.1:9000  (bucket de MinIO: fotos)

Docker Compose (docker-compose.prod.yml)
  craftplan  ghcr.io/ar-beep12/craftplan_devops:main   la aplicación
  postgres   postgres:16                               base de datos (volumen postgres_data)
  minio      quay.io/minio/minio:latest                fotos de productos (volumen minio_data)
```

- La app **sube** las fotos a MinIO por la red interna de Docker (`http://minio:9000`).
- El navegador **descarga** las fotos con URLs firmadas que apuntan al dominio público (`https://TU_DOMINIO/craftplan/...`). Nginx las reenvía a MinIO.
- Solo hay un dominio, por eso MinIO se publica **por ruta** (`/craftplan/`) y no por subdominio.

## 2. Requisitos del servidor

- Linux con Docker y Docker Compose.
- nginx y certbot (certificado HTTPS de Let's Encrypt).
- Un dominio apuntando a la IP del servidor.
- El repositorio clonado en `/apps/craftplan` (el workflow de deploy usa esa ruta).

## 3. Primer despliegue

```bash
cd /apps
git clone https://github.com/AR-beep12/craftplan_devops.git craftplan
cd craftplan
cp .env.example .env      # y rellenar los valores (sección 4)
docker compose -f docker-compose.prod.yml up -d
```

## 4. Variables de entorno (`.env`)

El `.env` vive **solo en el servidor** y no se sube al repositorio.

| Variable | Obligatoria | Descripción |
|---|---|---|
| `SECRET_KEY_BASE` | Sí | Clave de Phoenix. `openssl rand -base64 48` |
| `TOKEN_SIGNING_SECRET` | Sí | Firma de tokens de la API. `openssl rand -base64 48` |
| `CLOAK_KEY` | Sí | Clave AES de 32 bytes en base64 para cifrar datos. `openssl rand -base64 32` |
| `POSTGRES_PASSWORD` | Sí | Contraseña de PostgreSQL. |
| `HOST` | Sí | Dominio público, por ejemplo `TU_DOMINIO`. |
| `PORT` | No | Puerto de la app (por defecto `4000`). |
| `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` | **Sí, cámbialas** | Credenciales de MinIO. Por defecto son `minioadmin` / `minioadmin`, que no deben quedar en producción. La app usa estas mismas credenciales para subir fotos. |
| `AWS_S3_PUBLIC_SCHEME` | Sí (fotos) | `https://` |
| `AWS_S3_PUBLIC_HOST` | Sí (fotos) | Dominio público, sin `https://` ni puerto. Ejemplo: `TU_DOMINIO` |
| `AWS_S3_PUBLIC_PORT` | Sí (fotos) | `443` |

Las variables `AWS_S3_HOST`, `AWS_S3_PORT`, `AWS_S3_SCHEME`, `AWS_S3_BUCKET` y las credenciales de acceso ya las define `docker-compose.prod.yml`; no van en el `.env`.

Después de cambiar el `.env`, recrea los contenedores para que lo lean:

```bash
docker compose -f docker-compose.prod.yml up -d
```

## 5. nginx

Bloque `server` con HTTPS (certbot lo administra). Solo se muestran las partes que importan:

```nginx
server {
    server_name TU_DOMINIO;

    # La aplicación
    location / {
        proxy_pass http://127.0.0.1:4000;
        proxy_http_version 1.1;
        proxy_set_header Connection '';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Fotos de productos (bucket "craftplan" de MinIO)
    location /craftplan/ {
        proxy_pass http://127.0.0.1:9000;      # sin "/" ni ruta al final
        proxy_http_version 1.1;
        proxy_set_header Connection '';
        proxy_set_header Host $host;           # MinIO firma la URL con este host
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_request_buffering off;
        client_max_body_size 0;
    }

    listen 443 ssl;   # administrado por certbot
    # ssl_certificate ... (certbot)
}
```

Puntos importantes:

- `proxy_pass` de `/craftplan/` va **sin nada al final**, para que nginx conserve la ruta completa.
- El `Host` debe reenviarse sin cambios; si no, MinIO rechaza el enlace firmado (`SignatureDoesNotMatch`).
- Solo se expone el bucket `craftplan`. La consola de MinIO (puerto 9001) no se publica.

Recargar tras editar: `nginx -t && systemctl reload nginx`.

## 6. Fotos de productos

Flujo: la app guarda la foto en MinIO y luego pide una URL firmada con `AWS_S3_PUBLIC_*`. Si esas variables faltan, la URL apunta a `localhost:9000` y el navegador no puede cargar la imagen.

Comprobaciones:

```bash
# nginx enruta a MinIO: debe responder 403 AccessDenied en XML (Server: MinIO)
curl -i https://TU_DOMINIO/craftplan/

# la app recibió las variables
docker compose -f docker-compose.prod.yml exec craftplan env | grep -E "AWS_S3_(PORT|PUBLIC)"
```

## 7. CI/CD (GitHub Actions)

| Workflow | Cuándo corre | Qué hace |
|---|---|---|
| `ci.yml` | Pull requests y push a `main` | Levanta PostgreSQL 16, instala Elixir con mise y ejecuta `mise run ci`: formato, compilación, assets y tests. |
| `docker-publish.yml` | Push a `main` y releases | Construye la imagen (`amd64` y `arm64`) y la publica en `ghcr.io` con las etiquetas `main`, la versión y `latest`. |
| `deploy-contabo.yml` | Al terminar con éxito `Docker`, o manualmente | Entra por SSH al servidor, ejecuta `docker compose pull` y `up -d`, y limpia imágenes viejas. |

```
Pull request ------> CI

Push a main ---+---> CI                                    (en paralelo)
               |
               +---> Docker (imagen) ---> Deploy a Contabo
```

**El CI no bloquea el despliegue:** al hacer push a `main`, el CI y la construcción de la imagen arrancan a la vez, y el deploy solo espera a Docker. Si un merge rompe los tests, la imagen se despliega igual.

### Secretos del repositorio

Se configuran en GitHub → Settings → Secrets and variables → Actions:

| Secreto | Uso |
|---|---|
| `SSH_HOST` | IP o dominio del servidor |
| `SSH_USERNAME` | Usuario SSH |
| `SSH_PRIVATE_KEY` | Llave privada SSH |
| `SSH_PORT` | Puerto SSH |
| `GHCR_TOKEN` | Token para que el servidor descargue la imagen de GHCR |

## 8. Actualizar

- **Cambio de código:** push a `main` → el workflow publica la imagen y despliega solo.
- **Cambio en `docker-compose.prod.yml` o `.env`:** el deploy **no los actualiza**, solo baja la imagen. Hay que aplicarlos a mano en el servidor:

```bash
cd /apps/craftplan
git pull
docker compose -f docker-compose.prod.yml up -d
```

Si `git pull` se queja de cambios locales en el compose, revisa qué cambió con `git diff` antes de descartarlo.

## 9. Seguridad

- **MinIO en local:** los puertos `9000` y `9001` se publican solo en `127.0.0.1` (Docker se salta `ufw`, así que no basta con cerrarlos ahí). Nginx usa `127.0.0.1:9000`.
- **Credenciales:** cambia `minioadmin` en el `.env` (sección 4).
- **Puerto 4000:** la app también queda publicada en `0.0.0.0:4000` sin HTTPS. Si todo el acceso pasa por nginx, publícalo solo en local (`127.0.0.1:4000:4000` en el compose).

## 10. Respaldos

Comandos estándar; pruébalos antes de depender de ellos.

```bash
# Base de datos
docker compose -f docker-compose.prod.yml exec -T postgres pg_dump -U postgres craftplan > respaldo-$(date +%F).sql

# Fotos (volumen de MinIO; el nombre lleva el prefijo del proyecto)
docker run --rm -v craftplan_minio_data:/data -v "$(pwd)":/backup alpine \
  tar czf /backup/minio-$(date +%F).tgz -C /data .
```

## 11. Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| La foto no carga; consola: *Mixed Content ... blocked* | La URL de la foto es `http://` con la página en HTTPS | Usar `AWS_S3_PUBLIC_SCHEME=https://` y el bloque `/craftplan/` de nginx |
| La foto no carga; consola: *violates Content Security Policy* | Origen de la imagen no permitido | Con el dominio público en `AWS_S3_PUBLIC_*` ya queda permitido |
| `SignatureDoesNotMatch` al abrir la foto | nginx no reenvía el `Host` original | Dejar `proxy_set_header Host $host;` |
| No se pueden subir fotos | Falta `AWS_S3_PORT` en el contenedor: el compose del servidor está desactualizado | `git pull` y `docker compose ... up -d`; verificar con `env \| grep AWS_S3_PORT` |
| Cambié el `.env` y no pasa nada | Los contenedores no se recrearon | `docker compose -f docker-compose.prod.yml up -d` |
| El deploy corrió pero la app sigue igual | El cambio era del compose o del `.env` | Aplicarlo a mano (sección 8) |
