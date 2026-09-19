# 01 — Arquitectura

## Resumen de la propuesta

```
┌─────────────────────────────┐
│  TravAway.App (.NET MAUI)   │   Android (y iOS/Windows gratis)
│  C# + XAML + MVVM           │
└──────────────┬──────────────┘
               │ HTTPS/JSON + SignalR (resultados en streaming)
┌──────────────▼──────────────────────────────────────────────┐
│  TravAway.Api  (ASP.NET Core 8 Minimal API)                 │
│  Auth, Mis Planes, disparo de búsquedas, historial          │
└──────────────┬──────────────────────────────────────────────┘
               │ cola (Redis / Hangfire)
┌──────────────▼──────────────────────────────────────────────┐
│  TravAway.Worker  (BackgroundService + Hangfire)            │
│  ├─ SearchOrchestrator  → fan-out a N conectores            │
│  ├─ TrackerScheduler    → rastreo diario por plan           │
│  └─ AlertEngine         → evalúa reglas, dispara push       │
└──────┬───────────────────────┬──────────────────────────────┘
       │                       │
┌──────▼────────┐      ┌───────▼─────────────────────────────┐
│ Conectores    │      │ TravAway.Scraping (Playwright .NET) │
│ API (Amadeus, │      │ headless, pool de navegadores,      │
│ Duffel, Kiwi…)│      │ proxies, rate limiting              │
└──────┬────────┘      └───────┬─────────────────────────────┘
       └───────────┬───────────┘
        ┌──────────▼──────────┐   ┌──────────────┐
        │ PostgreSQL (Docker) │   │ Redis: caché │
        │ planes + historial  │   │ + colas      │
        └─────────────────────┘   └──────────────┘
```

## Decisión 1 — Xamarin ➜ .NET MAUI

**Xamarin llegó a fin de soporte el 1 de mayo de 2024.** Google Play ya exige niveles de
API que Xamarin.Android no acompaña sin parches, y no vas a recibir correcciones de seguridad.

.NET MAUI es su sucesor oficial: **mismo lenguaje (C#), mismo XAML, mismo MVVM**. Si ya sabés
Xamarin.Forms, la curva es de días, no de meses. Conservás todo lo que te interesaba de Xamarin
y además te queda iOS/Windows sin trabajo extra.

| Opción | Veredicto |
|---|---|
| **.NET MAUI + CommunityToolkit.Mvvm** | ✅ **Recomendado.** Sucesor directo, C#/XAML, soporte a largo plazo |
| Xamarin.Forms | ❌ Fin de vida, sin parches de seguridad |
| Blazor Hybrid (MAUI + Blazor) | 🤔 Válido si preferís HTML/CSS al XAML; mismo backend |
| Avalonia UI | 🤔 Alternativa sólida si algún día querés desktop Linux |

Si preferís quedarte en Xamarin igual, todo lo demás de este diseño aplica sin cambios: el
móvil es un cliente delgado y la inteligencia vive en el backend.

## Decisión 2 — El teléfono NO busca. El backend busca.

Es la decisión de arquitectura más importante del proyecto. El móvil **nunca** consulta
proveedores directamente. Motivos:

- **Rastreo automático diario**: Android mata procesos en background. `WorkManager` no garantiza
  una ventana diaria confiable, y menos con 20 consultas de red. Un worker en el servidor sí.
- **Credenciales**: las API keys de Amadeus/Duffel/Kiwi no pueden vivir en un APK (se extraen con
  `apktool` en dos minutos).
- **Scraping**: Playwright no corre en Android.
- **Caché compartida**: una búsqueda EZE→MAD del martes sirve para vos en el celular y en la web.
- **Batería y datos**: 20 requests en paralelo desde el teléfono es inviable.

El móvil dispara una búsqueda, recibe un `searchId`, y escucha resultados por SignalR **a medida
que cada proveedor responde** (los rápidos aparecen en 2s, no esperás al más lento).

## Decisión 3 — Patrón de orquestación: fan-out con degradación elegante

```csharp
public interface IFlightProvider
{
    string ProviderId { get; }          // "amadeus", "despegar", ...
    ProviderCapabilities Capabilities { get; }  // qué filtros soporta nativamente
    Task<ProviderResult> SearchAsync(SearchCriteria criteria, CancellationToken ct);
}
```

El orquestador:

1. Selecciona los proveedores aptos para el criterio (ej.: no consulta una OTA brasileña si el
   origen es EZE y no emite en AR).
2. Lanza los N en paralelo con **presupuesto de tiempo global** (ej. 25 s) y timeout individual (15 s).
3. Aplica **circuit breaker por proveedor** (Polly): si falla 5 veces seguidas, queda fuera 10 min.
4. **Nunca falla la búsqueda entera** porque un proveedor cayó: devuelve lo que llegó y marca
   los caídos como "sin respuesta" en la UI.
5. Normaliza cada oferta al modelo canónico y **deduplica** por
   `(operatingCarrier, flightNumbers[], fechas, cabina, familiaTarifaria)`, quedándose con el
   precio más bajo y guardando los demás vendedores como alternativas.

## Decisión 4 — Los filtros importantes van en la normalización, no en el filtro visual

Equipaje, carry-on, reembolsable y cambio de fecha son los filtros que pediste, y son **los que
peor expone cada proveedor**: cada uno los devuelve en un formato distinto, y varios no los
devuelven en absoluto en el resultado de búsqueda (hay que pedir las reglas de la tarifa).

La estrategia es un enum de tres estados en el modelo canónico:

```csharp
public enum PolicyState { Incluido, NoIncluido, ConCosto, Desconocido }
```

`Desconocido` es un valor legítimo y la UI lo muestra como tal (un guion gris, no un ✗). Es
preferible decir "no sé" a mentir sobre una política de cancelación. Cuando el usuario filtra por
"reembolsable", elige si quiere incluir los `Desconocido` o no.

Cuándo se resuelve cada uno:
- **En la búsqueda**: lo que el proveedor ya devuelve (Amadeus y Duffel traen bastante).
- **Bajo demanda**: al abrir el detalle de una oferta se dispara una llamada de reglas tarifarias
  (`FareRules` / `PriceOffer`) que completa lo `Desconocido`.

## Stack completo

| Capa | Tecnología | Por qué |
|---|---|---|
| Móvil | .NET MAUI 8 + CommunityToolkit.Mvvm | C#/XAML, sucesor de Xamarin |
| API | ASP.NET Core 8 Minimal API | Mismo lenguaje, rápido, OpenAPI incluido |
| Tiempo real | SignalR | Resultados en streaming durante la búsqueda |
| Jobs | Hangfire + PostgreSQL storage | Dashboard web para ver los rastreos, reintentos, cron |
| ORM | EF Core 8 + Npgsql | Migraciones versionadas |
| Base | PostgreSQL 16 (Docker) | Lo que pediste; excelente para series de precios |
| Caché/colas | Redis 7 | TTL corto por búsqueda, deduplicación de requests |
| Resiliencia | Polly | Retry, circuit breaker, timeout, bulkhead |
| Scraping | Playwright for .NET | Único que maneja SPAs con JS pesado |
| Push | Firebase Cloud Messaging | Estándar en Android |
| Observabilidad | Serilog + OpenTelemetry → Seq/Grafana | Sin esto no sabés qué conector se rompió |
| Tests | xUnit + Testcontainers + WireMock.Net | Postgres real en test, proveedores simulados |

## Estructura de la solución

```
TravAway.sln
├── src/
│   ├── TravAway.App/                 # .NET MAUI — Android
│   ├── TravAway.Api/                 # ASP.NET Core Minimal API
│   ├── TravAway.Worker/              # Hangfire: rastreo + alertas
│   ├── TravAway.Core/                # Modelo canónico, interfaces, reglas
│   ├── TravAway.Infrastructure/      # EF Core, repos, Redis
│   ├── TravAway.Providers.Abstractions/
│   ├── TravAway.Providers.Amadeus/
│   ├── TravAway.Providers.Duffel/
│   ├── TravAway.Providers.Kiwi/
│   ├── TravAway.Providers.Travelpayouts/
│   ├── TravAway.Providers.Web/       # conectores Playwright
│   └── TravAway.Shared.Contracts/    # DTOs compartidos App ↔ Api
├── tests/
└── infra/                            # docker-compose, migraciones
```

`TravAway.Shared.Contracts` compartido entre MAUI y la API significa **cero DTOs duplicados** y
errores de contrato en tiempo de compilación en lugar de en producción.
