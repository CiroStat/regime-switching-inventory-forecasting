# 07 — Monte Carlo workflow diagram
# Presentation-only script reconstructed from the final diagram source.

required <- c("DiagrammeR", "DiagrammeRsvg", "rsvg")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  stop("Install diagram packages first: ", paste(missing, collapse = ", "))
}

dir.create("outputs/figures", showWarnings = FALSE, recursive = TRUE)

mc_diagram <- DiagrammeR::grViz("
digraph montecarlo {
  graph [layout = dot, rankdir = TB, bgcolor = white]
  node [shape = box, style = rounded, fontname = 'Times New Roman', fontsize = 12,
        width = 3.4, height = 0.65]
  edge [color = black, arrowsize = 0.7]
  A [label = 'Historical Inventory Series']
  B [label = 'Fit MS-AR Model']
  C [label = 'Last Stock Level +\\nFinal Regime Probabilities']
  D [label = 'Monte Carlo Simulation\\n2,000 paths; 14-day horizon']
  E [label = 'Predictive Distribution']
  F [label = 'Low-Stock Probabilities\\nh = 1, 7, 14']
  G [label = 'Inventory Risk Metrics']
  A -> B; B -> C; C -> D; D -> E; D -> F; E -> G; F -> G
}")

svg_code <- DiagrammeRsvg::export_svg(mc_diagram)
writeLines(svg_code, "outputs/figures/Monte_Carlo_Workflow.svg")
rsvg::rsvg_pdf(charToRaw(svg_code), "outputs/figures/Monte_Carlo_Workflow.pdf")
