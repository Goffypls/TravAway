# 05 — Boceto de la app y sistema visual

Pediste algo **poco cargado, minimalista, celeste y blanco, con letras negras**. Eso es
exactamente lo correcto para esta app: la pantalla de resultados ya trae mucha información
(precio, horarios, escalas, equipaje, políticas), así que la interfaz tiene que desaparecer para
que los datos respiren.

## Paleta

| Token | Hex | Uso |
|---|---|---|
| `Celeste` | `#2E9BD8` | Acción principal, precios destacados, selección |
| `CelesteClaro` | `#E8F4FB` | Fondos de chips, tarjeta activa, franjas |
| `CelesteOscuro` | `#1B6E9C` | Estado presionado, texto sobre celeste claro |
| `Blanco` | `#FFFFFF` | Superficie de tarjetas |
| `Fondo` | `#F7FAFC` | Fondo de pantalla (blanco roto, evita el gris sucio) |
| `Negro` | `#101418` | Texto principal |
| `Gris` | `#5B6670` | Texto secundario, metadatos |
| `Borde` | `#E3E8ED` | Separadores de 1px |
| `Verde` | `#1E8E5A` | Bajó de precio |
| `Rojo` | `#C0392B` | Subió de precio |

Solo dos acentos semánticos (verde/rojo) y un único color de marca. Nada de degradados.

> **Cuidado con el contraste:** celeste `#2E9BD8` sobre blanco da ~3:1, suficiente para texto de
> 24px o más y para bordes, pero **no** para texto chico. Los precios en celeste van en 20px+ en
> negrita; el texto corriente siempre en negro `#101418`.

## Tipografía

Una sola familia: **Inter** o la del sistema (Roboto en Android). Escala corta:

| Rol | Tamaño / peso |
|---|---|
| Título de pantalla | 28 / 700 |
| Precio destacado | 24 / 700 |
| Título de tarjeta | 17 / 600 |
| Cuerpo | 15 / 400 |
| Metadato | 13 / 400, gris |
| Etiqueta de chip | 13 / 500 |

## Navegación

Tres tabs abajo. Ni uno más.

```
┌──────────┬──────────────┬──────────────┐
│  Buscar  │  Mis Planes  │ Notificaciones│
└──────────┴──────────────┴──────────────┘
```

Todo lo demás se apila encima: Resultados → Detalle de oferta, Mis Planes → Detalle del plan →
Historial.

## Las pantallas

### 1. Buscar
Formulario de una sola columna: origen (EZE fijo por defecto), destino, ida, vuelta, pasajeros,
cabina. Un botón celeste ancho. Debajo, "Búsquedas recientes" como chips.

### 2. Resultados
Encabezado fino con la ruta y un botón de filtros que muestra un badge con la cantidad activa.
**Barra de progreso de proveedores**: mientras buscan, se ven los chips con quién ya respondió.
Tarjetas de oferta: hora de salida → hora de llegada, duración, escalas, aerolínea, precio en
celeste a la derecha, y una fila de **íconos de política** (valija, mochila, cancelación, cambio).
El ícono en gris con un guion significa "no se sabe", nunca se dibuja una cruz por defecto.

### 3. Filtros
Hoja modal desde abajo. Secciones: Escalas · Equipaje · Flexibilidad · Clase · Aerolíneas ·
Horarios · Duración. Contador de resultados en vivo en el botón de aplicar.

### 4. Detalle de oferta
Timeline vertical del itinerario (cada segmento con aeronave y duración de escala), bloque de
políticas con los cuatro estados expandidos y sus costos, y dos acciones: **Comprar** (deep link
al vendedor) y **Guardar en un plan**.

### 5. Mis Planes
Lista de tarjetas. Cada una: nombre del viaje, ruta, ventana de fechas, mejor precio actual,
variación desde el último rastreo (verde/rojo), un sparkline de 30 días y cuándo fue el último
rastreo. Botón flotante celeste para crear un plan.

### 6. Detalle del plan
Gráfico de precio (30/90/365 días) con línea de precio objetivo punteada. Debajo: mejor oferta
actual, configuración de rastreo (switch de automático + frecuencia), botón **"Rastrear ahora"**
para el chequeo manual, y el listado de snapshots.

### 7. Notificaciones
Lista simple, no leídas con un punto celeste. Cada una lleva al plan que la originó.

## Principios que mantienen la app liviana

1. **Una acción primaria por pantalla**, en celeste. Todo lo demás es texto negro o borde gris.
2. **Sin sombras.** Separación por bordes de 1px y espacio en blanco.
3. **Radio de 12px** en tarjetas, 8px en chips. Consistente en todos lados.
4. **Espaciado en múltiplos de 4**, márgenes laterales de 20px.
5. **Estados vacíos con texto, no con ilustraciones.** "Todavía no guardaste ningún plan" + un botón.
6. **Nunca un spinner a pantalla completa**: los resultados aparecen a medida que llegan.
7. **Área táctil mínima de 44px** en todo lo que se pueda tocar.

## Implementación en MAUI

```xml
<!-- Resources/Styles/Colors.xaml -->
<Color x:Key="Celeste">#2E9BD8</Color>
<Color x:Key="CelesteClaro">#E8F4FB</Color>
<Color x:Key="Negro">#101418</Color>
<Color x:Key="Gris">#5B6670</Color>
<Color x:Key="Borde">#E3E8ED</Color>
<Color x:Key="Fondo">#F7FAFC</Color>
```

Navegación con **Shell** (`TabBar` de 3 items), listas con `CollectionView` (virtualiza, a
diferencia de `ListView`), filtros con `BottomSheet` del CommunityToolkit, y gráficos con
**LiveChartsCore.SkiaSharpView.Maui** o `Microcharts` si querés algo más simple para el sparkline.
