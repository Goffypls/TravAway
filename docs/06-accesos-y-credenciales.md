# 06 — Qué hay que conseguir (lo que no es gratis ni abierto)

Casi todo el stack de TravAway es open source y no requiere trámite: .NET 8, MAUI, ASP.NET Core,
EF Core, PostgreSQL, Redis, Playwright, Hangfire, Polly, Serilog, LiveCharts. Instalás y andás.

Lo que **sí** hay que ir a buscar afuera es corto y está casi todo en un solo lugar: las
credenciales de los proveedores de vuelos.

> ⚠️ Los precios, planes gratuitos y requisitos de alta de terceros cambian seguido. Verificá cada
> uno en su sitio antes de decidir — lo de acá es la referencia de qué buscar, no una cotización.

---

## 1. Credenciales de proveedores de vuelos

Este es el único bloqueo real del proyecto. Sin al menos una, no hay búsqueda.

### Alta inmediata, sin hablar con nadie (empezá por acá)

| Proveedor | Cómo se consigue | Costo |
|---|---|---|
| **Amadeus for Developers** | Te registrás en su portal, te dan API key y secret al instante. Entorno *test* gratis con datos de prueba; pasar a producción es un botón + tarjeta | Test gratis; producción por volumen de llamadas |
| **Travelpayouts** | Alta de afiliado, aprobación rápida. Te da token de API y links de afiliado | Gratis; vos cobrás comisión |
| **Duffel** | Registro self-service, modo test inmediato. Producción requiere completar datos de la empresa | Test gratis; producción por transacción |

Con **Amadeus test + Travelpayouts** ya podés hacer las fases 0 a 4 completas. Eso es lo mínimo
para tener la app funcionando de punta a punta.

### Requieren aprobación (semanas, no minutos)

| Proveedor | Qué te van a pedir |
|---|---|
| **Kiwi.com (Tequila)** | Formulario de partner: qué app estás haciendo, volumen estimado, modelo de negocio |
| **Skyscanner Partners** | Proceso de aprobación más exigente. Suelen querer una app ya publicada y tráfico |
| **Programas de afiliados de OTAs** (Despegar, Booking, Kayak, Expedia TAAP, eDreams) | Alta como afiliado: datos fiscales, a veces un sitio o app operativa |

Son gratis, pero se piden y se esperan. Conviene mandarlos temprano aunque todavía no los vayas a
usar, porque el tiempo de espera corre en paralelo a tu desarrollo.

### Contrato comercial de verdad (probablemente nunca los necesites)

**Sabre**, **Travelport** y **Travelfusion** requieren relación de agencia de viajes, certificación
técnica y contrato. Están en el documento por completitud; para lo que querés hacer, no hacen
falta.

---

## 2. Infraestructura

Acá hay un costo inevitable, y viene de una decisión que ya tomamos: el rastreo diario corre en el
servidor, no en el teléfono. Eso significa **una máquina prendida 24/7**.

| Qué | Opciones | Costo aproximado |
|---|---|---|
| VPS para API + Worker + Postgres + Redis | Hetzner, DigitalOcean, Contabo, Oracle Cloud Free Tier | Desde gratis (Oracle) a unos pocos USD/mes |
| Dominio | Cualquier registrador | ~USD 10–15/año |
| Certificado TLS | Let's Encrypt | Gratis |

Con 2 GB de RAM te alcanza de sobra para vos y unos cuantos planes. Playwright es lo más pesado;
si sumás muchos conectores web, subí a 4 GB.

**Alternativa de costo cero al principio:** corré todo en tu propia PC con Docker mientras
desarrollás. Solo necesitás el VPS cuando quieras que el rastreo ande con la máquina apagada.

---

## 3. Publicación en Android

| Qué | Cuándo lo necesitás | Costo |
|---|---|---|
| **Cuenta de Google Play Developer** | Solo si vas a publicar en la tienda | Pago único (~USD 25), + verificación de identidad |
| **Keystore de firma** | Siempre, para cualquier release | Gratis, lo generás vos con `keytool` |
| **Firebase (Cloud Messaging)** | Para las notificaciones push | Gratis — FCM no cobra por mensajes |

**Si la app es para vos y un par de amigos, saltate Play Store entero.** Generás el APK firmado y
lo instalás directo. Cero costo, cero trámite, cero revisión de Google. Google Play solo tiene
sentido si querés distribución pública — y desde hace un tiempo también piden verificación de
identidad para desarrolladores individuales, así que es un paso que conviene dejar para cuando
realmente lo necesites.

---

## 4. Datos de referencia (el detalle que nadie ve venir)

Vas a necesitar el catálogo de aeropuertos y aerolíneas: códigos IATA/ICAO, ciudad, país, zona
horaria. Sirve para el autocompletar de origen/destino y para calcular duraciones correctamente.

| Fuente | Licencia | Notas |
|---|---|---|
| **OurAirports** | Dominio público | La más completa y actualizada. **Usá esta** |
| **OpenFlights** | Open Database License | Clásica, pero con datos viejos en partes |
| Base oficial de IATA | Comercial, licencia paga | No hace falta para esto |

Se descarga una vez, se carga en una tabla de Postgres y listo. También te conviene una fuente de
cotización ARS/USD si vas a mostrar precios en pesos: el BCRA publica las suyas y hay APIs
gratuitas de dólar en Argentina con límites generosos.

---

## Resumen: qué conseguir y cuándo

**Para arrancar mañana (gratis, 20 minutos):**
1. API key de Amadeus, entorno test
2. Token de Travelpayouts
3. Dataset de OurAirports
4. Docker en tu máquina

**Para tener rastreo automático de verdad:**
5. Un VPS barato

**Cuando la app ya funcione:**
6. Solicitudes a Kiwi y a los afiliados de OTAs (mandalas temprano, tardan)
7. Proyecto de Firebase para el push

**Solo si vas a publicar:**
8. Cuenta de Google Play Developer

Todo lo demás del stack es software libre. El proyecto puede llegar a la Fase 5 completa sin que
gastes un peso.
