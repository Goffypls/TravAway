# 03 — Modelo de datos

## Modelo canónico de oferta (C#)

Todo proveedor, tenga API o se raspe, termina produciendo esto. Es el contrato que hace posible
comparar Despegar con Amadeus.

```csharp
public sealed record FlightOffer
{
    public required string Id { get; init; }
    public required string ProviderId { get; init; }      // "amadeus", "despegar", ...
    public required string SellerName { get; init; }      // quién cobra
    public Uri? DeepLink { get; init; }                   // para ir a comprar

    public required Money TotalPrice { get; init; }       // impuestos incluidos
    public Money? BasePrice { get; init; }
    public Money? TaxesAndFees { get; init; }

    public required IReadOnlyList<Itinerary> Itineraries { get; init; }  // ida, vuelta...
    public required CabinClass Cabin { get; init; }
    public string? FareFamily { get; init; }              // "Light", "Flex"...
    public required FarePolicy Policy { get; init; }

    public int? SeatsRemaining { get; init; }
    public required DateTimeOffset RetrievedAt { get; init; }
    public bool IsEstimate { get; init; }                 // precio de caché / sin verificar
}

public sealed record Itinerary
{
    public required IReadOnlyList<Segment> Segments { get; init; }
    public TimeSpan TotalDuration { get; init; }
    public int StopCount => Segments.Count - 1;
}

public sealed record Segment
{
    public required string MarketingCarrier { get; init; }   // "AR"
    public string? OperatingCarrier { get; init; }           // quién vuela de verdad
    public required string FlightNumber { get; init; }
    public required string Origin { get; init; }             // "EZE"
    public required string Destination { get; init; }        // "MAD"
    public required DateTimeOffset DepartureUtc { get; init; }
    public required DateTimeOffset ArrivalUtc { get; init; }
    public string? Aircraft { get; init; }
    public TimeSpan? LayoverAfter { get; init; }
}

/// Cada política es tri-estado. "Desconocido" es un valor válido y se muestra como tal.
public sealed record FarePolicy
{
    public required BaggageAllowance CheckedBaggage { get; init; }
    public required BaggageAllowance CarryOn { get; init; }
    public required PolicyState Cancellation { get; init; }
    public Money? CancellationFee { get; init; }
    public required PolicyState DateChange { get; init; }
    public Money? DateChangeFee { get; init; }
    public bool PolicyIsComplete => Cancellation != PolicyState.Desconocido
                                 && DateChange   != PolicyState.Desconocido;
}

public sealed record BaggageAllowance(PolicyState State, int? Pieces, int? WeightKg, Money? Fee);

public enum PolicyState { Incluido, NoIncluido, ConCosto, Desconocido }
public enum CabinClass   { Economy, PremiumEconomy, Business, First }
```

**El campo que más importa es `Desconocido`.** Ningún proveedor devuelve las cuatro políticas de
forma confiable en el resultado de búsqueda. Modelar la ignorancia explícitamente evita el peor
bug posible: decirle al usuario que su pasaje es reembolsable cuando no lo es.

## Esquema PostgreSQL

```sql
-- ─── Usuarios ────────────────────────────────────────────────────────────
CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         CITEXT UNIQUE NOT NULL,
    display_name  TEXT,
    fcm_token     TEXT,                       -- push de Firebase
    home_airport  CHAR(3) DEFAULT 'EZE',
    currency      CHAR(3) DEFAULT 'ARS',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── Mis Planes ──────────────────────────────────────────────────────────
CREATE TABLE travel_plans (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name              TEXT NOT NULL,             -- "Japón en primavera"
    origin            CHAR(3) NOT NULL,          -- EZE
    destination       CHAR(3) NOT NULL,          -- NRT
    trip_type         TEXT NOT NULL,             -- oneway | roundtrip | multicity
    depart_date       DATE NOT NULL,
    return_date       DATE,
    date_flex_days    SMALLINT NOT NULL DEFAULT 0,   -- ±N días alrededor
    adults            SMALLINT NOT NULL DEFAULT 1,
    children          SMALLINT NOT NULL DEFAULT 0,
    infants           SMALLINT NOT NULL DEFAULT 0,
    filters           JSONB NOT NULL DEFAULT '{}',   -- SearchFilters serializado
    target_price      NUMERIC(12,2),
    target_currency   CHAR(3) DEFAULT 'ARS',
    tracking_enabled  BOOLEAN NOT NULL DEFAULT true,
    tracking_cron     TEXT NOT NULL DEFAULT '0 6 * * *',  -- 06:00 todos los días
    is_favorite       BOOLEAN NOT NULL DEFAULT false,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_plans_user_active ON travel_plans(user_id) WHERE tracking_enabled;

-- ─── Historial de precios (serie temporal) ───────────────────────────────
CREATE TABLE price_snapshots (
    id                BIGGENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    plan_id           UUID NOT NULL REFERENCES travel_plans(id) ON DELETE CASCADE,
    captured_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    trigger           TEXT NOT NULL,             -- scheduled | manual
    best_price        NUMERIC(12,2),
    currency          CHAR(3) NOT NULL,
    best_provider_id  TEXT,
    offers_found      INT NOT NULL DEFAULT 0,
    providers_ok      TEXT[] NOT NULL DEFAULT '{}',
    providers_failed  TEXT[] NOT NULL DEFAULT '{}',
    top_offers        JSONB                      -- top 10 ofertas completas
);
CREATE INDEX ix_snapshots_plan_time ON price_snapshots(plan_id, captured_at DESC);

-- ─── Favoritos: una oferta concreta que te gustó ─────────────────────────
CREATE TABLE saved_offers (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id      UUID REFERENCES travel_plans(id) ON DELETE SET NULL,
    offer        JSONB NOT NULL,                 -- FlightOffer congelada
    price_at_save NUMERIC(12,2) NOT NULL,
    note         TEXT,
    saved_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── Alertas ─────────────────────────────────────────────────────────────
CREATE TABLE alerts (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id      UUID NOT NULL REFERENCES travel_plans(id) ON DELETE CASCADE,
    rule_type    TEXT NOT NULL,   -- below_target | drop_percent | historic_low
    threshold    NUMERIC(12,2),
    enabled      BOOLEAN NOT NULL DEFAULT true,
    last_fired_at TIMESTAMPTZ
);

CREATE TABLE notifications (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id      UUID REFERENCES travel_plans(id) ON DELETE CASCADE,
    title        TEXT NOT NULL,
    body         TEXT NOT NULL,
    payload      JSONB,
    read_at      TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── Salud de conectores (para saber qué se rompió) ──────────────────────
CREATE TABLE provider_health (
    provider_id     TEXT PRIMARY KEY,
    display_name    TEXT NOT NULL,
    kind            TEXT NOT NULL,        -- api | affiliate | web
    enabled         BOOLEAN NOT NULL DEFAULT true,
    last_success_at TIMESTAMPTZ,
    last_error_at   TIMESTAMPTZ,
    last_error      TEXT,
    consecutive_failures INT NOT NULL DEFAULT 0,
    avg_latency_ms  INT
);

-- ─── Caché de búsquedas ad-hoc (las que no son de un plan) ───────────────
CREATE TABLE search_runs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID REFERENCES users(id) ON DELETE SET NULL,
    criteria      JSONB NOT NULL,
    criteria_hash TEXT NOT NULL,
    started_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at  TIMESTAMPTZ,
    offers        JSONB
);
CREATE INDEX ix_search_hash ON search_runs(criteria_hash, started_at DESC);
```

> `BIGGENERATED` arriba es `BIGINT GENERATED` — la migración real la genera EF Core; este SQL es
> la referencia conceptual del esquema.

## Nota sobre volumen

Un plan rastreado a diario genera 365 filas por año en `price_snapshots`. Con 50 planes son
18.250 filas/año: PostgreSQL ni se despeina. Si algún día tenés miles de planes, el camino es
particionar `price_snapshots` por mes, o agregar la extensión TimescaleDB. No hace falta ahora.
