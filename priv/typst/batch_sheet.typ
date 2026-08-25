// Production Batch Sheet — Craftplan
// Data is passed via sys.inputs.elixir_data

#let data = sys.inputs.elixir_data

#set page(
  paper: "a4",
  margin: (top: 2cm, bottom: 2.5cm, left: 2cm, right: 2cm),
  footer: context {
    set text(8pt, fill: luma(120))
    grid(
      columns: (1fr, 1fr),
      align(left, [Lote #data.batch_code]),
      align(right, [Página #counter(page).display("1 de 1", both: true)]),
    )
  },
)

#set text(font: "Inter", size: 10pt)

// ── Header ──────────────────────────────────────────────────
#align(center)[
  #text(18pt, weight: "bold")[Hoja de Lote de Producción]
]

#v(0.5cm)

#grid(
  columns: (1fr, 1fr),
  gutter: 0.5cm,
  [
    #text(14pt, weight: "bold")[#data.batch_code] \
    #text(11pt)[#data.product_name] \
    #text(9pt, fill: luma(100))[SKU: #data.product_sku]
  ],
  align(right)[
    #text(11pt)[Estado: *#data.status*] \
    #text(10pt)[Cant. Planificada: *#data.planned_qty*] \
    #if data.produced_at != "" [
      #text(9pt, fill: luma(100))[Producido: #data.produced_at]
    ]
  ],
)

#line(length: 100%, stroke: 0.5pt + luma(180))

// ── Orders ──────────────────────────────────────────────────
#v(0.4cm)
#text(12pt, weight: "bold")[Pedidos]
#v(0.2cm)

#if data.orders.len() > 0 [
  #table(
    columns: (auto, 1fr, auto, auto),
    stroke: 0.4pt + luma(180),
    inset: 6pt,
    align: (left, left, right, left),
    table.header(
      [*Referencia*], [*Cliente*], [*Cantidad*], [*Fecha de Entrega*],
    ),
    ..for order in data.orders {
      (
        order.reference,
        order.customer_name,
        order.quantity,
        order.delivery_date,
      )
    },
  )
] else [
  #text(9pt, fill: luma(120))[No hay pedidos asignados a este lote.]
]

// ── Materials / BOM ─────────────────────────────────────────
#v(0.4cm)
#text(12pt, weight: "bold")[Materiales (Lista de Materiales)]
#v(0.2cm)

#if data.bom_components.len() > 0 [
  #table(
    columns: (1fr, auto, auto, auto, auto, auto),
    stroke: 0.4pt + luma(180),
    inset: 6pt,
    align: (left, right, right, left, right, right),
    table.header(
      [*Material*], [*Cant. / Unidad*], [*Total Req.*], [*Unidad*], [*% Merma*], [*Uso Real*],
    ),
    ..for comp in data.bom_components {
      (
        comp.name,
        comp.qty_per_unit,
        comp.total_required,
        comp.unit,
        comp.waste_percent,
        [],
      )
    },
  )
] else [
  #text(9pt, fill: luma(120))[No se encontraron componentes de la lista de materiales.]
]

// ── Labor Steps ─────────────────────────────────────────────
#v(0.4cm)
#text(12pt, weight: "bold")[Pasos de Mano de Obra]
#v(0.2cm)

#if data.labor_steps.len() > 0 [
  #table(
    columns: (auto, 1fr, auto, auto, auto),
    stroke: 0.4pt + luma(180),
    inset: 6pt,
    align: (center, left, right, right, center),
    table.header(
      [*\#*], [*Paso*], [*Duración (min)*], [*Unidades / Corrida*], [*Hecho*],
    ),
    ..for step in data.labor_steps {
      (
        step.sequence,
        step.name,
        step.duration_minutes,
        step.units_per_run,
        [$square$],
      )
    },
  )
] else [
  #text(9pt, fill: luma(120))[No se definieron pasos de mano de obra.]
]

// ── Lots Consumed (conditional) ─────────────────────────────
#if data.lots.len() > 0 [
  #v(0.4cm)
  #text(12pt, weight: "bold")[Lotes Consumidos]
  #v(0.2cm)

  #table(
    columns: (auto, 1fr, auto, auto, auto),
    stroke: 0.4pt + luma(180),
    inset: 6pt,
    align: (left, left, right, left, left),
    table.header(
      [*Código de Lote*], [*Material*], [*Cant. Usada*], [*Vencimiento*], [*Proveedor*],
    ),
    ..for lot in data.lots {
      (
        lot.lot_code,
        lot.material_name,
        lot.quantity_used,
        lot.expiry_date,
        lot.supplier,
      )
    },
  )
]

// ── Cost Summary (conditional — only if batch completed) ────
#if data.show_costs == "yes" [
  #v(0.4cm)
  #text(12pt, weight: "bold")[Resumen de Costos]
  #v(0.2cm)

  #table(
    columns: (1fr, auto),
    stroke: 0.4pt + luma(180),
    inset: 6pt,
    align: (left, right),
    [Costo de Material], [#data.costs.material_cost],
    [Costo de Mano de Obra], [#data.costs.labor_cost],
    [Costo General], [#data.costs.overhead_cost],
    table.hline(stroke: 1pt),
    [*Costo Total*], [*#data.costs.total_cost*],
    [*Costo Unitario*], [*#data.costs.unit_cost*],
  )
]

// ── Compliance Footer ───────────────────────────────────────
#v(1cm)
#line(length: 100%, stroke: 0.5pt + luma(180))
#v(0.3cm)

#grid(
  columns: (1fr, 1fr),
  gutter: 1cm,
  [
    #text(9pt, weight: "bold")[Operador] \
    #v(0.8cm)
    #line(length: 100%, stroke: 0.4pt + luma(150))
    #text(8pt, fill: luma(120))[Firma]
  ],
  [
    #text(9pt, weight: "bold")[Supervisor] \
    #v(0.8cm)
    #line(length: 100%, stroke: 0.4pt + luma(150))
    #text(8pt, fill: luma(120))[Firma]
  ],
)

#v(0.3cm)

#grid(
  columns: (1fr, 1fr),
  gutter: 1cm,
  [
    #text(9pt, weight: "bold")[Fecha] \
    #v(0.5cm)
    #line(length: 100%, stroke: 0.4pt + luma(150))
  ],
  [],
)

#v(0.3cm)
#text(9pt, weight: "bold")[Observaciones]
#v(0.2cm)
#rect(
  width: 100%,
  height: 3cm,
  stroke: 0.4pt + luma(150),
  radius: 2pt,
  inset: 8pt,
  text(9pt, fill: luma(140))[#data.observations],
)
