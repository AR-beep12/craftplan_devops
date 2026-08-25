// Invoice — Craftplan
// Data is passed via sys.inputs.elixir_data

#let data = sys.inputs.elixir_data

#set page(
  paper: "a4",
  margin: (top: 2cm, bottom: 2cm, left: 2cm, right: 2cm),
  footer: context {
    set text(8pt, fill: luma(120))
    grid(
      columns: (1fr, 1fr),
      align(left, [Factura #data.reference]),
      align(right, [Página #counter(page).display("1 de 1", both: true)]),
    )
  },
)

#set text(size: 10pt)

// ── Header ──────────────────────────────────────────────────
#grid(
  columns: (1fr, 1fr),
  gutter: 1cm,
  [
    #text(24pt, weight: "bold")[Factura]
    #v(0.3cm)
    #text(10pt)[Referencia: *#data.reference*] \
    #text(10pt)[Emitido: #data.issued_date] \
    #if data.delivery_date != "" [
      #text(10pt)[Entrega: #data.delivery_date]
    ]
  ],
  align(right)[
    #text(11pt, weight: "bold")[Cliente] \
    #text(10pt)[#data.customer_name] \
    #if data.customer_address != "" [
      #text(9pt, fill: luma(80))[#data.customer_address]
    ]
  ],
)

#v(0.6cm)
#line(length: 100%, stroke: 0.5pt + luma(180))

// ── Line Items ──────────────────────────────────────────────
#v(0.4cm)

#table(
  columns: (1fr, auto, auto, auto),
  stroke: 0.4pt + luma(180),
  inset: 8pt,
  align: (left, right, right, right),
  table.header(
    [*Producto*], [*Cant.*], [*Precio unitario*], [*Total de línea*],
  ),
  ..for item in data.items {
    (
      item.product_name,
      item.quantity,
      item.unit_price,
      item.line_total,
    )
  },
)

// ── Totals ──────────────────────────────────────────────────
#v(0.4cm)

#align(right)[
  #block(width: 50%)[
    #table(
      columns: (1fr, auto),
      stroke: none,
      inset: 6pt,
      align: (left, right),
      [Subtotal], [#data.subtotal],
      [Envío], [#data.shipping_total],
      [Impuesto], [#data.tax_total],
      [Descuentos], [#data.discount_total],
      table.hline(stroke: 1pt + luma(120)),
      [*Total*], [*#data.total*],
    )
  ]
]

// ── Notes ───────────────────────────────────────────────────
#if data.notes != "" [
  #v(0.6cm)
  #line(length: 100%, stroke: 0.3pt + luma(200))
  #v(0.3cm)
  #text(9pt, fill: luma(100))[#data.notes]
]
