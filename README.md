# TravAway

Orquestador de búsqueda y seguimiento de precios de vuelos con salida desde Buenos Aires (EZE/AEP),
consultando en paralelo múltiples fuentes (GDS/agregadores por API + OTAs nacionales e internacionales).

**Estado:** documentación de diseño e implementación. Todavía no hay código de aplicación.

## Qué resuelve

1. **Búsqueda federada**: una consulta → N proveedores en paralelo → resultados normalizados y comparables.
2. **Filtros que importan de verdad**: equipaje en bodega, carry-on, política de cancelación,
   política de cambio de fecha, clase de cabina y escalas.
3. **Mis Planes**: viajes guardados en PostgreSQL (Docker) con rastreo **manual y automático** (diario o a demanda).
4. **Alertas**: notificación push cuando un plan baja de un precio objetivo o cae un X%.

## Documentación

| Documento | Contenido |
|---|---|
| [docs/01-arquitectura.md](docs/01-arquitectura.md) | Stack, decisiones y por qué **.NET MAUI** en lugar de Xamarin |
| [docs/02-plan-implementacion.md](docs/02-plan-implementacion.md) | Roadmap por fases, entregables y criterios de aceptación |
| [docs/03-modelo-datos.md](docs/03-modelo-datos.md) | Esquema PostgreSQL + modelo canónico de oferta |
| [docs/04-conectores.md](docs/04-conectores.md) | Las ~20 fuentes, cómo se integra cada una y el marco legal |
| [docs/05-ui-boceto.md](docs/05-ui-boceto.md) | Pantallas, navegación y sistema visual (celeste / blanco / negro) |
| [infra/docker-compose.yml](infra/docker-compose.yml) | PostgreSQL + Redis + pgAdmin para desarrollo local |

## Arranque rápido del entorno de datos

```bash
cd infra
cp .env.example .env     # editar credenciales
docker compose up -d
```

PostgreSQL queda en `localhost:5432`, pgAdmin en `http://localhost:5050`.
