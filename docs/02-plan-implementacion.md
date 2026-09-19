# 02 — Plan de implementación

Siete fases. Cada una termina en algo que **funciona y se puede usar**, no en "media capa hecha".
Las estimaciones son de una persona trabajando part-time; ajustalas a tu ritmo.

---

## Fase 0 — Fundaciones (3–5 días)

**Objetivo:** que `docker compose up` + `dotnet run` levanten todo el esqueleto.

- [ ] Solución .NET 8 con la estructura de proyectos de `01-arquitectura.md`
- [ ] `docker-compose.yml`: PostgreSQL 16, Redis 7, pgAdmin
- [ ] EF Core + primera migración (esquema de `03-modelo-datos.md`)
- [ ] Serilog con salida estructurada + health checks (`/health`)
- [ ] App MAUI que arranca, muestra "Hola" y pega a `/health`
- [ ] CI en GitHub Actions: build + tests

**Criterio de aceptación:** el proyecto clona, levanta y el APK de debug muestra el estado del backend.

---

## Fase 1 — Modelo canónico y un solo proveedor (1–2 semanas)

**Objetivo:** buscar de verdad contra **una** fuente, de punta a punta.

- [ ] `TravAway.Core`: `SearchCriteria`, `FlightOffer`, `Itinerary`, `Segment`, `FarePolicy`
- [ ] Interfaz `IFlightProvider` + `ProviderCapabilities`
- [ ] **Conector Amadeus Self-Service** (tiene sandbox gratis — es el mejor para empezar)
- [ ] Normalizador Amadeus → modelo canónico, con tests sobre respuestas grabadas
- [ ] `POST /api/search` síncrono, devuelve ofertas normalizadas
- [ ] Pantalla de búsqueda + lista de resultados en MAUI

**Criterio de aceptación:** buscás EZE→MAD para una fecha y ves vuelos reales con precio, escalas
y cabina.

> **Por qué Amadeus primero:** sandbox sin contrato comercial, documentación seria, y devuelve
> equipaje y clase tarifaria en la propia respuesta de búsqueda. Te obliga a diseñar bien el
> modelo canónico desde el día uno.

---

## Fase 2 — El orquestador (1–2 semanas)

**Objetivo:** N proveedores en paralelo sin que uno lento o caído arruine la búsqueda.

- [ ] `SearchOrchestrator`: fan-out con presupuesto global y timeout por proveedor
- [ ] Polly: retry con jitter, circuit breaker y bulkhead por proveedor
- [ ] Deduplicación de ofertas equivalentes entre vendedores
- [ ] Caché Redis por `(ruta, fechas, pax, cabina)` con TTL 15–30 min
- [ ] `POST /api/search` async → `searchId` + **SignalR** con resultados incrementales
- [ ] Segundo y tercer conector (Duffel, Kiwi/Tequila) para validar la abstracción
- [ ] UI: resultados que aparecen progresivamente + chips por proveedor con su estado

**Criterio de aceptación:** matás un proveedor a propósito y la búsqueda devuelve igual el resto,
marcando el caído.

---

## Fase 3 — Filtros reales (1 semana)

**Objetivo:** los filtros que pediste, honestos sobre lo que no se sabe.

- [ ] `FarePolicy` con `PolicyState { Incluido, NoIncluido, ConCosto, Desconocido }` para:
      equipaje en bodega, carry-on, cancelación, cambio de fecha
- [ ] Enriquecimiento bajo demanda: al abrir el detalle se piden reglas tarifarias
- [ ] Filtros de clase (Economy / Premium / Business / First) y escalas (directo / 1 / 2+)
- [ ] Filtros extra: aerolínea, franja horaria, duración máxima, aeropuerto de escala
- [ ] Panel de filtros en MAUI con contador de resultados en vivo
- [ ] Ordenamiento: precio, duración, y **"mejor valor"** (precio + escalas + duración ponderados)

**Criterio de aceptación:** "solo directos, con valija de bodega incluida y cambio de fecha sin
costo" devuelve exactamente eso, y lo desconocido se ve como desconocido.

---

## Fase 4 — Mis Planes + rastreo (2 semanas) ⭐ el corazón del producto

**Objetivo:** guardar un viaje y que se rastree solo.

- [ ] CRUD de `TravelPlan` (origen, destinos, ventana de fechas, flexibilidad ±N días, pax,
      filtros guardados, precio objetivo)
- [ ] `POST /api/plans/{id}/track` → rastreo **manual** inmediato
- [ ] Hangfire recurring job: rastreo **automático** con frecuencia por plan
      (diaria / 12 h / 6 h / semanal)
- [ ] `PriceSnapshot`: cada corrida guarda el mejor precio y el top-N de ofertas
- [ ] Gráfico de evolución de precio (30/90/365 días) en el detalle del plan
- [ ] Escalonado de jobs para no golpear a todos los proveedores al mismo tiempo

**Criterio de aceptación:** guardás un plan, cerrás la app, y al otro día tenés un punto nuevo en
el gráfico sin haber hecho nada.

---

## Fase 5 — Alertas (4–5 días)

- [ ] Reglas: precio bajo el objetivo, caída de X%, mínimo histórico, vuelve a haber disponibilidad
- [ ] `AlertEngine` evaluado después de cada snapshot
- [ ] Push con Firebase Cloud Messaging + centro de notificaciones en la app
- [ ] Anti-spam: máximo una alerta por plan por día, y no repetir el mismo precio

---

## Fase 6 — Conectores web (3–4 semanas, iterativo y continuo)

**Objetivo:** las OTAs que no tienen API (Despegar, Al Mundo y compañía).

- [ ] Servicio Playwright aislado, con su propio contenedor y pool de navegadores
- [ ] `WebConnectorBase`: navegación, espera de resultados, extracción, normalización
- [ ] Un conector por sitio, **cada uno con su archivo de selectores versionado**
- [ ] Rate limiting agresivo y respeto de `robots.txt`
- [ ] **Tests canario diarios**: si un sitio cambia el HTML, te enterás vos antes que el usuario
- [ ] Degradación: un conector roto se desactiva solo y avisa

> Leé `04-conectores.md` antes de esta fase. **Esta es la parte frágil y legalmente sensible del
> proyecto**; el plan la deja para el final a propósito, cuando el producto ya funciona sin ella.

---

## Fase 7 — Pulido (1–2 semanas)

- [ ] Modo offline: último resultado cacheado visible sin red
- [ ] Multi-moneda (ARS / USD) con la cotización del día y aclaración de impuestos AR
- [ ] Exportar un plan a PDF/compartir
- [ ] Onboarding y estados vacíos con personalidad
- [ ] Telemetría: qué proveedor aporta las mejores ofertas, cuál es más lento
- [ ] Firma de release y publicación en Play Store (o APK propio)

---

## Orden sugerido si querés ver algo funcionando rápido

Fase 0 → 1 → **4 (versión mínima: guardar plan + rastreo manual)** → 2 → 3 → 5 → 6.

Adelantar Mis Planes te da el diferencial del producto antes que la sofisticación del
orquestador, y te mantiene motivado.

## Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Las OTAs cambian el HTML | Alto, recurrente | Selectores versionados + canarios diarios + el producto no depende de ellas |
| Bloqueo por anti-bot (Cloudflare, DataDome) | Alto | Priorizar APIs oficiales y programas de afiliados; rate limit conservador |
| Políticas de equipaje/cancelación incompletas | Medio | Estado `Desconocido` explícito + enriquecimiento bajo demanda |
| Costo de las APIs al escalar | Medio | Caché agresiva, deduplicación de búsquedas, tiers gratuitos primero |
| Términos de servicio de las OTAs | **Legal** | Ver `04-conectores.md`: afiliados > scraping; uso personal ≠ redistribución |
| Android mata los jobs en background | Alto | Ya resuelto: el rastreo vive en el servidor |
