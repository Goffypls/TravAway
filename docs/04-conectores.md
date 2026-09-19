# 04 — Conectores: las fuentes y cómo integrarlas

## Lo primero: no todos los conectores se construyen igual

Pediste "10 o 20 páginas de e-commerce". La forma de llegar a esas 20 fuentes **no es raspar 20
sitios**. Es una pirámide de tres niveles, y conviene agotar el nivel de arriba antes de bajar.

```
        ┌───────────────────────────────────┐
  Nivel 1│  APIs oficiales / agregadores     │  Estables, legales, contractuales
        │  5–6 conectores → miles de tarifas│  ← EL 80% DEL VALOR ESTÁ ACÁ
        ├───────────────────────────────────┤
  Nivel 2│  Programas de afiliados de OTAs   │  Legales, con deep link y comisión
        │  Despegar, Booking, Kayak...      │
        ├───────────────────────────────────┤
  Nivel 3│  Scraping de sitios sin programa  │  Frágil, sensible legalmente
        │  Solo si el nivel 1–2 no alcanza  │
        └───────────────────────────────────┘
```

Un solo conector de Nivel 1 como Kiwi o Travelpayouts ya agrega **cientos de OTAs y aerolíneas**
por dentro. Tres conectores de Nivel 1 te dan más cobertura real que quince scrapers, y no se
rompen el martes que Despegar rediseñe su grilla.

---

## Nivel 1 — APIs (empezá por acá)

| Proveedor | Qué aporta | Acceso | Notas |
|---|---|---|---|
| **Amadeus Self-Service** | GDS completo, contenido global | Sandbox gratis, self-service | **Arrancá por acá.** Devuelve equipaje y familia tarifaria |
| **Duffel** | NDC directo de aerolíneas | Test gratis, prod con contrato | Mejor modelado de políticas de todo el mercado |
| **Kiwi.com (Tequila)** | Agrega OTAs + low cost, incluye "virtual interlining" | Partner, gratis para empezar | Muy fuerte en rutas raras desde Sudamérica |
| **Travelpayouts / Aviasales** | Metabuscador con ~100 agencias por dentro | Afiliado, alta inmediata | Excelente relación esfuerzo/cobertura |
| **Skyscanner Partners** | Metabuscador global | Requiere aprobación | Cuesta entrar, vale la pena si entrás |
| **Travelfusion** | Agregador de low cost | Contrato comercial | Para cuando el proyecto sea serio |
| **Sabre / Travelport** | GDS clásicos | Contrato + certificación | Solo si tenés relación de agencia |

**Para vuelos saliendo de Ezeiza específicamente**, la mejor combinación inicial es
**Amadeus + Kiwi + Travelpayouts**: te cubre Aerolíneas Argentinas, las europeas, las brasileñas
y las low cost, con emisión nacional e internacional.

## Nivel 2 — Afiliados de OTAs

Estas son las "páginas de e-commerce" que mencionaste. Casi todas tienen programa de afiliados
que te da feed de precios y/o deep links **con permiso**, lo que resuelve tu caso de uso sin
riesgo legal:

| OTA | Región | Camino recomendado |
|---|---|---|
| Despegar | AR / LatAm | Programa de afiliados Despegar |
| Al Mundo | AR | Afiliados (es del grupo Despegar) |
| Almundo / Turismocity | AR | Turismocity tiene API para partners |
| Bestday / Price Travel | MX / LatAm | Afiliados |
| Booking.com Flights | Global | Booking Affiliate Partner Program |
| Kayak | Global | Kayak Affiliate Network |
| Expedia / eDreams / Opodo / Gotogate | Global | Expedia TAAP, eDreams ODIGEO afiliados |
| Kiwi, Trip.com, Mytrip, Kissandfly | Global | Ya cubiertas vía Travelpayouts |

Sumando Nivel 1 + Nivel 2 se llega cómodamente a **más de 20 fuentes efectivas** sin escribir un
solo scraper.

## Nivel 3 — Scraping

Para un sitio que no tiene ni API ni programa de afiliados. Va último, y el motivo principal es
técnico: **es la fuente que más se rompe**. Un selector cambia y el conector deja de andar; una
API versionada no.

### El encuadre, sin drama

Buscar precios de vuelos, compararlos y seguirlos día a día es una actividad perfectamente
normal: es el negocio entero de Kayak, Skyscanner y Turismocity. Automatizar para vos mismo lo
que harías abriendo veinte pestañas a mano no cambia eso.

El scraping tiene un matiz, y conviene tenerlo claro para dimensionarlo:

- Casi todas las OTAs lo prohíben en sus términos de servicio. Eso es **materia contractual, no
  penal**: incumplir un ToS no es un delito.
- Para uso personal y volumen bajo (tus propios planes, una consulta por día), el riesgo realista
  es uno solo: **que te bloqueen la IP y el conector deje de funcionar**.
- Donde sí aparecen reclamos de verdad es en otra cosa: republicar la base de precios de una OTA
  como producto propio, o barrer el sitio con miles de consultas y afectarle la infraestructura.
  Nada de eso es lo que hace TravAway.

### La regla práctica

Rastreá tus planes, no el catálogo. Una consulta por plan por día, `robots.txt` respetado,
`User-Agent` identificable y rate limit conservador te deja cómodamente del lado tranquilo y,
de paso, es lo que evita que te bloqueen.

Si algún día publicás la app o la compartís con gente, ahí sí migrá esas fuentes a programas de
afiliados. No es un trámite defensivo: existen justamente para que alguien consulte sus precios
y les mande compradores, y encima pagan comisión por hacerlo.

### Cómo se construye un conector web

```csharp
public abstract class WebConnectorBase : IFlightProvider
{
    protected abstract SelectorSet Selectors { get; }   // versionado en JSON aparte
    protected abstract Task NavigateToResultsAsync(IPage page, SearchCriteria c);
    protected abstract Task<IReadOnlyList<RawOffer>> ExtractAsync(IPage page);
    // Normalización y manejo de errores viven en la clase base
}
```

Reglas que hacen la diferencia entre un scraper que dura y uno que muere en dos semanas:

- **Selectores en un JSON versionado**, nunca hardcodeados. Arreglar un sitio = editar un archivo.
- **Test canario diario** por sitio: corre una búsqueda conocida y verifica que devuelva > 0
  resultados con precio parseable. Si falla dos días seguidos, el conector se autodesactiva y te
  llega una notificación.
- **Preferí la API interna al DOM.** Casi toda OTA moderna es una SPA que pega a su propio
  endpoint JSON. Interceptar esa respuesta con Playwright (`page.RouteAsync`) es muchísimo más
  estable que parsear HTML, y se rompe mucho menos seguido.
- **Rate limit por dominio** y jitter entre requests.
- **Un contenedor aparte** para Playwright: si un navegador se cuelga, no se lleva puesta la API.

---

## Cómo se registra un conector en el sistema

```csharp
// Program.cs del Worker
services.AddFlightProvider<AmadeusProvider>(o => {
    o.Priority = 1;                     // orden de preferencia ante empate
    o.TimeoutSeconds = 15;
    o.Capabilities = ProviderCapabilities.CabinFilter
                   | ProviderCapabilities.BaggageInfo
                   | ProviderCapabilities.FareRules;
});
services.AddFlightProvider<KiwiProvider>(...);
services.AddWebFlightProvider<DespegarConnector>(o => {
    o.RequestsPerMinute = 4;            // conservador a propósito
    o.RespectRobotsTxt = true;
});
```

`ProviderCapabilities` permite al orquestador saber qué filtros puede delegar al proveedor y
cuáles tiene que aplicar él mismo después de normalizar.

## Matriz de cobertura de políticas (lo que realmente devuelve cada uno)

| Fuente | Equipaje bodega | Carry-on | Cancelación | Cambio fecha |
|---|---|---|---|---|
| Amadeus | ✅ búsqueda | ✅ búsqueda | ⚠️ reglas tarifarias | ⚠️ reglas tarifarias |
| Duffel | ✅ búsqueda | ✅ búsqueda | ✅ búsqueda | ✅ búsqueda |
| Kiwi | ✅ búsqueda | ✅ búsqueda | ⚠️ parcial | ⚠️ parcial |
| Travelpayouts | ⚠️ parcial | ❌ | ❌ | ❌ |
| Conectores web | ⚠️ variable | ⚠️ variable | ⚠️ variable | ⚠️ variable |

✅ disponible · ⚠️ requiere segunda llamada o viene incompleto · ❌ no disponible → `Desconocido`

Esta tabla es exactamente la razón por la que el modelo canónico tiene el estado `Desconocido` y
por la que el enriquecimiento de reglas tarifarias es bajo demanda y no en la búsqueda.
